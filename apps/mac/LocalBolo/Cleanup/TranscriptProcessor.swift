import Foundation

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
                if let edited = try? await edit(content), TranscriptEditPolicy.isFaithful(edited, to: content) {
                    sentences.replaceSubrange(passage, with: [edited + trailingWhitespace(original)])
                }
            }
            return sentences.joined()

        case .polished:
            var output = ""
            for passage in TextPassages.split(transcript) {
                let content = passage.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else { output += passage; continue }
                if let edited = try? await edit(content), PolishedTextPolicy.accepts(edited, original: content, language: language) {
                    output += edited.trimmingCharacters(in: .whitespacesAndNewlines) + trailingWhitespace(passage)
                } else {
                    output += passage
                }
            }
            return output
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
