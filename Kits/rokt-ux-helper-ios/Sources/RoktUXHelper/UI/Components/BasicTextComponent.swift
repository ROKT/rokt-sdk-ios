import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct BasicTextComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    @SwiftUI.Environment(\.sizeCategory) var sizeCategory

    var style: BasicTextStyle? { model.currentStylingProperties }
    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    var lineLimit: Int? {
        guard let lineLimit = style?.text?.lineLimit else { return nil }
        return Int(lineLimit)
    }
    var lineHeight: CGFloat {
        guard let lineHeight = style?.text?.lineHeight,
              let fontLineHeight = style?.text?.styledUIFont?.lineHeight
        else {
            return 0
        }
        return CGFloat(lineHeight) - fontLineHeight
    }

    var lineHeightPadding: CGFloat {
        guard let lineHeight = style?.text?.lineHeight,
              let fontLineHeight = style?.text?.styledUIFont?.lineHeight,
              CGFloat(lineHeight) > fontLineHeight
        else {
            return 0
        }
        return (CGFloat(lineHeight) - fontLineHeight)/2
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize

    let config: ComponentConfig
    @ObservedObject var model: BasicTextViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?

    @Binding var styleState: StyleState

    @Binding var currentIndex: Int
    @Binding var viewableItems: Int

    var totalOffers: Int
    var totalPages: Int {
        return Int(ceil(Double(totalOffers)/Double(viewableItems)))
    }

    var stateReplacedValue: String {
        TextComponentBNFHelper.replaceStates(model.boundValue,
                                             currentOffer: "\(currentIndex + 1)",
                                             totalOffers: "\(totalPages)")
    }

    let parentOverride: ComponentParentOverride?

    let expandsToContainerOnSelfAlign: Bool

    var verticalAlignment: VerticalAlignmentProperty {
        parentOverride?.parentVerticalAlignment?.asVerticalAlignmentProperty ?? .top
    }

    var horizontalAlignment: HorizontalAlignmentProperty {
        if let textAlign = style?.text?.horizontalTextAlign?.asHorizontalAlignmentProperty {
            return textAlign
        } else if let parentAlign = parentOverride?.parentHorizontalAlignment?.asHorizontalAlignmentProperty {
            return parentAlign
        } else {
            return .start
        }
    }

    var horizontalAlignmentOverride: HorizontalAlignment? {
        style?.text?.horizontalTextAlign?.asAlignment.horizontal
    }

    init(
        config: ComponentConfig,
        model: BasicTextViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        styleState: Binding<StyleState>,
        parentOverride: ComponentParentOverride?,
        expandsToContainerOnSelfAlign: Bool
    ) {
        self.config = config
        self.model = model

        _parentWidth = parentWidth
        _parentHeight = parentHeight
        _styleState = styleState

        self.parentOverride = parentOverride
        self.expandsToContainerOnSelfAlign = expandsToContainerOnSelfAlign

        _currentIndex = model.currentIndex
        totalOffers = model.totalOffer
        _viewableItems = model.viewableItems
    }

    var body: some View {
        if !stateReplacedValue.isEmpty {
            build()
                .applyLayoutModifier(
                    verticalAlignmentProperty: verticalAlignment,
                    horizontalAlignmentProperty: horizontalAlignment,
                    spacing: spacingStyle,
                    dimension: dimensionStyle,
                    flex: flexStyle,
                    border: nil,
                    background: backgroundStyle,
                    parent: config.parent,
                    parentWidth: $parentWidth,
                    parentHeight: $parentHeight,
                    parentOverride: parentOverride,
                    horizontalAlignmentOverride: horizontalAlignmentOverride,
                    defaultHeight: .wrapContent,
                    defaultWidth: .wrapContent,
                    expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign,
                    imageLoader: model.imageLoader
                )
                .onChange(of: styleState) { styleState in
                    model.styleState = styleState
                }
                .onChange(of: style?.text) { _ in
                    model.validateFont(textStyle: style?.text)
                }
                .onAppear {
                    model.validateFont(textStyle: style?.text)
                }
                .onChange(of: globalScreenSize.width) { newSize in
                    DispatchQueue.main.async {
                        // update breakpoint index
                        let index = min(model.layoutState?.getGlobalBreakpointIndex(newSize) ?? 0,
                                        (model.defaultStyle?.count ?? 1) - 1)
                        model.breakpointIndex = index >= 0 ? index : 0
                    }
                }
        }
    }

    func build() -> some View {
        Text(stateReplacedValue)
            .baselineOffset(style?.text?.baselineOffset ?? 0)
            .underline(style?.text?.textDecoration == .underline)
            .strikethrough(style?.text?.textDecoration == .strikeThrough)
            .tracking(CGFloat(style?.text?.letterSpacing ?? 0))
            .lineSpacing(lineHeight)
            .padding(.vertical, lineHeightPadding)
            .multilineTextAlignment(style?.text?.horizontalTextAlign?.asTextAlignment ?? .leading)
            .lineLimit(lineLimit)
            // fixedSize required for consistent lineLimit behaviour
            .fixedSize(horizontal: false, vertical: true)
            .scaledFont(textStyle: style?.text)
            .foregroundColor(hex: style?.text?.textColor?.getAdaptiveColor(colorScheme))
    }
}
