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
        let transcriber = WhisperTranscriber(whisperKit: try await WhisperKit(config))
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
}

private actor WhisperTranscriber: Transcriber {
    /// Tuned for short English dictation: no language detection, no
    /// timestamps, and voice-activity chunking for recordings over 30 seconds.
    private static let options = DecodingOptions(
        task: .transcribe,
        language: "en",
        temperature: 0,
        usePrefillPrompt: true,
        detectLanguage: false,
        skipSpecialTokens: true,
        withoutTimestamps: true,
        suppressBlank: true,
        chunkingStrategy: .vad
    )

    private let whisperKit: WhisperKit

    init(whisperKit: WhisperKit) {
        self.whisperKit = whisperKit
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await whisperKit
            .transcribe(audioArray: samples, decodeOptions: Self.options)
            .map(\.text)
            .joined(separator: " ")
    }
}
