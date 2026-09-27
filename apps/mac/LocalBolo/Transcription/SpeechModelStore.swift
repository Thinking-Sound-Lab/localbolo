import Foundation

typealias SpeechModelStore = LocalModelStore<SpeechModelLoader>

extension SpeechModelStore {
    convenience init(defaults: UserDefaults = .standard) {
        self.init(
            loader: SpeechModelLoader(directory: ModelStorage.directory),
            activeModelKey: "activeModel",
            defaults: defaults
        )
    }

    /// The loaded speech model, or `nil` until it's ready to transcribe.
    var transcriber: (any Transcriber)? { loaded }

    /// Why dictation can't run yet, phrased for the pill.
    var readinessMessage: String {
        switch status(of: activeModel) {
        case .downloading: "Speech model is still downloading"
        case .loading: "Speech model is still loading"
        case .failed: "Speech model failed to load"
        default: "Download a speech model in Settings"
        }
    }
}

/// Routes each speech model to the engine that runs it.
nonisolated struct SpeechModelLoader: ModelLoader {
    private let parakeet: ParakeetBackend
    private let whisper: WhisperBackend

    init(directory: URL) {
        parakeet = ParakeetBackend(directory: directory.appending(path: "Parakeet", directoryHint: .isDirectory))
        whisper = WhisperBackend(directory: directory.appending(path: "Whisper", directoryHint: .isDirectory))
    }

    func isInstalled(_ model: SpeechModel) -> Bool {
        backend(for: model).isInstalled(model)
    }

    func download(_ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        try await backend(for: model).download(model, progress: progress)
    }

    func load(_ model: SpeechModel) async throws -> any Transcriber {
        try await backend(for: model).load(model)
    }

    func remove(_ model: SpeechModel) throws {
        try backend(for: model).remove(model)
    }

    private func backend(for model: SpeechModel) -> any ModelLoader<SpeechModel, any Transcriber> {
        switch model.engine {
        case .parakeet: parakeet
        case .whisper: whisper
        }
    }
}
