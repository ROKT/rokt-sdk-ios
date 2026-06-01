import XCTest
@testable import RoktUXHelper

@available(iOS 13, *)
final class PlaceholderPredicateResolverTests: XCTestCase {
    var sut: PlaceholderPredicateResolver!

    override func setUp() {
        super.setUp()
        sut = PlaceholderPredicateResolver()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_resolveDecimal_catalogItemPrice() {
        let catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        let context = PlaceholderResolutionContext(offers: [],
                                                   currentOfferIndex: 0,
                                                   activeCatalogItem: catalogItem)

        let resolved = sut.resolveDecimal(placeholder: "%^DATA.catalogItem.price^%", context: context)

        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved, Decimal(14.99))
    }

    func test_resolveString_catalogItemPrice() {
        let catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        let context = PlaceholderResolutionContext(offers: [],
                                                   currentOfferIndex: 0,
                                                   activeCatalogItem: catalogItem)

        let resolved = sut.resolveString(placeholder: "%^DATA.catalogItem.price^%", context: context)

        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved, "14.99")
    }
}
