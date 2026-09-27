import Foundation
import Testing
@testable import LocalBolo

/// End-to-end checks that download a real cleanup model and run it on the GPU.
///
/// These download hundreds of megabytes, so they only run when asked:
///
///     TEST_RUNNER_LOCALBOLO_INTEGRATION=1 xcodebuild test -scheme LocalBolo …
///
/// Models are stored in the app's normal location, so the app reuses them.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LOCALBOLO_INTEGRATION"] == "1"), .serialized)
struct CleanupIntegrationTests {
    @Test(arguments: CleanupModel.allCases)
    func appliesASelfCorrection(model: CleanupModel) async throws {
        let store = CleanupModelStore(defaults: try #require(UserDefaults(suiteName: "LocalBoloIntegrationTests")))
        await store.activate(model)
        let editor = try #require(store.loaded)

        let edited = try await editor.edit("Let's meet today at 9 p.m. sorry at 10 p.m.")

        #expect(edited.contains("10 p.m."))
        #expect(!edited.contains("9 p.m."))
        #expect(!edited.lowercased().contains("sorry"))
    }

    @Test func leavesAQuestionUnanswered() async throws {
        let store = CleanupModelStore(defaults: try #require(UserDefaults(suiteName: "LocalBoloIntegrationTests")))
        await store.activate(.recommended)
        let editor = try #require(store.loaded)

        let original = "Um, what's the weather like tomorrow?"
        let edited = try await editor.edit(original)

        #expect(TranscriptEditPolicy.isFaithful(edited, to: original))
    }
}
