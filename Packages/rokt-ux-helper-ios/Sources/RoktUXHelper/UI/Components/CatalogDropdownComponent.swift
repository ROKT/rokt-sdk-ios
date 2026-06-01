import SwiftUI
import DcuiSchema

@available(iOS 15, *)
struct CatalogDropdownComponent: View {
    @SwiftUI.Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var globalScreenSize: GlobalScreenSize
    @State var breakpointIndex: Int = 0
    @State var frameChangeIndex: Int = 0
    @State var isExpanded: Bool = false
    @State var showValidationError: Bool = false
    @State var isValidatorRegistered: Bool = false
    @State var buttonFrameInGlobal: CGRect = .zero

    let config: ComponentConfig
    let model: CatalogDropdownViewModel

    @Binding var parentWidth: CGFloat?
    @Binding var parentHeight: CGFloat?

    let parentOverride: ComponentParentOverride?

    // MARK: - Style Resolution

    private var headStyle: CatalogDropdownStyles? {
        let styles = model.headStyles
        guard let styles, breakpointIndex < styles.count else {
            return model.headStyles?.last?.default
        }
        if showValidationError, let errored = styles[breakpointIndex].errored {
            return errored
        }
        return styles[breakpointIndex].default
    }

    private var optionListStyle: CatalogDropdownStyles? {
        let styles = model.optionListStyles
        guard let styles, breakpointIndex < styles.count else {
            return model.optionListStyles?.last?.default
        }
        return styles[breakpointIndex].default
    }

    private func optionStyle(isSelected: Bool, isDisabled: Bool) -> CatalogDropdownStyles? {
        let styles = model.optionStyles
        guard let styles, breakpointIndex < styles.count else {
            return model.optionStyles?.last?.default
        }
        let block = styles[breakpointIndex]
        if isDisabled, let disabled = block.disabled { return disabled }
        if isSelected, let selected = block.selected { return selected }
        return block.default
    }

    private var errorStyle: CatalogDropdownStyles? {
        let styles = model.errorStyles
        guard let styles, breakpointIndex < styles.count else {
            return model.errorStyles?.last?.default
        }
        return styles[breakpointIndex].default
    }

    private var iconStyle: CatalogDropdownStyles? {
        let styles = model.iconStyles
        guard let styles, breakpointIndex < styles.count else {
            return model.iconStyles?.last?.default
        }
        return styles[breakpointIndex].default
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        // Hide the dropdown (and skip validator registration) when there is
        // nothing meaningful to choose. Align with web dcui, which
        // returns null when `items.length <= 1`. The two cases this guards:
        //   • Offer has no `catalogItemGroup` (e.g. single-variant product —
        //     the backend selector didn't configure a group) → options == [].
        //   • A group attribute has only one option.
        if model.options.count < 2 {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                headView
                if showValidationError {
                    errorView
                }
            }
            .background(
                DropdownWindowOverlayPresenter(
                    isPresented: $isExpanded,
                    content: { expandedOverlayView() }
                )
            )
            .onChange(of: globalScreenSize.width) { newSize in
                DispatchQueue.main.async {
                    breakpointIndex = model.updateBreakpointIndex(for: newSize)
                    frameChangeIndex += 1
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.a11yLabel ?? "")
            .onAppear { registerValidatorIfNeeded() }
            .onDisappear { unregisterValidator() }
        }
    }

    // MARK: - Validation Registration

    private func registerValidatorIfNeeded() {
        guard !isValidatorRegistered,
              let fieldConfig = model.validatorFieldConfig,
              let layoutState = model.layoutState else { return }
        let key = fieldConfig.validationFieldKey
        guard !key.isEmpty else { return }

        layoutState.validationCoordinator.registerField(
            key: key,
            owner: model,
            validation: {
                guard let validators = model.validatorFieldConfig?.validators else { return .valid }
                for validator in validators {
                    switch validator {
                    case .required:
                        if model.persistedSelectedIndex == nil {
                            return .invalid
                        }
                    }
                }
                return .valid
            },
            onStatusChange: { status in
                showValidationError = status == .invalid
            }
        )
        isValidatorRegistered = true
    }

    private func unregisterValidator() {
        guard isValidatorRegistered,
              let layoutState = model.layoutState,
              let key = model.validatorFieldConfig?.validationFieldKey else { return }

        layoutState.validationCoordinator.unregisterField(for: key, owner: model)
        isValidatorRegistered = false
        showValidationError = false
    }

    private func notifyValidationOfSelectionChange() {
        guard isValidatorRegistered,
              let layoutState = model.layoutState,
              let key = model.validatorFieldConfig?.validationFieldKey else { return }

        if model.validatorFieldConfig?.validateOnChange == true || showValidationError {
            layoutState.validationCoordinator.validate(field: key)
        }
    }

    // MARK: - Head View (trigger)

    private var headView: some View {
        let style = headStyle
        let padding = style?.spacing?.padding?.paddingEdgeInsets ?? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let bgColor = style?.background?.backgroundColor?.getAdaptiveColor(colorScheme)
        let borderColor = style?.border?.borderColor?.getAdaptiveColor(colorScheme)
        let borderRadius = CGFloat(style?.border?.borderRadius ?? 8)
        let borderWidth = style?.border?.borderWidth?.uniformWidth ?? 1
        let fontSize = CGFloat(style?.text?.fontSize ?? 14)
        let textColor = style?.text?.textColor?.getAdaptiveColor(colorScheme)

        return Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack(spacing: 0) {
                Text(model.displayText(for: model.persistedSelectedIndex))
                    .font(.system(size: fontSize))
                    .foregroundColor(model.persistedSelectedIndex == nil
                        ? Color(hex: textColor).opacity(0.5)
                        : Color(hex: textColor))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                chevronIcon
            }
            .padding(padding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(hex: bgColor))
        .overlay(
            RoundedRectangle(cornerRadius: borderRadius)
                .stroke(Color(hex: borderColor), lineWidth: borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: borderRadius))
        .background(
            ViewFrameReader { frame in
                guard frame != .zero else { return }
                DispatchQueue.main.async {
                    if buttonFrameInGlobal != frame {
                        buttonFrameInGlobal = frame
                    }
                }
            }
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: DropdownButtonFramePreferenceKey.self, value: proxy.frame(in: .global))
            }
        )
        .onPreferenceChange(DropdownButtonFramePreferenceKey.self) { frame in
            guard frame != .zero else { return }
            if buttonFrameInGlobal != frame {
                buttonFrameInGlobal = frame
            }
        }
    }

    private var chevronIcon: some View {
        let style = iconStyle
        let iconColor = style?.text?.textColor?.getAdaptiveColor(colorScheme)
        let iconSize = CGFloat(style?.text?.fontSize ?? 12)

        return Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(Color(hex: iconColor))
    }

    // MARK: - Expanded Overlay

    @ViewBuilder
    private func expandedOverlayView() -> some View {
        let screenBounds = UIScreen.main.bounds
        let overlayHeight = screenBounds.height
        let dropdownHeight = min(optionListEstimatedHeight, 220)
        let dropdownWidth = buttonFrameInGlobal.width

        let buttonBottom = buttonFrameInGlobal.maxY
        let buttonTop = buttonFrameInGlobal.minY
        let availableBelow = overlayHeight - buttonBottom
        let availableAbove = buttonTop

        let resolvedX = buttonFrameInGlobal.minX
        let resolvedY: CGFloat = {
            if availableBelow >= dropdownHeight {
                return buttonBottom
            } else if availableAbove >= dropdownHeight {
                return max(buttonTop - dropdownHeight, 0)
            } else {
                let maxStart = max(overlayHeight - dropdownHeight, 0)
                return min(max(buttonBottom - dropdownHeight/2, 0), maxStart)
            }
        }()

        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                .onTapGesture { isExpanded = false }

            optionListView
                .frame(width: dropdownWidth)
                .offset(x: resolvedX, y: resolvedY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }

    private var optionListEstimatedHeight: CGFloat {
        CGFloat(model.options.count) * 44
    }

    // MARK: - Option List

    private var optionListView: some View {
        let style = optionListStyle
        let borderColor = style?.border?.borderColor?.getAdaptiveColor(colorScheme)
        let borderRadius = CGFloat(style?.border?.borderRadius ?? 8)
        let borderWidth = style?.border?.borderWidth?.uniformWidth ?? 1
        let maxHeight: CGFloat = 220
        let contentHeight = min(optionListEstimatedHeight, maxHeight)

        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(model.options.enumerated()), id: \.offset) { index, option in
                    optionRow(index: index, option: option)
                }
            }
        }
        .frame(height: contentHeight)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: borderRadius))
        .overlay(
            RoundedRectangle(cornerRadius: borderRadius)
                .stroke(Color(hex: borderColor), lineWidth: borderWidth)
        )
        .shadow(radius: 4)
    }

    private func optionRow(index: Int, option: CatalogItemGroupOption) -> some View {
        let isSelected = model.persistedSelectedIndex == index
        let isDisabled = model.isOptionDisabled(at: index)
        let style = optionStyle(isSelected: isSelected, isDisabled: isDisabled)
        let bgColor = style?.background?.backgroundColor?.getAdaptiveColor(colorScheme)
        let textColor = style?.text?.textColor?.getAdaptiveColor(colorScheme)
        let fontSize = CGFloat(style?.text?.fontSize ?? 14)
        let rowPadding = style?.spacing?.padding?.paddingEdgeInsets ?? EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let rowBorderColor = style?.border?.borderColor?.getAdaptiveColor(colorScheme)
        let rowBorderWidth = style?.border?.borderWidth

        return Button {
            if !isDisabled {
                model.selectItem(at: index)
                withAnimation { isExpanded = false }
                notifyValidationOfSelectionChange()
            }
        } label: {
            HStack {
                Text(option.label ?? "")
                    .font(.system(size: fontSize))
                    .foregroundColor(isDisabled ? Color(hex: textColor).opacity(0.4) : Color(hex: textColor))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(rowPadding)
            .background(Color(hex: bgColor))
            .overlay(alignment: .bottom) {
                if let borderColor = rowBorderColor {
                    let bottomWidth = rowBorderWidth?.bottomWidth ?? 0
                    if bottomWidth > 0 {
                        Color(hex: borderColor)
                            .frame(height: bottomWidth)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Error View

    private var errorView: some View {
        let style = errorStyle
        let textColor = style?.text?.textColor?.getAdaptiveColor(colorScheme)
        let fontSize = CGFloat(style?.text?.fontSize ?? 12)
        let padding = style?.spacing?.padding?.paddingEdgeInsets ?? EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0)

        return Text(validationErrorMessage)
            .font(.system(size: fontSize))
            .foregroundColor(Color(hex: textColor))
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var validationErrorMessage: String {
        guard let validators = model.validatorFieldConfig?.validators else { return "" }
        for validator in validators {
            switch validator {
            case .required(let req):
                return req.message
            }
        }
        return ""
    }
}

// MARK: - Border Width Helpers

private extension String {
    /// Parse CSS-like border-width string (e.g. "1", "0 0 1 0") and return uniform or bottom width
    var uniformWidth: CGFloat {
        let parts = split(separator: " ").compactMap { Float($0) }
        guard let first = parts.first else { return 0 }
        return CGFloat(first)
    }

    var bottomWidth: CGFloat {
        let parts = split(separator: " ").compactMap { Float($0) }
        switch parts.count {
        case 1: return CGFloat(parts[0])
        case 2: return CGFloat(parts[0]) // top-bottom, left-right
        case 3: return CGFloat(parts[2]) // top, left-right, bottom
        case 4: return CGFloat(parts[2]) // top, right, bottom, left
        default: return 0
        }
    }

    var paddingEdgeInsets: EdgeInsets {
        let parts = split(separator: " ").compactMap { CGFloat(Float($0) ?? 0) }
        switch parts.count {
        case 1: return EdgeInsets(top: parts[0], leading: parts[0], bottom: parts[0], trailing: parts[0])
        case 2: return EdgeInsets(top: parts[0], leading: parts[1], bottom: parts[0], trailing: parts[1])
        case 3: return EdgeInsets(top: parts[0], leading: parts[1], bottom: parts[2], trailing: parts[1])
        case 4: return EdgeInsets(top: parts[0], leading: parts[3], bottom: parts[2], trailing: parts[1])
        default: return EdgeInsets()
        }
    }
}

// MARK: - View Frame Reader

private struct DropdownButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private struct ViewFrameReader: UIViewRepresentable {
    let onFrameChange: (CGRect) -> Void

    func makeUIView(context: Context) -> FrameObserverView {
        let view = FrameObserverView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onFrameChange = onFrameChange
        return view
    }

    func updateUIView(_ uiView: FrameObserverView, context: Context) {
        uiView.onFrameChange = onFrameChange
    }

    static func dismantleUIView(_ uiView: FrameObserverView, coordinator: ()) {
        uiView.onFrameChange = nil
    }
}

private final class FrameObserverView: UIView {
    var onFrameChange: ((CGRect) -> Void)?
    private var lastFrame: CGRect = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let superview else { return }
        let convertedFrame = superview.convert(bounds, to: nil)
        guard convertedFrame != lastFrame else { return }
        lastFrame = convertedFrame
        onFrameChange?(convertedFrame)
    }
}

// MARK: - Window Overlay Presenter

@available(iOS 15, *)
private struct DropdownWindowOverlayPresenter<OverlayContent: View>: UIViewRepresentable {
    @Binding var isPresented: Bool
    let content: () -> OverlayContent

    func makeUIView(context: Context) -> DropdownOverlayHostingView {
        DropdownOverlayHostingView()
    }

    func updateUIView(_ uiView: DropdownOverlayHostingView, context: Context) {
        if isPresented {
            uiView.present(content: AnyView(content()))
        } else {
            uiView.dismiss()
        }
    }

    static func dismantleUIView(_ uiView: DropdownOverlayHostingView, coordinator: ()) {
        uiView.dismiss()
    }
}

private final class DropdownOverlayHostingView: UIView {
    private var hostingController: UIHostingController<AnyView>?
    private weak var attachedWindow: UIWindow?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(content: AnyView) {
        guard let window = currentWindow else { return }

        if let hostingController {
            if attachedWindow === window {
                hostingController.rootView = content
                window.bringSubviewToFront(hostingController.view)
                return
            } else {
                hostingController.view.removeFromSuperview()
                self.hostingController = nil
                attachedWindow = nil
            }
        }

        let controller = UIHostingController(rootView: content)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        window.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: window.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])

        hostingController = controller
        attachedWindow = window
    }

    func dismiss() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        attachedWindow = nil
    }

    private var currentWindow: UIWindow? {
        if let w = hostingController?.view.window ?? attachedWindow ?? self.window {
            return w
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
