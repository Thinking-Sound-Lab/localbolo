import AVFoundation

/// Converts microphone buffers of any format into mono `Float` samples at a
/// fixed sample rate.
///
/// `AVAudioConverter` isn't thread-safe, so each recording creates its own
/// resampler and only ever uses it from the audio tap's thread.
nonisolated final class AudioResampler: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat, toSampleRate sampleRate: Double) {
        guard
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else { return nil }

        converter.downmix = true
        self.converter = converter
        self.outputFormat = outputFormat
    }

    func resample(_ input: AVAudioPCMBuffer) -> [Float] {
        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount((Double(input.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return []
        }

        // Hand the converter our single input buffer, then report that no more
        // data is available *right now* so it keeps its state for the next call.
        var hasProvidedInput = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if hasProvidedInput {
                status.pointee = .noDataNow
                return nil
            }
            hasProvidedInput = true
            status.pointee = .haveData
            return input
        }

        guard error == nil, let channel = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
