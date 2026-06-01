import XCTest
import SwiftUI
import ViewInspector
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15.0, *)
extension View {
    func inspectComponent<T: View>(_ type: T.Type) throws -> InspectableView<ViewType.ClassifiedView> {
        return try inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(type)
            .actualView()
            .inspect()
    }
}

@available(iOS 15.0, *)
extension DataImageCarouselViewModel {
    static func mock(
        key: String = "",
        images: [CreativeImage] = [],
        duration: Int32 = 0,
        ownStyle: [BasicStateStylingBlock<DataImageCarouselStyles>]? = nil,
        indicatorViewModel: ImageCarouselIndicatorViewModel? = nil,
        layoutState: (any LayoutStateRepresenting)? = nil,
        transition: Transition = .fadeInOut(0.3)
    ) -> DataImageCarouselViewModel {
        DataImageCarouselViewModel(
            key: key,
            images: images,
            duration: duration,
            ownStyle: ownStyle,
            indicatorViewModel: indicatorViewModel,
            layoutState: layoutState,
            transition: transition
        )
    }
}

extension CreativeImage {
    static func mock(light: String = "light", dark: String = "dark", alt: String = "", title: String = "") -> CreativeImage {
        .init(light: light, dark: dark, alt: alt, title: title)
    }
}

@available(iOS 15.0, *)
extension ImageCarouselIndicatorViewModel {
    static func mock(
        positions: Int = 2,
        duration: Int32 = 0,
        stylingProperties: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]? = nil,
        indicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]? = nil,
        seenIndicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]? = nil,
        activeIndicatorStyle: [BasicStateStylingBlock<DataImageCarouselIndicatorStyles>]? = nil,
        layoutState: (any LayoutStateRepresenting)? = nil,
        shouldDisplayProgress: Bool = false
    ) -> ImageCarouselIndicatorViewModel {
        ImageCarouselIndicatorViewModel(
            positions: positions,
            duration: duration,
            stylingProperties: stylingProperties,
            indicatorStyle: indicatorStyle,
            seenIndicatorStyle: seenIndicatorStyle,
            activeIndicatorStyle: activeIndicatorStyle,
            layoutState: layoutState,
            shouldDisplayProgress: shouldDisplayProgress
        )
    }
}

@available(iOS 15.0, *)
final class TestDataImageCarouselComponent: XCTestCase {
    func test_no_images() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.dataImageCarousel(
            .mock()
        ))
        
        let emptyView = try view.inspectComponent(DataImageCarouselComponent.self)
            .find(ViewType.EmptyView.self)
        
        XCTAssertNotNil(emptyView)
    }
    
    func test_images_rendersHSPageView() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.dataImageCarousel(
            .mock(images: [.mock(), .mock()], transition: .slideInOut(0.3))
        ))
        
        let zStack = try view.inspectComponent(DataImageCarouselComponent.self)
            .zStack()

        XCTAssertNotNil(try zStack.find(AsyncImageView.self))
        XCTAssertNotNil(try zStack.find(HSPageView<AnyView>.self))
    }
    
    func test_images_rendersOnlyAsyncImageView() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.dataImageCarousel(
            .mock(images: [.mock(), .mock()])
        ))

        let zStack = try view.inspectComponent(DataImageCarouselComponent.self)
            .zStack()

        XCTAssertNotNil(try? zStack.find(AsyncImageView.self))
        XCTAssertNil(try? zStack.find(HSPageView<AnyView>.self))
    }
    
    func test_images_indicatorViewModel_rendersOnlyAsyncImageView() throws {
        let view = TestPlaceHolder(layout: LayoutSchemaViewModel.dataImageCarousel(
            .mock(images: [.mock(), .mock()], indicatorViewModel: .mock())
        ))

        let zStack = try view.inspectComponent(DataImageCarouselComponent.self)
            .zStack()

        let vStack = try zStack.find(ViewType.VStack.self)
        XCTAssertNotNil(try? vStack[0].find(ViewType.Spacer.self))
        XCTAssertNotNil(try? vStack[1].find(ImageCarouselIndicator.self))
    }
}
