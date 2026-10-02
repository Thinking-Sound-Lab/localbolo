import Foundation
import MLX
import MLXLMCommon

/// Rewrites a transcript the way the speaker meant it, using a small
/// language model loaded in memory.
///
/// Two things keep an edit to about a fifth of a second:
///
/// - The instructions and examples are the same for every edit, so the model
///   reads them once, when it loads, and that work is reused.
/// - The edit is mostly a copy of the dictation, so the dictation is offered
///   to the model as a draft to check instead of having it write every token
///   (see ``DraftCursor``). The result is the same text either way.
actor TranscriptEditor {
    private let container: ModelContainer
    private let model: CleanupModel
    private let memory = PromptMemory()

    init(container: ModelContainer, model: CleanupModel) {
        self.container = container
        self.model = model
    }

    func edit(_ transcript: String) async throws -> String {
        let reply = try await container.perform { [memory, model] context in
            let prompt = try await Self.promptTokens(for: transcript, model: model, context: context)
            let tokens = Self.generate(
                prompt: prompt,
                draft: context.tokenizer.encode(text: transcript, addSpecialTokens: false),
                // An edit is never much longer than the original, so this only stops runaway output.
                maxTokens: transcript.count / 2 + 32,
                memory: memory,
                context: context
            )
            return context.tokenizer.decode(tokenIds: tokens, skipSpecialTokens: true)
        }
        return reply
            .replacing(/<think>[\s\S]*?<\/think>/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Gets the model ready to edit without a wait, by running one short edit.
    ///
    /// This runs when the model loads, so MLX compiles its GPU kernels then,
    /// and again at the start of every dictation. On a Mac that's short of
    /// memory, macOS moves an idle app's memory to disk within seconds, and
    /// bringing a model back takes a second or more. That is better spent
    /// while the user is still speaking than after they've finished.
    func warmUp() async throws {
        try await readPromptOnce()
        _ = try await edit("The meeting is at noon. Sorry, at one.")
    }

    /// Runs the start of the prompt, which every edit shares, through the
    /// model and keeps the result. Only the first call does anything.
    private func readPromptOnce() async throws {
        try await container.perform { [memory, model] context in
            guard memory.cache == nil else { return }

            // Whatever two different prompts both start with is the part that never changes.
            let first = try await Self.promptTokens(for: "a b c", model: model, context: context)
            let second = try await Self.promptTokens(for: "X Y Z", model: model, context: context)
            let shared = Array(first.prefix(zip(first, second).prefix { $0 == $1 }.count))

            let cache = context.model.newCache(parameters: nil)
            // Reusing the prompt and checking drafts both depend on rewinding the cache,
            // which a few model architectures can't do.
            guard canTrimPromptCache(cache) else { throw EditorError.cacheCannotRewind }

            // In pieces, so reading a long prompt doesn't need much memory at once.
            for start in stride(from: 0, to: shared.count, by: 256) {
                let piece = Array(shared[start..<min(start + 256, shared.count)])
                _ = context.model(LMInput.Text(tokens: MLXArray(piece))[text: .newAxis], cache: cache, state: nil)
                eval(cache)
            }
            memory.cache = cache
            memory.tokens = shared
        }
    }

    // MARK: - Generation

    private static func promptTokens(
        for transcript: String,
        model: CleanupModel,
        context: ModelContext
    ) async throws -> [Int] {
        let input = UserInput(
            chat: CleanupPrompt.messages(for: transcript),
            additionalContext: model.chatTemplateContext
        )
        return try await context.processor.prepare(input: input).text.tokens.asArray(Int.self)
    }

    /// Writes the model's reply to `prompt`, always picking the most likely
    /// next token, so the same dictation always gives the same edit.
    private static func generate(
        prompt: [Int],
        draft: [Int],
        maxTokens: Int,
        memory: PromptMemory,
        context: ModelContext
    ) -> [Int] {
        let model = context.model
        let tokenizer = context.tokenizer
        let cache = memory.cache ?? model.newCache(parameters: nil)

        // Skip the start of the prompt the model has already read.
        let remembered = zip(prompt.dropLast(), memory.tokens).prefix { $0 == $1 }.count
        trimPromptCache(cache, numTokens: memory.tokens.count - remembered)

        var stopTokens = context.configuration.eosTokenIds
        stopTokens.formUnion([tokenizer.eosTokenId, tokenizer.unknownTokenId].compactMap { $0 })
        stopTokens.formUnion(context.configuration.extraEOSTokens.compactMap(tokenizer.convertTokenToId))

        var cursor = DraftCursor(source: draft) { token in
            tokenizer.decode(tokenIds: [token], skipSpecialTokens: false)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        var pending = Array(prompt[remembered...])
        var output: [Int] = []
        var state: LMOutput.State?

        while output.count < maxTokens {
            // One pass reads what's new and checks the draft: the model's pick after each
            // position shows how far the draft was right.
            let offered = cursor.draft
            let input = LMInput.Text(tokens: MLXArray(pending + offered))
            let result = model(input[text: .newAxis], cache: cache, state: state)
            state = result.state
            let picks = result.logits[0, (pending.count - 1)..., 0...].argMax(axis: -1).asArray(Int.self)

            let accepted = zip(offered, picks).prefix { $0 == $1 }.count
            // Forget the draft tokens the model disagreed with.
            trimPromptCache(cache, numTokens: offered.count - accepted)
            output.append(contentsOf: offered.prefix(accepted))

            let token = picks[accepted]
            if stopTokens.contains(token) { break }
            output.append(token)
            pending = [token]
            cursor.advance(accepted: accepted, of: offered.count, then: token, output: output)
        }

        // Keep only the shared start of the prompt, so nothing of this dictation
        // is left for the next one.
        trimPromptCache(cache, numTokens: (cache.first?.offset ?? remembered) - remembered)
        eval(cache)
        memory.cache = cache
        memory.tokens = Array(prompt[..<remembered])

        return Array(output.prefix(maxTokens))
    }
}

nonisolated enum EditorError: LocalizedError {
    case cacheCannotRewind

    var errorDescription: String? {
        "This model can't be used for cleanup."
    }
}

/// What the model has already read: the start of the prompt that every edit shares.
///
/// Only used inside `ModelContainer.perform`, which runs one closure at a time.
private nonisolated final class PromptMemory: @unchecked Sendable {
    /// The model's attention state after reading `tokens`.
    var cache: [KVCache]?
    var tokens: [Int] = []
}
