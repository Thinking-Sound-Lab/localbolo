import AppKit
import Carbon.HIToolbox

/// Types text into whichever app has keyboard focus.
///
/// It briefly places the text on the clipboard and sends ⌘V, the one approach
/// that works the same in native, Electron and browser text fields. Sending
/// keystrokes to other apps requires Accessibility access.
final class TextInserter {
    /// How long the target app gets to read the clipboard before it is restored.
    private static let restoreDelay: Duration = .milliseconds(500)

    private let settings: AppSettings
    private let pasteboard: NSPasteboard

    init(settings: AppSettings, pasteboard: NSPasteboard = .general) {
        self.settings = settings
        self.pasteboard = pasteboard
    }

    func insert(_ text: String) {
        guard settings.restoresClipboard else {
            write(text, isTransient: false)
            sendPasteShortcut()
            return
        }

        let snapshot = PasteboardSnapshot(of: pasteboard)
        write(text, isTransient: true)
        let changeCountAfterWrite = pasteboard.changeCount
        sendPasteShortcut()

        Task {
            try? await Task.sleep(for: Self.restoreDelay)
            // Leave the clipboard alone if the user copied something in the meantime.
            guard pasteboard.changeCount == changeCountAfterWrite else { return }
            snapshot.restore(to: pasteboard)
        }
    }

    /// Leaves the text on the clipboard for the user to paste themselves.
    func copyToClipboard(_ text: String) {
        write(text, isTransient: false)
    }

    private func write(_ text: String, isTransient: Bool) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if isTransient {
            // Asks clipboard managers not to record this short-lived entry.
            // See http://nspasteboard.org
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    private func sendPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        for isKeyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: isKeyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
