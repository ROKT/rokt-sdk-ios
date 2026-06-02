import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestBorderModifier: XCTestCase {

    func test_column_with_multi_dimension_border() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.column(try get_model()))
        
        let hstack = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ColumnComponent.self)
            .actualView()
            .inspect()
            .vStack()
        
        // test border modifier
        let borderModifier = try hstack.modifier(BorderModifier.self).actualView()
        XCTAssertEqual(borderModifier.borderWidth, FrameAlignmentProperty(top: 2, right: 1, bottom: 2, left: 1))
        XCTAssertEqual(borderModifier.borderColor, ThemeColor(light: "#000000", dark: "#000000"))
        XCTAssertEqual(borderModifier.borderRadius, 10)
        XCTAssertEqual(borderModifier.borderWidth.defaultWidth(), 1)
    }

    func get_model() throws -> ColumnViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let column = ModelTestData.ColumnData.columnWithOffset()
        return try transformer.getColumn(
            column.styles,
            children: transformer.transformChildren(column.children, context: .outer([]))
        )
    }

}
