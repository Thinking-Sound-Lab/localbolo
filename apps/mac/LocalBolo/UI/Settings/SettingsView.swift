import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Models", systemImage: "waveform") {
                ModelsSettingsView()
            }
            Tab("Cleanup", systemImage: "wand.and.sparkles") {
                CleanupSettingsView()
            }
        }
        .frame(width: 520)
        .onAppear { NSApp.activate() }
    }
}

private struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var isGlobeKeyDoNothing = GlobeKeySetting.isSetToDoNothing

    var body: some View {
        @Bindable var settings = app.settings

        Form {
            Section("Dictation") {
                LabeledContent("Shortcut") {
                    Text("Hold fn")
                }
                Toggle("Show the pill when not dictating", isOn: $settings.showsIdlePill)
                Toggle("Restore clipboard after pasting", isOn: $settings.restoresClipboard)
            }

            Section("Permissions") {
                PermissionRow(title: "Microphone", isGranted: app.permissions.microphone == .granted, actionTitle: "Allow") {
                    Task { await app.permissions.requestMicrophone() }
                }
                PermissionRow(title: "Accessibility", isGranted: app.permissions.accessibility == .granted) {
                    app.permissions.requestAccessibility()
                }
                PermissionRow(title: "🌐 key set to “Do Nothing”", isGranted: isGlobeKeyDoNothing) {
                    SystemSettings.open(.keyboard)
                }
            }

            Section {
                Toggle("Launch LocalBolo at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, isEnabled in
                        LaunchAtLogin.isEnabled = isEnabled
                    }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { isGlobeKeyDoNothing = GlobeKeySetting.isSetToDoNothing }
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    var actionTitle = "Open Settings"
    let fix: () -> Void

    var body: some View {
        LabeledContent(title) {
            if isGranted {
                Label("On", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(actionTitle, action: fix)
            }
        }
    }
}

private struct ModelsSettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Form {
            Section {
                ForEach(SpeechModel.allCases) { model in
                    ModelRow(store: app.speechModels, model: model)
                }
            } footer: {
                ModelStorageFooter(text: "Speech models run entirely on this Mac using the Neural Engine.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CleanupSettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var cleanup = app.cleanup

        Form {
            Section {
                Toggle(isOn: $cleanup.isEnabled) {
                    Text("Clean up transcripts")
                    Text("Applies your corrections and removes filler words. “Let’s meet at 9 p.m., sorry, 10 p.m.” becomes “Let’s meet at 10 p.m.”")
                }
            }

            Section("Model") {
                ForEach(CleanupModel.allCases) { model in
                    ModelRow(store: cleanup.models, model: model)
                }
            }
            .disabled(!cleanup.isEnabled)

            Section {
            } footer: {
                ModelStorageFooter(text: "A small language model runs on this Mac’s GPU. Only transcripts with filler words or corrections are sent to it, so most dictations aren’t slowed down.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ModelStorageFooter: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([ModelStorage.directory])
            }
            .buttonStyle(.link)
        }
        .font(.callout)
    }
}
