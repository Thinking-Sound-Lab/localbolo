import AVFoundation
import Synchronization

/// Records the default microphone as 16 kHz mono `Float` samples, the input
/// format every supported speech model expects.
final class AudioRecorder {
    nonisolated static let sampleRate: Double = 16_000

    struct Recording {
        let samples: [Float]

        var duration: TimeInterval {
            Double(samples.count) / AudioRecorder.sampleRate
        }

        /// Filters out accidental presses and silent recordings, which some
        /// models would otherwise "transcribe" into hallucinated phrases.
        var containsSpeech: Bool {
            duration >= 0.3 && AudioLevelMeter.peakLevel(of: samples) >= AudioLevelMeter.speechThreshold
        }
    }

    enum RecorderError: LocalizedError {
        case noInputDevice
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .noInputDevice: "No microphone is available."
            case .unsupportedFormat: "The microphone's audio format isn't supported."
            }
        }
    }

    private var engine: AVAudioEngine?
    private let buffer = SampleBuffer()

    /// Starts recording. `onLevel` is called from the audio thread with the
    /// loudness of each captured chunk, normalized to `0...1`.
    func start(onLevel: @escaping @Sendable (Float) -> Void) throws {
        _ = stop()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInputDevice
        }
        guard let resampler = AudioResampler(from: inputFormat, toSampleRate: Self.sampleRate) else {
            throw RecorderError.unsupportedFormat
        }

        input.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat,
            block: Self.makeTapBlock(resampler: resampler, buffer: buffer, onLevel: onLevel)
        )
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    /// Stops recording and returns everything captured since `start`.
    func stop() -> Recording {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.engine = nil
        }
        return Recording(samples: buffer.drain())
    }

    /// Built outside the main actor because Core Audio invokes it on its own
    /// real-time thread.
    nonisolated private static func makeTapBlock(
        resampler: AudioResampler,
        buffer: SampleBuffer,
        onLevel: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        { pcmBuffer, _ in
            let samples = resampler.resample(pcmBuffer)
            buffer.append(samples)
            onLevel(AudioLevelMeter.level(of: samples))
        }
    }
}

/// A thread-safe accumulator shared between the audio thread and the main actor.
nonisolated final class SampleBuffer: Sendable {
    private let samples = Mutex<[Float]>([])

    func append(_ newSamples: [Float]) {
        samples.withLock { $0.append(contentsOf: newSamples) }
    }

    func drain() -> [Float] {
        samples.withLock { samples in
            defer { samples.removeAll(keepingCapacity: false) }
            return samples
        }
    }
}
