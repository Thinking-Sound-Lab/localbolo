import SwiftUI

/// The menu shown from LocalBolo's menu bar icon.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var cleanup = model.cleanup

        #if DEBUG
        // Both builds can run side by side, so make the development one obvious.
        Text("Development build")
        #endif
        Text(statusText)

        Divider()

        Toggle("Clean Up Transcripts", isOn: $cleanup.isEnabled)

        Button("Copy Last Transcript") {
            guard let transcript = model.dictation.lastTranscript else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcript, forType: .string)
        }
        .disabled(model.dictation.lastTranscript == nil)

        Divider()

        Button("Setup Guide…") {
            // LocalBolo has no Dock icon, so bring it forward before showing a window.
            NSApp.activate()
            openWindow(id: WindowID.onboarding)
        }
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit \(appName)") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// "LocalBolo", or "LocalBolo Dev" for development builds.
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LocalBolo"
    }

    private var statusText: String {
        guard model.permissions.allGranted else { return "Finish setup to start dictating" }

        return switch model.speechModels.status(of: model.speechModels.activeModel) {
        case .ready: "Hold fn to dictate"
        case .downloading(let progress): "Downloading speech model… \(progress.formatted(.percent.precision(.fractionLength(0))))"
        case .loading: "Loading speech model…"
        case .failed: "Speech model failed to load"
        case .notInstalled, .installed: "Download a speech model to start"
        }
    }
}

/// The menu bar icon: LocalBolo's monogram, which fills in while listening.
/// Both are template images, so macOS tints them to match the menu bar.
struct MenuBarIcon: View {
    let dictation: DictationController

    var body: some View {
        Image(dictation.phase == .listening ? "MenuBarIconListening" : "MenuBarIcon")
    }
}
