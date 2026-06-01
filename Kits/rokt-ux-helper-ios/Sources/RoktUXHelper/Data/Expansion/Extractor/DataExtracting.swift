import Foundation

protocol DataExtracting {
    associatedtype MappingSource: DomainMappingSource

    func extractDataRepresentedBy<T>(
        _ type: T.Type,
        propertyChain: String,
        responseKey: String?,
        from data: MappingSource?
    ) throws -> DataBinding<T>
}

enum DataBinding<T>: Hashable where T: Hashable {
    case value(T)
    case state(T)
}

enum DataBindingStateKeys {
    static let indicatorPosition = "IndicatorPosition"
    static let totalOffers = "TotalOffers"

    static func isIndicatorPosition(_ key: String) -> Bool {
        key.caseInsensitiveCompare(DataBindingStateKeys.indicatorPosition) == .orderedSame
    }

    static func isTotalOffers(_ key: String) -> Bool {
        key.caseInsensitiveCompare(DataBindingStateKeys.totalOffers) == .orderedSame
    }

    static func isValidKey(_ key: String) -> Bool {
        isIndicatorPosition(key) || isTotalOffers(key)
    }
}
