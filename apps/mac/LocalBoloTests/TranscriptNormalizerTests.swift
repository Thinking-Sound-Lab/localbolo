import Testing
@testable import LocalBolo

struct TranscriptNormalizerTests {
    @Test(arguments: [
        ("  Hello world.  ", "Hello world."),
        ("Line one\n  line two", "Line one\nline two"),
        ("Intro\r\n\r\n- One\r\n- Two", "Intro\n\n- One\n- Two"),
        ("Use [draft] for now", "Use [draft] for now"),
        ("你好。\n\n明天见！", "你好。\n\n明天见！"),
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
