import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestOffsetModifier: XCTestCase {

    func test_column_with_offset() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.column(try get_model()))
        
        let hstack = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ColumnComponent.self)
            .actualView()
            .inspect()
            .vStack()
        
        // test offset modifier
        let offsetModifier = try hstack.modifier(OffsetModifier.self).actualView()
        XCTAssertEqual(offsetModifier.offset?.x, 30)
        XCTAssertEqual(offsetModifier.offset?.y, 20)
        
        // test offset
        let offset = try hstack.offset()
        XCTAssertEqual(offset.width, 30)
        XCTAssertEqual(offset.height, 20)
        
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
