import Foundation

@main struct StatusItemPositionTests {
    static func main() {
        let suite = "TZswitch.StatusItemPositionTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var failures = 0
        func check(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL") \(name)")
            if !value { failures += 1 }
        }

        let position = StatusItemPosition(autosaveName: "clock", defaults: defaults)
        position.restore()
        check(defaults.object(forKey: position.preferredKey) == nil, "首次开启不强加菜单栏位置")
        defaults.set(193.5, forKey: position.preferredKey)
        position.hide { defaults.removeObject(forKey: position.preferredKey) }
        check(defaults.double(forKey: position.preferredKey) == 193.5, "隐藏菜单项清空原生记录后恢复用户位置")
        for _ in 0..<3 {
            position.hide { defaults.removeObject(forKey: position.preferredKey) }
            position.restore()
        }
        check(defaults.double(forKey: position.preferredKey) == 193.5, "多次开关不累积位置偏移")

        defaults.set(452, forKey: position.preferredKey)
        position.restore()
        position.hide { defaults.removeObject(forKey: position.preferredKey) }
        check(defaults.double(forKey: position.preferredKey) == 452, "重新拖动后使用新位置而非旧缓存")
        defaults.removeObject(forKey: position.preferredKey)
        let reopened = StatusItemPosition(autosaveName: "clock", defaults: UserDefaults(suiteName: suite)!)
        reopened.restore()
        check(defaults.double(forKey: position.preferredKey) == 452, "重启后可从独立记录恢复最后一次位置")

        defaults.set(0, forKey: position.preferredKey)
        position.hide { defaults.removeObject(forKey: position.preferredKey) }
        check(defaults.object(forKey: position.preferredKey) != nil && defaults.double(forKey: position.preferredKey) == 0,
              "最右侧零位置同样可恢复")
        let other = StatusItemPosition(autosaveName: "other", defaults: defaults)
        other.restore()
        check(defaults.object(forKey: other.preferredKey) == nil, "只恢复本菜单项，不影响其他图标")
        exit(failures == 0 ? 0 : 1)
    }
}
