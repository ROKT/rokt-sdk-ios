import XCTest
import DcuiSchema
@testable import RoktUXHelper

@available(iOS 15, *)
final class RoktUXTests: XCTestCase {

    // MARK: - Fixtures

    private let layoutId = "layout-id"

    private func makeCatalogItem(
        price: Decimal = 57.5,
        originalPrice: Decimal = 130.0
    ) -> CatalogItem {
        CatalogItem(
            images: [:],
            catalogItemId: "catalog-item-id",
            cartItemId: "v1:cart-item:canal",
            instanceGuid: "instance-guid",
            title: "GLD Rope Bracelet",
            description: "description",
            price: price,
            priceFormatted: "$57.50",
            originalPrice: originalPrice,
            originalPriceFormatted: "$130.00",
            currency: "USD",
            signalType: "SignalResponse",
            url: nil,
            minItemCount: 0,
            maxItemCount: 1,
            preSelectedQuantity: 0,
            providerData: "{}",
            urlBehavior: "newTab",
            positiveResponseText: "Buy Now",
            negativeResponseText: "Decline Offer",
            addOns: nil,
            copy: nil,
            inventoryStatus: "InStock",
            linkedProductId: "",
            token: "token"
        )
    }

    private func makeSUT(
        onEvent: @escaping (RoktUXEvent) -> Void
    ) -> RoktUX {
        let sut = RoktUX()
        sut.onRoktEvent = onEvent
        return sut
    }

    // MARK: - onCartItemInstantPurchase

    func test_onCartItemInstantPurchase_emitsSalePriceNotOriginalPrice() {
        let catalogItem = makeCatalogItem()
        var captured: RoktUXEvent.CartItemInstantPurchase?
        let sut = makeSUT { event in
            captured = event as? RoktUXEvent.CartItemInstantPurchase
        }

        sut.onCartItemInstantPurchase(layoutId, catalogItem: catalogItem)

        let event = try? XCTUnwrap(captured)
        XCTAssertEqual(event?.unitPrice, Decimal(57.5))
        XCTAssertEqual(event?.totalPrice, Decimal(57.5))
        XCTAssertNotEqual(event?.unitPrice, Decimal(130.0))
        XCTAssertNotEqual(event?.totalPrice, Decimal(130.0))
    }

    // MARK: - onCartItemDevicePay

    func test_onCartItemDevicePay_emitsSalePriceNotOriginalPrice() {
        let catalogItem = makeCatalogItem()
        var captured: RoktUXEvent.CartItemDevicePay?
        let sut = makeSUT { event in
            captured = event as? RoktUXEvent.CartItemDevicePay
        }

        sut.onCartItemDevicePay(
            layoutId,
            catalogItem: catalogItem,
            paymentProvider: .applePay,
            transactionData: nil
        )

        let event = try? XCTUnwrap(captured)
        XCTAssertEqual(event?.unitPrice, Decimal(57.5))
        XCTAssertEqual(event?.totalPrice, Decimal(57.5))
        XCTAssertNotEqual(event?.unitPrice, Decimal(130.0))
        XCTAssertNotEqual(event?.totalPrice, Decimal(130.0))
    }

    // MARK: - onCartItemForwardPayment

    func test_onCartItemForwardPayment_emitsSalePriceNotOriginalPrice() {
        let catalogItem = makeCatalogItem()
        var captured: RoktUXEvent.CartItemForwardPayment?
        let sut = makeSUT { event in
            captured = event as? RoktUXEvent.CartItemForwardPayment
        }

        sut.onCartItemForwardPayment(
            layoutId,
            catalogItem: catalogItem,
            transactionData: nil
        )

        let event = try? XCTUnwrap(captured)
        XCTAssertEqual(event?.unitPrice, Decimal(57.5))
        XCTAssertEqual(event?.totalPrice, Decimal(57.5))
        XCTAssertNotEqual(event?.unitPrice, Decimal(130.0))
        XCTAssertNotEqual(event?.totalPrice, Decimal(130.0))
    }
}
