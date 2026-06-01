import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestCloseButtonComponent: XCTestCase {

    func test_creative_response() throws {

        let view = try TestPlaceHolder.make(layoutMaker: LayoutSchemaViewModel.makeCloseButton(layoutState:eventService:))

        let closeButton = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CloseButtonComponent.self)
            .actualView()
            .inspect()
            .hStack()
        
        // test custom modifier class
        let paddingModifier = try closeButton.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 10, right: 10, bottom: 10, left: 10))
        
        // test the effect of custom modifier
        let padding = try closeButton.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0))
        
        XCTAssertEqual(try closeButton.accessibilityLabel().string(), "Close")
    }

    func test_send_close_event() throws {
        var closeEventCalled = false
        let eventDelegate = MockUXHelper()
        let view = try TestPlaceHolder.make(
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeEventCalled = true
                }
            },
            eventDelegate: eventDelegate,
            layoutMaker: LayoutSchemaViewModel.makeCloseButton(layoutState:eventService:)
        )

        let closeButton = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CloseButtonComponent.self)
            .actualView()

        let sut = closeButton.model
        sut.sendCloseEvent()

        XCTAssertTrue(closeEventCalled)
        XCTAssertTrue(eventDelegate.roktEvents.contains(.PlacementClosed))
        XCTAssertNotNil(sut.layoutState)
    }
    
}

@available(iOS 15.0, *)
extension LayoutSchemaViewModel {
    static func makeCloseButton(
        layoutState: LayoutState,
        eventService: EventService
    ) throws -> Self {
        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState,
            eventService: eventService
        )
        let closeButton = ModelTestData.CloseButtonData.closeButton()
        return LayoutSchemaViewModel.closeButton(
            try transformer.getCloseButton(
                styles: closeButton.styles,
                children: transformer.transformChildren(closeButton.children, context: .outer([]))
            )
        )
    }
}
