import Foundation

/// Tidies raw speech-model output: strips non-speech tags and extra whitespace.
nonisolated enum TranscriptNormalizer {
    static func clean(_ transcript: String) -> String {
        let text = transcript
            // Special tokens such as "<|endoftext|>" that slip through decoding.
            .replacing(/<\|[^|]*\|>/, with: "")
            // Strip known sound labels, preserving dictated brackets such as "[draft]".
            .replacingOccurrences(
                of: #"\[(?i:BLANK_AUDIO|NO_SPEECH|SILENCE|MUSIC|APPLAUSE|LAUGHTER|NOISE)\]"#,
                with: "", options: .regularExpression
            )
            .replacing("\r\n", with: "\n")
            .replacing("\r", with: "\n")
            .replacing(/[^\S\n]+/, with: " ")
            .replacing(/[ ]*\n[ ]*/, with: "\n")
            .replacing(/\n{3,}/, with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // A transcript that is nothing but a parenthetical, e.g. "(silence)" or
        // "(upbeat music)", describes the audio rather than transcribing speech.
        if text.wholeMatch(of: /\([^)]*\)|\*[^*]*\*/) != nil {
            return ""
        }
        return text
    }
}
