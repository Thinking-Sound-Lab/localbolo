import Foundation
import Synchronization
import Testing
@testable import LocalBolo

struct LicenseManagerTests {
    private let defaults = UserDefaults(suiteName: "LocalBoloTests-\(UUID().uuidString)")!
    private let today = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Activation

    @Test func activatesAndRemembersTheKey() async throws {
        let server = FakeLicenseServer(["licenses/activate": .init(status: 201, body: #"{"id":"lki_mac"}"#)])
        let license = makeManager(server)

        await license.activate(key: "  LB-1234-ABCD \n")

        #expect(license.activation == Activation(licenseKey: "LB-1234-ABCD", instanceID: "lki_mac", lastValidated: today))
        #expect(license.errorMessage == nil)
        let body = try #require(server.requests.first?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["license_key"] == "LB-1234-ABCD")
        #expect(json["name"]?.isEmpty == false)

        // A fresh launch picks the activation up again.
        #expect(makeManager(server).isActivated)
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

        #expect(!license.isActivated)
        #expect(license.errorMessage == error.errorDescription)
    }

    @Test func explainsWhenTheServerIsUnreachable() async {
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.activate(key: "LB-1234-ABCD")

        #expect(!license.isActivated)
        #expect(license.errorMessage == LicenseError.offline.errorDescription)
    }

    // MARK: - Re-checking

    @Test func removesAKeyThatIsNoLongerValid() async {
        storeActivation(checkedDaysAgo: 15)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":false}"#)]))

        await license.revalidateIfDue()

        #expect(!license.isActivated)
        #expect(!makeManager(FakeLicenseServer()).isActivated)
    }

    @Test func removesAKeyThatWasDisabled() async {
        storeActivation(checkedDaysAgo: 15)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 403, body: "{}")]))

        await license.revalidateIfDue()

        #expect(!license.isActivated)
    }

    @Test func recordsASuccessfulCheck() async {
        storeActivation(checkedDaysAgo: 15)
        let license = makeManager(FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":true}"#)]))

        await license.revalidateIfDue()

        #expect(license.activation?.lastValidated == today)
    }

    @Test func keepsTheKeyWhenOffline() async {
        storeActivation(checkedDaysAgo: 40)
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.revalidateIfDue()

        #expect(license.isActivated)
    }

    @Test func doesNotCheckAgainSoon() async {
        storeActivation(checkedDaysAgo: 3)
        let server = FakeLicenseServer(["licenses/validate": .init(status: 200, body: #"{"valid":false}"#)])
        let license = makeManager(server)

        await license.revalidateIfDue()

        #expect(license.isActivated)
        #expect(server.requests.isEmpty)
    }

    // MARK: - Deactivation

    @Test(arguments: [200, 404])
    func deactivatesThisMac(status: Int) async throws {
        storeActivation(checkedDaysAgo: 1)
        let server = FakeLicenseServer(["licenses/deactivate": .init(status: status, body: "")])
        let license = makeManager(server)

        await license.deactivate()

        #expect(!license.isActivated)
        let body = try #require(server.requests.first?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["license_key_instance_id"] == "lki_mac")
    }

    @Test func keepsTheActivationIfDeactivationFails() async {
        storeActivation(checkedDaysAgo: 1)
        let license = makeManager(FakeLicenseServer(isOffline: true))

        await license.deactivate()

        #expect(license.isActivated)
        #expect(license.errorMessage == LicenseError.offline.errorDescription)
    }

    // MARK: - Helpers

    private func makeManager(_ server: FakeLicenseServer) -> LicenseManager {
        LicenseManager(client: server.client, defaults: defaults, now: { [today] in today })
    }

    private func storeActivation(checkedDaysAgo days: Double) {
        let activation = Activation(
            licenseKey: "LB-1234-ABCD",
            instanceID: "lki_mac",
            lastValidated: today.addingTimeInterval(-days * 24 * 60 * 60)
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
    private let recorded = Mutex<[URLRequest]>([])

    init(_ responses: [String: Response] = [:], isOffline: Bool = false) {
        self.responses = responses
        self.isOffline = isOffline
    }

    var requests: [URLRequest] { recorded.withLock { $0 } }

    var client: LicenseClient {
        LicenseClient(baseURL: URL(string: "https://licenses.example")!) { [self] request in
            recorded.withLock { $0.append(request) }
            if isOffline { throw URLError(.notConnectedToInternet) }

            let path = String(request.url!.path().dropFirst())
            let response = responses[path] ?? Response(status: 404, body: "{}")
            let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: nil, headerFields: nil)!
            return (Data(response.body.utf8), http)
        }
    }
}
