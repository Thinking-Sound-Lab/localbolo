import AppKit
import UniformTypeIdentifiers

/// The app a transcript will be pasted into.
struct TargetApplication: Equatable {
    let processIdentifier: pid_t
    let name: String
    let icon: NSImage

    init?(_ app: NSRunningApplication?) {
        guard let app else { return nil }
        processIdentifier = app.processIdentifier
        name = app.localizedName ?? "App"
        icon = app.icon ?? NSWorkspace.shared.icon(for: .application)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier
    }
}
