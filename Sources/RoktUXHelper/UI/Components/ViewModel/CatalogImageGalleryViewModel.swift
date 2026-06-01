import Combine
import Foundation
import DcuiSchema

@available(iOS 15, *)
final class CatalogImageGalleryViewModel: ObservableObject, ScreenSizeAdaptive, Identifiable, Hashable {
    typealias Item = CatalogImageGalleryStyles

    let id: UUID = UUID()
    weak var layoutState: (any LayoutStateRepresenting)?
    weak var eventService: EventDiagnosticServicing?

    @Published var images: [DataImageViewModel] {
        didSet { clampSelectedIndex() }
    }

    @Published var selectedIndex: Int = 0

    let defaultStyle: [CatalogImageGalleryStyles]?
    let mainImageStyles: [BasicStateStylingBlock<CatalogImageGalleryStyles>]?
    let controlButtonStyles: [BasicStateStylingBlock<CatalogImageGalleryStyles>]?

    private let indicatorStyleBlocks: [BasicStateStylingBlock<BaseStyles>]?
    private let activeIndicatorStyleBlocks: [BasicStateStylingBlock<BaseStyles>]?
    private let seenIndicatorStyleBlocks: [BasicStateStylingBlock<BaseStyles>]?
    private let progressIndicatorContainerBlocks: [BasicStateStylingBlock<BaseStyles>]?

    let showIndicators: Bool
    let backwardImage: CatalogImageGalleryThemedImageUrl?
    let forwardImage: CatalogImageGalleryThemedImageUrl?
    let a11yLabel: String?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(
        images: [DataImageViewModel],
        defaultStyle: [CatalogImageGalleryStyles]?,
        mainImageStyles: [BasicStateStylingBlock<CatalogImageGalleryStyles>]?,
        controlButtonStyles: [BasicStateStylingBlock<CatalogImageGalleryStyles>]?,
        indicatorStyle: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]?,
        activeIndicatorStyle: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]?,
        seenIndicatorStyle: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]?,
        progressIndicatorContainer: [BasicStateStylingBlock<CatalogImageGalleryIndicatorStyles>]?,
        showIndicators: Bool,
        backwardImage: CatalogImageGalleryThemedImageUrl?,
        forwardImage: CatalogImageGalleryThemedImageUrl?,
        a11yLabel: String?,
        layoutState: (any LayoutStateRepresenting)?,
        eventService: EventDiagnosticServicing? = nil
    ) {
        self.layoutState = layoutState
        self.eventService = eventService
        self.images = images
        self.defaultStyle = defaultStyle
        self.mainImageStyles = mainImageStyles
        self.controlButtonStyles = controlButtonStyles
        self.indicatorStyleBlocks = indicatorStyle?.mapToBaseStyles(BaseStyles.init)
        self.activeIndicatorStyleBlocks = activeIndicatorStyle?.mapToBaseStyles(BaseStyles.init)
        self.seenIndicatorStyleBlocks = seenIndicatorStyle?.mapToBaseStyles(BaseStyles.init)
        self.progressIndicatorContainerBlocks = progressIndicatorContainer?.mapToBaseStyles(BaseStyles.init)
        self.showIndicators = showIndicators
        self.backwardImage = backwardImage
        self.forwardImage = forwardImage
        self.a11yLabel = a11yLabel
        clampSelectedIndex()
    }

    // MARK: - Image Navigation

    var selectedImage: DataImageViewModel? {
        images[safe: selectedIndex]
    }

    var canGoBackward: Bool { selectedIndex > 0 }
    var canGoForward: Bool { selectedIndex < images.count - 1 }

    func selectImage(at index: Int) {
        guard images.indices.contains(index), index != selectedIndex else { return }
        selectedIndex = index
    }

    func goBackward() {
        guard canGoBackward else { return }
        selectImage(at: selectedIndex - 1)
    }

    func goForward() {
        guard canGoForward else { return }
        selectImage(at: selectedIndex + 1)
    }

    // MARK: - Indicator Styles

    func dotStyle(for index: Int, breakpointIndex: Int) -> BaseStyles? {
        let activeStyle = activeIndicatorStyleBlocks?[safe: breakpointIndex]?.default
        let seenStyle = seenIndicatorStyleBlocks?[safe: breakpointIndex]?.default
        let indicatorStyle = indicatorStyleBlocks?[safe: breakpointIndex]?.default

        if index == selectedIndex {
            return activeStyle
        } else if index < selectedIndex {
            return seenStyle ?? indicatorStyle
        } else {
            return indicatorStyle
        }
    }

    func dotViewModel(for index: Int, breakpointIndex: Int) -> RowViewModel {
        let style = dotStyle(for: index, breakpointIndex: breakpointIndex)

        let stylingProperties = style.map {
            [
                BasicStateStylingBlock(
                    default: $0,
                    pressed: nil,
                    hovered: nil,
                    focussed: nil,
                    disabled: nil
                )
            ]
        }

        return .build(stylingProperties: stylingProperties, layoutState: layoutState)
    }

    func indicatorContainerViewModel(for breakpointIndex: Int) -> RowViewModel? {
        guard let containerBlocks = progressIndicatorContainerBlocks else { return nil }
        let children = images.indices.map { index in
            LayoutSchemaViewModel.row(dotViewModel(for: index, breakpointIndex: breakpointIndex))
        }
        return .build(children: children, stylingProperties: containerBlocks, layoutState: layoutState)
    }

    func indicatorAlignSelf(for breakpointIndex: Int) -> FlexAlignment? {
        progressIndicatorContainerBlocks?[safe: breakpointIndex]?.default.flexChild?.alignSelf
    }

    // MARK: - Event Tracking

    func handleNavButtonBackward() {
        sendScrollEvent(direction: .left, isSwipe: false)
    }

    func handleNavButtonForward() {
        sendScrollEvent(direction: .right, isSwipe: false)
    }

    func handleSwipeForward() {
        sendScrollEvent(direction: .right, isSwipe: true)
    }

    func handleSwipeBackward() {
        sendScrollEvent(direction: .left, isSwipe: true)
    }

    func handleIndicatorTap() {
        guard let catalogItem = activeCatalogItem else { return }
        eventService?.cartItemUserInteraction(
            itemId: catalogItem.catalogItemId,
            action: .ThumbnailClick,
            context: .CatalogImageGallery
        )
    }

    private var activeCatalogItem: CatalogItem? {
        layoutState?.items[LayoutState.activeCatalogItemKey] as? CatalogItem
    }

    private func sendScrollEvent(direction: ScrollDirection, isSwipe: Bool) {
        guard let catalogItem = activeCatalogItem else { return }
        let action: UserInteraction = switch (isSwipe, direction) {
        case (true, .left): .MainImageSwipeLeft
        case (true, .right): .MainImageSwipeRight
        case (false, .left): .MainImageScrollIconLeftClick
        case (false, .right): .MainImageScrollIconRightClick
        }
        eventService?.cartItemUserInteraction(
            itemId: catalogItem.catalogItemId,
            action: action,
            context: .CatalogImageGallery
        )
    }

    private enum ScrollDirection {
        case left, right
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CatalogImageGalleryViewModel, rhs: CatalogImageGalleryViewModel) -> Bool {
        lhs.id == rhs.id
    }

    private func clampSelectedIndex() {
        if images.isEmpty {
            selectedIndex = 0
            return
        }
        if selectedIndex > images.count - 1 {
            selectedIndex = images.count - 1
        }
    }
}

@available(iOS 15, *)
extension RowViewModel {
    static func build(
        children: [LayoutSchemaViewModel]? = nil,
        stylingProperties: [BasicStateStylingBlock<BaseStyles>]? = nil,
        animatableStyle: AnimationStyle? = nil,
        accessibilityGrouped: Bool = false,
        layoutState: (any LayoutStateRepresenting)? = nil,
        predicates: [WhenPredicate]? = nil,
        globalBreakPoints: BreakPoint? = nil,
        offers: [OfferModel?] = []
    ) -> RowViewModel {
        RowViewModel(
            children: children,
            stylingProperties: stylingProperties,
            animatableStyle: animatableStyle,
            accessibilityGrouped: accessibilityGrouped,
            layoutState: layoutState,
            predicates: predicates,
            globalBreakPoints: globalBreakPoints,
            offers: offers
        )
    }
}
