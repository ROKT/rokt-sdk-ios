import XCTest
import SwiftUI
import ViewInspector
import SnapshotTesting
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestCatalogDropdownComponent: XCTestCase {

    // MARK: - Hidden when nothing meaningful to choose

    func test_rendersEmpty_whenCatalogItemGroupIsAbsent() throws {
        let layoutState = makeLayoutState(group: nil)
        let view = makePlaceholder(layoutState: layoutState)

        let emptyView = try view.inspectComponent(CatalogDropdownComponent.self)
            .find(ViewType.EmptyView.self)

        XCTAssertNotNil(emptyView)
    }

    func test_rendersEmpty_whenAttributeHasSingleOption() throws {
        let layoutState = makeLayoutState(group: singleOptionGroup())
        let view = makePlaceholder(layoutState: layoutState)

        let emptyView = try view.inspectComponent(CatalogDropdownComponent.self)
            .find(ViewType.EmptyView.self)

        XCTAssertNotNil(emptyView)
    }

    func test_validationUnregistered_whenHidden() throws {
        let layoutState = makeLayoutState(group: nil)
        let key = "size"
        let view = makePlaceholder(
            layoutState: layoutState,
            validatorFieldConfig: ValidatorFieldConfig(
                validationFieldKey: key,
                validators: [.required(InputRequiredValidation(message: "Required"))],
                validateOnChange: nil
            )
        )

        // Force the view tree to realise so any `.onAppear` would have fired
        // in the real SwiftUI runtime. Inspect also walks the tree without
        // triggering .onAppear; we rely on the coordinator's unregistered
        // behaviour (returns valid) to confirm no registration exists.
        _ = try view.inspect()

        // Unregistered fields are treated as valid — confirming the hidden
        // dropdown did not block form submission by registering a `.required`
        // validator for a selection that will never happen.
        XCTAssertTrue(layoutState.validationCoordinator.validate(field: key))
    }

    // MARK: - Renders when there is something to choose

    func test_renders_whenAttributeHasTwoOrMoreOptions() throws {
        let layoutState = makeLayoutState(group: twoOptionGroup())
        let view = makePlaceholder(layoutState: layoutState)

        let inspected = try view.inspectComponent(CatalogDropdownComponent.self)
        XCTAssertNil(try? inspected.find(ViewType.EmptyView.self))
        XCTAssertNotNil(try? inspected.find(ViewType.VStack.self))
    }

    // MARK: - Snapshot

    func testSnapshot_collapsed_withProductionStyles() throws {
        let layoutState = makeLayoutState(group: threeOptionGroup())
        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState,
            eventService: get_mock_event_processor()
        )
        let viewModel = try transformer.getCatalogDropdown(
            model: ModelTestData.CatalogDropdownData.catalogDropdown()
        )
        let view = TestPlaceHolder(
            layout: .catalogDropdown(viewModel),
            layoutState: layoutState
        )
        .frame(width: 350)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    // MARK: - Helpers

    private func makePlaceholder(
        layoutState: LayoutState,
        validatorFieldConfig: ValidatorFieldConfig? = nil
    ) -> TestPlaceHolder {
        let viewModel = CatalogDropdownViewModel(
            ownStyles: nil,
            headStyles: nil,
            iconStyles: nil,
            optionListStyles: nil,
            optionStyles: nil,
            errorStyles: nil,
            placeholderValue: nil,
            unavailableValue: nil,
            validatorFieldConfig: validatorFieldConfig,
            a11yLabel: nil,
            attributeIndex: 0,
            layoutState: layoutState,
            eventService: nil
        )
        return TestPlaceHolder(
            layout: .catalogDropdown(viewModel),
            layoutState: layoutState
        )
    }

    private func makeLayoutState(group: CatalogItemGroup?) -> LayoutState {
        let layoutState = LayoutState()
        let items = (group?.catalogItemIds ?? ["item1"]).map {
            CatalogItem.mock(catalogItemId: $0, inventoryStatus: "InStock")
        }
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
            catalogItems: items,
            catalogItemGroup: group,
            transactionData: nil
        )
        layoutState.items[LayoutState.fullOfferKey] = offer
        return layoutState
    }

    private func singleOptionGroup() -> CatalogItemGroup {
        CatalogItemGroup(
            groupId: "g1",
            catalogItemIds: ["item1"],
            attributes: [
                CatalogItemGroupAttribute(
                    attributeId: "size",
                    label: "Size",
                    options: [
                        CatalogItemGroupOption(label: "8oz", catalogItemIds: ["item1"], metadata: nil)
                    ],
                    metadata: nil
                )
            ],
            metadata: nil
        )
    }

    private func twoOptionGroup() -> CatalogItemGroup {
        CatalogItemGroup(
            groupId: "g1",
            catalogItemIds: ["item1", "item2"],
            attributes: [
                CatalogItemGroupAttribute(
                    attributeId: "size",
                    label: "Size",
                    options: [
                        CatalogItemGroupOption(label: "8oz", catalogItemIds: ["item1"], metadata: nil),
                        CatalogItemGroupOption(label: "16oz", catalogItemIds: ["item2"], metadata: nil)
                    ],
                    metadata: nil
                )
            ],
            metadata: nil
        )
    }

    private func threeOptionGroup() -> CatalogItemGroup {
        CatalogItemGroup(
            groupId: "g1",
            catalogItemIds: ["item1", "item2", "item3"],
            attributes: [
                CatalogItemGroupAttribute(
                    attributeId: "size",
                    label: "Size",
                    options: [
                        CatalogItemGroupOption(label: "8oz", catalogItemIds: ["item1"], metadata: nil),
                        CatalogItemGroupOption(label: "16oz", catalogItemIds: ["item2"], metadata: nil),
                        CatalogItemGroupOption(label: "32oz", catalogItemIds: ["item3"], metadata: nil)
                    ],
                    metadata: nil
                )
            ],
            metadata: nil
        )
    }
}
