import Foundation

/// Turns raw fn-key activity into push-to-talk intents.
///
/// Holding fn starts a dictation and releasing it finishes one. Two things
/// cancel instead of finishing, so fn keeps working as a normal modifier:
/// - a quick tap shorter than `minimumHoldDuration`
/// - any other key pressed while fn is held (fn+F-keys, fn+arrows, …)
///
/// The recognizer is a plain value type with no system dependencies so it can
/// be unit tested; `FnKeyMonitor` feeds it events.
struct PushToTalkRecognizer {
    enum Event: Equatable {
        case fnDown(at: TimeInterval)
        case fnUp(at: TimeInterval)
        case otherKeyDown
    }

    enum Intent: Equatable {
        case start
        case finish
        case cancel
    }

    var minimumHoldDuration: TimeInterval = 0.25

    private var pressStartedAt: TimeInterval?

    mutating func handle(_ event: Event) -> Intent? {
        switch event {
        case .fnDown(let time):
            guard pressStartedAt == nil else { return nil }
            pressStartedAt = time
            return .start

        case .fnUp(let time):
            guard let startedAt = pressStartedAt else { return nil }
            pressStartedAt = nil
            return time - startedAt >= minimumHoldDuration ? .finish : .cancel

        case .otherKeyDown:
            guard pressStartedAt != nil else { return nil }
            pressStartedAt = nil
            return .cancel
        }
    }
}
