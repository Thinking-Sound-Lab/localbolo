import Foundation
import Observation
import os

/// A license key activated on this Mac.
nonisolated struct Activation: Codable, Equatable, Sendable {
    let licenseKey: String
    /// Dodo's ID for this Mac's activation (`lki_…`), needed to deactivate it.
    let instanceID: String
    /// The Mac the key was activated on (`MachineIdentity`).
    let machineID: String
    /// When Dodo last confirmed the key was still valid.
    var lastValidated: Date
    /// The latest time LocalBolo has seen, to tell when the clock is turned
    /// back.
    var latestSeen: Date
}

/// The license that unlocks LocalBolo on this Mac.
///
/// The buyer activates the key from their purchase email once. Each
/// activation is tied to one Mac, and Dodo limits how many Macs a key can be
/// active on. Every two weeks the app quietly re-checks the key, so a refunded
/// or deactivated key stops working; if it can't get through for a month, or
/// the clock is turned back, it asks to connect once before dictating again.
@Observable
final class LicenseManager {
    enum Status: Equatable {
        case notActivated
        case active
        /// Activated, but it's been too long since a successful check with
        /// Dodo, or the clock has been turned back since.
        case needsVerification
    }

    /// How often the app re-checks the key with Dodo: every two weeks.
    static let revalidationInterval: TimeInterval = 14 * 24 * 60 * 60
    /// How long LocalBolo keeps working without a successful check: 30 days.
    static let offlineAllowance: TimeInterval = 30 * 24 * 60 * 60
    /// How far the clock can go back without needing a check: enough for the
    /// small corrections macOS makes by itself.
    static let clockTolerance: TimeInterval = 10 * 60

    private(set) var activation: Activation?
    /// True while a request the user asked for is in flight.
    private(set) var isWorking = false
    /// Why the last activation, check or deactivation failed, for the UI.
    private(set) var errorMessage: String?

    var status: Status {
        guard let activation else { return .notActivated }
        if clockWentBack(activation) { return .needsVerification }
        let sinceLastCheck = max(now(), activation.latestSeen).timeIntervalSince(activation.lastValidated)
        return sinceLastCheck < Self.offlineAllowance ? .active : .needsVerification
    }

    /// Whether dictation is unlocked.
    var isLicensed: Bool { status == .active }

    @ObservationIgnored private let client: LicenseClient?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let machineID: String
    @ObservationIgnored private var revalidationLoop: Task<Void, Never>?

    /// The activation is kept in user defaults rather than the keychain: a
    /// license key isn't a password, and the keychain would prompt after every
    /// rebuild of an ad-hoc signed development build.
    private static let defaultsKey = "licenseActivation"

    init(
        client: LicenseClient? = .configured,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        machineID: String = MachineIdentity.current
    ) {
        self.client = client
        self.defaults = defaults
        self.now = now
        self.machineID = machineID

        let stored = defaults.data(forKey: Self.defaultsKey).flatMap { try? JSONDecoder().decode(Activation.self, from: $0) }
        if let stored, stored.machineID != machineID {
            // Settings copied from another Mac. That activation belongs to it.
            Logger.license.notice("Ignoring an activation made on another Mac")
            defaults.removeObject(forKey: Self.defaultsKey)
        } else {
            activation = stored
        }
    }

    /// Re-checks the activation now if it's due, then about twice a day, since
    /// LocalBolo usually runs for weeks at a time.
    func start() {
        revalidationLoop = Task { [weak self] in
            while !Task.isCancelled {
                self?.noteCurrentTime()
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
            let instanceID = try await client.activate(key: key, deviceName: deviceName)
            let date = now()
            save(Activation(licenseKey: key, instanceID: instanceID, machineID: machineID, lastValidated: date, latestSeen: date))
            Logger.license.info("Activated this Mac")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Checks the key with Dodo right away, for "Try Again" and "Verify Now".
    func verifyNow() async {
        guard let activation, !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        if let error = await check(activation) {
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

    /// Checks the key with Dodo if it's been two weeks, or if the clock has
    /// been turned back. Errors are only logged: being offline is fine until
    /// the 30-day allowance runs out.
    func revalidateIfDue() async {
        guard let activation else { return }
        let sinceLastCheck = now().timeIntervalSince(activation.lastValidated)
        guard clockWentBack(activation) || sinceLastCheck >= Self.revalidationInterval else { return }

        if let error = await check(activation) {
            Logger.license.info("Couldn't re-check the license: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private

    /// Asks Dodo whether `activation` is still valid and records the answer:
    /// a yes renews it, a definite no removes it. Returns why the question
    /// couldn't be answered, if it couldn't.
    private func check(_ activation: Activation) async -> LicenseError? {
        guard let client else { return .unexpectedResponse }

        let isValid: Bool
        do throws(LicenseError) {
            isValid = try await client.validate(key: activation.licenseKey, instanceID: activation.instanceID)
        } catch .notFound, .inactive {
            isValid = false
        } catch {
            return error
        }

        // Someone may have deactivated this Mac, or entered another key, while
        // the check was in flight. Its answer is about the old activation only.
        guard var current = self.activation, current.instanceID == activation.instanceID else { return nil }

        if isValid {
            // Start counting again from the clock as it reads now, even if it
            // was changed: Dodo has just confirmed the key.
            let date = now()
            current.lastValidated = date
            current.latestSeen = date
            save(current)
        } else {
            Logger.license.notice("License key is no longer valid; removing the activation")
            save(nil)
            errorMessage = LicenseError.inactive.errorDescription
        }
        return nil
    }

    /// Whether the clock reads earlier than a time LocalBolo has already seen,
    /// including a check dated in the future. There's no telling how long it's
    /// been offline then, so the key has to be checked again.
    private func clockWentBack(_ activation: Activation) -> Bool {
        max(activation.lastValidated, activation.latestSeen).timeIntervalSince(now()) > Self.clockTolerance
    }

    private func noteCurrentTime() {
        guard var activation, now() > activation.latestSeen else { return }
        activation.latestSeen = now()
        save(activation)
    }

    private func save(_ activation: Activation?) {
        self.activation = activation
        if let activation, let data = try? JSONEncoder().encode(activation) {
            defaults.set(data, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }

    /// How this Mac is listed among the key's activations, such as "Priya's
    /// MacBook Air · 3f9a2c1b", so the buyer and support can tell Macs apart.
    private var deviceName: String {
        "\(Host.current().localizedName ?? "Mac") · \(machineID.prefix(8))"
    }
}
