import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct ProgressIndicatorComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let config: ComponentConfig
    let model: ProgressIndicatorViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    @Binding var currentIndex: Int
    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex: Int = 0
    @State var frameChangeIndex: Int = 0

    let parentOverride: ComponentParentOverride?

    var style: ProgressIndicatorStyles? {
        return model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
    }
    var containerStyle: ContainerStylingProperties? { style?.container }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    var passableBackgroundStyle: BackgroundStylingProperties? {
        backgroundStyle ?? parentOverride?.parentBackgroundStyle
    }

    var verticalAlignmentOverride: VerticalAlignment? {
        containerStyle?.justifyContent?.asVerticalAlignment.vertical
    }
    var horizontalAlignmentOverride: HorizontalAlignment? {
        containerStyle?.alignItems?.asHorizontalAlignment.horizontal
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

    var startIndex: Int {
        // ensure startIndex is a valid positive integer
        guard let startPosition = model.startPosition,
              startPosition > 0
        else {
            return 0
        }
        // -1 for index as "startPosition" starts at 1 like indicator position
        return Int(startPosition) - 1
    }

    @Binding var viewableItems: Int
    var totalItems = 0
    var totalPages: Int {
        return Int(ceil(Double(totalItems)/Double(viewableItems)))
    }
    var accessibilityAnnouncement: String {
        String(format: kProgressIndicatorAnnouncement,
               currentIndex + 1,
               totalPages > 1 ? totalPages : 1)
    }

    private var isAccessibilityHidden: Bool {
        model.accessibilityHidden ?? false
    }

    private var hasValidBinding: Bool {
        switch model.dataBinding {
        case .state(let stateString):
            return !stateString.isEmpty
        case .value(let valueString):
            return !valueString.isEmpty
        }
    }

    init(
        config: ComponentConfig,
        model: ProgressIndicatorViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        parentOverride: ComponentParentOverride?
    ) {
        self.config = config
        self.model = model

        _parentWidth = parentWidth
        _parentHeight = parentHeight

        self.parentOverride = parentOverride

        _currentIndex = model.currentIndex
        totalItems = model.totalOffer
        _viewableItems = model.viewableItems
    }

    var body: some View {
        if currentIndex >= startIndex, hasValidBinding {
            createContainer()
                .applyLayoutModifier(
                    verticalAlignmentProperty: verticalAlignment,
                    horizontalAlignmentProperty: horizontalAlignment,
                    spacing: spacingStyle,
                    dimension: dimensionStyle,
                    flex: flexStyle,
                    border: borderStyle,
                    background: backgroundStyle,
                    container: containerStyle,
                    parent: config.parent,
                    parentWidth: $parentWidth,
                    parentHeight: $parentHeight,
                    parentOverride: parentOverride?.updateBackground(passableBackgroundStyle),
                    verticalAlignmentOverride: verticalAlignmentOverride,
                    horizontalAlignmentOverride: horizontalAlignmentOverride,
                    defaultHeight: .wrapContent,
                    defaultWidth: .wrapContent,
                    isContainer: true,
                    containerType: .row,
                    frameChangeIndex: $frameChangeIndex,
                    imageLoader: model.imageLoader
                )
                .readSize(spacing: spacingStyle) { size in
                    availableWidth = size.width
                    availableHeight = size.height
                }
                .onChange(of: globalScreenSize.width) { newSize in
                    DispatchQueue.main.async {
                        // update breakpoint index
                        let index = min(model.layoutState?.getGlobalBreakpointIndex(newSize) ?? 0,
                                        (model.defaultStyle?.count ?? 1) - 1)
                        breakpointIndex = index >= 0 ? index : 0
                        frameChangeIndex += 1
                    }
                }
        } else {
            EmptyView()
        }
    }

    func createContainer() -> some View {
        return HStack(alignment: rowPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems),
                      spacing: CGFloat(containerStyle?.gap ?? 0)) {
            ForEach((startIndex..<totalPages), id: \.self) { index in
                let isSeenIndex = index < currentIndex
                let isActiveIndex = index == currentIndex
                let style = isSeenIndex ? model.seenIndicatorStyle : (
                    isActiveIndex ? model.activeIndicatorStyle :
                        model.indicatorStyle
                )

                let breakpointStyle = style?.count ?? -1 > breakpointIndex ? style?[breakpointIndex] : nil
                let model = ProgressIndicatorComponent.createAndBindRichTextUIModel(
                    value: "\(index)",
                    dataBinding: model.dataBinding,
                    defaultStyle: style,
                    layoutState: model.layoutState,
                    eventService: model.eventService,
                    imageLoader: model.imageLoader
                )
                RichTextComponent(config: config.updateParent(.row),
                                  model: model,
                                  parentWidth: $availableWidth,
                                  parentHeight: $availableHeight,
                                  parentOverride:
                                    ComponentParentOverride(
                                        parentVerticalAlignment:
                                            rowPerpendicularAxisAlignment(
                                                alignItems: breakpointStyle?.container?.alignItems ?? containerStyle?.alignItems
                                            ),
                                        parentHorizontalAlignment:
                                            rowPrimaryAxisAlignment(
                                                justifyContent: breakpointStyle?.container?.justifyContent ??
                                                                containerStyle?.justifyContent
                                            ).asHorizontalType,
                                        parentBackgroundStyle: passableBackgroundStyle,
                                        stretchChildren: containerStyle?.alignItems == .stretch
                                    ),
                                  borderStyle: breakpointStyle?.border)
                                  // overrides default text color with indicator style's text color
                .foregroundColor(hex: breakpointStyle?.text?.textColor?.getAdaptiveColor(colorScheme))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityAnnouncement)
        .accessibilityHidden(isAccessibilityHidden)
    }

    private static func createAndBindRichTextUIModel(
        value: String?,
        dataBinding: DataBinding<String>,
        defaultStyle: [IndicatorStyles]?,
        layoutState: (any LayoutStateRepresenting)?,
        eventService: EventDiagnosticServicing?,
        imageLoader: RoktUXImageLoader?
    ) -> RichTextViewModel {
        let model = RichTextViewModel(
            value: value,
            defaultStyle: toTextStyleModel(defaultStyle),
            linkStyle: nil,
            openLinks: nil,
            stateDataExpansionClosure: ProgressIndicatorViewModel.performDataExpansion,
            layoutState: layoutState,
            eventService: eventService
        )

        model.updateDataBinding(dataBinding: dataBinding)

        return model
    }

    private static func toTextStyleModel(_ styles: [IndicatorStyles]?) -> [RichTextStyle]? {
        guard let styles else { return nil }
        var richTextStyles = [RichTextStyle]()

        styles.forEach { style in
            richTextStyles.append(RichTextStyle(dimension: style.dimension,
                                                flexChild: style.flexChild,
                                                spacing: style.spacing,
                                                background: style.background,
                                                text: style.text))
        }
        return richTextStyles
    }
}
