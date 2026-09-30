import CryptoKit
import Foundation
import IOKit

/// A stable, anonymous ID for this Mac, so a license activation belongs to the
/// Mac it was made on. Copying LocalBolo's settings to another Mac, for example
/// with Migration Assistant, doesn't carry the license with them.
///
/// It's a hash of the Mac's hardware UUID, which survives reinstalling macOS.
/// The UUID itself never leaves the Mac.
nonisolated enum MachineIdentity {
    static let current: String = {
        guard let uuid = hardwareUUID else { return "unknown" }
        let digest = SHA256.hash(data: Data("LocalBolo machine \(uuid)".utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }()

    private static var hardwareUUID: String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}
