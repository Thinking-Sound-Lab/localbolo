import Foundation
import Observation
import os

/// The optional AI cleanup step: applies self-corrections ("at 9, sorry, at
/// 10" becomes "at 10") and removes filler words using a small language model
/// running on this Mac.
@Observable
final class TranscriptCleanup {
    let models: CleanupModelStore
    @ObservationIgnored private let settings: AppSettings

    init(settings: AppSettings, models: CleanupModelStore) {
        self.settings = settings
        self.models = models
    }

    /// Turning cleanup on downloads and loads the model; turning it off frees its memory.
    var isEnabled: Bool {
        get { settings.cleansUpTranscripts }
        set {
            settings.cleansUpTranscripts = newValue
            if newValue {
                models.use(models.activeModel)
            } else {
                models.unload()
            }
        }
    }

    func start() {
        if isEnabled {
            models.loadActiveModelIfInstalled()
        }
    }

    /// The cleaned-up transcript, or the original when cleanup is off, has
    /// nothing to fix, or produces an edit that can't be trusted.
    func apply(to transcript: String) async -> String {
        guard isEnabled, let editor = models.loaded, TranscriptEditPolicy.needsEditing(transcript) else {
            return transcript
        }

        do {
            let started = ContinuousClock.now
            let edited = try await editor.edit(transcript)
            guard TranscriptEditPolicy.isFaithful(edited, to: transcript) else {
                Logger.cleanup.info("Kept the original transcript: the edit changed too much")
                return transcript
            }
            Logger.cleanup.info("Cleaned up transcript in \(ContinuousClock.now - started, privacy: .public)")
            return edited
        } catch {
            Logger.cleanup.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
            return transcript
        }
    }
}
