import AVFoundation
import Darwin
import Foundation
import MLX
import Testing
@preconcurrency import WhisperKit
@testable import LocalBolo

/// Opt-in, serial, real-model benchmarks. No downloads or changes to app preferences.
/// Use an optimized build and forward LOCALBOLO_BENCHMARKS=1 with TEST_RUNNER_.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LOCALBOLO_BENCHMARKS"] == "1"), .serialized)
struct PerformanceBenchmarks {
    /// Dictation after the app has sat idle, the case back-to-back runs can't
    /// see: macOS pages idle model memory out within about half a minute.
    /// Rotates warm-up strategies so drift in system memory affects each equally.
    @Test func idleWake() async throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = URL(filePath: try #require(environment["LOCALBOLO_BENCHMARK_DIRECTORY"]))
        let repetitions = max(1, min(10, Int(environment["LOCALBOLO_BENCHMARK_REPETITIONS"] ?? "4") ?? 4))
        let idle = Double(environment["LOCALBOLO_BENCHMARK_IDLE_SECONDS"] ?? "45") ?? 45
        var records: [Record] = []
        defer {
            let report = Report(label: "idle-wake", repetitions: repetitions, os: ProcessInfo.processInfo.operatingSystemVersionString,
                                processors: ProcessInfo.processInfo.processorCount, memoryBytes: ProcessInfo.processInfo.physicalMemory,
                                records: records)
            if let data = try? JSONEncoder().encode(report) {
                try? data.write(to: directory.appending(path: "idle-wake-\(Int(idle))s.json"), options: .atomic)
            }
        }
        let defaults = try #require(UserDefaults(suiteName: "LocalBolo.Benchmark.\(UUID())"))
        let speech = SpeechModelStore(defaults: defaults)
        let cleanup = CleanupModelStore(defaults: defaults)
        await speech.activate(.whisperLargeV3Turbo)
        await cleanup.activate(.qwen3_1_7B)
        let transcriber = try #require(speech.transcriber)
        let editor = try #require(cleanup.loaded)
        let fixture = Fixture(id: "ja", language: .japanese, voice: "Kyoko", text: "明日の朝、会社で会議があります。資料を持ってきてください。")
        let samples = try synthesize(fixture, directory: directory)
        let processing = TranscriptCleanup(settings: AppSettings(defaults: defaults), models: cleanup)
        let preferences = DictationPreferences(language: fixture.language, cleanupEnabled: true, cleanupStyle: .polished)
        _ = try await transcriber.transcribe(samples, language: fixture.language)
        _ = try await editor.edit("昨日は会社に行きますた", style: .polished, language: fixture.language)

        // "app" is what the app starts once fn has been held: both models, concurrently.
        let strategies = ["none", "app"]
        for iteration in 0..<repetitions {
            for offset in 0..<strategies.count {
                let strategy = strategies[(iteration + offset) % strategies.count]
                try await Task.sleep(for: .seconds(idle))
                let warmStart = ContinuousClock.now
                if strategy == "app" {
                    async let speechReady: Void = transcriber.warmUp()
                    await processing.warmUp(preferences: preferences)
                    try await speechReady
                }
                records.append(record("idle\(Int(idle)).\(strategy).warmup", iteration: iteration, seconds: elapsed(warmStart)))
                let started = ContinuousClock.now
                let recognized = try await transcriber.transcribe(samples, language: fixture.language)
                let asrSeconds = elapsed(started)
                let original = TranscriptNormalizer.clean(recognized.text)
                let editStart = ContinuousClock.now
                let edited = try await editor.edit(original, style: .polished, language: fixture.language)
                let editSeconds = elapsed(editStart)
                records.append(record("idle\(Int(idle)).\(strategy).asr", iteration: iteration, seconds: asrSeconds, output: original))
                records.append(record("idle\(Int(idle)).\(strategy).edit", iteration: iteration, seconds: editSeconds, output: edited))
                records.append(record("idle\(Int(idle)).\(strategy).pipeline", iteration: iteration, seconds: elapsed(started), output: edited))
                print("BENCHMARK idle \(strategy) \(iteration): warmup=\(records[records.count - 4].seconds) asr=\(asrSeconds) edit=\(editSeconds)")
            }
        }
        cleanup.unload()
        speech.unload()
    }

    /// Breaks Whisper Turbo's time into stages and compares decoding settings.
    @Test func whisperStages() async throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = URL(filePath: try #require(environment["LOCALBOLO_BENCHMARK_DIRECTORY"]))
        let repetitions = 6
        let model = SpeechModel.whisperLargeV3Turbo
        let base = ModelStorage.directory.appending(path: "Whisper", directoryHint: .isDirectory)
        let folder = HubApiWrapper(downloadBase: base)
            .localRepoLocation(HubApiWrapper.Repo(id: "argmaxinc/whisperkit-coreml"))
            .appending(path: model.rawValue, directoryHint: .isDirectory)
        let fixtures = [
            Fixture(id: "zh", language: .chinese, voice: "Tingting", text: "明天上午十点我们在办公室开会。请带上电脑和报告。"),
            Fixture(id: "hi", language: .hindi, voice: "Lekha", text: "कल सुबह हमारी बैठक है। कृपया रिपोर्ट भेज दें।"),
            Fixture(id: "ja", language: .japanese, voice: "Kyoko", text: "明日の朝、会社で会議があります。資料を持ってきてください。"),
            Fixture(id: "auto-ja", language: .automatic, voice: "Kyoko", text: "明日の朝、会社で会議があります。資料を持ってきてください。"),
        ]
        // The GPU encoder measured 3.7x slower than the Neural Engine on an M1, so only the decoder is compared.
        let variants: [(String, ModelComputeOptions?)] = [("ane", nil), ("gpu-decoder", ModelComputeOptions(textDecoderCompute: .cpuAndGPU))]
        for (computeName, compute) in variants {
            let loadStart = ContinuousClock.now
            let whisper = try await WhisperKit(WhisperKitConfig(
                model: model.rawValue, downloadBase: base, modelFolder: folder.path, tokenizerFolder: base,
                computeOptions: compute, verbose: false, logLevel: .error, load: true, download: false
            ))
            print("BENCHMARK whisper \(computeName) load=\(elapsed(loadStart))")
            var warmOptions = WhisperBackend.decodingOptions(for: .english)
            warmOptions.sampleLength = 1
            warmOptions.temperatureFallbackCount = 0
            let silence = WhisperBackend.padded([], beyond: warmOptions.windowClipTime)
            for iteration in 0..<3 {
                let started = ContinuousClock.now
                _ = try await whisper.transcribe(audioArray: silence, decodeOptions: warmOptions)
                print("BENCHMARK whisper \(computeName) warmup[\(iteration)]=\(elapsed(started)) footprint=\(record("", iteration: 0, seconds: 0).footprintBytes ?? 0)")
            }
            for fixture in fixtures {
                let samples = try synthesize(fixture, directory: directory)
                // VAD chunking measured no different from none for audio under 30 seconds.
                for (settingName, options) in [("current", WhisperBackend.decodingOptions(for: fixture.language))] {
                    for iteration in 0..<repetitions {
                        let started = ContinuousClock.now
                        let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)
                        let total = elapsed(started)
                        let t = try #require(results.first).timings
                        print("BENCHMARK whisper \(computeName) \(settingName) \(fixture.id)[\(iteration)] total=\(String(format: "%.3f", total)) "
                              + "mel=\(String(format: "%.3f", t.logmels)) enc=\(String(format: "%.3f", t.encoding)) "
                              + "decLoop=\(String(format: "%.3f", t.decodingLoop)) pred=\(String(format: "%.3f", t.decodingPredictions)) "
                              + "tokens=\(Int(t.totalDecodingLoops)) encRuns=\(Int(t.totalEncodingRuns)) "
                              + "fallbacks=\(Int(t.totalDecodingFallbacks)) windows=\(Int(t.totalDecodingWindows)) "
                              + "text=\(results.map(\.text).joined(separator: " ")) lang=\(results.map(\.language))")
                    }
                }
            }
            await whisper.unloadModels()
        }
    }

    @Test func dictationPipeline() async throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = URL(filePath: try #require(environment["LOCALBOLO_BENCHMARK_DIRECTORY"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repetitions = max(3, min(30, Int(environment["LOCALBOLO_BENCHMARK_REPETITIONS"] ?? "10") ?? 10))
        let label = environment["LOCALBOLO_BENCHMARK_LABEL"] ?? "run"
        var records: [Record] = []
        defer {
            let report = Report(label: label, repetitions: repetitions, os: ProcessInfo.processInfo.operatingSystemVersionString,
                                processors: ProcessInfo.processInfo.processorCount, memoryBytes: ProcessInfo.processInfo.physicalMemory,
                                records: records)
            if let data = try? JSONEncoder().encode(report) {
                try? data.write(to: directory.appending(path: "\(label).json"), options: .atomic)
            }
        }

        try await benchmarkSpeech(model: .parakeetV2, cleanupModel: .qwen25_1_5B, style: .conservative,
                                  cases: [Fixture(id: "en", language: .english, voice: "Samantha",
                                                  text: "The quick brown fox jumps over the lazy dog. Let's meet on Friday at seven. Sorry, at eight.")],
                                  directory: directory, repetitions: repetitions, records: &records)
        Memory.clearCache()
        try await benchmarkSpeech(model: .whisperLargeV3Turbo, cleanupModel: .qwen3_1_7B, style: .polished,
                                  cases: [
                                    Fixture(id: "zh", language: .chinese, voice: "Tingting", text: "明天上午十点我们在办公室开会。请带上电脑和报告。"),
                                    Fixture(id: "hi", language: .hindi, voice: "Lekha", text: "कल सुबह हमारी बैठक है। कृपया रिपोर्ट भेज दें।"),
                                    Fixture(id: "ja", language: .japanese, voice: "Kyoko", text: "明日の朝、会社で会議があります。資料を持ってきてください。"),
                                    Fixture(id: "auto-ja", language: .automatic, voice: "Kyoko", text: "明日の朝、会社で会議があります。資料を持ってきてください。"),
                                  ], directory: directory, repetitions: repetitions, records: &records)
        Memory.clearCache()
        print("BENCHMARK finished \(label): \(records.count) records; \(directory.path)")
    }

    private func benchmarkSpeech(
        model: SpeechModel, cleanupModel: CleanupModel, style: CleanupStyle, cases: [Fixture],
        directory: URL, repetitions: Int, records: inout [Record]
    ) async throws {
        let defaults = try #require(UserDefaults(suiteName: "LocalBolo.Benchmark.\(UUID())"))
        let speech = SpeechModelStore(defaults: defaults)
        let cleanup = CleanupModelStore(defaults: defaults)
        try #require(speech.isInstalled(model), "Install the speech model in Settings before benchmarking.")
        try #require(cleanup.isInstalled(cleanupModel), "Install the cleanup model in Settings before benchmarking.")
        let speechStart = ContinuousClock.now
        await speech.activate(model)
        records.append(record("load.\(model.rawValue)", iteration: 0, seconds: elapsed(speechStart)))
        let transcriber = try #require(speech.transcriber)
        let cleanupStart = ContinuousClock.now
        await cleanup.activate(cleanupModel)
        records.append(record("load.\(cleanupModel.rawValue)", iteration: 0, seconds: elapsed(cleanupStart)))
        let editor = try #require(cleanup.loaded)
        // The app's own warm-up and cleanup path, so each build is measured as it ships.
        let processing = TranscriptCleanup(settings: AppSettings(defaults: defaults), models: cleanup)

        for fixture in cases {
            let samples = try synthesize(fixture, directory: directory)
            let audioSeconds = Double(samples.count) / AudioRecorder.sampleRate
            let preferences = DictationPreferences(language: fixture.language, cleanupEnabled: true, cleanupStyle: style)
            for iteration in 0..<repetitions {
                // This is the work started while fn is held, outside text-ready latency.
                let speechWarmStart = ContinuousClock.now
                try await transcriber.warmUp()
                records.append(record("speechwarmup.\(fixture.id)", iteration: iteration, seconds: elapsed(speechWarmStart)))
                let warmStart = ContinuousClock.now
                await processing.warmUp(preferences: preferences)
                records.append(record("warmup.\(fixture.id)", iteration: iteration, seconds: elapsed(warmStart)))

                let started = ContinuousClock.now
                let recognized = try await transcriber.transcribe(samples, language: fixture.language)
                let asrSeconds = elapsed(started)
                let original = TranscriptNormalizer.clean(recognized.text)
                let cleanupStart = ContinuousClock.now
                let text = await processing.apply(to: original, preferences: preferences, detectedLanguage: recognized.language)
                let cleanupSeconds = elapsed(cleanupStart)
                let total = elapsed(started)
                #expect(!text.isEmpty)
                records.append(record("asr.\(fixture.id)", iteration: iteration, seconds: asrSeconds, audioSeconds: audioSeconds, output: original))
                records.append(record("cleanup.\(fixture.id)", iteration: iteration, seconds: cleanupSeconds, output: text))
                records.append(record("pipeline.\(fixture.id)", iteration: iteration, seconds: total, audioSeconds: audioSeconds, output: text))
                print("BENCHMARK \(fixture.id) \(iteration): asr=\(asrSeconds) cleanup=\(cleanupSeconds) total=\(total)")
            }
        }
        if style == .polished {
            let texts: [(String, SpeechLanguage, String)] = [
                ("en", .english, "she have two meeting tomorrow"),
                ("en-long", .english, "The engineering team have completed the migration yesterday and they is preparing the final report for tomorrow. We cannot approve the 250 dollar invoice until Priya reviews the contract. Please bring first milk second rice third tea. New paragraph. The launch is on Friday and we need two volunteers."),
                ("zh", .chinese, "明天我们要开会请带上电脑"),
                ("hi", .hindi, "रीना ने मुझे किताब दिया"),
                ("ja", .japanese, "私は昨日映画を見ますた"),
                ("mixed", .hindi, "आज team meeting है please send the agenda"),
            ]
            for (id, language, original) in texts {
                for iteration in 0..<repetitions {
                    let started = ContinuousClock.now
                    let edited = try await editor.edit(original, style: .polished, language: language)
                    let inferenceSeconds = elapsed(started)
                    let policyStart = ContinuousClock.now
                    let accepted = PolishedTextPolicy.accepts(edited, original: original, language: language.rawValue)
                    records.append(record("edit.\(id)", iteration: iteration, seconds: inferenceSeconds, output: edited, accepted: accepted))
                    records.append(record("policy.\(id)", iteration: iteration, seconds: elapsed(policyStart), accepted: accepted))
                }
            }
            for iteration in 0..<repetitions {
                for (id, language, original) in texts where id != "en-long" {
                    let started = ContinuousClock.now
                    let edited = try await editor.edit(original, style: .polished, language: language)
                    records.append(record("switch.\(id)", iteration: iteration, seconds: elapsed(started), output: edited,
                                          accepted: PolishedTextPolicy.accepts(edited, original: original, language: language.rawValue)))
                }
            }
        }
        cleanup.unload()
        speech.unload()
    }

    private func synthesize(_ fixture: Fixture, directory: URL) throws -> [Float] {
        let file = directory.appending(path: "audio-\(fixture.id).wav")
        if !FileManager.default.fileExists(atPath: file.path) {
            let say = Process()
            say.executableURL = URL(filePath: "/usr/bin/say")
            say.arguments = ["-v", fixture.voice, "-o", file.path, "--file-format=WAVE", "--data-format=LEF32@16000", fixture.text]
            try say.run()
            say.waitUntilExit()
            try #require(say.terminationStatus == 0)
        }
        let audio = try AVAudioFile(forReading: file)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(audio.length)))
        try audio.read(into: buffer)
        return Array(UnsafeBufferPointer(start: try #require(buffer.floatChannelData?[0]), count: Int(buffer.frameLength)))
    }

    private func elapsed(_ start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }

    private func record(_ name: String, iteration: Int, seconds: Double, audioSeconds: Double? = nil,
                        output: String? = nil, accepted: Bool? = nil) -> Record {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return Record(name: name, iteration: iteration, seconds: seconds, audioSeconds: audioSeconds, output: output, accepted: accepted,
                      footprintBytes: status == KERN_SUCCESS ? info.phys_footprint : nil,
                      activeBytes: Memory.activeMemory, cacheBytes: Memory.cacheMemory, peakBytes: Memory.peakMemory,
                      thermalState: ProcessInfo.processInfo.thermalState.rawValue)
    }

    private struct Fixture {
        let id: String
        let language: SpeechLanguage
        let voice: String
        let text: String
    }

    private struct Record: Encodable {
        let name: String
        let iteration: Int
        let seconds: Double
        let audioSeconds: Double?
        let output: String?
        let accepted: Bool?
        let footprintBytes: UInt64?
        let activeBytes: Int
        let cacheBytes: Int
        let peakBytes: Int
        let thermalState: Int
    }

    private struct Report: Encodable {
        let label: String
        let repetitions: Int
        let os: String
        let processors: Int
        let memoryBytes: UInt64
        let records: [Record]
    }
}
