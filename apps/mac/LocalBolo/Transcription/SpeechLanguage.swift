import Foundation

/// The language of a dictation, independent of the model used to recognize it.
nonisolated enum SpeechLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh"
    case hindi = "hi"
    case japanese = "ja"
    case automatic = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .chinese: "Chinese (Mandarin)"
        case .hindi: "Hindi"
        case .japanese: "Japanese"
        case .automatic: "Detect automatically"
        }
    }

    var decodingCode: String? { self == .automatic ? nil : rawValue }
}

/// Retain the recognized language so English cleanup rules are never applied
/// to a transcript identified as another language (or an unknown language).
nonisolated struct SpeechTranscript: Sendable {
    let text: String
    let language: String?
}
