import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import SnapshotTesting

@available(iOS 15.0, *)
final class TestStaticImageComponent: XCTestCase {
    
    enum LayoutName {
        case staticImage, emptyUrl, withAlt
    }

    func test_static_image() throws {

        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.staticImage(try get_model(.staticImage)))
        
        let imageView = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticImageViewComponent.self)
            .actualView()
            .inspect()
            .find(AsyncImageView.self)
        
        // test custom modifier class
        let paddingModifier = try imageView.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 18, right: 24, bottom: 0, left: 24))
        
        // test the effect of custom modifier
        let padding = try imageView.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 18.0, leading: 24.0, bottom: 0.0, trailing: 24.0))
        
        let image = try imageView.asyncImage()
        
        XCTAssertEqual(try image.accessibilityLabel().string(), "")
        XCTAssertEqual(try image.accessibilityHidden(), true)
    }
    
    func test_static_image_empty() throws {
        
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.staticImage(try get_model(.emptyUrl)))
        
        let image = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticImageViewComponent.self)
            .actualView()

        // test custom modifiers are removed with image
        XCTAssertEqual(image.padding() as? EdgeInsets, nil)
        
    }
    
    func test_static_image_with_alt() throws {
        
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.staticImage(try get_model(.withAlt)))
        
        let image = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticImageViewComponent.self)
            .actualView()
            .inspect()
            .find(AsyncImageView.self)
            .asyncImage()

        XCTAssertEqual(try image.accessibilityLabel().string(), "image")
        XCTAssertEqual(try image.accessibilityHidden(), false)
    }
    
    func get_model(_ layoutName: LayoutName) throws -> StaticImageViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        
        switch layoutName {
        case .emptyUrl:
            return try transformer.getStaticImage(ModelTestData.StaticImageData.emptyURLImage())
        case .staticImage:
            return try transformer.getStaticImage(ModelTestData.StaticImageData.staticImage())
        case .withAlt:
            return try transformer.getStaticImage(ModelTestData.StaticImageData.withAlt())
        }
    }
}
