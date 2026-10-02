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
        let editor = try await Self.editor(for: model)

        let edited = try await editor.edit("Let's have dinner on Friday at 7. Sorry, at 8.")

        #expect(edited.contains("at 8"))
        #expect(!edited.contains("at 7"))
        #expect(!edited.lowercased().contains("sorry"))
    }

    @Test func leavesAQuestionUnanswered() async throws {
        let editor = try await Self.editor(for: .recommended)

        let original = "How far is the airport from the hotel? I mean from the office?"
        let edited = try await editor.edit(original)

        #expect(TranscriptEditPolicy.isFaithful(edited, to: original))
    }

    @Test func leavesALiteralCueWordAlone() async throws {
        let editor = try await Self.editor(for: .recommended)

        let original = "I'm sorry for the late reply."
        let edited = try await editor.edit(original)

        #expect(TranscriptEditPolicy.words(in: edited) == TranscriptEditPolicy.words(in: original))
    }

    /// Reusing the model's work on the prompt must not let one dictation leak into the next.
    @Test func givesTheSameEditEveryTime() async throws {
        let editor = try await Self.editor(for: .recommended)
        let dictation = "The total comes to 80 dollars. Wait, 90 dollars."

        let first = try await editor.edit(dictation)
        _ = try await editor.edit("Book a table for two on Saturday, actually for six.")
        let second = try await editor.edit(dictation)

        #expect(first == second)
    }

    @Test func cleansUpALongDictation() async throws {
        let cleanup = try await Self.cleanup()

        let cleaned = await cleanup.apply(to: """
        Quick recap of today's sync. Marketing is on track for the campaign launch. Engineering found a \
        memory leak in the importer, and um they expect a fix by Wednesday. Sales closed two deals this \
        week. Sorry, three deals this week. Next sync is on the the 12th.
        """)

        #expect(cleaned == """
        Quick recap of today's sync. Marketing is on track for the campaign launch. Engineering found a \
        memory leak in the importer, and they expect a fix by Wednesday. Sales closed three deals this \
        week. Next sync is on the 12th.
        """)
    }

    /// Runs the dictations in `CleanupEvaluation.json`, each listed with the text it should become.
    ///
    /// This is the measure to check before changing the prompt, the rules or the model. Only the
    /// wording is compared, not punctuation or capitalization.
    @Test func cleansUpTheEvaluationSet() async throws {
        struct Case: Decodable {
            let kind: String
            let dictation: String
            let acceptable: [String]
        }
        let file = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "CleanupEvaluation.json")
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: file))
        let cleanup = try await Self.cleanup()

        var failures: [String] = []
        for item in cases {
            let cleaned = await cleanup.apply(to: item.dictation)
            let words = TranscriptEditPolicy.words(in: cleaned)
            if !item.acceptable.contains(where: { TranscriptEditPolicy.words(in: $0) == words }) {
                failures.append("[\(item.kind)] \(item.dictation)\n  became: \(cleaned)")
            }
        }

        // The recommended model gets all but two right.
        #expect(failures.count <= cases.count / 20, "\(failures.joined(separator: "\n"))")
    }

    /// Cleanup turned on, with the recommended model loaded.
    private static func cleanup() async throws -> TranscriptCleanup {
        let defaults = try #require(UserDefaults(suiteName: "LocalBoloIntegrationTests"))
        let models = CleanupModelStore(defaults: defaults)
        await models.activate(.recommended)
        let settings = AppSettings(defaults: defaults)
        settings.cleansUpTranscripts = true
        return TranscriptCleanup(settings: settings, models: models)
    }

    private static func editor(for model: CleanupModel) async throws -> TranscriptEditor {
        let store = CleanupModelStore(defaults: try #require(UserDefaults(suiteName: "LocalBoloIntegrationTests")))
        await store.activate(model)
        return try #require(store.loaded)
    }
}
