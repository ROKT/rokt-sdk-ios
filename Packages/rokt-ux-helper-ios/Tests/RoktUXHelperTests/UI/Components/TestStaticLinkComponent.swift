import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
final class TestStaticLinkComponent: XCTestCase {
    var stubComponent: MockUXHelper!
    
    override func setUpWithError() throws {
        self.stubComponent = MockUXHelper()
    }

    func test_static_link() throws {

        let view = try TestPlaceHolder.make(
            eventDelegate: stubComponent,
            layoutMaker: LayoutSchemaViewModel.makeStaticLink(layoutState:eventService:)
        )

        let staticLink = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticLinkComponent.self)
            .actualView()
            .inspect()
            .hStack()

        // test custom modifier class
        let paddingModifier = try staticLink.modifier(PaddingModifier.self)
        XCTAssertEqual(try paddingModifier.actualView().padding, FrameAlignmentProperty(top: 13, right: 14, bottom: 15, left: 16))
        
        // test the effect of custom modifier
        let padding = try staticLink.padding()
        XCTAssertEqual(padding, EdgeInsets(top: 13.0, leading: 16.0, bottom: 15.0, trailing: 14.0))
    }
    
    func test_staticLink_computedProperties_usesModelProperties() throws {
        let view = try TestPlaceHolder.make(
            eventDelegate: stubComponent,
            layoutMaker: LayoutSchemaViewModel.makeStaticLink(layoutState:eventService:)
        )

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticLinkComponent.self)
            .actualView()
        
        let model = sut.model
        
        XCTAssertEqual(sut.style, model.defaultStyle?[0])
        XCTAssertEqual(sut.dimensionStyle, model.defaultStyle?[0].dimension)
        XCTAssertEqual(sut.flexStyle, model.defaultStyle?[0].flexChild)
        XCTAssertEqual(sut.backgroundStyle, model.defaultStyle?[0].background)
        XCTAssertEqual(sut.spacingStyle, model.defaultStyle?[0].spacing)
        
        XCTAssertEqual(sut.verticalAlignment, .top)
        XCTAssertEqual(sut.horizontalAlignment, .center)
        XCTAssertNotNil(model.layoutState)
    }
    
    func test_tapGesture_shouldTriggerLinkhandler() throws {
        let view = try TestPlaceHolder.make(
            eventDelegate: stubComponent,
            layoutMaker: LayoutSchemaViewModel.makeStaticLink(layoutState:eventService:)
        )

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticLinkComponent.self)
            .actualView()

        XCTAssertFalse(stubComponent.roktEvents.contains(.OpenUrl))
        
        try sut.inspect().find(ViewType.HStack.self).callOnTapGesture()
        
        XCTAssertTrue(stubComponent.roktEvents.contains(.OpenUrl))
    }
    
    func test_longPressGesture_shouldUpdatePressedStyle() throws {
        let view = try TestPlaceHolder.make(
            eventDelegate: stubComponent,
            layoutMaker: LayoutSchemaViewModel.makeStaticLink(layoutState:eventService:)
        )

        let sut = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(StaticLinkComponent.self)
            .actualView()
        
        let model = sut.model
        
        try sut.inspect().find(ViewType.HStack.self).callOnTapGesture()
        
        XCTAssertEqual(sut.style, model.pressedStyle?[0])
    }
}

@available(iOS 15.0, *)
extension LayoutSchemaViewModel {

    static func makeStaticLink(
        layoutState: LayoutState,
        eventService: EventService
    ) throws -> Self {
        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState, 
            eventService: eventService
        )
        let model = ModelTestData.StaticLinkData.staticLink()
        return LayoutSchemaViewModel.staticLink(
            try transformer.getStaticLink(src: model.src,
                                          open: model.open,
                                          styles: model.styles,
                                          children: transformer.transformChildren(model.children, context: .outer([])))
        )
    }
}
