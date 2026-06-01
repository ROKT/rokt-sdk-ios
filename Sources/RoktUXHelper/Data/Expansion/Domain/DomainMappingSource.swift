import Foundation

/// Entities with values that can be used to transform `DomainMappable` properties
protocol DomainMappingSource {}

extension OfferModel: DomainMappingSource {}

extension CatalogItem: DomainMappingSource {}

extension TransactionData: DomainMappingSource {}
