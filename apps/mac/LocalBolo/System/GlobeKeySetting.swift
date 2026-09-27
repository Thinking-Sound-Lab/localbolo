import Foundation

/// Reads the "Press 🌐 key to" option from System Settings › Keyboard.
///
/// Unless it is set to "Do Nothing", macOS also reacts to fn presses itself,
/// for example by opening the emoji picker when the key is released.
enum GlobeKeySetting {
    private static let domain = "com.apple.HIToolbox" as CFString
    private static let key = "AppleFnUsageType" as CFString

    static var isSetToDoNothing: Bool {
        // Drop the cached copy so changes made in System Settings are picked up.
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue(key, domain) as? Int) == 0
    }
}
