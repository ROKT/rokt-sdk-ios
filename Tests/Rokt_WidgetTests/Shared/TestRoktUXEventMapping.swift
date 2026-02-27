import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

final class RoktUXEventMappingTests: XCTestCase {
    let testLayoutId = "test-layout-id"
    let testSessionId = "test-session-id"
    let testPageInstanceGuid = "test-page-guid"
    let testJwtToken = "test-jwt-token"
    let testUrl = "https://test.com"

    func testOfferEngagementMapping() {
        // Given
        let uxEvent = RoktUXEvent.OfferEngagement(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.OfferEngagement)
        if let event = roktEvent as? RoktEvent.OfferEngagement {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testFirstPositiveEngagementMapping() {
        // Given
        let uxEvent = RoktUXEvent.FirstPositiveEngagement(
            sessionId: testSessionId,
            pageInstanceGuid: testPageInstanceGuid,
            jwtToken: testJwtToken,
            layoutId: testLayoutId
        )

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.FirstPositiveEngagement)
        if let event = roktEvent as? RoktEvent.FirstPositiveEngagement {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testPositiveEngagementMapping() {
        // Given
        let uxEvent = RoktUXEvent.PositiveEngagement(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.PositiveEngagement)
        if let event = roktEvent as? RoktEvent.PositiveEngagement {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testLayoutInteractiveMapping() {
        // Given
        let uxEvent = RoktUXEvent.LayoutInteractive(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.PlacementInteractive)
        if let event = roktEvent as? RoktEvent.PlacementInteractive {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testLayoutReadyMapping() {
        // Given
        let uxEvent = RoktUXEvent.LayoutReady(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.PlacementReady)
        if let event = roktEvent as? RoktEvent.PlacementReady {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testLayoutClosedMapping() {
        // Given
        let uxEvent = RoktUXEvent.LayoutClosed(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.PlacementClosed)
        if let event = roktEvent as? RoktEvent.PlacementClosed {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testLayoutCompletedMapping() {
        // Given
        let uxEvent = RoktUXEvent.LayoutCompleted(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.PlacementCompleted)
        if let event = roktEvent as? RoktEvent.PlacementCompleted {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testLayoutFailureMapping() {
        // Given
        let uxEvent = RoktUXEvent.LayoutFailure(layoutId: testLayoutId)

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.PlacementFailure)
        if let event = roktEvent as? RoktEvent.PlacementFailure {
            XCTAssertEqual(event.identifier, testLayoutId)
        }
    }

    func testOpenUrlMapping() {
        // Given
        let uxEvent = RoktUXEvent.OpenUrl(
            url: testUrl,
            id: "test-id",
            layoutId: testLayoutId,
            type: .passthrough,
            onClose: { _ in },
            onError: { _, _ in }
        )

        // When
        let roktEvent = uxEvent.mapToRoktEvent

        // Then
        XCTAssertTrue(roktEvent is RoktEvent.OpenUrl)
        if let event = roktEvent as? RoktEvent.OpenUrl {
            XCTAssertEqual(event.identifier, testLayoutId)
            XCTAssertEqual(event.url, testUrl)
        }
    }

    func testUnknownEventMapping() {
        // Given
        let unknownEvent = UnknownRoktUXEvent()

        // When
        let roktEvent = unknownEvent.mapToRoktEvent

        // Then
        XCTAssertNil(roktEvent)
    }
}

// Helper class for testing unknown event types
private class UnknownRoktUXEvent: RoktUXEvent {
    var layoutId: String = "unknown"
}
