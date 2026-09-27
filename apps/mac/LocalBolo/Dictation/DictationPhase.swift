/// Where a dictation session currently is. Drives the pill and menu bar icon.
enum DictationPhase: Equatable {
    /// Waiting for the user to hold fn.
    case idle
    /// fn is held and the microphone is recording.
    case listening
    /// fn was released; the recording is being turned into text.
    case transcribing
    /// A short message explaining why dictation couldn't run.
    case notice(String)
}

extension DictationPhase {
    var isNotice: Bool {
        if case .notice = self { true } else { false }
    }
}
