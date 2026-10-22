import AVFoundation
import Foundation
import MLX
import Testing
@testable import LocalBolo

/// Real Core ML/MLX inference, opt-in because it downloads about 1.6 GB.
/// Run separately from other model integration suites on an 8 GB Mac:
/// TEST_RUNNER_LOCALBOLO_MULTILINGUAL_INTEGRATION=1 xcodebuild test ...
///     -only-testing:LocalBoloTests/MultilingualIntegrationTests
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LOCALBOLO_MULTILINGUAL_INTEGRATION"] == "1"), .serialized)
struct MultilingualIntegrationTests {
    @Test func recognizesTheSelectedLanguages() async throws {
        let store = SpeechModelStore(defaults: try isolatedDefaults())
        await store.activate(.whisperLargeV3Turbo)
        let transcriber = try #require(store.transcriber)
        let cleanupDefaults = try isolatedDefaults()
        let settings = AppSettings(defaults: cleanupDefaults)
        settings.cleansUpTranscripts = true
        settings.cleanupStyle = .polished
        let cleanupModels = CleanupModelStore(defaults: cleanupDefaults)
        await cleanupModels.activate(.qwen3_1_7B)
        let cleanup = TranscriptCleanup(settings: settings, models: cleanupModels)
        let cases: [(SpeechLanguage, String, String, String)] = [
            (.chinese, "Tingting", "明天上午十点我们在办公室开会。", "办公室"),
            (.hindi, "Lekha", "कल सुबह हमारी बैठक है। कृपया रिपोर्ट भेज दें।", "रिपोर्ट"),
            (.japanese, "Kyoko", "明日の朝、会社で会議があります。", "会議"),
        ]
        for (language, voice, sentence, expected) in cases {
            let samples = try synthesize(sentence, voice: voice)
            let started = ContinuousClock.now
            let result = try await transcriber.transcribe(samples, language: language)
            print("ASR \(language.rawValue): \(ContinuousClock.now - started); \(result.text)")
            #expect(result.language == language.rawValue)
            #expect(result.text.contains(expected))
            #expect(!result.text.isEmpty)
            let preferences = DictationPreferences(language: language, cleanupEnabled: true, cleanupStyle: .polished)
            let polished = await cleanup.apply(
                to: TranscriptNormalizer.clean(result.text), preferences: preferences, detectedLanguage: result.language
            )
            print("Dictation \(language.rawValue): \(polished)")
            #expect(polished.contains(expected))
            #expect(!polished.isEmpty)
        }

        let auto = try await transcriber.transcribe(try synthesize("明日は会社に行きます。", voice: "Kyoko"), language: .automatic)
        #expect(auto.language == "ja")
        #expect(auto.text.contains("会社"))

        // WhisperKit skips audio of a second or less unless it's padded.
        let quick = try synthesize("はい", voice: "Kyoko")
        #expect(Double(quick.count) < AudioRecorder.sampleRate)
        let reply = try await transcriber.transcribe(quick, language: .japanese)
        print("ASR quick reply (\(Double(quick.count) / AudioRecorder.sampleRate)s): \(reply.text)")
        #expect(reply.text.contains("はい"))
        print("MLX active=\(Memory.activeMemory) cache=\(Memory.cacheMemory) peak=\(Memory.peakMemory)")
        cleanupModels.unload()
        store.unload()
    }

    @Test func polishesHeldOutMultilingualDictations() async throws {
        let loader = CleanupModelLoader(directory: ModelStorage.directory.appending(path: "Cleanup", directoryHint: .isDirectory))
        let store = LocalModelStore(loader: loader, activeModelKey: "model", defaults: try isolatedDefaults())
        await store.activate(.qwen3_1_7B)
        let editor = try #require(store.loaded)

        let cases: [(SpeechLanguage, String, [String])] = [
            (.english, "she have two meeting tomorrow", ["She has two meetings tomorrow."]),
            (.chinese, "明天我们要开会请带上电脑", ["明天我们要开会，请带上电脑。", "明天我们要开会。请带上电脑。"]),
            (.hindi, "रीना ने मुझे किताब दिया", ["रीना ने मुझे किताब दी।", "रीना ने मुझे किताब दी है।"]),
            (.japanese, "私は昨日映画を見ますた", ["私は昨日映画を見ました。"]),
        ]
        for (language, original, acceptable) in cases {
            let started = ContinuousClock.now
            let raw = try await editor.edit(original, style: .polished, language: language)
            let accepted = PolishedTextPolicy.accepts(raw, original: original, language: language.rawValue)
            print("Polished \(language.rawValue): \(ContinuousClock.now - started); accepted=\(accepted); \(raw)")
            #expect(accepted)
            #expect(acceptable.contains(raw))
        }

        let listOriginal = "Please bring first milk second rice third tea."
        let list = try await editor.edit(listOriginal, style: .polished, language: .english)
        print("Polished list: \(list)")
        #expect(PolishedTextPolicy.accepts(list, original: listOriginal, language: "en"))
        #expect(list.contains("\n- "))
        #expect(["milk", "rice", "tea"].allSatisfy { list.localizedCaseInsensitiveContains($0) })

        let paragraphOriginal = "The launch is on Friday. New paragraph. We need two volunteers."
        let paragraphs = try await editor.edit(paragraphOriginal, style: .polished, language: .english)
        print("Polished paragraphs: \(paragraphs)")
        #expect(PolishedTextPolicy.accepts(paragraphs, original: paragraphOriginal, language: "en"))
        #expect(paragraphs.contains("\n\n"))

        let mixedOriginal = "आज team meeting है please send the agenda"
        let mixed = try await editor.edit(mixedOriginal, style: .polished, language: .hindi)
        print("Polished mixed: \(mixed)")
        #expect(PolishedTextPolicy.accepts(mixed, original: mixedOriginal, language: "hi"))
        #expect(mixed.contains("आज"))
        #expect(mixed.contains("team meeting"))
        #expect(mixed.contains("agenda"))
        #expect(mixed.hasSuffix("agenda."))
        #expect(!mixed.contains("。"))

        // Whether or not the model applies a spoken correction, the final version is never lost.
        let corrections: [(SpeechLanguage, String, String)] = [
            (.chinese, "明天9点见，不对，10点见", "10点"),
            (.hindi, "कल 5 बजे, नहीं, 6 बजे मिलते हैं", "6 बजे"),
            (.japanese, "明日は9時、いや、10時に行きます", "10時"),
        ]
        for (language, spoken, final) in corrections {
            let result = await TranscriptProcessor.apply(to: spoken, style: .polished, language: language.rawValue) {
                try await editor.edit($0, style: .polished, language: language)
            }
            print("Polished correction \(language.rawValue): \(result)")
            #expect(result.contains(final))
        }

        // Warm prompt state must not mix styles, languages or prior dictations.
        let original = "The invoice is 250 dollars and we cannot approve it."
        let unchanged = try await editor.edit(original, style: .polished, language: .english)
        #expect(PolishedTextPolicy.accepts(unchanged, original: original, language: "en"))
        #expect(unchanged.contains("250"))
        #expect(unchanged.contains("cannot"))
        store.unload()
    }

    @Test func rewindsSharedPromptAfterWarmupsAndLanguageChanges() async throws {
        let store = CleanupModelStore(defaults: try isolatedDefaults())
        await store.activate(.qwen3_1_7B)
        let editor = try #require(store.loaded)
        let original = "The invoice is 250 dollars and we cannot approve it."
        let expected = try await editor.edit(original, style: .polished, language: .english)
        for language in [SpeechLanguage.chinese, .hindi, .japanese, .automatic] {
            try await editor.warmUp(style: .polished, language: language)
            _ = try await editor.edit("कल meeting है please report भेज देना", style: .polished, language: language)
            try await editor.warmUp(style: .polished, language: .english)
            let repeated = try await editor.edit(original, style: .polished, language: .english)
            #expect(repeated == expected)
        }

        try await editor.warmUp(style: .conservative)
        let corrected = try await editor.edit("Let's have dinner on Friday at 7. Sorry, at 8.")
        #expect(corrected.contains("at 8"))
        #expect(!corrected.contains("at 7"))
        let repeated = try await editor.edit(original, style: .polished, language: .english)
        #expect(repeated == expected)
        store.unload()
    }

    /// Runs `PolishedCorrectionEvaluation.json`: spoken self-corrections, and
    /// controls where the same words aren't corrections. Check this before
    /// changing the Polished prompt, the policy or the model.
    ///
    /// A correction is applied when only the final version remains, kept when
    /// both do (safe, but not what was asked for), and lost when the final
    /// version is missing. A control must keep every listed phrase.
    @Test func evaluatesSpokenCorrections() async throws {
        struct Case: Codable {
            let kind: String
            let language: String
            let dictation: String
            let keep: [String]
            let drop: [String]
        }
        struct Outcome: Codable {
            let item: Case
            let raw: String
            let pasted: String
            let result: String
        }
        let file = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "PolishedCorrectionEvaluation.json")
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: file))
        let store = CleanupModelStore(defaults: try isolatedDefaults())
        await store.activate(.qwen3_1_7B)
        let editor = try #require(store.loaded)

        var outcomes: [Outcome] = []
        for item in cases {
            let language = try #require(SpeechLanguage(rawValue: item.language))
            let raw = try await editor.edit(item.dictation, style: .polished, language: language)
            let pasted = await TranscriptProcessor.apply(to: item.dictation, style: .polished, language: item.language) { _ in raw }
            let keeps = item.keep.allSatisfy { pasted.localizedCaseInsensitiveContains($0) }
            let drops = !item.drop.contains { pasted.localizedCaseInsensitiveContains($0) }
            let result = switch (item.kind, keeps, drops) {
            case ("control", true, _): "ok"
            case ("control", false, _): "harmed"
            case (_, false, _): "lost"
            case (_, true, true): "applied"
            default: "kept"
            }
            print("CORRECTION \(item.language) \(item.kind) \(result): \(item.dictation) -> raw: \(raw) -> pasted: \(pasted)")
            outcomes.append(Outcome(item: item, raw: raw, pasted: pasted, result: result))
        }
        store.unload()

        let count = { (result: String) in outcomes.filter { $0.result == result }.count }
        let corrections = cases.filter { $0.kind == "correction" }.count
        print("CORRECTIONS applied=\(count("applied"))/\(corrections) kept=\(count("kept")) lost=\(count("lost")) "
              + "controls ok=\(count("ok"))/\(cases.count - corrections)")
        if let directory = ProcessInfo.processInfo.environment["LOCALBOLO_BENCHMARK_DIRECTORY"] {
            let label = ProcessInfo.processInfo.environment["LOCALBOLO_BENCHMARK_LABEL"] ?? "run"
            let url = URL(filePath: directory).appending(path: "\(label)-corrections.json")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(outcomes).write(to: url, options: .atomic)
        }
        // Never paste a dictation that lost what the speaker finally said or meant.
        #expect(count("lost") == 0)
        #expect(count("harmed") == 0)
    }

    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "LocalBolo.MultilingualIntegration.\(UUID())"))
    }

    private func synthesize(_ text: String, voice: String) throws -> [Float] {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: file) }
        let say = Process()
        say.executableURL = URL(filePath: "/usr/bin/say")
        say.arguments = ["-v", voice, "-o", file.path, "--file-format=WAVE", "--data-format=LEF32@16000", text]
        try say.run()
        say.waitUntilExit()
        #expect(say.terminationStatus == 0)
        let audio = try AVAudioFile(forReading: file)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(audio.length)))
        try audio.read(into: buffer)
        let channel = try #require(buffer.floatChannelData?[0])
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
