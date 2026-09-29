import Foundation
import Observation
import os
import Sparkle

/// Finds and installs new versions of LocalBolo with Sparkle, which checks
/// the update feed once a day and installs only updates signed with our key.
///
/// It's off unless the build has both a feed and a public key: development
/// builds have neither, so they never try to replace themselves.
@Observable
final class Updater {
    /// Whether this build can update itself at all.
    let isAvailable: Bool
    /// False while a check is already running.
    private(set) var canCheckForUpdates = false

    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        isAvailable = !feedURL.isEmpty && !publicKey.isEmpty
        controller = isAvailable
            ? SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    /// Whether Sparkle checks for updates on its own, once a day. People can
    /// turn this off in Settings; Sparkle remembers the choice.
    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    func start() {
        guard let controller else {
            Logger.updates.info("Updates are off in this build")
            return
        }
        controller.startUpdater()
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    /// Checks now and shows the result, even when LocalBolo is up to date.
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
