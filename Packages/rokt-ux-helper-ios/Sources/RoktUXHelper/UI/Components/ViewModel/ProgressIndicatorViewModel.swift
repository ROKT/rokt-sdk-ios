import SwiftUI
import DcuiSchema
import Combine

@available(iOS 15, *)
class ProgressIndicatorViewModel: Identifiable, Hashable {
    let id: UUID = UUID()

    let indicator: String
    private(set) var dataBinding: DataBinding = .value("")

    let defaultStyle: [ProgressIndicatorStyles]?
    let indicatorStyle: [IndicatorStyles]?
    let activeIndicatorStyle: [IndicatorStyles]?
    let seenIndicatorStyle: [IndicatorStyles]?
    let startPosition: Int32?
    let accessibilityHidden: Bool?
    weak var eventService: EventDiagnosticServicing?
    weak var layoutState: (any LayoutStateRepresenting)?
    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    var currentIndex: Binding<Int>
    var viewableItems: Binding<Int>

    var totalOffer: Int {
        layoutState?.items[LayoutState.totalItemsKey] as? Int ?? 1
    }
    private var cancellable: AnyCancellable?

    init(
        indicator: String,
        defaultStyle: [ProgressIndicatorStyles]?,
        indicatorStyle: [IndicatorStyles]?,
        activeIndicatorStyle: [IndicatorStyles]?,
        seenIndicatorStyle: [IndicatorStyles]?,
        startPosition: Int32?,
        accessibilityHidden: Bool?,
        layoutState: any LayoutStateRepresenting,
        eventService: EventDiagnosticServicing?
    ) {
        self.indicator = indicator

        self.defaultStyle = defaultStyle
        self.indicatorStyle = indicatorStyle
        self.seenIndicatorStyle = seenIndicatorStyle
        self.activeIndicatorStyle = activeIndicatorStyle
        self.startPosition = startPosition
        self.accessibilityHidden = accessibilityHidden
        self.layoutState = layoutState
        self.eventService = eventService
        self.viewableItems = layoutState.items[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
        self.currentIndex = layoutState.items[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)

        cancellable = layoutState.itemsPublisher.sink { [weak self] newValue in
            guard let self else { return }
            self.viewableItems = newValue[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
            self.currentIndex = newValue[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)
        }
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
    }

    func updateDataBinding(dataBinding: DataBinding<String>) {
        self.dataBinding = dataBinding
    }

    static func performDataExpansion(value: String?) -> String? {
        guard let value,
              let valueAsInt = Int(value)
        else { return value }

        return "\(valueAsInt + 1)"
    }
}
