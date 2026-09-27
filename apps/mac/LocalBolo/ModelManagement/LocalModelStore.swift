import Foundation
import Observation
import os

enum ModelStatus: Equatable {
    case notInstalled
    case downloading(progress: Double)
    /// Loading into memory. The first load of a speech model also optimizes
    /// it for this Mac's Neural Engine, which can take a minute.
    case loading
    case installed
    /// Loaded and in use.
    case ready
    case failed(String)
}

/// Downloads, loads and switches between the models of one kind.
///
/// The active model keeps working while another one downloads, and is only
/// replaced once the new model has loaded successfully.
@Observable
final class LocalModelStore<Loader: ModelLoader> {
    typealias Model = Loader.Model
    typealias Loaded = Loader.Loaded

    /// The model in use, persisted across launches.
    private(set) var activeModel: Model
    /// The active model once it's in memory.
    private(set) var loaded: Loaded?

    /// The model currently downloading or loading. Only one runs at a time.
    private(set) var inProgress: (model: Model, status: ModelStatus)?
    private var failures: [Model: String] = [:]
    /// Refreshed after each download or delete, so views don't hit the disk on every render.
    private var installedModels: Set<Model> = []

    @ObservationIgnored private let loader: Loader
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let activeModelKey: String

    init(loader: Loader, activeModelKey: String, defaults: UserDefaults = .standard) {
        self.loader = loader
        self.defaults = defaults
        self.activeModelKey = activeModelKey
        self.activeModel = defaults.string(forKey: activeModelKey).flatMap(Model.init) ?? .recommended
        refreshInstalledModels()
    }

    // There's nothing to clean up, so the deinit doesn't need to hop to the
    // main actor. Keeping it nonisolated also avoids an Xcode 26 optimizer
    // crash on main-actor deinits of generic classes.
    nonisolated deinit {}

    var isBusy: Bool { inProgress != nil }

    func status(of model: Model) -> ModelStatus {
        if let inProgress, inProgress.model == model { return inProgress.status }
        if model == activeModel, loaded != nil { return .ready }
        if let message = failures[model] { return .failed(message) }
        return installedModels.contains(model) ? .installed : .notInstalled
    }

    func isInstalled(_ model: Model) -> Bool {
        installedModels.contains(model)
    }

    // MARK: - Actions

    func loadActiveModelIfInstalled() {
        guard isInstalled(activeModel), loaded == nil else { return }
        use(activeModel)
    }

    /// Downloads `model` if needed, loads it, and makes it the active model.
    func use(_ model: Model) {
        Task { await activate(model) }
    }

    /// Like `use(_:)`, but waits until the model is ready (or has failed).
    func activate(_ model: Model) async {
        guard !isBusy, status(of: model) != .ready else { return }
        await download(andLoad: model)
    }

    /// Frees the memory held by the active model. It stays on disk.
    func unload() {
        guard !isBusy else { return }
        loaded = nil
    }

    func delete(_ model: Model) {
        guard model != activeModel, !isBusy else { return }
        do {
            try loader.remove(model)
        } catch {
            Logger.models.error("Couldn't delete \(model.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        refreshInstalledModels()
    }

    // MARK: - Private

    private func download(andLoad model: Model) async {
        failures[model] = nil

        do {
            if !loader.isInstalled(model) {
                inProgress = (model, .downloading(progress: 0))
                try await loader.download(model) { [weak self] progress in
                    Task { @MainActor in self?.reportDownloadProgress(progress, for: model) }
                }
                refreshInstalledModels()
            }

            inProgress = (model, .loading)
            let loadStarted = ContinuousClock.now
            let loadedModel = try await loader.load(model)

            loaded = loadedModel
            activeModel = model
            defaults.set(model.rawValue, forKey: activeModelKey)
            Logger.models.info("Loaded \(model.rawValue, privacy: .public) in \(ContinuousClock.now - loadStarted, privacy: .public)")
        } catch {
            Logger.models.error("Couldn't activate \(model.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            failures[model] = error.localizedDescription
        }

        inProgress = nil
        refreshInstalledModels()
    }

    private func reportDownloadProgress(_ progress: Double, for model: Model) {
        guard let inProgress, inProgress.model == model, case .downloading = inProgress.status else { return }
        self.inProgress = (model, .downloading(progress: progress))
    }

    private func refreshInstalledModels() {
        installedModels = Set(Model.allCases.filter { loader.isInstalled($0) })
    }
}
