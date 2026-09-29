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
            Tab("License", systemImage: "key") {
                LicenseSettingsView()
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

            if app.updater.isAvailable {
                UpdatesSection()
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { isGlobeKeyDoNothing = GlobeKeySetting.isSetToDoNothing }
    }
}

private struct UpdatesSection: View {
    @Environment(AppModel.self) private var app
    @State private var checksAutomatically = false

    var body: some View {
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: $checksAutomatically)
                .onChange(of: checksAutomatically) { _, isOn in
                    app.updater.automaticallyChecksForUpdates = isOn
                }
            LabeledContent("Version \(Bundle.main.shortVersion)") {
                Button("Check Now") { app.updater.checkForUpdates() }
                    .disabled(!app.updater.canCheckForUpdates)
            }
        }
        .onAppear { checksAutomatically = app.updater.automaticallyChecksForUpdates }
    }
}

private struct LicenseSettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var isConfirmingDeactivation = false

    var body: some View {
        Form {
            Section {
                if let activation = app.license.activation {
                    LabeledContent("Status") {
                        if app.license.status == .active {
                            Label("Activated on this Mac", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            HStack {
                                Label("Needs a check", systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                Button("Check Now") { Task { await app.license.verifyNow() } }
                                    .disabled(app.license.isWorking)
                            }
                        }
                    }
                    LabeledContent("License key") {
                        Text(activation.licenseKey)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    LabeledContent("Moving to another Mac?") {
                        Button("Deactivate This Mac…") { isConfirmingDeactivation = true }
                            .disabled(app.license.isWorking)
                    }
                    if let error = app.license.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                } else {
                    LabeledContent("License key") {
                        LicenseKeyField()
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your license key is in the email from Dodo Payments. Deactivating this Mac frees it up to use on another one. LocalBolo checks the key every two weeks, and needs to reach Dodo at least once a month.")
                    Link("Lost your key?", destination: AppLinks.findLicense)
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog(
            "Deactivate LocalBolo on this Mac?",
            isPresented: $isConfirmingDeactivation
        ) {
            Button("Deactivate", role: .destructive) {
                Task { await app.license.deactivate() }
            }
        } message: {
            Text("Dictation stops working here until you enter a license key again. You can use the same key on this Mac or another one.")
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
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
