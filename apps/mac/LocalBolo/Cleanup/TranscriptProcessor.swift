import Foundation
import os

/// Routing and validation are independent of GPU inference so the actual
/// dictation pipeline can be checked without downloading a model.
nonisolated enum TranscriptProcessor {
    static func apply(
        to transcript: String,
        style: CleanupStyle,
        language: String?,
        edit: @Sendable (String) async throws -> String
    ) async -> String {
        switch style {
        case .conservative:
            // Even an English-detected mixed-script transcript must bypass the
            // English filler list (for example, German "um" is a real word).
            guard language == "en", !containsNonLatinLetters(transcript) else { return transcript }
            let tidied = DisfluencyFilter.clean(transcript)
            var sentences = TranscriptEditPolicy.sentences(in: tidied)
            for passage in TranscriptEditPolicy.passagesToEdit(among: sentences).reversed() {
                let original = sentences[passage].joined()
                let content = original.trimmingCharacters(in: .whitespacesAndNewlines)
                do {
                    let edited = try await edit(content)
                    guard TranscriptEditPolicy.isFaithful(edited, to: content) else {
                        Logger.cleanup.info("Kept a passage as spoken: the edit changed too much")
                        continue
                    }
                    sentences.replaceSubrange(passage, with: [edited + trailingWhitespace(original)])
                } catch {
                    Logger.cleanup.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            return sentences.joined()

        case .polished:
            var output = ""
            for passage in TextPassages.split(transcript) {
                output += await polish(passage, language: language, edit: edit)
            }
            return output
        }
    }

    /// Polishes one passage, or keeps it as spoken.
    ///
    /// Passages are bounded in characters, but the model's limit is in tokens,
    /// and Hindi or Japanese can use several per character. A passage over it
    /// is split in two and each half tried on its own.
    private static func polish(
        _ passage: String,
        language: String?,
        edit: @Sendable (String) async throws -> String
    ) async -> String {
        let content = passage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return passage }
        do {
            let edited = try await edit(content)
            guard PolishedTextPolicy.accepts(edited, original: content, language: language) else {
                Logger.cleanup.info("Kept a passage as spoken: the edit failed validation")
                return passage
            }
            return edited.trimmingCharacters(in: .whitespacesAndNewlines) + trailingWhitespace(passage)
        } catch EditorError.inputTooLong where passage.count >= 100 {
            let halves = TextPassages.split(passage, maximumCharacters: passage.count / 2)
            var output = ""
            for half in halves {
                output += await polish(half, language: language, edit: edit)
            }
            return output
        } catch {
            Logger.cleanup.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
            return passage
        }
    }

    static func containsNonLatinLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar) && scalar.value > 0x024F
        }
    }

    private static func trailingWhitespace(_ text: String) -> Substring {
        text[(text.lastIndex { !$0.isWhitespace }.map(text.index(after:)) ?? text.startIndex)...]
    }
}
