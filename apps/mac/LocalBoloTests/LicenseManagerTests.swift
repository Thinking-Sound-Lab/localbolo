import Foundation
import Synchronization
import Testing
@testable import LocalBolo

struct LicenseManagerTests {
    private let defaults = UserDefaults(suiteName: "LocalBoloTests-\(UUID().uuidString)")!
    private let today = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    // MARK: - Activation

    @Test func activatesAndRemembersTheKey() async throws {
        let server = FakeLicenseServer(["licenses/activate": .init(status: 201, body: #"{"id":"lki_mac"}"#)])
        let license = makeManager(server)

        await license.activate(key: "  LB-1234-ABCD \n")

        #expect(license.activation == Activation(
            licenseKey: "LB-1234-ABCD", instanceID: "lki_mac", machineID: thisMac, lastValidated: today, latestSeen: today
        ))
        #expect(license.isLicensed)
        #expect(license.errorMessage == nil)
        let body = try #require(server.requests.first?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["license_key"] == "LB-1234-ABCD")
        // The Mac's name, plus its anonymous ID so Macs with the same name can be told apart.
        #expect(json["name"]?.hasSuffix(" · \(thisMac.prefix(8))") == true)

        // A fresh launch picks the activation up again.
        #expect(makeManager(server).isLicensed)
    }

    @Test(arguments: [
        (404, LicenseError.notFound),
        (403, LicenseError.inactive),
        (422, LicenseError.activationLimitReached),
        (500, LicenseError.unexpectedResponse),
    ])
    func explainsWhyActivationFailed(status: Int, error: LicenseError) async {
        let license = makeManager(FakeLicenseServer(["licenses/activate": .init(status: status, body: "{}")]))

        await license.activate(key: "LB-1234-ABCD")

        #expect(license.status == .notActivated)
        #expect(license.errorMessage == error.errorDescription)
    }

    @Test func explainsWhenTheServerIsUnreachable() async {
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.activate(key: "LB-1234-ABCD")

        #expect(license.status == .notActivated)
        #expect(license.errorMessage == LicenseError.offline.errorDescription)
    }

    // MARK: - Re-checking

    @Test func removesAKeyThatIsNoLongerValid() async {
        storeActivation(checkedDaysAgo: 15)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":false}"#)]))

        await license.revalidateIfDue()

        #expect(license.status == .notActivated)
        #expect(makeManager(FakeLicenseServer()).status == .notActivated)
    }

    @Test func removesAKeyThatWasDisabled() async {
        storeActivation(checkedDaysAgo: 15)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 403, body: "{}")]))

        await license.revalidateIfDue()

        #expect(license.status == .notActivated)
    }

    @Test func recordsASuccessfulCheck() async {
        storeActivation(checkedDaysAgo: 15)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":true}"#)]))

        await license.revalidateIfDue()

        #expect(license.activation?.lastValidated == today)
    }

    @Test func keepsWorkingOfflineForAMonth() async {
        storeActivation(checkedDaysAgo: 29)
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.revalidateIfDue()

        #expect(license.isLicensed)
    }

    @Test func asksToConnectAfterAMonthOffline() async {
        storeActivation(checkedDaysAgo: 31)
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.revalidateIfDue()

        #expect(license.status == .needsVerification)
        #expect(!license.isLicensed)
    }

    @Test func aSuccessfulCheckEndsTheWait() async {
        storeActivation(checkedDaysAgo: 45)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":true}"#)]))

        await license.verifyNow()

        #expect(license.isLicensed)
        #expect(license.activation?.lastValidated == today)
    }

    @Test func turningTheClockBackAsksForACheck() async {
        // Checked yesterday, and LocalBolo has seen today; the clock now reads two days ago.
        storeActivation(checkedDaysAgo: 1, latestSeenDaysAgo: 0)
        let server = FakeLicenseServer(isOffline: true)
        let license = makeManager(server, now: today.addingTimeInterval(-2 * day))

        await license.revalidateIfDue()

        #expect(license.status == .needsVerification)
        #expect(server.requests.count == 1)
    }

    @Test func smallClockCorrectionsDoNotNeedACheck() {
        storeActivation(checkedDaysAgo: 1, latestSeenDaysAgo: 0)
        let license = makeManager(FakeLicenseServer(), now: today.addingTimeInterval(-5 * 60))

        #expect(license.isLicensed)
    }

    @Test func aCheckWithTheClockAheadDoesNotStretchTheMonth() async {
        // A successful check while the clock reads a year ahead, then the clock is put right.
        storeActivation(checkedDaysAgo: 15)
        let clock = TestClock(today.addingTimeInterval(365 * day))
        let server = FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":true}"#)])
        let license = LicenseManager(client: server.client, defaults: defaults, now: { clock.now }, machineID: thisMac)
        await license.revalidateIfDue()
        #expect(license.isLicensed)

        clock.set(today)

        #expect(license.status == .needsVerification)
    }

    @Test func aSuccessfulCheckUnlocksEvenWithTheClockBehind() async {
        storeActivation(checkedDaysAgo: 31, latestSeenDaysAgo: 0)
        let license = makeManager(
            FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":true}"#)]),
            now: today.addingTimeInterval(-40 * day)
        )

        await license.verifyNow()

        #expect(license.isLicensed)
        #expect(license.activation?.lastValidated == today.addingTimeInterval(-40 * day))
    }

    @Test func ignoresAnActivationFromAnotherMac() {
        storeActivation(checkedDaysAgo: 1, machineID: "another-mac")

        let license = makeManager(FakeLicenseServer())

        #expect(license.status == .notActivated)
        #expect(defaults.data(forKey: "licenseActivation") == nil)
    }

    @Test func checksADateInTheFutureStraightAway() async {
        storeActivation(checkedDaysAgo: -365)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 404, body: "{}")]))

        await license.revalidateIfDue()

        #expect(license.status == .notActivated)
    }

    @Test func aCheckInFlightDoesNotUndoDeactivation() async {
        storeActivation(checkedDaysAgo: 15)
        let (validateGate, openGate) = AsyncStream<Void>.makeStream()
        let server = FakeLicenseServer(
            [
                "licenses/validate": .init(status: 200, body: #"{"valid":true}"#),
                "licenses/deactivate": .init(status: 200, body: ""),
            ],
            validateGate: validateGate
        )
        let license = makeManager(server)

        let check = Task { await license.revalidateIfDue() }
        while server.requests.isEmpty { await Task.yield() }
        await license.deactivate()
        openGate.yield()
        await check.value

        #expect(license.status == .notActivated)
    }

    @Test func doesNotCheckAgainSoon() async {
        storeActivation(checkedDaysAgo: 3)
        let server = FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":false}"#)])
        let license = makeManager(server)

        await license.revalidateIfDue()

        #expect(license.isLicensed)
        #expect(server.requests.isEmpty)
    }

    // MARK: - Deactivation

    @Test(arguments: [200, 404])
    func deactivatesThisMac(status: Int) async throws {
        storeActivation(checkedDaysAgo: 1)
        let server = FakeLicenseServer(["licenses/deactivate": .init(status: status, body: "")])
        let license = makeManager(server)

        await license.deactivate()

        #expect(license.status == .notActivated)
        let body = try #require(server.requests.first?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["license_key_instance_id"] == "lki_mac")
    }

    @Test func keepsTheActivationIfDeactivationFails() async {
        storeActivation(checkedDaysAgo: 1)
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.deactivate()

        #expect(license.isLicensed)
        #expect(license.errorMessage == LicenseError.offline.errorDescription)
    }

    // MARK: - Helpers

    private let thisMac = "0123456789abcdef"

    private func makeManager(_ server: FakeLicenseServer, now: Date? = nil) -> LicenseManager {
        let date = now ?? today
        return LicenseManager(client: server.client, defaults: defaults, now: { date }, machineID: thisMac)
    }

    private func storeActivation(checkedDaysAgo days: Double, latestSeenDaysAgo seenDays: Double? = nil, machineID: String? = nil) {
        let lastValidated = today.addingTimeInterval(-days * day)
        let activation = Activation(
            licenseKey: "LB-1234-ABCD",
            instanceID: "lki_mac",
            machineID: machineID ?? thisMac,
            lastValidated: lastValidated,
            latestSeen: seenDays.map { today.addingTimeInterval(-$0 * day) } ?? lastValidated
        )
        defaults.set(try! JSONEncoder().encode(activation), forKey: "licenseActivation")
    }
}

/// Answers license requests with a canned response for each path, and records them.
private final class FakeLicenseServer: Sendable {
    struct Response: Sendable {
        let status: Int
        let body: String
    }

    private let responses: [String: Response]
    private let isOffline: Bool
    /// When set, validation requests wait for a value from this stream before answering.
    private let validateGate: AsyncStream<Void>?
    private let recorded = Mutex<[URLRequest]>([])

    init(_ responses: [String: Response] = [:], isOffline: Bool = false, validateGate: AsyncStream<Void>? = nil) {
        self.responses = responses
        self.isOffline = isOffline
        self.validateGate = validateGate
    }

    var requests: [URLRequest] { recorded.withLock { $0 } }

    var client: LicenseClient {
        LicenseClient(baseURL: URL(string: "https://licenses.example")!) { [self] request in
            recorded.withLock { $0.append(request) }
            if isOffline { throw URLError(.notConnectedToInternet) }

            let path = String(request.url!.path().dropFirst())
            if path == "licenses/validate", let validateGate {
                for await _ in validateGate { break }
            }
            let response = responses[path] ?? Response(status: 404, body: "{}")
            let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: nil)!
            return (Data(response.body.utf8), http)
        }
    }
}

/// A clock a test can change while LocalBolo is running.
private final class TestClock: Sendable {
    private let date: Mutex<Date>

    init(_ date: Date) {
        self.date = Mutex(date)
    }

    var now: Date { date.withLock { $0 } }

    func set(_ newDate: Date) {
        date.withLock { $0 = newDate }
    }
}
