import Foundation
import os

nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "LocalBolo"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let dictation = Logger(subsystem: subsystem, category: "Dictation")
    static let models = Logger(subsystem: subsystem, category: "Models")
    static let cleanup = Logger(subsystem: subsystem, category: "Cleanup")
    static let license = Logger(subsystem: subsystem, category: "License")
    static let updates = Logger(subsystem: subsystem, category: "Updates")
}
