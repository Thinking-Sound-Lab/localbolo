import Foundation
import Observation
import os

/// Optional conservative cleanup or multilingual grammar and formatting.
@Observable
final class TranscriptCleanup {
    let models: CleanupModelStore
    @ObservationIgnored private let settings: AppSettings

    init(settings: AppSettings, models: CleanupModelStore) {
        self.settings = settings
        self.models = models
    }

    var isEnabled: Bool {
        get { settings.cleansUpTranscripts }
        set {
            settings.cleansUpTranscripts = newValue
            if newValue {
                models.use(models.activeModel.supports(style) ? models.activeModel : .recommended(for: style))
            } else {
                models.unload()
            }
        }
    }

    var style: CleanupStyle {
        get { settings.cleanupStyle }
        set {
            settings.cleanupStyle = newValue
            if isEnabled {
                let compatible = models.activeModel.supports(newValue)
                // The old editor cannot serve the new style. Release its large
                // weights before loading the replacement on an 8 GB Mac.
                if !compatible { models.unload() }
                models.use(compatible ? models.activeModel : .recommended(for: newValue))
            }
        }
    }

    func readinessMessage(for preferences: DictationPreferences) -> String? {
        guard preferences.cleanupEnabled, preferences.cleanupStyle == .polished else { return nil }
        if models.activeModel.supports(.polished), models.loaded != nil { return nil }
        return models.isBusy ? "Polishing model is still preparing" : "Download the polishing model in Settings"
    }

    func start() {
        if isEnabled, models.activeModel.supports(style) {
            models.loadActiveModelIfInstalled()
        }
    }

    func warmUp(preferences: DictationPreferences? = nil) async {
        let preferences = preferences ?? settings.dictationPreferences
        guard preferences.cleanupEnabled, let editor = models.loaded else { return }
        try? await editor.warmUp(style: preferences.cleanupStyle, language: preferences.language)
    }

    func apply(to transcript: String, preferences: DictationPreferences? = nil, detectedLanguage: String? = "en") async -> String {
        let preferences = preferences ?? settings.dictationPreferences
        guard preferences.cleanupEnabled else { return transcript }
        let editor = models.activeModel.supports(preferences.cleanupStyle) ? models.loaded : nil
        let editingLanguage = preferences.language == .automatic
            ? detectedLanguage.flatMap(SpeechLanguage.init) ?? .automatic
            : preferences.language
        let started = ContinuousClock.now
        let text = await TranscriptProcessor.apply(
            to: transcript, style: preferences.cleanupStyle, language: detectedLanguage
        ) { passage in
            guard let editor else { throw EditorError.cacheCannotRewind }
            return try await editor.edit(passage, style: preferences.cleanupStyle, language: editingLanguage)
        }
        Logger.cleanup.info("Cleaned up transcript in \(ContinuousClock.now - started, privacy: .public)")
        return text
    }
}
