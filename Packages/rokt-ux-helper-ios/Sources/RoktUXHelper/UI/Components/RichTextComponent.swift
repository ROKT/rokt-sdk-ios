import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct RichTextComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    @SwiftUI.Environment(\.sizeCategory) var sizeCategory

    var style: RichTextStyle? {
        model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
    }

    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }
    var linkStyle: InlineTextStylingProperties? {
        model.linkStyle?.count ?? -1 > breakpointLinkIndex ? model.linkStyle?[breakpointLinkIndex].text : nil
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex: Int = 0
    @State var breakpointLinkIndex: Int = 0

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

    let config: ComponentConfig
    @ObservedObject var model: RichTextViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?

    let parentOverride: ComponentParentOverride?

    // for indicator styling
    let borderStyle: BorderStylingProperties?

    @State private var hasValidated = false

    var textView: Text {
        if model.attributedString.description.contains(BNFSeparator.startDelimiter.rawValue) ||
            model.attributedString.description.contains(BNFSeparator.endDelimiter.rawValue) {
            Text(AttributedString(model.stateReplacedAttributedString))
        } else if model.attributedString.description.isEmpty {
            Text(model.stateReplacedText)
        } else {
            Text(AttributedString(model.attributedString))
        }
    }

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

    init(
        config: ComponentConfig,
        model: RichTextViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        parentOverride: ComponentParentOverride?,
        borderStyle: BorderStylingProperties?
    ) {
        self.config = config
        self.model = model

        _parentWidth = parentWidth
        _parentHeight = parentHeight

        self.parentOverride = parentOverride
        self.borderStyle = borderStyle
    }

    var body: some View {
        if !model.stateReplacedText.isEmpty {
            build()
                .applyLayoutModifier(
                    verticalAlignmentProperty: verticalAlignment,
                    horizontalAlignmentProperty: horizontalAlignment,
                    spacing: spacingStyle,
                    dimension: dimensionStyle,
                    flex: flexStyle,
                    border: borderStyle ?? nil,
                    background: backgroundStyle,
                    parent: config.parent,
                    parentWidth: $parentWidth,
                    parentHeight: $parentHeight,
                    parentOverride: parentOverride,
                    defaultHeight: .wrapContent,
                    defaultWidth: .wrapContent,
                    imageLoader: model.imageLoader
                )
                .onChange(of: globalScreenSize.width) { newSize in
                    DispatchQueue.main.async {
                        breakpointIndex = model.updateBreakpointIndex(for: newSize)
                        breakpointLinkIndex = model.updateBreakpointLinkIndex(for: newSize)
                        model.breakpointIndex = breakpointIndex
                        model.breakpointLinkIndex = breakpointLinkIndex
                        model.updateAttributedString(colorScheme)
                    }
                }
                .onChange(of: colorScheme) { newSchema in
                    DispatchQueue.main.async {
                        model.updateAttributedString(newSchema)
                    }
                }
                .onChange(of: sizeCategory) { _ in
                    DispatchQueue.main.async {
                        model.updateAttributedString(colorScheme)
                    }
                }
                .onChange(of: style?.text) { _ in
                    model.validateFont(textStyle: style?.text)
                }
                .onAppear {
                    model.onAppear(textStyle: style)
                }
        }
    }

    func build() -> some View {
        return textView
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
            .tint(Color(hex: style?.text?.textColor?.getAdaptiveColor(colorScheme)))
            .environment(\.openURL, OpenURLAction(handler: model.handleURL))
    }
}
