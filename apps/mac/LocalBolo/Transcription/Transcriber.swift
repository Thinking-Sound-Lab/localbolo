/// A loaded speech model that turns audio into text.
nonisolated protocol Transcriber: Sendable {
    /// Transcribes 16 kHz mono samples.
    func transcribe(_ samples: [Float]) async throws -> String
}

nonisolated extension Transcriber {
    /// Runs the model once on a second of silence.
    ///
    /// The first inference compiles the model for the Neural Engine, which
    /// can take half a minute on a newly installed or updated app. Doing it
    /// while the model is loading keeps that wait off the first dictation.
    ///
    /// It also runs at the start of each dictation: a model that has sat
    /// idle for half a minute takes over half a second longer to answer, and
    /// that is better spent while the user is still speaking.
    func warmUp() async throws {
        _ = try await transcribe(Array(repeating: 0, count: Int(AudioRecorder.sampleRate)))
    }
}
