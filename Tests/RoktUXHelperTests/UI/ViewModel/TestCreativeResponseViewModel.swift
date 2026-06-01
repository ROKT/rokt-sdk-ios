import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
final class TestCreativeResponseViewModel: XCTestCase {
    var events = [RoktEventRequest]()
    var stubUXHelper: MockUXHelper!
    var eventService: EventService!

    override func setUpWithError() throws {
        events = [RoktEventRequest]()
        self.stubUXHelper = MockUXHelper()
    }
    
    func test_send_signal_impression_event() throws {
        // Arrange
        eventService = get_mock_event_processor(
            uxEventDelegate: stubUXHelper,
            eventHandler: { event in
                self.events.append(event)
            }
        )
        let viewModel = get_model(eventService: eventService)

        // Act
        viewModel.sendSignalResponseEvent()
        
        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalResponse)
        XCTAssertEqual(events.first?.parentGuid, "creativeInstance")
        XCTAssertEqual(events.first?.jwtToken, "response-jwt")
    }
    
    func test_send_signal_gated_impression_event() throws {
        // Arrange
        eventService = get_mock_event_processor(
            uxEventDelegate: stubUXHelper,
            eventHandler: { event in
                self.events.append(event)
            }
        )
        let viewModel = get_model(signalType: .signalGatedResponse, eventService: eventService)

        // Act
        viewModel.sendSignalResponseEvent()
        
        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalGatedResponse)
        XCTAssertEqual(events.first?.parentGuid, "creativeInstance")
        XCTAssertEqual(events.first?.jwtToken, "response-jwt")
    }
    
    func test_get_valid_url() throws {
        // Arrange
        eventService = get_mock_event_processor(
            uxEventDelegate: stubUXHelper,
            eventHandler: { event in
                self.events.append(event)
            }
        )
        let viewModel = get_model(url: "https://www.rokt.com", eventService: eventService)
        // Act
        let url = viewModel.getOfferUrl()
        // Assert
        XCTAssertEqual(url, URL(string: "https://www.rokt.com"))
    }
    
    func test_get_inavlid_url_nil() throws {
        // Arrange
        eventService = get_mock_event_processor(
            uxEventDelegate: stubUXHelper,
            eventHandler: { event in
                self.events.append(event)
            }
        )
        let viewModel = get_model(signalType: .signalGatedResponse, eventService: eventService)

        // Act
        let url = viewModel.getOfferUrl()
        // Assert
        XCTAssertNil(url)
    }
    
    func test_get_inavlid_url_nil_when_action_is_not_url() throws {
        // Arrange
        eventService = get_mock_event_processor(
            uxEventDelegate: stubUXHelper,
            eventHandler: { event in
                self.events.append(event)
            }
        )
        let viewModel = get_model(action: .captureOnly, eventService: eventService)
        // Act
        let url = viewModel.getOfferUrl()
        // Assert
        XCTAssertNil(url)
    }

    func test_next_offer() {
        eventService = get_mock_event_processor()
        let actionCollection = ActionCollection()
        var nextOfferCalled = false
        actionCollection[.nextOffer] = { _ in
            nextOfferCalled = true
        }
        let layoutState = LayoutState(actionCollection: actionCollection)
        let viewModel = get_model(action: .captureOnly, eventService: eventService, layoutState: layoutState)
        viewModel.goToNextOffer()

        XCTAssertTrue(nextOfferCalled)
    }

    func get_model(
        signalType: RoktUXSignalType = .signalResponse,
        url: String? = nil,
        action: Action = .url,
        eventService: EventService,
        layoutState: LayoutState = LayoutState()
    ) -> CreativeResponseViewModel {
        return CreativeResponseViewModel(
            children: [],
            responseKey: .positive,
            responseOptions:
                RoktUXResponseOption(id: "",
                                     action: action,
                                     instanceGuid: "creativeInstance",
                                     signalType: signalType,
                                     shortLabel: "",
                                     longLabel: "",
                                     shortSuccessLabel: "",
                                     isPositive: nil,
                                     url: url,
                                     responseJWTToken: "response-jwt"),
            openLinks: nil,
            layoutState: layoutState,
            eventService: eventService,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil
        )
    }
}
