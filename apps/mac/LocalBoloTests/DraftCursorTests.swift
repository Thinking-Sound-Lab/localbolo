import Testing
@testable import LocalBolo

/// Tokens here are small integers, and each one's "text" is given by `vocabulary`.
struct DraftCursorTests {
    private static let vocabulary: [Int: String] = [
        1: "send", 2: "it", 3: "to", 4: "alex", 5: ".", 6: "sorry", 7: ",", 8: "jordan",
        // The same words as 1 and 3, capitalized: other tokens with the same text.
        11: "send", 13: "to",
    ]

    private func cursor(over source: [Int]) -> DraftCursor {
        DraftCursor(source: source) { Self.vocabulary[$0] ?? "" }
    }

    @Test func offersTheStartOfTheDictationFirst() {
        #expect(cursor(over: [1, 2, 3, 4, 5]).draft == [1, 2, 3, 4, 5])
    }

    @Test func movesPastWhatTheModelCopied() {
        var cursor = cursor(over: [1, 2, 3, 4, 5])
        // The model agreed with "send it", then wrote "to" itself.
        cursor.advance(accepted: 2, of: 2, then: 3, output: [1, 2, 3])
        #expect(cursor.draft == [4, 5])
    }

    @Test func skipsWhatTheModelDropped() {
        // "send it to alex . sorry , to jordan ."
        var cursor = cursor(over: [1, 2, 3, 4, 5, 6, 7, 3, 8, 5])
        // The model copied "send it to", then wrote "jordan": it dropped "alex. sorry, to".
        cursor.advance(accepted: 3, of: 5, then: 8, output: [1, 2, 3, 8])
        #expect(cursor.draft == [5])
    }

    @Test func recognizesAWordWhoseCapitalizationChanged() {
        // "sorry , send it": the model drops "sorry," and capitalizes "send".
        var cursor = cursor(over: [6, 7, 1, 2])
        cursor.advance(accepted: 0, of: 4, then: 11, output: [11])
        #expect(cursor.draft == [2])
    }

    @Test func staysPutWhenTheModelAddsPunctuation() {
        var cursor = cursor(over: [1, 2, 3, 4])
        // The model copied "send it", then added a comma.
        cursor.advance(accepted: 2, of: 4, then: 7, output: [1, 2, 7])
        #expect(cursor.draft == [3, 4])
    }

    @Test func stopsDraftingWhenTheModelWritesSomethingElse() {
        var cursor = cursor(over: [1, 2, 3, 4])
        // "jordan" isn't in the dictation at all.
        cursor.advance(accepted: 1, of: 4, then: 8, output: [1, 8])
        #expect(cursor.draft.isEmpty)

        // Once the model is copying again, drafts resume from the matching place.
        cursor.advance(accepted: 0, of: 0, then: 3, output: [1, 8, 3])
        cursor.advance(accepted: 0, of: 0, then: 4, output: [1, 8, 3, 4])
        #expect(cursor.position == 4)
    }
}
