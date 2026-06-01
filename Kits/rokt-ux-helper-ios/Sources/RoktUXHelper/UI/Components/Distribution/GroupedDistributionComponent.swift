import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct GroupedDistributionComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    var style: GroupedDistributionStyles? {
        return model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex = 0
    @State var frameChangeIndex: Int = 0

    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    var transition: DcuiSchema.Transition? { model.transition }

    let config: ComponentConfig
    let model: GroupedDistributionViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState

    @State var currentGroup = 0
    @State private var toggleTransition = false
    @State private var currentLeadingOffer: Int

    @State var customStateMap: RoktUXCustomStateMap?

    @AccessibilityFocusState private var shouldFocusAccessibility: Bool
    var accessibilityAnnouncement: String {
        String(format: kPageAnnouncement,
               currentGroup + 1,
               model.children?.count ?? 1)
    }

    let parentOverride: ComponentParentOverride?

    var passableBackgroundStyle: BackgroundStylingProperties? {
        backgroundStyle ?? parentOverride?.parentBackgroundStyle
    }

    init(
        config: ComponentConfig,
        model: GroupedDistributionViewModel,
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
        _currentLeadingOffer = State(wrappedValue: model.initialCurrentIndex ?? 0)
        _customStateMap = State(wrappedValue: model.initialCustomStateMap ?? RoktUXCustomStateMap())
        setRecalculatedCurrentGroup()
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

    @State var viewableItems: Int = 1
    var children: [LayoutSchemaViewModel] {
        guard let children = model.children, !children.isEmpty else {
            return []
        }
        return children
    }

    var totalOffers: Int {
        children.count
    }

    var pages: [[LayoutSchemaViewModel]] {
        stride(from: 0, to: totalOffers, by: viewableItems).map {
            Array(children[$0..<$0.advanced(by: min(viewableItems, children.endIndex - $0))])
        }
    }

    var totalPages: Int {
        pages.count
    }

    var gap: CGFloat {
        CGFloat(containerStyle?.gap ?? 0)
    }

    var viewableChildren: [LayoutSchemaViewModel] {
        guard !children.isEmpty else { return [] }
        guard currentGroup < totalPages else { return [] }
        return pages[currentGroup]
    }

    func getViewableChildren() -> [LayoutSchemaViewModel] {
        guard !children.isEmpty else { return [] }
        guard currentGroup < totalPages else { return [] }
        return pages[currentGroup]
    }

    var body: some View {
        if !children.isEmpty {
            build(page: getViewableChildren())
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
                                     parentOverride: parentOverride?.updateBackground(passableBackgroundStyle),
                                     defaultHeight: .wrapContent,
                                     defaultWidth: .wrapContent,
                                     isContainer: true,
                                     frameChangeIndex: $frameChangeIndex,
                                     imageLoader: model.imageLoader)
                .onLoad {
                    registerActions()
                    shouldFocusAccessibility = true
                }
                .accessibilityElement(children: .contain)
                .accessibilityFocused($shouldFocusAccessibility)
                .accessibilityLabel(accessibilityAnnouncement)
                .onChange(of: currentLeadingOffer) { newValue in
                    model.layoutState?.capturePluginViewState(offerIndex: newValue, dismiss: false)
                    model.sendViewableImpressionEvents(viewableItems: viewableItems,
                                                       currentLeadingOffer: newValue)
                    shouldFocusAccessibility = true
                    UIAccessibility.post(notification: .announcement,
                                         argument: accessibilityAnnouncement)
                }
                .onChange(of: customStateMap) { _ in
                    model.layoutState?.capturePluginViewState(offerIndex: nil, dismiss: false)
                }
                .onChange(of: globalScreenSize.width) { newSize in
                    DispatchQueue.main.async {
                        breakpointIndex = model.updateBreakpointIndex(for: newSize)
                        frameChangeIndex += 1
                        setViewableItemsForBreakpoint(newSize)
                        // set viewableItems first then send impressions for offers based on viewableItems
                        // duplicated events will be filtered out
                        model.sendViewableImpressionEvents(viewableItems: viewableItems,
                                                           currentLeadingOffer: currentLeadingOffer)
                    }
                }
        }
    }

    func build(page: [LayoutSchemaViewModel]) -> some View {
        return VStack(alignment: columnPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
                      spacing: gap) {
            ForEach(page, id: \.self) { child in
                if let childIndex = children.firstIndex(of: child) {
                    LayoutSchemaComponent(config: config.updatePosition(childIndex),
                                          layout: child,
                                          parentWidth: $parentWidth,
                                          parentHeight: $parentHeight,
                                          styleState: $styleState,
                                          parentOverride: parentOverride?.updateBackground(passableBackgroundStyle))
                    .opacity(getOpacity())
                    .onLoad {
                        toggleTransition = true
                    }
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
    }

    func registerActions() {
        model.layoutState?.actionCollection[.nextOffer] = goToNextOffer
        model.layoutState?.actionCollection[.progressControlNext] = goToNextGroup
        model.layoutState?.actionCollection[.progressControlPrevious] = goToPreviousGroup
        model.layoutState?.actionCollection[.toggleCustomState] = toggleCustomState

        model.setupBindings(
            currentProgress: $currentGroup,
            totalItems: model.children?.count ?? 0,
            viewableItems: $viewableItems,
            customStateMap: $customStateMap
        )
    }

    func goToNextGroup(_: Any? = nil) {
        if currentGroup + 1 < totalPages {
            transitionToNextGroup()
        } else if model.layoutState?.closeOnComplete() == true {
            // when on last page AND closeOnComplete is true
            if case .embeddedLayout = model.layoutState?.layoutType() {
                model.sendDismissalCollapsedEvent()
            } else {
                model.sendDismissalNoMoreOfferEvent()
            }

            exit()
        }
    }

    func goToPreviousGroup(_: Any? = nil) {
        if currentGroup > 0 {
            transitionToPreviousGroup()
        }
    }

    // note this action only applies when viewableItems = 1
    func goToNextOffer(_: Any? = nil) {
        guard viewableItems == 1 else { return }
        if currentGroup + 1 < model.children?.count ?? 0 {
            transitionToNextGroup()
        } else if model.layoutState?.closeOnComplete() == true {
            // when on last offer AND closeOnComplete is true
            if case .embeddedLayout = model.layoutState?.layoutType() {
                model.sendDismissalCollapsedEvent()
            } else {
                model.sendDismissalNoMoreOfferEvent()
            }

            exit()
        }
    }

    func exit() {
        model.layoutState?.actionCollection[.close](nil)
    }

    func transitionIn() {
        switch transition {
        case .fadeInOut(let settings):
            let duration = Double(settings.duration)/1000/2
            withAnimation(
                .easeIn(duration: Double(duration))
            ) {
                toggleTransition = true
            }
        default:
            return
        }
    }

    func transitionToNextGroup() {
        switch transition {
        case .fadeInOut(let settings):
            let duration = Double(settings.duration)/1000/2
            withAnimation(.easeOut(duration: duration)) {
                toggleTransition = false
            }

            // Wait to complete fade out of previous offer
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                incrementCurrentGroup()
            }
        default:
            incrementCurrentGroup()
        }
    }

    func transitionToPreviousGroup() {
        switch transition {
        case .fadeInOut(let settings):
            let duration = Double(settings.duration)/1000/2
            withAnimation(.easeOut(duration: duration)) {
                toggleTransition = false
            }

            // Wait to complete fade out of previous offer
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                decrementCurrentGroup()
            }
        default:
            decrementCurrentGroup()
        }
    }

    private func toggleCustomState(_ customStateId: Any?) {
        var mutatingCustomStateMap: RoktUXCustomStateMap = customStateMap ?? RoktUXCustomStateMap()
        self.customStateMap = mutatingCustomStateMap.toggleValueFor(customStateId)
    }

    func getOpacity() -> Double {
        switch transition {
        case .fadeInOut:
            return toggleTransition ? 1 : 0
        default:
            return 1
        }
    }

    func setViewableItemsForBreakpoint(_ newSize: CGFloat?) {
        let maxViewableItemsIndex = (model.viewableItems.count) - 1

        let currentBreakpointIndex = model.getGlobalBreakpointIndex(newSize)

        let index = max(min(currentBreakpointIndex, maxViewableItemsIndex), 0)
        let previousLeadingOffer = pages[currentGroup].first

        viewableItems = Int(model.viewableItems[index])

        // navigate to the currect page
        navigateToBreakPointPage(previousLeadingOffer)
    }

    func navigateToBreakPointPage(_ currentLeadingOffer: LayoutSchemaViewModel?) {
        if let currentLeadingOffer {
            var newPageIndex = 0
            pages.forEach { page in
                if page.contains(currentLeadingOffer) {
                    currentGroup = newPageIndex
                }
                newPageIndex += 1
            }
        }
    }

    func setRecalculatedCurrentGroup() {
        if currentLeadingOffer >= 0 {
            self.currentGroup = Int(floor(Double(currentLeadingOffer + 1/viewableItems)))
        }
    }

    private func incrementCurrentGroup() {
        currentGroup += 1
        currentLeadingOffer = currentGroup * viewableItems
    }

    private func decrementCurrentGroup() {
        currentGroup -= 1
        currentLeadingOffer = currentGroup * viewableItems
    }
}
