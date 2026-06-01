import XCTest
import DcuiSchema
@testable import RoktUXHelper

@available(iOS 15, *)
final class CatalogImageGalleryViewModelTests: XCTestCase {

    // MARK: - Selection

    func test_selectedImage_defaultsToFirst() {
        let first = makeImageVM()
        let second = makeImageVM()

        let viewModel = makeViewModel(images: [first, second])

        XCTAssertTrue(viewModel.selectedImage === first)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_selectImage_updatesSelectedIndex() {
        let viewModel = makeViewModel(imageCount: 3)

        viewModel.selectImage(at: 2)
        XCTAssertEqual(viewModel.selectedIndex, 2)
    }

    func test_selectImage_outOfBoundsIsIgnored() {
        let viewModel = makeViewModel(imageCount: 2)

        viewModel.selectImage(at: 5)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_selectImage_sameIndexIsIgnored() {
        let viewModel = makeViewModel(imageCount: 3)
        viewModel.selectImage(at: 0)
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    // MARK: - Navigation

    func test_goForward_advancesIndex() {
        let viewModel = makeViewModel(imageCount: 3)

        viewModel.goForward()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func test_goBackward_decrementsIndex() {
        let viewModel = makeViewModel(imageCount: 3)
        viewModel.selectImage(at: 2)

        viewModel.goBackward()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func test_goForward_atLastIndex_doesNotAdvance() {
        let viewModel = makeViewModel(imageCount: 2)
        viewModel.selectImage(at: 1)

        viewModel.goForward()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func test_goBackward_atFirstIndex_doesNotDecrement() {
        let viewModel = makeViewModel(imageCount: 2)

        viewModel.goBackward()
        XCTAssertEqual(viewModel.selectedIndex, 0)
    }

    func test_canGoForward_trueWhenNotAtEnd() {
        let viewModel = makeViewModel(imageCount: 3)
        XCTAssertTrue(viewModel.canGoForward)
    }

    func test_canGoForward_falseAtEnd() {
        let viewModel = makeViewModel(imageCount: 2)
        viewModel.selectImage(at: 1)
        XCTAssertFalse(viewModel.canGoForward)
    }

    func test_canGoBackward_falseAtStart() {
        let viewModel = makeViewModel(imageCount: 3)
        XCTAssertFalse(viewModel.canGoBackward)
    }

    func test_canGoBackward_trueWhenNotAtStart() {
        let viewModel = makeViewModel(imageCount: 3)
        viewModel.selectImage(at: 1)
        XCTAssertTrue(viewModel.canGoBackward)
    }

    // MARK: - Event Tracking

    func test_handleNavButtonForward_sendsUserInteractionEvent() {
        let layoutState = LayoutState()
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "img-item")
        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let viewModel = makeViewModel(imageCount: 3, layoutState: layoutState, eventService: eventService)

        viewModel.handleNavButtonForward()

        XCTAssertTrue(eventService.cartItemUserInteractionCalled)
    }

    func test_handleSwipeForward_sendsUserInteractionEvent() {
        let layoutState = LayoutState()
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "img-item")
        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let viewModel = makeViewModel(imageCount: 3, layoutState: layoutState, eventService: eventService)

        viewModel.handleSwipeForward()

        XCTAssertTrue(eventService.cartItemUserInteractionCalled)
    }

    func test_handleIndicatorTap_sendsUserInteractionEvent() {
        let layoutState = LayoutState()
        let eventService = MockEventService()
        let catalogItem = CatalogItem.mock(catalogItemId: "img-item")
        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let viewModel = makeViewModel(imageCount: 3, layoutState: layoutState, eventService: eventService)

        viewModel.handleIndicatorTap()

        XCTAssertTrue(eventService.cartItemUserInteractionCalled)
    }

    // MARK: - Helpers

    private func makeImageVM() -> DataImageViewModel {
        DataImageViewModel(
            image: nil,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            layoutState: nil
        )
    }

    private func makeViewModel(
        imageCount: Int = 0,
        images: [DataImageViewModel]? = nil,
        layoutState: LayoutState? = nil,
        eventService: EventDiagnosticServicing? = nil
    ) -> CatalogImageGalleryViewModel {
        let imgs = images ?? (0..<imageCount).map { _ in makeImageVM() }

        return CatalogImageGalleryViewModel(
            images: imgs,
            defaultStyle: nil,
            mainImageStyles: nil,
            controlButtonStyles: nil,
            indicatorStyle: nil,
            activeIndicatorStyle: nil,
            seenIndicatorStyle: nil,
            progressIndicatorContainer: nil,
            showIndicators: true,
            backwardImage: nil,
            forwardImage: nil,
            a11yLabel: nil,
            layoutState: layoutState,
            eventService: eventService
        )
    }
}
