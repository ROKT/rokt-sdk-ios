import XCTest
import SwiftUI
import ViewInspector
import SnapshotTesting
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestScrollableColumn: XCTestCase {

    func test_column() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableColumn(try get_model()))

        let vstack = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableColumnComponent.self)
            .scrollView()
            .view(ColumnComponent.self)
            .actualView()
            .inspect()
            .vStack()

        // test custom modifier class
        let paddingModifier = try vstack.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 18, right: 24, bottom: 0, left: 24))

        // test the effect of custom modifier
        let padding = try vstack.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 18.0, leading: 24.0, bottom: 0.0, trailing: 24.0))

        // Test weight = 1 add maxHeight .infinity
        let flexFrame = try vstack.flexFrame()
        XCTAssertEqual(flexFrame.maxHeight, .infinity)

        // background
        let backgroundModifier = try vstack.modifier(BackgroundModifier.self)
        let backgroundStyle = try backgroundModifier.actualView().backgroundStyle

        XCTAssertEqual(backgroundStyle?.backgroundColor, ThemeColor(light: "#F5C1C4", dark: "#F5C1C4"))

        // border
        let borderModifier = try vstack.modifier(BorderModifier.self)
        let borderStyle = try borderModifier.actualView().borderStyle

        XCTAssertNil(borderStyle)

        // alignment
        let alignment = try vstack.alignment()
        XCTAssertEqual(alignment, .center)
    }

    // MARK: - Tests for ScrollableColumnComponent computed properties

    func test_scrollableColumnComponent_computedProperties_withWeight() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableColumn(try get_model()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableColumnComponent.self)
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
        XCTAssertEqual(sut.weightProperties.parent, .column)

        // When only weight is set (no maxHeight in dimensions), dimensionMaxHeight should be nil
        XCTAssertNil(sut.dimensionMaxHeight)
    }

    func test_scrollableColumnComponent_dimensionMaxHeight_prioritizedOverWeight() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableColumn(try get_model_with_max_height()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableColumnComponent.self)
            .actualView()

        // Test that both weight and maxHeight are present in the style
        XCTAssertNotNil(sut.flexStyle)
        XCTAssertEqual(sut.flexStyle?.weight, 1)
        XCTAssertNotNil(sut.dimensionStyle)
        XCTAssertEqual(sut.dimensionStyle?.maxHeight, 200)

        // Test that dimensionMaxHeight returns the dimension maxHeight value
        // This verifies that dimension maxHeight takes precedence over weight
        XCTAssertEqual(sut.dimensionMaxHeight, 200)
    }

    func test_scrollableColumnComponent_dimensionStyle_accessible() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableColumn(try get_model_with_max_height()))

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ScrollableColumnComponent.self)
            .actualView()

        // Verify dimensionStyle is accessible and contains expected values
        XCTAssertNotNil(sut.dimensionStyle)
        XCTAssertEqual(sut.dimensionStyle?.maxHeight, 200)
    }

    // MARK: - Snapshots

    func testSnapshot() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.scrollableColumn(try get_model()))
            .frame(width: 350, height: 350)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    // MARK: - Helpers

    func get_model() throws -> ColumnViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let column = ModelTestData.ColumnData.columnWithBasicText()
        return try transformer.getColumn(
            column.styles,
            children: transformer.transformChildren(column.children, context: .outer([]))
        )
    }

    func get_model_with_max_height() throws -> ColumnViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let column = ModelTestData.ColumnData.scrollableColumnWithMaxHeight()
        return try transformer.getColumn(
            column.styles,
            children: transformer.transformChildren(column.children, context: .outer([]))
        )
    }

}
