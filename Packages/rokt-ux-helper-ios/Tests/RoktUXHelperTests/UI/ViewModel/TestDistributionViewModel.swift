import XCTest
@testable import RoktUXHelper

@available(iOS 13, *)
final class TestDistributionViewModel: XCTestCase {
    
    var events = [RoktEventRequest]()
    var eventService: EventService!
    var stubUXHelper: MockUXHelper!
    var layoutState: LayoutState = LayoutState()
    override func setUpWithError() throws {
        events = [RoktEventRequest]()
        eventService = get_mock_event_processor { [weak self] event in
            self?.events.append(event)
        }
        stubUXHelper = MockUXHelper()
    }
    
    func test_slot_impression_event() throws {
        // Arrange
        let viewModel = getDistributionViewModel(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendSlotImpressionEvent(currentOffer: 0)

        // Assert
        XCTAssertNotNil(viewModel.layoutState)
        XCTAssertEqual(events.first?.eventType, .SignalImpression)
        XCTAssertEqual(events.first?.parentGuid, "Slot1")
        XCTAssertEqual(events.first?.jwtToken, "JwtToken0")
    }
    
    func test_creative_impression_event() throws {
        // Arrange
        let viewModel = getDistributionViewModel(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendCreativeImpressionEvent(currentOffer: 0)

        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalImpression)
        XCTAssertEqual(events.first?.parentGuid, "instanceGuid")
        XCTAssertEqual(events.first?.jwtToken, "jwtToken1")
    }

    func test_creative_viewed_event() throws {
        // Arrange
        let viewModel = getDistributionViewModel(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendCreativeViewedEvent(currentOffer: 0)

        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalViewed)
        XCTAssertEqual(events.first?.parentGuid, "instanceGuid")
        XCTAssertEqual(events.first?.jwtToken, "jwtToken1")
    }

    func test_creative_viewed_event_for_next_offer_after_transition() throws {
        // Arrange
        let viewModel = getDistributionViewModelWithTwoSlots(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendCreativeViewedEvent(currentOffer: 0)
        viewModel.sendCreativeViewedEvent(currentOffer: 1)

        // Assert
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, .SignalViewed)
        XCTAssertEqual(events[0].parentGuid, "instanceGuid")
        XCTAssertEqual(events[0].jwtToken, "jwtToken1")
        XCTAssertEqual(events[1].eventType, .SignalViewed)
        XCTAssertEqual(events[1].parentGuid, "instanceGuid2")
        XCTAssertEqual(events[1].jwtToken, "jwtToken2")
    }
    
    func test_dismissal_no_more_offer_event() throws {
        // Arrange
        let viewModel = getDistributionViewModel(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendDismissalNoMoreOfferEvent()

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalDismissal)
        XCTAssertEqual(event?.parentGuid, "pluginInstanceGuid")
        XCTAssertEqual(event?.jwtToken, "plugin-config-token")
        XCTAssertNotNil(event?.metadata.first{$0.name == kInitiator})
        XCTAssertNotNil(event?.metadata.first{$0.value == kNoMoreOfferToShow})
    }
    
    func test_dismissal_collapsed_event() throws {
        // Arrange
        let viewModel = getDistributionViewModel(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendDismissalCollapsedEvent()

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalDismissal)
        XCTAssertEqual(event?.parentGuid, "pluginInstanceGuid")
        XCTAssertEqual(event?.jwtToken, "plugin-config-token")
        XCTAssertNotNil(event?.metadata.first{$0.name == kInitiator})
        XCTAssertNotNil(event?.metadata.first{$0.value == kCollapsed})
    }

    private func getDistributionViewModel(
        eventService: EventService,
        layoutState: LayoutState = LayoutState()
    ) -> DistributionViewModel {
        DistributionViewModel(
            eventService: eventService,
            slots: [getSlot()],
            layoutState: layoutState
        )
    }

    private func getDistributionViewModelWithTwoSlots(
        eventService: EventService,
        layoutState: LayoutState = LayoutState()
    ) -> DistributionViewModel {
        DistributionViewModel(
            eventService: eventService,
            slots: [getSlot(), getSlot2()],
            layoutState: layoutState
        )
    }
    
    private func getSlot() -> SlotModel {
        SlotModel(
            instanceGuid: "Slot1",
            offer: .mock(
                campaignId: "Campaign1",
                referralCreativeId: "referralCreativeId1",
                instanceGuid: "instanceGuid",
                token: "jwtToken1"
            ),
            layoutVariant: nil,
            jwtToken: "JwtToken0"
        )
    }

    private func getSlot2() -> SlotModel {
        SlotModel(
            instanceGuid: "Slot2",
            offer: .mock(
                campaignId: "Campaign2",
                referralCreativeId: "referralCreativeId2",
                instanceGuid: "instanceGuid2",
                token: "jwtToken2"
            ),
            layoutVariant: nil,
            jwtToken: "JwtToken1"
        )
    }
}
