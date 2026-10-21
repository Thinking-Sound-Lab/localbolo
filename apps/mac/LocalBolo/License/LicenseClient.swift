import CryptoKit
import Foundation

/// Direct purchases use Dodo's public API; AppSumo purchases use our license
/// server. No payment or AppSumo API secret is included in the app.
nonisolated struct LicenseClient: Sendable {
    /// Sends a request and returns the response. Replaced in tests.
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    let baseURL: URL
    var appSumoBaseURL: URL? = nil
    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    /// The client for the server in the app's Info.plist: Dodo's test mode in
    /// development builds and live mode in production.
    static var configured: LicenseClient? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "LicenseServerURL") as? String,
              !value.isEmpty, let url = URL(string: value)
        else { return nil }
        let appSumoValue = Bundle.main.object(forInfoDictionaryKey: "AppSumoLicenseServerURL") as? String
        let appSumoURL = appSumoValue.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        return LicenseClient(baseURL: url, appSumoBaseURL: appSumoURL)
    }

    static func isAppSumoKey(_ key: String) -> Bool {
        key.uppercased().hasPrefix("LB-AS-")
    }

    /// Activates `key` on this Mac and returns the provider's activation ID.
    func activate(key: String, deviceName: String, deviceID: String? = nil) async throws(LicenseError) -> String {
        struct Request: Encodable { let licenseKey: String; let name: String; let deviceId: String? }
        struct Response: Decodable { let id: String }
        var appSumoDeviceID: String?
        if Self.isAppSumoKey(key) {
            guard let deviceID, !deviceID.isEmpty, deviceID != "unknown" else { throw .unexpectedResponse }
            // Keep the existing on-disk machine ID compatible with older
            // releases, and send a provider-specific hash to our server.
            appSumoDeviceID = SHA256.hash(data: Data("LocalBolo AppSumo device \(deviceID)".utf8))
                .map { String(format: "%02x", $0) }.joined()
        }
        let data = try await post("licenses/activate", key: key, Request(
            licenseKey: key, name: deviceName, deviceId: appSumoDeviceID
        ))
        guard let response = try? decoder.decode(Response.self, from: data) else { throw .unexpectedResponse }
        return response.id
    }

    /// Whether `key` is still active and this Mac's activation still exists.
    func validate(key: String, instanceID: String) async throws(LicenseError) -> Bool {
        struct Request: Encodable { let licenseKey: String; let licenseKeyInstanceId: String }
        struct Response: Decodable { let valid: Bool }
        let data = try await post("licenses/validate", key: key, Request(licenseKey: key, licenseKeyInstanceId: instanceID))
        guard let response = try? decoder.decode(Response.self, from: data) else { throw .unexpectedResponse }
        return response.valid
    }

    /// Removes this Mac's activation, freeing it for another Mac.
    func deactivate(key: String, instanceID: String) async throws(LicenseError) {
        struct Request: Encodable { let licenseKey: String; let licenseKeyInstanceId: String }
        _ = try await post("licenses/deactivate", key: key, Request(licenseKey: key, licenseKeyInstanceId: instanceID))
    }

    private var decoder: JSONDecoder { JSONDecoder() }

    private func post(_ path: String, key: String, _ body: some Encodable) async throws(LicenseError) -> Data {
        let server: URL
        if Self.isAppSumoKey(key) {
            guard let appSumoBaseURL else { throw .unexpectedResponse }
            server = appSumoBaseURL
        } else {
            server = baseURL
        }
        var request = URLRequest(url: server.appending(path: path), timeoutInterval: 20)
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
    /// The request didn't reach the license server.
    case offline
    case unexpectedResponse
}

extension LicenseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFound:
            "That license key wasn't found. Check your purchase email or AppSumo activation page."
        case .inactive:
            "That license key is no longer active."
        case .activationLimitReached:
            "That key is already active on as many Macs as it allows. Remove a Mac in LocalBolo's Settings or your AppSumo license page, then try again."
        case .offline:
            "Couldn't reach the license server. Check your internet connection and try again."
        case .unexpectedResponse:
            "Something went wrong activating that key. Please try again in a minute."
        }
    }
}
