import Foundation

/// Resolves `%^DATA.catalogRuntime.<key> | <default>^%` placeholders against the
/// catalog-runtime data dictionary published by the host SDK (e.g. after
/// `/v1/cart/initialize-purchase`).
///
/// Unlike the catalog/creative mappers — which run once at layout-transform time — this
/// resolver is invoked reactively from `BasicTextViewModel` / `RichTextViewModel` whenever
/// `LayoutState.itemsPublisher` emits, so freshly pushed runtime values appear without
/// re-running the transformer.
///
/// The resolver only touches placeholders that contain at least one `DATA.catalogRuntime.*`
/// alternative; everything else passes through untouched so other namespaces (catalog,
/// transactionData, creative) can be handled by their own mappers.
enum CatalogRuntimePlaceholderResolver {

    private static let bnfRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "(?<=\\%\\^)[a-zA-Z0-9 .|_$\\-]*(?=\\^\\%)")
    }()

    static func resolve(text: String, catalogRuntimeData: [String: String]?) -> String {
        guard let regex = bnfRegex else { return text }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        // Build replacements by walking the chain alternatives in order. Reverse-iterate so
        // earlier index ranges remain valid as we splice the result string.
        var result = text
        let prefix = BNFNamespace.dataCatalogRuntime.withNamespaceSeparator
        let startLen = BNFSeparator.startDelimiter.charCount
        let endLen = BNFSeparator.endDelimiter.charCount
        for match in matches.reversed() {
            guard let chainRange = Range(match.range, in: result) else { continue }
            let chain = String(result[chainRange])
            // Skip placeholders that don't reference DATA.catalogRuntime.* in any alternative.
            guard chain.contains(prefix) else { continue }

            let resolved = resolveChain(chain, prefix: prefix, runtimeData: catalogRuntimeData)
            // Replace at the regex-derived position (expanded to include `%^` and `^%`).
            // A global string search would re-target the first identical token if the same
            // placeholder appears multiple times; reverse iteration keeps positional ranges
            // valid because earlier indices stay stable when later content shifts.
            let tokenStart = result.index(chainRange.lowerBound, offsetBy: -startLen)
            let tokenEnd = result.index(chainRange.upperBound, offsetBy: endLen)
            result.replaceSubrange(tokenStart..<tokenEnd, with: resolved)
        }
        return result
    }

    /// Walks the `|`-separated alternatives. For each `DATA.catalogRuntime.<key>` alternative,
    /// returns the runtime value if present. If no runtime alternative resolves and there is
    /// a trailing default literal, returns it. Otherwise returns the chain re-wrapped in
    /// delimiters so the placeholder remains visible (preferable to silently emptying it).
    private static func resolveChain(
        _ chain: String,
        prefix: String,
        runtimeData: [String: String]?
    ) -> String {
        let parts = chain.split(separator: BNFSeparator.alternative.rawValue.first!,
                                omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var fallback: String?
        for part in parts {
            if part.hasPrefix(prefix) {
                let key = String(part.dropFirst(prefix.count))
                if let value = runtimeData?[key], !value.isEmpty {
                    return value
                }
            } else if !part.isEmpty || fallback == nil {
                // Treat trailing literal (no namespace) as the default. An empty trailing
                // literal "" is also a valid default — preserved on first encounter.
                fallback = part
            }
        }
        return fallback ?? (BNFSeparator.startDelimiter.rawValue + chain + BNFSeparator.endDelimiter.rawValue)
    }
}
