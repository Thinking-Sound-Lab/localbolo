import SwiftUI

/// The setup guide's first screen: before anything else, LocalBolo asks for
/// the license key from the purchase email. Once it's activated, the guide
/// moves on to permissions.
struct LicenseScreen: View {
    @Environment(AppModel.self) private var app
    @State private var key = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 8) {
                Text("Welcome to LocalBolo")
                    .font(.largeTitle.bold())
                Text("Enter the license key from the email Dodo Payments sent you after you bought LocalBolo. You only need to do this once on each Mac.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

                if let error = app.license.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Link("Don't have a key? Buy LocalBolo", destination: AppLinks.buy)
                .font(.callout)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var canActivate: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !app.license.isWorking
    }

    private func activate() {
        guard canActivate else { return }
        Task { await app.license.activate(key: key) }
    }
}
