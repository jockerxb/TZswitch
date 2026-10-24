import AppKit
import SwiftUI

@MainActor final class AppModel: ObservableObject {
    @Published var snapshot = SystemSnapshot.read()
    @Published var now = Date()
    @Published var busy = false
    @Published var message: String?
    @Published var failed = false
    @Published var favorites = FavoriteZones(defaults: .standard)
    let authorizationReady: Bool
    private var lastVerified: Destination?
    private var timer: Timer?

    init() {
        authorizationReady = [Destination.lusaka].allSatisfy {
            var error: NSDictionary?
            return NSAppleScript(source: SystemCommands.appleScript(for: SystemCommands.switchScript(to: $0)))?.compileAndReturnError(&error) == true
        }
        if !authorizationReady {
            failed = true
            message = "系统授权组件不可用，请重新打开 App 后重试。"
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        now = Date()
        snapshot = .read()
        if let expected = lastVerified, !busy,
           snapshot.destination != expected || snapshot.automatic == true {
            failed = true
            message = "系统设置已被其他程序更改，请重新选择时区。"
            lastVerified = nil
        }
    }

    func saveFavorite(slot: Int, destination: Destination) -> Bool {
        guard !busy else { return false }
        var updated = favorites
        guard updated.replace(slot: slot, with: destination, defaults: .standard) else {
            failed = true
            message = "两个常用时区请选择不同的时区。"
            return false
        }
        favorites = updated
        failed = false
        message = "已保存常用时区，系统时区未更改。"
        return true
    }

    func select(_ target: Destination) {
        guard !busy else { return }
        guard snapshot.destination != target || snapshot.automatic != false else {
            failed = false
            message = "系统已使用\(target.city)时区。"
            return
        }
        let script = SystemCommands.switchScript(to: target)
        var compileError: NSDictionary?
        guard NSAppleScript(source: SystemCommands.appleScript(for: script))?.compileAndReturnError(&compileError) == true else {
            failed = true
            message = "系统授权组件不可用，请重新打开 App 后重试。"
            return
        }
        busy = true
        failed = false
        message = "请在 macOS 弹窗中授权…"
        Task {
            let result = await Task.detached { SystemCommands.runAuthorized(script) }.value
            snapshot = .read()
            busy = false
            switch SwitchOutcome.evaluate(result: result, snapshot: snapshot, target: target) {
            case .success:
                lastVerified = target
                message = "已切换至\(target.city)，退出 App 后继续生效。"
            case .cancelled:
                message = "已取消，系统设置未更改。"
            case .failure(let reason):
                failed = true
                message = reason
            }
        }
    }
}

private let ink = Color(red: 0.07, green: 0.10, blue: 0.17)
private let teal = Color(red: 0.08, green: 0.45, blue: 0.43)

struct PickerRequest: Identifiable {
    let slot: Int
    var id: Int { slot }
}

struct TimezoneView: View {
    @ObservedObject var model: AppModel
    @State private var picker: PickerRequest?
    private var inFavoritePair: Bool {
        model.favorites.slots.contains { $0?.rawValue == model.snapshot.identifier }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
                       let url = Bundle.main.url(forResource: name, withExtension: nil),
                       let icon = NSImage(contentsOf: url) {
                        Image(nsImage: icon).resizable().frame(width: 48, height: 48)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TZswitch").font(.system(size: 22, weight: .semibold))
                        Text("常用时区，随手切换").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(teal).frame(width: 6, height: 6)
                        Text("系统当前时区").font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text(model.snapshot.destination?.offset(at: model.now) ?? model.snapshot.identifier)
                            .font(.system(size: 11, design: .monospaced))
                    }.foregroundColor(.secondary)
                    Text(currentTime).font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                    HStack {
                        Text(model.snapshot.destination?.city ?? model.snapshot.identifier).font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text(currentDate).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Text(model.snapshot.identifier).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                }.padding(20).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 19))

                VStack(spacing: 10) {
                    HStack {
                        Text("常用时区").font(.system(size: 13, weight: .semibold))
                        if model.favorites.configuredCount > 0 {
                            Menu("设置") {
                                ForEach(0..<2, id: \.self) { slot in
                                    Button("常用时区 \(slot + 1) · \(model.favorites.slots[slot]?.city ?? "未设置")") {
                                        picker = PickerRequest(slot: slot)
                                    }
                                }
                            }
                            .menuStyle(.borderlessButton).fixedSize()
                            .font(.system(size: 11)).foregroundColor(.secondary)
                            .accessibilityLabel("设置常用时区").disabled(model.busy)
                        }
                        Spacer()
                        if model.busy { ProgressView().controlSize(.small) }
                        if model.favorites.isComplete, inFavoritePair {
                            Text("1 ⇄ 2").font(.system(size: 11)).foregroundColor(.secondary)
                            Toggle("切换两个常用时区", isOn: Binding(
                                get: { model.snapshot.destination == model.favorites.slots[1] },
                                set: { if let zone = model.favorites.slots[$0 ? 1 : 0] { model.select(zone) } }
                            ))
                            .labelsHidden().toggleStyle(.switch).tint(teal).disabled(model.busy)
                            .help("关闭使用常用时区 1，开启使用常用时区 2")
                        } else if model.favorites.isComplete {
                            Text("当前使用其他时区").font(.system(size: 11)).foregroundColor(.secondary)
                        } else {
                            Text("已设置 \(model.favorites.configuredCount)/2").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    if !model.favorites.isComplete {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("先选择两个常用时区").font(.system(size: 14, weight: .semibold))
                            Text("点击下方空位，选择你常用的两个时区。设置只保存偏好；完成后，点击卡片或使用开关切换系统时区。")
                                .font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(teal.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    ForEach(0..<2, id: \.self) { slot in favoriteRow(slot) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: model.failed ? "exclamationmark.circle" : "checkmark.shield")
                        Text(model.message ?? (model.snapshot.automatic == true
                            ? "切换需要管理员授权，并会关闭自动时区。"
                            : "切换需要 macOS 管理员授权。"))
                            .fixedSize(horizontal: false, vertical: true)
                    }.font(.system(size: 11)).foregroundColor(model.failed ? .red : .secondary)
                    Text("关闭窗口即退出 · 系统时区会继续保留").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Divider()
                Button("日期与时间设置") { openDateSettings() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(26).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .frame(minWidth: 460, idealWidth: 460, minHeight: 560, idealHeight: 630)
        .foregroundColor(ink).background(Color(red: 0.95, green: 0.96, blue: 0.95)).preferredColorScheme(.light)
        .sheet(item: $picker) { request in ZonePicker(model: model, slot: request.slot) }
    }

    @ViewBuilder private func favoriteRow(_ slot: Int) -> some View {
        if let zone = model.favorites.slots[slot] {
            let selected = model.snapshot.destination == zone
            Button { model.select(zone) } label: {
                HStack(spacing: 10) {
                    Text("\(slot + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(teal)
                        .frame(width: 27, height: 36).background(teal.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(zone.city).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(zone.offset(at: model.now) + (zone.zone.isDaylightSavingTime(for: model.now) ? " · 夏令时" : ""))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(zone.time(at: model.now)).font(.system(size: 22, design: .rounded)).monospacedDigit()
                    Image(systemName: "arrow.right").font(.system(size: 14)).foregroundColor(teal)
                }.padding(13).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("切换到\(zone.city)")
            .background(selected ? teal.opacity(0.045) : Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? teal.opacity(0.5) : Color.black.opacity(0.04)))
            .disabled(model.busy)
        } else {
            Button { picker = PickerRequest(slot: slot) } label: {
                HStack(spacing: 10) {
                    Text("\(slot + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(teal)
                        .frame(width: 27, height: 36).background(teal.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("选择常用时区 \(slot + 1)").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "plus").foregroundColor(teal)
                }.padding(13).contentShape(Rectangle())
            }.buttonStyle(.plain).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(model.busy)
        }
    }
    private var currentTime: String { format("HH:mm:ss", locale: "en_US_POSIX") }
    private var currentDate: String { format("M月d日 EEEE", locale: "zh_CN") }
    private func format(_ pattern: String, locale: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = TimeZone(identifier: model.snapshot.identifier) ?? .current
        formatter.dateFormat = pattern
        return formatter.string(from: model.now)
    }
}

// Keep catalog results and the reference date stable while the live clock updates.
final class PickerCatalog: ObservableObject {
    private let referenceDate: Date
    @Published private(set) var groups: [ZoneCatalog.OffsetGroup]
    init() {
        let date = Date()
        referenceDate = date
        groups = ZoneCatalog.groups("", at: date)
    }
    func search(_ query: String) { groups = ZoneCatalog.groups(query, at: referenceDate) }
}

struct ZonePicker: View {
    @ObservedObject var model: AppModel
    let slot: Int
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var error: String?
    // Stable data and date while choosing; the live clock cannot reorder rows.
    @StateObject private var catalog = PickerCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("设置常用时区 \(slot + 1)").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("按当前 UTC 偏移从小到大排列。选择仅保存偏好，不会更改系统时区。")
                .font(.system(size: 12)).foregroundColor(.secondary)
            TextField("搜索城市、IANA 标识或 UTC 偏移", text: $search)
                .textFieldStyle(.roundedBorder).accessibilityLabel("搜索全球时区")
            HStack {
                Text("\(catalog.groups.reduce(0) { $0 + $1.zones.count }) 个时区").font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                if let error { Text(error).font(.system(size: 11)).foregroundColor(.red) }
            }
            // Avoid native List's floating section headers, which can shift the
            // initial viewport during sheet presentation on macOS.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(catalog.groups) { group in
                        Text(group.title)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(teal)
                            .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 8)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.zones) { zone in
                            let selected = model.favorites.slots[slot] == zone
                            let usedByOther = model.favorites.slots[1 - slot] == zone
                            Button {
                                if model.saveFavorite(slot: slot, destination: zone) { dismiss() }
                                else { error = "此时区已在另一个常用时区中" }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(zone.city).font(.system(size: 13, weight: .medium))
                                        Text(zone.rawValue).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if usedByOther { Text("另一常用时区").font(.system(size: 10)).foregroundColor(.secondary) }
                                    Text(group.title).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                }.padding(8).contentShape(Rectangle())
                                    .background(selected ? teal.opacity(0.05) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? teal.opacity(0.5) : .clear))
                            }.buttonStyle(.plain).accessibilityLabel("选择\(zone.city)，\(zone.rawValue)")
                            Divider().padding(.horizontal, 8)
                        }
                    }
                }.padding(.horizontal, 6).padding(.bottom, 12)
            }
            .id(search)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                if catalog.groups.isEmpty { Text("未找到时区，请尝试城市英文名或 IANA 标识。").foregroundColor(.secondary).font(.system(size: 12)) }
            }
        }
        .padding(22).frame(width: 570, height: 590).preferredColorScheme(.light)
        .onChange(of: search) { query in catalog.search(query) }
    }
}

func openDateSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension")!)
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingController(rootView: TimezoneView(model: model))
        window = NSWindow(contentViewController: host)
        window.delegate = self
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "TZswitch"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.contentMinSize = NSSize(width: 460, height: 560)
        window.setContentSize(NSSize(width: 460, height: model.favorites.isComplete ? 630 : 730))
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("TimezoneSwitchWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "显示TZswitch", action: #selector(showWindow), keyEquivalent: "0")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出TZswitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    @objc private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    private func canQuit() -> Bool {
        guard !model.busy else {
            model.message = "正在切换时区，请完成或取消系统授权后再退出。"
            return false
        }
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { canQuit() }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        canQuit() ? .terminateNow : .terminateCancel
    }

    // The timezone is stored by macOS. Launching and quitting only read it;
    // only explicit select actions above are allowed to run a switching script.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct TimezoneSwitchApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
