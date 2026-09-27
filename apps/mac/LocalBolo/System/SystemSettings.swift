import AppKit

/// Deep links into System Settings panes.
enum SystemSettings {
    enum Pane: String {
        case microphonePrivacy = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case accessibilityPrivacy = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case keyboard = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
    }

    static func open(_ pane: Pane) {
        guard let url = URL(string: pane.rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
}
