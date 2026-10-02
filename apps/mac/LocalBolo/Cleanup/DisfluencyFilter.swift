import Foundation

/// Removes the slips of speech that need no judgement: sounds like "um" and
/// "uh", and words doubled by accident ("the the", "can you can you").
///
/// These are plain rules, so they take no time and can't change what was said.
/// Anything that needs understanding, such as a self-correction, is left to
/// the language model.
nonisolated enum DisfluencyFilter {
    private static let fillers: Set<String> = ["um", "umm", "uh", "uhh", "uhm", "er", "erm"]

    /// Words people double by accident. Words that are also doubled on
    /// purpose ("very very", "had had", "that that", "no no") are left out.
    private static let stutteredWords: Set<String> = [
        "i", "we", "you", "he", "she", "it", "they", "the", "a", "an", "and", "but", "or", "to", "of", "in",
        "on", "at", "for", "with", "from", "by", "if", "when", "this", "can", "could", "will", "would",
        "should", "do", "does", "did", "is", "are", "was", "were", "am", "have", "has", "my", "your", "our",
        "his", "her", "their", "its", "it's", "i'm", "i'll", "i've", "we're", "we'll", "let's", "what", "how",
        "as", "not", "be", "about", "because",
    ]

    /// A doubled phrase is a stutter only if it starts like the beginning of
    /// a clause, which keeps "New York, New York" and "thank you, thank you".
    private static let phraseStarters = stutteredWords.union(
        ["that", "so", "there", "then", "which", "who", "where", "why", "please"]
    )

    static func clean(_ transcript: String) -> String {
        collapsingStutters(in: removingFillers(from: transcript))
    }

    // MARK: - Fillers

    static func removingFillers(from transcript: String) -> String {
        var spoken = SpokenWords(transcript)
        var kept: [SpokenWords.Word] = []
        var capitalizesNext = false

        var index = 0
        while index < spoken.words.count {
            var word = spoken.words[index]
            guard fillers.contains(word.normalized) else {
                if capitalizesNext {
                    word.text = word.text.capitalizedIfLowercase
                    capitalizesNext = false
                }
                kept.append(word)
                index += 1
                continue
            }

            // A run of fillers ("um, uh,") is removed as one.
            while index + 1 < spoken.words.count,
                  fillers.contains(spoken.words[index + 1].normalized),
                  !spoken.words[index].separator.endsSentence {
                index += 1
            }
            let after = spoken.words[index].separator
            let before = kept.last?.separator ?? spoken.leading
            let isLastWord = index == spoken.words.count - 1

            let joined: String
            if kept.isEmpty || before.endsSentence {
                // "Um, can you" becomes "Can you".
                joined = before
                capitalizesNext = true
            } else if after.endsSentence || isLastWord {
                // "so, um." becomes "so."
                let closing = after.replacing(/^[,\s]+/, with: "")
                joined = closing.isEmpty || closing.prefixMatch(of: /[.!?…]/) != nil ? closing : " " + closing
            } else if before.contains(","), after.contains(",") {
                // The commas were around the filler: "I was, um, wondering" becomes "I was wondering".
                joined = " "
            } else if !before.isBlank {
                joined = before
            } else if !after.isBlank {
                joined = after
            } else {
                joined = " "
            }

            if kept.isEmpty {
                spoken.leading = joined
            } else {
                kept[kept.count - 1].separator = joined
            }
            index += 1
        }

        spoken.words = kept
        return spoken.text
    }

    // MARK: - Stutters

    static func collapsingStutters(in transcript: String) -> String {
        var spoken = SpokenWords(transcript)

        var index = 0
        while index < spoken.words.count {
            // Longest phrase first, so "can you can you" isn't mistaken for two single words.
            let length = [3, 2, 1].first { isStutter(at: index, length: $0, in: spoken.words) }
            guard let length else {
                index += 1
                continue
            }
            // Keep the first copy's words and what followed the second.
            let trailing = spoken.words[index + 2 * length - 1].separator
            spoken.words.removeSubrange(index + length..<index + 2 * length)
            spoken.words[index + length - 1].separator = trailing
        }
        return spoken.text
    }

    /// Whether the `length` words at `index` are said twice in a row.
    private static func isStutter(at index: Int, length: Int, in words: [SpokenWords.Word]) -> Bool {
        guard index + 2 * length <= words.count else { return false }
        let first = words[index..<index + length].map(\.normalized)
        let second = words[index + length..<index + 2 * length].map(\.normalized)
        guard first == second else { return false }

        // Repeated digits are usually meant, as in a phone number.
        guard !first.contains(where: { $0.contains(where: \.isNumber) }) else { return false }
        // Across a sentence or clause boundary it's a new start, not a stutter.
        guard words[index..<index + 2 * length - 1].allSatisfy({ !$0.separator.contains(/[.!?…;:]/) }) else {
            return false
        }
        return (length == 1 ? stutteredWords : phraseStarters).contains(first[0])
    }
}

private nonisolated extension String {
    var isBlank: Bool {
        allSatisfy(\.isWhitespace)
    }

    /// Capitalizes an all-lowercase word, leaving ones like "iPhone" alone.
    var capitalizedIfLowercase: String {
        guard let first, self == lowercased() else { return self }
        return first.uppercased() + dropFirst()
    }
}
