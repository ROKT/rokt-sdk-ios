import SwiftUI
import DcuiSchema

@available(iOS 15, *)
internal extension View {
    func frame(
        dimension: DimensionStylingProperties?,
        weight: Float?,
        parent: ComponentParentType,
        defaultWidth: WidthFitProperty,
        parentWidth: CGFloat?,
        defaultHeight: HeightFitProperty,
        parentHeight: CGFloat?,
        horizontalAxisAlignment: Alignment,
        verticalAxisAlignment: Alignment,
        alignSelf: FlexAlignment?,
        parentOverride: ComponentParentOverride?,
        margin: FrameAlignmentProperty?
    ) -> some View {
        var minWidth: CGFloat?
        var maxWidth: CGFloat?
        var minHeight: CGFloat?
        var maxHeight: CGFloat?
        var alignment: Alignment = horizontalAxisAlignment

        // update with width values
        let width = WidthModifier(widthProperty: dimension?.width,
                                  minimum: dimension?.minWidth,
                                  maximum: dimension?.maxWidth,
                                  alignment: horizontalAxisAlignment,
                                  defaultWidth: defaultWidth,
                                  parentWidth: parentWidth)
        if width.widthProperty != nil,
           width.isFixedWidth,
           let fixedWidth = width.fixedWidth {
            minWidth = fixedWidth
            maxWidth = fixedWidth
            alignment.horizontal = width.alignmentAsHorizontalType
        } else {
            if let frameMinWidth = width.frameMinWidth {
                minWidth = frameMinWidth
                alignment.horizontal = width.alignmentAsHorizontalType
            }
            if let frameMaxWidth = width.frameMaxWidth {
                maxWidth = frameMaxWidth
                alignment.horizontal = width.alignmentAsHorizontalType
            }
        }

        // update with percentage width values
        let percentageWidth = PercentageWidthModifier(width: parentWidth,
                                                      percentage: dimension?.width,
                                                      horizontalAxisAlignment: horizontalAxisAlignment,
                                                      margin: margin)
        if let frameWidth = percentageWidth.frameWidth {
            minWidth = frameWidth
            maxWidth = frameWidth
            alignment.horizontal = percentageWidth.alignmentAsHorizontalType
        }

        // update with height values
        let height = HeightModifier(heightProperty: dimension?.height,
                                    minimum: dimension?.minHeight,
                                    maximum: dimension?.maxHeight,
                                    alignment: verticalAxisAlignment,
                                    defaultHeight: defaultHeight,
                                    parentHeight: parentHeight)
        if height.heightProperty != nil,
           height.isFixedHeight,
           let fixedHeight = height.fixedHeight {
            minHeight = fixedHeight
            maxHeight = fixedHeight
            alignment.vertical = height.alignmentAsVerticalType
        } else {
            if let frameMinHeight = height.frameMinHeight {
                minHeight = frameMinHeight
                alignment.vertical = height.alignmentAsVerticalType
            }
            if let frameMaxHeight = height.frameMaxHeight {
                maxHeight = frameMaxHeight
                alignment.vertical = height.alignmentAsVerticalType
            }
        }

        // update with percentage height
        let percentageHeight = PercentageHeightModifier(height: parentHeight,
                                                        percentage: dimension?.height,
                                                        verticalAxisAlignment: verticalAxisAlignment,
                                                        margin: margin)
        if let frameHeight = percentageHeight.frameHeight {
            minHeight = frameHeight
            maxHeight = frameHeight
            alignment.vertical = percentageHeight.alignmentAsVerticalType
        }

        // update with weight
        let weightProperties = WeightModifier.Properties(weight: weight,
                                                         parent: parent,
                                                         verticalAlignment: verticalAxisAlignment,
                                                         horizontalAlignment: horizontalAxisAlignment)
        let weight = WeightModifier(props: weightProperties)

        if let frameMaxWidth = weight.frameMaxWidth {
            maxWidth = frameMaxWidth
            alignment.horizontal = weight.alignment.asHorizontalType ?? WeightModifier.Constant.defaultHorizontalAlignment
        }
        if let frameMaxHeight = weight.frameMaxHeight {
            maxHeight = frameMaxHeight
            alignment.vertical = weight.alignment.asVerticalType ?? WeightModifier.Constant.defaultVerticalAlignment
        }

        // update with align self stretch
        let alignSelfStretch = AlignSelfStretchModifier(alignSelf: alignSelf,
                                                        parent: parent,
                                                        parentHeight: parentHeight,
                                                        parentWidth: parentWidth,
                                                        parentOverride: parentOverride)
        if let frameMaxWidth = alignSelfStretch.frameMaxWidth {
            maxWidth = frameMaxWidth
            alignment.horizontal = alignSelfStretch.wrapperAlignment?.asHorizontalType ??
            AlignSelfStretchModifier.Constant.defaultHorizontalAlignment
        }
        if let frameMaxHeight = alignSelfStretch.frameMaxHeight {
            maxHeight = frameMaxHeight
            alignment.vertical = alignSelfStretch.wrapperAlignment?.asVerticalType ??
            AlignSelfStretchModifier.Constant.defaultVerticalAlignment
        }

        return modifier(FrameModifier(minWidth: minWidth,
                                      maxWidth: maxWidth,
                                      minHeight: minHeight,
                                      maxHeight: maxHeight,
                                      alignment: alignment))
    }

    func alignSelf(
        alignSelf: FlexAlignment?,
        parent: ComponentParentType,
        parentHeight: CGFloat?,
        parentWidth: CGFloat?,
        parentVerticalAlignment: VerticalAlignment? = nil,
        parentHorizontalAlignment: HorizontalAlignment? = nil,
        rowAlignmentOverride: VerticalAlignment? = nil,
        columnAlignmentOverride: HorizontalAlignment? = nil,
        expandsToContainerOnSelfAlign: Bool = false,
        applyAlignSelf: Bool
    ) -> some View {
        return modifier(AlignSelfModifier(
            alignSelf: alignSelf,
            parent: parent,
            parentHeight: parentHeight,
            parentWidth: parentWidth,
            parentRowAlignment: parentVerticalAlignment,
            parentColumnAlignment: parentHorizontalAlignment,
            rowAlignmentOverride: rowAlignmentOverride,
            columnAlignmentOverride: columnAlignmentOverride,
            expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign,
            applyAlignself: applyAlignSelf
        ))
    }

    func overflow(overflow: Overflow?) -> some View {
        modifier(OverflowModifier(overFlow: overflow))
    }

    func background(backgroundStyle: BackgroundStylingProperties?, imageLoader: RoktUXImageLoader?) -> some View {
        modifier(BackgroundModifier(backgroundStyle: backgroundStyle, imageLoader: imageLoader))
    }

    func backgroundColor(hex: String?) -> some View {
        modifier(BackgroundColorModifier(backgroundColor: hex))
    }

    func backgroundImage(backgroundImage: BackgroundImage?, imageLoader: RoktUXImageLoader?) -> some View {
        modifier(BackgroundImageModifier(backgroundImage: backgroundImage, imageLoader: imageLoader))
    }

    func foregroundColor(hex: String?) -> some View {
        modifier(ForegroundModifier(color: hex))
    }

    func rotate(rotateZ: Float?) -> some View {
        modifier(RotateModifier(rotateZ: rotateZ))
    }

    func padding(frame: FrameAlignmentProperty?) -> some View {
        modifier(PaddingModifier(padding: frame))
    }

    func offset(offset: OffsetProperty?) -> some View {
        modifier(OffsetModifier(offset: offset))
    }

    func blur(blur: Float?) -> some View {
        modifier(BlurModifier(blur: blur))
    }

    func bounceBasedOnSize() -> some View {
        modifier(ScrollBounceBasedOnSize())
    }

    func equalStretch(containerType: ComponentParentType,
                      isContainer: Bool,
                      stretchChildren: Bool?,
                      breakpointIndex: Binding<Int>) -> some View {
        modifier(EqualStretchModifier(containerType: containerType,
                                      isContainer: isContainer,
                                      stretchChildren: stretchChildren,
                                      breakpointIndex: breakpointIndex))
    }

    func margin(spacing: SpacingStylingProperties?, applyMargin: Bool) -> some View {
        modifier(MarginModifier(spacing: spacing, applyMargin: applyMargin))
    }

    func border(
        borderRadius: Float?,
        borderColor: ThemeColor?,
        borderWidth: String?,
        borderStyle: BorderStyle?
    ) -> some View {
        modifier(BorderModifier(borderRadius: borderRadius,
                                borderColor: borderColor,
                                borderWidth: FrameAlignmentProperty.getFrameAlignment(borderWidth),
                                borderStyle: borderStyle))
    }

    func shadow(
        backgroundColor: ThemeColor?,
        borderRadius: Float?,
        xOffset: Float?,
        yOffset: Float?,
        shadowColor: ThemeColor?,
        blurRadius: Float?,
        isContainer: Bool
    ) -> some View {
        return modifier(ShadowModifier(
            backgroundColor: backgroundColor,
            borderRadius: borderRadius,
            shadowOffsetX: xOffset,
            shadowOffsetY: yOffset,
            shadowColor: shadowColor,
            blurRadius: blurRadius,
            isContainer: isContainer
        ))
    }

    func customColorMode(colorMode: RoktUXConfig.ColorMode?) -> some View {
        modifier(ColorModeModifier(colorMode: colorMode))
    }

    func onLoad(perform action: (() -> Void)? = nil) -> some View {
        modifier(ViewDidLoadModifier(perform: action))
    }

    func onFirstTouch(perform action: (() -> Void)? = nil) -> some View {
        modifier(FirstTouchModifier(perform: action))
    }

    func onUserInteraction(perform action: (() -> Void)? = nil) -> some View {
        modifier(UserInteractionModifier(perform: action))
    }

    // return type must be `Alignment` since Width/Height uses the axis-independent type in `frame`
    func rowPrimaryAxisAlignment(justifyContent: FlexJustification?) -> Alignment {
        guard let justifyContent else { return .leading }

        return justifyContent.asHorizontalAlignment
    }

    // return type must be `VerticalAlignment` since HStack needs axis-specific type
    func rowPerpendicularAxisAlignment(alignItems: FlexAlignment?) -> VerticalAlignment {
        guard let alignItems,
              let horizontalAlignment = alignItems.asVerticalAlignment.asVerticalType
        else { return .top }

        return horizontalAlignment
    }

    // return type must be `Alignment` since Width/Height uses the axis-independent type in `frame`
    func columnPrimaryAxisAlignment(justifyContent: FlexJustification?) -> Alignment {
        guard let justifyContent else { return .top }

        return justifyContent.asVerticalAlignment
    }

    // return type must be `HorizontalAlignment` since VStack needs axis-specific type
    func columnPerpendicularAxisAlignment(alignItems: FlexAlignment?) -> HorizontalAlignment {
        guard let alignItems,
              let horizontalAlignment = alignItems.asHorizontalAlignment.asHorizontalType
        else { return .leading }

        return horizontalAlignment
    }

    func scaledFont(textStyle: TextStylingProperties?) -> some View {
        return self.modifier(ScaledFont(textStyle: textStyle))
    }
}

enum StyleState {
    case `default`, pressed, disabled, hovered
}

@available(iOS 15, *)
struct FrameModifier: ViewModifier {
    let minWidth: CGFloat?
    let maxWidth: CGFloat?
    let minHeight: CGFloat?
    let maxHeight: CGFloat?
    let alignment: Alignment

    func body(content: Content) -> some View {
        content
            .frame(minWidth: minWidth,
                   maxWidth: maxWidth,
                   minHeight: minHeight,
                   maxHeight: maxHeight,
                   alignment: alignment)
    }
}

@available(iOS 15, *)
struct PercentageWidthModifier {
    let width: CGFloat?
    let percentage: DimensionWidthValue?
    let alignmentAsHorizontalType: HorizontalAlignment
    let margin: FrameAlignmentProperty?

    init(width: CGFloat?,
         percentage: DimensionWidthValue?,
         horizontalAxisAlignment: Alignment,
         margin: FrameAlignmentProperty?) {
        self.width = width
        self.percentage = percentage
        self.alignmentAsHorizontalType = horizontalAxisAlignment.asHorizontalType ?? HorizontalAlignment.leading
        self.margin = margin
    }

    var frameWidth: CGFloat? {
        guard let width,
              let percentage,
              case .percentage(let value) = percentage
        else {
            return nil
        }

        return (width * CGFloat(value/100)) - (margin?.horizontalSpacing ?? 0)
    }
}

@available(iOS 15, *)
struct PercentageHeightModifier {
    let height: CGFloat?
    let percentage: DimensionHeightValue?
    let alignmentAsVerticalType: VerticalAlignment
    let margin: FrameAlignmentProperty?

    init(height: CGFloat?,
         percentage: DimensionHeightValue?,
         verticalAxisAlignment: Alignment,
         margin: FrameAlignmentProperty?) {
        self.height = height
        self.percentage = percentage
        self.alignmentAsVerticalType = verticalAxisAlignment.asVerticalType ?? VerticalAlignment.top
        self.margin = margin
    }

    var frameHeight: CGFloat? {
        guard let height,
              let percentage,
              case .percentage(let value) = percentage
        else {
            return nil
        }
        return height * CGFloat(value/100) - (margin?.verticalSpacing ?? 0)
    }
}

@available(iOS 15, *)
struct ForegroundModifier: ViewModifier {
    let color: String?

    var foregroundColor: Color? {
        guard let color else { return nil }
        return Color(hex: color)
    }

    func body(content: Content) -> some View {
        content.foregroundColor(foregroundColor)
    }
}

@available(iOS 15, *)
struct RotateModifier: ViewModifier {
    let rotateZ: Float?

    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(Double(rotateZ ?? 0)))
    }
}

@available(iOS 15, *)
struct ColorModeModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let colorMode: RoktUXConfig.ColorMode?

    var configColorScheme: ColorScheme {
        switch colorMode {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return colorScheme
        }
    }
    func body(content: Content) -> some View {
        if let colorMode, colorMode != .system {
            content
                .environment(\.colorScheme, configColorScheme)
                .preferredColorScheme(configColorScheme)
        } else {
            content
        }
    }
}

@available(iOS 15, *)
struct PaddingModifier: ViewModifier {
    let padding: FrameAlignmentProperty?

    func body(content: Content) -> some View {
        content
            .padding(.top, padding?.top ?? 0)
            .padding(.leading, padding?.left ?? 0)
            .padding(.bottom, padding?.bottom ?? 0)
            .padding(.trailing, padding?.right ?? 0)
    }
}

@available(iOS 15, *)
struct OffsetModifier: ViewModifier {
    let offset: OffsetProperty?

    func body(content: Content) -> some View {
        content
            .offset(
                x: offset?.x ?? 0,
                y: offset?.y ?? 0
            )
    }
}

@available(iOS 15, *)
struct BlurModifier: ViewModifier {
    let blur: Float?

    func body(content: Content) -> some View {
        content
            .blur(radius: CGFloat(blur ?? 0))
    }
}

@available(iOS 15, *)
struct ScrollBounceBasedOnSize: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

@available(iOS 15, *)
struct EqualStretchModifier: ViewModifier {
    let containerType: ComponentParentType
    let isContainer: Bool
    let stretchChildren: Bool?
    @Binding var frameChangeIndex: Int

    @State var horizontalFixSize: Bool
    @State var verticalFixSize: Bool
    @State var show: Bool = true

    init(containerType: ComponentParentType,
         isContainer: Bool,
         stretchChildren: Bool?,
         breakpointIndex: Binding<Int>) {
        self.containerType = containerType
        self.isContainer = isContainer
        self.stretchChildren = stretchChildren
        self._frameChangeIndex = breakpointIndex
        self.horizontalFixSize = containerType != .row
        self.verticalFixSize = containerType == .row
    }

    var horizontal: Bool {
        if isContainer && stretchChildren == true && containerType != .row {
            return true
        }
        return false
    }

    var vertical: Bool {
        if isContainer && stretchChildren == true && containerType == .row {
            return true
        }
        return false
    }

    func body(content: Content) -> some View {
        // Only apply this listeners if it is container and has stretch modifier
        if isContainer && stretchChildren == true {
            // To remove the fixedSize on the rotation.
            // This allows the frame to grow based on the content
            if show {
                content.fixedSize(horizontal: horizontalFixSize, vertical: verticalFixSize)
                    .onChange(of: frameChangeIndex) { newChange in
                        // No need to change for the first time
                        if newChange > 1 {
                            DispatchQueue.main.async {
                                verticalFixSize = false
                                horizontalFixSize = false
                                show = false
                            }
                        }
                    }
            } else {
                content
                    .onAppear {
                        // To bring fixedSize back after resizing
                        DispatchQueue.main.async {
                            show = true
                            verticalFixSize = vertical
                            horizontalFixSize = horizontal
                        }
                    }
            }
        } else {
            content
        }
    }
}

@available(iOS 15, *)
struct BorderModifier: ViewModifier {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let borderRadius: Float?
    let borderColor: ThemeColor?
    let borderWidth: FrameAlignmentProperty
    let borderStyle: BorderStyle?

    func body(content: Content) -> some View {
        content
            .cornerRadius(CGFloat(borderRadius ?? 0))
            .overlay {
                if borderWidth.isMultiDimension() && borderStyle != .dashed {
                    MultiDimensionBorder(borderWidth: borderWidth)
                        .foregroundColor(Color(hex: borderColor?.getAdaptiveColor(colorScheme)))
                        .cornerRadius(CGFloat(borderRadius ?? 0))
                }
                RoundedRectangle(cornerRadius: CGFloat(borderRadius ?? 0))
                    .strokeBorder(
                        Color(hex: borderColor?.getAdaptiveColor(colorScheme)),
                        style: getStrokeStyle(borderWidth: borderWidth.defaultWidth(), borderStyle: borderStyle)
                    )

            }
    }

    func getStrokeStyle(borderWidth: CGFloat, borderStyle: BorderStyle?) -> StrokeStyle {
        guard let borderStyle else { return StrokeStyle(lineWidth: CGFloat(borderWidth))}

        switch borderStyle {
        case .dashed:
            return StrokeStyle(
                lineWidth: borderWidth,
                dash: [10]
            )
            // To be supported when these styles are in SSoT
//        case .none:
//            return StrokeStyle(dash: [0])
//        case .dotted:
//            return StrokeStyle(
//                lineWidth: CGFloat(borderWidth),
//                lineCap: CGLineCap.round,
//                dash: [1, CGFloat(borderWidth*2)]
//            )
        default:
            return StrokeStyle(
                lineWidth: CGFloat(borderWidth)
            )
        }
    }
}

@available(iOS 15, *)
struct MultiDimensionBorder: Shape {
    let borderWidth: FrameAlignmentProperty

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addPath(Path(.init(x: rect.minX, y: rect.minY, width: rect.width, height: borderWidth.top)))
        path.addPath(Path(.init(x: rect.minX, y: rect.maxY - borderWidth.bottom, width: rect.width, height: borderWidth.bottom)))
        path.addPath(Path(.init(x: rect.minX, y: rect.minY, width: borderWidth.left, height: rect.height)))
        path.addPath(Path(.init(x: rect.maxX - borderWidth.right, y: rect.minY, width: borderWidth.right, height: rect.height)))
        return path
    }
}

@available(iOS 15, *)
struct ViewDidLoadModifier: ViewModifier {

    @State private var loaded = false
    private let action: (() -> Void)?

    init(perform action: (() -> Void)? = nil) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.onAppear {
            if !loaded {
                loaded = true
                action?()
            }
        }
    }
}

@available(iOS 15, *)
struct FirstTouchModifier: ViewModifier {

    @State private var loaded = false
    private let action: (() -> Void)?

    init(perform action: (() -> Void)? = nil) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded({
                if !loaded {
                    loaded = true
                    action?()
                }
            })
        )
    }
}

@available(iOS 15, *)
struct UserInteractionModifier: ViewModifier {

    private let action: (() -> Void)?

    init(perform action: (() -> Void)? = nil) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded({
                action?()
            })
        )
    }
}

@available(iOS 15, *)
struct ScaledFont: ViewModifier {
    @SwiftUI.Environment(\.sizeCategory) var sizeCategory
    let textStyle: TextStylingProperties?
    func body(content: Content) -> some View {
        return content.font(textStyle?.styledFont)
    }
}
