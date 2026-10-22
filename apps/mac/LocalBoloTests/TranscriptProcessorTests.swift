import Foundation
import Testing
@testable import LocalBolo

struct TranscriptProcessorTests {
    @Test func rendersPlainTextParagraphs() {
        #expect(TranscriptEditor.normalizedReply("First.  \nSecond.", style: .polished) == "First.\n\nSecond.")
        #expect(TranscriptEditor.normalizedReply("First.  \nSecond.", style: .conservative) == "First.  \nSecond.")
    }

    @Test(arguments: [("hi", "कल meeting है"), ("ja", "明日は会議です"), ("zh", "明天有会议"), ("en", "कल meeting है")])
    func conservativeCleanupLeavesOtherLanguagesAlone(language: String, transcript: String) async {
        let result = await TranscriptProcessor.apply(to: transcript, style: .conservative, language: language) { _ in
            Issue.record("English correction rules must not edit this dictation")
            return "Changed"
        }
        #expect(result == transcript)
    }

    @Test func unknownLanguageBypassesEnglishRules() async {
        let result = await TranscriptProcessor.apply(to: "um 10 Uhr", style: .conservative, language: nil) { $0 }
        #expect(result == "um 10 Uhr")
    }

    @Test func polishesWithoutAnEnglishCorrectionCue() async {
        let result = await TranscriptProcessor.apply(to: "he go to office yesterday", style: .polished, language: "en") { _ in
            "He went to the office yesterday."
        }
        #expect(result == "He went to the office yesterday.")
    }

    @Test func preservesParagraphsAndListFormatting() async {
        let original = "Please bring first apples second oranges third bread."
        let formatted = "Please bring:\n- Apples\n- Oranges\n- Bread"
        let result = await TranscriptProcessor.apply(to: original, style: .polished, language: "en") { _ in formatted }
        #expect(result == formatted)
    }

    @Test func failedValidationKeepsTheOriginal() async {
        let original = "Send the 250 dollar invoice to Priya."
        let result = await TranscriptProcessor.apply(to: original, style: .polished, language: "en") { _ in
            "Send the 350 dollar invoice to Alex."
        }
        #expect(result == original)
    }

    @Test func failedOrTruncatedInferenceKeepsEveryPassage() async {
        let original = String(repeating: "This is a complete sentence.\n\n", count: 150)
        let result = await TranscriptProcessor.apply(to: original, style: .polished, language: "en") { _ in
            throw EditorError.outputTooLong
        }
        #expect(result == original)
    }

    @Test func splitsPassagesTooLongForTheModel() async {
        // Within the character limit, but over the editor's token limit.
        let sentence = "मैंने कल रिपोर्ट भेज दिया"
        let original = Array(repeating: sentence, count: 40).joined(separator: "। ")
        #expect(original.count <= TextPassages.maximumCharacters)
        let result = await TranscriptProcessor.apply(to: original, style: .polished, language: "hi") { passage in
            guard passage.count <= 400 else { throw EditorError.inputTooLong }
            return passage.replacing("भेज दिया", with: "भेज दी")
        }
        #expect(!result.contains("भेज दिया"))
        #expect(result.components(separatedBy: "भेज दी").count == 41)
    }

    @Test func conservativeRulesStillRunWithoutAModel() async {
        let result = await TranscriptProcessor.apply(to: "Um, the the meeting is tomorrow.", style: .conservative, language: "en") { _ in
            throw EditorError.cacheCannotRewind
        }
        #expect(result == "The meeting is tomorrow.")
    }
}
