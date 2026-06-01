import XCTest
import DcuiSchema
@testable import RoktUXHelper

@available(iOS 15, *)
final class CatalogResponseButtonViewModelTests: XCTestCase {

    func test_isPartnerManagedPurchase_defaultsToTrue_whenNotProvided() {
        let sut = makeSUT()

        XCTAssertTrue(sut.isPartnerManagedPurchase)
    }

    func test_cartItemInstantPurchase_partnerManaged_callsInstantPurchaseAndDismisses() {
        let eventService = MockEventService()
        let layoutState = MockLayoutState()
        var closeInvoked = false
        layoutState.actionCollection[.close] = { _ in closeInvoked = true }

        let sut = makeSUT(
            catalogItem: makeCatalogItem(id: "item-1"),
            layoutState: layoutState,
            eventService: eventService,
            transactionData: makeTransactionData(isPartnerManagedPurchase: true)
        )

        sut.cartItemInstantPurchase(position: nil)

        XCTAssertTrue(eventService.cartItemInstantPurchaseCalled)
        XCTAssertFalse(eventService.cartItemForwardPaymentCalled)
        XCTAssertTrue(eventService.dismissalEventCalled)
        XCTAssertEqual(eventService.dismissOption, .defaultDismiss)
        XCTAssertTrue(closeInvoked)
    }

    func test_cartItemInstantPurchase_forwardPayment_forwardsTransactionData() {
        let eventService = MockEventService()
        let layoutState = MockLayoutState()
        var closeInvoked = false
        layoutState.actionCollection[.close] = { _ in closeInvoked = true }

        let transactionData = TransactionData(
            shippingAddress: Address(
                name: "",
                address1: "123 Main St",
                address2: "Apt 4B",
                city: "New York",
                state: "NY",
                stateCode: "",
                country: "US",
                countryCode: "",
                zip: "10001"
            ),
            billingAddress: nil,
            paymentType: nil,
            supportedPaymentMethods: nil,
            isPartnerManagedPurchase: false,
            partnerPaymentReference: "ref-xyz",
            confirmationRef: nil,
            metadata: [:]
        )
        let sut = makeSUT(
            catalogItem: makeCatalogItem(id: "item-1"),
            layoutState: layoutState,
            eventService: eventService,
            transactionData: transactionData
        )

        sut.cartItemInstantPurchase(position: nil)

        XCTAssertTrue(eventService.cartItemForwardPaymentCalled)
        XCTAssertFalse(eventService.cartItemInstantPurchaseCalled)
        XCTAssertFalse(eventService.dismissalEventCalled)
        XCTAssertFalse(closeInvoked)
        XCTAssertEqual(eventService.lastForwardPaymentCatalogItem?.catalogItemId, "item-1")
        XCTAssertEqual(eventService.lastForwardPaymentTransactionData?.shippingAddress?.address1, "123 Main St")
        XCTAssertEqual(eventService.lastForwardPaymentTransactionData?.shippingAddress?.zip, "10001")
        XCTAssertEqual(eventService.lastForwardPaymentTransactionData?.partnerPaymentReference, "ref-xyz")
    }

    func test_cartItemInstantPurchase_nilCatalogItem_dismisses() {
        let eventService = MockEventService()
        let layoutState = MockLayoutState()
        var closeInvoked = false
        layoutState.actionCollection[.close] = { _ in closeInvoked = true }

        let sut = makeSUT(
            catalogItem: nil,
            layoutState: layoutState,
            eventService: eventService
        )

        sut.cartItemInstantPurchase(position: nil)

        XCTAssertFalse(eventService.cartItemInstantPurchaseCalled)
        XCTAssertFalse(eventService.cartItemForwardPaymentCalled)
        XCTAssertTrue(eventService.dismissalEventCalled)
        XCTAssertTrue(closeInvoked)
    }

    func test_forwardPaymentSuccess_writesSuccessToPaymentResult() {
        let eventService = MockEventService()
        let layoutState = MockLayoutState()

        let sut = makeSUT(
            catalogItem: makeCatalogItem(id: "item-1"),
            layoutState: layoutState,
            eventService: eventService,
            transactionData: makeTransactionData(isPartnerManagedPurchase: false)
        )

        sut.cartItemInstantPurchase(position: 0)
        XCTAssertTrue(eventService.cartItemForwardPaymentCalled)

        let expectation = expectation(description: "Success state written")
        eventService.cartItemForwardPaymentCompletionCallback?(.success)
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.paymentResult.rawValue,
                position: 0
            ),
            1
        )
    }

    func test_forwardPaymentFailure_writesFailureToPaymentResult() {
        let eventService = MockEventService()
        let layoutState = MockLayoutState()

        let sut = makeSUT(
            catalogItem: makeCatalogItem(id: "item-1"),
            layoutState: layoutState,
            eventService: eventService,
            transactionData: makeTransactionData(isPartnerManagedPurchase: false)
        )

        sut.cartItemInstantPurchase(position: 0)
        XCTAssertTrue(eventService.cartItemForwardPaymentCalled)

        let expectation = expectation(description: "Failure state written")
        eventService.cartItemForwardPaymentCompletionCallback?(.failure(reason: "declined"))
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(
            layoutState.layoutVariantCustomStateValue(
                for: CustomStateIdentifiable.Keys.paymentResult.rawValue,
                position: 0
            ),
            -1
        )
    }

    // MARK: - Helpers

    private func makeSUT(
        catalogItem: CatalogItem? = nil,
        layoutState: MockLayoutState = MockLayoutState(),
        eventService: MockEventService = MockEventService(),
        transactionData: TransactionData? = nil
    ) -> CatalogResponseButtonViewModel {
        CatalogResponseButtonViewModel(
            catalogItem: catalogItem,
            children: nil,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            transactionData: transactionData
        )
    }

    private func makeTransactionData(isPartnerManagedPurchase: Bool) -> TransactionData {
        TransactionData(
            shippingAddress: nil,
            billingAddress: nil,
            paymentType: nil,
            supportedPaymentMethods: nil,
            isPartnerManagedPurchase: isPartnerManagedPurchase,
            partnerPaymentReference: nil,
            confirmationRef: nil,
            metadata: [:]
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
