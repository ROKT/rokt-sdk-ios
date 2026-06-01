import XCTest
@testable import RoktUXHelper

@available(iOS 13, *)
final class CatalogDataExtractorTests: XCTestCase {
    var catalogItem: CatalogItem!
    var sut: CatalogDataExtractor? = CatalogDataExtractor()

    override func setUp() {
        super.setUp()

        catalogItem = ModelTestData.CatalogPageModelData.withBNF().layoutPlugins?.first!.slots[0].offer!.catalogItems?.first
        sut = CatalogDataExtractor()
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    func test_extractDataRepresentedBy_usingValidCreativeCopyPropertyChain_returnsNestedString() {
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.title",
                responseKey: nil,
                from: catalogItem
            ),
            .value("Catalog Title")
        )
    }

    func test_extractDataRepresentedBy_usingValidCreativeResponsePropertyChain_returnsNestedString() {
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.description",
                responseKey: nil,
                from: catalogItem
            ),
            .value("Catalog Description")
        )
    }

    func test_extractDataRepresentedBy_usingInvalidPropertyChain_returnsNestedString() {
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalog.missingTestId",
                responseKey: nil,
                from: catalogItem
            ),
            .value("DATA.catalog.missingTestId")
        )
    }

    func test_extractDataRepresentedBy_usingValidCreativeLinkPropertyChain_returnsNestedString() {
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.originalPriceFormatted",
                responseKey: nil,
                from: catalogItem
            ),
            .value("$14.99")
        )
    }

    func test_extractDataRepresentedBy_usingNestedCatalogCopy_returnsNestedString() {
        let catalogItem = makeCatalogItem(copy: ["product.subtitle": "Extra battery"])

        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.copy.product.subtitle",
                responseKey: nil,
                from: catalogItem
            ),
            .value("Extra battery")
        )
    }

    func test_extractDataRepresentedBy_usingDecimalCatalogValue_canCoerceToDecimalDoubleAndString() throws {
        let catalogItem = makeCatalogItem(price: Decimal(string: "14.99"))

        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                Decimal.self,
                propertyChain: "DATA.catalogItem.price",
                responseKey: nil,
                from: catalogItem
            ),
            .value(Decimal(string: "14.99")!)
        )
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                Double.self,
                propertyChain: "DATA.catalogItem.price",
                responseKey: nil,
                from: catalogItem
            ),
            .value(14.99)
        )
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.price",
                responseKey: nil,
                from: catalogItem
            ),
            .value("14.99")
        )
    }

    func test_extractDataRepresentedBy_usingCatalogCopyKey_returnsCopyValue() {
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.copy.provider.variationTitle",
                responseKey: nil,
                from: catalogItem
            ),
            .value("Burnt Clay")
        )

        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.copy.provider.discountLabel",
                responseKey: nil,
                from: catalogItem
            ),
            .value("Save 20%")
        )

        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.copy.provider.pricing.shippingFees",
                responseKey: nil,
                from: catalogItem
            ),
            .value("4.90")
        )
    }

    func test_extractDataRepresentedBy_usingIntCatalogValue_canCoerceToIntAndString() throws {
        let catalogItem = makeCatalogItem(minItemCount: 2)

        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                Int.self,
                propertyChain: "DATA.catalogItem.minItemCount",
                responseKey: nil,
                from: catalogItem
            ),
            .value(2)
        )
        XCTAssertEqual(
            try sut?.extractDataRepresentedBy(
                String.self,
                propertyChain: "DATA.catalogItem.minItemCount",
                responseKey: nil,
                from: catalogItem
            ),
            .value("2")
        )
    }

    private func makeCatalogItem(
        copy: [String: String]? = nil,
        price: Decimal? = 14.99,
        minItemCount: Int? = nil
    ) -> CatalogItem {
        .init(
            images: [:],
            catalogItemId: "catalog-item-id",
            cartItemId: "cart-item-id",
            instanceGuid: "instance-guid",
            title: "Catalog Title",
            description: "Catalog Description",
            price: price,
            priceFormatted: nil,
            originalPrice: 19.99,
            originalPriceFormatted: "$19.99",
            currency: "USD",
            signalType: nil,
            url: nil,
            minItemCount: minItemCount,
            maxItemCount: nil,
            preSelectedQuantity: nil,
            providerData: "{}",
            urlBehavior: nil,
            positiveResponseText: "Add to cart",
            negativeResponseText: "No thanks",
            addOns: nil,
            copy: copy,
            inventoryStatus: nil,
            linkedProductId: nil,
            token: "catalog-token"
        )
    }
}
