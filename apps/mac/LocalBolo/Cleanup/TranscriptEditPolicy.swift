import Foundation

/// Decides which sentences the language model should edit, and whether its
/// edit can be trusted.
nonisolated enum TranscriptEditPolicy {
    /// Phrases that can mean "ignore what I just said".
    private static let correctionPhrases = [
        "sorry", "i mean", "i meant", "actually", "wait", "no wait", "scratch that", "strike that",
        "never mind", "nevermind", "make that", "rather", "or rather", "correction", "let me rephrase",
        "no no", "oops",
    ].map { $0.split(separator: " ").map(String.init) }

    /// Filler that can go on its own, with nothing taken back.
    private static let fillerCues = [["you", "know"]]

    // MARK: - What to edit

    /// The sentences of a transcript. Each keeps the whitespace after it, so
    /// joining them gives the transcript back.
    static func sentences(in transcript: String) -> [String] {
        var sentences: [String] = []
        var start = transcript.startIndex

        // Sentence punctuation, then a space, then a capital or a digit.
        for match in transcript.matches(of: #/[.!?…]+["'”’)]*\s+(?=["'“‘(]*[\p{Lu}\p{N}])/#) {
            // A period after an abbreviation ("p.m.", "Mrs.") doesn't end the sentence.
            if match.output.hasPrefix("."),
               let lastWord = words(in: String(transcript[start..<match.range.lowerBound])).last,
               lastWord.count == 1 || abbreviations.contains(lastWord) {
                continue
            }
            sentences.append(String(transcript[start..<match.range.upperBound]))
            start = match.range.upperBound
        }
        if start < transcript.endIndex {
            sentences.append(String(transcript[start...]))
        }
        return sentences
    }

    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs", "etc", "inc", "ltd",
    ]

    /// The stretches of sentences worth sending to the model: those where the
    /// speaker may have corrected themselves.
    ///
    /// Most dictations have none, and in a long one only the sentences around
    /// a correction are edited. That keeps cleanup fast however long the
    /// dictation is, and leaves every other sentence exactly as spoken.
    static func passagesToEdit(among sentences: [String]) -> [ClosedRange<Int>] {
        var passages: [ClosedRange<Int>] = []

        for (index, sentence) in sentences.enumerated() {
            let spoken = Spoken(sentence)
            // Nothing comes before a dictation's first word, so a cue there takes nothing back.
            let corrections = correctionCues(in: spoken).filter { index > 0 || $0.lowerBound > 0 }
            let hasFiller = !starts(of: fillerCues, in: spoken.words).isEmpty
            guard !corrections.isEmpty || hasFiller else { continue }

            var first = index
            var last = index
            // A sentence that opens with the cue takes back something in the one before:
            // "at nine. No, at ten."
            if index > 0, corrections.contains(where: { $0.lowerBound < 3 }) {
                first = index - 1
            }
            // "Scratch that." on its own: include what follows, so the edit isn't empty.
            if spoken.words.count <= 3, index + 1 < sentences.count {
                last = index + 1
            }

            if let previous = passages.last, first <= previous.upperBound {
                passages[passages.count - 1] = previous.lowerBound...max(last, previous.upperBound)
            } else {
                passages.append(first...last)
            }
        }
        return passages
    }

    /// Where the speaker may be taking something back: a correction phrase
    /// said after a pause, as in "at nine, sorry, at ten".
    ///
    /// Without the pause the same words are meant as they're said ("we had
    /// to wait", "it's actually faster"), so they don't count. "No" also has
    /// to be followed by a comma, to tell "No, at ten" from "no idea".
    private static func correctionCues(in spoken: Spoken) -> [Range<Int>] {
        let phrases = correctionPhrases.flatMap { phrase in
            starts(of: [phrase], in: spoken.words).map { $0..<$0 + phrase.count }
        }
        let nos = spoken.words.indices
            .filter { spoken.words[$0] == "no" && spoken.precedesComma[$0] }
            .map { $0..<$0 + 1 }
        return (phrases + nos).filter { spoken.followsPause[$0.lowerBound] }
    }

    // MARK: - Whether to trust an edit

    /// An edit is trusted only if every change it makes is one a filler or a
    /// self-correction explains:
    ///
    /// - It may drop filler, a doubled word, or words the speaker took back
    ///   ("at 9, sorry, at 10" loses "at 9, sorry"), but never the correction.
    /// - It may swap in the speaker's own correction for an earlier word
    ///   ("to Sam by Friday, sorry, to Kim" becomes "to Kim by Friday").
    ///
    /// Anything else, such as new words, rewording, a dropped clause or an
    /// answer to a dictated question, means the model went beyond editing.
    static func isFaithful(_ edited: String, to original: String) -> Bool {
        let editedWords = words(in: edited)
        let spoken = Spoken(original)
        let originalWords = spoken.words
        guard !editedWords.isEmpty else { return false }
        guard editedWords != originalWords else { return true }

        // A correction replaces part of a sentence, not most of it.
        guard originalWords.count < 6 || Double(editedWords.count) >= Double(originalWords.count) * 0.35 else {
            return false
        }

        // Walk the gaps between the words both texts share.
        var removals: [Range<Int>] = []
        var replacements: [(removed: Range<Int>, inserted: [String])] = []
        var previous = (original: -1, edited: -1)
        for match in sharedWords(originalWords, editedWords) + [(originalWords.count, editedWords.count)] {
            let removed = previous.original + 1..<match.0
            let inserted = Array(editedWords[previous.edited + 1..<match.1])
            previous = match

            if !inserted.isEmpty {
                // Words that replace nothing were made up by the model.
                guard !removed.isEmpty else { return false }
                replacements.append((removed, inserted))
            } else if !removed.isEmpty {
                removals.append(removed)
            }
        }

        let cues = correctionCues(in: spoken)

        // Swapped-in words must be the speaker's own, said after a correction phrase later on.
        var corrections: Set<Range<Int>> = []
        for (removed, inserted) in replacements {
            guard inserted.count <= 4, removed.count <= inserted.count + 2 else { return false }
            let correction = removals.first {
                $0.lowerBound >= removed.upperBound && restates(inserted, in: $0, of: originalWords, cues: cues)
            }
            guard let correction else { return false }
            corrections.insert(correction)
        }

        // "At nine, sorry, at ten" must not become "at nine".
        if replacements.isEmpty, keepsWithdrawnVersion(editedWords, of: originalWords) { return false }

        return removals.allSatisfy { removal in
            let run = Array(originalWords[removal])
            let after = originalWords[removal.upperBound...].prefix(run.count)
            let before = originalWords[..<removal.lowerBound].suffix(run.count)
            let isDoubled = after.elementsEqual(run) || before.elementsEqual(run)
            return corrections.contains(removal) || isDoubled || isOnlyFiller(run)
                || isTakenBack(removal, cues: cues)
        }
    }

    /// Whether `run` is nothing but filler phrases.
    private static func isOnlyFiller(_ run: [String]) -> Bool {
        var rest = run[...]
        while !rest.isEmpty {
            guard let cue = fillerCues.first(where: { rest.starts(with: $0) }) else { return false }
            rest = rest.dropFirst(cue.count)
        }
        return true
    }

    /// Whether the removed words read as something the speaker withdrew:
    /// something said, then a correction phrase, then at most a few words
    /// restarting the sentence.
    private static func isTakenBack(_ removal: Range<Int>, cues: [Range<Int>]) -> Bool {
        let cues = cues.filter { removal.lowerBound <= $0.lowerBound && $0.upperBound <= removal.upperBound }
        guard let first = cues.map(\.lowerBound).min(), let last = cues.map(\.upperBound).max() else {
            return false
        }
        return first > removal.lowerBound && removal.upperBound - last <= 3
    }

    /// Whether an edit that only removes words kept what the speaker took
    /// back and dropped the correction instead.
    ///
    /// Matching the edit's words as early in the original as possible shows
    /// that as a removed run starting with the correction phrase.
    private static func keepsWithdrawnVersion(_ edited: [String], of original: [String]) -> Bool {
        var remaining = edited[...]
        var removedRuns: [[String]] = [[]]
        for word in original {
            if word == remaining.first {
                remaining = remaining.dropFirst()
                removedRuns.append([])
            } else {
                removedRuns[removedRuns.count - 1].append(word)
            }
        }
        return removedRuns.contains { run in
            run.first == "no" || correctionPhrases.contains { run.starts(with: $0) }
        }
    }

    /// Whether the removed words are a correction phrase followed by
    /// `inserted`, with at most a few other words.
    private static func restates(
        _ inserted: [String],
        in removal: Range<Int>,
        of original: [String],
        cues: [Range<Int>]
    ) -> Bool {
        cues.contains { cue in
            guard cue.lowerBound == removal.lowerBound, cue.upperBound <= removal.upperBound else { return false }
            let rest = Array(original[cue.upperBound..<removal.upperBound])
            return rest.count - inserted.count <= 3 && !starts(of: [inserted], in: rest).isEmpty
        }
    }

    // MARK: - Words

    /// Lowercased words, ignoring punctuation and apostrophes ("Let's" and "lets" match).
    static func words(in text: String) -> [String] {
        Spoken(text).words
    }

    /// A text's words as the policy compares them, with the pauses around them.
    private struct Spoken {
        let words: [String]
        /// Whether each word starts the text or comes after punctuation.
        let followsPause: [Bool]
        let precedesComma: [Bool]

        init(_ text: String) {
            let spoken = SpokenWords(text).words
            words = spoken.map { $0.normalized.replacing("'", with: "") }
            followsPause = spoken.indices.map { $0 == 0 || spoken[$0 - 1].separator.marksPause }
            precedesComma = spoken.map { $0.separator.contains(",") }
        }
    }

    /// Where any of `phrases` begins in `words`.
    private static func starts(of phrases: [[String]], in words: [String]) -> [Int] {
        phrases.flatMap { phrase in
            words.indices.filter { words[$0...].starts(with: phrase) }
        }
    }

    /// The words `original` and `edited` have in common, in order, as pairs
    /// of positions (a longest common subsequence).
    ///
    /// Words are matched as late in `original` as possible, because a
    /// correction keeps the later of two versions.
    private static func sharedWords(_ original: [String], _ edited: [String]) -> [(Int, Int)] {
        var lengths = Array(repeating: Array(repeating: 0, count: edited.count + 1), count: original.count + 1)
        for i in original.indices {
            for j in edited.indices {
                lengths[i + 1][j + 1] = original[i] == edited[j]
                    ? lengths[i][j] + 1
                    : max(lengths[i][j + 1], lengths[i + 1][j])
            }
        }

        var pairs: [(Int, Int)] = []
        var i = original.count
        var j = edited.count
        while i > 0, j > 0 {
            if original[i - 1] == edited[j - 1] {
                pairs.append((i - 1, j - 1))
                i -= 1
                j -= 1
            } else if lengths[i - 1][j] >= lengths[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return pairs.reversed()
    }
}
