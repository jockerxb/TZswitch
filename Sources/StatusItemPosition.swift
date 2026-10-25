import Foundation

/// AppKit clears a status item's preferred position when it is hidden. Keep a
/// separate copy so hiding and restarting cannot discard a user-dragged order.
final class StatusItemPosition {
    let preferredKey: String
    private let savedKey: String
    private let defaults: UserDefaults

    init(autosaveName: String, defaults: UserDefaults = .standard) {
        preferredKey = "NSStatusItem Preferred Position \(autosaveName)"
        savedKey = "statusItemPosition.v1.\(autosaveName)"
        self.defaults = defaults
    }

    func remember() {
        if let position = defaults.object(forKey: preferredKey) as? NSNumber {
            defaults.set(position, forKey: savedKey)
        }
    }

    func restore() {
        // An existing native value is newer (for example, after a drag).
        if let position = defaults.object(forKey: preferredKey) as? NSNumber {
            defaults.set(position, forKey: savedKey)
        } else if let position = defaults.object(forKey: savedKey) as? NSNumber {
            defaults.set(position, forKey: preferredKey)
        }
    }

    func hide(_ changeVisibility: () -> Void) {
        remember()
        changeVisibility()
        restore()
    }
}
