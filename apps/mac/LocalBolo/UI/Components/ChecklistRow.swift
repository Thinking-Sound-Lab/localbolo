import SwiftUI

/// A setup item with a completion indicator, an explanation, and an action
/// that is shown until the item is complete.
struct ChecklistRow<Action: View>: View {
    let title: String
    let detail: String
    let isComplete: Bool
    var isOptional = false
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 22))
                .foregroundStyle(isComplete ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if isOptional {
                        Text("Optional")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: .capsule)
                    }
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if !isComplete {
                action()
            }
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .animation(.default, value: isComplete)
    }
}
