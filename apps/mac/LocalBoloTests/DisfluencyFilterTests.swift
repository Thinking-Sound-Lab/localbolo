import Testing
@testable import LocalBolo

struct DisfluencyFilterTests {
    @Test(arguments: [
        ("Um, I think we should ship this on Friday.", "I think we should ship this on Friday."),
        ("Umm, can somebody close the door?", "Can somebody close the door?"),
        ("So, uh, the build is failing.", "So the build is failing."),
        ("I was, um, wondering if you had, uh, time.", "I was wondering if you had time."),
        ("She was um very strong on system design.", "She was very strong on system design."),
        ("We need to, um, uh, rethink the flow.", "We need to rethink the flow."),
        ("The numbers look good. Uh, revenue is up.", "The numbers look good. Revenue is up."),
        ("I think so, um. Next point.", "I think so. Next point."),
        ("That's all from my side, um.", "That's all from my side."),
        ("That's it, uh", "That's it"),
        ("uh iPhone is fine", "iPhone is fine"),
        // After a word a comma can follow, one comma stays.
        ("Bring apples, um, oranges and pears.", "Bring apples, oranges and pears."),
        ("Okay, um, let's get started.", "Okay, let's get started."),
        ("I don't know, uh, maybe we should ask.", "I don't know, maybe we should ask."),
    ])
    func removesFillers(transcript: String, expected: String) {
        #expect(DisfluencyFilter.clean(transcript) == expected)
    }

    @Test(arguments: [
        ("I I think the the deadline is next week.", "I think the deadline is next week."),
        ("The server is is down again.", "The server is down again."),
        ("Add milk, eggs and and butter.", "Add milk, eggs and butter."),
        ("It's it's not ready yet.", "It's not ready yet."),
        ("Can you can you send me the slides?", "Can you send me the slides?"),
        ("We should, we should probably test this.", "We should probably test this."),
        ("In the in the first quarter we doubled.", "In the first quarter we doubled."),
        ("I I I don't know.", "I don't know."),
    ])
    func collapsesStutters(transcript: String, expected: String) {
        #expect(DisfluencyFilter.clean(transcript) == expected)
    }

    @Test(arguments: [
        "It was a very, very long day.",
        "I had had enough of that that day.",
        "He said no, no, absolutely not.",
        "Bye bye, talk to you tomorrow.",
        "New York, New York is a great song.",
        "Call 555 555 1234.",
        "That is what it is. Is it ready?",
        "The summer was hot. The winter was cold.",
        // Capitals make it a name, not a hesitation or a repeat.
        "Take him to the ER.",
        "We asked IT, it said no.",
        // A repeat that ends the sentence is said for emphasis.
        "So what, so what?",
        "It's fine, it's fine.",
        "I do, I do.",
    ])
    func leavesIntendedWordsAlone(transcript: String) {
        #expect(DisfluencyFilter.clean(transcript) == transcript)
    }
}
