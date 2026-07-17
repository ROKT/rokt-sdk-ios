import XCTest
internal import RoktUXHelper
@testable import Rokt_Widget

/// End-to-end proof that the adapter's output is renderable: a selection response
/// carrying real DCUI schema strings, run through the adapter, parses into a
/// non-nil RoktUX page model — i.e. the renderer's decode contract (including the
/// pre-serialized layout schemas) is satisfied.
final class TestOffersRenderCompat: XCTestCase {

    func test_adaptedExperienceParsesIntoRenderablePageModel() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "offers_render", withExtension: "json"),
            "offers_render.json missing from the test bundle"
        )
        let response = try JSONDecoder().decode(SelectResponse.self, from: Data(contentsOf: url))

        let experienceString = try SelectExperienceAdapter.experienceJSONString(from: response)

        let parsed = try XCTUnwrap(
            RoktUX.parseExperience(experienceString),
            "adapter output did not decode as a renderer experience"
        )
        XCTAssertEqual(parsed.sessionId, "render-session")
        XCTAssertNotNil(parsed.pageModel, "adapter output produced no renderable page model")
    }

    /// Guards BUG-011: a shoppable offer's `catalog_items` must survive the adapter
    /// (with the renderer's camelCase keys) and satisfy the renderer's `CatalogItem`
    /// decode contract. Before the `RenderCatalogItem` mapping the items were dropped,
    /// so the catalog components rendered nothing and the overlay was blank.
    func test_shoppableOfferCatalogItemsSurviveAdapterAndParse() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "offers_render_shoppable", withExtension: "json"),
            "offers_render_shoppable.json missing from the test bundle"
        )
        let response = try JSONDecoder().decode(SelectResponse.self, from: Data(contentsOf: url))

        let experienceString = try SelectExperienceAdapter.experienceJSONString(from: response)

        // 1. The adapter forwards catalog_items under the renderer's camelCase keys.
        let probe = try JSONDecoder().decode(CatalogProbe.self, from: Data(experienceString.utf8))
        let items = try XCTUnwrap(
            probe.plugins?.first?.plugin.config.slots.first?.offer?.catalogItems,
            "catalog items were dropped by the adapter"
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.catalogItemId, "cat-jm-1")
        XCTAssertEqual(items.first?.cartItemId, "cart-1")
        XCTAssertEqual(items.first?.title, "Jason Markk Quick Clean Kit")
        XCTAssertEqual(items.first?.priceFormatted, "$18")
        XCTAssertNotNil(items.first?.images["hero"], "catalog item image was not carried through")

        // 2. The renderer's decode contract accepts it — a missing required CatalogItem
        //    field would throw in OfferModel decode and yield a nil page model.
        let parsed = try XCTUnwrap(
            RoktUX.parseExperience(experienceString),
            "adapter output did not decode as a renderer experience"
        )
        XCTAssertNotNil(parsed.pageModel, "shoppable adapter output produced no renderable page model")
    }
}

/// Decodes only the path to the catalog items in the adapter's experience JSON,
/// asserting the camelCase keys the renderer expects (`RoktDecoder` uses a plain
/// `JSONDecoder` with no key-decoding strategy, so keys must match verbatim).
private struct CatalogProbe: Decodable {
    let plugins: [PluginBox]?
    struct PluginBox: Decodable { let plugin: Plugin }
    struct Plugin: Decodable { let config: Config }
    struct Config: Decodable { let slots: [Slot] }
    struct Slot: Decodable { let offer: Offer? }
    struct Offer: Decodable { let catalogItems: [Item]? }
    struct Item: Decodable {
        let catalogItemId: String
        let cartItemId: String
        let title: String
        let priceFormatted: String?
        let images: [String: Image]
    }
    struct Image: Decodable { let light: String?; let dark: String? }
}
