import SwiftUI

/// Vertical bars that dance with the microphone level while listening and
/// ripple gently while the recording is transcribed.
struct WaveformView: View {
    /// Microphone level in `0...1`.
    var level: Float
    var isProcessing: Bool

    private static let barCount = 11
    private static let barWidth: CGFloat = 2.5
    private static let barSpacing: CGFloat = 2.5
    private static let minimumBarHeight: CGFloat = 3
    private static let maximumBarHeight: CGFloat = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: Self.barSpacing) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(isProcessing ? 0.55 : 1))
                        .frame(width: Self.barWidth, height: barHeight(at: index, time: time))
                }
            }
            .frame(height: Self.maximumBarHeight)
        }
    }

    private func barHeight(at index: Int, time: TimeInterval) -> CGFloat {
        // 0 for the leftmost bar, 1 for the rightmost.
        let position = Double(index) / Double(Self.barCount - 1)

        let amplitude: Double
        if isProcessing {
            // A low wave travelling from left to right.
            amplitude = 0.22 + 0.18 * sin(time * 6 - position * 5)
        } else {
            // Taller in the middle, with each bar wobbling at its own pace so
            // the waveform looks alive rather than like a level meter.
            let envelope = 0.35 + 0.65 * sin(position * .pi)
            let wobble = 0.7 + 0.3 * sin(time * 11 + Double(index) * 1.9)
            amplitude = Double(level) * envelope * wobble
        }

        let clamped = CGFloat(min(max(amplitude, 0), 1))
        return Self.minimumBarHeight + (Self.maximumBarHeight - Self.minimumBarHeight) * clamped
    }
}

#Preview("Listening") {
    WaveformView(level: 0.7, isProcessing: false)
        .padding()
        .background(.black)
}

#Preview("Processing") {
    WaveformView(level: 0, isProcessing: true)
        .padding()
        .background(.black)
}
