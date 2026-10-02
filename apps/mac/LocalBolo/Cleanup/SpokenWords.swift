import Foundation

/// A transcript as its words and the spaces and punctuation between them, so
/// words can be removed without disturbing the rest.
nonisolated struct SpokenWords {
    struct Word {
        var text: String
        /// The spaces and punctuation up to the next word.
        var separator: String

        /// The word as it's compared against word lists: lowercased, with a plain apostrophe.
        var normalized: String {
            text.lowercased().replacing("’", with: "'")
        }

        /// Written in capitals, like "ER" or "IT". These are names, not the
        /// small words they happen to spell.
        var isAcronym: Bool {
            text.count > 1 && text == text.uppercased() && text.contains(where: \.isLetter)
        }
    }

    /// Whatever comes before the first word.
    var leading: String
    var words: [Word]

    init(_ text: String) {
        var words: [Word] = []
        var leading = ""
        var cursor = text.startIndex

        // Apostrophes stay inside a word, so "it's" and "o'clock" are one word each.
        for match in text.matches(of: /[\p{L}\p{N}]+(?:['’]\p{L}+)*/) {
            let separator = String(text[cursor..<match.range.lowerBound])
            if words.isEmpty {
                leading = separator
            } else {
                words[words.count - 1].separator = separator
            }
            words.append(Word(text: String(match.output), separator: ""))
            cursor = match.range.upperBound
        }

        let rest = String(text[cursor...])
        if words.isEmpty {
            leading = rest
        } else {
            words[words.count - 1].separator = rest
        }
        self.leading = leading
        self.words = words
    }

    var text: String {
        leading + words.map { $0.text + $0.separator }.joined()
    }
}

nonisolated extension String {
    /// Whether this separator closes a sentence.
    var endsSentence: Bool {
        contains(/[.!?…]/)
    }

    /// Whether this separator marks a pause in speech: any punctuation a
    /// speech model writes where the speaker stopped for a moment.
    var marksPause: Bool {
        contains(/[,.;:!?…—–]/)
    }
}
