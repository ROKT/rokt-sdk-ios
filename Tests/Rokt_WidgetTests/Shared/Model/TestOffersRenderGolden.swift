import XCTest
@testable import Rokt_Widget

/// Guard for the offers render adapter output. The `.expected.json` goldens were
/// captured from the previous per-type `Render*` model tree; the single-pass
/// ``RenderExperience`` encoder must reproduce them exactly. Comparison is on the
/// parsed JSON (deep `NSDictionary` equality), so it is agnostic to key ordering
/// and whitespace but still catches any changed key, value, nesting, or a
/// spurious `null` from an `encode`/`encodeIfPresent` slip. Regenerate the goldens
/// only when the render contract intentionally changes.
final class TestOffersRenderGolden: XCTestCase {

    func test_offersRenderMatchesGolden() throws {
        try assertMatchesGolden(fixture: "offers_render")
    }

    func test_shoppableRenderMatchesGolden() throws {
        try assertMatchesGolden(fixture: "offers_render_shoppable")
    }

    private func assertMatchesGolden(fixture: String) throws {
        let wireURL = try XCTUnwrap(
            Bundle.module.url(forResource: fixture, withExtension: "json"),
            "\(fixture).json missing from the test bundle"
        )
        let expectedURL = try XCTUnwrap(
            Bundle.module.url(forResource: "\(fixture).expected", withExtension: "json"),
            "\(fixture).expected.json missing from the test bundle"
        )
        let response = try JSONDecoder().decode(SelectResponse.self, from: Data(contentsOf: wireURL))
        let actualString = try SelectExperienceAdapter.experienceJSONString(from: response)

        let actual = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(actualString.utf8)) as? NSDictionary
        )
        let expected = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: expectedURL)) as? NSDictionary
        )
        XCTAssertEqual(actual, expected, "render JSON diverged from the golden for \(fixture)")
    }
}
