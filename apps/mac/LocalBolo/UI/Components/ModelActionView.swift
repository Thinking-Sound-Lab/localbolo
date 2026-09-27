import SwiftUI

/// The download / use control for a model, including progress while the model
/// downloads and loads.
struct ModelActionView<Loader: ModelLoader>: View {
    let store: LocalModelStore<Loader>
    let model: Loader.Model

    var body: some View {
        switch store.status(of: model) {
        case .notInstalled:
            Button("Download") { store.use(model) }
                .disabled(store.isBusy)

        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Preparing…")
                    .foregroundStyle(.secondary)
            }
            .help("The first load optimizes the model for this Mac and can take a minute.")

        case .installed:
            Button("Use") { store.use(model) }
                .disabled(store.isBusy)

        case .ready:
            Label("In use", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .failed:
            Button("Retry") { store.use(model) }
                .disabled(store.isBusy)
        }
    }
}
