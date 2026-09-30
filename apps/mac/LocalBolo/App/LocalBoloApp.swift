import SwiftUI

@main
struct LocalBoloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var model: AppModel { appDelegate.model }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(model)
        } label: {
            MenuBarIcon(dictation: model.dictation)
        }

        Window("Welcome to LocalBolo", id: WindowID.onboarding) {
            OnboardingView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        // Open whenever setup is incomplete, such as after an update that asks
        // for a license key, rather than restoring however it was left.
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(model.needsSetup ? .presented : .suppressed)

        Settings {
            SettingsView()
                .environment(model)
        }
        .windowResizability(.contentSize)
    }
}

/// Identifiers for windows opened with `openWindow(id:)`.
enum WindowID {
    static let onboarding = "onboarding"
}
