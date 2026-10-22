import Foundation
import MLX
import MLXLMCommon

/// Rewrites a transcript the way the speaker meant it, using a small
/// language model loaded in memory.
///
/// Conservative cleanup reuses the prompt and checks copied text as a draft.
/// Polished edits use the same machinery with a separate multilingual prompt.
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

    func edit(_ transcript: String, style: CleanupStyle = .conservative, language: SpeechLanguage = .english) async throws -> String {
        try await readPromptOnce(style: style, language: language)
        let reply = try await container.perform { [memory, model] context in
            let draft = context.tokenizer.encode(text: transcript, addSpecialTokens: false)
            guard draft.count <= 1_536 else { throw EditorError.inputTooLong }
            let prompt = try await Self.promptTokens(for: transcript, model: model, style: style, language: language, context: context)
            let tokens = try Self.generate(
                prompt: prompt,
                draft: draft,
                // Hindi and Japanese can use several tokens per character.
                maxTokens: max(128, draft.count * 2 + 64),
                memory: memory,
                context: context
            )
            return context.tokenizer.decode(tokenIds: tokens, skipSpecialTokens: true)
        }
        return Self.normalizedReply(reply, style: style)
    }

    nonisolated static func normalizedReply(_ reply: String, style: CleanupStyle) -> String {
        let text = reply
            .replacing(/<think>[\s\S]*?<\/think>/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard style == .polished else { return text }
        // The clipboard carries plain text. Models sometimes emit Markdown's
        // two-space hard break when asked for a new paragraph.
        return text.replacing(/[ \t]{2,}\n/, with: "\n\n")
    }

    /// Gets the model ready to edit without a wait, by running one short edit.
    ///
    /// This runs when the model loads, so MLX compiles its GPU kernels then,
    /// and again at the start of every dictation. On a Mac that's short of
    /// memory, macOS moves an idle app's memory to disk within seconds, and
    /// bringing a model back takes a second or more. That is better spent
    /// while the user is still speaking than after they've finished.
    ///
    /// A real edit also wakes the tokenizer and the decoding path. A single
    /// forward pass was measured to leave the next edit slower after idle.
    func warmUp(style: CleanupStyle = .conservative, language: SpeechLanguage = .english) async throws {
        _ = try await edit("The meeting is at noon. Sorry, at one.", style: style, language: language)
    }

    /// Keeps the shared prompt ready, reusing its matching prefix when the
    /// selected language or editing style changes.
    private func readPromptOnce(style: CleanupStyle, language: SpeechLanguage) async throws {
        try await container.perform { [memory, model] context in
            guard memory.cache == nil || memory.style != style || memory.language != language else { return }
            // Whatever two different prompts both start with is the part that never changes.
            let first = try await Self.promptTokens(for: "a b c", model: model, style: style, language: language, context: context)
            let second = try await Self.promptTokens(for: "X Y Z", model: model, style: style, language: language, context: context)
            let shared = Array(first.prefix(zip(first, second).prefix { $0 == $1 }.count))

            // Retain the matching prefix in the single GPU cache. In Polished
            // mode, changing language only changes the short final hint.
            let cache = memory.cache ?? context.model.newCache(parameters: nil)
            // Reusing the prompt and checking drafts both depend on rewinding the cache,
            // which a few model architectures can't do.
            guard canTrimPromptCache(cache) else { throw EditorError.cacheCannotRewind }

            let remembered = zip(shared, memory.tokens).prefix { $0 == $1 }.count
            trimPromptCache(cache, numTokens: (cache.first?.offset ?? 0) - remembered)
            memory.cache = cache
            memory.tokens = Array(shared.prefix(remembered))
            memory.style = nil
            memory.language = nil

            // In pieces, so reading a long prompt doesn't need much memory at once.
            for start in stride(from: remembered, to: shared.count, by: 256) {
                try Task.checkCancellation()
                let piece = Array(shared[start..<min(start + 256, shared.count)])
                _ = context.model(LMInput.Text(tokens: MLXArray(piece))[text: .newAxis], cache: cache, state: nil)
                eval(cache)
                // Keep cache bookkeeping valid even if preparation is cancelled.
                memory.tokens.append(contentsOf: piece)
            }
            memory.style = style
            memory.language = language
        }
    }

    // MARK: - Generation

    private static func promptTokens(
        for transcript: String,
        model: CleanupModel,
        style: CleanupStyle,
        language: SpeechLanguage,
        context: ModelContext
    ) async throws -> [Int] {
        let input = UserInput(
            chat: style == .polished
                ? PolishedPrompt.messages(for: transcript, language: language)
                : CleanupPrompt.messages(for: transcript),
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
    ) throws -> [Int] {
        let model = context.model
        let tokenizer = context.tokenizer
        let cache = memory.cache ?? model.newCache(parameters: nil)

        // Skip the start of the prompt the model has already read.
        let remembered = zip(prompt.dropLast(), memory.tokens).prefix { $0 == $1 }.count
        trimPromptCache(cache, numTokens: memory.tokens.count - remembered)
        // Rewind after errors and cancellation too, never retaining a dictation
        // as part of the next one's shared prompt.
        defer {
            trimPromptCache(cache, numTokens: (cache.first?.offset ?? remembered) - remembered)
            eval(cache)
            memory.cache = cache
            memory.tokens = Array(prompt[..<remembered])
        }

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
        var reachedEnd = false

        while output.count < maxTokens {
            try Task.checkCancellation()
            // One pass reads what's new and checks the draft: the model's pick after each
            // position shows how far the draft was right.
            let offered = Array(cursor.draft.prefix(maxTokens - output.count - 1))
            let input = LMInput.Text(tokens: MLXArray(pending + offered))
            let result = model(input[text: .newAxis], cache: cache, state: state)
            state = result.state
            let picks = result.logits[0, (pending.count - 1)..., 0...].argMax(axis: -1).asArray(Int.self)

            let accepted = zip(offered, picks).prefix { $0 == $1 }.count
            // Forget the draft tokens the model disagreed with.
            trimPromptCache(cache, numTokens: offered.count - accepted)
            output.append(contentsOf: offered.prefix(accepted))

            let token = picks[accepted]
            if stopTokens.contains(token) { reachedEnd = true; break }
            output.append(token)
            pending = [token]
            cursor.advance(accepted: accepted, of: offered.count, then: token, output: output)
        }

        // A truncated edit must never be pasted as though it were complete.
        guard reachedEnd else { throw EditorError.outputTooLong }
        return output
    }
}

nonisolated enum EditorError: LocalizedError {
    case cacheCannotRewind
    case inputTooLong
    case outputTooLong

    var errorDescription: String? {
        switch self {
        case .cacheCannotRewind: "This model can't be used for cleanup."
        case .inputTooLong: "This passage is too long to edit safely."
        case .outputTooLong: "The edit did not finish; keeping the original passage."
        }
    }
}

/// What the model has already read: the start of the prompt that every edit shares.
///
/// Only used inside `ModelContainer.perform`, which runs one closure at a time.
private nonisolated final class PromptMemory: @unchecked Sendable {
    /// The model's attention state after reading `tokens`.
    var cache: [KVCache]?
    var tokens: [Int] = []
    var style: CleanupStyle?
    var language: SpeechLanguage?
}
