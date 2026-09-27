import SwiftUI

/// A model in a settings list: what it is, its size, and its download / use control.
struct ModelRow<Model: LocalModel, Loaded: Sendable>: View {
    let store: LocalModelStore<Model, Loaded>
    let model: Model

    var body: some View {
        let status = store.status(of: model)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.headline)
                    if model == Model.recommended {
                        Text("Recommended")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint, in: .capsule)
                    }
                }
                Text(model.summary)
                    .foregroundStyle(.secondary)
                Text("\(model.family) · \(model.downloadSize)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if case .failed(let message) = status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            ModelActionView(store: store, model: model)

            if status == .installed {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.delete(model)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(store.isBusy)
                .help("Delete \(model.displayName) from this Mac")
            }
        }
        .padding(.vertical, 4)
    }
}
