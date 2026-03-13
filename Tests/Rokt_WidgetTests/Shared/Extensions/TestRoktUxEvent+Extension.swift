import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

final class TestRoktUxEventExtension: XCTestCase {

    func test_mapToRoktEvent_OfferEngagement() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.OfferEngagement(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.OfferEngagement {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.OfferEngagement")
        }
    }

    func test_mapToRoktEvent_FirstPositiveEngagement() {
        let expectedLayoutId = "123"
        let expectedSessionId = "456"
        let expectedToken = "token"
        let expectedPageGuid = "pageGuid"

        let providedEvent = RoktUXEvent.FirstPositiveEngagement(
            sessionId: expectedSessionId,
            pageInstanceGuid: expectedPageGuid,
            jwtToken: expectedToken,
            layoutId: expectedLayoutId
        )

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.FirstPositiveEngagement {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.FirstPositiveEngagement")
        }
    }

    func test_mapToRoktEvent_OpenUrl() {
        let expectedLayoutId = "123"
        let expectedUrl = "url"

        let providedEvent = RoktUXEvent.OpenUrl(
            url: expectedUrl,
            id: "id",
            layoutId: expectedLayoutId,
            type: RoktUXOpenURLType.externally,
            onClose: { _ in },
            onError: { _, _ in }
        )

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.OpenUrl {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
            XCTAssertEqual(offerEvent.url, expectedUrl)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.OpenUrl")
        }
    }

    func test_mapToRoktEvent_PositiveEngagement() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.PositiveEngagement(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.PositiveEngagement {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.PositiveEngagement")
        }
    }

    func test_mapToRoktEvent_LayoutInteractive_PlacementInteractive() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.LayoutInteractive(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.PlacementInteractive {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.PlacementInteractive")
        }
    }

    func test_mapToRoktEvent_LayoutReady_PlacementReady() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.LayoutReady(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.PlacementReady {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.PlacementReady")
        }
    }

    func test_mapToRoktEvent_LayoutClosed_PlacementClosed() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.LayoutClosed(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.PlacementClosed {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.PlacementClosed")
        }
    }

    func test_mapToRoktEvent_LayoutCompleted_PlacementCompleted() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.LayoutCompleted(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.PlacementCompleted {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.PlacementCompleted")
        }
    }

    func test_mapToRoktEvent_LayoutFailure_PlacementFailure() {
        let expectedLayoutId = "123"

        let providedEvent = RoktUXEvent.LayoutFailure(layoutId: expectedLayoutId)

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.PlacementFailure {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.PlacementFailure")
        }
    }

    func test_mapToRoktEvent_CartItemInstantPurchase() {
        let expectedLayoutId = "123"
        let expectedName = "name"
        let expectedCartItemId = "cartItemId"
        let expectedCatalogItemId = "catalogItemId"
        let expectedCurrency = "currency"
        let expectedDescription = "description"
        let expectedLinkedProductId = "linkedProductId"
        let expectedProviderData = "providerData"
        let expectedQuantity = NSDecimalNumber(decimal: 123.0)
        let expectedTotalPrice = NSDecimalNumber(decimal: 456.0)
        let expectedUnitPrice = NSDecimalNumber(decimal: 789.0)

        let providedEvent = RoktUXEvent.CartItemInstantPurchase(
            layoutId: expectedLayoutId,
            name: expectedName,
            cartItemId: expectedCartItemId,
            catalogItemId: expectedCatalogItemId,
            currency: expectedCurrency,
            description: expectedDescription,
            linkedProductId: expectedLinkedProductId,
            providerData: expectedProviderData,
            quantity: expectedQuantity.decimalValue,
            totalPrice: expectedTotalPrice.decimalValue,
            unitPrice: expectedUnitPrice.decimalValue
        )

        let returnedEvent = providedEvent.mapToRoktEvent

        XCTAssertNotNil(returnedEvent)
        if let offerEvent = returnedEvent as? RoktEvent.CartItemInstantPurchase {
            XCTAssertEqual(offerEvent.identifier, expectedLayoutId)
            XCTAssertEqual(offerEvent.name, expectedName)
            XCTAssertEqual(offerEvent.cartItemId, expectedCartItemId)
            XCTAssertEqual(offerEvent.catalogItemId, expectedCatalogItemId)
            XCTAssertEqual(offerEvent.currency, expectedCurrency)
            XCTAssertEqual(offerEvent.description, expectedDescription)
            XCTAssertEqual(offerEvent.linkedProductId, expectedLinkedProductId)
            XCTAssertEqual(offerEvent.providerData, expectedProviderData)
            XCTAssertEqual(offerEvent.quantity, expectedQuantity)
            XCTAssertEqual(offerEvent.totalPrice, expectedTotalPrice)
            XCTAssertEqual(offerEvent.unitPrice, expectedUnitPrice)
        } else {
            XCTFail("returnedEvent is not of type RoktEvent.CartItemInstantPurchase")
        }
    }
}
