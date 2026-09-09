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
