import Foundation
import NaturalLanguage

/// Bounded passages keep long dictations from growing the editor's temporary
/// tensors without limit. Splitting never drops text, punctuation or whitespace.
nonisolated enum TextPassages {
    static let maximumCharacters = 1_200

    static func split(_ text: String) -> [String] {
        guard text.count > maximumCharacters else { return [text] }

        let range = text.startIndex..<text.endIndex
        let sentences = NLTokenizer(unit: .sentence)
        sentences.string = text
        let sentenceEnds = sentences.tokens(for: range).map(\.upperBound)
        let words = NLTokenizer(unit: .word)
        words.string = text
        let wordEnds = words.tokens(for: range).map(\.upperBound)

        var passages: [String] = []
        var start = text.startIndex
        while let limit = text.index(start, offsetBy: maximumCharacters, limitedBy: text.endIndex), limit < text.endIndex {
            let minimum = text.index(start, offsetBy: maximumCharacters / 3)
            var end = sentenceEnds.last { $0 >= minimum && $0 <= limit }
                ?? wordEnds.last { $0 >= minimum && $0 <= limit }
                ?? limit
            while end < text.endIndex, text[end].isWhitespace {
                end = text.index(after: end)
            }
            passages.append(String(text[start..<end]))
            start = end
        }
        if start < text.endIndex { passages.append(String(text[start...])) }
        return passages
    }

    /// Unicode-aware word boundaries, including scripts without spaces.
    static func words(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).compactMap { range in
            let word = String(text[range]).lowercased()
            return word.contains(where: { $0.isLetter || $0.isNumber }) ? word : nil
        }
    }
}
