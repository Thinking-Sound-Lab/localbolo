import Foundation
import MLX
import MLXLLM
import MLXLMCommon
@preconcurrency import WhisperKit

typealias CleanupModelStore = LocalModelStore<CleanupModel, TranscriptEditor>

extension CleanupModelStore {
    convenience init(defaults: UserDefaults = .standard) {
        self.init(
            loader: CleanupModelLoader(directory: ModelStorage.directory.appending(path: "Cleanup", directoryHint: .isDirectory)),
            activeModelKey: "activeCleanupModel",
            defaults: defaults
        )
    }
}

/// Downloads MLX language models from Hugging Face and loads them onto the GPU.
nonisolated struct CleanupModelLoader: ModelLoader {
    /// Everything MLX needs to load a model: weights, config and tokenizer.
    private static let requiredFiles = ["*.json", "*.safetensors", "*.txt", "*.jinja"]

    /// Parent folder for every cleanup model.
    let directory: URL

    init(directory: URL) {
        self.directory = directory
        // MLX keeps freed GPU buffers around for reuse. Cap that cache so an
        // idle model doesn't hold on to memory other apps could use.
        Memory.cacheLimit = 32 * 1024 * 1024
    }

    func isInstalled(_ model: CleanupModel) -> Bool {
        let folder = modelFolder(for: model)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return files.contains("config.json") && files.contains("tokenizer.json")
            && files.contains { $0.hasSuffix(".safetensors") }
    }

    func download(_ model: CleanupModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        // The Hugging Face client bundled with WhisperKit, so both kinds of
        // model are downloaded and stored the same way.
        _ = try await HubApiWrapper(downloadBase: directory).snapshot(
            from: HubApiWrapper.Repo(id: model.rawValue),
            matching: Self.requiredFiles
        ) { update in
            progress(update.fractionCompleted)
        }
    }

    func load(_ model: CleanupModel) async throws -> TranscriptEditor {
        let container = try await LLMModelFactory.shared.loadContainer(
            from: modelFolder(for: model),
            using: HuggingFaceTokenizerLoader()
        )
        let editor = TranscriptEditor(container: container, model: model)
        try await editor.warmUp()
        return editor
    }

    func remove(_ model: CleanupModel) throws {
        try FileManager.default.removeItem(at: modelFolder(for: model))
    }

    private func modelFolder(for model: CleanupModel) -> URL {
        HubApiWrapper(downloadBase: directory).localRepoLocation(HubApiWrapper.Repo(id: model.rawValue))
    }
}
