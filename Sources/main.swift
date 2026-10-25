import AppKit
import Combine
import CoreServices
import SwiftUI


private let ink = Color(red: 0.07, green: 0.10, blue: 0.17)
private let teal = Color(red: 0.08, green: 0.45, blue: 0.43)

private enum WindowLayout {
    static let width: CGFloat = 460
    static let minimumHeight: CGFloat = 460
    static let initialHeight: CGFloat = 620
    static let revision = 4
}

private struct ContentHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct TimezoneView: View {
    @ObservedObject var model: AppModel
    var onContentHeightChange: (CGFloat) -> Void = { _ in }

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
                        Text("随手切换，留住本地时间").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Link(destination: URL(string: "https://github.com/jockerxb/TZswitch")!) {
                        HStack(spacing: 4) {
                            Text("GitHub")
                            Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .medium))
                        }
                        .font(.system(size: 11)).padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundColor(.secondary)
                    .accessibilityLabel("打开 TZswitch GitHub 项目")
                    .help("在浏览器中查看源码、下载更新或反馈问题")
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(teal).frame(width: 6, height: 6)
                        Text("系统当前时区").font(.system(size: 11, weight: .medium))
                    }.foregroundColor(.secondary)
                    Text(currentTime).font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(model.snapshot.destination?.city ?? model.snapshot.identifier)
                            .font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
                        Text(model.snapshot.destination?.offset(at: model.now) ?? model.snapshot.identifier)
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).fixedSize()
                        Text(currentDate).font(.system(size: 11)).foregroundColor(.secondary).fixedSize()
                            .padding(.leading, 4)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(20).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 19))

                VStack(spacing: 10) {
                    HStack {
                        Text("常用时区").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if model.busy { ProgressView().controlSize(.small) }
                    }
                    if model.favorites.needsSetup {
                        Text("设置一个常用城市，即可开始使用")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if model.favorites.needsSetup {
                        favoriteRow(0)
                    } else {
                        ForEach(model.favorites.configuredSlots, id: \.self) { slot in favoriteRow(slot) }
                        if let slot = model.favorites.nextAvailableSlot {
                            Button { model.editFavorite(slot) } label: {
                                Label("添加常用时区", systemImage: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundColor(teal).disabled(model.busy)
                        }
                    }
                }
                backupClockSection
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: model.failed ? "exclamationmark.circle" : "checkmark.shield")
                    if model.failed || model.busy {
                        // Authorization and error details remain fully readable.
                        Text(model.message ?? "正在处理…").fixedSize(horizontal: false, vertical: true)
                    } else {
                        let status = model.message ?? (model.snapshot.automatic == true
                            ? "切换需管理员授权并关闭自动时区"
                            : "切换需管理员授权")
                        let closing = model.backupClock.enabled ? "关闭窗口保留备用时间" : "关闭即退出，时区保留"
                        Text(status + " · " + closing)
                            .lineLimit(1).minimumScaleFactor(0.85)
                            .help(status + " · " + closing + "；系统时区继续保留")
                    }
                }.font(.system(size: 10)).foregroundColor(model.failed ? .red : .secondary)

            }
            .padding(.horizontal, 26).padding(.top, 26).padding(.bottom, 16)
            .frame(maxWidth: 650).frame(maxWidth: .infinity)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: ContentHeight.self, value: geometry.size.height)
            })
        }
        .onPreferenceChange(ContentHeight.self, perform: onContentHeightChange)
        .frame(minWidth: WindowLayout.width, idealWidth: WindowLayout.width,
               minHeight: WindowLayout.minimumHeight, idealHeight: WindowLayout.initialHeight)
        .foregroundColor(ink).background(Color(red: 0.95, green: 0.96, blue: 0.95)).preferredColorScheme(.light)
        .sheet(item: $model.picker, onDismiss: model.pickerDidDismiss) { request in
            ZonePicker(model: model, request: request)
        }
    }

    private var backupClockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("备用时区显示").font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("备用时区显示", isOn: Binding(get: { model.backupClock.enabled }, set: model.setBackupDisplay))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .accessibilityLabel("显示备用时区时间").disabled(model.busy)
            }
            if model.backupClock.enabled, let zone = model.backupClock.destination {
                Button { model.editBackup() } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(zone.city).font(.system(size: 13, weight: .medium))
                            Text(zone.offset(at: model.now)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(model.backupClock.title(at: model.now) ?? "").font(.system(size: 15)).monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundColor(teal).disabled(model.busy)
                    .accessibilityLabel("更换备用城市：\(zone.city)")
            }
            Text(model.backupClock.enabled ? "关闭主窗口后，顶部菜单栏继续显示备用时间。" : "开启后选择城市，在顶部菜单栏查看星期和时间。")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(14).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private func favoriteRow(_ slot: Int) -> some View {
        if let zone = model.favorites.slots[slot] {
            let selected = model.snapshot.destination?.isSameLocation(as: zone) == true
            HStack(spacing: 0) {
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
                    }.padding(.leading, 13).padding(.vertical, 13).padding(.trailing, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("切换到\(zone.city)")
                Button { model.editFavorite(slot) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundColor(teal)
                        .frame(width: 44, height: 62).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("更换常用城市 \(slot + 1)")
                .help("更换常用城市")
            }
            .background(selected ? teal.opacity(0.045) : Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? teal.opacity(0.5) : Color.black.opacity(0.04)))
            .disabled(model.busy)
        } else {
            let prompt = "点击设置常用城市"
            Button { model.editFavorite(slot) } label: {
                HStack(spacing: 10) {
                    Text("\(slot + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(teal)
                        .frame(width: 27, height: 36).background(teal.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(prompt)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(teal)
                    Spacer()
                    Image(systemName: "plus").foregroundColor(teal)
                }.padding(13).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(prompt)
                .background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 14))
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
    var summary: String { "\(groups.count) 个时区 · \(groups.reduce(0) { $0 + $1.zones.count }) 个城市" }
    init() {
        let date = Date()
        referenceDate = date
        groups = ZoneCatalog.groups("", at: date)
    }
    func search(_ query: String) { groups = ZoneCatalog.groups(query, at: referenceDate) }
}

private struct OffsetPositions: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct ZonePicker: View {
    @ObservedObject var model: AppModel
    let request: PickerRequest
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var error: String?
    @State private var visibleOffset: Int?
    // Stable data and date while choosing; the live clock cannot reorder rows.
    @StateObject private var catalog = PickerCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(request.title).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { dismiss() } label: { Label("关闭", systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction).accessibilityLabel("关闭时区选择")
            }
            Text(pickerExplanation)
                .font(.system(size: 12)).foregroundColor(.secondary)
            TextField("搜索时区/城市，例如：utc9、北京", text: $search)
                .textFieldStyle(.roundedBorder).accessibilityLabel("搜索全球时区")
            HStack {
                Text(catalog.summary).font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                if let error { Text(error).font(.system(size: 11)).foregroundColor(.red) }
            }
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 8) {
                    catalogList.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !catalog.groups.isEmpty {
                        VStack(spacing: 4) {
                            Text("UTC").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                            ScrollView {
                                VStack(spacing: 1) {
                                    ForEach(catalog.groups) { group in
                                        Button {
                                            proxy.scrollTo("offset-\(group.id)", anchor: .top)
                                        } label: {
                                            Text(group.indexTitle)
                                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                .frame(maxWidth: .infinity).frame(height: 20)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain).foregroundColor(teal)
                                        .accessibilityLabel("跳转到\(group.title)")
                                        .help("跳转到\(group.title)")
                                    }
                                }
                            }
                        }.frame(width: 58)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(22).frame(width: 570, height: 590).preferredColorScheme(.light)
        .onChange(of: search) { query in
            visibleOffset = nil
            catalog.search(query)
        }
    }
    private var currentGroup: ZoneCatalog.OffsetGroup? {
        catalog.groups.first { $0.id == visibleOffset } ?? catalog.groups.first
    }
    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(teal)
            .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
    private var catalogList: some View {
        // This small catalog uses measured stacks so scrollTo has exact group
        // bounds; lazy height estimates can clip a destination header.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(catalog.groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        groupHeader(group.title).accessibilityHidden(currentGroup?.id == group.id)
                        ForEach(group.zones) { zone in
                            let selected = selectedDestination?.isSameLocation(as: zone) == true
                            let usedByOther = isUsedByOtherFavorite(zone)
                            Button {
                                switch request {
                                case .favorite(let slot):
                                    if !model.chooseFavorite(slot: slot, destination: zone) {
                                        error = "此城市已在常用时区中"
                                    }
                                case .backup:
                                    model.chooseBackup(zone)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(zone.city).font(.system(size: 13, weight: .medium))
                                        Text(zone.rawValue).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if usedByOther { Text("已添加").font(.system(size: 10)).foregroundColor(.secondary) }
                                    Text(group.title).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                }.padding(8).contentShape(Rectangle())
                                    .background(selected ? teal.opacity(0.05) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? teal.opacity(0.5) : .clear))
                            }.buttonStyle(.plain).accessibilityLabel("选择\(zone.city)，\(zone.rawValue)")
                            Divider().padding(.horizontal, 8)
                        }
                    }
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: OffsetPositions.self,
                            value: [group.id: geometry.frame(in: .named("catalogScroll")).minY])
                    })
                    .id("offset-\(group.id)")
                }
            }.padding(.horizontal, 6).padding(.bottom, 12)
        }
        .coordinateSpace(name: "catalogScroll")
        .onPreferenceChange(OffsetPositions.self) { positions in
            let offset = positions.filter { $0.value <= 1 }.max { $0.value < $1.value }?.key
            if visibleOffset != offset { visibleOffset = offset }
        }
        .id(search)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .overlay(alignment: .topLeading) {
            if let currentGroup {
                groupHeader(currentGroup.title).background(Color.white)
                    .padding(.horizontal, 6).allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            if catalog.groups.isEmpty {
                Text("未找到结果，试试 utc9、utc-8 或北京。")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 16)
            }
        }
    }

    private var pickerExplanation: String {
        switch request {
        case .favorite: return "选择城市后将请求 macOS 管理员授权，确认即可切换。"
        case .backup: return "仅用于显示备用时间，不修改系统时区，无需管理员授权。"
        }
    }

    private var selectedDestination: Destination? {
        switch request {
        case .favorite(let slot): return model.favorites.slots[slot]
        case .backup: return model.backupClock.destination
        }
    }

    private func isUsedByOtherFavorite(_ zone: Destination) -> Bool {
        guard case .favorite(let slot) = request else { return false }
        return model.favorites.contains(zone, excluding: slot)
    }

}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var window: NSWindow!
    private var clockObserver: AnyCancellable?
    private var statusItem: NSStatusItem?
    private var menuClock: BackupClockSettings?
    private var fittedContentHeight = WindowLayout.initialHeight
    private var measuredContentHeight: CGFloat = 0
    private var windowReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingController(rootView: TimezoneView(model: model, onContentHeightChange: { [weak self] height in
            self?.fitWindow(to: height)
        }))
        window = NSWindow(contentViewController: host)
        window.delegate = self
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "TZswitch"
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        let initialSize = NSSize(width: WindowLayout.width, height: WindowLayout.initialHeight)
        window.contentMinSize = NSSize(width: WindowLayout.width, height: WindowLayout.minimumHeight)
        window.setContentSize(initialSize)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("TimezoneSwitchWindow")
        // Remember the last measured default separately from a user-resized
        // window, so optional rows can fit without overriding manual sizing.
        let savedFit = UserDefaults.standard.double(forKey: "windowFittedHeight.v1")
        fittedContentHeight = savedFit > 0 ? savedFit : WindowLayout.initialHeight
        let layoutRevisionKey = "windowLayoutRevision"
        if UserDefaults.standard.integer(forKey: layoutRevisionKey) < WindowLayout.revision {
            window.setContentSize(initialSize)
            fittedContentHeight = WindowLayout.initialHeight
            UserDefaults.standard.set(WindowLayout.revision, forKey: layoutRevisionKey)
        }
        clockObserver = model.$backupClock.combineLatest(model.$now)
            .sink { [weak self] settings, date in self?.updateStatusClock(settings, at: date) }
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
        windowReady = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fitWindow(to: self.measuredContentHeight)
        }
    }

    private func fitWindow(to measuredHeight: CGFloat) {
        measuredContentHeight = measuredHeight
        guard windowReady, let window, measuredHeight > 0 else { return }
        let titleHeight = window.frame.height - (window.contentView?.frame.height ?? 0)
        let available = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let target = min(max(WindowLayout.minimumHeight, ceil(measuredHeight)), available - titleHeight)
        let previous = fittedContentHeight
        fittedContentHeight = target
        UserDefaults.standard.set(Double(target), forKey: "windowFittedHeight.v1")
        guard !window.isZoomed, !window.styleMask.contains(.fullScreen),
              let current = window.contentView?.frame.height,
              abs(current - previous) < 1, abs(target - current) >= 1 else { return }
        var frame = window.frame
        frame.size.height += target - current
        frame.origin.y -= target - current
        if let screen = window.screen { frame.origin.y = max(frame.origin.y, screen.visibleFrame.minY) }
        window.setFrame(frame, display: true)
    }

    private func updateStatusClock(_ settings: BackupClockSettings, at date: Date) {
        guard let title = settings.title(at: date), let zone = settings.destination else {
            // Keep the native item while the main interface is running so
            // toggling the clock does not discard a user-dragged position.
            if statusItem?.isVisible == true { statusItem?.isVisible = false }
            menuClock = nil
            return
        }
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.autosaveName = "TZswitchBackupClock"
            statusItem?.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        if statusItem?.isVisible == false { statusItem?.isVisible = true }
        if statusItem?.button?.title != title { statusItem?.button?.title = title }
        statusItem?.button?.toolTip = "TZswitch · \(zone.city) · \(zone.offset(at: date))\n按住 ⌘ 拖动时间可调整菜单栏位置"
        statusItem?.button?.setAccessibilityLabel("备用时间 \(zone.city) \(title)")
        // Rebuilding an open menu on every clock tick would interrupt clicks.
        if menuClock != settings {
            let menu = NSMenu()
            menu.addItem(withTitle: "备用时区：\(zone.city)", action: nil, keyEquivalent: "")
            menu.addItem(.separator())
            let show = menu.addItem(withTitle: "打开 TZswitch", action: #selector(showWindow), keyEquivalent: "")
            show.target = self
            let edit = menu.addItem(withTitle: "更换备用时区…", action: #selector(editBackupClock), keyEquivalent: "")
            edit.target = self
            menu.addItem(.separator())
            let stop = menu.addItem(withTitle: "退出\(zone.city)时间", action: #selector(stopBackupClock), keyEquivalent: "")
            stop.target = self
            statusItem?.menu = menu
            menuClock = settings
        }
    }

    @objc private func editBackupClock() {
        showWindow()
        model.editBackup()
    }

    @objc private func stopBackupClock() {
        guard !model.busy else { showWindow(); return }
        model.setBackupDisplay(false)
        // No visible main window and no clock means there is nothing to keep
        // running. This only stops the process; it never restores a timezone.
        if !window.isVisible { NSApp.terminate(nil) }
    }

    private func keepBackupClockAndHideWindow() {
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func showWindow() {
        NSApp.setActivationPolicy(.regular)
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard canQuit() else { return false }
        if model.backupClock.enabled {
            keepBackupClockAndHideWindow()
            return false
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // A logout, restart, or shutdown must be allowed to terminate the app.
        // Normal Quit / Command-Q keeps an explicitly enabled clock alive.
        let systemQuit = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
        if systemQuit { return .terminateNow }
        guard canQuit() else { return .terminateCancel }
        if model.backupClock.enabled {
            keepBackupClockAndHideWindow()
            return .terminateCancel
        }
        return .terminateNow
    }

    // The timezone is stored by macOS. Launching and quitting only read it;
    // only explicit select actions above are allowed to run a switching script.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !model.backupClock.enabled }
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
