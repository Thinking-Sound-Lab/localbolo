import Foundation
import MLXLMCommon

/// Rewrites a transcript the way the speaker meant it, using a small
/// language model loaded in memory.
actor TranscriptEditor {
    private let container: ModelContainer
    private let model: CleanupModel

    init(container: ModelContainer, model: CleanupModel) {
        self.container = container
        self.model = model
    }

    func edit(_ transcript: String) async throws -> String {
        // A fresh session per edit, so earlier dictations never leak into this one.
        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(
                // An edit is never much longer than the original, so this only stops runaway output.
                maxTokens: transcript.count / 2 + 32,
                // Deterministic: always pick the most likely next token.
                temperature: 0
            ),
            additionalContext: model.chatTemplateContext
        )
        let reply = try await session.respond(to: CleanupPrompt.messages(for: transcript))
        return reply
            .replacing(/<think>[\s\S]*?<\/think>/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs one short edit so MLX compiles its GPU kernels now rather than
    /// during the first real cleanup.
    func warmUp() async throws {
        _ = try await edit("Um, this is a warm-up.")
    }
}
