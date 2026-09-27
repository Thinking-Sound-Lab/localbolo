import Testing
@testable import LocalBolo

struct PushToTalkRecognizerTests {
    @Test func holdingFnStartsAndReleasingFinishes() {
        var recognizer = PushToTalkRecognizer()
        #expect(recognizer.handle(.fnDown(at: 10)) == .start)
        #expect(recognizer.handle(.fnUp(at: 11.5)) == .finish)
    }

    @Test func quickTapCancels() {
        var recognizer = PushToTalkRecognizer()
        #expect(recognizer.handle(.fnDown(at: 10)) == .start)
        #expect(recognizer.handle(.fnUp(at: 10.1)) == .cancel)
    }

    @Test func pressingAnotherKeyWhileHoldingFnCancels() {
        var recognizer = PushToTalkRecognizer()
        #expect(recognizer.handle(.fnDown(at: 10)) == .start)
        #expect(recognizer.handle(.otherKeyDown) == .cancel)
        // Releasing fn afterwards must not finish the cancelled dictation.
        #expect(recognizer.handle(.fnUp(at: 12)) == nil)
    }

    @Test func otherKeysAreIgnoredWhileFnIsUp() {
        var recognizer = PushToTalkRecognizer()
        #expect(recognizer.handle(.otherKeyDown) == nil)
    }

    @Test func repeatedFnDownIsIgnored() {
        var recognizer = PushToTalkRecognizer()
        #expect(recognizer.handle(.fnDown(at: 10)) == .start)
        #expect(recognizer.handle(.fnDown(at: 10.5)) == nil)
        #expect(recognizer.handle(.fnUp(at: 11)) == .finish)
    }

    @Test func releaseWithoutPressIsIgnored() {
        var recognizer = PushToTalkRecognizer()
        #expect(recognizer.handle(.fnUp(at: 10)) == nil)
    }

    @Test func canDictateAgainAfterFinishing() {
        var recognizer = PushToTalkRecognizer()
        _ = recognizer.handle(.fnDown(at: 10))
        _ = recognizer.handle(.fnUp(at: 11))
        #expect(recognizer.handle(.fnDown(at: 20)) == .start)
    }
}
