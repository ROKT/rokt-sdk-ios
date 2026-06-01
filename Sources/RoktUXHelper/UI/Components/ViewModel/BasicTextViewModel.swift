import SwiftUI
import Combine
import DcuiSchema

protocol DataBindingImplementable {
    associatedtype T: Hashable
    var dataBinding: DataBinding<T> { get }
    func updateDataBinding(dataBinding: DataBinding<T>)
}

class BasicTextViewModel: Hashable, Identifiable, ObservableObject, DataBindingImplementable {
    private var bag = Set<AnyCancellable>()

    let id: UUID = UUID()

    // `value` is used by our BNF transformer to update `dataBinding`
    private(set) var value: String?
    private(set) var dataBinding: DataBinding<String> = .value("")

    // Post-mapper text retained as the template for reactive catalog-runtime resolution. Mappers
    // resolve their own namespaces and write the partially-resolved text here; on every
    // `LayoutState.itemsPublisher` emission we re-resolve `%^DATA.catalogRuntime.<key>^%`
    // against the latest catalog-runtime dictionary so live values from the host SDK appear
    // without re-running the layout transformer.
    private var postMapperTemplate: String?

    // extracted data from `dataBinding` that's published externally
    @LazyPublished var boundValue = ""

    @LazyPublished var styleState = StyleState.default
    @LazyPublished var breakpointIndex = 0
    var currentStylingProperties: BasicTextStyle? {
        switch styleState {
        case .hovered:
            return hoveredStyle?.count ?? -1 > breakpointIndex ? hoveredStyle?[breakpointIndex] : nil
        case .pressed:
            return pressedStyle?.count ?? -1 > breakpointIndex ? pressedStyle?[breakpointIndex] : nil
        case .disabled:
            return disabledStyle?.count ?? -1 > breakpointIndex ? disabledStyle?[breakpointIndex] : nil
        default:
            return defaultStyle?.count ?? -1 > breakpointIndex ? defaultStyle?[breakpointIndex] : nil
        }
    }

    let defaultStyle: [BasicTextStyle]?
    let pressedStyle: [BasicTextStyle]?
    let hoveredStyle: [BasicTextStyle]?
    let disabledStyle: [BasicTextStyle]?
    weak var layoutState: (any LayoutStateRepresenting)?
    weak var diagnosticService: DiagnosticServicing?
    // this closure performs the STATE-based data expansion (eg. progress indicator component owning a rich text child)
    private var stateDataExpansionClosure: ((String?) -> String?)?
    private var cancellable: AnyCancellable?

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    var currentIndex: Binding<Int> = .constant(0)
    var viewableItems: Binding<Int> = .constant(1)

    var totalOffer: Int {
        layoutState?.items[LayoutState.totalItemsKey] as? Int ?? 1
    }

    init(
        value: String?,
        defaultStyle: [BasicTextStyle]?,
        pressedStyle: [BasicTextStyle]?,
        hoveredStyle: [BasicTextStyle]?,
        disabledStyle: [BasicTextStyle]?,
        stateDataExpansionClosure: ((String?) -> String?)? = nil,
        layoutState: (any LayoutStateRepresenting)?,
        diagnosticService: DiagnosticServicing?
    ) {
        self.value = value

        self.boundValue = value ?? ""

        self.defaultStyle = defaultStyle
        self.pressedStyle = pressedStyle
        self.hoveredStyle = hoveredStyle
        self.disabledStyle = disabledStyle

        self.stateDataExpansionClosure = stateDataExpansionClosure
        self.layoutState = layoutState
        self.diagnosticService = diagnosticService
        self.viewableItems = layoutState?.items[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
        self.currentIndex = layoutState?.items[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)
        performStyleStateBinding()

        cancellable = layoutState?.itemsPublisher.sink { [weak self] newValue in
            guard let self else { return }
            self.viewableItems = newValue[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
            self.currentIndex = newValue[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)
            // Re-resolve `%^DATA.catalogRuntime.<key>^%` against the latest catalog-runtime dict so the
            // confirmation screen picks up subtotal/tax/shipping/total values pushed at runtime.
            self.reapplyCatalogRuntimeResolution()
        }
    }

    deinit {
        cancellable?.cancel()
        bag.removeAll()
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

    // update the text to display if State changes
    private func performStyleStateBinding() {
        $styleState.sink { [weak self] _ in
            self?.updateBoundValueWithStyling()
        }
        .store(in: &bag)
    }

    // only runs if the DataBinding is STATE. this is where we do a STATE operation (eg. adding + 1)
    func processStateValue(_ value: String?, isStateIndicatorPosition: Bool) {
        guard isStateIndicatorPosition,
              let stateDataExpansionClosure,
              let expandedValue = stateDataExpansionClosure(value)
        else { return }

        boundValue = expandedValue
    }

    private func updateBoundValueWithStyling() {
        guard let transform = currentStylingProperties?.text?.textTransform else { return }

        switch transform {
        case .uppercase:
            boundValue = boundValue.uppercased()
        case .lowercase:
            boundValue = boundValue.lowercased()
        case .capitalize:
            boundValue = boundValue.capitalized
        default: break
        }
    }

    func validateFont(textStyle: TextStylingProperties?) {
        if let fontFamily = textStyle?.fontFamily,
            UIFont(name: fontFamily,
                   size: CGFloat(textStyle?.fontSize ?? 17)) == nil {
            diagnosticService?.sendFontDiagnostics(fontFamily)
        }
    }
}
