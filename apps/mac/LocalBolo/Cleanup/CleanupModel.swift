/// Small language models that clean up transcripts, run on the GPU with MLX.
///
/// Picked by benchmarking on an 8 GB M1: both edit a dictated sentence in
/// about a second or less.
nonisolated enum CleanupModel: String, LocalModel {
    case qwen25_1_5B = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
    case qwen3_0_6B = "mlx-community/Qwen3-0.6B-4bit"

    static let recommended = CleanupModel.qwen25_1_5B

    var displayName: String {
        switch self {
        case .qwen25_1_5B: "Qwen 2.5 1.5B"
        case .qwen3_0_6B: "Qwen 3 0.6B"
        }
    }

    var summary: String {
        switch self {
        case .qwen25_1_5B: "Most careful edits. About a second per cleanup."
        case .qwen3_0_6B: "Twice as fast and a third of the size, but occasionally trims too much."
        }
    }

    var family: String { "Alibaba Qwen" }

    var downloadSize: String {
        switch self {
        case .qwen25_1_5B: "880 MB"
        case .qwen3_0_6B: "350 MB"
        }
    }

    /// Extra values for the model's chat template.
    var chatTemplateContext: [String: any Sendable]? {
        switch self {
        case .qwen25_1_5B: nil
        // Qwen 3 writes out its reasoning first unless told not to, which only adds latency here.
        case .qwen3_0_6B: ["enable_thinking": false]
        }
    }
}
