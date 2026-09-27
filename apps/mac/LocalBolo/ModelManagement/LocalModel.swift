import Foundation

/// A model LocalBolo downloads from Hugging Face and runs on this Mac.
nonisolated protocol LocalModel: RawRepresentable<String>, CaseIterable, Identifiable, Hashable, Sendable {
    var displayName: String { get }
    var summary: String { get }
    /// The model family and who makes it, e.g. "OpenAI Whisper".
    var family: String { get }
    /// Approximate download size, shown before the user commits to a download.
    var downloadSize: String { get }

    static var recommended: Self { get }
}

nonisolated extension LocalModel {
    var id: String { rawValue }
}

/// Downloads, loads and deletes the models of one kind.
///
/// Each engine library has its own download and loading API; conforming types
/// hide those differences so `LocalModelStore` can treat every model the same way.
nonisolated protocol ModelLoader<Model, Loaded>: Sendable {
    associatedtype Model: LocalModel
    associatedtype Loaded: Sendable

    func isInstalled(_ model: Model) -> Bool

    /// Downloads the model, reporting progress in `0...1`.
    func download(_ model: Model, progress: @escaping @Sendable (Double) -> Void) async throws

    /// Loads an installed model into memory, ready to use.
    func load(_ model: Model) async throws -> Loaded

    /// Deletes the model's files from disk.
    func remove(_ model: Model) throws
}

/// Where every downloaded model is stored.
nonisolated enum ModelStorage {
    static let directory = URL.applicationSupportDirectory.appending(path: "LocalBolo/Models", directoryHint: .isDirectory)
}
