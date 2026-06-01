import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestScrollableRow: XCTestCase {

    func test_row() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableRow(try get_model()))

        let hstack = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableRowComponent.self)
            .scrollView()
            .view(RowComponent.self)
            .actualView()
            .inspect()
            .hStack()

        XCTAssertEqual(hstack.count, 1)

        // test custom modifier class
        let paddingModifier = try hstack.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 18, right: 24, bottom: 0, left: 24))

        // test the effect of custom modifier
        let padding = try hstack.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 18.0, leading: 24.0, bottom: 0.0, trailing: 24.0))

        // background
        let backgroundModifier = try hstack.modifier(BackgroundModifier.self)
        let backgroundStyle = try backgroundModifier.actualView().backgroundStyle

        XCTAssertEqual(backgroundStyle?.backgroundColor, ThemeColor(light: "#F5C1C4", dark: "#F5C1C4"))

        // border
        let borderModifier = try hstack.modifier(BorderModifier.self)
        let borderStyle = try borderModifier.actualView().borderStyle

        XCTAssertNil(borderStyle)

        // alignment
        let alignment = try hstack.alignment()
        XCTAssertEqual(alignment, .center)

        // frame
        let flexFrame = try hstack.flexFrame()
        XCTAssertEqual(flexFrame.minHeight, 24)
        XCTAssertEqual(flexFrame.maxHeight, 24)
        XCTAssertEqual(flexFrame.minWidth, 140)
        XCTAssertEqual(flexFrame.maxWidth, 140)

    }

    func test_rowComponent_computedProperties_usesModelProperties() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableRow(try get_model()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableRowComponent.self)
            .scrollView()
            .view(RowComponent.self)
            .actualView()

        let defaultStyle = sut.model.defaultStyle?[0]

        XCTAssertEqual(sut.style, defaultStyle)

        XCTAssertEqual(sut.containerStyle, defaultStyle?.container)
        XCTAssertEqual(sut.dimensionStyle, defaultStyle?.dimension)
        XCTAssertEqual(sut.flexStyle, defaultStyle?.flexChild)
        XCTAssertEqual(sut.backgroundStyle, defaultStyle?.background)
        XCTAssertEqual(sut.spacingStyle, defaultStyle?.spacing)
        XCTAssertEqual(sut.borderStyle, defaultStyle?.border)

        XCTAssertEqual(sut.passableBackgroundStyle, defaultStyle?.background)

        XCTAssertEqual(sut.verticalAlignment, .center)
        XCTAssertEqual(sut.horizontalAlignment, .center)

        XCTAssertEqual(sut.accessibilityBehavior, .contain)
    }

    // MARK: - Tests for ScrollableRowComponent computed properties

    func test_scrollableRowComponent_computedProperties_withWeight() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableRow(try get_model_with_max_width()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableRowComponent.self)
            .actualView()

        // Test computed properties
        XCTAssertNotNil(sut.style)
        XCTAssertNotNil(sut.containerStyle)
        XCTAssertNotNil(sut.flexStyle)
        XCTAssertEqual(sut.flexStyle?.weight, 1)

        // Test alignment properties
        XCTAssertEqual(sut.verticalAlignment, .center)
        XCTAssertEqual(sut.horizontalAlignment, .center)

        // Test weightProperties
        XCTAssertEqual(sut.weightProperties.weight, 1)
        XCTAssertEqual(sut.weightProperties.parent, .row)
    }

    func test_scrollableRowComponent_dimensionMaxWidth_prioritizedOverWeight() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableRow(try get_model_with_max_width()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableRowComponent.self)
            .actualView()

        // Test that both weight and maxWidth are present in the style
        XCTAssertNotNil(sut.flexStyle)
        XCTAssertEqual(sut.flexStyle?.weight, 1)
        XCTAssertNotNil(sut.dimensionStyle)
        XCTAssertEqual(sut.dimensionStyle?.maxWidth, 200)

        // Test that dimensionMaxWidth returns the dimension maxWidth value
        // This verifies that dimension maxWidth takes precedence over weight
        XCTAssertEqual(sut.dimensionMaxWidth, 200)
    }

    func test_scrollableRowComponent_dimensionStyle_accessible() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableRow(try get_model_with_max_width()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableRowComponent.self)
            .actualView()

        // Verify dimensionStyle is accessible and contains expected values
        XCTAssertNotNil(sut.dimensionStyle)
        XCTAssertEqual(sut.dimensionStyle?.maxWidth, 200)
    }

    func test_scrollableRowComponent_dimensionMaxWidth_nilWhenNoDimensionMaxWidth() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableRow(try get_model()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableRowComponent.self)
            .actualView()

        // When no maxWidth is set in dimensions, dimensionMaxWidth should be nil
        // (even though fixed width/height might be set)
        XCTAssertNil(sut.dimensionMaxWidth)
    }

    func get_model() throws -> RowViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let row = ModelTestData.RowData.rowWithBasicText()
        return try transformer.getRow(row.styles, children: transformer.transformChildren(row.children, context: .outer([])))
    }

    func get_model_with_max_width() throws -> RowViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let row = ModelTestData.RowData.scrollableRowWithMaxWidth()
        return try transformer.getRow(row.styles, children: transformer.transformChildren(row.children, context: .outer([])))
    }
}
