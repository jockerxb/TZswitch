import AppKit
import Combine

@MainActor final class AppModel: ObservableObject {
    @Published var snapshot: SystemSnapshot
    @Published var now = Date()
    @Published var busy = false
    @Published var message: String?
    @Published var failed = false
    @Published var favorites: FavoriteZones
    @Published private(set) var backupClock: BackupClockSettings
    @Published var picker: PickerRequest?
    let authorizationReady: Bool
    private var lastVerified: Destination?
    private var pendingFavorite: (destination: Destination, favorites: FavoriteZones)?
    private let defaults: UserDefaults
    private let snapshotReader: () -> SystemSnapshot
    private let authorizer: @Sendable (String) -> CommandResult
    private let compiler: (String) -> Bool
    private var timer: Timer?

    init(defaults: UserDefaults = .standard,
         snapshotReader: @escaping () -> SystemSnapshot = SystemSnapshot.read,
         authorizer: @escaping @Sendable (String) -> CommandResult = { SystemCommands.runAuthorized($0) },
         compiler: @escaping (String) -> Bool = { script in
             var error: NSDictionary?
             return NSAppleScript(source: SystemCommands.appleScript(for: script))?.compileAndReturnError(&error) == true
         }) {
        self.defaults = defaults
        self.snapshotReader = snapshotReader
        self.authorizer = authorizer
        self.compiler = compiler
        snapshot = snapshotReader()
        favorites = FavoriteZones(defaults: defaults)
        backupClock = BackupClockSettings(defaults: defaults)
        authorizationReady = compiler(SystemCommands.switchScript(to: .lusaka))
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
        snapshot = snapshotReader()
        if let expected = lastVerified, !busy,
           snapshot.destination?.isSameLocation(as: expected) != true || snapshot.automatic == true {
            failed = true
            message = "系统设置已被其他程序更改，请重新选择时区。"
            lastVerified = nil
        }
    }

    func editFavorite(_ slot: Int) {
        guard !busy, picker == nil, favorites.slots.indices.contains(slot) else { return }
        picker = .favorite(slot)
    }

    func isAddingFavorite(_ slot: Int) -> Bool {
        !favorites.needsSetup && favorites.slots.indices.contains(slot) && favorites.slots[slot] == nil
    }

    @discardableResult func removeFavorite(_ slot: Int) -> Bool {
        guard !busy, let updated = favorites.removing(slot: slot),
              let removed = favorites.slots[slot] else { return false }
        commitFavorite(updated)
        picker = nil
        failed = false
        message = "已删除\(removed.city)，系统时区未更改。"
        return true
    }

    func editBackup() {
        guard !busy, picker == nil else { return }
        picker = .backup(enableAfterSelection: false)
    }

    func setBackupDisplay(_ enabled: Bool) {
        guard !busy else { return }
        if enabled {
            guard picker == nil else { return }
            if let destination = backupClock.destination {
                setBackupClock(enabled: true, destination: destination)
            } else {
                // Only first-time setup needs a city choice. Hiding a clock
                // keeps that choice, so enabling it can resume immediately.
                picker = .backup(enableAfterSelection: true)
            }
        } else {
            setBackupClock(enabled: false, destination: backupClock.destination)
        }
    }

    private func setBackupClock(enabled: Bool, destination: Destination?) {
        guard !busy else { return }
        let settings = BackupClockSettings(enabled: enabled, destination: destination)
        settings.persist(defaults: defaults)
        backupClock = settings
    }

    func chooseBackup(_ destination: Destination) {
        guard !busy, case .backup(let enableAfterSelection) = picker else { return }
        setBackupClock(enabled: enableAfterSelection || backupClock.enabled, destination: destination)
        picker = nil
    }

    func chooseFavorite(slot: Int, destination: Destination) -> Bool {
        guard !busy, case .favorite(let requestedSlot) = picker, requestedSlot == slot else { return false }
        guard let updated = favorites.replacing(slot: slot, with: destination) else {
            failed = true
            message = "常用时区请选择不同的城市。"
            return false
        }
        failed = false
        // Adding another favorite manages the list only. First-time setup and
        // replacing an existing city keep the explicit switch flow below.
        if isAddingFavorite(slot) {
            commitFavorite(updated)
            message = "已添加\(destination.city)，点击卡片即可切换。"
            picker = nil
            return true
        }
        pendingFavorite = (destination, updated)
        busy = true
        message = "正在准备切换至\(destination.city)…"
        picker = nil
        return true
    }

    func pickerDidDismiss() {
        // Start authorization only after the picker has fully dismissed. Drain
        // the request first so closing/reopening a picker cannot replay it.
        guard let target = pendingFavorite else { return }
        pendingFavorite = nil
        busy = false
        select(target.destination, favoriteChange: target.favorites)
    }

    private func commitFavorite(_ change: FavoriteZones?) {
        guard let change else { return }
        change.persist(defaults: defaults)
        favorites = change
    }

    func select(_ target: Destination, favoriteChange: FavoriteZones? = nil) {
        guard !busy else { return }
        guard snapshot.destination?.isSameLocation(as: target) != true || snapshot.automatic != false else {
            commitFavorite(favoriteChange)
            failed = false
            message = "系统已使用\(target.city)时区。"
            return
        }
        let script = SystemCommands.switchScript(to: target)
        guard compiler(script) else {
            failed = true
            message = "系统授权组件不可用，请重新打开 App 后重试。"
            return
        }
        busy = true
        failed = false
        message = "请在 macOS 弹窗中授权…"
        let authorize = authorizer
        Task {
            let result = await Task.detached { authorize(script) }.value
            snapshot = snapshotReader()
            busy = false
            switch SwitchOutcome.evaluate(result: result, snapshot: snapshot, target: target) {
            case .success:
                commitFavorite(favoriteChange)
                lastVerified = target
                message = "已切换至\(target.city)"
            case .cancelled:
                message = "已取消，保留原城市与系统时区。"
            case .failure(let reason):
                failed = true
                message = reason
            }
        }
    }
}

enum PickerRequest: Identifiable {
    case favorite(Int)
    case backup(enableAfterSelection: Bool)

    var id: String {
        switch self {
        case .favorite(let slot): return "favorite-\(slot)"
        case .backup: return "backup"
        }
    }
    var title: String {
        switch self {
        case .favorite(let slot): return "设置常用时区 \(slot + 1)"
        case .backup: return "设置备用时区"
        }
    }
}
