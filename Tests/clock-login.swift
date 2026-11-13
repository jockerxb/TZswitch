import AppKit
import CoreServices

@main struct ClockLoginTests {
    @MainActor static func main() {
        func openEvent() -> NSAppleEventDescriptor {
            NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass),
                                   eventID: AEEventID(kAEOpenApplication),
                                   targetDescriptor: nil,
                                   returnID: AEReturnID(kAutoGenerateReturnID),
                                   transactionID: AETransactionID(kAnyTransactionID))
        }

        let manual = openEvent()
        let login = openEvent()
        login.setParam(NSAppleEventDescriptor(enumCode: AEKeyword(keyAELaunchedAsLogInItem)),
                       forKeyword: AEKeyword(keyAEPropData))
        let checks = [
            (ClockLogin.isLoginLaunch(event: login, registered: false), "系统登录事件走后台"),
            (ClockLogin.isLoginLaunch(event: nil, registered: true), "已注册的无事件启动走后台"),
            (!ClockLogin.isLoginLaunch(event: manual, registered: true), "注册后仍可正常手动打开窗口"),
            (!ClockLogin.isLoginLaunch(event: nil, registered: false), "未注册时不会因缺少事件而隐藏窗口")
        ]
        for (passed, name) in checks { print("\(passed ? "PASS" : "FAIL") \(name)") }
        exit(checks.allSatisfy { $0.0 } ? 0 : 1)
    }
}
