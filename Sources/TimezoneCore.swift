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
            return (destination.rawValue, Label(city: isUTC ? "协调世界时" : (cn.isEmpty || cn == "未知城市" ? fallback : cn),
                                               english: isUTC ? "Coordinated Universal Time" : (en.isEmpty || en == "Unknown City" ? fallback : en)))
        })
    }()
    static func search(_ query: String, at date: Date) -> [Destination] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard !terms.isEmpty else { return Destination.allCases }
        return Destination.allCases.filter { destination in
            let text = "\(destination.city) \(destination.englishCity) \(destination.rawValue.replacingOccurrences(of: "_", with: " ")) \(destination.rawValue) \(destination.offset(at: date).replacingOccurrences(of: "−", with: "-"))"
            return terms.allSatisfy { text.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
}

struct QuickZones: Equatable {
    static let key = "quickTimezones.v2"
    private(set) var zones: [Destination]
    init(defaults: UserDefaults) {
        let saved = defaults.stringArray(forKey: Self.key) ?? []
        let valid = saved.compactMap { Destination(rawValue: $0) }
        zones = saved.count == 2 && valid.count == 2 && valid[0] != valid[1] ? valid : [.lusaka, .losAngeles]
    }
    /// Returns false for a duplicate or invalid slot; editing never changes macOS.
    mutating func replace(slot: Int, with zone: Destination, defaults: UserDefaults) -> Bool {
        guard zones.indices.contains(slot), zones[1 - slot] != zone else { return false }
        zones[slot] = zone
        defaults.set(zones.map(\.rawValue), forKey: Self.key)
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
