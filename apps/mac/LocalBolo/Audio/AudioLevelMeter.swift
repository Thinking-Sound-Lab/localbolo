import Accelerate

/// Loudness helpers for 16 kHz mono sample buffers.
nonisolated enum AudioLevelMeter {
    /// Quietest level treated as speech. Room noise on a typical built-in
    /// microphone sits well below this, while normal speech sits well above.
    static let speechThreshold: Float = 0.2

    /// Levels are mapped linearly from this range of decibels to `0...1`.
    private static let silenceFloor: Float = -55
    private static let loudCeiling: Float = -10

    /// Loudness of a chunk of audio, normalized to `0...1`.
    static func level(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let rms = vDSP.rootMeanSquare(samples)
        let decibels = 20 * log10(max(rms, .leastNonzeroMagnitude))
        return min(max((decibels - silenceFloor) / (loudCeiling - silenceFloor), 0), 1)
    }

    /// The loudest 100 ms window in a recording, normalized to `0...1`.
    static func peakLevel(of samples: [Float], windowSize: Int = 1_600) -> Float {
        stride(from: 0, to: samples.count, by: windowSize)
            .map { start in level(of: Array(samples[start..<min(start + windowSize, samples.count)])) }
            .max() ?? 0
    }
}
