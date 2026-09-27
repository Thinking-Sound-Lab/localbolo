import FluidAudio
import Foundation

/// Runs NVIDIA Parakeet TDT models on the Neural Engine using FluidAudio.
nonisolated struct ParakeetBackend: ModelLoader {
    /// Parent folder for every Parakeet model this backend manages.
    let directory: URL

    func isInstalled(_ model: SpeechModel) -> Bool {
        let (version, repo) = Self.variant(for: model)
        return AsrModels.modelsExist(at: folder(for: repo), version: version)
    }

    func download(_ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        let (version, repo) = Self.variant(for: model)
        try await AsrModels.download(to: folder(for: repo), version: version) { update in
            progress(update.fractionCompleted)
        }
    }

    func load(_ model: SpeechModel) async throws -> any Transcriber {
        let (version, repo) = Self.variant(for: model)
        let models = try await AsrModels.load(from: folder(for: repo), version: version)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        let transcriber = ParakeetTranscriber(manager: manager)
        try await transcriber.warmUp()
        return transcriber
    }

    func remove(_ model: SpeechModel) throws {
        let (_, repo) = Self.variant(for: model)
        try FileManager.default.removeItem(at: folder(for: repo))
    }

    /// FluidAudio stores a model's files in a sibling folder named after its
    /// Hugging Face repo, so pointing it at that exact folder keeps them together.
    private func folder(for repo: Repo) -> URL {
        directory.appending(path: repo.folderName, directoryHint: .isDirectory)
    }

    private static func variant(for model: SpeechModel) -> (AsrModelVersion, Repo) {
        switch model {
        case .parakeetV2: (.v2, .parakeetV2)
        default: preconditionFailure("\(model) is not a Parakeet model")
        }
    }
}

private actor ParakeetTranscriber: Transcriber {
    /// Parakeet rejects clips shorter than this, so short recordings are
    /// padded with silence.
    private static let minimumSampleCount = Int(AudioRecorder.sampleRate)

    private let manager: AsrManager

    init(manager: AsrManager) {
        self.manager = manager
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        var audio = samples
        if audio.count < Self.minimumSampleCount {
            audio.append(contentsOf: repeatElement(0, count: Self.minimumSampleCount - audio.count))
        }

        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(audio, decoderState: &decoderState).text
    }
}
