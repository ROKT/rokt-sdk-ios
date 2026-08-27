import XCTest
@testable import Rokt_Widget

final class TestProductCarouselFixture: XCTestCase {
    func test_selectionPreservesOfferOrderAndCatalogIdentity() throws {
        let response = try JSONDecoder().decode(SelectResponse.self, from: ProductCarouselFixture.data())
        let config = try XCTUnwrap(response.plugins?.first?.plugin?.config)
        XCTAssertEqual(config.slots.map(\.instanceGuid), ["slot:example/before", "slot:example/products", "slot:example/after"])
        XCTAssertEqual(config.slots.map { $0.offer?.catalogItems?.count }, [0, 4, 0])
        XCTAssertTrue(try XCTUnwrap(config.outerLayoutSchema).contains("OneByOneDistribution"))
        let productSlot = try XCTUnwrap(config.slots.dropFirst().first)
        let schema = try XCTUnwrap(productSlot.layoutVariant?.layoutVariantSchema)
        XCTAssertTrue(schema.contains("CatalogCarouselCollection"))
        XCTAssertTrue(schema.contains("InlineContainer"))
        XCTAssertEqual(productSlot.offer?.creative?.images?["creativeImage.brandIcon"]?.light,
                       "https://example.com/images/products-brand.png")
        XCTAssertEqual(productSlot.offer?.creative?.images?["creativeImage.brandIcon"]?.dark,
                       "https://example.com/images/products-brand-dark.png")
        let items = try XCTUnwrap(productSlot.offer?.catalogItems)
        for (index, item) in items.enumerated() {
            let letter = ["a", "b", "c", "d"][index]
            XCTAssertEqual(item.catalogItemId, "item:example/product-\(letter)")
            XCTAssertEqual(item.instanceGuid, "catalog:example/product-\(letter)")
            XCTAssertEqual(item.token, "synthetic-item-token-\(letter)")
            XCTAssertEqual(item.images?["catalogItemImage0"]?.light, "https://example.com/images/product-\(letter)-light.png")
            XCTAssertEqual(response.eventData?["catalog:example/product-\(letter)"]?.token, item.token)
        }
        for (index, slot) in config.slots.enumerated() {
            let name = ["before", "products", "after"][index]
            let options = try XCTUnwrap(slot.offer?.creative?.responseOptionsMap)
            XCTAssertEqual(options["a-accept"]?.id, "synthetic-response-\(name)-accept")
            XCTAssertEqual(options["z-decline"]?.token, "synthetic-response-token-\(name)-decline")
            XCTAssertEqual(options["a-accept"]?.isPositive, true)
            XCTAssertEqual(options["z-decline"]?.isPositive, false)
        }
    }

    func test_rawSelectionRetainsBothAttributeSelectorsAndItemResponses() throws {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProductCarouselFixture.data()) as? [String: Any])
        let plugins = try XCTUnwrap(root["plugins"] as? [[String: Any]])
        let plugin = try XCTUnwrap(plugins.first?["plugin"] as? [String: Any])
        let config = try XCTUnwrap(plugin["config"] as? [String: Any])
        let slots = try XCTUnwrap(config["slots"] as? [[String: Any]])
        let offer = try XCTUnwrap(slots.dropFirst().first?["offer"] as? [String: Any])
        let items = try XCTUnwrap(offer["catalog_items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 4)
        for (index, item) in items.enumerated() {
            let letter = ["a", "b", "c", "d"][index]
            XCTAssertEqual(item["product_cart_attribute1"] as? String, index.isMultiple(of: 2) ? "title" : "price")
            XCTAssertEqual(item["product_cart_attribute2"] as? String, index.isMultiple(of: 2) ? "price" : "title")
            let options = try XCTUnwrap(item["response_options_map"] as? [String: [String: Any]])
            XCTAssertEqual(Set(options.keys), Set(["positive", "details"]))
            for key in ["positive", "details"] {
                let option = try XCTUnwrap(options[key])
                XCTAssertEqual(option["id"] as? String, "synthetic-response-product-\(letter)-\(key)")
                XCTAssertEqual(option["instance_guid"] as? String, "response:example/product-\(letter)/\(key)")
                XCTAssertEqual(option["token"] as? String, "synthetic-response-token-product-\(letter)-\(key)")
                XCTAssertEqual(option["url"] as? String, "https://example.com/product-\(letter)?source=\(key)&value=%2F")
                XCTAssertEqual(option["signal_type"] as? String, "SignalProductItemResponse")
            }
        }
    }
}
