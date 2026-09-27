import SwiftUI

/// First-run checklist: permissions, a speech model, and a place to try dictating.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var isGlobeKeyDoNothing = GlobeKeySetting.isSetToDoNothing
    @State private var practiceText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            checklist
            if isReadyToDictate {
                tryItOut
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            footer
        }
        .padding(32)
        .frame(width: 580)
        .animation(.default, value: isReadyToDictate)
        .onAppear { NSApp.activate() }
        .task { await watchGlobeKeySetting() }
    }

    private var isReadyToDictate: Bool {
        app.permissions.allGranted && app.speechModels.status(of: app.speechModels.activeModel) == .ready
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to LocalBolo")
                    .font(.largeTitle.bold())
                Text("Hold fn, speak, and let go. Your words appear wherever you're typing, and your voice never leaves this Mac.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var checklist: some View {
        VStack(spacing: 10) {
            ChecklistRow(
                title: "Allow microphone access",
                detail: "LocalBolo only listens while you hold fn.",
                isComplete: app.permissions.microphone == .granted
            ) {
                Button("Allow") { Task { await app.permissions.requestMicrophone() } }
            }

            ChecklistRow(
                title: "Allow accessibility access",
                detail: "Lets LocalBolo notice the fn key and paste text into any app.",
                isComplete: app.permissions.accessibility == .granted
            ) {
                Button("Open Settings") { app.permissions.requestAccessibility() }
            }

            ChecklistRow(
                title: "Download a speech model",
                detail: "\(app.speechModels.activeModel.displayName) · \(app.speechModels.activeModel.downloadSize). You can switch models in Settings.",
                isComplete: app.speechModels.status(of: app.speechModels.activeModel) == .ready
            ) {
                ModelActionView(store: app.speechModels, model: app.speechModels.activeModel)
            }

            ChecklistRow(
                title: "Set the 🌐 key to “Do Nothing”",
                detail: "Stops macOS from also opening the emoji picker when you release fn. It's under “Press 🌐 key to” in Keyboard settings.",
                isComplete: isGlobeKeyDoNothing,
                isOptional: true
            ) {
                Button("Open Settings") { SystemSettings.open(.keyboard) }
            }
        }
    }

    private var tryItOut: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try it out")
                .font(.headline)
            TextEditor(text: $practiceText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 90)
                .background(.background.secondary, in: .rect(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if practiceText.isEmpty {
                        Text("Click here, then hold fn and say something…")
                            .foregroundStyle(.tertiary)
                            .padding(15)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var footer: some View {
        HStack {
            Text("Everything runs locally. No account, no cloud.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismissWindow() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }

    // MARK: - Helpers

    /// macOS doesn't announce changes to this setting, so re-read it while the window is open.
    private func watchGlobeKeySetting() async {
        while !Task.isCancelled {
            isGlobeKeyDoNothing = GlobeKeySetting.isSetToDoNothing
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
