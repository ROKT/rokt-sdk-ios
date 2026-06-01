import XCTest
import SwiftUI
import SnapshotTesting
import DcuiSchema
@testable import RoktUXHelper

@available(iOS 15, *)
final class TestCatalogDevicePayButtonComponent: XCTestCase {

    // MARK: - Snapshots

    func testSnapshot_applePay() throws {
        let view = try TestPlaceHolder.make(
            layoutMaker: { layoutState, eventService in
                try LayoutSchemaViewModel.makeCatalogDevicePayButton(
                    provider: .applePay,
                    layoutState: layoutState,
                    eventService: eventService
                )
            }
        )
        .frame(width: 350, height: 80)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    func testSnapshot_afterpay() throws {
        let view = try TestPlaceHolder.make(
            layoutMaker: { layoutState, eventService in
                try LayoutSchemaViewModel.makeCatalogDevicePayButton(
                    provider: .afterpay,
                    layoutState: layoutState,
                    eventService: eventService
                )
            }
        )
        .frame(width: 350, height: 120)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    func test_handleTap_callsDevicePay_whenNoValidation() {
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "item-1")

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: catalogItem,
            children: nil,
            provider: .applePay,
            layoutState: MockLayoutState(),
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: nil
        )

        sut.handleTap()

        XCTAssertTrue(eventService.cartItemDevicePayCalled)
    }

    func test_handleTap_routesCardProvider_throughCartItemDevicePay() {
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "item-card")

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: catalogItem,
            children: nil,
            provider: .card,
            layoutState: MockLayoutState(),
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: nil
        )

        sut.handleTap()

        XCTAssertTrue(eventService.cartItemDevicePayCalled)
        XCTAssertEqual(eventService.cartItemDevicePayLastProvider, .card)
    }

    func test_handleTap_blockedByValidation_sendsUserInteraction() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "item-1")

        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: { .invalid },
            onStatusChange: { _ in }
        )

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: catalogItem,
            children: nil,
            provider: .applePay,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: ValidationTriggerConfig(validatorFieldKeys: ["dropdown"])
        )

        sut.handleTap()

        XCTAssertFalse(eventService.cartItemDevicePayCalled)
        XCTAssertTrue(eventService.cartItemUserInteractionCalled)
    }

    func test_devicePayCompletion_success_setsCustomState() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "item-1")

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: catalogItem,
            children: nil,
            provider: .applePay,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: nil
        )
        sut.position = 0

        sut.handleTap()
        XCTAssertTrue(eventService.cartItemDevicePayCalled)

        // Simulate completion callback
        eventService.cartItemDevicePayCompletionCallback?(.success)

        let exp = expectation(description: "custom state updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let map = layoutState.items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?>
            let identifier = CustomStateIdentifiable(position: 0, key: .paymentResult)
            XCTAssertEqual(map?.wrappedValue?[identifier], 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func test_devicePayCompletion_failure_setsNegativeCustomState() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "item-1")

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: catalogItem,
            children: nil,
            provider: .applePay,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: nil
        )
        sut.position = 0

        sut.handleTap()
        eventService.cartItemDevicePayCompletionCallback?(.failure)

        let exp = expectation(description: "custom state updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let map = layoutState.items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?>
            let identifier = CustomStateIdentifiable(position: 0, key: .paymentResult)
            XCTAssertEqual(map?.wrappedValue?[identifier], -1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

@available(iOS 15.0, *)
extension LayoutSchemaViewModel {
    static func makeCatalogDevicePayButton(
        provider: PaymentProvider,
        layoutState: LayoutState,
        eventService: EventService
    ) throws -> Self {
        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState,
            eventService: eventService
        )
        let model: CatalogDevicePayButtonModel<LayoutSchemaModel, WhenPredicate>
        switch provider {
        case .applePay:
            model = ModelTestData.CatalogDevicePayButtonData.applePay()
        case .afterpay:
            model = ModelTestData.CatalogDevicePayButtonData.afterpay()
        default:
            model = ModelTestData.CatalogDevicePayButtonData.catalogDevicePayButton()
        }

        guard let catalogItem = ModelTestData.CatalogPageModelData.withBNF().layoutPlugins?.first?.slots.first?.offer?
            .catalogItems?.first else {
            XCTFail("Couldn't get catalog item")
            throw LayoutTransformerError.InvalidMapping()
        }
        return LayoutSchemaViewModel.catalogDevicePayButton(
            try transformer.getCatalogDevicePayButton(
                model: model,
                children: transformer.transformChildren(model.children, context: .inner(.addToCart(catalogItem))),
                context: .inner(.addToCart(catalogItem))
            )
        )
    }
}
