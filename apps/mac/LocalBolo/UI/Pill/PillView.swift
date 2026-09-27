import SwiftUI

/// The floating dictation indicator.
///
/// At rest it is a small translucent capsule at the bottom of the screen.
/// While dictating it grows into a black pill showing the icon of the app the
/// text will be pasted into, next to a live waveform.
struct PillView: View {
    var phase: DictationPhase
    /// The app the transcript will be pasted into.
    var targetApp: TargetApplication?
    /// Microphone level in `0...1`.
    var audioLevel: Float
    var showsWhenIdle: Bool

    /// The pill is centered in a slot of this height, so every state shares
    /// the same midpoint and the pill grows and shrinks around it.
    private static let slotHeight: CGFloat = 36

    var body: some View {
        ZStack {
            if style != .hidden {
                pill
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.slotHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 4)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: style)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var pill: some View {
        // The container keeps the capsule drawing when there's no content (the resting pill).
        ZStack { content }
            .font(.system(size: 12, weight: .medium))
            .padding(style.padding)
            .frame(minWidth: style.minimumSize.width, minHeight: style.minimumSize.height)
            .background(Capsule().fill(.black.opacity(style.fillOpacity)))
            // Keeps the content inside the capsule while it grows, so the
            // content appears to open out from the middle.
            .clipShape(.capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(style.strokeOpacity), lineWidth: 1))
            .shadow(color: .black.opacity(style.shadowOpacity), radius: 10, y: 4)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .listening, .transcribing:
            HStack(spacing: 8) {
                TargetAppIcon(app: targetApp)
                WaveformView(level: audioLevel, isProcessing: phase == .transcribing)
            }
            .transition(.scale(scale: 0.3).combined(with: .opacity))
        case .notice(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .transition(.scale(scale: 0.3).combined(with: .opacity))
        }
    }

    private var style: PillStyle {
        switch phase {
        case .idle: showsWhenIdle ? .resting : .hidden
        case .listening, .transcribing: .active
        case .notice: .notice
        }
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idle: "Dictation ready"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .notice(let message): message
        }
    }
}

/// Visual variants of the pill. Switching between them animates the capsule's
/// size, so the resting pill appears to grow into the active one.
private enum PillStyle: Equatable {
    case hidden
    case resting
    case active
    case notice

    var padding: EdgeInsets {
        switch self {
        case .hidden, .resting: EdgeInsets()
        case .active: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        case .notice: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        }
    }

    var minimumSize: CGSize {
        self == .resting ? CGSize(width: 40, height: 8) : .zero
    }

    var fillOpacity: Double { self == .resting ? 0.45 : 0.92 }
    var strokeOpacity: Double { self == .resting ? 0.35 : 0.14 }
    var shadowOpacity: Double { self == .resting ? 0 : 0.3 }
}

/// The icon of the app that will receive the transcript.
private struct TargetAppIcon: View {
    let app: TargetApplication?

    var body: some View {
        Group {
            if let app {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "text.cursor")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityLabel(app.map { "Pasting into \($0.name)" } ?? "")
    }
}

#Preview("Resting") {
    PillView(phase: .idle, audioLevel: 0, showsWhenIdle: true)
        .frame(width: 360, height: 80)
}

#Preview("Listening") {
    PillView(phase: .listening, targetApp: TargetApplication(.current), audioLevel: 0.7, showsWhenIdle: true)
        .frame(width: 360, height: 80)
}

#Preview("Transcribing") {
    PillView(phase: .transcribing, targetApp: TargetApplication(.current), audioLevel: 0, showsWhenIdle: true)
        .frame(width: 360, height: 80)
}

#Preview("Notice") {
    PillView(phase: .notice("Speech model is still loading"), audioLevel: 0, showsWhenIdle: true)
        .frame(width: 360, height: 80)
}
