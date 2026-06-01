import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestProgressControlComponent: XCTestCase {

    func test_progress_control() throws {

        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.progressControl(try get_model()))
        
        let progressControl = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ProgressControlComponent.self)
            .actualView()
            .inspect()
            .hStack()
        
        // test custom modifier class
        let paddingModifier = try progressControl.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 5, right: 5, bottom: 5, left: 5))
        
        // test the effect of custom modifier
        let paddingMargin = try progressControl.padding()
        XCTAssertEqual(paddingMargin, EdgeInsets(top: 5.0, leading: 25.0, bottom: 13.0, trailing: 15.0))
        
        XCTAssertEqual(try progressControl.accessibilityLabel().string(), "Next")
    }

    func get_model() throws -> ProgressControlViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let progressControl = ModelTestData.ProgressControlData.progressControl()
        return try transformer.getProgressControl(styles: progressControl.styles, direction: progressControl.direction,
                                                  children: transformer.transformChildren(progressControl.children,
                                                                                          context: .outer([])))
    }
}
