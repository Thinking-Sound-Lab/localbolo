/// Follows the language model through the dictation it's editing, so that the
/// tokens it will probably copy next can be offered to it as a draft.
///
/// An edit is mostly a copy of its input. Checking a stretch of copied tokens
/// takes the model one pass, where writing them takes one pass each, so a
/// good draft makes an edit several times faster. A wrong draft costs only a
/// little time: the model's own choice always wins.
nonisolated struct DraftCursor {
    /// The dictation's tokens.
    private let source: [Int]
    /// A token's text, lowercased and trimmed, to recognize a word whose
    /// capitalization or spacing the model changed.
    private let text: (Int) -> String

    /// The next source token the model is expected to copy.
    private(set) var position = 0
    /// False once the cursor has lost track of where the model is copying from.
    private var isAligned = true
    private var draftLength = 24

    init(source: [Int], text: @escaping (Int) -> String) {
        self.source = source
        self.text = text
    }

    /// The tokens to offer the model next.
    var draft: [Int] {
        isAligned ? Array(source[position...].prefix(draftLength)) : []
    }

    /// Records one pass of the model: it agreed with the first `accepted`
    /// tokens of the draft, then wrote `token`. `output` is everything it has
    /// written so far, ending in `token`.
    mutating func advance(accepted: Int, of offered: Int, then token: Int, output: [Int]) {
        position += accepted

        if position < source.count, source[position] == token {
            // Still copying. A draft that was right all the way earns a longer one.
            position += 1
            isAligned = true
            draftLength = accepted == offered ? min(draftLength * 2, 64) : 16
        } else {
            // The model wrote something else: work out where it carries on from.
            let resumed = resumePosition(after: token, output: output)
            isAligned = resumed != nil
            position = resumed ?? position
            draftLength = 16
        }
    }

    private func resumePosition(after token: Int, output: [Int]) -> Int? {
        // The last few tokens written, found in the dictation, closest to where we were.
        for length in [3, 2] where output.count >= length {
            let tail = output.suffix(length)
            let ends = source.indices.dropLast(length - 1)
                .filter { source[$0..<$0 + length].elementsEqual(tail) }
                .map { $0 + length }
            if let nearest = ends.min(by: { abs($0 - position) < abs($1 - position) }) {
                return nearest
            }
        }

        let written = text(token)
        guard written.contains(where: { $0.isLetter || $0.isNumber }) else {
            // Punctuation the model added or changed. The next word is still the one expected.
            let replacesPunctuation = position < source.count
                && !text(source[position]).contains(where: { $0.isLetter || $0.isNumber })
            return replacesPunctuation ? position + 1 : position
        }

        // A word from further on means the model dropped what came before it.
        let ahead = source.indices[position...].prefix(48)
        return ahead.first { source[$0] == token || text(source[$0]) == written }.map { $0 + 1 }
    }
}
