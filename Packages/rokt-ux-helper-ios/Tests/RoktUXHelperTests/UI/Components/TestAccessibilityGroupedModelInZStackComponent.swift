import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper

@available(iOS 15.0, *)
final class TestAccessibilityGroupedModelInZStackComponent: XCTestCase {
    
    func test_zStackComponent_computedProperties_accessibility() throws {
        let model = try get_model()
        
        guard case .zStack(let zStackUIModel) = model else {
            XCTFail()
            return
        }
        
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.zStack(zStackUIModel))
        
        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(ZStackComponent.self)
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
        
        XCTAssertEqual(sut.accessibilityBehavior, .combine)
        
    }
    func get_model() throws -> LayoutSchemaViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let accessibilityGroup = ModelTestData.ZStackData.accessibilityGroupedZStack()
        return try transformer.getAccessibilityGrouped(child: accessibilityGroup.child, context: .outer([]))
    }
}
