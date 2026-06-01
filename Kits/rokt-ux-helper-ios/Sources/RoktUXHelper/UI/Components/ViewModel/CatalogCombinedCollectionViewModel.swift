import Foundation
import Combine
import DcuiSchema

@available(iOS 15, *)
final class CatalogCombinedCollectionViewModel: Identifiable, Hashable, ScreenSizeAdaptive, ObservableObject {
    typealias Item = CatalogCombinedCollectionStyles

    let id: UUID = UUID()
    @Published var children: [LayoutSchemaViewModel]?
    let defaultStyle: [CatalogCombinedCollectionStyles]?
    weak var layoutState: (any LayoutStateRepresenting)?
    weak var eventService: EventServicing?
    private let childBuilder: ((CatalogItem) -> [LayoutSchemaViewModel]?)?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(
        children: [LayoutSchemaViewModel]?,
        defaultStyle: [CatalogCombinedCollectionStyles]?,
        layoutState: any LayoutStateRepresenting,
        eventService: EventServicing? = nil,
        childBuilder: ((CatalogItem) -> [LayoutSchemaViewModel]?)? = nil
    ) {
        self.children = children
        self.defaultStyle = defaultStyle
        self.layoutState = layoutState
        self.eventService = eventService
        self.childBuilder = childBuilder
    }

    @discardableResult
    func rebuildChildren(for catalogItem: CatalogItem) -> Bool {
        guard let newChildren = childBuilder?(catalogItem) else { return false }

        newChildren.forEach { child in
            AttributedStringTransformer.convertRichTextHTMLIfExists(
                uiModel: child,
                config: layoutState?.config
            )
        }

        children = newChildren

        eventService?.sendSlotImpressionEvent(
            instanceGuid: catalogItem.instanceGuid,
            jwtToken: catalogItem.token
        )

        return true
    }

    static func == (lhs: CatalogCombinedCollectionViewModel, rhs: CatalogCombinedCollectionViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
