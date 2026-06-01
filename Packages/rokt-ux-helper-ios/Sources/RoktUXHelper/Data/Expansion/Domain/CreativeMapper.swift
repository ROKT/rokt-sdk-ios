import Foundation

enum CreativeContext {
    case outer
    case generic(OfferModel?)
    case positiveResponse(OfferModel)
    case negativeResponse(OfferModel)

    var creativeResponse: BNFNamespace.CreativeResponseKey? {
        switch self {
        case .generic, .outer: nil
        case .positiveResponse: .positive
        case .negativeResponse: .negative
        }
    }

    var offerModel: OfferModel? {
        switch self {
        case .generic(.some(let offerModel)),
                .positiveResponse(let offerModel),
                .negativeResponse(let offerModel):
            offerModel
        case .outer,
                .generic(.none): nil
        }
    }
}

/// Maps properties of `Node`s using values in `context`.
/// The mappable property of each `node` is known here (eg. `TextNode`'s value)
/// Bridge that knows the `LayoutSchemaModel` data type
struct CreativeMapper<Extractor: DataExtracting>: SyntaxMapping where Extractor.MappingSource == OfferModel {
    let extractor: Extractor

    init(extractor: Extractor = CreativeDataExtractor()) {
        self.extractor = extractor
    }

    func map(consumer: LayoutSchemaViewModel, context: CreativeContext) {
        switch consumer {
            // assumption is that the `value` property will be the mappable value
            // this is where we decide that only creative.responseOptions is allowed for buttons
        case .richText(let textModel):
            let originalText = textModel.value ?? ""

            let transformedText = resolveDataExpansion(
                originalText,
                context: context
            )

            textModel.updateDataBinding(dataBinding: .value(transformedText))
        case .basicText(let textModel):
            let originalText = textModel.value ?? ""

            let transformedText = resolveDataExpansion(
                originalText,
                context: context
            )

            textModel.updateDataBinding(dataBinding: .value(transformedText))
        case .progressIndicator(let indicatorModel):
            guard let updatedText = try? extractor.extractDataRepresentedBy(
                String.self,
                propertyChain: indicatorModel.indicator,
                responseKey: context.creativeResponse?.rawValue,
                from: context.offerModel
            ) else { return }
            indicatorModel.updateDataBinding(dataBinding: updatedText)
        default:
            break
        }
    }

    private func resolveDataExpansion(_ fullText: String, context: CreativeContext) -> String {
        do {
            guard let offerModel = context.offerModel else { throw LayoutTransformerError.InvalidSyntaxMapping() }
            let placeholdersToResolved = try placeholdersToResolvedValues(fullText,
                                                                          responseKey: context.creativeResponse,
                                                                          dataSource: offerModel)

            var transformedText = fullText

            placeholdersToResolved.forEach {
                let keyWithDelimiters = BNFSeparator.startDelimiter.rawValue + $0 + BNFSeparator.endDelimiter.rawValue
                transformedText = transformedText.replacingOccurrences(of: keyWithDelimiters, with: $1)
            }

            return transformedText
        } catch {
            return ""
        }
    }

    // return type is a hashmap of placeholders to their resolved values
    private func placeholdersToResolvedValues(
        _ fullText: String,
        responseKey: BNFNamespace.CreativeResponseKey?,
        dataSource: OfferModel
    ) throws -> [String: String] {
        // given fullText = "Hello %^DATA.creativeCopy.someValue1^ AND %^DATA.creativeCopy.someValue2^%"
        var placeHolderToResolvedValue: [String: String] = [:]

        let bnfRegexPattern = "(?<=\\%\\^)[a-zA-Z0-9 .|]*(?=\\^\\%)"
        let fullTextRange = NSRange(fullText.startIndex..<fullText.endIndex, in: fullText)

        guard let regexCheck = try? NSRegularExpression(pattern: bnfRegexPattern) else { return [:] }

        // [DATA.creativeCopy.someValue1, DATA.creativeCopy.someValue2]
        let bnfMatches = regexCheck.matches(in: fullText, options: [], range: fullTextRange)

        for match in bnfMatches {
            guard let swiftRange = Range(match.range, in: fullText) else { continue }

            // DATA.creativeCopy.someValue1, DATA.creativeCopy.someValue2
            let chainOfValues = String(fullText[swiftRange])

            // Only resolve placeholders this mapper owns; leave others (catalog, transactionData,
            // DATA.catalogRuntime) intact for subsequent mappers / reactive resolution.
            guard chainBelongsToCreativeMapper(chainOfValues) else { continue }

            let resolvedDataBinding = try extractor.extractDataRepresentedBy(
                String.self,
                propertyChain: chainOfValues,
                responseKey: responseKey?.rawValue,
                from: dataSource
            )

            guard case .value(let resolvedValue) = resolvedDataBinding else { continue }

            // [DATA.creativeCopy.someValue1: "some-value1", DATA.creativeCopy.someValue2: "some-value2"]
            placeHolderToResolvedValue[chainOfValues] = resolvedValue
        }

        return placeHolderToResolvedValue
    }

    private func chainBelongsToCreativeMapper(_ chain: String) -> Bool {
        let creativeMarkers: [BNFNamespace] = [
            .dataCreativeCopy,
            .dataCreativeResponse,
            .dataCreativeLink,
            .dataImageCarousel
        ]
        if creativeMarkers.contains(where: { chain.contains($0.withNamespaceSeparator) }) {
            return true
        }
        // STATE.* placeholders (e.g. STATE.IndicatorPosition) are owned by this mapper too,
        // but DATA.catalogRuntime.* is reserved for reactive resolution in BasicTextViewModel.
        return chain.contains(BNFNamespace.state.withNamespaceSeparator)
            && !chain.contains(BNFNamespace.dataCatalogRuntime.withNamespaceSeparator)
    }
}
