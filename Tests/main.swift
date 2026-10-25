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
for (queries, seconds) in [
    (["utc9", "UTC+9", "utc 9", "utc + 09", "UTC+09:00"], 32400),
    (["utc-8", "UTC − 08", "UTC-08:00"], -28800),
    (["utc5:30", "utc+05:30", "utc5.5"], 19800),
    (["utc5:45", "utc5.75"], 20700),
    (["utc0", "utc+0", "utc-0"], 0)
] {
    let expected = ZoneCatalog.choices.filter { $0.zone.secondsFromGMT(for: winter) == seconds }
    for query in queries {
        check(Set(ZoneCatalog.search(query, at: winter)) == Set(expected) && !expected.isEmpty,
              "简写偏移精确匹配所有城市：\(query)")
    }
}
check(ZoneCatalog.search("utc8 北京", at: winter) == [Destination(rawValue: "Asia/Shanghai")!], "偏移与城市可以组合搜索")
check(ZoneCatalog.search("utc9 北京", at: winter).isEmpty, "组合搜索必须同时符合偏移和城市")
for invalid in ["utc99", "utc+14:01", "utc9:70", "utc9:7", "utc9.999", "utc-13"] {
    check(ZoneCatalog.search(invalid, at: winter).isEmpty, "无效偏移不误匹配城市：\(invalid)")
}
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
check(pair.slots == [nil, nil, nil] && pair.needsSetup, "新用户无预设城市且最多三个常用位")
let tokyo = Destination(rawValue: "Asia/Tokyo")!
check(pair.nextAvailableSlot == 0 && pair.configuredSlots.isEmpty, "新用户仅提供首次添加入口")
check(pair.replace(slot: 0, with: tokyo, defaults: defaults), "保存第一个常用时区")
check(pair.configuredCount == 1 && !pair.needsSetup, "设置一个城市后即完成首次设置")
check(FavoriteZones(defaults: defaults).slots == [tokyo, nil, nil], "重启后保留单城市与两个可选空位")
check(pair.replace(slot: 1, with: .losAngeles, defaults: defaults), "手动添加第二个常用时区")
check(pair.replace(slot: 2, with: .lusaka, defaults: defaults), "手动添加第三个常用时区")
check(pair.nextAvailableSlot == nil && pair.configuredSlots == [0, 1, 2], "三城市后不再提供添加入口")
check(FavoriteZones(defaults: defaults).slots == [tokyo, .losAngeles, .lusaka], "三个常用时区均可重启读取")
check(!pair.replace(slot: 0, with: .lusaka, defaults: defaults), "跨第三位重复城市不能覆盖第一位")
check(!pair.replace(slot: 2, with: tokyo, defaults: defaults), "第三位不能重复第一位城市")
check(!pair.replace(slot: 3, with: tokyo, defaults: defaults), "拒绝第四个常用位置")
check(pair.slots == [tokyo, .losAngeles, .lusaka], "失败编辑不修改现有选择")
check(pair.replace(slot: 2, with: shanghai, defaults: defaults), "第三位可以独立更换城市")
for slot in 0..<FavoriteZones.capacity {
    let removed = pair.removing(slot: slot)!
    let expected = pair.slots.enumerated().filter { $0.offset != slot }.map { $0.element } + [nil]
    check(removed.slots == expected && removed.nextAvailableSlot == 2, "删除任意位置后顺序不变、编号连续且可继续添加")
}
let two = pair.removing(slot: 1)!
two.persist(defaults: defaults)
check(FavoriteZones(defaults: defaults) == two, "删除结果可持久化，不会重启后重新出现")
let one = two.removing(slot: 1)!
check(one.slots == [tokyo, nil, nil] && one.removing(slot: 0) == nil, "至少保留一个常用城市，底层拒绝删除最后一个")
check(pair.removing(slot: -1) == nil && pair.removing(slot: 3) == nil && two.removing(slot: 2) == nil,
      "拒绝越界或空位删除")
check(pair.slots == [tokyo, .losAngeles, shanghai], "删除暂存不修改原数据")
let aliasSuite = suite + ".aliases"
let aliasDefaults = UserDefaults(suiteName: aliasSuite)!
var aliases = FavoriteZones(defaults: aliasDefaults)
check(aliases.replace(slot: 0, with: johnston, defaults: aliasDefaults), "旧别名可以保存")
check(!aliases.replace(slot: 2, with: honolulu, defaults: aliasDefaults), "第三位拒绝同一城市的兼容别名")
aliasDefaults.removePersistentDomain(forName: aliasSuite)
for source in [FavoriteZones.previousKey, FavoriteZones.legacyKey] {
    defaults.removeObject(forKey: FavoriteZones.key)
    defaults.removeObject(forKey: FavoriteZones.previousKey)
    defaults.removeObject(forKey: FavoriteZones.legacyKey)
    defaults.set(["Africa/Lusaka", "America/Los_Angeles"], forKey: source)
    var migrated = FavoriteZones(defaults: defaults)
    check(migrated.slots == [.lusaka, .losAngeles, nil] && !migrated.needsSetup, "升级保留旧版两城市并留下可选第三位：\(source)")
    check(migrated.replace(slot: 2, with: tokyo, defaults: defaults), "旧用户可以添加第三城市")
    check(FavoriteZones(defaults: defaults).slots == [.lusaka, .losAngeles, tokyo], "新版偏好优先于旧版数据")
}
for (saved, expected) in [
    (["Africa/Lusaka"], [Destination.lusaka, nil, nil]),
    (["Africa/Lusaka", "Africa/Lusaka"], [Destination.lusaka, nil, nil]),
    (["Bogus/Zone", "Asia/Tokyo"], [nil, tokyo, nil]),
    (["", "Asia/Tokyo"], [nil, tokyo, nil]),
    (["Asia/Tokyo", "Asia/Shanghai", "Etc/UTC"], [tokyo, shanghai, Destination(rawValue: "Etc/UTC")!]),
    (["Asia/Tokyo", "Bogus/Zone", "Asia/Shanghai", "Africa/Lusaka"], [tokyo, nil, shanghai])
] as [([String], [Destination?])] {
    defaults.set(saved, forKey: FavoriteZones.key)
    check(FavoriteZones(defaults: defaults).slots == expected, "偏好读取保留有效项、去重并遵守容量")
}
check(BackupClockSettings(defaults: defaults) == BackupClockSettings(enabled: false, destination: nil), "新用户备用时区默认关闭且没有预设城市")
let backup = BackupClockSettings(enabled: true, destination: shanghai)
backup.persist(defaults: defaults)
check(BackupClockSettings(defaults: defaults) == backup, "备用时区与显示开关可持久化")
let midnight = iso.date(from: "2026-01-17T17:30:00Z")!
check(backup.title(at: midnight) == "周日 01:30", "备用时间按所选城市计算星期与24小时分钟，正确跨日")
let laxClock = BackupClockSettings(enabled: true, destination: .losAngeles)
check(laxClock.title(at: before) == "周日 01:59" && laxClock.title(at: after) == "周日 03:00", "备用时钟自动遵循夏令时跳变")
let fractionalClock = BackupClockSettings(enabled: true, destination: Destination(rawValue: "Asia/Kathmandu")!)
check(fractionalClock.title(at: winter) == "周四 17:45", "备用时钟支持45分钟时区")
let disabled = BackupClockSettings(enabled: false, destination: shanghai)
disabled.persist(defaults: defaults)
check(disabled.title(at: midnight) == nil && BackupClockSettings(defaults: defaults).destination == shanghai, "关闭显示仍保留备用城市")
defaults.set(["enabled": true, "timezone": "Bogus/Zone"], forKey: BackupClockSettings.key)
check(!BackupClockSettings(defaults: defaults).enabled, "非法备用城市不能产生空白常驻项")
check(!BackupClockSettings(enabled: true, destination: nil).enabled, "无城市不能开启备用显示")
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
check(fractionalGroups.first?.indexTitle == "+5:45", "导航保留分数小时")
check(ZoneCatalog.groups("utc-8", at: winter).first?.indexTitle == "−8", "导航负时区标识")
check(ZoneCatalog.groups("utc0", at: winter).first?.indexTitle == "+0", "导航零时区标识")
let live = SystemSnapshot.read()
check(TimeZone(identifier: live.identifier) != nil, "当前系统时区可以被解析")
print("LIVE timezone=\(live.identifier), automatic=\(String(describing: live.automatic))")
defaults.removePersistentDomain(forName: suite)
exit(failures == 0 ? 0 : 1)
