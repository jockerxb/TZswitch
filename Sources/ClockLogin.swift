import AppKit
import CoreServices
import ServiceManagement

@MainActor final class ClockLogin: ObservableObject {
    private let service = SMAppService.mainApp
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var changeFailed = false

    init() { status = service.status }

    func refresh() { status = service.status }

    func setEnabled(_ enabled: Bool) {
        changeFailed = false
        refresh()
        do {
            if enabled, status == .notRegistered || status == .notFound {
                try service.register()
            } else if !enabled, status == .enabled || status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            refresh()
            changeFailed = status != .requiresApproval || !enabled
            return
        }
        refresh()
        changeFailed = enabled ? status != .enabled && status != .requiresApproval
            : status == .enabled || status == .requiresApproval
    }

    func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }

    // Login Services may deliver a marked open event or start the registered
    // app directly. Manual launches from Finder/Dock have a normal open event.
    static func isLoginLaunch(event: NSAppleEventDescriptor?, registered: Bool) -> Bool {
        guard let event else { return registered }
        let marker = AEKeyword(keyAELaunchedAsLogInItem)
        return event.eventID == AEEventID(kAEOpenApplication)
            && (event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == marker
                || event.attributeDescriptor(forKeyword: marker) != nil)
    }
}
