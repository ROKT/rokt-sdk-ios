import Foundation

/// Entities that have `DomainMappable` children
@available(iOS 15, *)
protocol DomainMappableParent {
    var children: [LayoutSchemaViewModel]? { get set }
    mutating func updateChildren(_ updatedChildren: [LayoutSchemaViewModel]?)
}

@available(iOS 15, *)
extension DomainMappableParent {
    mutating func updateChildren(_ updatedChildren: [LayoutSchemaViewModel]?) {
        self.children = updatedChildren
    }
}

@available(iOS 15, *)
extension OverlayViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension BottomSheetViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension RowViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension ColumnViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension WhenViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension CreativeResponseViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension OneByOneViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension CarouselViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension GroupedDistributionViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension ProgressControlViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension ZStackViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension ToggleButtonViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension CatalogStackedCollectionViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension CatalogCombinedCollectionViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension CatalogResponseButtonViewModel: DomainMappableParent {}

@available(iOS 15, *)
extension CatalogDevicePayButtonViewModel: DomainMappableParent {}
