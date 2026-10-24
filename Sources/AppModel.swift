import AppKit
import Combine

@MainActor final class AppModel: ObservableObject {
    @Published var snapshot: SystemSnapshot
    @Published var now = Date()
    @Published var busy = false
    @Published var message: String?
    @Published var failed = false
    @Published var favorites: FavoriteZones
    @Published var favoritePicker: PickerRequest?
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
        guard !busy, favoritePicker == nil, favorites.slots.indices.contains(slot) else { return }
        favoritePicker = PickerRequest(slot: slot)
    }

    func chooseFavorite(slot: Int, destination: Destination) -> Bool {
        guard !busy else { return false }
        guard let updated = favorites.replacing(slot: slot, with: destination) else {
            failed = true
            message = "两个常用时区请选择不同的时区。"
            return false
        }
        failed = false
        pendingFavorite = (destination, updated)
        busy = true
        message = "正在准备切换至\(destination.city)…"
        favoritePicker = nil
        return true
    }

    func favoritePickerDidDismiss() {
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

struct PickerRequest: Identifiable {
    let slot: Int
    var id: Int { slot }
}
