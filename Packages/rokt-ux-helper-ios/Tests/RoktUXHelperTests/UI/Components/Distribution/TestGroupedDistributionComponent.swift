import XCTest
import SwiftUI
import ViewInspector
import Combine
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestGroupedDistributionComponent: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()

    func test_grouped_distribution() throws {
        var closeActionCalled = false
        
        let view = try TestPlaceHolder.make(
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeGroupedDistribution(layoutState:eventService:)
        )

        let groupedComponent = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(GroupedDistributionComponent.self)
            .actualView()
        
        let grouped = try groupedComponent
            .inspect()
            .vStack()
        
        // test custom modifier class
        let paddingModifier = try grouped.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 3, right: 4, bottom: 5, left: 6))
        
        // test the effect of custom modifier
        let padding = try grouped.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 4.0))
        
        XCTAssertEqual(try grouped.accessibilityLabel().string(), "Page 1 of 1")

        groupedComponent.goToNextOffer()
        XCTAssertTrue(closeActionCalled)
    }
    
    func test_goToNextGroup_with_closeOnComplete_default() throws {
        var closeActionCalled = false
        
        let view = try TestPlaceHolder.make(
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeGroupedDistribution(layoutState:eventService:)
        )

        let groupedComponent = try view.inspect()
            .view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(GroupedDistributionComponent.self)
            .actualView()

        groupedComponent.goToNextGroup()
        XCTAssertTrue(closeActionCalled)
    }
    
    func test_goToNextOffer_with_closeOnComplete_false() throws {
        var closeActionCalled = false
        let closeOnCompleteSettings = LayoutSettings(closeOnComplete: false)
        let view = try TestPlaceHolder.make(
            layoutSettings: closeOnCompleteSettings,
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeGroupedDistribution(layoutState:eventService:)
        )
        
        let groupedComponent = try view.inspect()
            .view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(GroupedDistributionComponent.self)
            .actualView()

        groupedComponent.goToNextOffer()
        XCTAssertFalse(closeActionCalled)
    }
    
    func test_goToNextGroup_with_closeOnComplete_false() throws {
        var closeActionCalled = false
        let closeOnCompleteSettings = LayoutSettings(closeOnComplete: false)
        
        let view = try TestPlaceHolder.make(
            layoutSettings: closeOnCompleteSettings,
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeGroupedDistribution(layoutState:eventService:)
        )
        
        let groupedComponent = try view.inspect()
            .view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(GroupedDistributionComponent.self)
            .actualView()

        groupedComponent.goToNextGroup()
        XCTAssertFalse(closeActionCalled)
    }
}

@available(iOS 15.0, *)
extension LayoutSchemaViewModel {

    static func makeGroupedDistribution(
        layoutState: LayoutState,
        eventService: EventService
    ) throws -> Self {
        let slots = ModelTestData.PageModelData.withBNF().layoutPlugins?.first?.slots
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin(slots: slots!),
                                            layoutState: layoutState,
                                            eventService: eventService)
        let model = ModelTestData.GroupedDistributionData.groupedDistribution()
        return LayoutSchemaViewModel.groupDistribution(
            try transformer.getGroupedDistribution(
                groupedModel: model!, context: .outer(slots!.map(\.offer))
            )
        )
    }
}
