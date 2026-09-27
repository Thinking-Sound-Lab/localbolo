import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`.
@Observable
final class AppSettings {
    /// Shows a small resting pill at the bottom of the screen when not dictating.
    var showsIdlePill: Bool {
        didSet { defaults.set(showsIdlePill, forKey: Key.showsIdlePill) }
    }

    /// Puts the previous clipboard contents back after a transcript is pasted.
    var restoresClipboard: Bool {
        didSet { defaults.set(restoresClipboard, forKey: Key.restoresClipboard) }
    }

    /// Runs transcripts through a local language model to apply self-corrections
    /// and remove filler words. Off by default because it needs a model download.
    var cleansUpTranscripts: Bool {
        didSet { defaults.set(cleansUpTranscripts, forKey: Key.cleansUpTranscripts) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.showsIdlePill: true,
            Key.restoresClipboard: true,
        ])
        showsIdlePill = defaults.bool(forKey: Key.showsIdlePill)
        restoresClipboard = defaults.bool(forKey: Key.restoresClipboard)
        cleansUpTranscripts = defaults.bool(forKey: Key.cleansUpTranscripts)
    }

    private enum Key {
        static let showsIdlePill = "showsIdlePill"
        static let restoresClipboard = "restoresClipboard"
        static let cleansUpTranscripts = "cleansUpTranscripts"
    }
}
