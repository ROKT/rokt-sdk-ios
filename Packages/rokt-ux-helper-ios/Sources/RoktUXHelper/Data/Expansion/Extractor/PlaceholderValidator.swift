import Foundation

protocol DataValidating {
    associatedtype T

    func isValid(data: T) -> Bool
}

/// Checks if a BNF-formatted String is correctly formatted
struct PlaceholderValidator<Sanitiser: DataSanitising>: DataValidating where Sanitiser.T == String {
    private let sanitiser: Sanitiser
    private let parser: PropertyChainDataParsing

    init(
        sanitiser: Sanitiser = DataSanitiser(),
        parser: PropertyChainDataParsing = PropertyChainDataParser()
    ) {
        self.sanitiser = sanitiser
        self.parser = parser
    }

    func isValid(data: String) -> Bool {
        // if the last character is '|', we exclude it from format validation
        var dataToCheck = data

        if let lastChar = dataToCheck.last, String(lastChar) == BNFSeparator.alternative.rawValue {
            dataToCheck = String(dataToCheck.dropLast(1))
        }

        return areAllBindingsValid(placeholder: dataToCheck)
    }

    private func areAllBindingsValid(placeholder: String) -> Bool {
        let bindings = placeholder.components(separatedBy: BNFSeparator.alternative.rawValue)

        guard !bindings.isEmpty else { return false }

        var isValid = true
        for (index, binding) in bindings.enumerated() {
            // remove namespace
            // split by .
            if index == 0 {
                isValid = isValid &&
                            parser.namespaceIn(placeholder: binding) != nil &&
                            hasValidCharactersAndNamespace(binding: binding)
            }

            isValid = isValid && hasValidCharactersAndNamespace(binding: binding)
        }

        return isValid
    }

    private func hasValidCharactersAndNamespace(binding: String) -> Bool {
        var sanitisedBinding = sanitiser.sanitiseDelimiters(data: binding)
        if let namespace = parser.namespaceIn(placeholder: binding) {
            sanitisedBinding = sanitiser.sanitiseNamespace(data: sanitisedBinding, namespace: namespace)
        }

        let wordsInBinding = sanitisedBinding.components(separatedBy: BNFSeparator.namespace.rawValue)

        return wordsInBinding.allSatisfy(hasOnlyAlphaNumericOrSpace(binding:))
    }

    private func hasOnlyAlphaNumericOrSpace(binding: String) -> Bool {
        guard !binding.isEmpty else { return false }

        return binding.range(of: "[^a-zA-Z0-9 ]", options: .regularExpression) == nil
    }
}
