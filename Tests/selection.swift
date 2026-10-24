import AppKit

private final class StubSystem: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SystemSnapshot
    private var calls = 0
    private let result: CommandResult
    private let after: SystemSnapshot?
    init(initial: SystemSnapshot, result: CommandResult, after: SystemSnapshot? = nil) {
        snapshot = initial
        self.result = result
        self.after = after
    }
    func read() -> SystemSnapshot { lock.lock(); defer { lock.unlock() }; return snapshot }
    func run(_ script: String) -> CommandResult {
        lock.lock(); defer { lock.unlock() }
        calls += 1
        if let after { snapshot = after }
        return result
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
}

@main struct SelectionTests {
    @MainActor static func main() async {
        var failures = 0
        func check(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL") \(name)")
            if !value { failures += 1 }
        }
        let original = SystemSnapshot(identifier: "Africa/Lusaka", automatic: false)
        let target = Destination(rawValue: "America/New_York")!
        let applied = SystemSnapshot(identifier: target.rawValue, automatic: false)
        let old = ["Africa/Lusaka", "America/Los_Angeles"]
        let suitePrefix = "TZswitch.SelectionTests." + UUID().uuidString
        let scenarios: [(String, CommandResult, SystemSnapshot?, Bool, Bool)] = [
            ("取消授权", CommandResult(status: 1, output: "User canceled. (-128)"), nil, true, false),
            ("执行失败", CommandResult(status: 1, output: "failed"), nil, true, false),
            ("回读验证失败", CommandResult(status: 0, output: "VERIFIED:America/New_York"), nil, true, false),
            ("授权组件不可用", CommandResult(status: 0, output: ""), nil, false, false),
            ("验证成功", CommandResult(status: 0, output: "VERIFIED:America/New_York"), applied, true, true)
        ]
        for (index, scenario) in scenarios.enumerated() {
            let (name, result, after, compiles, commits) = scenario
            let suite = suitePrefix + ".\(index)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set(old, forKey: FavoriteZones.key)
            let system = StubSystem(initial: original, result: result, after: after)
            let model = AppModel(defaults: defaults, snapshotReader: { system.read() },
                authorizer: { system.run($0) }, compiler: { _ in compiles })
            model.editFavorite(0)
            check(model.chooseFavorite(slot: 0, destination: target), name + "：接受城市选择")
            check(model.busy && model.favoritePicker == nil && system.count == 0,
                  name + "：先关闭选择面板，防止重复点击")
            check(model.favorites.slots == [.lusaka, .losAngeles] && defaults.stringArray(forKey: FavoriteZones.key) == old,
                  name + "：授权前不修改界面和本地城市")
            model.favoritePickerDidDismiss()
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
            check(!model.busy, name + "：切换流程正常结束")
            let expected: [Destination?] = commits ? [target, .losAngeles] : [.lusaka, .losAngeles]
            check(model.favorites.slots == expected, name + "：界面城市正确")
            check(FavoriteZones(defaults: defaults).slots == expected, name + "：重启后读取的城市正确")
            check(model.snapshot.identifier == (commits ? target.rawValue : original.identifier), name + "：系统回读正确")
            let executions = system.count
            model.favoritePickerDidDismiss()
            check(system.count == executions && executions == (compiles ? 1 : 0), name + "：关闭回调不会重复执行")
            defaults.removePersistentDomain(forName: suite)
        }
        for succeeds in [false, true] {
            let suite = suitePrefix + ".new.\(succeeds)"
            let defaults = UserDefaults(suiteName: suite)!
            let result = succeeds ? CommandResult(status: 0, output: "VERIFIED:America/New_York")
                                  : CommandResult(status: 1, output: "(-128)")
            let system = StubSystem(initial: original, result: result, after: succeeds ? applied : nil)
            let model = AppModel(defaults: defaults, snapshotReader: { system.read() },
                authorizer: { system.run($0) }, compiler: { _ in true })
            model.editFavorite(0)
            _ = model.chooseFavorite(slot: 0, destination: target)
            model.favoritePickerDidDismiss()
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
            let expected: [Destination?] = succeeds ? [target, nil] : [nil, nil]
            check(!model.busy && model.favorites.slots == expected && FavoriteZones(defaults: defaults).slots == expected,
                  succeeds ? "首次设置成功后保存一个城市" : "首次设置取消后仍为两个空位")
            check(model.favorites.needsSetup == !succeeds && FavoriteZones(defaults: defaults).needsSetup == !succeeds,
                  succeeds ? "只设一个城市即结束引导，重启后不要求第二个" : "首次授权取消后仍显示设置指引")
            if succeeds {
                let calls = system.count
                model.select(target)
                check(!model.busy && system.count == calls, "只有一个常用城市时卡片操作可正常使用")
            }
            defaults.removePersistentDomain(forName: suite)
        }
        let optionalSuite = suitePrefix + ".optional"
        let optionalDefaults = UserDefaults(suiteName: optionalSuite)!
        optionalDefaults.set(["Africa/Lusaka", ""], forKey: FavoriteZones.key)
        let optionalSystem = StubSystem(initial: original, result: CommandResult(status: 1, output: "(-128)"))
        let single = AppModel(defaults: optionalDefaults, snapshotReader: { optionalSystem.read() },
            authorizer: { optionalSystem.run($0) }, compiler: { _ in true })
        single.editFavorite(1)
        _ = single.chooseFavorite(slot: 1, destination: target)
        single.favoritePickerDidDismiss()
        let deadline = Date().addingTimeInterval(3)
        while single.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
        check(!single.busy && !single.favorites.needsSetup && single.favorites.slots == [.lusaka, nil]
              && !FavoriteZones(defaults: optionalDefaults).needsSetup,
              "取消添加第二个城市后仍保持单城市可用状态")
        optionalDefaults.removePersistentDomain(forName: optionalSuite)
        let suite = suitePrefix + ".active"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["Asia/Tokyo", "America/Los_Angeles"], forKey: FavoriteZones.key)
        let system = StubSystem(initial: original, result: CommandResult(status: 1, output: "must not execute"))
        let model = AppModel(defaults: defaults, snapshotReader: { system.read() },
            authorizer: { system.run($0) }, compiler: { _ in true })
        model.editFavorite(0)
        _ = model.chooseFavorite(slot: 0, destination: .lusaka)
        model.favoritePickerDidDismiss()
        check(!model.busy && system.count == 0 && model.favorites.slots == [.lusaka, .losAngeles],
              "选择已生效的城市直接保存，无需再次授权")
        check(FavoriteZones(defaults: defaults).slots == [.lusaka, .losAngeles], "已生效城市的保存可被下次启动读取")
        model.editFavorite(0)
        model.favoritePicker = nil
        model.favoritePickerDidDismiss()
        check(!model.busy && system.count == 0 && model.favorites.slots == [.lusaka, .losAngeles], "仅关闭面板不发起切换")
        model.editFavorite(0)
        check(!model.chooseFavorite(slot: 0, destination: .losAngeles) && !model.busy && system.count == 0,
              "重复城市不会覆盖原值或请求授权")
        defaults.removePersistentDomain(forName: suite)
        exit(failures == 0 ? 0 : 1)
    }
}
