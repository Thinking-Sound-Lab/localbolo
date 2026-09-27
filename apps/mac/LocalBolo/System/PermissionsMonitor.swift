import AVFoundation
import ApplicationServices
import Observation
import os

/// Tracks the two permissions dictation depends on:
/// - **Microphone**, to record speech.
/// - **Accessibility**, to see the fn key system-wide and paste into other apps.
@Observable
final class PermissionsMonitor {
    enum State {
        case notDetermined
        case denied
        case granted
    }

    private(set) var microphone: State = .notDetermined
    private(set) var accessibility: State = .notDetermined

    /// Called once when Accessibility access goes from missing to granted.
    @ObservationIgnored var onAccessibilityGranted: (() -> Void)?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    init() {
        refresh()
    }

    var allGranted: Bool {
        microphone == .granted && accessibility == .granted
    }

    /// Polls for changes. macOS sends no notification when the user flips a
    /// switch in System Settings, so polling is the only reliable option.
    func startMonitoring() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func refresh() {
        let microphone: State = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
        let accessibility: State = AXIsProcessTrusted() ? .granted : .denied

        // Only assign changes: every assignment re-renders the views that read these.
        if microphone != self.microphone {
            self.microphone = microphone
        }
        if accessibility != self.accessibility {
            self.accessibility = accessibility
            if accessibility == .granted {
                onAccessibilityGranted?()
            }
        }
    }

    func requestMicrophone() async {
        if microphone == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            refresh()
        } else {
            SystemSettings.open(.microphonePrivacy)
        }
    }

    func requestAccessibility() {
        guard !AXIsProcessTrusted() else { return refresh() }

        removeStaleAccessibilityEntry()
        // Adds LocalBolo to the Accessibility list, so the user only has to flip its switch.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        SystemSettings.open(.accessibilityPrivacy)
    }

    /// macOS ties the Accessibility switch to the code signature of the copy
    /// of the app that was first listed. After an update or rebuild the switch
    /// still shows LocalBolo as allowed, but it no longer applies to this copy,
    /// and turning it on and off doesn't help. Removing the old entry lets the
    /// prompt list this copy instead.
    private func removeStaleAccessibilityEntry() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let tccutil = Process()
        tccutil.executableURL = URL(filePath: "/usr/bin/tccutil")
        tccutil.arguments = ["reset", "Accessibility", bundleIdentifier]
        do {
            try tccutil.run()
            tccutil.waitUntilExit()
        } catch {
            Logger.app.error("Couldn't reset Accessibility entry: \(error.localizedDescription, privacy: .public)")
        }
    }
}
