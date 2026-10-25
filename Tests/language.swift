import AppKit

@main struct LanguageTests {
    @MainActor static func main() {
        let suite = "TZswitch.LanguageTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var failures = 0
        func check(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL") \(name)")
            if !value { failures += 1 }
        }
        check(AppLanguage(defaults: defaults) == .chinese, "已有中文体验作为默认语言")
        defaults.set("unsupported", forKey: AppLanguage.key)
        check(AppLanguage(defaults: defaults) == .chinese, "非法语言设置回退到可用语言")
        defaults.removeObject(forKey: AppLanguage.key)
        let favorites = ["Africa/Lusaka", "America/Los_Angeles", ""]
        defaults.set(favorites, forKey: FavoriteZones.key)
        let shanghai = Destination(rawValue: "Asia/Shanghai")!
        let backup = BackupClockSettings(enabled: true, destination: shanghai)
        backup.persist(defaults: defaults)
        let positionKey = "NSStatusItem Preferred Position TZswitchBackupClock"
        defaults.set(193, forKey: positionKey)
        let original = SystemSnapshot(identifier: "Africa/Lusaka", automatic: false)
        let model = AppModel(defaults: defaults, snapshotReader: { original },
            authorizer: { _ in fatalError("Language selection must never request authorization") }, compiler: { _ in true })
        let newYork = Destination(rawValue: "America/New_York")!
        model.showMessage(.addedNotice, destination: newYork)
        check(model.message?.contains("纽约") == true, "中文提示显示中文城市名")
        model.setLanguage(.english)
        check(AppLanguage(defaults: defaults) == .english && model.language == .english,
              "单一语言状态持久化用户选择")
        check(model.message == "Added New York. Click its card to switch.", "切换语言即时翻译已显示的动态提示")
        check(model.snapshot.identifier == original.identifier && model.favorites.slots == [.lusaka, .losAngeles, nil]
              && model.backupClock == backup && defaults.double(forKey: positionKey) == 193,
              "切换语言不改变系统时区、常用城市、备用时钟或位置")
        let reopened = AppModel(defaults: defaults, snapshotReader: { original },
            authorizer: { _ in fatalError("Reload must not request authorization") }, compiler: { _ in true })
        check(reopened.language == .english && reopened.backupClock == backup, "重开 App 保留语言和原时钟设置")
        model.setLanguage(.chinese)
        check(model.message?.contains("纽约") == true && AppLanguage(defaults: defaults) == .chinese,
              "切回中文即时恢复动态提示并保存选择")
        check(Destination.lusaka.displayName(in: .english) == "Lusaka"
              && shanghai.displayName(in: .english) == "Beijing / Shanghai", "城市名称与当前语言一致")
        let date = ISO8601DateFormatter().date(from: "2026-10-25T21:00:00Z")!
        check(backup.title(at: date, language: .english) == "Mon 05:00"
              && backup.title(at: date, language: .chinese) == "周一 05:00", "菜单栏星期随语言切换并保留正确跨日时间")
        let groups = ZoneCatalog.groups("utc-7", at: date, language: .english)
        check(groups.allSatisfy { group in
            let names = group.zones.map { $0.displayName(in: .english) }
            return names == names.sorted { $0.compare($1, locale: AppLanguage.english.locale) == .orderedAscending }
        }, "英文城市列表在 UTC 分组内按英文名称排序")
        check(ZoneCatalog.search("北京", at: date).contains(shanghai)
              && ZoneCatalog.search("Beijing", at: date).contains(shanghai), "两种界面均支持中英文城市搜索")
        let format = try! NSRegularExpression(pattern: #"(?<!%)%(?:\d+\$)?[@df]"#)
        func placeholders(_ value: String) -> [String] {
            format.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                String(value[Range($0.range, in: value)!])
            }
        }
        for key in AppText.allCases {
            let pair = key.translations
            check(!pair.chinese.isEmpty && !pair.english.isEmpty
                  && !pair.english.unicodeScalars.contains { (0x3400...0x9fff).contains($0.value) }
                  && placeholders(pair.chinese) == placeholders(pair.english), "翻译完整且格式占位符一致：\(key)")
        }
        check(AppLanguage.english.catalogSummary(offsets: 1, cities: 1) == "1 UTC offset · 1 city",
              "英文搜索计数支持单数")
        exit(failures == 0 ? 0 : 1)
    }
}
