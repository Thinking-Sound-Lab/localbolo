import AVFoundation
import Testing
@testable import LocalBolo

struct AudioResamplerTests {
    @Test func convertsStereo48kHzToMono16kHz() throws {
        let inputFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let resampler = try #require(AudioResampler(from: inputFormat, toSampleRate: 16_000))

        // Feed one second of audio in 100 ms chunks, the way the microphone tap does.
        var output: [Float] = []
        for _ in 0..<10 {
            output += resampler.resample(try makeBuffer(format: inputFormat, frames: 4_800))
        }

        // The converter holds back roughly 15 ms of samples as filter latency.
        #expect((15_600...16_000).contains(output.count))
        #expect(output.contains { $0 != 0 })
    }

    private func makeBuffer(format: AVAudioFormat, frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            for frame in 0..<Int(frames) {
                buffer.floatChannelData![channel][frame] = 0.5 * sin(2 * .pi * 440 * Float(frame) / 48_000)
            }
        }
        return buffer
    }
}
