import Foundation

/// Final-pass guard that runs after every mapper has had a chance to resolve placeholders
/// in a text node. Two responsibilities:
///
/// 1. **Optional orphans** (`%^X | fallback^%` that no mapper resolved) are substituted with
///    their `|` default literal — matching the original BNF semantic that "if a `|` is
///    present, the layout never fails; we render the fallback instead".
///
/// 2. **Mandatory orphans** (`%^X^%` with no `|` that no mapper resolved) cause the entire
///    line to be zeroed — restoring the original "fail-loud when a critical copy is missing"
///    contract that existed before mappers became chainable.
///
/// **Deferred namespaces** (`DATA.catalogRuntime.*` and any `STATE.*`) are intentionally
/// skipped: they have separate runtime / render-time resolution paths and may be unresolved
/// at finalize time without indicating a defect.
enum OrphanedPlaceholderResolver {

    private static let bnfRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "(?<=\\%\\^)[a-zA-Z0-9 .|_$\\-]*(?=\\^\\%)")
    }()

    /// - Returns: the validated text with optional orphans replaced by their `|` defaults,
    ///   or `nil` if a mandatory orphan was found (caller should render an empty string).
    static func resolve(text: String) -> String? {
        guard let regex = bnfRegex else { return text }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let parser = PropertyChainDataParser()
        let deferredPrefixes = [
            BNFNamespace.dataCatalogRuntime.withNamespaceSeparator,
            BNFNamespace.state.withNamespaceSeparator
        ]

        var result = text
        let startLen = BNFSeparator.startDelimiter.charCount
        let endLen = BNFSeparator.endDelimiter.charCount
        // Walk in reverse so substitutions don't shift earlier match ranges.
        for match in matches.reversed() {
            guard let chainRange = Range(match.range, in: result) else { continue }
            let chain = String(result[chainRange])

            if deferredPrefixes.contains(where: { chain.contains($0) }) { continue }

            let parsed = parser.parse(propertyChain: chain)
            if let fallback = parsed.defaultValue {
                // Replace at the regex-derived position (expanded to include `%^` and `^%`).
                // A global string search would re-target the first identical token if the same
                // placeholder appears multiple times; reverse iteration keeps positional ranges
                // valid because earlier indices stay stable when later content shifts.
                let tokenStart = result.index(chainRange.lowerBound, offsetBy: -startLen)
                let tokenEnd = result.index(chainRange.upperBound, offsetBy: endLen)
                result.replaceSubrange(tokenStart..<tokenEnd, with: fallback)
            } else {
                // Mandatory and unresolved → fail-loud.
                return nil
            }
        }
        return result
    }
}
