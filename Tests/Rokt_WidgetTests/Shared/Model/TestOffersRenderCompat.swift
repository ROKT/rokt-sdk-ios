import XCTest
internal import RoktUXHelper
@testable import Rokt_Widget

/// End-to-end proof that the raw snake_case offers selection response is renderable:
/// the response the offers service now forwards unchanged (no camelCase adapter) —
/// carrying real DCUI schema strings — parses into a non-nil RoktUX page model, i.e.
/// the renderer's `SelectResponse` decode contract (including the pre-serialized
/// layout schemas) is satisfied.
final class TestOffersRenderCompat: XCTestCase {

    func test_rawSelectionResponseParsesIntoRenderablePageModel() throws {
        let experienceString = try rawFixture("offers_render")

        let parsed = try XCTUnwrap(
            RoktUX.parseExperience(experienceString),
            "raw selection response did not decode as a renderer experience"
        )
        XCTAssertEqual(parsed.sessionId, "render-session")
        XCTAssertNotNil(parsed.pageModel, "raw selection response produced no renderable page model")
    }

    /// Guards BUG-011: a shoppable offer's `catalog_items` must satisfy the renderer's
    /// `CatalogItem` decode contract. A missing required field would throw in the
    /// offer decode and yield a nil page model, so the overlay would render blank.
    func test_shoppableOfferParsesIntoRenderablePageModel() throws {
        let experienceString = try rawFixture("offers_render_shoppable")

        let parsed = try XCTUnwrap(
            RoktUX.parseExperience(experienceString),
            "raw shoppable selection response did not decode as a renderer experience"
        )
        XCTAssertNotNil(parsed.pageModel, "raw shoppable selection response produced no renderable page model")
    }

    // MARK: - helpers

    private func rawFixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json"),
            "\(name).json missing from the test bundle"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }
}
