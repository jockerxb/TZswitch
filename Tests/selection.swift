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
            check(model.busy && model.picker == nil && system.count == 0,
                  name + "：先关闭选择面板，防止重复点击")
            check(model.favorites.slots == [.lusaka, .losAngeles, nil] && defaults.stringArray(forKey: FavoriteZones.key) == old,
                  name + "：授权前不修改界面和本地城市")
            model.pickerDidDismiss()
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
            check(!model.busy, name + "：切换流程正常结束")
            let expected: [Destination?] = commits ? [target, .losAngeles, nil] : [.lusaka, .losAngeles, nil]
            check(model.favorites.slots == expected, name + "：界面城市正确")
            check(FavoriteZones(defaults: defaults).slots == expected, name + "：重启后读取的城市正确")
            check(model.snapshot.identifier == (commits ? target.rawValue : original.identifier), name + "：系统回读正确")
            let executions = system.count
            model.pickerDidDismiss()
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
            model.pickerDidDismiss()
            let deadline = Date().addingTimeInterval(3)
            while model.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
            let expected: [Destination?] = succeeds ? [target, nil, nil] : [nil, nil, nil]
            check(!model.busy && model.favorites.slots == expected && FavoriteZones(defaults: defaults).slots == expected,
                  succeeds ? "首次设置成功后保存一个城市" : "首次设置取消后仍为空")
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
        single.pickerDidDismiss()
        let deadline = Date().addingTimeInterval(3)
        while single.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
        check(!single.busy && !single.favorites.needsSetup && single.favorites.slots == [.lusaka, nil, nil]
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
        model.pickerDidDismiss()
        check(!model.busy && system.count == 0 && model.favorites.slots == [.lusaka, .losAngeles, nil],
              "选择已生效的城市直接保存，无需再次授权")
        check(FavoriteZones(defaults: defaults).slots == [.lusaka, .losAngeles, nil], "已生效城市的保存可被下次启动读取")
        model.editFavorite(0)
        model.picker = nil
        model.pickerDidDismiss()
        check(!model.busy && system.count == 0 && model.favorites.slots == [.lusaka, .losAngeles, nil], "仅关闭面板不发起切换")
        model.editFavorite(0)
        check(!model.chooseFavorite(slot: 0, destination: .losAngeles) && !model.busy && system.count == 0,
              "重复城市不会覆盖原值或请求授权")
        defaults.removePersistentDomain(forName: suite)

        let thirdSuite = suitePrefix + ".third"
        let thirdDefaults = UserDefaults(suiteName: thirdSuite)!
        thirdDefaults.set(old, forKey: FavoriteZones.previousKey)
        let thirdSystem = StubSystem(initial: original,
            result: CommandResult(status: 0, output: "VERIFIED:America/New_York"), after: applied)
        let third = AppModel(defaults: thirdDefaults, snapshotReader: { thirdSystem.read() },
            authorizer: { thirdSystem.run($0) }, compiler: { _ in true })
        third.editFavorite(2)
        check(third.chooseFavorite(slot: 2, destination: target), "第三个城市可从同一选择流程添加")
        check(third.favorites.slots == [.lusaka, .losAngeles, nil], "第三个城市授权前不提交")
        third.pickerDidDismiss()
        let thirdDeadline = Date().addingTimeInterval(3)
        while third.busy && Date() < thirdDeadline { try? await Task.sleep(nanoseconds: 1_000_000) }
        check(!third.busy && thirdSystem.count == 1 && third.favorites.slots == [.lusaka, .losAngeles, target],
              "第三个城市授权成功后提交且保留原两城")
        check(FavoriteZones(defaults: thirdDefaults).slots == [.lusaka, .losAngeles, target], "第三个城市持久化可被重启读取")
        thirdDefaults.removePersistentDomain(forName: thirdSuite)

        let clockSuite = suitePrefix + ".clock"
        let clockDefaults = UserDefaults(suiteName: clockSuite)!
        let clockSystem = StubSystem(initial: original,
            result: CommandResult(status: 0, output: "VERIFIED:America/New_York"), after: applied)
        let clock = AppModel(defaults: clockDefaults, snapshotReader: { clockSystem.read() },
            authorizer: { clockSystem.run($0) }, compiler: { _ in true })
        let shanghai = Destination(rawValue: "Asia/Shanghai")!
        clock.setBackupDisplay(true)
        check(!clock.backupClock.enabled && clock.backupClock.destination == nil && clock.picker != nil,
              "开启前必须手动选城市，不能默认使用系统或常用城市")
        clock.picker = nil
        clock.pickerDidDismiss()
        check(!clock.backupClock.enabled && clockSystem.count == 0, "取消首次备用选择保持关闭且不授权")
        clock.setBackupDisplay(true)
        clock.chooseBackup(.lusaka)
        clock.pickerDidDismiss()
        check(clock.backupClock.enabled && clock.backupClock.destination == .lusaka, "手动选城后才开启备用显示")
        check(clockSystem.count == 0 && clock.snapshot.identifier == original.identifier && clock.favorites.needsSetup,
              "开启备用显示不请求授权、不修改系统或常用城市")
        clock.editBackup()
        clock.chooseBackup(shanghai)
        clock.pickerDidDismiss()
        check(clockSystem.count == 0 && clock.picker == nil && clock.backupClock.destination == shanghai,
              "更换备用城市只保存显示设置，关闭选择面板也不发起授权")
        clock.select(target)
        let clockDeadline = Date().addingTimeInterval(3)
        while clock.busy && Date() < clockDeadline { try? await Task.sleep(nanoseconds: 1_000_000) }
        clock.refresh()
        check(clock.snapshot.identifier == target.rawValue && clock.backupClock.destination == shanghai && clock.backupClock.enabled,
              "切换系统时区后备用时区保持不变")
        let restoredClock = AppModel(defaults: clockDefaults, snapshotReader: { clockSystem.read() },
            authorizer: { clockSystem.run($0) }, compiler: { _ in true })
        check(restoredClock.backupClock == clock.backupClock, "重新启动可恢复备用城市和显示开关")
        restoredClock.setBackupDisplay(false)
        check(!BackupClockSettings(defaults: clockDefaults).enabled
              && BackupClockSettings(defaults: clockDefaults).destination == shanghai && clockSystem.count == 1,
              "关闭备用显示不丢失城市、不执行额外系统修改")
        restoredClock.setBackupDisplay(true)
        check(!restoredClock.backupClock.enabled && restoredClock.picker != nil, "再次开启也先请求用户选择城市")
        restoredClock.picker = nil
        restoredClock.pickerDidDismiss()
        check(!restoredClock.backupClock.enabled && clockSystem.count == 1, "取消再次开启不会恢复旧时钟或修改系统")
        restoredClock.setBackupDisplay(true)
        restoredClock.chooseBackup(.losAngeles)
        restoredClock.pickerDidDismiss()
        check(restoredClock.backupClock.enabled && restoredClock.backupClock.destination == .losAngeles
              && clockSystem.count == 1, "再次手动选择后启用新备用城市，无额外系统授权")
        clockDefaults.removePersistentDomain(forName: clockSuite)
        exit(failures == 0 ? 0 : 1)
    }
}
