import Foundation

struct TransactionDataMapper<Extractor: DataExtracting>: SyntaxMapping where Extractor.MappingSource == TransactionData {

    private let extractor: Extractor

    init(extractor: Extractor = TransactionDataExtractor()) {
        self.extractor = extractor
    }

    func map(consumer: LayoutSchemaViewModel, context: TransactionData) {
        switch consumer {
        case .richText(let textModel):
            // Chain after creative/catalog mappers: prefer the post-mapper template so
            // earlier substitutions are preserved (including legitimate empty resolutions);
            // fall back to the raw template on first run.
            let originalText = textModel.currentTemplateText
            let transformedText = resolveDataExpansion(originalText, context: context)
            textModel.updateDataBinding(dataBinding: .value(transformedText))
        case .basicText(let textModel):
            let originalText = textModel.currentTemplateText
            let transformedText = resolveDataExpansion(originalText, context: context)
            textModel.updateDataBinding(dataBinding: .value(transformedText))
        default:
            break
        }
    }

    private func resolveDataExpansion(_ fullText: String, context: TransactionData) -> String {
        do {
            let placeholdersToResolved = try placeholdersToResolvedValues(fullText, data: context)

            var transformedText = fullText
            placeholdersToResolved.forEach {
                let keyWithDelimiters = BNFSeparator.startDelimiter.rawValue
                    + $0
                    + BNFSeparator.endDelimiter.rawValue
                transformedText = transformedText.replacingOccurrences(of: keyWithDelimiters, with: $1)
            }

            return transformedText
        } catch {
            return fullText
        }
    }

    private func placeholdersToResolvedValues(
        _ fullText: String,
        data: TransactionData
    ) throws -> [String: String] {
        var placeHolderToResolvedValue: [String: String] = [:]

        let bnfRegexPattern = "(?<=\\%\\^)[a-zA-Z0-9 .|]*(?=\\^\\%)"
        let fullTextRange = NSRange(fullText.startIndex..<fullText.endIndex, in: fullText)

        guard let regexCheck = try? NSRegularExpression(pattern: bnfRegexPattern) else { return [:] }

        let bnfMatches = regexCheck.matches(in: fullText, options: [], range: fullTextRange)

        for match in bnfMatches {
            guard let swiftRange = Range(match.range, in: fullText) else { continue }

            let chainOfValues = String(fullText[swiftRange])

            // Only resolve placeholders this mapper owns; leave others intact for sibling mappers
            // (catalog, creative) and reactive resolution (DATA.catalogRuntime.*).
            guard chainOfValues.contains(BNFNamespace.dataTransactionData.withNamespaceSeparator) else { continue }

            let resolvedDataBinding = try extractor.extractDataRepresentedBy(
                String.self,
                propertyChain: chainOfValues,
                responseKey: nil,
                from: data
            )

            guard case .value(let resolvedValue) = resolvedDataBinding else { continue }

            placeHolderToResolvedValue[chainOfValues] = resolvedValue
        }

        return placeHolderToResolvedValue
    }
}
