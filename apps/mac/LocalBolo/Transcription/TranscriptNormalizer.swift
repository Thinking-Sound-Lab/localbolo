import Foundation

/// Tidies raw speech-model output: strips non-speech tags and extra whitespace.
nonisolated enum TranscriptNormalizer {
    static func clean(_ transcript: String) -> String {
        let text = transcript
            // Special tokens such as "<|endoftext|>" that slip through decoding.
            .replacing(/<\|[^|]*\|>/, with: "")
            // Whisper labels non-speech audio with tags like "[BLANK_AUDIO]" or "[Music]".
            .replacing(/\[[^\]]*\]/, with: "")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // A transcript that is nothing but a parenthetical, e.g. "(silence)" or
        // "(upbeat music)", describes the audio rather than transcribing speech.
        if text.wholeMatch(of: /\([^)]*\)|\*[^*]*\*/) != nil {
            return ""
        }
        return text
    }
}
