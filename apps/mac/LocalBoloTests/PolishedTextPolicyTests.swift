import Testing
@testable import LocalBolo

struct PolishedTextPolicyTests {
    @Test(arguments: [
        ("he go to office yesterday", "He went to the office yesterday.", "en"),
        ("I am agree with the report.", "I agree with the report.", "en"),
        ("Send the 250 dollar invoice to Priya.", "Send the 250 dollar invoice to Priya.", "en"),
        ("我昨天去公司了今天在家工作", "我昨天去公司了。今天在家工作。", "zh"),
        ("मैंने कल रिपोर्ट भेज दिया", "मैंने कल रिपोर्ट भेज दी।", "hi"),
        ("昨日は会社に行きますた", "昨日は会社に行きました。", "ja"),
        ("कल meeting है please report भेज देना", "कल meeting है। Please report भेज देना।", "hi"),
        ("Please bring first apples second oranges third bread.", "Please bring:\n- Apples\n- Oranges\n- Bread", "en"),
        ("Use https://example.com", "Use https://example.com.", "en"),
        ("The invoice is 250 dollars and we cannot approve it.", "The invoice is $250 and we cannot approve it.", "en"),
        ("Hello. New paragraph. Goodbye.", "Hello.\n\nGoodbye.", "en"),
    ])
    func permitsGrammarAndFormatting(original: String, edited: String, language: String) {
        #expect(PolishedTextPolicy.accepts(edited, original: original, language: language))
    }

    @Test(arguments: [
        ("Send the 250 dollar invoice.", "Send the 350 dollar invoice.", "en"),
        ("Send the $250 invoice.", "Send the €250 invoice.", "en"),
        ("The invoice is $250.", "The invoice is 250.", "en"),
        ("The invoices are $250 and €300.", "The invoices are €250 and $300.", "en"),
        ("We need five chairs.", "We need ten chairs.", "en"),
        ("Send it on Monday.", "Send it on Tuesday.", "en"),
        ("Send the report to Priya.", "Send the report to Alex.", "en"),
        ("We cannot approve the invoice.", "We can approve the invoice.", "en"),
        ("We approved the invoice.", "We rejected the invoice.", "en"),
        ("Send the report tomorrow.", "Send the report yesterday.", "en"),
        ("报告还没有批准", "报告已经批准。", "zh"),
        ("मैं नहीं आऊंगा", "मैं आऊंगा।", "hi"),
        ("明日は行きません", "明日は行きます。", "ja"),
        ("मैंने रिपोर्ट भेज दी", "I sent the report.", "hi"),
        ("Can you send the report?", "Here is the corrected text: Can you send the report?", "en"),
        ("Call Priya tomorrow.", "", "en"),
        ("Read the report and send the invoice to the office tomorrow.", "Read the report.", "en"),
        ("Use https://example.com", "Use https://other.example.com.", "en"),
    ])
    func rejectsObviousContentChanges(original: String, edited: String, language: String) {
        #expect(!PolishedTextPolicy.accepts(edited, original: original, language: language))
    }

    @Test func keepsExplicitEnglishCorrections() {
        #expect(PolishedTextPolicy.accepts("Meet at 10 p.m.", original: "Meet at 9 p.m., sorry, at 10 p.m.", language: "en"))
    }
}
