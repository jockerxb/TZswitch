import AppKit
import SwiftUI


private let ink = Color(red: 0.07, green: 0.10, blue: 0.17)
private let teal = Color(red: 0.08, green: 0.45, blue: 0.43)

private enum WindowLayout {
    static let width: CGFloat = 460
    static let minimumHeight: CGFloat = 480
    static let standardHeight: CGFloat = 510
    static let setupHeight: CGFloat = 540
    static let revision = 2
}


struct TimezoneView: View {
    @ObservedObject var model: AppModel

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
                        if !model.favorites.isComplete {
                            Text("已设置 \(model.favorites.configuredCount)/2").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                    if !model.favorites.isComplete {
                        Text(model.favorites.configuredCount == 0
                             ? "点击 1 和 2，选择常用城市"
                             : "再选一个城市，就可以开始切换了")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(0..<2, id: \.self) { slot in favoriteRow(slot) }
                }
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: model.failed ? "exclamationmark.circle" : "checkmark.shield")
                    if model.failed || model.busy {
                        // Authorization and error details remain fully readable.
                        Text(model.message ?? "正在处理…").fixedSize(horizontal: false, vertical: true)
                    } else {
                        let status = model.message ?? (model.snapshot.automatic == true
                            ? "切换需管理员授权并关闭自动时区"
                            : "切换需管理员授权")
                        Text(status + " · 关闭即退出，时区保留")
                            .lineLimit(1).minimumScaleFactor(0.85)
                            .help(status + " · 关闭窗口即退出，系统时区会继续保留")
                    }
                }.font(.system(size: 10)).foregroundColor(model.failed ? .red : .secondary)

            }
            .padding(26).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .frame(minWidth: WindowLayout.width, idealWidth: WindowLayout.width,
               minHeight: WindowLayout.minimumHeight, idealHeight: WindowLayout.standardHeight)
        .foregroundColor(ink).background(Color(red: 0.95, green: 0.96, blue: 0.95)).preferredColorScheme(.light)
        .sheet(item: $model.favoritePicker, onDismiss: model.favoritePickerDidDismiss) { request in
            ZonePicker(model: model, slot: request.slot)
        }
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
            Button { model.editFavorite(slot) } label: {
                HStack(spacing: 10) {
                    Text("\(slot + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(teal)
                        .frame(width: 27, height: 36).background(teal.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("点击设置常用城市\(slot + 1)")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(teal)
                    Spacer()
                    Image(systemName: "plus").foregroundColor(teal)
                }.padding(13).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("点击设置常用城市\(slot + 1)")
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
    let slot: Int
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var error: String?
    @State private var visibleOffset: Int?
    // Stable data and date while choosing; the live clock cannot reorder rows.
    @StateObject private var catalog = PickerCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("设置常用时区 \(slot + 1)").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { dismiss() } label: { Label("关闭", systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction).accessibilityLabel("关闭时区选择")
            }
            Text("选择城市后将请求 macOS 管理员授权，确认即可切换。")
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
                            let selected = model.favorites.slots[slot]?.isSameLocation(as: zone) == true
                            let usedByOther = model.favorites.slots[1 - slot]?.isSameLocation(as: zone) == true
                            Button {
                                if !model.chooseFavorite(slot: slot, destination: zone) {
                                    error = "此时区已在另一个常用时区中"
                                }
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
        let initialSize = NSSize(width: WindowLayout.width, height: model.favorites.isComplete ? WindowLayout.standardHeight : WindowLayout.setupHeight)
        window.contentMinSize = NSSize(width: WindowLayout.width, height: WindowLayout.minimumHeight)
        window.setContentSize(initialSize)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("TimezoneSwitchWindow")
        // Migrate saved geometry when the content layout changes.
        // Migrate geometry once, then preserve future user resizing as usual.
        let layoutRevisionKey = "windowLayoutRevision"
        if UserDefaults.standard.integer(forKey: layoutRevisionKey) < WindowLayout.revision {
            window.setContentSize(initialSize)
            UserDefaults.standard.set(WindowLayout.revision, forKey: layoutRevisionKey)
        }
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
