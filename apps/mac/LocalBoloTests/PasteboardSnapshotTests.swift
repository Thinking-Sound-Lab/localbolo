import AppKit
import Testing
@testable import LocalBolo

struct PasteboardSnapshotTests {
    private let pasteboard = NSPasteboard(name: .init("LocalBoloTests-\(UUID().uuidString)"))

    @Test func restoresPreviousText() {
        pasteboard.clearContents()
        pasteboard.setString("What the user copied", forType: .string)

        let snapshot = PasteboardSnapshot(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("Dictated text", forType: .string)
        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "What the user copied")
    }

    @Test func restoresEveryRepresentation() {
        let item = NSPasteboardItem()
        item.setString("Bold", forType: .string)
        item.setString("<b>Bold</b>", forType: .html)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        let snapshot = PasteboardSnapshot(of: pasteboard)
        pasteboard.clearContents()
        snapshot.restore(to: pasteboard)

        #expect(pasteboard.string(forType: .string) == "Bold")
        #expect(pasteboard.string(forType: .html) == "<b>Bold</b>")
    }

    @Test func restoringAnEmptyClipboardLeavesItEmpty() {
        pasteboard.clearContents()

        let snapshot = PasteboardSnapshot(of: pasteboard)
        pasteboard.setString("Dictated text", forType: .string)
        snapshot.restore(to: pasteboard)

        #expect(pasteboard.pasteboardItems?.isEmpty ?? true)
    }
}
