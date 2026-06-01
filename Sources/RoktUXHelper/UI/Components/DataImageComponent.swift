import SwiftUI
import Combine
import DcuiSchema

@available(iOS 15, *)
struct DataImageViewComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    private var style: DataImageStyles? {
        switch styleState {
        case .hovered:
            return model.hoveredStyle?.count ?? -1 > breakpointIndex ? model.hoveredStyle?[breakpointIndex] : nil
        case .pressed:
            return model.pressedStyle?.count ?? -1 > breakpointIndex ? model.pressedStyle?[breakpointIndex] : nil
        case .disabled:
            return model.disabledStyle?.count ?? -1 > breakpointIndex ? model.disabledStyle?[breakpointIndex] : nil
        default:
            return model.defaultStyle?.count ?? -1 > breakpointIndex ? model.defaultStyle?[breakpointIndex] : nil
        }
    }

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex = 0

    var dimensionStyle: DimensionStylingProperties? { style?.dimension }
    var flexStyle: FlexChildStylingProperties? { style?.flexChild }
    var borderStyle: BorderStylingProperties? { style?.border }
    var spacingStyle: SpacingStylingProperties? { style?.spacing }
    var backgroundStyle: BackgroundStylingProperties? { style?.background }

    let config: ComponentConfig
    let model: DataImageViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?
    @Binding var styleState: StyleState

    @State private var isImageValid = true

    let parentOverride: ComponentParentOverride?

    let expandsToContainerOnSelfAlign: Bool

    var verticalAlignment: VerticalAlignmentProperty {
        parentOverride?.parentVerticalAlignment?.asVerticalAlignmentProperty ?? .center
    }

    var horizontalAlignment: HorizontalAlignmentProperty {
        parentOverride?.parentHorizontalAlignment?.asHorizontalAlignmentProperty ?? .center
    }

    var body: some View {
        if !isImageValid || !hasUrlForColorScheme() {
            EmptyView()
        } else if isImageValid && hasUrlForColorScheme() {
            build()
                .applyLayoutModifier(
                    verticalAlignmentProperty: verticalAlignment,
                    horizontalAlignmentProperty: horizontalAlignment,
                    spacing: spacingStyle,
                    dimension: dimensionStyle,
                    flex: flexStyle,
                    border: borderStyle,
                    background: backgroundStyle,
                    parent: config.parent,
                    parentWidth: $parentWidth,
                    parentHeight: $parentHeight,
                    parentOverride: parentOverride,
                    defaultHeight: .wrapContent,
                    defaultWidth: .wrapContent,
                    expandsToContainerOnSelfAlign: expandsToContainerOnSelfAlign,
                    imageLoader: model.imageLoader
                )
                .onChange(of: globalScreenSize.width) { newSize in
                    DispatchQueue.main.async {
                        breakpointIndex = model.updateBreakpointIndex(for: newSize)
                    }
                }

        }
    }

    func build() -> some View {
        AsyncImageView(imageUrl: ThemeUrl(light: model.image?.light ?? "",
                                          dark: model.image?.dark ?? ""),
                       scale: .fit,
                       alt: model.image?.accessibilityAltText,
                       imageLoader: model.imageLoader,
                       isImageValid: $isImageValid)
    }

    func hasUrlForColorScheme() -> Bool {
        return (model.image?.light?.isEmpty == false && colorScheme == .light)
        || (model.image?.dark?.isEmpty == false && colorScheme == .dark)
    }
}
