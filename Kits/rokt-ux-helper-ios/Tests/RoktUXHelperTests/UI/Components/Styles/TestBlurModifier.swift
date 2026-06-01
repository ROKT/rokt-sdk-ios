import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestBlurModifier: XCTestCase {

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
        
        // test blur modifier
        let blurModifier = try hstack.modifier(BlurModifier.self).actualView()
        XCTAssertEqual(blurModifier.blur, 5)
        
        // test blur
        let blur = try hstack.blur()
        XCTAssertEqual(blur.radius, 5)
        
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
