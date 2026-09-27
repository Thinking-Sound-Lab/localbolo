import AppKit

/// Watches the system-wide keyboard stream for the fn (🌐) key.
///
/// macOS only delivers key events to global monitors once the app has been
/// granted Accessibility access, so call `start()` again after that happens.
final class FnKeyMonitor {
    var onEvent: ((PushToTalkRecognizer.Event) -> Void)?

    private var monitors: [Any] = []
    private var isFnDown = false
    private var releaseWatchdog: Task<Void, Never>?

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]

        // Global monitors see events headed to other apps; the local monitor
        // covers our own windows (onboarding and settings).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        releaseWatchdog?.cancel()
        isFnDown = false
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            // Track the fn flag itself rather than a key code: it is reported
            // consistently across built-in and external Apple keyboards.
            let fnIsDown = event.modifierFlags.contains(.function)
            guard fnIsDown != isFnDown else { return }
            isFnDown = fnIsDown
            onEvent?(fnIsDown ? .fnDown(at: event.timestamp) : .fnUp(at: event.timestamp))
            if fnIsDown {
                watchForMissedRelease()
            }

        case .keyDown:
            onEvent?(.otherKeyDown)

        default:
            break
        }
    }

    /// macOS stops sending key events while secure input is on (for example
    /// when a password field gains focus), so a release can go unseen and
    /// leave the microphone recording. While fn is down, poll the live key
    /// state and report a release that the monitors missed.
    private func watchForMissedRelease() {
        releaseWatchdog?.cancel()
        releaseWatchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.isFnDown else { return }
                if !NSEvent.modifierFlags.contains(.function) {
                    self.isFnDown = false
                    // Key event timestamps are measured from system startup too.
                    self.onEvent?(.fnUp(at: ProcessInfo.processInfo.systemUptime))
                    return
                }
            }
        }
    }
}
