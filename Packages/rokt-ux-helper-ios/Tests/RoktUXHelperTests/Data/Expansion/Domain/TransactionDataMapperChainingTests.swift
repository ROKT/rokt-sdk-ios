import XCTest
@testable import RoktUXHelper

final class TransactionDataMapperChainingTests: XCTestCase {

    // Regression: when a prior mapper (catalog/creative) resolves a placeholder to "",
    // the chained transaction mapper must treat that as a real prior mapping result —
    // not as "no mapping yet" — so the empty resolution is preserved instead of
    // reintroducing raw placeholders for the orphan-finalize pass to zero the line.

    func test_basicText_currentTemplateText_returnsRawValueBeforeAnyMapperRuns() {
        let raw = "%^DATA.catalogItem.title^%"
        let model = BasicTextViewModel(
            value: raw,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            layoutState: nil,
            diagnosticService: nil
        )

        XCTAssertEqual(model.currentTemplateText, raw)
    }

    func test_basicText_currentTemplateText_preservesEmptyMapperResolution() {
        let model = BasicTextViewModel(
            value: "%^DATA.catalogItem.title^%",
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            layoutState: nil,
            diagnosticService: nil
        )

        // Simulate a prior mapper resolving the placeholder to an empty string
        // (e.g. catalog data legitimately has an empty title field).
        model.updateDataBinding(dataBinding: .value(""))

        XCTAssertEqual(model.currentTemplateText, "",
                       "Empty post-mapper output must be preserved, not reverted to the raw template")
    }

    func test_richText_currentTemplateText_returnsRawValueBeforeAnyMapperRuns() {
        let raw = "%^DATA.catalogItem.title^%"
        let model = RichTextViewModel(
            value: raw,
            defaultStyle: nil,
            linkStyle: nil,
            openLinks: nil,
            layoutState: nil,
            eventService: nil
        )

        XCTAssertEqual(model.currentTemplateText, raw)
    }

    func test_richText_currentTemplateText_preservesEmptyMapperResolution() {
        let model = RichTextViewModel(
            value: "%^DATA.catalogItem.title^%",
            defaultStyle: nil,
            linkStyle: nil,
            openLinks: nil,
            layoutState: nil,
            eventService: nil
        )

        model.updateDataBinding(dataBinding: .value(""))

        XCTAssertEqual(model.currentTemplateText, "",
                       "Empty post-mapper output must be preserved, not reverted to the raw template")
    }
}
