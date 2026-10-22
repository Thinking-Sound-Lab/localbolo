import Foundation
import Testing
@testable import LocalBolo

struct ModelLifecycleTests {
    @Test func disablingDuringLoadDoesNotRetainTheFinishedModel() async throws {
        let gate = ModelLoadGate()
        let name = "LocalBolo.Lifecycle.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LocalModelStore(loader: DelayedLoader(gate: gate), activeModelKey: "model", defaults: defaults)
        let loading = Task { await store.activate(.sample) }
        await gate.waitUntilStarted()
        store.unload()
        await gate.finish()
        await loading.value
        #expect(store.loaded == nil)
        #expect(store.status(of: .sample) == .installed)
    }

    @Test func reEnablingDuringLoadRetainsTheModel() async throws {
        let gate = ModelLoadGate()
        let name = "LocalBolo.Lifecycle.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LocalModelStore(loader: DelayedLoader(gate: gate), activeModelKey: "model", defaults: defaults)
        let loading = Task { await store.activate(.sample) }
        await gate.waitUntilStarted()
        store.unload()
        store.use(.sample)
        await gate.finish()
        await loading.value
        #expect(store.loaded == "loaded")
        #expect(store.status(of: .sample) == .ready)
    }
}

private nonisolated enum LifecycleModel: String, LocalModel {
    case sample
    static let recommended = LifecycleModel.sample
    var displayName: String { "Sample" }
    var summary: String { "Test model" }
    var family: String { "Test" }
    var downloadSize: String { "0 MB" }
}

private nonisolated struct DelayedLoader: ModelLoader {
    let gate: ModelLoadGate
    func isInstalled(_ model: LifecycleModel) -> Bool { true }
    func download(_ model: LifecycleModel, progress: @escaping @Sendable (Double) -> Void) async throws {}
    func load(_ model: LifecycleModel) async throws -> String { await gate.load() }
    func remove(_ model: LifecycleModel) throws {}
}

private actor ModelLoadGate {
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var finishWaiter: CheckedContinuation<String, Never>?

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func load() async -> String {
        started = true
        startWaiter?.resume()
        return await withCheckedContinuation { finishWaiter = $0 }
    }

    func finish() { finishWaiter?.resume(returning: "loaded") }
}
