import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestCarouselDistributionComponent: XCTestCase {

    func test_carousel() throws {
        var closeActionCalled = false
        let view = try TestPlaceHolder.make(
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeCarousel(layoutState:eventService:)
        )

        let carouselComponent = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CarouselDistributionComponent.self)
            .actualView()

        let geometryReader = try carouselComponent.inspect().geometryReader()

        // test custom modifier class
        let paddingModifier = try geometryReader.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 3, right: 4, bottom: 5, left: 6))

        // test the effect of custom modifier
        let padding = try geometryReader.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 4.0))

        // Test accessibility label on the carousel item (LayoutSchemaComponent)
        let carouselItem = try geometryReader.find(LayoutSchemaComponent.self)
        XCTAssertEqual(try carouselItem.accessibilityLabel().string(), "Page 1 of 1")

        carouselComponent.model.goToNextOffer(nil)
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
            layoutMaker: LayoutSchemaViewModel.makeCarousel(layoutState:eventService:)
        )

        let carouselComponent = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CarouselDistributionComponent.self)
            .actualView()

        carouselComponent.model.goToNextOffer(nil)
        XCTAssertFalse(closeActionCalled)
    }
}

@available(iOS 15.0, *)
extension LayoutSchemaViewModel {

    static func makeCarousel(
        layoutState: LayoutState,
        eventService: EventService
    ) throws -> Self {
        let slots = ModelTestData.PageModelData.withBNF().layoutPlugins?.first?.slots
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin(slots: slots!),
                                            layoutState: layoutState,
                                            eventService: eventService)
        let model = ModelTestData.CarouselData.carousel()
        return LayoutSchemaViewModel.carousel(try transformer.getCarousel(carouselModel: model!, context: .outer([])))
    }
}
