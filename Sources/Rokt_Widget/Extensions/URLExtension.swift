import Foundation

internal extension URL {
    private static let kHttpPrefix = "http://"
    private static let kHttpsPrefix = "https://"

    func isWebURL() -> Bool {
        return URL.isWebURL(url: self.absoluteString)
    }

    static func isWebURL(url: String) -> Bool {
        return url.lowercased().hasPrefix(kHttpPrefix) || url.lowercased().hasPrefix(kHttpsPrefix)
    }
}
