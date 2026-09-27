import ServiceManagement
import os

/// Registers LocalBolo as a login item.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Logger.app.error("Couldn't update login item: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
