import Foundation
import Observation
import os

/// A license key activated on this Mac.
nonisolated struct Activation: Codable, Equatable, Sendable {
    let licenseKey: String
    /// Dodo's ID for this Mac's activation (`lki_…`), needed to deactivate it.
    let instanceID: String
    /// When Dodo last confirmed the key was still valid.
    var lastValidated: Date
}

/// The license that unlocks LocalBolo. It's activated once with the key from
/// the purchase email, then quietly re-checked every couple of weeks so a
/// refunded or deactivated key stops working. Being offline never locks
/// anyone out.
@Observable
final class LicenseManager {
    /// How long an activation goes between checks with Dodo: two weeks.
    static let revalidationInterval: TimeInterval = 14 * 24 * 60 * 60

    private(set) var activation: Activation?
    /// True while a request to Dodo is in flight.
    private(set) var isWorking = false
    /// Why the last activation or deactivation failed, for the UI.
    private(set) var errorMessage: String?

    var isActivated: Bool { activation != nil }

    @ObservationIgnored private let client: LicenseClient?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var revalidationLoop: Task<Void, Never>?

    /// The activation is kept in user defaults rather than the keychain: a
    /// license key isn't a password, and the keychain would prompt after every
    /// rebuild of an ad-hoc signed development build.
    private static let defaultsKey = "licenseActivation"

    init(client: LicenseClient? = .configured, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.client = client
        self.defaults = defaults
        self.now = now
        activation = defaults.data(forKey: Self.defaultsKey).flatMap { try? JSONDecoder().decode(Activation.self, from: $0) }
    }

    /// Re-checks the activation now if it's due, then about twice a day, since
    /// LocalBolo usually runs for weeks at a time.
    func start() {
        revalidationLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.revalidateIfDue()
                try? await Task.sleep(for: .seconds(12 * 60 * 60))
            }
        }
    }

    /// Activates `key` on this Mac.
    func activate(key rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !isWorking, let client else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let instanceID = try await client.activate(key: key, deviceName: Self.deviceName)
            save(Activation(licenseKey: key, instanceID: instanceID, lastValidated: now()))
            Logger.license.info("Activated this Mac")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes the activation from this Mac, freeing it for another one.
    func deactivate() async {
        guard let activation, !isWorking, let client else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do throws(LicenseError) {
            try await client.deactivate(key: activation.licenseKey, instanceID: activation.instanceID)
        } catch .notFound, .inactive {
            // Already gone on Dodo's side, so there's nothing left to free.
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        save(nil)
        Logger.license.info("Deactivated this Mac")
    }

    /// Asks Dodo whether the key is still valid if it's been a while. Only a
    /// definite "no" removes the activation; errors leave it in place.
    func revalidateIfDue() async {
        guard var activation, let client, isRevalidationDue(activation) else { return }

        let isValid: Bool
        do throws(LicenseError) {
            isValid = try await client.validate(key: activation.licenseKey, instanceID: activation.instanceID)
        } catch .notFound, .inactive {
            isValid = false
        } catch {
            Logger.license.info("Couldn't re-check the license: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Someone may have deactivated this Mac, or entered another key, while
        // the check was in flight. Its answer is about the old activation only.
        guard self.activation?.instanceID == activation.instanceID else { return }

        if isValid {
            activation.lastValidated = now()
            save(activation)
        } else {
            Logger.license.notice("License key is no longer valid; removing the activation")
            save(nil)
        }
    }

    /// Due every two weeks. A date in the future can only come from editing the
    /// preferences by hand, so it's due straight away rather than trusted.
    private func isRevalidationDue(_ activation: Activation) -> Bool {
        let sinceLastCheck = now().timeIntervalSince(activation.lastValidated)
        return sinceLastCheck < 0 || sinceLastCheck >= Self.revalidationInterval
    }

    private func save(_ activation: Activation?) {
        self.activation = activation
        if let activation, let data = try? JSONEncoder().encode(activation) {
            defaults.set(data, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }

    /// The name this Mac's activation is listed under, such as "Priya's MacBook Air".
    private static var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }
}
