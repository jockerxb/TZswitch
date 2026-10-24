import Foundation

/// A system-provided IANA identifier, never arbitrary shell input.
struct Destination: Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
    private static let allowed: Set<String> = {
        // Foundation can omit modern aliases (for example Asia/Kolkata).
        // Merge the system's IANA tables so valid installed IDs stay selectable.
        let tableIDs = ["zone.tab", "zone1970.tab"].flatMap { filename -> [String] in
            guard let table = try? String(contentsOfFile: "/usr/share/zoneinfo/" + filename, encoding: .utf8) else { return [] }
            return table.split(separator: "\n").compactMap { line in
                guard !line.hasPrefix("#") else { return nil }
                let fields = line.split(separator: "\t")
                return fields.count >= 3 ? String(fields[2]) : nil
            }
        }
        return Set(TimeZone.knownTimeZoneIdentifiers + tableIDs + ["Etc/UTC", "UTC"])
            .filter { TimeZone(identifier: $0) != nil && FileManager.default.fileExists(atPath: "/usr/share/zoneinfo/" + $0) }
    }()

    init?(rawValue: String) {
        guard Self.allowed.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }
    static let lusaka = Destination(rawValue: "Africa/Lusaka")!
    static let losAngeles = Destination(rawValue: "America/Los_Angeles")!
    static let allCases: [Destination] = allowed.sorted().compactMap { Destination(rawValue: $0) }
    var zone: TimeZone { TimeZone(identifier: rawValue)! }
    var city: String { ZoneCatalog.labels[rawValue]?.city ?? rawValue }
    var englishCity: String { ZoneCatalog.labels[rawValue]?.english ?? rawValue }
    var ruleData: Data? { try? Data(contentsOf: URL(fileURLWithPath: "/usr/share/zoneinfo/" + rawValue)) }
    var catalogID: String { ZoneCatalog.representatives[rawValue] ?? rawValue }
    func isSameLocation(as other: Destination) -> Bool { catalogID == other.catalogID }

    func offset(at date: Date) -> String {
        let minutes = zone.secondsFromGMT(for: date) / 60
        return String(format: "UTC%@%02d:%02d", minutes >= 0 ? "+" : "−", abs(minutes) / 60, abs(minutes) % 60)
    }
    func time(at date: Date, seconds: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = seconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: date)
    }
}

enum ZoneCatalog {
    struct Label { let city: String; let english: String }
    static let labels: [String: Label] = {
        let chinese = DateFormatter(), english = DateFormatter()
        chinese.locale = Locale(identifier: "zh_CN")
        english.locale = Locale(identifier: "en_US")
        chinese.dateFormat = "VVV"
        english.dateFormat = "VVV"
        return Dictionary(uniqueKeysWithValues: Destination.allCases.map { destination in
            chinese.timeZone = destination.zone
            english.timeZone = destination.zone
            let fallback = destination.rawValue.components(separatedBy: "/").last!.replacingOccurrences(of: "_", with: " ")
            let cn = chinese.string(from: Date()), en = english.string(from: Date())
            let isUTC = ["Etc/UTC", "UTC"].contains(destination.rawValue)
            return (destination.rawValue, Label(city: destination.rawValue == "Asia/Shanghai" ? "北京 / 上海" : (isUTC ? "协调世界时" : (cn.isEmpty || cn == "未知城市" ? fallback : cn)),
                                               english: isUTC ? "Coordinated Universal Time" : (en.isEmpty || en == "Unknown City" ? fallback : en)))
        })
    }()

    private struct LocationKey: Hashable { let city: String; let rules: Data }
    // Merge compatibility names only when both the localized city and complete
    // TZif rules agree. Equal current offsets alone must never merge cities.
    private static let locations: [[Destination]] = {
        let table = (try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8)) ?? ""
        let primary = Set(table.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(separator: "\t")
            return !line.hasPrefix("#") && fields.count >= 3 ? String(fields[2]) : nil
        })
        let grouped = Dictionary(grouping: Destination.allCases) {
            LocationKey(city: $0.englishCity, rules: $0.ruleData ?? Data($0.rawValue.utf8))
        }
        var result: [[Destination]] = []
        for members in grouped.values {
            let sorted = members.sorted { left, right in
                let a = left.rawValue == "Etc/UTC" || primary.contains(left.rawValue)
                let b = right.rawValue == "Etc/UTC" || primary.contains(right.rawValue)
                if a != b { return a }
                return left.rawValue < right.rawValue
            }
            result.append(sorted)
        }
        return result.sorted { $0[0].rawValue < $1[0].rawValue }
    }()
    static let representatives: [String: String] = Dictionary(uniqueKeysWithValues:
        locations.flatMap { members in members.map { ($0.rawValue, members[0].rawValue) } })
    static let choices: [Destination] = locations.map { $0[0] }
    private static let searchText: [String: String] = Dictionary(uniqueKeysWithValues: locations.map { members in
        let representative = members[0]
        let names = members.map { "\($0.city) \($0.englishCity) \($0.rawValue.replacingOccurrences(of: "_", with: " ")) \($0.rawValue)" }.joined(separator: " ")
        let aliases = representative.rawValue == "Asia/Shanghai" ? " 北京 Beijing Peking 北京时间 中国标准时间 China Standard Time" : ""
        return (representative.rawValue, names + aliases)
    })
    static func search(_ query: String, at date: Date) -> [Destination] {
        var textQuery = query.replacingOccurrences(of: "−", with: "-")
        var offsetSeconds: Int?
        // Parse UTC as an offset, rather than matching unrelated digits in IDs.
        let pattern = #"(?i)\butc\s*([+-]?)\s*([0-9]{1,2})(?::([0-9]{2})|\.([0-9]{1,2}))?(?![0-9:.])"#
        let expression = try! NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(textQuery.startIndex..<textQuery.endIndex, in: textQuery)
        if let match = expression.firstMatch(in: textQuery, range: fullRange) {
            func component(_ index: Int) -> String {
                guard let range = Range(match.range(at: index), in: textQuery) else { return "" }
                return String(textQuery[range])
            }
            let hours = Int(component(2))!
            let decimal = component(4)
            let minutes = decimal.isEmpty ? (Int(component(3)) ?? 0)
                : Int((Double("0." + decimal)! * 60).rounded())
            let sign = component(1) == "-" ? -1 : 1
            let total = sign * (hours * 3600 + minutes * 60)
            guard minutes < 60, (-12 * 3600...14 * 3600).contains(total) else { return [] }
            offsetSeconds = total
            textQuery.replaceSubrange(Range(match.range, in: textQuery)!, with: " ")
        }
        let terms = textQuery.split(whereSeparator: \.isWhitespace)
        let matches = choices.filter { destination in
            if let offsetSeconds, destination.zone.secondsFromGMT(for: date) != offsetSeconds { return false }
            let text = (searchText[destination.rawValue] ?? "") + " " + destination.offset(at: date).replacingOccurrences(of: "−", with: "-")
            return terms.allSatisfy { text.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        return matches.sorted {
            let left = $0.zone.secondsFromGMT(for: date), right = $1.zone.secondsFromGMT(for: date)
            if left != right { return left < right }
            let cityOrder = $0.city.compare($1.city, locale: Locale(identifier: "zh_CN"))
            return cityOrder == .orderedSame ? $0.rawValue < $1.rawValue : cityOrder == .orderedAscending
        }
    }

    struct OffsetGroup: Identifiable {
        let seconds: Int
        let title: String
        let zones: [Destination]
        var id: Int { seconds }
        var indexTitle: String {
            let minutes = abs(seconds) / 60
            let sign = seconds >= 0 ? "+" : "−"
            let hours = "\(sign)\(minutes / 60)"
            return minutes % 60 == 0 ? hours : hours + String(format: ":%02d", minutes % 60)
        }
    }
    static func groups(_ query: String, at date: Date) -> [OffsetGroup] {
        let matches = search(query, at: date)
        let grouped = Dictionary(grouping: matches) { $0.zone.secondsFromGMT(for: date) }
        return grouped.keys.sorted().map { seconds in
            let zones = grouped[seconds]!
            return OffsetGroup(seconds: seconds, title: zones[0].offset(at: date), zones: zones)
        }
    }
}

/// Up to two favorites; one saved city completes setup. Never modifies macOS.
struct FavoriteZones: Equatable {
    static let key = "favoriteTimezones.v3"
    static let legacyKey = "quickTimezones.v2"
    private(set) var slots: [Destination?]
    var configuredCount: Int { slots.compactMap { $0 }.count }
    var needsSetup: Bool { configuredCount == 0 }

    init(defaults: UserDefaults) {
        // Preserve existing users' choices; new installs start with two empty slots.
        let saved = defaults.stringArray(forKey: Self.key) ?? defaults.stringArray(forKey: Self.legacyKey)
        guard let saved, saved.count == 2 else { slots = [nil, nil]; return }
        slots = saved.map { Destination(rawValue: $0) }
        if let first = slots[0], let second = slots[1], first.isSameLocation(as: second) { slots[1] = nil }
    }
    /// Stage a change without mutating either the visible pair or saved defaults.
    func replacing(slot: Int, with zone: Destination) -> FavoriteZones? {
        guard slots.indices.contains(slot), slots[1 - slot]?.isSameLocation(as: zone) != true else { return nil }
        var updated = self
        updated.slots[slot] = zone
        return updated
    }
    func persist(defaults: UserDefaults) {
        defaults.set(slots.map { $0?.rawValue ?? "" }, forKey: Self.key)
    }
    /// Commit a validated replacement; callers awaiting authorization use staging instead.
    mutating func replace(slot: Int, with zone: Destination, defaults: UserDefaults) -> Bool {
        guard let updated = replacing(slot: slot, with: zone) else { return false }
        self = updated
        persist(defaults: defaults)
        return true
    }
}

struct SystemSnapshot {
    let identifier: String
    let automatic: Bool?
    var destination: Destination? { Destination(rawValue: identifier) }

    static func read() -> SystemSnapshot {
        let target = try? FileManager.default.destinationOfSymbolicLink(atPath: "/etc/localtime")
        let identifier = target?.components(separatedBy: "/zoneinfo/").last ?? TimeZone.current.identifier
        let url = URL(fileURLWithPath: "/Library/Preferences/com.apple.timezone.auto.plist")
        let data = try? Data(contentsOf: url)
        let dict = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]
        return SystemSnapshot(identifier: identifier, automatic: (dict?["Active"] as? NSNumber)?.boolValue)
    }
}

struct CommandResult {
    let status: Int32
    let output: String
}

enum SystemCommands {
    // Destination validates against system tzdata; quote again at the shell boundary.
    static func switchScript(to destination: Destination) -> String {
        """
        set -eu
        target=\(shellQuote(destination.rawValue))
        pref='/Library/Preferences/com.apple.timezone.auto'
        previous_auto=$(/usr/bin/defaults read "$pref" Active 2>/dev/null || /usr/bin/printf absent)
        previous_path=$(/usr/bin/readlink /etc/localtime)
        previous_zone=${previous_path##*/zoneinfo/}
        restore() {
            /usr/sbin/systemsetup -settimezone "$previous_zone" >/dev/null 2>&1 || true
            case "$previous_auto" in
                1) /usr/bin/defaults write "$pref" Active -bool true ;;
                0) /usr/bin/defaults write "$pref" Active -bool false ;;
                *) /usr/bin/defaults delete "$pref" Active >/dev/null 2>&1 || true ;;
            esac
        }
        trap 'restore' EXIT
        /usr/bin/defaults write "$pref" Active -bool false
        # Some macOS versions emit Error:-99 despite applying the timezone.
        # Verify actual system state rather than treating command output as success.
        /usr/sbin/systemsetup -settimezone "$target" >/dev/null 2>&1 || true
        actual_path=$(/usr/bin/readlink /etc/localtime)
        actual_zone=${actual_path##*/zoneinfo/}
        if [ "$actual_zone" != "$target" ]; then
            /usr/bin/printf 'VERIFY_FAILED: 系统时区未变更，已尝试恢复原设置。' >&2
            exit 1
        fi
        if [ "$(/usr/bin/defaults read "$pref" Active)" != '0' ]; then
            /usr/bin/printf 'AUTO_ZONE_FAILED: 自动时区未关闭，已尝试恢复原设置。' >&2
            exit 1
        fi
        trap - EXIT
        /usr/bin/printf 'VERIFIED:%s' "$actual_zone"
        """
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScript(for shell: String) -> String {
        let quoted = shell.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "do shell script \"\(quoted)\" with administrator privileges"
    }

    static func runAuthorized(_ script: String) -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript(for: script)]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        } catch {
            return CommandResult(status: -1, output: error.localizedDescription)
        }
    }
}

enum SwitchOutcome: Equatable {
    case success
    case cancelled
    case failure(String)

    static func evaluate(result: CommandResult, snapshot: SystemSnapshot, target: Destination) -> SwitchOutcome {
        if result.status != 0 {
            if result.output.contains("(-128)") { return .cancelled }
            return .failure("系统未完成切换。请重试或检查管理员权限。")
        }
        guard snapshot.identifier == target.rawValue, snapshot.automatic == false,
              result.output.contains("VERIFIED:\(target.rawValue)") else {
            return .failure("验证未通过：系统时区与所选城市不一致，请检查日期与时间设置。")
        }
        return .success
    }
}
