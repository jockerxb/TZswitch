import Foundation

var failures = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() { print("PASS \(name)") }
    else { failures += 1; print("FAIL \(name)") }
}
let iso = ISO8601DateFormatter()
let winter = iso.date(from: "2026-01-15T12:00:00Z")!
let summer = iso.date(from: "2026-07-15T12:00:00Z")!
check(Destination.lusaka.offset(at: winter) == "UTC+02:00", "卢萨卡冬季 UTC+2")
check(Destination.lusaka.offset(at: summer) == "UTC+02:00", "卢萨卡夏季 UTC+2")
check(Destination.losAngeles.offset(at: winter) == "UTC−08:00", "洛杉矶冬季 UTC-8")
check(Destination.losAngeles.offset(at: summer) == "UTC−07:00", "洛杉矶夏令时 UTC-7")
let before = iso.date(from: "2026-03-08T09:59:59Z")!
let after = iso.date(from: "2026-03-08T10:00:00Z")!
check(Destination.losAngeles.time(at: before, seconds: true) == "01:59:59", "夏令时切换前")
check(Destination.losAngeles.time(at: after, seconds: true) == "03:00:00", "夏令时切换后跳过不存在的小时")
let snapshot = SystemSnapshot(identifier: Destination.lusaka.rawValue, automatic: false)
check(SwitchOutcome.evaluate(result: CommandResult(status: 0, output: "VERIFIED:Africa/Lusaka"), snapshot: snapshot, target: .lusaka) == .success, "回读与执行结果一致才成功")
check(SwitchOutcome.evaluate(result: CommandResult(status: 1, output: "User canceled. (-128)"), snapshot: snapshot, target: .losAngeles) == .cancelled, "用户取消授权")
check(SwitchOutcome.evaluate(result: CommandResult(status: 0, output: "VERIFIED:America/Los_Angeles"), snapshot: snapshot, target: .losAngeles) != .success, "执行返回成功但系统未变更时拒绝报成功")
check(SwitchOutcome.evaluate(result: CommandResult(status: 0, output: "VERIFIED:Africa/Lusaka"), snapshot: SystemSnapshot(identifier: Destination.lusaka.rawValue, automatic: true), target: .lusaka) != .success, "自动时区仍开启时拒绝报成功")

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fixtures: [(String, Destination)] = [
    ("LUN", .lusaka), ("LAX", .losAngeles),
    ("KTM", Destination(rawValue: "Asia/Kathmandu")!),
    ("CHT", Destination(rawValue: "Pacific/Chatham")!),
    ("UTC", Destination(rawValue: "Etc/UTC")!)
]
for (name, destination) in fixtures {
    try SystemCommands.switchScript(to: destination).write(to: root.appendingPathComponent("\(name).sh"), atomically: true, encoding: .utf8)
    try SystemCommands.appleScript(for: SystemCommands.switchScript(to: destination)).write(to: root.appendingPathComponent("\(name).applescript"), atomically: true, encoding: .utf8)
}
check(Destination.allCases.count > 400, "全球系统时区目录")
for id in ["Asia/Shanghai", "Europe/London", "America/New_York", "Australia/Sydney", "Asia/Kathmandu", "Pacific/Chatham", "Etc/UTC"] {
    check(Destination(rawValue: id) != nil, "支持 \(id)")
}
for invalid in ["", "Bogus/Zone", "UTC; touch /tmp/invalid", "Africa/Lusaka'", "../etc/passwd", "America/Los_Angeles\nwhoami"] {
    check(Destination(rawValue: invalid) == nil, "拒绝非法时区：\(invalid.debugDescription)")
}
check(SystemCommands.shellQuote("a'b") == "'a'\\''b'", "Shell 边界再次转义")
check(Destination(rawValue: "Asia/Kathmandu")!.offset(at: winter) == "UTC+05:45", "45 分钟偏移")
check(Destination(rawValue: "Pacific/Chatham")!.offset(at: winter) == "UTC+13:45", "跨日与夏令时偏移")
check(Destination(rawValue: "Asia/Kolkata")!.offset(at: winter) == "UTC+05:30", "30 分钟偏移")
check(ZoneCatalog.search("上海", at: winter).contains(Destination(rawValue: "Asia/Shanghai")!), "中文城市搜索")
check(ZoneCatalog.search("los angeles", at: winter).contains(.losAngeles), "英文城市搜索")
check(ZoneCatalog.search("asia/kathmandu", at: winter).contains(Destination(rawValue: "Asia/Kathmandu")!), "IANA 标识不区分大小写")
check(ZoneCatalog.search("UTC+05:45", at: winter).contains(Destination(rawValue: "Asia/Kathmandu")!), "偏移搜索")
check(ZoneCatalog.search("UTC-08:00", at: winter).contains(.losAngeles), "负偏移搜索")
check(ZoneCatalog.search("UTC−08:00", at: winter).contains(.losAngeles), "支持从界面复制的 Unicode 负号")
check(ZoneCatalog.search("  ", at: winter).count == ZoneCatalog.choices.count, "空白查询展示去重后的时区")
let honolulu = Destination(rawValue: "Pacific/Honolulu")!
let johnston = Destination(rawValue: "Pacific/Johnston")!
check(honolulu.isSameLocation(as: johnston), "兼容名称识别为同一个城市")
check(ZoneCatalog.search("檀香山", at: winter) == [honolulu], "檀香山只出现一次并使用主名称")
check(ZoneCatalog.search("Pacific/Johnston", at: winter) == [honolulu], "旧 IANA 名称仍可搜索到主条目")
let shanghai = Destination(rawValue: "Asia/Shanghai")!
for query in ["北京", "Beijing", "北京时间", "上海", "Shanghai", "Asia/Shanghai"] {
    check(ZoneCatalog.search(query, at: winter).contains(shanghai), "北京时间搜索：\(query)")
}
check(shanghai.city == "北京 / 上海", "北京搜索结果有明确城市名称")
check(ZoneCatalog.choices.contains(.lusaka), "同规则的不同城市仍保留卢萨卡")
check(ZoneCatalog.choices.contains(Destination(rawValue: "Africa/Maputo")!), "同规则的不同城市仍保留马普托")
check(ZoneCatalog.representatives.count == Destination.allCases.count, "所有旧时区名称都保留目录映射")
check(Set(ZoneCatalog.choices.map(\.catalogID)).count == ZoneCatalog.choices.count, "目录代表项不重复")
for zone in Destination.allCases {
    let representative = Destination(rawValue: zone.catalogID)!
    check(zone.ruleData != nil && zone.ruleData == representative.ruleData && zone.englishCity == representative.englishCity,
          "合并仅限同城且完整规则相同：\(zone.rawValue)")
}
check(ZoneCatalog.search("nothing-matches-this", at: winter).isEmpty, "无匹配搜索")
let suite = "TZswitch.Tests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
var pair = FavoriteZones(defaults: defaults)
check(pair.slots == [nil, nil] && !pair.isComplete, "新用户没有预设城市，进入设置引导")
let tokyo = Destination(rawValue: "Asia/Tokyo")!
check(pair.replace(slot: 0, with: tokyo, defaults: defaults), "保存第一个常用时区")
check(pair.configuredCount == 1 && !pair.isComplete, "设置一项后继续引导")
check(FavoriteZones(defaults: defaults).slots == [tokyo, nil], "设置到一半退出重开可继续")
check(pair.replace(slot: 1, with: .losAngeles, defaults: defaults), "保存第二个常用时区")
check(pair.isComplete && pair.configuredCount == 2, "两项设置完成后结束引导")
check(FavoriteZones(defaults: defaults).slots == [tokyo, .losAngeles], "重新读取已保存常用时区")
check(!pair.replace(slot: 1, with: tokyo, defaults: defaults), "拒绝重复常用时区")
check(!pair.replace(slot: 3, with: tokyo, defaults: defaults), "拒绝不存在的常用位置")
check(pair.slots == [tokyo, .losAngeles], "失败的编辑不修改现有选择")
var aliases = FavoriteZones(defaults: UserDefaults(suiteName: suite + ".aliases")!)
check(aliases.replace(slot: 0, with: johnston, defaults: defaults), "旧别名可以保存")
check(!aliases.replace(slot: 1, with: honolulu, defaults: defaults), "常用时区拒绝同一城市的不同别名")
defaults.set([johnston.rawValue, honolulu.rawValue], forKey: FavoriteZones.key)
check(FavoriteZones(defaults: defaults).slots == [johnston, nil], "旧偏好中的重复别名引导补全")
defaults.removeObject(forKey: FavoriteZones.key)
defaults.set(["Africa/Lusaka", "America/Los_Angeles"], forKey: FavoriteZones.legacyKey)
var migrated = FavoriteZones(defaults: defaults)
check(migrated.slots == [.lusaka, .losAngeles] && migrated.isComplete, "保留旧版用户已保存的两个城市")
check(migrated.replace(slot: 1, with: tokyo, defaults: defaults), "升级后继续编辑")
check(FavoriteZones(defaults: defaults).slots == [.lusaka, tokyo], "新偏好优先于旧版数据")
for (saved, expected) in [
    (["Africa/Lusaka"], [nil, nil]),
    (["Africa/Lusaka", "Africa/Lusaka"], [Destination.lusaka, nil]),
    (["Bogus/Zone", "Asia/Tokyo"], [nil, tokyo]),
    (["", "Asia/Tokyo"], [nil, tokyo]),
    (["Asia/Tokyo", "Asia/Shanghai", "Etc/UTC"], [nil, nil])
] as [([String], [Destination?])] {
    defaults.set(saved, forKey: FavoriteZones.key)
    check(FavoriteZones(defaults: defaults).slots == expected, "损坏偏好保留有效项并引导补全")
}
for date in [winter, summer] {
    let sorted = ZoneCatalog.search("", at: date)
    let offsets = sorted.map { $0.zone.secondsFromGMT(for: date) }
    check(offsets == offsets.sorted(), "全球时区按当日 UTC 偏移递增")
    let groups = ZoneCatalog.groups("", at: date)
    check(groups.map(\.seconds) == Array(Set(offsets)).sorted(), "UTC 分组顺序连续且不重复")
    check(groups.flatMap(\.zones) == sorted, "分组不丢失或重复任何城市")
    check(groups.allSatisfy { group in group.zones.allSatisfy { $0.offset(at: date) == group.title } }, "分组标题与城市真实偏移一致")
}
let fractionalGroups = ZoneCatalog.groups("UTC+05:45", at: winter)
check(fractionalGroups.count == 1 && fractionalGroups[0].seconds == 20700, "45 分钟时区独立分组")
let live = SystemSnapshot.read()
check(TimeZone(identifier: live.identifier) != nil, "当前系统时区可以被解析")
print("LIVE timezone=\(live.identifier), automatic=\(String(describing: live.automatic))")
defaults.removePersistentDomain(forName: suite)
exit(failures == 0 ? 0 : 1)
