import Foundation

/// Validation and matching rules for the return URL used by redirect-based
/// payment methods. Depends on Foundation only so the rules can be checked in
/// isolation from UIKit and the payment provider SDK.
enum ReturnURLMatching {

    /// Returns `true` when `url` can serve as a universal-link return URL: an
    /// `https` scheme, a non-empty host, and no query, fragment, or credentials.
    /// The payment provider appends its own query on return, so a configured
    /// query would make callback matching ambiguous.
    static func isValidUniversalLink(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.query == nil,
              url.fragment == nil,
              url.user == nil,
              url.password == nil else {
            return false
        }
        return true
    }

    /// Returns `true` when `url` and `expected` share a scheme and host
    /// (case-insensitively), the same port, and the same path. The scheme's
    /// default port (443 for `https`, 80 for `http`) counts as no port, so an
    /// incoming `https://host:443/path` matches a configured `https://host/path`.
    /// A trailing slash on the path is ignored, as are the query and fragment.
    static func matchesUniversalLink(_ url: URL, expected: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              let expectedScheme = expected.scheme?.lowercased(),
              scheme == expectedScheme,
              let host = url.host?.lowercased(),
              let expectedHost = expected.host?.lowercased(),
              host == expectedHost,
              effectivePort(of: url, scheme: scheme) == effectivePort(of: expected, scheme: scheme) else {
            return false
        }
        return normalizedPath(of: url) == normalizedPath(of: expected)
    }

    /// Returns `true` when `url` is `<scheme>://<host>` for the configured bare
    /// scheme (compared case-insensitively) and the fixed host. Query and
    /// fragment are ignored.
    static func matchesCustomScheme(_ url: URL, scheme: String, host: String) -> Bool {
        url.scheme?.lowercased() == scheme.lowercased() && url.host == host
    }

    private static let defaultPorts = ["https": 443, "http": 80]

    /// The port to compare: an explicit port, or the scheme's default when none is given.
    private static func effectivePort(of url: URL, scheme: String) -> Int? {
        url.port ?? defaultPorts[scheme]
    }

    private static func normalizedPath(of url: URL) -> String {
        var path = url.path
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path.isEmpty ? "/" : path
    }
}
