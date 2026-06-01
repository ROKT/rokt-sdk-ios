import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestImageCarouselIndicator: XCTestCase {
    func test_noStyles_emptyHStack() throws {
        let styleState = Binding<StyleState>(wrappedValue: .default)
        let parentWidth = Binding<CGFloat?>(wrappedValue: 0.0)
        let parentHeight = Binding<CGFloat?>(wrappedValue: 0.0)
        let globalScreenSize = GlobalScreenSize()
        
        let view = ImageCarouselIndicator(
            config: ComponentConfig(parent: .root, position: 0),
            model: .mock(),
            styleState: styleState,
            parentWidth: parentWidth,
            parentHeight: parentHeight,
            frameChangeIndex: 0,
            parentOverride: nil
        )
        .environmentObject(globalScreenSize)
        ViewHosting.host(view: view)
        
        XCTAssertNotNil(view)
        let hstack = try view.inspect().hStack()
        XCTAssertNotNil(hstack)
        XCTAssertEqual(hstack.count, 1)
    }
    
    func test_withStyles_rowsAvailable() throws {
        let styleState = Binding<StyleState>(wrappedValue: .default)
        let parentWidth = Binding<CGFloat?>(wrappedValue: 0.0)
        let parentHeight = Binding<CGFloat?>(wrappedValue: 0.0)
        let globalScreenSize = GlobalScreenSize()
        
        let view = ImageCarouselIndicator(
            config: ComponentConfig(parent: .root, position: 0),
            model: .mock(activeIndicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>(
                default: .init(
                    container: nil,
                    background: nil,
                    border: nil,
                    dimension: nil,
                    flexChild: nil,
                    spacing: nil
                ),
                pressed: nil,
                hovered: nil,
                focussed: nil,
                disabled: nil
            )]),
            styleState: styleState,
            parentWidth: parentWidth,
            parentHeight: parentHeight,
            frameChangeIndex: 0,
            parentOverride: nil
        )
        .environmentObject(globalScreenSize)
        ViewHosting.host(view: view)
        
        XCTAssertNotNil(view)
        let forEach = try view.inspect().hStack().forEach(0)
        XCTAssertNotNil(forEach)
        XCTAssertEqual(forEach.count, 2)
    }
}
