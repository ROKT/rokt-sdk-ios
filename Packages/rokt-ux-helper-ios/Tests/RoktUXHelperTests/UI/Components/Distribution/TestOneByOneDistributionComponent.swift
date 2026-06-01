import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema
import SnapshotTesting

@available(iOS 15.0, *)
final class TestOneByOneDistributionComponent: XCTestCase {

    func test_one_by_one() throws {
        var closeActionCalled = false
        let view = try TestPlaceHolder.make(
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeOneByOne(layoutState:eventService:)
        )
        let oneByOneComponent = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(OneByOneDistributionComponent.self)
            .actualView()

        let group = try oneByOneComponent
            .inspect()
            .group()

        let oneByOne = try group
            .find(LayoutSchemaComponent.self)

        // test custom modifier class
        let paddingModifier = try oneByOne.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 3, right: 4, bottom: 5, left: 6))

        // test the effect of custom modifier
        let padding = try oneByOne.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 3.0, leading: 6.0, bottom: 5.0, trailing: 4.0))

        XCTAssertEqual(oneByOneComponent.accessibilityAnnouncement, "Offer 1 of 1")
        XCTAssertThrowsError(try group.accessibilityLabel())

        oneByOneComponent.goToNextOffer()
        XCTAssertTrue(closeActionCalled)
    }

    func test_goToNextOffer_with_closeOnComplete_false() throws {
        var closeActionCalled = false
        var SignalResponseCalled = false

        let closeOnCompleteSettings = LayoutSettings(closeOnComplete: false)

        let view = try TestPlaceHolder.make(
            layoutSettings: closeOnCompleteSettings,
            eventHandler: { event in
                if event.eventType == .SignalDismissal {
                    closeActionCalled = true
                } else if event.eventType == .SignalResponse {
                    SignalResponseCalled = true
                }
            },
            layoutMaker: LayoutSchemaViewModel.makeOneByOne(layoutState:eventService:)
        )
        let oneByOneComponent = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(OneByOneDistributionComponent.self)
            .actualView()

        XCTAssertFalse(SignalResponseCalled)

        oneByOneComponent.goToNextOffer()
        XCTAssertFalse(closeActionCalled)
        XCTAssertFalse(SignalResponseCalled)
    }

    func testEmbeddedOneByOne() {
//        withSnapshotTesting(diffTool: .ksdiff) {
//            waitForViewController("embedded_onebyone") { testViewController in
//                assertSnapshot(of: testViewController, as: .image(on: .iPhone13Pro(.portrait)))
//            }
//        }
    }
}

@available(iOS 15.0, *)
extension LayoutSchemaViewModel {

    static func makeOneByOne(
        layoutState: LayoutState,
        eventService: EventService
    ) throws -> Self {
        let slots = ModelTestData.PageModelData.withBNF().layoutPlugins?.first?.slots
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin(slots: slots!),
                                            layoutState: layoutState,
                                            eventService: eventService)
        let model = ModelTestData.OneByOneData.oneByOne()
        return LayoutSchemaViewModel.oneByOne(try transformer.getOneByOne(
            oneByOneModel: model!,
            context: .outer(slots!.map(\.offer))
        ))
    }
}
