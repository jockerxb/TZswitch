import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"

    static let key = "appLanguage.v1"
    init(defaults: UserDefaults) {
        self = defaults.string(forKey: Self.key).flatMap(Self.init(rawValue:)) ?? .chinese
    }
    var name: String { self == .chinese ? "中文" : "English" }
    var locale: Locale { Locale(identifier: self == .chinese ? "zh_CN" : "en_US") }
    var datePattern: String { self == .chinese ? "M月d日 EEEE" : "EEE, MMM d" }
    var weekdays: [String] {
        self == .chinese ? ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
    func persist(defaults: UserDefaults) { defaults.set(rawValue, forKey: Self.key) }
    func text(_ key: AppText, _ arguments: CVarArg...) -> String {
        let format = self == .english ? key.translations.english : key.translations.chinese
        return arguments.isEmpty ? format : String(format: format, locale: locale, arguments: arguments)
    }
    func catalogSummary(offsets: Int, cities: Int) -> String {
        if self == .chinese { return "\(offsets) 个时区 · \(cities) 个城市" }
        return "\(offsets) UTC \(offsets == 1 ? "offset" : "offsets") · \(cities) \(cities == 1 ? "city" : "cities")"
    }


}

/// Each new UI key must provide both languages; the exhaustive switch makes a
/// missing translation a compiler error rather than a silent Chinese fallback.
enum AppText: CaseIterable {
    case tagline
    case changeLanguage
    case openGitHub
    case gitHubHelp
    case currentTimezone
    case favorites
    case setupHint
    case addFavorite
    case working
    case adminAutomatic
    case adminRequired
    case closeKeepClock
    case closeQuit
    case timezoneStaysHelp
    case backupClock
    case showBackupClock
    case changeBackupCity
    case dstSuffix
    case switchTo
    case changeFavoriteNumber
    case changeFavorite
    case deleteCity
    case chooseFavoriteCity
    case setFavoriteNumber
    case setBackup
    case close
    case closePicker
    case searchPlaceholder
    case searchGlobal
    case jumpTo
    case deleteFavorite
    case removeFavoriteHint
    case duplicateCity
    case addedLabel
    case chooseCityIdentifier
    case noResults
    case addOnlyHint
    case switchCityHint
    case backupOnlyHint
    case showAppMenu
    case quitAppMenu
    case moveClockHelp
    case backupAccessibility
    case backupTimezoneMenu
    case openApp
    case changeBackupMenu
    case stopClockMenu
    case quitWhileSwitching
    case authorizationUnavailable
    case systemChanged
    case deletedNotice
    case distinctFavorites
    case addedNotice
    case preparingSwitch
    case alreadyCurrent
    case authorizing
    case switched
    case cancelled
    case switchFailed
    case verificationFailed

    var translations: (chinese: String, english: String) {
        switch self {
        case .tagline: return ("时区随手切，本地时间随时看", "Switch time zones. See local time.")
        case .changeLanguage: return ("切换语言", "Change language")
        case .openGitHub: return ("打开 TZswitch GitHub 项目", "Open TZswitch on GitHub")
        case .gitHubHelp: return ("在浏览器中查看源码、下载更新或反馈问题", "View source code, download updates, or report an issue")
        case .currentTimezone: return ("系统当前时区", "System time zone")
        case .favorites: return ("常用时区", "Favorite time zones")
        case .setupHint: return ("设置一个常用城市，即可开始使用", "Choose a city to get started.")
        case .addFavorite: return ("添加常用时区", "Add Favorite Time Zone")
        case .working: return ("正在处理…", "Working…")
        case .adminAutomatic: return ("切换需管理员授权并关闭自动时区", "Requires admin approval; disables automatic time zone detection")
        case .adminRequired: return ("切换需管理员授权", "Administrator approval required")
        case .closeKeepClock: return ("关闭窗口保留备用时间", "Closing keeps menu bar time visible")
        case .closeQuit: return ("关闭即退出，时区保留", "Close to quit; your time zone stays set")
        case .timezoneStaysHelp: return ("；系统时区继续保留", "; your Mac keeps the selected time zone")
        case .backupClock: return ("备用时区显示", "Backup time zone")
        case .showBackupClock: return ("显示备用时区时间", "Show backup time zone")
        case .changeBackupCity: return ("更换备用城市：%@", "Change backup time zone: %@")
        case .dstSuffix: return (" · 夏令时", " · DST")
        case .switchTo: return ("切换到%@", "Switch to %@")
        case .changeFavoriteNumber: return ("更换常用城市 %d", "Change favorite city %d")
        case .changeFavorite: return ("更换常用城市", "Change Favorite City…")
        case .deleteCity: return ("删除%@", "Remove %@")
        case .chooseFavoriteCity: return ("点击设置常用城市", "Choose a City…")
        case .setFavoriteNumber: return ("设置常用时区 %d", "Choose a city for favorite %d")
        case .setBackup: return ("设置备用时区", "Choose a backup time zone")
        case .close: return ("关闭", "Close")
        case .closePicker: return ("关闭时区选择", "Close time zone picker")
        case .searchPlaceholder: return ("搜索时区/城市，例如：utc9、北京", "Search time zones or cities: utc9, Beijing")
        case .searchGlobal: return ("搜索全球时区", "Search time zones and cities")
        case .jumpTo: return ("跳转到%@", "Go to %@")
        case .deleteFavorite: return ("删除此常用时区", "Remove from Favorites")
        case .removeFavoriteHint: return ("仅移除常用项，系统时区与备用时间不变", "Your system and backup time zones won’t change.")
        case .duplicateCity: return ("此城市已在常用时区中", "This city is already in Favorites.")
        case .addedLabel: return ("已添加", "Saved")
        case .chooseCityIdentifier: return ("选择%@，%@", "Choose %@, %@")
        case .noResults: return ("未找到结果，试试 utc9、utc-8 或北京。", "No results. Try utc9, utc-8, or Beijing.")
        case .addOnlyHint: return ("仅添加常用城市，不切换系统时区。添加后点击卡片即可切换。", "Choose a city to add to Favorites. Your system time zone won’t change.")
        case .switchCityHint: return ("选择城市后将请求 macOS 管理员授权，确认即可切换。", "Choose a city, then authorize the change in the macOS dialog.")
        case .backupOnlyHint: return ("仅用于显示备用时间，不修改系统时区，无需管理员授权。", "Choose a city to show in the menu bar. Your system time zone won’t change.")
        case .showAppMenu: return ("显示TZswitch", "Show TZswitch")
        case .quitAppMenu: return ("退出TZswitch", "Quit TZswitch")
        case .moveClockHelp: return ("按住 ⌘ 拖动时间可调整菜单栏位置", "Hold ⌘ and drag to move the time in the menu bar.")
        case .backupAccessibility: return ("备用时间 %@ %@", "Backup time zone, %@, %@")
        case .backupTimezoneMenu: return ("备用时区：%@", "Backup time zone: %@")
        case .openApp: return ("打开 TZswitch", "Open TZswitch")
        case .changeBackupMenu: return ("更换备用时区…", "Change Backup Time Zone…")
        case .stopClockMenu: return ("退出%@时间", "Hide %@ Time")
        case .quitWhileSwitching: return ("正在切换时区，请完成或取消系统授权后再退出。", "Finish or cancel authorization in the macOS dialog before quitting.")
        case .authorizationUnavailable: return ("系统授权组件不可用，请重新打开 App 后重试。", "Administrator authorization is unavailable. Restart TZswitch and try again.")
        case .systemChanged: return ("系统设置已被其他程序更改，请重新选择时区。", "Your Mac’s time settings changed. Choose a time zone again.")
        case .deletedNotice: return ("已删除%@，系统时区未更改。", "Removed %@ from Favorites. Your Mac’s time zone hasn’t changed.")
        case .distinctFavorites: return ("常用时区请选择不同的城市。", "This city is already in Favorites. Choose another city.")
        case .addedNotice: return ("已添加%@，点击卡片即可切换。", "Added %@ to Favorites. Click it to switch.")
        case .preparingSwitch: return ("正在准备切换至%@…", "Preparing to switch to %@…")
        case .alreadyCurrent: return ("系统已使用%@时区。", "Your Mac is already set to %@ time.")
        case .authorizing: return ("请在 macOS 弹窗中授权…", "Authorize the change in the macOS dialog…")
        case .switched: return ("已切换至%@", "Switched to %@")
        case .cancelled: return ("已取消，保留原城市与系统时区。", "Canceled. Your saved cities and system time zone haven’t changed.")
        case .switchFailed: return ("系统未完成切换。请重试或检查管理员权限。", "Couldn’t change the time zone. Try again with administrator authorization.")
        case .verificationFailed: return ("验证未通过：系统时区与所选城市不一致，请检查日期与时间设置。", "The time zone change couldn’t be confirmed. Check System Settings > General > Date & Time.")
        }
    }
}

/// Keep messages semantic so switching the UI language also updates a notice
/// already on screen, without replaying the underlying operation.
struct AppNotice {
    let key: AppText
    let destination: Destination?
    func text(in language: AppLanguage) -> String {
        if let destination { return language.text(key, destination.displayName(in: language)) }
        return language.text(key)
    }
}

extension Destination {
    func displayName(in language: AppLanguage) -> String {
        if language == .chinese { return city }
        return catalogID == "Asia/Shanghai" ? "Beijing / Shanghai" : englishCity
    }
}
