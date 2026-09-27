import Foundation

/// Decides when the language model should edit a transcript, and whether its
/// edit can be trusted.
nonisolated enum TranscriptEditPolicy {
    /// Words and phrases that signal filler or a self-correction.
    private static let cues = [
        "um", "uh", "uhm", "er", "erm", "hmm", "you know", "i mean", "i meant", "sorry",
        "actually", "wait", "scratch that", "never mind", "nevermind", "make that",
        "rather", "correction", "let me rephrase", "no no",
    ]

    /// Most dictations have nothing to fix, and skipping the model for them
    /// saves about a second each. Only transcripts with filler words,
    /// repeated words or correction phrases are edited.
    static func needsEditing(_ transcript: String) -> Bool {
        let words = words(in: transcript)
        guard words.count >= 3 else { return false }

        let hasRepeatedWord = zip(words, words.dropFirst()).contains { $0 == $1 }
        let paddedText = " \(words.joined(separator: " ")) "
        return hasRepeatedWord || cues.contains { paddedText.contains(" \($0) ") }
    }

    /// An edit is trusted only if it reads like a cleanup of what was said:
    /// it may drop words (fillers, the part being corrected) but must not
    /// introduce new ones, and must keep a reasonable share of the original.
    /// This catches the model answering a question or following an
    /// instruction in the dictation instead of editing it.
    static func isFaithful(_ edited: String, to original: String) -> Bool {
        let editedWords = words(in: edited)
        let originalWords = words(in: original)
        guard !editedWords.isEmpty else { return false }

        // Allow a little rewording, such as "five" becoming "5".
        let vocabulary = Set(originalWords)
        let newWordCount = editedWords.count { !vocabulary.contains($0) }
        guard newWordCount <= max(1, editedWords.count / 5) else { return false }

        // A correction replaces part of a sentence, not most of it.
        return originalWords.count < 6 || Double(editedWords.count) >= Double(originalWords.count) * 0.35
    }

    /// Lowercased words, ignoring punctuation and apostrophes ("Let's" and "lets" match).
    static func words(in text: String) -> [String] {
        text.lowercased()
            .replacing(/['’]/, with: "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}
