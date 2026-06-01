import XCTest
import DcuiSchema
@testable import RoktUXHelper

final class CatalogDevicePayButtonViewModelTests: XCTestCase {

    func test_customStateKey_isPaymentResult() {
        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
            children: nil,
            provider: .applePay,
            layoutState: MockLayoutState(),
            eventService: MockEventService(),
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: nil
        )

        XCTAssertEqual(sut.customStateKey, "paymentResult")
    }

    func test_handleTap_doesNotTriggerEventWhenValidationFails() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let isValid = false

        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: {
                return isValid ? .valid : .invalid
            },
            onStatusChange: { _ in }
        )

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
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
    }

    func test_handleTap_triggersEventWhenValidationSucceeds() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        var isValid = false

        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: {
                return isValid ? .valid : .invalid
            },
            onStatusChange: { _ in }
        )

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
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

        isValid = true
        sut.handleTap()

        XCTAssertTrue(eventService.cartItemDevicePayCalled)
    }

    func test_devicePaySuccess_setsLayoutVariantCustomState() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let isValid = true

        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: {
                return isValid ? .valid : .invalid
            },
            onStatusChange: { _ in }
        )

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
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
        sut.position = 0

        sut.handleTap()

        XCTAssertTrue(eventService.cartItemDevicePayCalled)

        let expectation = expectation(description: "State is set")
        eventService.cartItemDevicePayCompletionCallback?(.success)

        DispatchQueue.main.async {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.paymentResult.rawValue,
                position: 0
            ),
            1
        )
    }

    func test_devicePayFailure_setsLayoutVariantCustomState() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let isValid = true

        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: {
                return isValid ? .valid : .invalid
            },
            onStatusChange: { _ in }
        )

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
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
        sut.position = 0

        sut.handleTap()

        XCTAssertTrue(eventService.cartItemDevicePayCalled)

        let expectation = expectation(description: "State is set")
        eventService.cartItemDevicePayCompletionCallback?(.failure)

        DispatchQueue.main.async {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.paymentResult.rawValue,
                position: 0
            ),
            -1
        )
    }

    func test_devicePayRetry_setsLayoutVariantCustomState() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let isValid = true

        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: {
                return isValid ? .valid : .invalid
            },
            onStatusChange: { _ in }
        )

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
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
        sut.position = 0

        sut.handleTap()

        XCTAssertTrue(eventService.cartItemDevicePayCalled)

        let expectation = expectation(description: "State is set")
        eventService.cartItemDevicePayCompletionCallback?(.retry)

        DispatchQueue.main.async {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.paymentResult.rawValue,
                position: 0
            ),
            -1
        )
    }

    func test_devicePayPendingConfirmation_writesDevicePayStateAndBreakdown() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        let catalogRuntimeData: [String: String] = [
            "subtotal": "$24.00",
            "tax": "$1.94",
            "shipping": "$0.00",
            "total": "$26.72"
        ]

        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
            children: nil,
            provider: .paypal,
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

        let expectation = expectation(description: "State is set")
        eventService.cartItemDevicePayCompletionCallback?(.pendingConfirmation(catalogRuntimeData: catalogRuntimeData))

        DispatchQueue.main.async {
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        // devicePayState gates the confirmation When-node.
        XCTAssertEqual(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.devicePayState.rawValue,
                position: 0
            ),
            1
        )
        // paymentResult is reserved for success/failure and must not be touched here.
        XCTAssertNil(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.paymentResult.rawValue,
                position: 0
            )
        )
        // Catalog-runtime payload is published into items so reactive text resolution sees it.
        XCTAssertEqual(
            layoutState.items[LayoutState.catalogRuntimeDataKey] as? [String: String],
            catalogRuntimeData
        )
    }

    // MARK: - Multi-tap / in-flight guard

    func test_handleTap_secondTapWhileInFlight_doesNotFireEventAgain() {
        let eventService = MockEventService()
        let sut = makeViewModel(eventService: eventService)

        sut.handleTap()
        sut.handleTap()

        XCTAssertEqual(eventService.cartItemDevicePayCallCount, 1)
        XCTAssertTrue(sut.isProcessing)
    }

    func test_handleTap_setsIsProcessingTrueBeforeFiring() {
        let eventService = MockEventService()
        let sut = makeViewModel(eventService: eventService)

        XCTAssertFalse(sut.isProcessing)
        sut.handleTap()
        XCTAssertTrue(sut.isProcessing)
    }

    func test_handleTap_secondTapAfterSuccess_firesEventAgain() {
        let eventService = MockEventService()
        let sut = makeViewModel(eventService: eventService)

        sut.handleTap()
        eventService.cartItemDevicePayCompletionCallback?(.success)

        let exp = expectation(description: "isProcessing reset")
        DispatchQueue.main.async {
            XCTAssertFalse(sut.isProcessing)
            sut.handleTap()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(eventService.cartItemDevicePayCallCount, 2)
    }

    func test_handleTap_secondTapAfterFailure_firesEventAgain() {
        let eventService = MockEventService()
        let sut = makeViewModel(eventService: eventService)

        sut.handleTap()
        eventService.cartItemDevicePayCompletionCallback?(.failure)

        let exp = expectation(description: "isProcessing reset")
        DispatchQueue.main.async {
            XCTAssertFalse(sut.isProcessing)
            sut.handleTap()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(eventService.cartItemDevicePayCallCount, 2)
    }

    func test_handleTap_secondTapAfterRetry_firesEventAgain() {
        let eventService = MockEventService()
        let sut = makeViewModel(eventService: eventService)

        sut.handleTap()
        eventService.cartItemDevicePayCompletionCallback?(.retry)

        let exp = expectation(description: "isProcessing reset")
        DispatchQueue.main.async {
            XCTAssertFalse(sut.isProcessing)
            sut.handleTap()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(eventService.cartItemDevicePayCallCount, 2)
    }

    func test_handleTap_secondTapAfterPendingConfirmation_resetsIsProcessing() {
        let eventService = MockEventService()
        let sut = makeViewModel(eventService: eventService)

        sut.handleTap()
        eventService.cartItemDevicePayCompletionCallback?(.pendingConfirmation(catalogRuntimeData: [:]))

        let exp = expectation(description: "isProcessing reset")
        DispatchQueue.main.async {
            XCTAssertFalse(sut.isProcessing)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func test_handleTap_doesNotSetIsProcessing_whenValidationFails() {
        let layoutState = MockLayoutState()
        let eventService = MockEventService()
        layoutState.validationCoordinator.registerField(
            key: "dropdown",
            owner: self,
            validation: { .invalid },
            onStatusChange: { _ in }
        )
        let sut = CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
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

        XCTAssertFalse(sut.isProcessing)
        XCTAssertEqual(eventService.cartItemDevicePayCallCount, 0)
    }

    private func makeViewModel(
        eventService: MockEventService,
        validatorTriggerConfig: ValidationTriggerConfig? = nil
    ) -> CatalogDevicePayButtonViewModel {
        CatalogDevicePayButtonViewModel(
            catalogItem: makeCatalogItem(id: "item"),
            children: nil,
            provider: .applePay,
            layoutState: MockLayoutState(),
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            validatorTriggerConfig: validatorTriggerConfig
        )
    }

    private func makeCatalogItem(id: String) -> CatalogItem {
        CatalogItem(
            images: [:],
            catalogItemId: id,
            cartItemId: "cart-\(id)",
            instanceGuid: "instance-\(id)",
            title: "title-\(id)",
            description: "description-\(id)",
            price: nil,
            priceFormatted: nil,
            originalPrice: nil,
            originalPriceFormatted: nil,
            currency: "USD",
            signalType: nil,
            url: nil,
            minItemCount: nil,
            maxItemCount: nil,
            preSelectedQuantity: nil,
            providerData: "provider-\(id)",
            urlBehavior: nil,
            positiveResponseText: "positive",
            negativeResponseText: "negative",
            addOns: nil,
            copy: nil,
            inventoryStatus: nil,
            linkedProductId: nil,
            token: "token-\(id)"
        )
    }
}
