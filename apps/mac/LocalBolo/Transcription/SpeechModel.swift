/// The on-device speech models LocalBolo can download and run.
///
/// All of them run on Apple Silicon's Neural Engine via Core ML and are tuned
/// for (or restricted to) English.
nonisolated enum SpeechModel: String, LocalModel {
    case parakeetV2 = "parakeet-tdt-0.6b-v2"
    case whisperBaseEnglish = "openai_whisper-base.en"
    case whisperSmallEnglish = "openai_whisper-small.en_217MB"
    case whisperLargeV3Turbo = "openai_whisper-large-v3-v20240930_626MB"

    static let recommended = SpeechModel.parakeetV2

    enum Engine: Sendable {
        /// NVIDIA Parakeet, run with FluidAudio.
        case parakeet
        /// OpenAI Whisper, run with WhisperKit.
        case whisper

        var displayName: String {
            switch self {
            case .parakeet: "NVIDIA Parakeet"
            case .whisper: "OpenAI Whisper"
            }
        }
    }

    var engine: Engine {
        switch self {
        case .parakeetV2: .parakeet
        case .whisperBaseEnglish, .whisperSmallEnglish, .whisperLargeV3Turbo: .whisper
        }
    }

    var family: String { engine.displayName }

    var displayName: String {
        switch self {
        case .parakeetV2: "Parakeet v2"
        case .whisperBaseEnglish: "Whisper Base"
        case .whisperSmallEnglish: "Whisper Small"
        case .whisperLargeV3Turbo: "Whisper Large v3 Turbo"
        }
    }

    var summary: String {
        switch self {
        case .parakeetV2: "Best for English. Very fast and highly accurate."
        case .whisperBaseEnglish: "Smallest download. Good for quick notes."
        case .whisperSmallEnglish: "A balance of speed and accuracy."
        case .whisperLargeV3Turbo: "Most accurate Whisper. Slower on older Macs."
        }
    }

    /// Approximate download size, shown before the user commits to a download.
    var downloadSize: String {
        switch self {
        case .parakeetV2: "470 MB"
        case .whisperBaseEnglish: "150 MB"
        case .whisperSmallEnglish: "220 MB"
        case .whisperLargeV3Turbo: "630 MB"
        }
    }
}
