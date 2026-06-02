import Foundation
import DcuiSchema
import Combine

@available(iOS 15, *)
class CatalogDropdownViewModel: Identifiable, Hashable, ScreenSizeAdaptive {
    let id: UUID = UUID()

    let ownStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?
    let headStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?
    let iconStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?
    let optionListStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?
    let optionStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?
    let errorStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?

    let placeholderValue: String?
    let unavailableValue: String?
    let validatorFieldConfig: ValidatorFieldConfig?
    let a11yLabel: String?

    /// Which attribute in `catalogItemGroup.attributes` this dropdown represents.
    let attributeIndex: Int

    weak var layoutState: (any LayoutStateRepresenting)?
    weak var eventService: EventServicing?

    // ScreenSizeAdaptive conformance
    var defaultStyle: [CatalogDropdownStyles]? {
        ownStyles?.compactMap { $0.default }
    }

    var imageLoader: RoktUXImageLoader? {
        layoutState?.imageLoader
    }

    init(ownStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?,
         headStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?,
         iconStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?,
         optionListStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?,
         optionStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?,
         errorStyles: [FormStateStylingBlock<CatalogDropdownStyles>]?,
         placeholderValue: String?,
         unavailableValue: String?,
         validatorFieldConfig: ValidatorFieldConfig?,
         a11yLabel: String?,
         attributeIndex: Int = 0,
         layoutState: (any LayoutStateRepresenting)?,
         eventService: EventServicing?) {
        self.ownStyles = ownStyles
        self.headStyles = headStyles
        self.iconStyles = iconStyles
        self.optionListStyles = optionListStyles
        self.optionStyles = optionStyles
        self.errorStyles = errorStyles
        self.placeholderValue = placeholderValue
        self.unavailableValue = unavailableValue
        self.validatorFieldConfig = validatorFieldConfig
        self.a11yLabel = a11yLabel
        self.attributeIndex = attributeIndex
        self.layoutState = layoutState
        self.eventService = eventService
    }

    // MARK: - Data Access

    var catalogItemGroup: CatalogItemGroup? {
        guard let offer = layoutState?.items[LayoutState.fullOfferKey] as? OfferModel else { return nil }
        return offer.catalogItemGroup
    }

    var catalogItems: [CatalogItem]? {
        guard let offer = layoutState?.items[LayoutState.fullOfferKey] as? OfferModel else { return nil }
        return offer.catalogItems
    }

    /// The attribute this dropdown is bound to.
    var attribute: CatalogItemGroupAttribute? {
        guard let attributes = catalogItemGroup?.attributes,
              attributeIndex < attributes.count else { return nil }
        return attributes[attributeIndex]
    }

    var options: [CatalogItemGroupOption] {
        attribute?.options ?? []
    }

    var attributeLabel: String? {
        attribute?.label
    }

    /// Returns the set of `catalogItemIds` that are still eligible based on
    /// selections made in *other* attribute dropdowns.
    private var eligibleCatalogItemIds: Set<String> {
        guard let group = catalogItemGroup,
              let attributes = group.attributes,
              let selections = layoutState?.items[LayoutState.catalogDropdownSelectedIndexKey] as? [Int: Int]
        else {
            // No constraints — all group items are eligible
            return Set(catalogItemGroup?.catalogItemIds ?? [])
        }

        var eligible = Set(group.catalogItemIds)

        for (attrIdx, optionIdx) in selections where attrIdx != attributeIndex {
            guard attrIdx < attributes.count,
                  let opts = attributes[attrIdx].options,
                  optionIdx < opts.count,
                  let itemIds = opts[optionIdx].catalogItemIds
            else { continue }
            eligible = eligible.intersection(itemIds)
        }

        return eligible
    }

    func catalogItem(for option: CatalogItemGroupOption) -> CatalogItem? {
        guard let catalogItemId = option.catalogItemIds?.first,
              let items = catalogItems else { return nil }
        return items.first { $0.catalogItemId == catalogItemId }
    }

    /// An option is disabled if it has no eligible items when intersected with
    /// the current cross-attribute selection, or if all its items are out of stock.
    func isOptionDisabled(at index: Int) -> Bool {
        guard index < options.count else { return false }
        let option = options[index]
        guard let optionItemIds = option.catalogItemIds else { return false }

        let eligible = eligibleCatalogItemIds
        let intersected = eligible.intersection(optionItemIds)

        // No items remain after cross-attribute filtering
        if intersected.isEmpty { return true }

        // All remaining items are out of stock
        guard let items = catalogItems else { return false }
        let matchingItems = items.filter { intersected.contains($0.catalogItemId) }
        return matchingItems.allSatisfy {
            $0.inventoryStatus?.caseInsensitiveCompare("OutOfStock") == .orderedSame
        }
    }

    // MARK: - Selection State

    /// Selection state keyed by attribute index: `[attributeIndex: optionIndex]`
    var persistedSelectedIndex: Int? {
        get {
            guard let dict = layoutState?.items[LayoutState.catalogDropdownSelectedIndexKey] as? [Int: Int] else {
                return nil
            }
            return dict[attributeIndex]
        }
        set {
            var dict = (layoutState?.items[LayoutState.catalogDropdownSelectedIndexKey] as? [Int: Int]) ?? [:]
            dict[attributeIndex] = newValue
            layoutState?.items[LayoutState.catalogDropdownSelectedIndexKey] = dict
        }
    }

    func displayText(for selectedIndex: Int?) -> String {
        if let index = selectedIndex, index < options.count {
            let option = options[index]
            if isOptionDisabled(at: index) {
                return unavailableValue ?? option.label ?? ""
            }
            return option.label ?? ""
        }
        return placeholderValue ?? attributeLabel ?? ""
    }

    func selectItem(at index: Int) {
        guard index < options.count, !isOptionDisabled(at: index) else { return }

        persistedSelectedIndex = index

        // Resolve the active catalog item from the intersection of all selections
        if let resolvedItem = resolveActiveCatalogItem() {
            layoutState?.items[LayoutState.activeCatalogItemKey] = resolvedItem
        }

        layoutState?.publishStateChange()
    }

    /// Resolves the single catalog item matching all current attribute selections.
    /// Returns `nil` if not all attributes have been selected yet.
    private func resolveActiveCatalogItem() -> CatalogItem? {
        guard let group = catalogItemGroup,
              let attributes = group.attributes,
              let selections = layoutState?.items[LayoutState.catalogDropdownSelectedIndexKey] as? [Int: Int],
              let items = catalogItems
        else { return nil }

        var candidateIds = Set(group.catalogItemIds)

        for (attrIdx, optionIdx) in selections {
            guard attrIdx < attributes.count,
                  let opts = attributes[attrIdx].options,
                  optionIdx < opts.count,
                  let itemIds = opts[optionIdx].catalogItemIds
            else { continue }
            candidateIds = candidateIds.intersection(itemIds)
        }

        // Return the first matching in-stock item, or the first match if all are out of stock
        let matching = items.filter { candidateIds.contains($0.catalogItemId) }
        return matching.first {
            $0.inventoryStatus?.caseInsensitiveCompare("OutOfStock") != .orderedSame
        } ?? matching.first
    }

    // MARK: - Hashable

    static func == (lhs: CatalogDropdownViewModel, rhs: CatalogDropdownViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
