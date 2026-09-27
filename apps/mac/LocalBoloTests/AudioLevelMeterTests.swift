import Foundation
import Testing
@testable import LocalBolo

struct AudioLevelMeterTests {
    @Test func silenceHasNoLevel() {
        #expect(AudioLevelMeter.level(of: Array(repeating: 0, count: 1_600)) == 0)
        #expect(AudioLevelMeter.level(of: []) == 0)
    }

    @Test func fullScaleToneIsLoudest() {
        #expect(AudioLevelMeter.level(of: sine(amplitude: 1, seconds: 0.1)) == 1)
    }

    @Test func quietRoomNoiseIsBelowSpeechThreshold() {
        // Roughly -65 dBFS, like the noise floor of a built-in microphone.
        let level = AudioLevelMeter.level(of: sine(amplitude: 0.0006, seconds: 0.1))
        #expect(level < AudioLevelMeter.speechThreshold)
    }

    @Test func peakLevelFindsShortBurstOfSpeech() {
        let recording = silence(seconds: 1) + sine(amplitude: 0.2, seconds: 0.2) + silence(seconds: 1)
        #expect(AudioLevelMeter.peakLevel(of: recording) > AudioLevelMeter.speechThreshold)
    }

    @Test func recordingsNeedSpeechAndMinimumLength() {
        #expect(AudioRecorder.Recording(samples: sine(amplitude: 0.2, seconds: 1)).containsSpeech)
        #expect(!AudioRecorder.Recording(samples: silence(seconds: 1)).containsSpeech)
        #expect(!AudioRecorder.Recording(samples: sine(amplitude: 0.2, seconds: 0.1)).containsSpeech)
    }

    private func sine(amplitude: Float, seconds: Double) -> [Float] {
        let count = Int(seconds * AudioRecorder.sampleRate)
        return (0..<count).map { amplitude * sin(2 * .pi * 440 * Float($0) / Float(AudioRecorder.sampleRate)) }
    }

    private func silence(seconds: Double) -> [Float] {
        Array(repeating: 0, count: Int(seconds * AudioRecorder.sampleRate))
    }
}
