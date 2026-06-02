import XCTest
import SwiftUI
import ViewInspector
import SnapshotTesting
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestToggleButtonComponent: XCTestCase {

    func test_toggleButton_styles() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.toggleButton(try get_model()))
        
        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ToggleButtonComponent.self)
            .actualView()
        
        let model = sut.model
        
        XCTAssertEqual(sut.style, model.defaultStyle?[0])
        XCTAssertEqual(sut.dimensionStyle, model.defaultStyle?[0].dimension)
        XCTAssertEqual(sut.flexStyle, model.defaultStyle?[0].flexChild)
        XCTAssertEqual(sut.backgroundStyle, model.defaultStyle?[0].background)
        XCTAssertEqual(sut.spacingStyle, model.defaultStyle?[0].spacing)
        
        XCTAssertEqual(sut.verticalAlignment, .top)
        XCTAssertEqual(sut.horizontalAlignment, .center)
        
        let toggleButton = try sut.inspect().hStack()
        
        // test the effect of custom modifier
        let backgroundModifier = try toggleButton.modifier(BackgroundModifier.self)
        let backgroundStyle = try backgroundModifier.actualView().backgroundStyle
        
        XCTAssertEqual(backgroundStyle?.backgroundColor, ThemeColor(light: "#FFFFFF", dark: "#000000"))
    }

    // MARK: - Snapshots

    func testSnapshot() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.toggleButton(try get_snapshot_model()))
            .frame(width: 350, height: 200)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    // MARK: - Helpers

    func get_model() throws -> ToggleButtonViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let model = ModelTestData.ToggleButtonData.basicToggleButton()
        return try transformer.getToggleButton(customStateKey: model.customStateKey,
                                               styles: model.styles,
                                               children: transformer.transformChildren(model.children, context: .outer([])))
    }

    func get_snapshot_model() throws -> ToggleButtonViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let model = ModelTestData.ToggleButtonData.toggleButtonWithLabel()
        return try transformer.getToggleButton(customStateKey: model.customStateKey,
                                               styles: model.styles,
                                               children: transformer.transformChildren(model.children, context: .outer([])))
    }
}
