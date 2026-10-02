import Foundation
import Observation
import os

/// The optional cleanup step. It removes filler sounds and doubled words with
/// plain rules, and applies self-corrections ("at 9, sorry, at 10" becomes
/// "at 10") using a small language model running on this Mac.
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

    /// Gets the model ready for the dictation that's starting. See ``TranscriptEditor/warmUp()``.
    func warmUp() async {
        guard isEnabled, let editor = models.loaded else { return }
        try? await editor.warmUp()
    }

    /// The cleaned-up transcript, or the original when cleanup is off.
    func apply(to transcript: String) async -> String {
        guard isEnabled else { return transcript }

        // The rules need no model, so they apply even while it's still loading.
        let tidied = DisfluencyFilter.clean(transcript)
        guard let editor = models.loaded else { return tidied }

        var sentences = TranscriptEditPolicy.sentences(in: tidied)
        let passages = TranscriptEditPolicy.passagesToEdit(among: sentences)
        guard !passages.isEmpty else { return tidied }

        let started = ContinuousClock.now
        // Last passage first, so replacing one doesn't shift the ones still to do.
        for passage in passages.reversed() {
            let original = sentences[passage].joined()
            if let edited = await edit(original, with: editor) {
                sentences.replaceSubrange(passage, with: [edited])
            }
        }
        Logger.cleanup.info("Cleaned up transcript in \(ContinuousClock.now - started, privacy: .public)")
        return sentences.joined()
    }

    /// The model's edit of `passage`, or `nil` if it failed or can't be trusted.
    private func edit(_ passage: String, with editor: TranscriptEditor) async -> String? {
        // The model sees the text without the whitespace that joins it to the next sentence.
        let text = passage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trailingWhitespace = passage.suffix(while: \.isWhitespace)

        do {
            let edited = try await editor.edit(text)
            guard TranscriptEditPolicy.isFaithful(edited, to: text) else {
                Logger.cleanup.info("Kept a passage as spoken: the edit changed too much")
                return nil
            }
            return edited + trailingWhitespace
        } catch {
            Logger.cleanup.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

private extension String {
    /// The longest run of characters at the end that all satisfy `predicate`.
    func suffix(while predicate: (Character) -> Bool) -> Substring {
        self[(lastIndex { !predicate($0) }.map(index(after:)) ?? startIndex)...]
    }
}
