nonisolated enum CleanupStyle: String, CaseIterable, Identifiable, Sendable {
    case conservative
    case polished

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conservative: "Conservative (English)"
        case .polished: "Polished"
        }
    }

    var summary: String {
        switch self {
        case .conservative:
            "Removes English fillers and applies spoken corrections, keeping your wording. Other languages pass through unchanged."
        case .polished:
            "Fixes grammar and punctuation and adds paragraphs or lists, keeping your meaning and languages. Uses Qwen 3 1.7B (about 990 MB)."
        }
    }
}

/// Captured when fn is pressed. A preference change must not change the
/// language or editing rules halfway through a dictation.
nonisolated struct DictationPreferences: Sendable {
    var language: SpeechLanguage = .english
    var cleanupEnabled = false
    var cleanupStyle: CleanupStyle = .conservative
}
