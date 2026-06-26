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
}
