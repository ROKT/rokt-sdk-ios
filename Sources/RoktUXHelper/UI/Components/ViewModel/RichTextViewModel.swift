import SwiftUI
import Combine
import DcuiSchema

class RichTextViewModel: Hashable, Identifiable, ObservableObject, ScreenSizeAdaptive {
    // `value` is used by our BNF transformer to update `dataBinding`
    private(set) var value: String?
    private(set) var dataBinding: DataBinding = .value("")
    // Post-mapper text retained as the template for reactive `%^DATA.catalogRuntime.<key>^%`
    // resolution. See `BasicTextViewModel` for the same pattern.
    private var postMapperTemplate: String?
    // this closure performs the STATE-based data expansion (eg. progress indicator component owning a rich text child)
    private var stateDataExpansionClosure: ((String?) -> String?)?
    private weak var eventService: EventDiagnosticServicing?

    let id: UUID = UUID()
    let defaultStyle: [RichTextStyle]?
    let linkStyle: [InLineTextStyle]?
    let openLinks: LinkOpenTarget?
    weak var layoutState: (any LayoutStateRepresenting)?

    // extracted data from `dataBinding` that's published externally
    @LazyPublished var boundValue = ""
    @LazyPublished var breakpointIndex = 0
    @LazyPublished var breakpointLinkIndex = 0
    @LazyPublished var attributedString = NSAttributedString("")

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    var viewableItems: Binding<Int>
    var currentIndex: Binding<Int>
    lazy var totalOffer: Int = layoutState?.items[LayoutState.totalItemsKey] as? Int ?? 1
    private var cancellable: AnyCancellable?

    var totalPages: Int {
        return Int(ceil(Double(totalOffer)/Double(viewableItems.wrappedValue)))
    }

    var stateReplacedAttributedString: NSAttributedString {
        let text = attributedString.description.isEmpty ? NSAttributedString(string: boundValue) : attributedString

        let replacedText = TextComponentBNFHelper.replaceStates(text,
                                                                currentOffer: "\(currentIndex.wrappedValue + 1)",
                                                                totalOffers: "\(totalPages)")
        return replacedText
    }

    var stateReplacedText: String {
        TextComponentBNFHelper.replaceStates(boundValue,
                                             currentOffer: "\(currentIndex.wrappedValue + 1)",
                                             totalOffers: "\(totalPages)")
    }

    init(
        value: String?,
        defaultStyle: [RichTextStyle]?,
        linkStyle: [InLineTextStyle]? = nil,
        openLinks: LinkOpenTarget?,
        stateDataExpansionClosure: ((String?) -> String?)? = nil,
        layoutState: (any LayoutStateRepresenting)?,
        eventService: EventDiagnosticServicing?
    ) {
        self.value = value
        self.boundValue = value ?? ""

        self.defaultStyle = defaultStyle
        self.linkStyle = linkStyle
        self.openLinks = openLinks
        self.stateDataExpansionClosure = stateDataExpansionClosure
        self.layoutState = layoutState
        self.eventService = eventService
        self.viewableItems = layoutState?.items[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
        self.currentIndex = layoutState?.items[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)
        updateBoundValueWithStyling()
        cancellable = layoutState?.itemsPublisher.sink { [weak self] newValue in
            guard let self else { return }
            self.viewableItems = newValue[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
            self.currentIndex = newValue[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)
            self.reapplyCatalogRuntimeResolution()
        }
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
    }

    func updateDataBinding(dataBinding: DataBinding<String>) {
        self.dataBinding = dataBinding
        if case .value(let v) = dataBinding {
            self.postMapperTemplate = v
        }
        runDataExpansion()
    }

    /// Template text for chained mappers: the post-previous-mapper output if any mapper has
    /// already written to `dataBinding`, otherwise the raw template. Distinguishes "no prior
    /// mapping" (postMapperTemplate == nil) from "prior mapping resolved to empty"
    /// (postMapperTemplate == ""), so an empty mapper output is preserved instead of
    /// reintroducing the raw placeholders for a later finalize pass to zero the line.
    var currentTemplateText: String {
        postMapperTemplate ?? value ?? ""
    }

    private func runDataExpansion() {
        switch dataBinding {
        case .value(let data):
            boundValue = applyCatalogRuntimeResolution(to: data)
        case .state(let data):
            var isStateIndicatorPosition = false
            // if the input is `%^STATE.IndicatorPosition^%`, associated value `data` = `IndicatorPosition`
            if DataBindingStateKeys.isValidKey(data) {
                isStateIndicatorPosition = true
            }

            // if the input is `%^STATE.IndicatorPosition^%`, becomes `IndicatorPosition`
            // if the input is `Hello`, becomes `Hello`
            boundValue = data

            // perform data expansion on initialiser argument `value` if the DataBinding is STATE
            processStateValue(value, isStateIndicatorPosition: isStateIndicatorPosition)
        }

        updateBoundValueWithStyling()
    }

    private func reapplyCatalogRuntimeResolution() {
        guard let template = postMapperTemplate else { return }
        boundValue = applyCatalogRuntimeResolution(to: template)
        updateBoundValueWithStyling()
    }

    private func applyCatalogRuntimeResolution(to text: String) -> String {
        CatalogRuntimePlaceholderResolver.resolve(
            text: text,
            catalogRuntimeData: layoutState?.items[LayoutState.catalogRuntimeDataKey] as? [String: String]
        )
    }

    /// Called by the layout transformer after every mapper has had its turn. Substitutes
    /// `|` defaults for any placeholder no mapper claimed, and zeroes the line if a
    /// mandatory placeholder is still unresolved. Deferred namespaces (`DATA.catalogRuntime`,
    /// `STATE.*`) are left intact.
    func finalizePlaceholders() {
        guard let template = postMapperTemplate else { return }
        guard let validated = OrphanedPlaceholderResolver.resolve(text: template) else {
            postMapperTemplate = ""
            boundValue = ""
            updateBoundValueWithStyling()
            return
        }
        postMapperTemplate = validated
        boundValue = applyCatalogRuntimeResolution(to: validated)
        updateBoundValueWithStyling()
    }

    // only runs if the DataBinding is STATE. this is where we do a STATE operation (eg. adding + 1)
    private func processStateValue(_ value: String?, isStateIndicatorPosition: Bool) {
        guard isStateIndicatorPosition,
              let stateDataExpansionClosure,
              let expandedValue = stateDataExpansionClosure(value)
        else { return }

        boundValue = expandedValue
    }

    func updateBoundValueWithStyling() {
        guard defaultStyle?.count ?? -1 > breakpointIndex,
              let transform = defaultStyle?[breakpointIndex].text?.textTransform else { return }

        switch transform {
        case .uppercase:
            boundValue = boundValue.uppercased()
        case .lowercase:
            boundValue = boundValue.lowercased()
        case .capitalize:
            boundValue = boundValue.capitalized
        default:
            break
        }
    }

    func transformValueToAttributedString(_ colorMode: RoktUXConfig.ColorMode?, colorScheme: ColorScheme? = nil) {
        let customColorScheme: ColorScheme = colorScheme ?? UITraitCollection.getConfigColorSchema(colorMode: colorMode)
        transformValueToAttributedString(customColorScheme)
    }

    private func transformValueToAttributedString(_ colorScheme: ColorScheme) {
        let valueToTransform = boundValue

        let breakpointDefaultStyle = (defaultStyle?.count ?? -1 > breakpointIndex)
            ? defaultStyle?[breakpointIndex]
            : nil

        let shouldSelectLink = linkStyle != nil && linkStyle?.count ?? -1 > breakpointLinkIndex
        let breakpointLinkStyle = shouldSelectLink ? linkStyle?[breakpointLinkIndex] : nil

        let performTransformation = { [weak self] in
            guard let self else { return }

            let htmlTransformedValue = valueToTransform.htmlToAttributedString(
                textColorHex: breakpointDefaultStyle?.text?.textColor?.getAdaptiveColor(colorScheme),
                uiFont: breakpointDefaultStyle?.text?.styledUIFont,
                linkStyles: breakpointLinkStyle?.text,
                colorScheme: colorScheme,
                blockSpacerHeight: breakpointDefaultStyle?.text?.lineHeight.map { CGFloat($0) }
            )

            self.attributedString = htmlTransformedValue
        }

        DispatchQueue.main.async {
            performTransformation()
        }
    }

    func updateAttributedString(_ colorScheme: ColorScheme) {
        transformValueToAttributedString(colorScheme)
    }

    func validateFont(textStyle: TextStylingProperties?) {
        if let fontFamily = textStyle?.fontFamily,
            UIFont(name: fontFamily,
                   size: CGFloat(textStyle?.fontSize ?? 17)) == nil {
            eventService?.sendFontDiagnostics(fontFamily)
        }
    }

    func handleURL(_ url: URL) -> OpenURLAction.Result {
        eventService?.openURL(url: url, type: .init(openLinks), completionHandler: {})
        return .handled
    }

    func updateBreakpointLinkIndex(for newSize: CGFloat?) -> Int {
        let linkIndex = min(layoutState?.getGlobalBreakpointIndex(newSize) ?? 0,
                            (linkStyle?.count ?? 1) - 1)
        return linkIndex >= 0 ? linkIndex : 0
    }

    func onAppear(textStyle: RichTextStyle?) {
        if attributedString.description.isEmpty && stateReplacedAttributedString.description.isEmpty {
            eventService?.sendDiagnostics(
                message: kViewErrorCode,
                callStack: kInvalidHTMLFormatError + stateReplacedAttributedString.description
            )
        }
        validateFont(textStyle: textStyle?.text)
    }
}
