import Foundation

class CreativeDataExtractor<Validator: DataValidating>: DataExtracting where Validator.T == String {

    private let dataValidator: Validator
    private let parser: PropertyChainDataParsing
    private let dataReflector: any DataReflecting

    init(
        dataValidator: Validator = PlaceholderValidator(),
        parser: PropertyChainDataParsing = PropertyChainDataParser(),
        dataReflector: any DataReflecting = DataReflector()
    ) {
        self.dataValidator = dataValidator
        self.parser = parser
        self.dataReflector = dataReflector
    }

    // maps `propertyChain` to a value inside `Offer`, if possible
    // note that you can chain statements like A? | B? | Default?
    // if A does not exist, check B, else use default
    func extractDataRepresentedBy<U>(
        _ type: U.Type,
        propertyChain: String,
        responseKey: String?,
        from data: OfferModel?
    ) throws -> DataBinding<U> {
        guard dataValidator.isValid(data: propertyChain) else { return .value(propertyChain as! U) }

        let placeholder = parser.parse(propertyChain: propertyChain)

        let processedData = try processChains(placeholder.parseableChains, responseKey: responseKey, data: data)

        // Use default value if no mapping was found
        let finalData = processedData.mappedValue ?? placeholder.defaultValue

        // Return empty string if no data was found
        guard let finalData else { return .value("" as! U) }

        // Return appropriate type based on whether it's a state or value
        return processedData.isStateType ? .state(finalData as! U) : .value(finalData as! U)
    }

    private func processChains(_ chains: [BNFKeyAndNamespace], responseKey: String?, data: OfferModel?) throws -> ProcessedData {
        for chain in chains {
            let result = try processChain(chain, responseKey: responseKey, data: data)
            if result != .empty {
                return result
            }
        }
        return .empty
    }

    private func processChain(_ chain: BNFKeyAndNamespace, responseKey: String?, data: OfferModel?) throws -> ProcessedData {
        switch chain.namespace {
        case .dataImageCarousel:
            return try processImageCarousel(chain: chain, data: data)
        case .dataCreativeCopy:
            return try processCreativeCopy(chain: chain, data: data)
        case .dataCreativeResponse:
            return try processCreativeResponse(chain: chain, responseKey: responseKey, data: data)
        case .dataCreativeLink:
            return try processCreativeLink(chain: chain, data: data)
        case .state:
            guard DataBindingStateKeys.isValidKey(chain.key) else { return .empty }
            return .init(mappedValue: chain.key, isStateType: true)
        case .dataCatalogItem,
                .dataTransactionData,
                .dataCatalogRuntime:
            // Foreign namespaces — handled by other mappers / reactive resolution.
            return .empty
        }
    }

    private func processImageCarousel(chain: BNFKeyAndNamespace, data: OfferModel?) throws -> ProcessedData {
        guard let data else { return .empty }
        guard let creativeImage = data.creative.images?.first(where: { chain.key.contains($0.key) }) else {
            if chain.isMandatory {
                throw BNFPlaceholderError.mandatoryKeyEmpty
            }
            return .empty
        }
        let childNamespaceKey = chain.key.replacingOccurrences(of: creativeImage.key, with: "")
        let creativeImagesMirror = Mirror(reflecting: creativeImage.value)

        if let mappedValue = dataReflector.getReflectedValue(
            data: creativeImagesMirror,
            keys: childNamespaceKey.split(separator: ".").map(String.init)
        ) as? String {
            return ProcessedData(mappedValue: mappedValue)
        } else if chain.isMandatory {
            throw BNFPlaceholderError.mandatoryKeyEmpty
        }
        return .empty
    }

    private func processCreativeCopy(chain: BNFKeyAndNamespace, data: OfferModel?) throws -> ProcessedData {
        guard let data else { return .empty }

        let creativeCopy = data.creative.copy
        if let copyForKey = creativeCopy[chain.key],
           !copyForKey.isEmpty {
            return ProcessedData(mappedValue: copyForKey)
        } else if chain.isMandatory {
            throw BNFPlaceholderError.mandatoryKeyEmpty
        } else {
            return .empty
        }
    }

    private func processCreativeResponse(
        chain: BNFKeyAndNamespace,
        responseKey: String?,
        data: OfferModel?
    ) throws -> ProcessedData {
        guard let data,
              let responseKey
        else { return .empty }

        var responseOption: RoktUXResponseOption?

        if responseKey.caseInsensitiveCompare(
            BNFNamespace.CreativeResponseKey.positive.rawValue
        ) == .orderedSame {
            responseOption = data.creative.responseOptionsMap?.positive
        } else if responseKey.caseInsensitiveCompare(
            BNFNamespace.CreativeResponseKey.negative.rawValue
        ) == .orderedSame {
            responseOption = data.creative.responseOptionsMap?.negative
        }

        guard let responseOption else { return .empty }

        let responseOptionMirror = Mirror(reflecting: responseOption)
        let chainAsList = toArray(propertyChain: chain.key)

        if let nestedValue = dataReflector.getReflectedValue(data: responseOptionMirror, keys: chainAsList),
        let mappedData = nestedValue as? String {
            return .init(mappedValue: mappedData)
        }
        return .empty
    }

    private func processCreativeLink(chain: BNFKeyAndNamespace, data: OfferModel?) throws -> ProcessedData {
        guard let data else { return .empty }

        let linkObject = data.creative.links?[chain.key]

        let linkTitle = linkObject?.title ?? ""
        let linkURL = linkObject?.url ?? ""

        if !linkTitle.isEmpty && !linkURL.isEmpty {
            return .init(mappedValue: "<a href=\"\(linkURL)\" target=\"_blank\">\(linkTitle)</a>")
        } else if chain.isMandatory {
            throw BNFPlaceholderError.mandatoryKeyEmpty
        } else {
            return .empty
        }
    }

    private func toArray(propertyChain: String) -> [String] {
        propertyChain.components(separatedBy: ".")
    }

    private struct ProcessedData: Equatable {
        let mappedValue: String?
        let isStateType: Bool

        static var empty: ProcessedData {
            return ProcessedData(mappedValue: nil, isStateType: false)
        }

        init(mappedValue: String?, isStateType: Bool = false) {
            self.mappedValue = mappedValue
            self.isStateType = isStateType
        }
    }
}
