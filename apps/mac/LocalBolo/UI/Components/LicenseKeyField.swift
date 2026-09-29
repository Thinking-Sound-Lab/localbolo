import SwiftUI

/// A compact field for the license key from the purchase email, for Settings.
/// The setup guide asks for it on its own screen (LicenseScreen).
struct LicenseKeyField: View {
    @Environment(AppModel.self) private var app
    @State private var key = ""

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack {
                TextField("License key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onSubmit(activate)
                Button("Activate", action: activate)
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.license.isWorking)
            }

            if app.license.isWorking {
                ProgressView()
                    .controlSize(.small)
            } else if let error = app.license.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 280, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Link("Need a key? Buy LocalBolo", destination: AppLinks.buy)
                    .font(.caption)
            }
        }
    }

    private func activate() {
        Task { await app.license.activate(key: key) }
    }
}
