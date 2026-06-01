//
//  TestCatalogImageGalleryComponent.swift
//  RoktUXHelperTests
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import XCTest
import SwiftUI
import ViewInspector
import SnapshotTesting
@testable import RoktUXHelper
import DcuiSchema

// MARK: - Component Tests

final class TestCatalogImageGalleryComponent: XCTestCase {

    // MARK: - Rendering

    func test_catalogImageGallery_rendersWithCorrectImageCount() throws {
        let view = try TestPlaceHolder.make(
            layoutMaker: { layoutState, eventService in
                try LayoutSchemaViewModel.makeCatalogImageGallery(
                    layoutState: layoutState,
                    eventService: eventService
                )
            }
        )

        let component = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CatalogImageGalleryComponent.self)

        let sut = try component.actualView()

        XCTAssertEqual(sut.model.images.count, 3)
        XCTAssertEqual(sut.model.selectedIndex, 0)
    }

    // MARK: - Snapshots

    func testSnapshot_fullFeatured() throws {
        let view = try TestPlaceHolder.make(
            layoutMaker: { layoutState, eventService in
                try LayoutSchemaViewModel.makeCatalogImageGalleryForSnapshot(
                    layoutState: layoutState,
                    eventService: eventService,
                    includeNavigationButtons: true
                )
            }
        )
        .frame(width: 390, height: 500)

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(of: hostingController, as: .image(on: snapshotDevice))
    }

    // MARK: - Image Navigation

    func test_goForward_advancesIndex() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        XCTAssertEqual(vm.selectedIndex, 0)

        vm.goForward()
        XCTAssertEqual(vm.selectedIndex, 1)

        vm.goForward()
        XCTAssertEqual(vm.selectedIndex, 2)
    }

    func test_goForward_doesNotExceedLastIndex() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.goForward()
        vm.goForward()
        vm.goForward()

        XCTAssertEqual(vm.selectedIndex, 2)
    }

    func test_goBackward_decrementsIndex() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.goForward()
        vm.goForward()
        XCTAssertEqual(vm.selectedIndex, 2)

        vm.goBackward()
        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func test_goBackward_doesNotGoBelowZero() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.goBackward()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_selectImage_updatesIndex() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.selectImage(at: 2)
        XCTAssertEqual(vm.selectedIndex, 2)
        XCTAssertTrue(vm.selectedImage === vm.images[2])
    }

    func test_selectImage_ignoresOutOfBoundsIndex() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.selectImage(at: 10)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_selectImage_ignoresSameIndex() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.selectImage(at: 0)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - canGoForward / canGoBackward

    func test_canGoForward_trueAtStart() throws {
        let vm = try makeCatalogImageGalleryViewModel()
        XCTAssertTrue(vm.canGoForward)
    }

    func test_canGoForward_falseAtEnd() throws {
        let vm = try makeCatalogImageGalleryViewModel()
        vm.selectImage(at: 2)
        XCTAssertFalse(vm.canGoForward)
    }

    func test_canGoBackward_falseAtStart() throws {
        let vm = try makeCatalogImageGalleryViewModel()
        XCTAssertFalse(vm.canGoBackward)
    }

    func test_canGoBackward_trueAfterAdvancing() throws {
        let vm = try makeCatalogImageGalleryViewModel()
        vm.goForward()
        XCTAssertTrue(vm.canGoBackward)
    }

    // MARK: - Indicators

    func test_showIndicators_defaultTrue() throws {
        let vm = try makeCatalogImageGalleryViewModel()
        XCTAssertTrue(vm.showIndicators)
    }

    func test_showIndicators_respectsExplicitFalse() throws {
        let vm = try makeCatalogImageGalleryViewModel(showIndicators: false)
        XCTAssertFalse(vm.showIndicators)
    }

    func test_indicatorOverlay_hiddenWithoutContainer() throws {
        let view = try TestPlaceHolder.make { layoutState, eventService in
            try LayoutSchemaViewModel.makeCatalogImageGallery(
                layoutState: layoutState,
                eventService: eventService,
                includeIndicatorContainer: false
            )
        }

        let component = try view.inspect().view(TestPlaceHolder.self)
            .view(EmbeddedComponent.self)
            .vStack()[0]
            .view(LayoutSchemaComponent.self)
            .view(CatalogImageGalleryComponent.self)

        let rowComponents = component.findAll(ViewType.View<RowComponent>.self)
        XCTAssertEqual(rowComponents.count, 0)
    }

    func test_indicatorAlignSelf_readsFromStyles() throws {
        let vm = try makeCatalogImageGalleryViewModel(indicatorAlignSelf: .flexEnd)
        XCTAssertEqual(vm.indicatorAlignSelf(for: 0), .flexEnd)
    }

    // MARK: - Navigation Images

    func test_backwardImage_isSet() throws {
        let vm = try makeCatalogImageGalleryViewModel(includeNavImages: true)
        XCTAssertNotNil(vm.backwardImage)
        XCTAssertEqual(vm.backwardImage?.light, "https://example.com/back-light.png")
    }

    func test_forwardImage_isSet() throws {
        let vm = try makeCatalogImageGalleryViewModel(includeNavImages: true)
        XCTAssertNotNil(vm.forwardImage)
        XCTAssertEqual(vm.forwardImage?.light, "https://example.com/fwd-light.png")
    }

    func test_navImages_nilByDefault() throws {
        let vm = try makeCatalogImageGalleryViewModel()
        XCTAssertNil(vm.backwardImage)
        XCTAssertNil(vm.forwardImage)
    }

    // MARK: - Event Tracking

    func test_handleSwipeForward_sendsEvent() throws {
        let context = try makeViewModelWithEventTracking()

        context.vm.handleSwipeForward()

        XCTAssertTrue(context.eventService.cartItemUserInteractionCalled)
    }

    func test_handleSwipeBackward_sendsEvent() throws {
        let context = try makeViewModelWithEventTracking()

        context.vm.handleSwipeBackward()

        XCTAssertTrue(context.eventService.cartItemUserInteractionCalled)
    }

    func test_handleNavButtonForward_sendsEvent() throws {
        let context = try makeViewModelWithEventTracking()

        context.vm.handleNavButtonForward()

        XCTAssertTrue(context.eventService.cartItemUserInteractionCalled)
    }

    func test_handleNavButtonBackward_sendsEvent() throws {
        let context = try makeViewModelWithEventTracking()

        context.vm.handleNavButtonBackward()

        XCTAssertTrue(context.eventService.cartItemUserInteractionCalled)
    }

    func test_handleIndicatorTap_sendsEvent() throws {
        let context = try makeViewModelWithEventTracking()

        context.vm.handleIndicatorTap()

        XCTAssertTrue(context.eventService.cartItemUserInteractionCalled)
    }

    // MARK: - Index Clamping

    func test_selectedIndex_clampsWhenImagesReduced() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.selectImage(at: 2)
        XCTAssertEqual(vm.selectedIndex, 2)

        vm.images = Array(vm.images.prefix(2))
        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func test_selectedIndex_resetsToZeroWhenImagesEmpty() throws {
        let vm = try makeCatalogImageGalleryViewModel()

        vm.selectImage(at: 1)
        vm.images = []

        XCTAssertEqual(vm.selectedIndex, 0)
    }
}

// MARK: - GalleryGestureView Tests

final class GalleryGestureViewTests: XCTestCase {

    func test_coordinator_handleTap_callsOnTapClosure() {
        var capturedPoint: CGPoint?
        let coordinator = GalleryGestureView.Coordinator(onTap: { point in
            capturedPoint = point
        }, onPanChanged: nil, onPanEnded: nil)

        let mockView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let expectedLocation = CGPoint(x: 75, y: 125)

        let mockGesture = MockTapGestureRecognizer(
            target: coordinator,
            action: #selector(GalleryGestureView.Coordinator.handleTap(_:))
        )
        mockGesture.mockLocation = expectedLocation
        mockGesture.mockView = mockView

        coordinator.handleTap(mockGesture)

        XCTAssertNotNil(capturedPoint)
        XCTAssertEqual(capturedPoint, expectedLocation)
    }

    func test_makeCoordinator_returnsCoordinator() {
        let sut = GalleryGestureView(onTap: { _ in }, onPanChanged: nil, onPanEnded: nil)

        let coordinator = sut.makeCoordinator()

        XCTAssertNotNil(coordinator)
        XCTAssertNotNil(coordinator)
    }

    func test_coordinator_horizontalPanLocksOutSimultaneousScroll() {
        let coordinator = GalleryGestureView.Coordinator(onTap: { _ in }, onPanChanged: nil, onPanEnded: nil)
        let pan = MockPanGestureRecognizer(
            target: coordinator,
            action: #selector(GalleryGestureView.Coordinator.handlePan(_:))
        )
        pan.mockTranslation = CGPoint(x: 40, y: 5)
        pan.mockVelocity = CGPoint(x: 300, y: 40)

        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(pan))
        XCTAssertFalse(coordinator.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()))
    }

    func test_coordinator_verticalPanDoesNotBeginGalleryGesture() {
        let coordinator = GalleryGestureView.Coordinator(onTap: { _ in }, onPanChanged: nil, onPanEnded: nil)
        let pan = MockPanGestureRecognizer(
            target: coordinator,
            action: #selector(GalleryGestureView.Coordinator.handlePan(_:))
        )
        pan.mockTranslation = CGPoint(x: 5, y: 40)
        pan.mockVelocity = CGPoint(x: 40, y: 300)

        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan))
    }

    func test_coordinator_verticalDominantDiagonalPanDoesNotBeginGalleryGesture() {
        let coordinator = GalleryGestureView.Coordinator(onTap: { _ in }, onPanChanged: nil, onPanEnded: nil)
        let pan = MockPanGestureRecognizer(
            target: coordinator,
            action: #selector(GalleryGestureView.Coordinator.handlePan(_:))
        )
        pan.mockTranslation = CGPoint(x: 80, y: 100)
        pan.mockVelocity = CGPoint(x: 80, y: 100)

        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(pan))
        XCTAssertTrue(coordinator.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()))
    }
}

// MARK: - GallerySwipePolicy Tests

final class GallerySwipePolicyTests: XCTestCase {

    func test_shortSwipe_doesNotChangePage() {
        let resolution = GallerySwipePolicy.targetPage(
            currentPage: 1,
            pages: 3,
            width: 390,
            translation: -30,
            velocity: -120
        )

        XCTAssertEqual(resolution.page, 1)
        XCTAssertNil(resolution.direction)
    }

    func test_naturalImageSwipe_advancesPage() {
        let resolution = GallerySwipePolicy.targetPage(
            currentPage: 0,
            pages: 3,
            width: 390,
            translation: -100,
            velocity: -120
        )

        XCTAssertEqual(resolution.page, 1)
        XCTAssertEqual(resolution.direction, .forward)
    }

    func test_fastFlick_advancesPageWithShortTranslation() {
        let resolution = GallerySwipePolicy.targetPage(
            currentPage: 0,
            pages: 3,
            width: 390,
            translation: -20,
            velocity: -650
        )

        XCTAssertEqual(resolution.page, 1)
        XCTAssertEqual(resolution.direction, .forward)
    }

    func test_swipeAtBounds_clampsPage() {
        let forwardAtEnd = GallerySwipePolicy.targetPage(
            currentPage: 2,
            pages: 3,
            width: 390,
            translation: -100,
            velocity: -120
        )
        let backwardAtStart = GallerySwipePolicy.targetPage(
            currentPage: 0,
            pages: 3,
            width: 390,
            translation: 100,
            velocity: 120
        )

        XCTAssertEqual(forwardAtEnd.page, 2)
        XCTAssertEqual(forwardAtEnd.direction, .forward)
        XCTAssertEqual(backwardAtStart.page, 0)
        XCTAssertEqual(backwardAtStart.direction, .backward)
    }

    func test_horizontalDominantDiagonalPan_canBegin() {
        XCTAssertTrue(GallerySwipePolicy.shouldBeginPan(velocity: CGPoint(x: 120, y: 100)))
    }

    func test_verticalDominantDiagonalPan_doesNotBegin() {
        XCTAssertFalse(GallerySwipePolicy.shouldBeginPan(velocity: CGPoint(x: 80, y: 100)))
    }

    func test_equalDiagonalPan_prioritizesVerticalScroll() {
        XCTAssertFalse(GallerySwipePolicy.shouldBeginPan(velocity: CGPoint(x: 100, y: 100)))
    }

    func test_axisLock_usesInitialHorizontalTranslationBeforeVerticalVelocity() {
        let axis = GallerySwipePolicy.lockedAxis(
            translation: CGPoint(x: 40, y: 5),
            velocity: CGPoint(x: 20, y: 500)
        )

        XCTAssertEqual(axis, .horizontal)
    }

    func test_axisLock_usesInitialVerticalTranslationBeforeHorizontalVelocity() {
        let axis = GallerySwipePolicy.lockedAxis(
            translation: CGPoint(x: 5, y: 40),
            velocity: CGPoint(x: 500, y: 20)
        )

        XCTAssertEqual(axis, .vertical)
    }
}

// MARK: - Mock Helpers

private class MockTapGestureRecognizer: UITapGestureRecognizer {
    var mockLocation: CGPoint = .zero
    var mockView: UIView?

    override func location(in view: UIView?) -> CGPoint {
        return mockLocation
    }
}

private class MockPanGestureRecognizer: UIPanGestureRecognizer {
    var mockTranslation: CGPoint = .zero
    var mockVelocity: CGPoint = .zero

    override func translation(in view: UIView?) -> CGPoint {
        return mockTranslation
    }

    override func velocity(in view: UIView?) -> CGPoint {
        return mockVelocity
    }
}

// MARK: - Factory Helpers

private extension TestCatalogImageGalleryComponent {

    func makeCatalogImageGalleryViewModel(
        imageCount: Int = 3,
        showIndicators: Bool = true,
        includeIndicatorContainer: Bool = true,
        indicatorAlignSelf: FlexAlignment? = nil,
        includeNavImages: Bool = false,
        mockEventService: MockEventService? = nil
    ) throws -> CatalogImageGalleryViewModel {
        let catalogItem = CatalogItem.mock(
            images: makeMockImages(count: imageCount)
        )

        let layoutState = LayoutState()
        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState,
            eventService: get_mock_event_processor()
        )

        let indicatorContainer: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]?
        if includeIndicatorContainer {
            indicatorContainer = [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>(
                default: CatalogImageGalleryIndicatorStyles(
                    container: ContainerStylingProperties(
                        justifyContent: .center,
                        alignItems: .center,
                        shadow: nil,
                        overflow: nil,
                        gap: 4,
                        blur: nil
                    ),
                    background: nil,
                    border: nil,
                    dimension: nil,
                    flexChild: indicatorAlignSelf.map {
                        FlexChildStylingProperties(weight: nil, order: nil, alignSelf: $0)
                    },
                    spacing: nil
                ),
                pressed: nil,
                hovered: nil,
                focussed: nil,
                disabled: nil
            )]
        } else {
            indicatorContainer = nil
        }

        let galleryStyles = CatalogImageGalleryStyles(
            container: nil,
            background: nil,
            border: nil,
            dimension: nil,
            flexChild: nil,
            spacing: nil,
            text: nil
        )

        let elements = CatalogImageGalleryElements(
            own: [
                BasicStateStylingBlock(
                    default: galleryStyles,
                    pressed: nil,
                    hovered: nil,
                    focussed: nil,
                    disabled: nil
                )
            ],
            mainImage: nil,
            controlButton: nil,
            indicator: nil,
            activeIndicator: nil,
            seenIndicator: nil,
            progressIndicatorContainer: indicatorContainer
        )

        let backwardImage: CatalogImageGalleryThemedImageUrl? = includeNavImages
            ? CatalogImageGalleryThemedImageUrl(
                light: "https://example.com/back-light.png",
                dark: "https://example.com/back-dark.png"
            )
            : nil
        let forwardImage: CatalogImageGalleryThemedImageUrl? = includeNavImages
            ? CatalogImageGalleryThemedImageUrl(
                light: "https://example.com/fwd-light.png",
                dark: "https://example.com/fwd-dark.png"
            )
            : nil

        let galleryModel = CatalogImageGalleryModel<WhenPredicate>(
            styles: LayoutStyle(elements: elements, conditionalTransitions: nil),
            showIndicators: showIndicators,
            backwardImage: backwardImage,
            forwardImage: forwardImage,
            a11yLabel: nil
        )

        let vm = try transformer.getCatalogImageGallery(
            model: galleryModel,
            context: .inner(.addToCart(catalogItem))
        )

        if let mockEventService {
            vm.eventService = mockEventService
        }

        return vm
    }

    struct EventTrackingContext {
        let vm: CatalogImageGalleryViewModel
        let eventService: MockEventService
        let layoutState: LayoutState
    }

    func makeViewModelWithEventTracking() throws -> EventTrackingContext {
        let mockEventService = MockEventService()
        let catalogItem = CatalogItem.mock(
            images: makeMockImages(count: 3)
        )

        let layoutState = LayoutState()
        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let images = catalogItem.images
            .sorted { $0.key < $1.key }
            .compactMap { DataImageViewModel(
                image: $0.value,
                defaultStyle: nil,
                pressedStyle: nil,
                hoveredStyle: nil,
                disabledStyle: nil,
                layoutState: layoutState
            ) }

        let vm = CatalogImageGalleryViewModel(
            images: images,
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
            eventService: mockEventService
        )

        return EventTrackingContext(vm: vm, eventService: mockEventService, layoutState: layoutState)
    }

    func makeMockImages(count: Int) -> [String: CreativeImage] {
        var images: [String: CreativeImage] = [:]
        for i in 0..<count {
            images["catalogItemImage\(i)"] = CreativeImage(
                light: "https://example.com/gallery-\(i).png",
                dark: nil,
                alt: "Gallery \(i)",
                title: nil
            )
        }
        return images
    }
}

// MARK: - LayoutSchemaViewModel Factory

extension LayoutSchemaViewModel {
    static func makeCatalogImageGallery(
        layoutState: LayoutState,
        eventService: EventService,
        includeIndicatorContainer: Bool = true,
        indicatorAlignSelf: FlexAlignment? = nil
    ) throws -> Self {
        let catalogItem = CatalogItem.mock(
            images: [
                "catalogItemImage0": CreativeImage(
                    light: "https://example.com/gallery-0.png",
                    dark: nil,
                    alt: "Gallery 0",
                    title: nil
                ),
                "catalogItemImage1": CreativeImage(
                    light: "https://example.com/gallery-1.png",
                    dark: nil,
                    alt: "Gallery 1",
                    title: nil
                ),
                "catalogItemImage2": CreativeImage(
                    light: "https://example.com/gallery-2.png",
                    dark: nil,
                    alt: "Gallery 2",
                    title: nil
                )
            ]
        )

        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState,
            eventService: eventService
        )

        let indicatorContainer: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]?
        if includeIndicatorContainer {
            indicatorContainer = [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>(
                default: CatalogImageGalleryIndicatorStyles(
                    container: ContainerStylingProperties(
                        justifyContent: .center,
                        alignItems: .center,
                        shadow: nil,
                        overflow: nil,
                        gap: 4,
                        blur: nil
                    ),
                    background: nil,
                    border: nil,
                    dimension: nil,
                    flexChild: indicatorAlignSelf.map {
                        FlexChildStylingProperties(weight: nil, order: nil, alignSelf: $0)
                    },
                    spacing: nil
                ),
                pressed: nil,
                hovered: nil,
                focussed: nil,
                disabled: nil
            )]
        } else {
            indicatorContainer = nil
        }

        let galleryStyles = CatalogImageGalleryStyles(
            container: nil,
            background: nil,
            border: nil,
            dimension: nil,
            flexChild: nil,
            spacing: nil,
            text: nil
        )

        let elements = CatalogImageGalleryElements(
            own: [
                BasicStateStylingBlock(
                    default: galleryStyles,
                    pressed: nil,
                    hovered: nil,
                    focussed: nil,
                    disabled: nil
                )
            ],
            mainImage: nil,
            controlButton: nil,
            indicator: nil,
            activeIndicator: nil,
            seenIndicator: nil,
            progressIndicatorContainer: indicatorContainer
        )

        let galleryModel = CatalogImageGalleryModel<WhenPredicate>(
            styles: LayoutStyle(elements: elements, conditionalTransitions: nil),
            showIndicators: true,
            backwardImage: nil,
            forwardImage: nil,
            a11yLabel: nil
        )

        return LayoutSchemaViewModel.catalogImageGallery(
            try transformer.getCatalogImageGallery(
                model: galleryModel,
                context: .inner(.addToCart(catalogItem))
            )
        )
    }

    // MARK: - Snapshot Data URIs

    private static let redPNG =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OQQ0AIAwAsZlCAv4NTAwyuEeTCujsuUHzfaClpaWlpdWgpaVVoKWlVaClpVWgpaVVoKWlVaClpVUQbT3M8Aycbkr8QgAAAABJRU5ErkJggg=="
    private static let greenPNG =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQklEQVR4nO3OQQ0AIAwAscnBCFpnExnco0kFdM7eoPk+0NLS0tLSatDS0irQ0tIq0NLSKtDS0irQ0tIq0NLSKoi2HnBBh+eymnQ8AAAAAElFTkSuQmCC"
    private static let bluePNG =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAARElEQVR4nO3OMQ0AMAwDsPIu+I7A/uSwZACe2WuUH2hpaWlpaXXID7S0tLS0tDrkB1paWlpaWh3yAy0tLS0trQ75wc8Dq3ZsO5dwNeUAAAAASUVORK5CYII="
    private static let leftArrowPNG =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAaUlEQVR4nM3PQQoAIAhE0e5/6WoZYaXjF5qt8B+2Bq3PUS0zXgb0ZaVxHNjjKGDFMeAUR4BbPA284inAE5cBb1wCIvEwEI3/94GCSEAEkQEvkgI8SBp4IQhwQzDghKCAheDAjpQAK2LdBgy8nX9MqQgaAAAAAElFTkSuQmCC"
    private static let rightArrowPNG =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAaklEQVR4nM3PMQoAIAxDUe9/6ergIGK1aVIwa+E/2pozG/NuktlcOVCG2LZyQI6cACniATLkBkiQF0AjEYBCokAaQYAUggIw8tUHcBwBUvEokI5HACr+Auj4DZDEPUAWPwHS+A7I4yvAdjqikJ1/9GT7CgAAAABJRU5ErkJggg=="

    private static func snapshotImages(count: Int) -> [String: CreativeImage] {
        let allImages = [
            ("catalogItemImage0", redPNG, "Red"),
            ("catalogItemImage1", greenPNG, "Green"),
            ("catalogItemImage2", bluePNG, "Blue")
        ]
        var images: [String: CreativeImage] = [:]
        for i in 0..<min(count, allImages.count) {
            let (key, uri, alt) = allImages[i]
            images[key] = CreativeImage(light: uri, dark: uri, alt: alt, title: nil)
        }
        return images
    }

    // swiftlint:disable function_body_length
    static func makeCatalogImageGalleryForSnapshot(
        layoutState: LayoutState,
        eventService: EventService,
        imageCount: Int = 3,
        showIndicators: Bool = true,
        includeNavigationButtons: Bool = false,
        indicatorAlignSelf: FlexAlignment = .flexEnd,
        galleryBorderRadius: Float? = nil,
        galleryPadding: String? = nil
    ) throws -> Self {
        let catalogItem = CatalogItem.mock(images: snapshotImages(count: imageCount))
        layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState,
            eventService: eventService
        )

        // Indicator container
        let indicatorContainer: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]? = showIndicators
            ? [BasicStateStylingBlock(
                default: CatalogImageGalleryIndicatorStyles(
                    container: ContainerStylingProperties(
                        justifyContent: .center, alignItems: .center,
                        shadow: nil, overflow: nil, gap: 8, blur: nil
                    ),
                    background: BackgroundStylingProperties(
                        backgroundColor: ThemeColor(light: "#99000000", dark: "#99FFFFFF"), backgroundImage: nil
                    ),
                    border: BorderStylingProperties(borderRadius: 50, borderColor: nil, borderWidth: nil, borderStyle: nil),
                    dimension: nil,
                    flexChild: FlexChildStylingProperties(weight: nil, order: nil, alignSelf: indicatorAlignSelf),
                    spacing: SpacingStylingProperties(padding: "6px 12px", margin: "0px 0px 12px 0px", offset: nil)
                ),
                pressed: nil, hovered: nil, focussed: nil, disabled: nil
            )]
            : nil

        // Dot styles
        let indicatorDotStyle: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]? = showIndicators
            ? [BasicStateStylingBlock(
                default: CatalogImageGalleryIndicatorStyles(
                    container: nil,
                    background: BackgroundStylingProperties(
                        backgroundColor: ThemeColor(light: "#99FFFFFF", dark: "#99555555"), backgroundImage: nil
                    ),
                    border: BorderStylingProperties(borderRadius: 50, borderColor: nil, borderWidth: nil, borderStyle: nil),
                    dimension: DimensionStylingProperties(
                        minWidth: nil, maxWidth: nil, width: .fixed(8),
                        minHeight: nil, maxHeight: nil, height: .fixed(8), rotateZ: nil
                    ),
                    flexChild: nil, spacing: nil
                ),
                pressed: nil, hovered: nil, focussed: nil, disabled: nil
            )]
            : nil

        let activeDotStyle: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]? = showIndicators
            ? [BasicStateStylingBlock(
                default: CatalogImageGalleryIndicatorStyles(
                    container: nil,
                    background: BackgroundStylingProperties(
                        backgroundColor: ThemeColor(light: "#FFFFFF", dark: "#000000"), backgroundImage: nil
                    ),
                    border: BorderStylingProperties(borderRadius: 50, borderColor: nil, borderWidth: nil, borderStyle: nil),
                    dimension: DimensionStylingProperties(
                        minWidth: nil, maxWidth: nil, width: .fixed(10),
                        minHeight: nil, maxHeight: nil, height: .fixed(10), rotateZ: nil
                    ),
                    flexChild: nil, spacing: nil
                ),
                pressed: nil, hovered: nil, focussed: nil, disabled: nil
            )]
            : nil

        // Control button styles (for nav buttons)
        let controlButton: [BasicStateStylingBlock<CatalogImageGalleryStyles>]? = includeNavigationButtons
            ? [BasicStateStylingBlock(
                default: CatalogImageGalleryStyles(
                    container: nil,
                    background: BackgroundStylingProperties(
                        backgroundColor: ThemeColor(light: "#00000080", dark: "#FFFFFF80"), backgroundImage: nil
                    ),
                    border: BorderStylingProperties(borderRadius: 20, borderColor: nil, borderWidth: nil, borderStyle: nil),
                    dimension: nil, flexChild: nil,
                    spacing: SpacingStylingProperties(padding: "8px", margin: nil, offset: nil),
                    text: TextStylingProperties(
                        textColor: nil,
                        fontSize: 20,
                        fontFamily: nil,
                        fontWeight: nil,
                        lineHeight: nil,
                        horizontalTextAlign: nil,
                        baselineTextAlign: nil,
                        fontStyle: nil,
                        textTransform: nil,
                        letterSpacing: nil,
                        textDecoration: nil,
                        lineLimit: nil
                    )
                ),
                pressed: nil, hovered: nil, focussed: nil, disabled: nil
            )]
            : nil

        // Gallery own styles
        let borderStyle: BorderStylingProperties? = galleryBorderRadius.map {
            BorderStylingProperties(
                borderRadius: $0,
                borderColor: ThemeColor(light: "#DDDDDD", dark: "#444444"),
                borderWidth: "1",
                borderStyle: nil
            )
        }
        let spacingStyle: SpacingStylingProperties? = galleryPadding.map {
            SpacingStylingProperties(padding: $0, margin: nil, offset: nil)
        }

        let galleryStyles = CatalogImageGalleryStyles(
            container: nil,
            background: BackgroundStylingProperties(
                backgroundColor: ThemeColor(light: "#F5F5F5", dark: "#1A1A1A"), backgroundImage: nil
            ),
            border: borderStyle,
            dimension: nil, flexChild: nil,
            spacing: spacingStyle,
            text: nil
        )

        let elements = CatalogImageGalleryElements(
            own: [BasicStateStylingBlock(default: galleryStyles, pressed: nil, hovered: nil, focussed: nil, disabled: nil)],
            mainImage: nil,
            controlButton: controlButton,
            indicator: indicatorDotStyle,
            activeIndicator: activeDotStyle,
            seenIndicator: nil,
            progressIndicatorContainer: indicatorContainer
        )

        let backwardImage: CatalogImageGalleryThemedImageUrl? = includeNavigationButtons
            ? CatalogImageGalleryThemedImageUrl(light: leftArrowPNG, dark: leftArrowPNG)
            : nil
        let forwardImage: CatalogImageGalleryThemedImageUrl? = includeNavigationButtons
            ? CatalogImageGalleryThemedImageUrl(light: rightArrowPNG, dark: rightArrowPNG)
            : nil

        let galleryModel = CatalogImageGalleryModel<WhenPredicate>(
            styles: LayoutStyle(elements: elements, conditionalTransitions: nil),
            showIndicators: showIndicators,
            backwardImage: backwardImage,
            forwardImage: forwardImage,
            a11yLabel: "Product gallery"
        )

        return LayoutSchemaViewModel.catalogImageGallery(
            try transformer.getCatalogImageGallery(
                model: galleryModel,
                context: .inner(.addToCart(catalogItem))
            )
        )
    }
    // swiftlint:enable function_body_length
}
