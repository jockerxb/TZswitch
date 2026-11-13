import AppKit
import CoreServices
import ServiceManagement

@MainActor final class ClockLogin: ObservableObject {
    private let service = SMAppService.mainApp
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var changeFailed = false

    init() { status = service.status }

    func refresh() { status = service.status }

    var isRequested: Bool { status == .enabled || status == .requiresApproval }

    func setEnabled(_ enabled: Bool) -> Bool {
        changeFailed = false
        refresh()
        do {
            if enabled, status == .notRegistered || status == .notFound {
                try service.register()
            } else if !enabled, isRequested {
                try service.unregister()
            }
        } catch {
            // The system can report an error after the state already changed.
            // In particular, registration can be waiting for user approval.
        }
        refresh()
        changeFailed = isRequested != enabled
        return !changeFailed
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
