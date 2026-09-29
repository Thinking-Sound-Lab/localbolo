import Foundation

/// Pages on the LocalBolo website that the app links to.
enum AppLinks {
    static let buy = URL(string: "https://localbolo.app/#pricing")!
    /// Sends buyers to Dodo's customer portal, where they can look up their key.
    static let findLicense = URL(string: "https://localbolo.app/license")!
    static let support = URL(string: "https://localbolo.app/support")!
}
