import SwiftUI
import PassKit
import DcuiSchema

@available(iOS 15, *)
struct CatalogDevicePayButtonComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme

    let config: ComponentConfig
    @ObservedObject var model: CatalogDevicePayButtonViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?

    let parentOverride: ComponentParentOverride?

    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex = 0
    @State var frameChangeIndex: Int = 0
    @State var styleState: StyleState = .default
    @State var isHovered: Bool = false
    @State var isPressed: Bool = false
    @State var isDisabled: Bool = false
    @State private var availableWidth: CGFloat?
    @State private var availableHeight: CGFloat?

    init(
        config: ComponentConfig,
        model: CatalogDevicePayButtonViewModel,
        parentWidth: Binding<CGFloat?>,
        parentHeight: Binding<CGFloat?>,
        parentOverride: ComponentParentOverride?
    ) {
        self.config = config
        self.model = model
        _parentWidth = parentWidth
        _parentHeight = parentHeight
        self.parentOverride = parentOverride
        self.model.position = config.position
    }

    var style: CatalogDevicePayButtonStyles? {
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
        return containerStyle?.justifyContent?.asVerticalAlignment.vertical
    }
    var horizontalAlignmentOverride: HorizontalAlignment? {
        return containerStyle?.alignItems?.asHorizontalAlignment.horizontal
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

    var body: some View {
        buildPayButton()
            .disabled(model.isProcessing)
            .onChange(of: model.isProcessing) { newValue in
                isDisabled = newValue
                updateStyleState()
            }
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    breakpointIndex = model.updateBreakpointIndex(for: newSize)
                    frameChangeIndex += 1
                }
            }
    }

    @ViewBuilder
    private func buildPayButton() -> some View {
        switch model.provider {
        case .applePay:
            buildApplePay()
        default:
            buildChildrenButton()
        }
    }

    @ViewBuilder
    private func buildApplePay() -> some View {
        if #available(iOS 16.0, *) {
            PayWithApplePayButton(.buy, action: {
                model.handleTap()
            })
            .payWithApplePayButtonStyle(colorScheme == .dark ? .white : .black)
        } else {
            LegacyApplePayButton(colorScheme: colorScheme, action: {
                model.handleTap()
            })
            .id(colorScheme)
        }
    }

    private func buildChildrenButton() -> some View {
        HStack(alignment: rowPerpendicularAxisAlignment(alignItems: containerStyle?.alignItems), spacing: 0) {
            if let children = model.children {
                ForEach(children, id: \.self) { child in
                    LayoutSchemaComponent(
                        config: config.updateParent(.row),
                        layout: child,
                        parentWidth: $availableWidth,
                        parentHeight: $availableHeight,
                        styleState: $styleState,
                        parentOverride: ComponentParentOverride(
                            parentVerticalAlignment: rowPerpendicularAxisAlignment(
                                alignItems: containerStyle?.alignItems
                            ),
                            parentHorizontalAlignment: rowPrimaryAxisAlignment(
                                justifyContent: containerStyle?.justifyContent
                            ).asHorizontalType,
                            parentBackgroundStyle: passableBackgroundStyle,
                            stretchChildren: containerStyle?.alignItems == .stretch
                        ),
                        expandsToContainerOnSelfAlign: shouldExpandToContainerOnSelfAlign()
                    )
                }
            }
        }
        .accessibilityAddTraits(.isButton)
        .onHover { hovered in
            isHovered = hovered
            updateStyleState()
        }
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
            applyAlignSelf: false,
            applyMargin: false,
            frameChangeIndex: $frameChangeIndex,
            imageLoader: model.imageLoader
        )
        .contentShape(Rectangle())
        .alignSelf(alignSelf: flexStyle?.alignSelf,
                   parent: config.parent,
                   parentHeight: parentHeight,
                   parentWidth: parentWidth,
                   parentVerticalAlignment: parentOverride?.parentVerticalAlignment,
                   parentHorizontalAlignment: parentOverride?.parentHorizontalAlignment,
                   applyAlignSelf: true)
        .margin(spacing: spacingStyle, applyMargin: true)
        .readSize(spacing: spacingStyle) { size in
            availableWidth = size.width
            availableHeight = size.height
        }
        .onTapGesture {
            model.handleTap()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0, maximumDistance: 44)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        updateStyleState()
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        isPressed = false
                        updateStyleState()
                    }
                }
        )
    }

    private func shouldExpandToContainerOnSelfAlign() -> Bool {
        guard let heightType = model.defaultStyle?[breakpointIndex].dimension?.height else { return false }
        switch heightType {
        case .fixed, .percentage:
            return true
        default:
            return false
        }
    }

    private func updateStyleState() {
        if isDisabled {
            styleState = .disabled
        } else if isPressed {
            styleState = .pressed
        } else if isHovered {
            styleState = .hovered
        } else {
            styleState = .default
        }
    }
}

@available(iOS 15.0, *)
private struct LegacyApplePayButton: UIViewRepresentable {
    @SwiftUI.Environment(\.isEnabled) private var isEnabled
    var colorScheme: ColorScheme
    var action: () -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: colorScheme == .dark ? .white : .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {
        uiView.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func buttonTapped() {
            action()
        }
    }
}
