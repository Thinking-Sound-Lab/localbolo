import Foundation

/// Dodo Payments' license API. Activating, validating and deactivating a key
/// are public endpoints, so the app calls them without any secret.
nonisolated struct LicenseClient: Sendable {
    /// Sends a request and returns the response. Replaced in tests.
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let baseURL: URL
    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    /// The client for the server in the app's Info.plist: Dodo's test mode in
    /// development builds and live mode in production.
    static var configured: LicenseClient? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "LicenseServerURL") as? String,
              !value.isEmpty, let url = URL(string: value)
        else { return nil }
        return LicenseClient(baseURL: url)
    }

    /// Activates `key` on this Mac and returns the activation's ID (`lki_…`).
    func activate(key: String, deviceName: String) async throws(LicenseError) -> String {
        struct Request: Encodable { let licenseKey: String; let name: String }
        struct Response: Decodable { let id: String }
        let data = try await post("licenses/activate", Request(licenseKey: key, name: deviceName))
        guard let response = try? decoder.decode(Response.self, from: data) else { throw .unexpectedResponse }
        return response.id
    }

    /// Whether `key` is still active and this Mac's activation still exists.
    func validate(key: String, instanceID: String) async throws(LicenseError) -> Bool {
        struct Request: Encodable { let licenseKey: String; let licenseKeyInstanceId: String }
        struct Response: Decodable { let valid: Bool }
        let data = try await post("licenses/validate", Request(licenseKey: key, licenseKeyInstanceId: instanceID))
        guard let response = try? decoder.decode(Response.self, from: data) else { throw .unexpectedResponse }
        return response.valid
    }

    /// Removes this Mac's activation, freeing it for another Mac.
    func deactivate(key: String, instanceID: String) async throws(LicenseError) {
        struct Request: Encodable { let licenseKey: String; let licenseKeyInstanceId: String }
        _ = try await post("licenses/deactivate", Request(licenseKey: key, licenseKeyInstanceId: instanceID))
    }

    private var decoder: JSONDecoder { JSONDecoder() }

    private func post(_ path: String, _ body: some Encodable) async throws(LicenseError) -> Data {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try? encoder.encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw .offline
        }

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: return data
        case 403: throw .inactive
        case 404: throw .notFound
        case 422: throw .activationLimitReached
        default: throw .unexpectedResponse
        }
    }
}

/// Why a license request failed, in terms the buyer can act on.
nonisolated enum LicenseError: Error, Equatable {
    /// No key like this exists.
    case notFound
    /// The key exists but is disabled or expired, for example after a refund.
    case inactive
    /// The key is already active on as many Macs as it allows.
    case activationLimitReached
    /// The request didn't reach Dodo Payments.
    case offline
    case unexpectedResponse
}

extension LicenseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            "That license key wasn't found. Check it against the email from Dodo Payments."
        case .inactive:
            "That license key is no longer active."
        case .activationLimitReached:
            "That key is already active on as many Macs as it allows. Deactivate it on another Mac in LocalBolo's Settings, then try again."
        case .offline:
            "Couldn't reach the license server. Check your internet connection and try again."
        case .unexpectedResponse:
            "Something went wrong activating that key. Please try again in a minute."
        }
    }
}
