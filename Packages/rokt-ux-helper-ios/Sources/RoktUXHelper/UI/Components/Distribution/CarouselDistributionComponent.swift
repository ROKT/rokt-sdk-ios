import SwiftUI
import DcuiSchema

/// The CarouselDistributionComponent is a container component that enables cycling through
/// offers in a carousel-like manner.
///
/// ## Usage Location
/// This component is designed for use in outer layouts.
@available(iOS 15, *)
struct CarouselDistributionComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    var style: CarouselDistributionStyles? {
        return model.defaultStyle?.count ?? -1 > styleBreakpointIndex ? model.defaultStyle?[styleBreakpointIndex] : nil
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize

    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    let config: ComponentConfig

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState

    @GestureState private var offset: CGFloat = 0

    // states to track paging when we have multiple viewable items
    @ObservedObject var model: CarouselViewModel

    @State private var carouselHeightMap: [Int: CGFloat] = [:]
    @State private var maxHeight: CGFloat = 0

    @AccessibilityFocusState private var shouldFocusAccessibility: Bool

    var accessibilityAnnouncement: String {
        String(format: kPageAnnouncement,
               model.currentPage + 1,
               model.totalPages)
    }

    let parentOverride: ComponentParentOverride?

    var passableBackgroundStyle: BackgroundStylingProperties? {
        backgroundStyle ?? parentOverride?.parentBackgroundStyle
    }

    var styleBreakpointIndex: Int {
        let maxStyleIndex = (model.defaultStyle?.count ?? 1) - 1
        return max(min(model.breakpointIndex, maxStyleIndex), 0)
    }

    var peekThroughBreakpointIndex: Int {
        let maxPeekThroughIndex = (model.peekThroughSize.count) - 1
        return max(min(model.breakpointIndex, maxPeekThroughIndex), 0)
    }

    init(
        config: ComponentConfig,
        model: CarouselViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        styleState: Binding<StyleState>,
        parentOverride: ComponentParentOverride?
    ) {
        self.config = config
        _parentWidth = parentWidth
        _parentHeight = parentHeight
        _styleState = styleState

        self.parentOverride = parentOverride
        self.model = model
    }

    var verticalAlignment: VerticalAlignmentProperty {
        if let justifyContent = containerStyle?.alignItems?.asVerticalAlignmentProperty {
            return justifyContent
        } else if let parentAlign = parentOverride?.parentVerticalAlignment?.asVerticalAlignmentProperty {
            return parentAlign
        } else {
            return .top
        }
    }

    var horizontalAlignment: HorizontalAlignmentProperty {
        if let alignItems = containerStyle?.justifyContent?.asHorizontalAlignmentProperty {
            return alignItems
        } else if let parentAlign = parentOverride?.parentHorizontalAlignment?.asHorizontalAlignmentProperty {
            return parentAlign
        } else {
            return .start
        }
    }

    var gap: CGFloat {
        CGFloat(containerStyle?.gap ?? 0)
    }

    var gapOffset: CGFloat {
        getGapOffset()
    }

    var body: some View {
        if model.totalPages > 0 {
            GeometryReader { containerProxy in
                let peekThrough = getPeekThrough(containerProxy.size.width)
                let pageWidth = getPageWidth(width: containerProxy.size.width,
                                             peekThrough: peekThrough)

                let offerWidth = getOfferWidth(pageWidth: pageWidth,
                                               totalOffers: model.totalOffers)

                let peekThroughOffset = getPeekThroughOffset(peekThrough: peekThrough,
                                                             totalPages: model.totalPages)

                let pageOffset = CGFloat(model.currentPage) * -pageWidth
                let indexOffset = CGFloat(model.indexWithinPage) * -offerWidth

                HStack(alignment: rowPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
                       spacing: gap) {
                    ForEach(model.pages, id: \.self) { page in
                        HStack(alignment: rowPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
                               spacing: gap) {
                            build(page: page,
                                  offerWidth: offerWidth)
                        }
                        .offset(x: (containerProxy.size.width - pageWidth)/2 - peekThrough)
                    }
                }
                .offset(x: pageOffset + indexOffset + offset + peekThroughOffset + gapOffset)
                .gesture(
                    DragGesture()
                        .updating($offset, body: { value, out, _ in
                            out = value.translation.width
                        })
                        .onEnded({ value in
                            let progress = -value.translation.width/offerWidth
                            let roundProgress = Int(progress.rounded())

                            model.updateStatesOnDragEnded(roundProgress)
                        })
                )
                .clipped()
            }
            .applyLayoutModifier(verticalAlignmentProperty: verticalAlignment,
                                 horizontalAlignmentProperty: horizontalAlignment,
                                 spacing: spacingStyle,
                                 dimension: dimensionStyle,
                                 flex: flexStyle,
                                 border: borderStyle,
                                 background: backgroundStyle,
                                 parent: config.parent,
                                 parentWidth: $parentWidth,
                                 parentHeight: $parentHeight,
                                 parentOverride: nil,
                                 defaultHeight: .wrapContent,
                                 defaultWidth: .wrapContent,
                                 isContainer: true,
                                 containerType: .row,
                                 frameChangeIndex: $model.frameChangeIndex,
                                 imageLoader: model.imageLoader)
            .onLoad {
                model.setupLayoutState()
                setupLayoutState()
                shouldFocusAccessibility = true
            }
            .onChange(of: model.currentLeadingOfferIndex) { newValue in
                model.layoutState?.capturePluginViewState(offerIndex: newValue, dismiss: false)
                model.sendViewableImpressionEvents(currentLeadingOffer: newValue)
                shouldFocusAccessibility = true
            }
            .onChange(of: model.currentPage) { v in
                UIAccessibility.post(notification: .announcement, argument: accessibilityAnnouncement)
                currentPage = v
            }
            .onChange(of: model.customStateMap) { _ in
                model.layoutState?.capturePluginViewState(offerIndex: nil, dismiss: false)
            }
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    model.globalScreenSizeUpdated(newSize)
                }
            }
            .animation(.linear, value: model.currentLeadingOfferIndex)
            // workaround to set dynamic height otherwise GeometryReader fills available space
            .frame(height: getContentHeight())
        }
    }

    @State var currentPage: Int = 0

    func setupLayoutState() {
        model.layoutState?.items[LayoutState.currentProgressKey] = $currentPage
    }

    func build(page: [LayoutSchemaViewModel],
               offerWidth: CGFloat) -> some View {
        ForEach(page, id: \.self) { child in
            if let childIndex = model.children?.firstIndex(of: child) {
                LayoutSchemaComponent(config: config.updatePosition(childIndex),
                                      layout: child,
                                      parentWidth: $parentWidth,
                                      parentHeight: $carouselHeightMap[childIndex],
                                      styleState: $styleState)
                .frame(width: offerWidth)
                .readSize { size in
                    let newHeight = size.height
                    if carouselHeightMap[childIndex] != newHeight {
                        carouselHeightMap[childIndex] = newHeight
                        // Update maxHeight only if it's different to prevent infinite loops
                        let newMaxHeight = carouselHeightMap.values.max() ?? 0
                        if abs(maxHeight - newMaxHeight) > 1.0 {
                            DispatchQueue.main.async {
                                maxHeight = newMaxHeight
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityFocused($shouldFocusAccessibility)
                .accessibilityLabel(accessibilityAnnouncement)
                .onBecomingViewed { visibilityInfo in
                    if visibilityInfo.isInViewAndCorrectSize {
                        model.sendCreativeViewedEvent(currentOffer: childIndex)
                    }
                }
                .onUserInteraction {
                    model.sendCreativeViewedEvent(currentOffer: childIndex)
                }
            }
        }
    }

    func getGapOffset() -> CGFloat {
        // This calculates the gap offset to add on each drag end
        guard model.currentLeadingOfferIndex != 0, gap != 0 else { return 0 }
        if model.currentPage == model.totalPages - 1 {
            return gap - gap * CGFloat(model.indexWithinPage)
        } else {
            return gap/2 - gap * CGFloat(model.indexWithinPage)
        }
    }

    func getPeekThrough(_ width: CGFloat) -> CGFloat {
        let breakPointPeekThrough = model.peekThroughSize[peekThroughBreakpointIndex]

        // convert PeekThroughSize to actual width
        switch breakPointPeekThrough {
        case .fixed(let peekthrough):
            return CGFloat(peekthrough)
        case .percentage(let percentage):
            return width * CGFloat(percentage/100)
        }
    }

    func getPageWidth(width: CGFloat,
                      peekThrough: CGFloat) -> CGFloat {
        return width - peekThrough * 2
    }

    func getOfferWidth(pageWidth: CGFloat,
                       totalOffers: Int) -> CGFloat {
        return model.viewableItems > 1 && totalOffers > 1
        ? pageWidth/CGFloat(model.viewableItems) - gap
            : pageWidth - gap
    }

    func getPeekThroughOffset(peekThrough: CGFloat,
                              totalPages: Int) -> CGFloat {
        // This calculates the offset we require to apply peek through logic:
        // 1. 1st offer has trailing peek through width=peekThrough*2
        // 2. Last offer has leading peek through width=peekThrough*2
        // 3. In-between offers have both leading and trailing peek through width=peekThrough
        if model.viewableItems > 1 {
            return model.currentLeadingOfferIndex == 0 ? 0 : (model.currentPage == totalPages - 1 ? peekThrough * 2 : peekThrough)
        } else {
            return model.currentPage == 0 ? 0 : (model.currentPage == totalPages - 1 ? peekThrough * 2 : peekThrough)
        }
    }

    private func getContentHeight() -> CGFloat {
        let modifier = MarginModifier(spacing: spacingStyle, applyMargin: false)
        let margin = modifier.getMargin()
        let padding = modifier.getPadding()
        return maxHeight + margin.top + margin.bottom + padding.top + padding.bottom
    }
}
