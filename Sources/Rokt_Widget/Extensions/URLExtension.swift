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

    /// `true` when the host is a loopback address: `localhost`, `127.0.0.1` or `::1`. The IPv6 form is matched with
    /// and without its brackets, since Foundation has returned it both ways.
    var hasLoopbackHost: Bool {
        guard let host = host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
    }

    /// Whether this file URL resolves to a location strictly inside `directory`.
    ///
    /// The comparison is purely lexical: `.` and `..` segments are collapsed and the
    /// components compared, without consulting the filesystem. Foundation's own
    /// standardization consults it (symbolic links and the `/private` prefix), so its answer
    /// can differ between a directory that exists and a file that has not been created yet.
    func isContained(in directory: URL) -> Bool {
        let directoryComponents = URL.collapsedPathComponents(directory)
        let candidateComponents = URL.collapsedPathComponents(self)
        guard candidateComponents.count > directoryComponents.count else { return false }
        return Array(candidateComponents.prefix(directoryComponents.count)) == directoryComponents
    }

    private static func collapsedPathComponents(_ url: URL) -> [String] {
        var collapsed: [String] = []
        for component in url.pathComponents where component != "/" && component != "." {
            if component == ".." {
                _ = collapsed.popLast()
            } else {
                collapsed.append(component)
            }
        }
        return collapsed
    }
}
