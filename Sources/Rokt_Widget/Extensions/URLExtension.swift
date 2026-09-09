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

    /// `true` for an `http`/`https` URL that also names a host — the only shape a web view can load.
    func isWebURLWithHost() -> Bool {
        return isWebURL() && !(host ?? "").isEmpty
    }
}
