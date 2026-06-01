import Foundation
import DcuiSchema

@available(iOS 15, *)
class CatalogStackedCollectionViewModel: Identifiable, Hashable, ScreenSizeAdaptive {

    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?
    let defaultStyle: [CatalogStackedCollectionStyles]?
    weak var layoutState: (any LayoutStateRepresenting)?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }
    init(
        children: [LayoutSchemaViewModel]?,
        defaultStyle: [CatalogStackedCollectionStyles]?,
        layoutState: any LayoutStateRepresenting
    ) {
        self.children = children
        self.defaultStyle = defaultStyle
        self.layoutState = layoutState
    }
}
