import AppKit
import Observation
import os

/// Runs the push-to-talk loop: hold fn → record → release → transcribe → clean up → paste.
@Observable
final class DictationController {
    private(set) var phase: DictationPhase = .idle
    /// The app that will receive the transcript. Shown in the pill.
    private(set) var targetApp: TargetApplication?
    /// Smoothed microphone level in `0...1`, used to animate the waveform.
    private(set) var audioLevel: Float = 0
    private(set) var lastTranscript: String?

    @ObservationIgnored private let license: LicenseManager
    @ObservationIgnored private let speechModels: SpeechModelStore
    @ObservationIgnored private let cleanup: TranscriptCleanup
    @ObservationIgnored private let permissions: PermissionsMonitor
    @ObservationIgnored private let inserter: TextInserter
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let keyMonitor = FnKeyMonitor()
    @ObservationIgnored private var recognizer = PushToTalkRecognizer()
    @ObservationIgnored private var appActivationObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var noticeDismissal: Task<Void, Never>?

    init(
        license: LicenseManager,
        speechModels: SpeechModelStore,
        cleanup: TranscriptCleanup,
        permissions: PermissionsMonitor,
        inserter: TextInserter
    ) {
        self.license = license
        self.speechModels = speechModels
        self.cleanup = cleanup
        self.permissions = permissions
        self.inserter = inserter
    }

    func start() {
        keyMonitor.onEvent = { [weak self] event in self?.handle(event) }
        keyMonitor.start()

        // Global key monitors stay silent until Accessibility is granted,
        // so reinstall them the moment it is.
        permissions.onAccessibilityGranted = { [weak self] in self?.keyMonitor.start() }

        observeFrontmostApp()
    }

    // MARK: - Push-to-talk

    private func handle(_ event: PushToTalkRecognizer.Event) {
        switch recognizer.handle(event) {
        case .start: beginListening()
        case .finish: finishListening()
        case .cancel: cancelListening()
        case nil: break
        }
    }

    private func beginListening() {
        guard phase == .idle || phase.isNotice else { return }

        switch license.status {
        case .active:
            break
        case .notActivated:
            return showNotice("Enter your license key in the Setup Guide")
        case .needsVerification:
            return showNotice("Connect to the internet to verify your license")
        }

        switch permissions.microphone {
        case .granted:
            break
        case .notDetermined:
            Task { await permissions.requestMicrophone() }
            return showNotice("Allow microphone access, then try again")
        case .denied:
            return showNotice("Microphone access is off")
        }

        guard speechModels.transcriber != nil else {
            return showNotice(speechModels.readinessMessage)
        }

        targetApp = TargetApplication(NSWorkspace.shared.frontmostApplication)
        do {
            try recorder.start { [weak self] level in
                Task { @MainActor in self?.updateAudioLevel(level) }
            }
            phase = .listening
        } catch {
            Logger.dictation.error("Couldn't start recording: \(error.localizedDescription, privacy: .public)")
            showNotice("Couldn't start the microphone")
        }
    }

    private func finishListening() {
        guard phase == .listening else { return }
        let recording = recorder.stop()
        audioLevel = 0

        guard recording.containsSpeech, let transcriber = speechModels.transcriber else {
            phase = .idle
            return
        }

        phase = .transcribing
        Task {
            do {
                let started = ContinuousClock.now
                let transcript = TranscriptNormalizer.clean(try await transcriber.transcribe(recording.samples))
                Logger.dictation.info(
                    "Transcribed \(recording.duration, format: .fixed(precision: 1))s of audio in \(ContinuousClock.now - started, privacy: .public)"
                )
                let text = await cleanup.apply(to: transcript)
                guard !text.isEmpty else {
                    phase = .idle
                    return
                }
                lastTranscript = text

                if permissions.accessibility == .granted {
                    inserter.insert(text)
                    phase = .idle
                } else {
                    // Without Accessibility access macOS silently drops the ⌘V
                    // keystroke, so leave the text on the clipboard instead.
                    inserter.copyToClipboard(text)
                    showNotice("Copied. Turn on Accessibility to paste")
                }
            } catch {
                Logger.dictation.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
                showNotice("Couldn't transcribe that")
            }
        }
    }

    private func cancelListening() {
        guard phase == .listening else { return }
        _ = recorder.stop()
        audioLevel = 0
        phase = .idle
    }

    // MARK: - Helpers

    private func updateAudioLevel(_ level: Float) {
        guard phase == .listening else { return }
        // Rise quickly and fall slowly so the waveform feels lively without flickering.
        let smoothing: Float = level > audioLevel ? 0.5 : 0.15
        audioLevel += (level - audioLevel) * smoothing
    }

    private func showNotice(_ message: String) {
        phase = .notice(message)
        noticeDismissal?.cancel()
        noticeDismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, let self, self.phase.isNotice else { return }
            self.phase = .idle
        }
    }

    /// Keeps the pill's app icon in sync if the user switches apps mid-dictation,
    /// since the transcript is always pasted into whichever app is frontmost.
    private func observeFrontmostApp() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, self.phase == .listening || self.phase == .transcribing else { return }
                self.targetApp = TargetApplication(app)
            }
        }
    }
}
