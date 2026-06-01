import Foundation

protocol DataSanitising {
    associatedtype T

    func sanitiseDelimiters(data: T) -> T
    func sanitiseNamespace(data: T, namespace: BNFNamespace) -> T
}

struct DataSanitiser: DataSanitising {
    func sanitiseDelimiters(data: String) -> String {
        data.replacingOccurrences(of: BNFSeparator.startDelimiter.rawValue, with: "")
            .replacingOccurrences(of: BNFSeparator.endDelimiter.rawValue, with: "")
    }

    func sanitiseNamespace(data: String, namespace: BNFNamespace) -> String {
        var inputData = data

        if data.contains(namespace.withNamespaceSeparator) {
            inputData = inputData.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        return inputData.replacingOccurrences(of: namespace.withNamespaceSeparator, with: "")
    }
}
