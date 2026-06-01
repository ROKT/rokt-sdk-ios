import Foundation

struct PlaceholderResolutionContext {
    let offers: [OfferModel?]
    let currentOfferIndex: Int
    let activeCatalogItem: CatalogItem?
}

final class PlaceholderPredicateResolver {

    private let creativeExtractor: CreativeDataExtractor<PlaceholderValidator<DataSanitiser>>
    private let catalogExtractor: CatalogDataExtractor<PlaceholderValidator<DataSanitiser>>
    private let parser: PropertyChainDataParsing

    init(creativeExtractor: CreativeDataExtractor<PlaceholderValidator<DataSanitiser>> = CreativeDataExtractor(),
         catalogExtractor: CatalogDataExtractor<PlaceholderValidator<DataSanitiser>> = CatalogDataExtractor(),
         parser: PropertyChainDataParsing = PropertyChainDataParser()) {
        self.creativeExtractor = creativeExtractor
        self.catalogExtractor = catalogExtractor
        self.parser = parser
    }

    func resolveString(placeholder: String,
                       context: PlaceholderResolutionContext) -> String? {
        do {
            guard let extracted = try extract(placeholder: placeholder, context: context) else { return nil }
            if let stringValue = extracted as? String {
                return stringValue
            }
            if let decimalValue = extracted as? Decimal {
                return NSDecimalNumber(decimal: decimalValue).stringValue
            }
            if let convertible = extracted as? CustomStringConvertible {
                return convertible.description
            }
            return nil
        } catch {
            return nil
        }
    }

    func resolveDecimal(placeholder: String,
                        context: PlaceholderResolutionContext) -> Decimal? {
        do {
            guard let extracted = try extract(placeholder: placeholder, context: context) else { return nil }

            if let decimalValue = extracted as? Decimal {
                return decimalValue
            }

            if let stringValue = extracted as? String {
                return Decimal(string: stringValue)
            }

            if let intValue = extracted as? Int {
                return Decimal(intValue)
            }

            if let number = extracted as? NSNumber {
                return number.decimalValue
            }

            return nil
        } catch {
            return nil
        }
    }

    func resolveInt(placeholder: String,
                    context: PlaceholderResolutionContext) -> Int? {
        if let decimal = resolveDecimal(placeholder: placeholder, context: context) {
            return NSDecimalNumber(decimal: decimal).intValue
        }
        return nil
    }

    func resolveTextLength(placeholder: String,
                           context: PlaceholderResolutionContext) -> Int? {
        guard let rawValue = resolveString(placeholder: placeholder, context: context) else { return nil }
        return rawValue.count
    }

    private func extract(placeholder: String,
                         context: PlaceholderResolutionContext) throws -> Any? {
        let parsedPlaceholder = parser.parse(propertyChain: placeholder)

        for keyAndNamespace in parsedPlaceholder.parseableChains {
            switch keyAndNamespace.namespace {
            case .dataCreativeCopy, .dataCreativeResponse, .dataCreativeLink, .dataImageCarousel:
                guard let offer = context.offers[safe: context.currentOfferIndex] else { continue }
                let result = try creativeExtractor.extractDataRepresentedBy(String.self,
                                                                            propertyChain: keyAndNamespace.withNamespace,
                                                                            responseKey: nil,
                                                                            from: offer)
                return unwrapBinding(result)
            case .dataCatalogItem:
                if let catalogItem = context.activeCatalogItem {
                    let result = try catalogExtractor.extractDataRepresentedBy(String.self,
                                                                               propertyChain: keyAndNamespace.withNamespace,
                                                                               responseKey: nil,
                                                                               from: catalogItem)
                    return unwrapBinding(result)
                }
            case .state:
                if keyAndNamespace.key == DataBindingStateKeys.indicatorPosition {
                    return String(context.currentOfferIndex)
                }
                if keyAndNamespace.key == DataBindingStateKeys.totalOffers {
                    return String(context.offers.count)
                }
            case .dataTransactionData, .dataCatalogRuntime:
                // Predicates targeting transactionData / DATA.catalogRuntime.* aren't supported
                // through this resolver; the When predicate framework would need its own
                // injection. Skip so other chain alternatives can resolve.
                continue
            }
        }

        return parsedPlaceholder.defaultValue
    }

    private func unwrapBinding(_ binding: DataBinding<String>) -> Any {
        switch binding {
        case .value(let value), .state(let value):
            return value
        }
    }

}

private extension BNFKeyAndNamespace {
    var withNamespace: String {
        namespace.rawValue + BNFSeparator.namespace.rawValue + key
    }
}
