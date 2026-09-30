import Foundation

/// Pages on the LocalBolo website that the app links to. The website's address
/// comes from the WEBSITE_URL build setting, through the app's Info.plist.
enum AppLinks {
    static let buy = page("/#pricing")
    /// Sends buyers to Dodo's customer portal, where they can look up their key.
    static let findLicense = page("/license")
    static let support = page("/support")

    private static func page(_ path: String) -> URL {
        guard let website = Bundle.main.object(forInfoDictionaryKey: "WebsiteURL") as? String,
              !website.isEmpty, let url = URL(string: website + path)
        else { return URL(string: "https://localbolo.app\(path)")! }
        return url
    }
}
