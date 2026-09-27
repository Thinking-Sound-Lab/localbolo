import AVFoundation
import Foundation
import Testing
@testable import LocalBolo

/// End-to-end checks that download real models, load them onto the Neural
/// Engine and transcribe synthesized speech.
///
/// These download hundreds of megabytes, so they only run when asked:
///
///     TEST_RUNNER_LOCALBOLO_INTEGRATION=1 xcodebuild test -scheme LocalBolo …
///
/// Models are stored in the app's normal location, so the app reuses them.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LOCALBOLO_INTEGRATION"] == "1"), .serialized)
struct TranscriptionIntegrationTests {
    private static let sentence = "The quick brown fox jumps over the lazy dog."

    @Test(arguments: [SpeechModel.parakeetV2, .whisperBaseEnglish])
    func transcribesSpokenEnglish(model: SpeechModel) async throws {
        let store = SpeechModelStore(defaults: try #require(UserDefaults(suiteName: "LocalBoloIntegrationTests")))
        await store.activate(model)
        #expect(store.status(of: model) == .ready)

        let transcriber = try #require(store.transcriber)
        let transcript = try await transcriber.transcribe(try Self.synthesizeSpeech(Self.sentence))
        let words = TranscriptNormalizer.clean(transcript).lowercased()

        #expect(words.contains("quick brown fox"))
        #expect(words.contains("lazy dog"))
    }

    /// Speaks `text` with the system voice into 16 kHz mono samples.
    private static func synthesizeSpeech(_ text: String) throws -> [Float] {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: file) }

        let say = Process()
        say.executableURL = URL(filePath: "/usr/bin/say")
        say.arguments = ["-o", file.path, "--file-format=WAVE", "--data-format=LEF32@16000", text]
        try say.run()
        say.waitUntilExit()

        let audioFile = try AVAudioFile(forReading: file)
        let buffer = try #require(AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ))
        try audioFile.read(into: buffer)
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
}
