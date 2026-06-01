import XCTest
@testable import RoktUXHelper
import DcuiSchema

final class CatalogMapperTests: XCTestCase {

    var sut: CatalogMapper? = CatalogMapper()
    var bnfColumn: ColumnModel<LayoutSchemaModel, WhenPredicate>?
    var catalogItem: CatalogItem?

    override func setUp() {
        super.setUp()

        sut = CatalogMapper()

        let bnfPageModel = ModelTestData.CatalogPageModelData.withBNF()
        let firstSlot = bnfPageModel.layoutPlugins?.first?.slots[0]
        let bnfChildren = firstSlot?.layoutVariant?.layoutVariantSchema
        catalogItem = firstSlot?.offer?.catalogItems?.first

        if case .column(let myColumn) = bnfChildren {
            bnfColumn = myColumn
        }
    }

    override func tearDown() {
        catalogItem = nil
        bnfColumn = nil
        sut = nil

        super.tearDown()
    }

    // MARK: - BasicText

    func test_basicText_parsesSingleValue() {
        // %^DATA.catalogItem.title^%
        assertBasicTextDataExpansion(
            childIndex: 0,
            expectedValue: "Catalog Title"
        )
    }

    func test_basicText_invalidFirstValueValidSecondValue_parsesSecondValue() {
        // %^DATA.catalogItem.nonexistent | DATA.catalogItem.title^%
        assertBasicTextDataExpansion(
            childIndex: 11,
            expectedValue: "Catalog Title"
        )
    }

    func test_basicText_invalidFirstValueWithDefaultValue_parsesSecondValue() {
        // %^DATA.catalogItem.nonexistent | my default^%
        assertBasicTextDataExpansion(
            childIndex: 12,
            expectedValue: "my default"
        )
    }

    func test_basicText_chainOfValues_parsesAllValues() {
        // %^DATA.catalogItem.title^% this is my sentence %^DATA.catalogItem.title^%
        assertBasicTextDataExpansion(
            childIndex: 13,
            expectedValue: "Catalog Title this is my sentence Catalog Title"
        )
    }

    // MARK: - RichText

    func test_richText_chainOfValues_parsesAllValues() {
        // %^DATA.catalogItem.title^%%^DATA.catalogItem.description^%%^DATA.catalogItem.priceFormatted^%%^DATA.catalogItem.positiveResponseText^%
        assertRichTextDataExpansion(
            childIndex: 1,
            expectedValue: "Catalog TitleCatalog Description$14.99Add to order"
        )
    }

    func test_richText_withHTMLTags_performsDataExpansionAndRetainsTags() {
        // <b>%^DATA.catalogItem.title^%</b>
        assertRichTextDataExpansion(
            childIndex: 2,
            expectedValue: "<b>Catalog Title</b>"
        )

        // <u>%^DATA.catalogItem.title^%</u>
        assertRichTextDataExpansion(
            childIndex: 3,
            expectedValue: "<u>Catalog Title</u>"
        )
    }

    func test_richText_firstValueDoesNotExist_secondValueExists_shouldReturnSecondValue() {
        // %^DATA.catalogItem.nonexistent | DATA.catalogItem.title^%
        assertRichTextDataExpansion(
            childIndex: 4,
            expectedValue: "Catalog Title"
        )
    }

    func test_richText_sentenceWithMultipleValidDataExpansion_parsesAll() {
        // This is my sentence with %^DATA.catalogItem.title^% and %^DATA.catalogItem.description^%
        assertRichTextDataExpansion(
            childIndex: 5,
            expectedValue: "This is my sentence with Catalog Title and Catalog Description"
        )
    }

    func test_richText_multipleValidDataExpansion_returnsFirsMatch() {
        // %^DATA.catalogItem.title | DATA.catalogItem.description^%
        assertRichTextDataExpansion(
            childIndex: 9,
            expectedValue: "Catalog Title"
        )
    }

    func test_richText_multipleInvalidDataExpansionWithDefault_returnsDefault() {
        // No data expansion
        assertRichTextDataExpansion(
            childIndex: 14,
            expectedValue: "my default value after 2 invalids"
        )
    }

    func test_richText_withNoDataExpansion_returnsNormalText() {
        // No data expansion
        assertRichTextDataExpansion(
            childIndex: 6,
            expectedValue: "No data expansion"
        )
    }

    func test_richText_withNonExistentDataExpansionAndDefaultValue_usesDefaultValue() {
        // %^DATA.catalogItem.nonexistent | my default value^%
        assertRichTextDataExpansion(
            childIndex: 7,
            expectedValue: "my default value"
        )
    }

    func test_richText_withValidDataExpansionAndDefaultValue_usesDataExpansion() {
        // %^DATA.catalogItem.title | my default value^%
        assertRichTextDataExpansion(
            childIndex: 8,
            expectedValue: "Catalog Title"
        )
    }

    func test_richText_withInvalidChainAndEmptyPipe_usesEmptyString() {
        // %^DATA.catalogItem.nonexistent |^%
        assertRichTextDataExpansion(
            childIndex: 16,
            expectedValue: ""
        )
    }

    func test_richText_withValidChainAndEmptyPipe_usesDataExpansion() {
        // %^DATA.catalogItem.title |^%
        assertRichTextDataExpansion(
            childIndex: 17,
            expectedValue: "Catalog Title"
        )
    }

    func test_richText_withMultipleInvalidChainAndEmptyPipe_usesEmptyString() {
        // %^DATA.catalogItem.nonexistent | DATA.catalogItem.nonexistentv2 |^%
        assertRichTextDataExpansion(
            childIndex: 18,
            expectedValue: ""
        )
    }

    func test_richText_withSecondValidChainAndEmptyPipe_usesDataExpansion() {
        // %^DATA.catalogItem.nonexistent | DATA.catalogItem.title |^%
        assertRichTextDataExpansion(
            childIndex: 19,
            expectedValue: "Catalog Title"
        )
    }

    func test_richText_withInvalidChainAndEmptyPipeInSentence_usesEmptyString() {
        // %^DATA.catalogItem.nonexistent |^% is my sentence
        assertRichTextDataExpansion(
            childIndex: 20,
            expectedValue: " is my sentence"
        )
    }

    // sad path
    func test_richText_withInvalidDataExpansion_returnsEmptyString() {
        // %^DATA.catalogItem.nonexistent^%
        assertRichTextDataExpansion(
            childIndex: 10,
            expectedValue: ""
        )
    }

    // sentence with an invalid mandatory and a valid optional copy should still return empty
    func test_richText_sentenceWithInvalidMandatorycatalogItem_returnsEmptyString() {
        // Sentence with %^DATA.catalogItem.nonexistent^% and %^DATA.catalogItem.title|^%
        assertRichTextDataExpansion(
            childIndex: 21,
            expectedValue: ""
        )
    }

    // CatalogMapper now skips foreign-namespace placeholders so subsequent mappers (or
    // reactive resolution) can handle them; previously it threw and zeroed the whole text.
    func test_richText_creativeLinkPlaceholders_passThroughUnchanged() {
        // %^DATA.creativeLink.nonexistent^% and %^DATA.creativeLink.privacyPolicy|^%
        assertRichTextDataExpansion(
            childIndex: 22,
            expectedValue: "%^DATA.creativeLink.nonexistent^% and %^DATA.creativeLink.privacyPolicy|^%"
        )
    }

    private func assertRichTextDataExpansion(childIndex: Int, expectedValue: String) {
        guard let catalogItem else {
            XCTFail("No data source offer")
            return
        }

        guard case .richText(let textModel) = bnfColumn?.children[childIndex] else {
            XCTFail("RichText does not exist")
            return
        }

        let uiModel = textModel.asViewModel

        sut?.map(consumer: .richText(uiModel), context: catalogItem)
        XCTAssertEqual(uiModel.boundValue, expectedValue)
    }

    private func assertBasicTextDataExpansion(childIndex: Int, expectedValue: String) {
        guard let catalogItem else {
            XCTFail("No data source offer")
            return
        }

        guard case .basicText(let textModel) = bnfColumn?.children[childIndex] else {
            XCTFail("BasicText does not exist")
            return
        }

        let uiModel = textModel.asViewModel

        sut?.map(consumer: .basicText(uiModel), context: catalogItem)
        XCTAssertEqual(uiModel.boundValue, expectedValue)
    }

}

fileprivate extension RichTextModel {
    var asViewModel: RichTextViewModel {
        RichTextViewModel(
            value: self.value,
            defaultStyle: nil,
            linkStyle: nil,
            openLinks: nil,
            stateDataExpansionClosure: nil,
            layoutState: LayoutState(),
            eventService: nil
        )
    }
}

fileprivate extension BasicTextModel {
    var asViewModel: BasicTextViewModel {
        BasicTextViewModel(
            value: self.value,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            layoutState: LayoutState(),
            diagnosticService: nil
        )
    }
}
