import Foundation
import DcuiSchema

@available(iOS 15, *)
class CarouselViewModel: DistributionViewModel, Identifiable, ObservableObject {
    let id: UUID = UUID()
    var children: [LayoutSchemaViewModel]?

    var totalOffers: Int {
        children?.count ?? 0
    }

    var totalPages: Int {
        pages.count
    }

    var pages: [[LayoutSchemaViewModel]] {
        guard let children else {
            return []
        }
        return stride(from: 0, to: totalOffers, by: viewableItems).map {
            Array(children[$0..<$0.advanced(by: min(viewableItems, children.endIndex - $0))])
        }
    }

    let defaultStyle: [CarouselDistributionStyles]?
    let allBreakpointViewableItems: [UInt8]
    let peekThroughSize: [PeekThroughSize]
    @Published var currentPage: Int = 0
    @Published var indexWithinPage: Int = 0
    @Published var viewableItems: Int = 1
    @Published var breakpointIndex: Int = 0
    @Published var frameChangeIndex: Int = 0
    @Published var customStateMap: RoktUXCustomStateMap?

    /// The left most offer index in a RTL layout
    @Published var currentLeadingOfferIndex: Int = 0

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(children: [LayoutSchemaViewModel]?,
         defaultStyle: [CarouselDistributionStyles]?,
         viewableItems: [UInt8],
         peekThroughSize: [PeekThroughSize],
         eventService: EventServicing?,
         slots: [SlotModel],
         layoutState: any LayoutStateRepresenting) {
        self.children = children ?? []
        self.defaultStyle = defaultStyle
        self.allBreakpointViewableItems = viewableItems
        self.peekThroughSize = peekThroughSize

        // Calculate initial page before super.init
        if let initialIndex = layoutState.items[LayoutState.currentProgressKey] as? Int,
           let childrenCount = children?.count,
           let firstViewableItems = viewableItems.first.map(Int.init) {
            let viewableItemCount = min(firstViewableItems, childrenCount)
            if initialIndex + viewableItemCount > childrenCount - 1 {
                self.currentPage = (childrenCount - viewableItemCount)/viewableItemCount
            } else if initialIndex >= 0 {
                self.currentPage = initialIndex/viewableItemCount
            }
        }

        super.init(eventService: eventService, slots: slots, layoutState: layoutState)

        self.currentLeadingOfferIndex = (self.currentPage * self.viewableItems)
        self.indexWithinPage = 0
        self.customStateMap = initialCustomStateMap ?? RoktUXCustomStateMap()
    }

    func sendViewableImpressionEvents(currentLeadingOffer: Int) {
        for offer in currentLeadingOffer..<currentLeadingOffer + viewableItems {
            sendImpressionEvents(currentOffer: offer)
        }
    }

    func getGlobalBreakpointIndex(_ width: CGFloat?) -> Int {
        layoutState?.getGlobalBreakpointIndex(width) ?? 0
    }

    func setupLayoutState() {
        layoutState?.actionCollection[.progressControlPrevious] = goToPreviousPage
        layoutState?.actionCollection[.progressControlNext] = goToNextPage
        layoutState?.actionCollection[.nextOffer] = goToNextOffer
        layoutState?.actionCollection[.toggleCustomState] = toggleCustomState

        // Store the raw values instead of bindings
        layoutState?.items[LayoutState.totalItemsKey] = children?.count ?? 0
        layoutState?.items[LayoutState.viewableItemsKey] = viewableItems
        layoutState?.items[LayoutState.customStateMap] = customStateMap
    }

    private func toggleCustomState(_ customStateId: Any?) {
        var mutatingCustomStateMap: RoktUXCustomStateMap = customStateMap ?? RoktUXCustomStateMap()
        self.customStateMap = mutatingCustomStateMap.toggleValueFor(customStateId)
    }

    func goToNextOffer(_: Any?) {
        guard viewableItems == 1 else { return }
        if currentPage + 1 < children?.count ?? 0 {
            self.currentPage += 1
            self.currentLeadingOfferIndex = (self.currentPage * self.viewableItems)
            self.indexWithinPage = 0
        } else if layoutState?.closeOnComplete() == true {
            // when on last offer AND closeOnComplete is true
            closeOnComplete()
        }
    }

    func goToNextPage(_: Any?) {
        let totalPages = calculateTotalPages()
        if currentPage < totalPages - 1 {
            self.currentPage += 1
            self.currentLeadingOfferIndex = (self.currentPage * self.viewableItems)
            self.indexWithinPage = 0
        } else if layoutState?.closeOnComplete() == true {
            closeOnComplete()
        }
    }

    func goToPreviousPage(_: Any?) {
        let newCurrentPage = if indexWithinPage == 0 && currentPage != 0 {
            currentPage - 1
        } else {
            currentPage
        }
        self.currentPage = newCurrentPage
        self.indexWithinPage = 0
        self.currentLeadingOfferIndex = self.currentPage * self.viewableItems
    }

    func updateStatesOnDragEnded(_ roundProgress: Int) {
        if viewableItems > 1 {
            let projectedLeadingOffer = currentLeadingOfferIndex + roundProgress

            if projectedLeadingOffer + viewableItems > totalOffers - 1 {
                // if projected to go above totalOffers, update to last page
                currentPage = totalPages - 1
                indexWithinPage = pages[currentPage].count - viewableItems
                currentLeadingOfferIndex = totalOffers - viewableItems
            } else if projectedLeadingOffer >= 0, currentPage <= totalPages - 1 {
                // ensure projectedLeadingOffer above 0 and currentPage below totalPages
                currentPage = Int(floor(Double(projectedLeadingOffer/viewableItems)))
                indexWithinPage = projectedLeadingOffer % viewableItems
                currentLeadingOfferIndex = projectedLeadingOffer
            }
        } else {
            // ensure currentPage is never below 0 or above totalPages for 1 viewable item
            currentPage = max(min(currentPage + roundProgress, totalPages - 1), 0)
            currentLeadingOfferIndex = currentPage
        }
    }

    func setRecalculatedCurrentPage() {
        if currentLeadingOfferIndex + viewableItems > totalOffers - 1 {
            // if projected to go above totalOffers, update to last page
            currentPage = totalPages - 1
            indexWithinPage = pages[currentPage].count - viewableItems
        } else if currentLeadingOfferIndex >= 0,
                  currentPage <= totalPages - 1 {
            // ensure projectedLeadingOffer above 0 and currentPage below totalPages
            currentPage = Int(floor(Double(currentLeadingOfferIndex/viewableItems)))
            indexWithinPage = currentLeadingOfferIndex % viewableItems
        }
    }

    func globalScreenSizeUpdated(_ width: CGFloat?) {
        breakpointIndex = getGlobalBreakpointIndex(width)
        setViewableItemsForBreakpoint()
        setRecalculatedCurrentPage()
        // set viewableItems first then send impressions for offers based on viewableItems
        // duplicated events will be filtered out
        sendViewableImpressionEvents(currentLeadingOffer: currentLeadingOfferIndex)
        frameChangeIndex += 1
    }

    private func closeOnComplete() {
        // when on last offer AND closeOnComplete is true
        if case .embeddedLayout = layoutState?.layoutType() {
            sendDismissalCollapsedEvent()
        } else {
            sendDismissalNoMoreOfferEvent()
        }
        close()
    }

    func close() {
        layoutState?.actionCollection[.close](nil)
    }

    private func calculateTotalPages() -> Int {
        guard let children = children, !children.isEmpty else { return 0 }
        let viewableItemCount = Int(allBreakpointViewableItems[getGlobalBreakpointIndex(nil)])
        return Int(ceil(Double(children.count)/Double(viewableItemCount)))
    }

    private func setViewableItemsForBreakpoint() {
        let maxViewableItemsIndex = (allBreakpointViewableItems.count) - 1
        let index = max(min(breakpointIndex, maxViewableItemsIndex), 0)

        let viewableItemsFromBreakpoints = Int(allBreakpointViewableItems[index])
        // ensure viewableItems doesn't exceed totalOffers
        viewableItems = (viewableItemsFromBreakpoints < totalOffers) ? viewableItemsFromBreakpoints : totalOffers
    }
}
