import Foundation
import SwiftUI
import DcuiSchema
import Combine

@available(iOS 13.0, *)
class LayoutState: LayoutStateRepresenting {

    static let breakPointsSharedKey = "breakPoints" // BreakPoint
    static let currentProgressKey = "currentProgress" // Binding<Int>
    static let totalItemsKey = "totalItems" // Int
    static let layoutType = "layoutCode" // PlacementLayoutCode
    static let viewableItemsKey = "viewableItems" // Binding<Int>
    static let layoutSettingsKey = "layoutSettings" // LayoutSettings
    static let customStateMap = "customStateMap" // CustomStateMap
    static let globalCustomStateMapKey = "globalCustomStateMap" // Global CustomStateMap
    static let activeCatalogItemKey = "activeCatalogItem" // CatalogItem
    static let fullOfferKey = "fullOffer" // OfferModel
    static let catalogDropdownSelectedIndexKey = "catalogDropdownSelectedIndex" // [Int: Int] (attributeIndex -> optionIndex)
    // Holds runtime catalog values pushed by the host SDK after API calls
    // (e.g. {subtotal, tax, shipping, total} after `/cart/initialize-purchase`)
    // for reactive `%^DATA.catalogRuntime.<key>^%` placeholder resolution in text view models.
    static let catalogRuntimeDataKey = "catalogRuntimeData" // [String: String]

    /// Counter used during layout transformation to assign attribute indices to dropdowns.
    var nextCatalogDropdownAttributeIndex: Int = 0

    private var _items = [String: Any]()
    private var _globalCustomStateMap = RoktUXCustomStateMap()
    private(set) var itemsPublisher: CurrentValueSubject<[String: Any], Never> = .init([:])
    private let queue = DispatchQueue(label: kSharedDataItemsQueueLabel, attributes: .concurrent)
    let config: RoktUXConfig?
    let validationCoordinator: FormValidationCoordinating

    var items: [String: Any] {
        get {
            queue.sync {
                return _items
            }
        }
        set {
            queue.sync(flags: .barrier) {
                _items = newValue
            }
            itemsPublisher.send(newValue)
        }
    }

    var actionCollection: ActionCollecting

    var colorMode: RoktUXConfig.ColorMode? {
        config?.colorMode
    }

    var imageLoader: (any RoktUXImageLoader)? {
        config?.imageLoader
    }

    public let initialPluginViewState: RoktPluginViewState?
    private let pluginId: String?
    private let onPluginViewStateChange: ((RoktPluginViewState) -> Void)?

    init(actionCollection: ActionCollecting = ActionCollection(),
         config: RoktUXConfig? = nil,
         validationCoordinator: FormValidationCoordinating = FormValidationCoordinator(),
         pluginId: String? = nil,
         initialPluginViewState: RoktPluginViewState? = nil,
         onPluginViewStateChange: ((RoktPluginViewState) -> Void)? = nil) {
        self.actionCollection = actionCollection
        self.config = config
        self.validationCoordinator = validationCoordinator
        self.pluginId = pluginId
        self.initialPluginViewState = initialPluginViewState
        self.onPluginViewStateChange = onPluginViewStateChange
        if let initialCustomStates = initialPluginViewState?.customStateMap {
            let globalEntries = initialCustomStates.filter { $0.key.position == nil }
            if !globalEntries.isEmpty {
                _globalCustomStateMap = globalEntries.reduce(into: RoktUXCustomStateMap()) { partialResult, element in
                    partialResult[element.key] = element.value
                }
            }
        }
        items[LayoutState.globalCustomStateMapKey] = globalCustomStateMapBinding
    }

    func capturePluginViewState(offerIndex: Int?, dismiss: Bool?) {
        guard let pluginId else { return }
        let currentProgress: Binding<Int>? = items[LayoutState.currentProgressKey] as? Binding<Int>
        let customStateMap: Binding<RoktUXCustomStateMap?>? = items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?>
        let globalStates = queue.sync { _globalCustomStateMap }
        // Filter out nil-position (global) entries from local state to avoid
        // resurrecting stale values that were cleared via resetGlobalCustomState.
        var combinedStates = (customStateMap?.wrappedValue ?? [:]).filter { $0.key.position != nil }
        for (key, value) in globalStates {
            combinedStates[key] = value
        }
        onPluginViewStateChange?(RoktPluginViewState(pluginId: pluginId,
                                                     offerIndex: offerIndex ?? currentProgress?.wrappedValue,
                                                     isPluginDismissed: dismiss,
                                                     customStateMap: combinedStates.isEmpty ? nil : combinedStates))
    }

    func setLayoutType(_ type: RoktUXPlacementLayoutCode) {
        items[LayoutState.layoutType] = type
    }

    func layoutType() -> RoktUXPlacementLayoutCode {
        (items[LayoutState.layoutType] as? RoktUXPlacementLayoutCode) ?? .unknown
    }

    func closeOnComplete() -> Bool {
        guard let layoutSettings = items[LayoutState.layoutSettingsKey] as? LayoutSettings,
              let closeOnComplete = layoutSettings.closeOnComplete
        else {
            return true
        }
        return closeOnComplete
    }

    func getGlobalBreakpointIndex(_ width: CGFloat?) -> Int {
        guard let width,
              let globalBreakPoints = items[LayoutState.breakPointsSharedKey] as? BreakPoint,
              !globalBreakPoints.isEmpty
        else { return 0 }

        let sortedGlobalBreakPoints = globalBreakPoints.sorted { $0.1 < $1.1 }
        var index = 0
        for breakpoint in sortedGlobalBreakPoints {
            if CGFloat(breakpoint.value) > width {
                return index
            }
            index += 1
        }

        return index
    }

    func publishStateChange() {
        itemsPublisher.send(items)
    }

    private lazy var globalCustomStateMapBinding: Binding<RoktUXCustomStateMap?> = Binding(
        get: { [weak self] in
            guard let self else { return nil }
            return self.queue.sync {
                self._globalCustomStateMap.isEmpty ? nil : self._globalCustomStateMap
            }
        },
        set: { [weak self] newValue in
            guard let self else { return }
            self.queue.async(flags: .barrier) {
                self._globalCustomStateMap = newValue ?? [:]
                DispatchQueue.main.async {
                    self.publishStateChange()
                }
            }
        }
    )

    func globalCustomStateValue(for key: String) -> Int? {
        let identifier = CustomStateIdentifiable(position: nil, key: key)
        return queue.sync { _globalCustomStateMap[identifier] }
    }

    func setGlobalCustomState(key: String, value: Int) {
        let identifier = CustomStateIdentifiable(position: nil, key: key)
        queue.async(flags: .barrier) {
            self._globalCustomStateMap[identifier] = value
            DispatchQueue.main.async {
                self.publishStateChange()
            }
        }
    }

    func resetGlobalCustomState(key: String) {
        let identifier = CustomStateIdentifiable(position: nil, key: key)
        queue.async(flags: .barrier) {
            self._globalCustomStateMap.removeValue(forKey: identifier)
            DispatchQueue.main.async {
                self.publishStateChange()
            }
        }
    }
}

extension Int {
    /// Returns the current value and increments it. Used for assigning sequential indices.
    mutating func advanceAndReturnPrevious() -> Int {
        let current = self
        self += 1
        return current
    }
}
