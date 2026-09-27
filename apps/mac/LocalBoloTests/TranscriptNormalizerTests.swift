import Testing
@testable import LocalBolo

struct TranscriptNormalizerTests {
    @Test(arguments: [
        ("  Hello world.  ", "Hello world."),
        ("Line one\n  line two", "Line one line two"),
        ("[BLANK_AUDIO]", ""),
        ("Hello [Music] there", "Hello there"),
        ("<|endoftext|>Hi", "Hi"),
        ("(upbeat music)", ""),
        ("*coughs*", ""),
        ("Call me (maybe) later", "Call me (maybe) later"),
    ])
    func cleans(transcript: String, expected: String) {
        #expect(TranscriptNormalizer.clean(transcript) == expected)
    }
}
