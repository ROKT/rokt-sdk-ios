import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
final class TestRoktEmbeddedViewModel: XCTestCase {
    var events = [RoktEventRequest]()
    var eventService: EventService!
    var stubUXHelper: MockUXHelper!
    let startDate = Date()
    
    override func setUpWithError() throws {
        events = [RoktEventRequest]()
        eventService = get_mock_event_processor { [weak self] event in
            self?.events.append(event)
        }
        self.stubUXHelper = MockUXHelper()
    }
    
    func test_plugin_impression_event() throws {
        // Arrange
        let layoutState = LayoutState()
        eventService = get_mock_event_processor(startDate: startDate) { [weak self] event in
            self?.events.append(event)
        }
        let viewModel = get_model(eventService: eventService, layoutState: layoutState)

        // Act
        viewModel.sendOnLoadEvents()
        
        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalImpression)
        XCTAssertNotNil(event?.metadata.first{$0.name == BE_PAGE_SIGNAL_LOAD})
        XCTAssertNotNil(event?.metadata.first{$0.value == EventDateFormatter.getDateString(startDate)})
        XCTAssertNotNil(event?.metadata.first{$0.name == BE_PAGE_RENDER_ENGINE})
        XCTAssertNotNil(event?.metadata.first{$0.value == BE_RENDER_ENGINE_LAYOUTS})
        XCTAssertNotNil(viewModel.layoutState)
    }
    
    func test_plugin_activation_event() throws {
        // Arrange
        let viewModel = get_model(eventService: eventService)
        // Act
        viewModel.sendSignalActivationEvent()
        
        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalActivation)
        XCTAssertEqual(event?.parentGuid, mockPluginInstanceGuid)
        XCTAssertEqual(event?.jwtToken, mockPluginConfigJWTToken)
        XCTAssertNil(viewModel.layoutState)
    }

    func get_model(eventService: EventService, layoutState: LayoutState = LayoutState()) -> RoktEmbeddedViewModel {
        RoktEmbeddedViewModel(layouts: [],
                              eventService: eventService,
                              layoutState: layoutState)
    }
}
