import Foundation

/// Entities with properties that can be transformed according to business logic
protocol DomainMappable {}

@available(iOS 15, *)
extension RichTextViewModel: DomainMappable {}

@available(iOS 15, *)
extension BasicTextViewModel: DomainMappable {}

@available(iOS 15, *)
extension LayoutSchemaViewModel: DomainMappable {}

@available(iOS 15, *)
extension ProgressIndicatorViewModel: DomainMappable {}
