import Foundation
import Testing
@testable import LocalBolo

struct MultilingualDictationTests {
    @Test func preservesExistingPreferences() throws {
        let name = "LocalBolo.Preferences.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "cleansUpTranscripts")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.speechLanguage == .english)
        #expect(settings.cleanupStyle == .conservative)
        #expect(settings.cleansUpTranscripts)

        let snapshot = settings.dictationPreferences
        settings.speechLanguage = .hindi
        settings.cleanupStyle = .polished
        let restored = AppSettings(defaults: defaults)
        #expect(restored.speechLanguage == .hindi)
        #expect(restored.cleanupStyle == .polished)
        #expect(snapshot.language == .english)
        #expect(snapshot.cleanupStyle == .conservative)
    }

    @Test(arguments: [SpeechLanguage.chinese, .hindi, .japanese, .automatic])
    func requiresAMultilingualModel(language: SpeechLanguage) {
        #expect(!SpeechModel.parakeetV2.supports(language))
        #expect(!SpeechModel.whisperBaseEnglish.supports(language))
        #expect(!SpeechModel.whisperSmallEnglish.supports(language))
        #expect(SpeechModel.whisperLargeV3Turbo.supports(language))
        #expect(SpeechModel.recommended(for: language) == .whisperLargeV3Turbo)
    }

    @Test(arguments: [SpeechLanguage.english, .chinese, .hindi, .japanese])
    func pinsTheSelectedLanguageWithoutTranslation(language: SpeechLanguage) {
        let options = WhisperBackend.decodingOptions(for: language)
        #expect(options.language == language.rawValue)
        #expect(!options.detectLanguage)
        #expect(options.task == .transcribe)
    }

    @Test func detectsOnlyInAutomaticMode() {
        let options = WhisperBackend.decodingOptions(for: .automatic)
        #expect(options.language == nil)
        #expect(options.detectLanguage)
        #expect(options.task == .transcribe)
    }

    @Test func padsShortRecordingsSoWhisperTranscribesThem() {
        let clipTime = WhisperBackend.decodingOptions(for: .japanese).windowClipTime
        let short = [Float](repeating: 0.5, count: Int(0.6 * AudioRecorder.sampleRate))
        let padded = WhisperBackend.padded(short, beyond: clipTime)
        // WhisperKit only decodes audio longer than the clip time.
        #expect(Double(padded.count) > Double(clipTime) * AudioRecorder.sampleRate)
        #expect(Array(padded.prefix(short.count)) == short)
        #expect(padded.dropFirst(short.count).allSatisfy { $0 == 0 })

        let long = [Float](repeating: 0.5, count: Int(3 * AudioRecorder.sampleRate))
        #expect(WhisperBackend.padded(long, beyond: clipTime) == long)
    }

    @Test func keepsHindiCombiningMarksInsideWords() {
        #expect(SpokenWords("मैंने रिपोर्ट भेज दी।").words.map(\.text) == ["मैंने", "रिपोर्ट", "भेज", "दी"])
    }

    @Test func longPassagesRoundTripWithoutLosingText() {
        let text = String(repeating: "First paragraph. 你好，明天见。\n\nमैंने रिपोर्ट भेज दी। 次の項目です。\n", count: 150)
        let passages = TextPassages.split(text)
        #expect(passages.count > 1)
        #expect(passages.joined() == text)
        #expect(passages.allSatisfy { !$0.isEmpty && $0.count <= TextPassages.maximumCharacters + 4 })
    }

    @Test func splitsEvenALongUnpunctuatedSentence() {
        let text = String(repeating: "これは長い文章です", count: 500)
        let passages = TextPassages.split(text)
        #expect(passages.count > 1)
        #expect(passages.joined() == text)
    }
}
