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
check(ZoneCatalog.search("  ", at: winter).count == Destination.allCases.count, "空白查询展示全部时区")
check(ZoneCatalog.search("nothing-matches-this", at: winter).isEmpty, "无匹配搜索")
let suite = "TZswitch.Tests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
var pair = QuickZones(defaults: defaults)
check(pair.zones == [.lusaka, .losAngeles], "首次启动默认快捷位")
let tokyo = Destination(rawValue: "Asia/Tokyo")!
check(pair.replace(slot: 0, with: tokyo, defaults: defaults), "修改快捷位")
check(QuickZones(defaults: defaults).zones == [tokyo, .losAngeles], "重新读取已保存快捷位")
check(!pair.replace(slot: 1, with: tokyo, defaults: defaults), "拒绝重复快捷位")
check(!pair.replace(slot: 3, with: tokyo, defaults: defaults), "拒绝不存在的快捷位")
for corrupt in [["Africa/Lusaka"], ["Africa/Lusaka", "Africa/Lusaka"], ["Bogus/Zone", "Asia/Tokyo"], ["Asia/Tokyo", "Asia/Shanghai", "Etc/UTC"]] {
    defaults.set(corrupt, forKey: QuickZones.key)
    check(QuickZones(defaults: defaults).zones == [.lusaka, .losAngeles], "损坏偏好恢复有效默认值")
}
let live = SystemSnapshot.read()
check(TimeZone(identifier: live.identifier) != nil, "当前系统时区可以被解析")
print("LIVE timezone=\(live.identifier), automatic=\(String(describing: live.automatic))")
defaults.removePersistentDomain(forName: suite)
exit(failures == 0 ? 0 : 1)
