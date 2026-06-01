import Foundation

struct CatalogDataExtractor<Validator: DataValidating>: DataExtracting where Validator.T == String {

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
        from data: CatalogItem?
    ) throws -> DataBinding<U> {
        guard dataValidator.isValid(data: propertyChain) else {
            return .value(propertyChain as! U)
        }

        let placeholder = parser.parse(propertyChain: propertyChain)
        let resolution = try resolveValue(from: placeholder, data: data)
        let mappedData: Any? = resolution.value ?? placeholder.defaultValue

        guard let mappedData,
              let normalizedData = unwrapOptional(mappedData) else {
            return .value("" as! U)
        }

        return makeBinding(from: normalizedData, as: type, isState: resolution.isStateType)
    }

    // Keep catalog extraction schema-agnostic so catalog items and future shoppable-ad fields
    // can be resolved without coupling the extractor to a specific schema version.
    private func resolveValue(
        from placeholder: BNFPlaceholder,
        data: CatalogItem?
    ) throws -> (value: Any?, isStateType: Bool) {
        for keyAndNamespace in placeholder.parseableChains {
            switch keyAndNamespace.namespace {
            case .dataCatalogItem:
                guard let data else { continue }
                let resolvedValue = resolveCatalogItemValue(for: keyAndNamespace.key, in: data)
                if resolvedValue.isNil == true, keyAndNamespace.isMandatory {
                    throw BNFPlaceholderError.mandatoryKeyEmpty
                }
                if let resolvedValue {
                    return (resolvedValue, false)
                }
            case .state:
                guard DataBindingStateKeys.isValidKey(keyAndNamespace.key) else { continue }
                return (keyAndNamespace.key, true)
            case .dataCreativeCopy,
                    .dataCreativeResponse,
                    .dataCreativeLink,
                    .dataImageCarousel,
                    .dataTransactionData,
                    .dataCatalogRuntime:
                // Foreign namespaces — handled by other mappers / reactive resolution.
                // The mapper-level filter prevents these from reaching here in normal flow;
                // throw defensively if it does.
                throw LayoutTransformerError.InvalidSyntaxMapping()
            }
        }

        return (nil, false)
    }

    // Nested lookups support dictionary-backed fields such as copy.someKey while preserving
    // the existing scalar access path for current catalog item placeholders.
    private func resolveCatalogItemValue(for keyPath: String, in data: CatalogItem) -> Any? {
        let keys = keyPath.split(separator: ".").map(String.init)
        guard let firstKey = keys.first else { return nil }

        if keys.count > 1 {
            let reflectedValue = dataReflector.getReflectedValue(
                data: Mirror(reflecting: data),
                keys: keys
            )
            guard let reflectedValue else { return nil }
            return unwrapOptional(reflectedValue)
        }

        return Mirror(reflecting: data)
            .children
            .first { $0.label == firstKey }
            .flatMap { unwrapOptional($0.value) }
    }

    private func makeBinding<U>(from value: Any, as type: U.Type, isState: Bool) -> DataBinding<U> {
        let coercedValue = coerce(value, to: type)
        return isState ? .state(coercedValue) : .value(coercedValue)
    }

    // Coercion stays generic on purpose: these non-schema helpers let the same extractor
    // power text, numeric, and state bindings for catalog and shoppable-ad surfaces.
    private func coerce<U>(_ value: Any, to type: U.Type) -> U {
        if let typed = value as? U {
            return typed
        }

        if type == String.self, let stringValue = stringValue(from: value) {
            return stringValue as! U
        }

        if type == Int.self, let intValue = intValue(from: value) {
            return intValue as! U
        }

        if type == Double.self, let doubleValue = doubleValue(from: value) {
            return doubleValue as! U
        }

        if type == Decimal.self, let decimalValue = decimalValue(from: value) {
            return decimalValue as! U
        }

        return value as! U
    }

    private func stringValue(from value: Any) -> String? {
        switch value {
        case let stringValue as String:
            stringValue
        case let decimalValue as Decimal:
            NSDecimalNumber(decimal: decimalValue).stringValue
        case let boolValue as Bool:
            String(boolValue)
        case let convertible as CustomStringConvertible:
            convertible.description
        default:
            nil
        }
    }

    private func intValue(from value: Any) -> Int? {
        switch value {
        case let intValue as Int:
            intValue
        case let stringValue as String:
            Int(stringValue)
        case let decimalValue as Decimal:
            NSDecimalNumber(decimal: decimalValue).intValue
        default:
            nil
        }
    }

    private func doubleValue(from value: Any) -> Double? {
        switch value {
        case let doubleValue as Double:
            doubleValue
        case let stringValue as String:
            Double(stringValue)
        case let decimalValue as Decimal:
            NSDecimalNumber(decimal: decimalValue).doubleValue
        default:
            nil
        }
    }

    private func decimalValue(from value: Any) -> Decimal? {
        switch value {
        case let decimalValue as Decimal:
            decimalValue
        case let stringValue as String:
            Decimal(string: stringValue)
        case let intValue as Int:
            Decimal(intValue)
        case let doubleValue as Double:
            Decimal(doubleValue)
        default:
            nil
        }
    }

    private func unwrapOptional(_ value: Any) -> Any? {
        var currentValue = value
        var mirror = Mirror(reflecting: currentValue)

        while mirror.displayStyle == .optional {
            guard let child = mirror.children.first else {
                return nil
            }
            currentValue = child.value
            mirror = Mirror(reflecting: currentValue)
        }

        return currentValue
    }
}
