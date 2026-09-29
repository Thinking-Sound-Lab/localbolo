import SwiftUI

/// The setup guide's first screen: before anything else, LocalBolo asks for
/// the license key from the purchase email. Once it's activated, the guide
/// moves on to permissions.
///
/// It also appears if a month has passed without checking the key, or the
/// clock was turned back, and then asks the buyer to connect to the internet
/// instead.
struct LicenseScreen: View {
    @Environment(AppModel.self) private var app
    @State private var key = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            if app.license.status == .needsVerification {
                verification
            } else {
                activation
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var activation: some View {
        VStack(spacing: 24) {
            Heading(
                title: "Welcome to LocalBolo",
                message: "Enter the license key from the email Dodo Payments sent you after you bought LocalBolo. You only need to do this once on each Mac."
            )

            VStack(spacing: 12) {
                TextField("License key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .frame(width: 360)
                    .onSubmit(activate)

                Button(action: activate) {
                    Text(app.license.isWorking ? "Activating…" : "Activate")
                        .frame(width: 120)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(!canActivate)

                ErrorText(message: app.license.errorMessage)
            }

            HStack(spacing: 20) {
                Link("Lost your key?", destination: AppLinks.findLicense)
                Link("Buy LocalBolo", destination: AppLinks.buy)
            }
            .font(.callout)
        }
    }

    private var verification: some View {
        VStack(spacing: 24) {
            Heading(
                title: "Check your license",
                message: "LocalBolo needs to check your license with Dodo Payments. It does this at least once a month, and again if your Mac's clock is turned back. Connect to the internet, then try again."
            )

            VStack(spacing: 12) {
                Button {
                    Task { await app.license.verifyNow() }
                } label: {
                    Text(app.license.isWorking ? "Checking…" : "Try Again")
                        .frame(width: 120)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(app.license.isWorking)

                ErrorText(message: app.license.errorMessage)
            }
        }
    }

    private var canActivate: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !app.license.isWorking
    }

    private func activate() {
        guard canActivate else { return }
        Task { await app.license.activate(key: key) }
    }
}

private struct Heading: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
