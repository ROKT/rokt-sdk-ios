import Foundation

enum BNFNamespace: String, CaseIterable {

    // MARK: Creative

    case dataCreativeCopy = "DATA.creativeCopy"
    case dataCreativeResponse = "DATA.creativeResponse"
    case dataCreativeLink = "DATA.creativeLink"
    case dataImageCarousel = "DATA.creativeImage"

    // MARK: Transaction Data

    // Surfaces `OfferModel.transactionData` to layouts via placeholders such as
    // `%^DATA.transactionData.shippingAddress.address1^%`.
    case dataTransactionData = "DATA.transactionData"

    // MARK: Catalog Runtime (host-pushed dynamic values)

    // Generic bucket for values the host SDK pushes into the layout AFTER the initial
    // transform — order breakdowns, recalculated totals, server-rendered cart copy, etc.
    // Pairs with the frozen `DATA.catalogItem` namespace: `catalogItem` is the static
    // catalog data decoded from the experience response, `catalogRuntime` is its
    // dynamic counterpart updated reactively after API round-trips.
    // Resolved reactively by `BasicTextViewModel` / `RichTextViewModel` against
    // `LayoutState.catalogRuntimeDataKey`.
    case dataCatalogRuntime = "DATA.catalogRuntime"

    case state = "STATE"

    var withNamespaceSeparator: String { self.rawValue + BNFSeparator.namespace.rawValue }

    enum CreativeResponseKey: String {
        case positive
        case negative
    }

    // MARK: Catalog Item

    case dataCatalogItem = "DATA.catalogItem"
}
