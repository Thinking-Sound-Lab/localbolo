import Foundation
@preconcurrency import WhisperKit

/// Runs OpenAI Whisper models on the Neural Engine using WhisperKit.
nonisolated struct WhisperBackend: ModelLoader {
    private static let repository = HubApiWrapper.Repo(id: "argmaxinc/whisperkit-coreml")

    /// Parent folder for every Whisper model (and tokenizer) this backend manages.
    let directory: URL

    func isInstalled(_ model: SpeechModel) -> Bool {
        let folder = modelFolder(for: model)
        return ["MelSpectrogram", "AudioEncoder", "TextDecoder"].allSatisfy { component in
            FileManager.default.fileExists(atPath: folder.appending(path: "\(component).mlmodelc").path)
        }
    }

    func download(_ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        _ = try await WhisperKit.download(variant: model.rawValue, downloadBase: directory) { update in
            progress(update.fractionCompleted)
        }
    }

    func load(_ model: SpeechModel) async throws -> any Transcriber {
        let config = WhisperKitConfig(
            model: model.rawValue,
            downloadBase: directory,
            modelFolder: modelFolder(for: model).path,
            // The tokenizer is fetched on first load and cached next to the models.
            tokenizerFolder: directory,
            verbose: false,
            logLevel: .error,
            load: true,
            download: false
        )
        let transcriber = WhisperTranscriber(whisperKit: try await WhisperKit(config), model: model)
        try await transcriber.warmUp()
        return transcriber
    }

    func remove(_ model: SpeechModel) throws {
        try FileManager.default.removeItem(at: modelFolder(for: model))
    }

    private func modelFolder(for model: SpeechModel) -> URL {
        HubApiWrapper(downloadBase: directory)
            .localRepoLocation(Self.repository)
            .appending(path: model.rawValue, directoryHint: .isDirectory)
    }

    static func decodingOptions(for language: SpeechLanguage) -> DecodingOptions {
        DecodingOptions(
            task: .transcribe,
            language: language.decodingCode,
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: language == .automatic,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            suppressBlank: true,
            chunkingStrategy: .vad
        )
    }

    /// WhisperKit skips audio no longer than `windowClipTime` (a second), so a
    /// quick "はい" came back empty and warming up on a second of silence never
    /// woke the model. Whisper pads every window with silence to 30 seconds
    /// anyway, so a little more of it at the end doesn't change what it hears.
    static func padded(_ samples: [Float], beyond clipTime: Float) -> [Float] {
        let minimum = Int((Double(clipTime) + 0.1) * AudioRecorder.sampleRate)
        guard samples.count < minimum else { return samples }
        return samples + repeatElement(0, count: minimum - samples.count)
    }
}

private actor WhisperTranscriber: Transcriber {
    private let whisperKit: WhisperKit
    private let model: SpeechModel
    private var lastRun: ContinuousClock.Instant?

    init(whisperKit: WhisperKit, model: SpeechModel) {
        self.whisperKit = whisperKit
        self.model = model
    }

    func transcribe(_ samples: [Float], language: SpeechLanguage) async throws -> SpeechTranscript {
        guard model.supports(language) else { throw TranscriptionError.unsupportedLanguage }
        let options = WhisperBackend.decodingOptions(for: language)
        let results = try await whisperKit.transcribe(
            audioArray: WhisperBackend.padded(samples, beyond: options.windowClipTime), decodeOptions: options
        )
        lastRun = .now
        let languages = Set(results.map(\.language))
        return SpeechTranscript(
            text: results.map(\.text).joined(separator: " "),
            language: languages.count == 1 ? languages.first : nil
        )
    }

    /// Wakes the encoder and decoder, which go cold when idle like any model.
    ///
    /// The encoder always reads a 30-second window, so this costs about a
    /// second of Neural Engine time however short the audio is. A dictation
    /// released before it finishes waits for it, so skip it when the model
    /// has just run and is still awake.
    func warmUp() async throws {
        if let lastRun, lastRun.duration(to: .now) < .seconds(15) { return }
        var options = WhisperBackend.decodingOptions(for: .english)
        // One sampled token after the forced prompt already runs every decoder
        // layer, and silence must not trigger retries at higher temperatures.
        options.sampleLength = 1
        options.temperatureFallbackCount = 0
        _ = try await whisperKit.transcribe(
            audioArray: WhisperBackend.padded([], beyond: options.windowClipTime), decodeOptions: options
        )
        lastRun = .now
    }
}
