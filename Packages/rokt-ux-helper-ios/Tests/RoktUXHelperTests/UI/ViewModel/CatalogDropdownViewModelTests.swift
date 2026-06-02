import XCTest
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15, *)
final class CatalogDropdownViewModelTests: XCTestCase {

    func test_isOptionDisabled_outOfStockItem() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState)

        // Option 0 ("Red") maps to "item1" which is InStock
        XCTAssertFalse(viewModel.isOptionDisabled(at: 0))
        // Option 1 ("Blue") maps to "item2" which is OutOfStock
        XCTAssertTrue(viewModel.isOptionDisabled(at: 1))
    }

    func test_isOptionDisabled_outOfBoundsReturnsFalse() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState)

        XCTAssertFalse(viewModel.isOptionDisabled(at: 99))
    }

    func test_selectItem_updatesPersistedIndex() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState)

        XCTAssertNil(viewModel.persistedSelectedIndex)

        viewModel.selectItem(at: 0)

        XCTAssertEqual(viewModel.persistedSelectedIndex, 0)
    }

    func test_selectItem_disabledOptionIsIgnored() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState)

        // Option 1 is out of stock
        viewModel.selectItem(at: 1)

        XCTAssertNil(viewModel.persistedSelectedIndex)
    }

    func test_displayText_showsPlaceholderWhenNothingSelected() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState, placeholderValue: "Please select")

        XCTAssertEqual(viewModel.displayText(for: nil), "Please select")
    }

    func test_displayText_showsOptionLabel() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState)

        XCTAssertEqual(viewModel.displayText(for: 0), "Red")
    }

    func test_options_returnsAttributeOptions() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        let viewModel = makeViewModel(layoutState: layoutState)

        XCTAssertEqual(viewModel.options.count, 2)
        XCTAssertEqual(viewModel.options[0].label, "Red")
        XCTAssertEqual(viewModel.options[1].label, "Blue")
    }

    func test_options_returnsEmptyWhenCatalogItemGroupIsNil() {
        let layoutState = LayoutState()
        let offer = OfferModel(
            campaignId: "",
            creative: .init(
                referralCreativeId: "",
                instanceGuid: "",
                copy: [:],
                images: nil,
                links: [:],
                responseOptionsMap: nil,
                jwtToken: ""
            ),
            catalogItems: [CatalogItem.mock(catalogItemId: "item1", inventoryStatus: "InStock")],
            catalogItemGroup: nil,
            transactionData: nil
        )
        layoutState.items[LayoutState.fullOfferKey] = offer

        let viewModel = makeViewModel(layoutState: layoutState)

        XCTAssertTrue(viewModel.options.isEmpty)
        XCTAssertNil(viewModel.attribute)
    }

    func test_options_returnsEmptyWhenAttributeIndexOutOfRange() {
        let (layoutState, _) = makeLayoutStateWithGroup()
        // Group has a single attribute at index 0 — requesting index 1 is out of range.
        let viewModel = makeViewModel(layoutState: layoutState, attributeIndex: 1)

        XCTAssertTrue(viewModel.options.isEmpty)
        XCTAssertNil(viewModel.attribute)
    }

    // MARK: - Helpers

    private func makeLayoutStateWithGroup() -> (LayoutState, [CatalogItem]) {
        let layoutState = LayoutState()
        let item1 = CatalogItem.mock(catalogItemId: "item1", inventoryStatus: "InStock")
        let item2 = CatalogItem.mock(catalogItemId: "item2", inventoryStatus: "OutOfStock")

        let group = CatalogItemGroup(
            groupId: "group1",
            catalogItemIds: ["item1", "item2"],
            attributes: [
                CatalogItemGroupAttribute(
                    attributeId: "color",
                    label: "Color",
                    options: [
                        CatalogItemGroupOption(label: "Red", catalogItemIds: ["item1"], metadata: nil),
                        CatalogItemGroupOption(label: "Blue", catalogItemIds: ["item2"], metadata: nil)
                    ],
                    metadata: nil
                )
            ],
            metadata: nil
        )

        let offer = OfferModel(
            campaignId: "",
            creative: .init(
                referralCreativeId: "",
                instanceGuid: "",
                copy: [:],
                images: nil,
                links: [:],
                responseOptionsMap: nil,
                jwtToken: ""
            ),
            catalogItems: [item1, item2],
            catalogItemGroup: group,
            transactionData: nil
        )
        layoutState.items[LayoutState.fullOfferKey] = offer

        return (layoutState, [item1, item2])
    }

    private func makeViewModel(
        layoutState: LayoutState,
        placeholderValue: String? = nil,
        attributeIndex: Int = 0,
        eventService: EventServicing? = nil
    ) -> CatalogDropdownViewModel {
        CatalogDropdownViewModel(
            ownStyles: nil,
            headStyles: nil,
            iconStyles: nil,
            optionListStyles: nil,
            optionStyles: nil,
            errorStyles: nil,
            placeholderValue: placeholderValue,
            unavailableValue: nil,
            validatorFieldConfig: nil,
            a11yLabel: nil,
            attributeIndex: attributeIndex,
            layoutState: layoutState,
            eventService: eventService
        )
    }
}
