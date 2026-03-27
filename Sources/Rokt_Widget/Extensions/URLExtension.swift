import Foundation

internal extension URL {
    private static let httpPrefix = "http://"
    private static let httpsPrefix = "https://"

    func isWebURL() -> Bool {
        return URL.isWebURL(url: self.absoluteString)
    }

    static func isWebURL(url: String) -> Bool {
        return url.lowercased().hasPrefix(httpPrefix) || url.lowercased().hasPrefix(httpsPrefix)
    }
}
