import AppKit

private enum PlacementFailure: Error { case missingWindow, changedPosition }

@MainActor final class NativePositionDelegate: NSObject, NSApplicationDelegate {
    private(set) var failed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do { try await runCheck() }
            catch { failed = true; print("FAIL native menu-bar placement: \(error)") }
            fflush(stdout)
            exit(failed ? 1 : 0)
        }
    }

    // Yield to AppKit rather than nesting a run loop inside a main-queue block:
    // status-item windows finish positioning asynchronously on the main queue.
    private func frame(of item: NSStatusItem) async throws -> CGRect {
        for _ in 0..<40 {
            try await Task.sleep(nanoseconds: 50_000_000)
            if let button = item.button, let window = button.window, window.isVisible {
                let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
                if frame.width > 0, frame.height > 0, frame.minX != 0 { return frame }
            }
        }
        throw PlacementFailure.missingWindow
    }

    private func runCheck() async throws {
        let name = "TZswitchPlacementCheck-" + UUID().uuidString
        let position = StatusItemPosition(autosaveName: name)
        let defaults = UserDefaults.standard
        defaults.set(193, forKey: position.preferredKey)
        var item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = name
        item.button?.title = "TZcheck"
        defer {
            NSStatusBar.system.removeStatusItem(item)
            defaults.removeObject(forKey: position.preferredKey)
            defaults.removeObject(forKey: "NSStatusItem Visible \(name)")
            defaults.removeObject(forKey: "statusItemPosition.v1.\(name)")
        }
        let before = try await frame(of: item)
        for cycle in 1...3 {
            position.hide { item.isVisible = false }
            try await Task.sleep(nanoseconds: 150_000_000)
            position.restore()
            item.isVisible = true
            let after = try await frame(of: item)
            print("Cycle \(cycle): x before=\(before.minX) after=\(after.minX)")
            guard abs(before.minX - after.minX) < 1 else { throw PlacementFailure.changedPosition }
        }
        position.remember()
        NSStatusBar.system.removeStatusItem(item)
        let reopened = StatusItemPosition(autosaveName: name)
        reopened.restore()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = name
        item.button?.title = "TZcheck"
        reopened.restore()
        item.isVisible = true
        let recreated = try await frame(of: item)
        guard abs(before.minX - recreated.minX) < 1 else { throw PlacementFailure.changedPosition }
        print("PASS native menu-bar position unchanged after three hide/show cycles and item recreation")
    }
}

@main struct NativePositionCheck {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = NativePositionDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
        exit(delegate.failed ? 1 : 0)
    }
}
