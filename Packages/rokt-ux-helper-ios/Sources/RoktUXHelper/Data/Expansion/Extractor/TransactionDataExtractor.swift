import Foundation

struct TransactionDataExtractor<Validator: DataValidating>: DataExtracting where Validator.T == String {

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

    func extractDataRepresentedBy<U>(
        _ type: U.Type,
        propertyChain: String,
        responseKey: String?,
        from data: TransactionData?
    ) throws -> DataBinding<U> {
        guard dataValidator.isValid(data: propertyChain) else {
            return .value(propertyChain as! U)
        }

        let placeholder = parser.parse(propertyChain: propertyChain)
        let resolved = try resolveValue(from: placeholder, data: data)
        let mappedData: Any? = resolved ?? placeholder.defaultValue

        guard let mappedData,
              let normalizedData = unwrapOptional(mappedData) else {
            return .value("" as! U)
        }

        return .value(coerce(normalizedData, to: type))
    }

    private func resolveValue(
        from placeholder: BNFPlaceholder,
        data: TransactionData?
    ) throws -> Any? {
        for keyAndNamespace in placeholder.parseableChains {
            switch keyAndNamespace.namespace {
            case .dataTransactionData:
                guard let data else { continue }
                let resolved = resolveTransactionDataValue(for: keyAndNamespace.key, in: data)
                if resolved.isNil == true, keyAndNamespace.isMandatory {
                    throw BNFPlaceholderError.mandatoryKeyEmpty
                }
                if let resolved {
                    return resolved
                }
            case .dataCatalogItem,
                    .state,
                    .dataCatalogRuntime,
                    .dataCreativeCopy,
                    .dataCreativeResponse,
                    .dataCreativeLink,
                    .dataImageCarousel:
                // Foreign namespaces — handled by other mappers / reactive resolution.
                throw LayoutTransformerError.InvalidSyntaxMapping()
            }
        }
        return nil
    }

    private func resolveTransactionDataValue(for keyPath: String, in data: TransactionData) -> Any? {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else { return nil }
        // Custom walker because `TransactionData` exposes Optional struct members
        // (e.g. `shippingAddress: Address?`) which `DataReflector` treats as opaque
        // Optional mirrors and refuses to recurse into.
        return walk(value: data, remainingKeys: keys)
    }

    private func walk(value: Any, remainingKeys: [String]) -> Any? {
        guard let firstKey = remainingKeys.first else { return unwrapOptional(value) }
        guard let unwrapped = unwrapOptional(value) else { return nil }
        let mirror = Mirror(reflecting: unwrapped)
        // Top-level lookup by label, then recurse into the matched child's value.
        for child in mirror.children {
            guard child.label == firstKey else { continue }
            let next = Array(remainingKeys.dropFirst())
            if next.isEmpty {
                return unwrapOptional(child.value)
            }
            // Special-case dictionary fields like `metadata: [String: String]`.
            if let dict = child.value as? [String: String] {
                let dictKey = next.joined(separator: BNFSeparator.namespace.rawValue)
                return dict[dictKey]
            }
            if let dict = child.value as? [String: Any] {
                let dictKey = next.joined(separator: BNFSeparator.namespace.rawValue)
                return dict[dictKey].flatMap(unwrapOptional)
            }
            return walk(value: child.value, remainingKeys: next)
        }
        return nil
    }

    private func coerce<U>(_ value: Any, to type: U.Type) -> U {
        if let typed = value as? U { return typed }
        if type == String.self, let stringValue = stringValue(from: value) {
            return stringValue as! U
        }
        return value as! U
    }

    private func stringValue(from value: Any) -> String? {
        switch value {
        case let stringValue as String:
            stringValue
        case let boolValue as Bool:
            String(boolValue)
        case let convertible as CustomStringConvertible:
            convertible.description
        default:
            nil
        }
    }

    private func unwrapOptional(_ value: Any) -> Any? {
        var currentValue = value
        var mirror = Mirror(reflecting: currentValue)

        while mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            currentValue = child.value
            mirror = Mirror(reflecting: currentValue)
        }

        return currentValue
    }
}
