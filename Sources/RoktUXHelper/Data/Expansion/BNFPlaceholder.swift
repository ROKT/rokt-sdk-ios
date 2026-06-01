import Foundation

struct BNFPlaceholder: Equatable {
    let parseableChains: [BNFKeyAndNamespace]
    let defaultValue: String?
}

enum BNFPlaceholderError: Error {
    case mandatoryKeyEmpty
}

struct BNFKeyAndNamespace: Equatable {
    let key: String
    let namespace: BNFNamespace
    var isMandatory: Bool = false
}
