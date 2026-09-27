import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app process; keep them free of global
        // keyboard monitors, microphone access and floating windows.
        guard !ProcessInfo.processInfo.isRunningUnitTests else { return }
        model.start()
    }
}

private extension ProcessInfo {
    var isRunningUnitTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
