import XCTest
import SwiftUI
import ViewInspector
import SnapshotTesting
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestCreativeResponseComponent: XCTestCase {

    func test_creative_response() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.creativeResponse(try get_model()))
        
        let creativeResponse = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CreativeResponseComponent.self)
            .actualView()
            .inspect()
            .hStack()
        
        // test custom modifier class
        let paddingModifier = try creativeResponse.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 10, right: 10, bottom: 10, left: 10))
        
        // test the effect of custom modifier
        let padding = try creativeResponse.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0))
        
        // background
        let backgroundModifier = try creativeResponse.modifier(BackgroundModifier.self)
        let backgroundStyle = try backgroundModifier.actualView().backgroundStyle
        
        XCTAssertEqual(backgroundStyle?.backgroundColor, ThemeColor(light: "#000000", dark: nil))
    }
    
    func test_creativeResponse_computedProperties_usesModelProperties() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.creativeResponse(try get_model()))
        
        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CreativeResponseComponent.self)
            .actualView()
        
        let defaultStyle = sut.model.defaultStyle?[0]
        
        XCTAssertEqual(sut.style, defaultStyle)
        XCTAssertEqual(sut.containerStyle, defaultStyle?.container)
        XCTAssertEqual(sut.dimensionStyle, defaultStyle?.dimension)
        XCTAssertEqual(sut.flexStyle, defaultStyle?.flexChild)
        XCTAssertEqual(sut.borderStyle, defaultStyle?.border)
        XCTAssertEqual(sut.backgroundStyle, defaultStyle?.background)
        XCTAssertEqual(sut.passableBackgroundStyle, defaultStyle?.background)
        
        XCTAssertEqual(sut.verticalAlignment, .top)
        XCTAssertEqual(sut.horizontalAlignment, .center)
        
        XCTAssertEqual(sut.verticalAlignmentOverride, .center)
        XCTAssertEqual(sut.horizontalAlignment, .center)
    }
    
    // MARK: - Snapshots

    func testSnapshot() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.creativeResponse(try get_model()))
            .frame(width: 350, height: 200)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    // MARK: - Helpers

    func get_model() throws -> CreativeResponseViewModel {
        let transformer = LayoutTransformer(layoutPlugin: get_mock_layout_plugin())
        let creativeResponse = ModelTestData.CreativeResponseData.positive()
        return try transformer.getCreativeResponseUIModel(responseKey: creativeResponse?.responseKey ?? "",
                                                          openLinks: nil,
                                                          styles: creativeResponse?.styles,
                                                          children: transformer.transformChildren(creativeResponse?.children,
                                                                                                  context: .outer([])),
                                                          offer: .mock())
    }
}
