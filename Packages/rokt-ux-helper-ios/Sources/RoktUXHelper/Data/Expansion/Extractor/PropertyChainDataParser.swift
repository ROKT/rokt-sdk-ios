import Foundation

protocol PropertyChainDataParsing {
    func parse(propertyChain: String) -> BNFPlaceholder
    func namespaceIn(placeholder: String) -> BNFNamespace?
}

/// Strips namespace and separators from a BNF-formatted String and separates it into possible values, including default
struct PropertyChainDataParser<Sanitiser: DataSanitising>: PropertyChainDataParsing where Sanitiser.T == String {
    private let sanitiser: Sanitiser

    init(sanitiser: Sanitiser = DataSanitiser()) {
        self.sanitiser = sanitiser
    }

    func parse(propertyChain: String) -> BNFPlaceholder {
        // Given `propertyChain` = "%^DATA.creativeCopy.firstValue | DATA.creativeCopy.secondValue^%"

        // Trim whitespaces
        let trimmedPropertyChain = propertyChain.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert to "DATA.creativeCopy.firstValue | DATA.creativeCopy.secondValue"
        var sanitisedFullChain = sanitiser.sanitiseDelimiters(data: trimmedPropertyChain)

        var defaultValue: String?
        if let lastChar = sanitisedFullChain.last, String(lastChar) == BNFSeparator.alternative.rawValue {
            // if the last character is "|", remove it and set "" as default value
            sanitisedFullChain = String(sanitisedFullChain.dropLast(1))
            defaultValue = ""
        }

        // Convert to [DATA.creativeCopy.firstValue, DATA.creativeCopy.secondValue]
        let sanitisedFullChainList = sanitisedFullChain.components(separatedBy: BNFSeparator.alternative.rawValue)

        // Prepare namespace and generate ["firstValue": BNFNamespace.dataCreativeCopy, "secondValue": BNFNamespace.dataCreativeCopy]
        // This does not extract data yet. This is in preparation for the extraction
        var parseableChains = getParseableChainsIn(sanitisedFullChainList: sanitisedFullChainList)

        // if the last character is not "|", attempt to extract the last sentence as default value
        if defaultValue == nil {
            defaultValue = getDefaultValueIn(sanitisedFullChainList: sanitisedFullChainList)
        }

        // if defaultValue is still unassigned, set the last key in this chain to isMandatory
        if defaultValue == nil {
            parseableChains.indices.last.map { parseableChains[$0].isMandatory = true }
        }

        return BNFPlaceholder(parseableChains: parseableChains, defaultValue: defaultValue)
    }

    // given %^DATA.creativeResponse.shortLabel | DATA.creativeCopy.creative.copy | some_default_value%^
    // returns [ {"shortLabel", BNFNamespace.dataCreativeResponse}, {"creative.copy", BNFNamespace.dataCreativeCopy} ]
    private func getParseableChainsIn(sanitisedFullChainList: [String]) -> [BNFKeyAndNamespace] {
        sanitisedFullChainList.compactMap {
            guard let namespace = namespaceIn(placeholder: $0) else { return nil }

            let chainWithoutNamespace = sanitiser.sanitiseNamespace(data: $0, namespace: namespace)

            return BNFKeyAndNamespace(key: chainWithoutNamespace, namespace: namespace)
        }
    }

    // given %^DATA.creativeResponse.shortLabel | DATA.creativeCopy.creative.copy | some_default_value%^
    // returns some_default_value
    private func getDefaultValueIn(sanitisedFullChainList: [String]) -> String? {
        guard let defV = sanitisedFullChainList.last, namespaceIn(placeholder: defV) == nil else { return nil }

        return defV.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func namespaceIn(placeholder: String) -> BNFNamespace? {
        BNFNamespace.allCases.first(where: {placeholder.contains($0.withNamespaceSeparator)})
    }
}
