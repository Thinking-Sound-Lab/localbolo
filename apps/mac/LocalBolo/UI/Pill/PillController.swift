import AppKit
import Observation
import SwiftUI

/// Owns the floating pill window and keeps it at the bottom centre of the
/// screen the user is working on.
final class PillController {
    /// Large enough for the widest pill state plus its shadow. The window is
    /// transparent and click-through, so the extra space is invisible.
    private static let panelSize = CGSize(width: 360, height: 80)
    /// Gap between the bottom of the panel and the Dock (or screen edge).
    private static let bottomInset: CGFloat = 4

    private let dictation: DictationController
    private let panel: PillPanel
    private var screenObserver: (any NSObjectProtocol)?

    init(dictation: DictationController, settings: AppSettings) {
        self.dictation = dictation

        let hostingView = NSHostingView(rootView: LivePillView(dictation: dictation, settings: settings))
        hostingView.sizingOptions = []
        panel = PillPanel(contentView: hostingView)
    }

    func start() {
        moveToActiveScreen()
        panel.orderFrontRegardless()
        observeDictationPhase()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.moveToActiveScreen() }
        }
    }

    private func observeDictationPhase() {
        withObservationTracking {
            _ = dictation.phase
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.dictationPhaseDidChange()
                self?.observeDictationPhase()
            }
        }
    }

    private func dictationPhaseDidChange() {
        // Follow the user to whichever display they started dictating on.
        if dictation.phase == .listening {
            moveToActiveScreen()
        }
    }

    private func moveToActiveScreen() {
        // The pointer is almost always on the display the user is typing on.
        // (`NSScreen.main` only tracks this app's own key window.)
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        else { return }
        let visibleFrame = screen.visibleFrame
        let origin = CGPoint(
            x: visibleFrame.midX - Self.panelSize.width / 2,
            y: visibleFrame.minY + Self.bottomInset
        )
        panel.setFrame(CGRect(origin: origin, size: Self.panelSize), display: true)
    }
}

/// Feeds live dictation state and settings into `PillView`.
private struct LivePillView: View {
    let dictation: DictationController
    let settings: AppSettings

    var body: some View {
        PillView(
            phase: dictation.phase,
            targetApp: dictation.targetApp,
            audioLevel: dictation.audioLevel,
            showsWhenIdle: settings.showsIdlePill
        )
    }
}
