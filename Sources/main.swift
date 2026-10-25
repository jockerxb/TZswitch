import AppKit
import Combine
import CoreServices
import SwiftUI


private let ink = Color(red: 0.07, green: 0.10, blue: 0.17)
private let teal = Color(red: 0.08, green: 0.45, blue: 0.43)
private let headerButtonHeight: CGFloat = 30
// Older supported macOS versions may not include the translate symbol.
private let languageSymbolName = NSImage(systemSymbolName: "translate", accessibilityDescription: nil) != nil
    ? "translate" : "character.bubble"

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
    private var language: AppLanguage { model.language }
    var onContentHeightChange: (CGFloat) -> Void = { _ in }
    @State private var showingLanguages = false

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
                        Text(language.text(.tagline)).font(.system(size: 12)).foregroundColor(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        languageButton
                        Link(destination: URL(string: "https://github.com/jockerxb/TZswitch")!) {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("GitHub")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).frame(height: headerButtonHeight)
                            .background(teal.opacity(0.08), in: Capsule())
                            .contentShape(Capsule())
                            .fixedSize()
                        }
                        .buttonStyle(.plain).foregroundColor(teal)
                        .accessibilityLabel(language.text(.openGitHub))
                        .help(language.text(.gitHubHelp))
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(teal).frame(width: 6, height: 6)
                        Text(language.text(.currentTimezone)).font(.system(size: 11, weight: .medium))
                    }.foregroundColor(.secondary)
                    Text(currentTime).font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(model.snapshot.destination.map { $0.displayName(in: language) } ?? model.snapshot.identifier)
                            .font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
                        Text(model.snapshot.destination?.offset(at: model.now) ?? model.snapshot.identifier)
                            .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).fixedSize()
                        Text(currentDate).font(.system(size: 11)).foregroundColor(.secondary).fixedSize()
                            .padding(.leading, 4)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(20).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 19))

                VStack(spacing: 10) {
                    HStack {
                        Text(language.text(.favorites)).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        if model.busy { ProgressView().controlSize(.small) }
                    }
                    if model.favorites.needsSetup {
                        Text(language.text(.setupHint))
                            .font(.system(size: 12)).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if model.favorites.needsSetup {
                        favoriteRow(0)
                    } else {
                        ForEach(model.favorites.configuredSlots, id: \.self) { slot in favoriteRow(slot) }
                        if let slot = model.favorites.nextAvailableSlot {
                            HStack(spacing: 0) {
                                Button { model.editFavorite(slot) } label: {
                                    Label(language.text(.addFavorite), systemImage: "plus")
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.vertical, 6).padding(.trailing, 10)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).foregroundColor(teal).disabled(model.busy)
                                    .fixedSize()
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                backupClockSection
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: model.failed ? "exclamationmark.circle" : "checkmark.shield")
                    if model.failed || model.busy {
                        // Authorization and error details remain fully readable.
                        Text(model.message ?? language.text(.working)).fixedSize(horizontal: false, vertical: true)
                    } else {
                        let status = model.message ?? (model.snapshot.automatic == true
                            ? language.text(.adminAutomatic)
                            : language.text(.adminRequired))
                        let closing = model.backupClock.enabled ? language.text(.closeKeepClock) : language.text(.closeQuit)
                        Text(status + " · " + closing)
                            .lineLimit(1).minimumScaleFactor(0.85)
                            .help(status + " · " + closing + language.text(.timezoneStaysHelp))
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

    private var languageButton: some View {
        Button { showingLanguages.toggle() } label: {
            Image(systemName: languageSymbolName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 16)
                .padding(.horizontal, 12).frame(height: headerButtonHeight)
                .background(teal.opacity(0.08), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).foregroundColor(teal)
        .accessibilityLabel(language.text(.changeLanguage))
        .help(language.text(.changeLanguage))
        .popover(isPresented: $showingLanguages, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                ForEach(AppLanguage.allCases, id: \.self) { option in
                    Button {
                        model.setLanguage(option)
                        showingLanguages = false
                    } label: {
                        HStack {
                            Text(option.name)
                            Spacer()
                            if option == language {
                                Image(systemName: "checkmark").foregroundColor(teal)
                            }
                        }
                        .font(.system(size: 14)).padding(10)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(6).frame(width: 160).foregroundColor(ink)
            .preferredColorScheme(.light)
        }
    }

    private var backupClockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text(.backupClock)).font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle(language.text(.backupClock), isOn: Binding(get: { model.backupClock.enabled }, set: model.setBackupDisplay))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .accessibilityLabel(language.text(.showBackupClock)).disabled(model.busy)
            }
            if model.backupClock.enabled, let zone = model.backupClock.destination {
                Button { model.editBackup() } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(zone.displayName(in: language)).font(.system(size: 13, weight: .medium))
                            Text(zone.offset(at: model.now)).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(model.backupClock.title(at: model.now, language: language) ?? "").font(.system(size: 15)).monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundColor(teal).disabled(model.busy)
                    .accessibilityLabel(language.text(.changeBackupCity, zone.displayName(in: language)))
            }
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
                            Text(zone.displayName(in: language)).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            Text(zone.offset(at: model.now) + (zone.zone.isDaylightSavingTime(for: model.now) ? language.text(.dstSuffix) : ""))
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(zone.time(at: model.now)).font(.system(size: 22, design: .rounded)).monospacedDigit()
                    }.padding(.leading, 13).padding(.vertical, 13).padding(.trailing, 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(language.text(.switchTo, zone.displayName(in: language)))
                Button { model.editFavorite(slot) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundColor(teal)
                        .frame(width: 44, height: 62).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel(language.text(.changeFavoriteNumber, slot + 1))
                .help(language.text(.changeFavorite))
            }
            .background(selected ? teal.opacity(0.045) : Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? teal.opacity(0.5) : Color.black.opacity(0.04)))
            .disabled(model.busy)
            .contextMenu {
                if model.favorites.configuredCount > 1 {
                    Button(role: .destructive) { model.removeFavorite(slot) } label: {
                        Label(language.text(.deleteCity, zone.displayName(in: language)), systemImage: "trash")
                    }.disabled(model.busy)
                }
            }
        } else {
            let prompt = language.text(.chooseFavoriteCity)
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
    private var currentDate: String { format(language.datePattern, locale: language.locale.identifier) }
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
    func summary(in language: AppLanguage) -> String {
        language.catalogSummary(offsets: groups.count, cities: groups.reduce(0) { $0 + $1.zones.count })
    }
    init() {
        let date = Date()
        referenceDate = date
        groups = ZoneCatalog.groups("", at: date)
    }
    func search(_ query: String, language: AppLanguage) { groups = ZoneCatalog.groups(query, at: referenceDate, language: language) }
}

private struct OffsetPositions: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct ZonePicker: View {
    @ObservedObject var model: AppModel
    private var language: AppLanguage { model.language }
    let request: PickerRequest
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var error: AppText?
    @State private var visibleOffset: Int?
    // Stable data and date while choosing; the live clock cannot reorder rows.
    @StateObject private var catalog = PickerCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(request.title(in: language)).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { dismiss() } label: { Label(language.text(.close), systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction).accessibilityLabel(language.text(.closePicker))
            }
            Text(pickerExplanation)
                .font(.system(size: 12)).foregroundColor(.secondary)
            TextField(language.text(.searchPlaceholder), text: $search)
                .textFieldStyle(.roundedBorder).accessibilityLabel(language.text(.searchGlobal))
            HStack {
                Text(catalog.summary(in: language)).font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                if let error { Text(language.text(error)).font(.system(size: 11)).foregroundColor(.red) }
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
                                        .accessibilityLabel(language.text(.jumpTo, group.title))
                                        .help(language.text(.jumpTo, group.title))
                                    }
                                }
                            }
                        }.frame(width: 58)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if case .favorite(let slot) = request,
               model.favorites.configuredCount > 1, model.favorites.slots[slot] != nil {
                Divider()
                HStack {
                    Button(role: .destructive) { model.removeFavorite(slot) } label: {
                        Label(language.text(.deleteFavorite), systemImage: "trash")
                    }
                    .disabled(model.busy).accessibilityLabel(language.text(.deleteFavorite))
                    Spacer()
                    Text(language.text(.removeFavoriteHint))
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
        }
        .padding(22).frame(width: 570, height: 590).preferredColorScheme(.light)
        .onAppear { catalog.search(search, language: language) }
        .onChange(of: model.language) { value in catalog.search(search, language: value) }
        .onChange(of: search) { query in
            visibleOffset = nil
            catalog.search(query, language: language)
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
                                        error = .duplicateCity
                                    }
                                case .backup:
                                    model.chooseBackup(zone)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(zone.displayName(in: language)).font(.system(size: 13, weight: .medium))
                                        Text(zone.rawValue).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if usedByOther { Text(language.text(.addedLabel)).font(.system(size: 10)).foregroundColor(.secondary) }
                                    Text(group.title).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                }.padding(8).contentShape(Rectangle())
                                    .background(selected ? teal.opacity(0.05) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? teal.opacity(0.5) : .clear))
                            }.buttonStyle(.plain).accessibilityLabel(language.text(.chooseCityIdentifier, zone.displayName(in: language), zone.rawValue))
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
                Text(language.text(.noResults))
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 16)
            }
        }
    }

    private var pickerExplanation: String {
        switch request {
        case .favorite(let slot):
            return model.isAddingFavorite(slot)
                ? language.text(.addOnlyHint)
                : language.text(.switchCityHint)
        case .backup: return language.text(.backupOnlyHint)
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
    private var languageObserver: AnyCancellable?
    private var clockMenuLanguage: AppLanguage?
    private var statusItem: NSStatusItem?
    private let statusItemPosition = StatusItemPosition(autosaveName: "TZswitchBackupClock")
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
        clockObserver = model.$backupClock.combineLatest(model.$now, model.$language)
            .sink { [weak self] settings, date, language in self?.updateStatusClock(settings, at: date, language: language) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        languageObserver = model.$language.sink { [weak self] language in
            self?.updateApplicationMenu(in: language)
        }
        windowReady = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fitWindow(to: self.measuredContentHeight)
        }
    }

    private func updateApplicationMenu(in language: AppLanguage) {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: language.text(.showAppMenu), action: #selector(showWindow), keyEquivalent: "0")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: language.text(.quitAppMenu), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
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

    private func updateStatusClock(_ settings: BackupClockSettings, at date: Date, language: AppLanguage) {
        guard let title = settings.title(at: date, language: language), let zone = settings.destination else {
            if let statusItem, statusItem.isVisible {
                statusItemPosition.hide { statusItem.isVisible = false }
            }
            menuClock = nil
            clockMenuLanguage = nil
            return
        }
        if statusItem == nil {
            statusItemPosition.restore()
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.autosaveName = "TZswitchBackupClock"
            statusItem?.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
        if statusItem?.isVisible == false {
            statusItemPosition.restore()
            statusItem?.isVisible = true
        }
        if statusItem?.button?.title != title { statusItem?.button?.title = title }
        statusItem?.button?.toolTip = "TZswitch · \(zone.displayName(in: language)) · \(zone.offset(at: date))\n" + language.text(.moveClockHelp)
        statusItem?.button?.setAccessibilityLabel(language.text(.backupAccessibility, zone.displayName(in: language), title))
        // Rebuilding an open menu on every clock tick would interrupt clicks.
        if menuClock != settings || clockMenuLanguage != language {
            let menu = NSMenu()
            menu.addItem(withTitle: language.text(.backupTimezoneMenu, zone.displayName(in: language)), action: nil, keyEquivalent: "")
            menu.addItem(.separator())
            let show = menu.addItem(withTitle: language.text(.openApp), action: #selector(showWindow), keyEquivalent: "")
            show.target = self
            let edit = menu.addItem(withTitle: language.text(.changeBackupMenu), action: #selector(editBackupClock), keyEquivalent: "")
            edit.target = self
            menu.addItem(.separator())
            let stop = menu.addItem(withTitle: language.text(.stopClockMenu, zone.displayName(in: language)), action: #selector(stopBackupClock), keyEquivalent: "")
            stop.target = self
            statusItem?.menu = menu
            menuClock = settings
            clockMenuLanguage = language
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
            model.showMessage(.quitWhileSwitching)
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

    func applicationWillTerminate(_ notification: Notification) {
        statusItemPosition.remember()
    }
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
