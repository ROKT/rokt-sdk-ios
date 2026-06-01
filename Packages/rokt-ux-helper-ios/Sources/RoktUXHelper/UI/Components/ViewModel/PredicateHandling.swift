import Foundation
import DcuiSchema
import SwiftUI
import Combine

@available(iOS 13.0, *)
protocol PredicateHandling {
    var layoutState: (any LayoutStateRepresenting)? { get }
    var predicates: [WhenPredicate]? { get }
    var currentProgress: Binding<Int> { get }
    var totalItems: Int { get }
    var customStateMap: Binding<RoktUXCustomStateMap?> { get }
    var globalCustomStateMap: Binding<RoktUXCustomStateMap?> { get }
    var globalBreakPoints: BreakPoint? { get }
    var offers: [OfferModel?] { get }
    var width: CGFloat { get }
    var componentConfig: ComponentConfig? { get }
    var animate: Bool { get set }
    var cancellable: AnyCancellable? { get }

    func shouldApply(_ uiState: WhenComponentUIState) -> Bool
    func shouldApply() -> Bool
}

@available(iOS 13.0, *)
extension PredicateHandling {

    var placeholderResolver: PlaceholderPredicateResolver { PlaceholderPredicateResolver() }

    var currentProgress: Binding<Int> {
        layoutState?.items[LayoutState.currentProgressKey] as? Binding<Int> ?? .constant(0)
    }

    var viewableItems: Binding<Int> {
        layoutState?.items[LayoutState.viewableItemsKey] as? Binding<Int> ?? .constant(1)
    }

    var totalItems: Int {
        layoutState?.items[LayoutState.totalItemsKey] as? Int ?? 0
    }

    var customStateMap: Binding<RoktUXCustomStateMap?> {
        layoutState?.items[LayoutState.customStateMap] as? Binding<RoktUXCustomStateMap?> ?? .constant(nil)
    }

    var globalCustomStateMap: Binding<RoktUXCustomStateMap?> {
        layoutState?.items[LayoutState.globalCustomStateMapKey] as? Binding<RoktUXCustomStateMap?> ?? .constant(nil)
    }

    var activeCatalogItem: CatalogItem? {
        layoutState?.items[LayoutState.activeCatalogItemKey] as? CatalogItem
    }

    func shouldApply() -> Bool {
        shouldApply(
            WhenComponentUIState(
                currentProgress: currentProgress.wrappedValue,
                totalOffers: totalItems,
                position: componentConfig?.position ?? 0,
                width: width,
                isDarkMode: layoutState?.colorMode == .dark,
                customStateMap: customStateMap.wrappedValue,
                globalCustomStateMap: globalCustomStateMap.wrappedValue
            )
        )
    }

    private var darkModePredicates: [DarkModePredicate] {
        predicates?.compactMap {
            switch $0 {
            case .darkMode(let predicate): return predicate
            default: return nil
            }
        } ?? []
    }

    private var progressionPredicates: [ProgressionPredicate] { predicates?.compactMap {
        switch $0 {
        case .progression(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var breakPointPredicates: [BreakpointPredicate] { predicates?.compactMap {
        switch $0 {
        case .breakpoint(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var positionPredicates: [PositionPredicate] { predicates?.compactMap {
        switch $0 {
        case .position(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var staticBooleanPredicates: [StaticBooleanPredicate] { predicates?.compactMap {
        switch $0 {
        case .staticBoolean(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var creativeCopyPredicates: [CreativeCopyPredicate] { predicates?.compactMap {
        switch $0 {
        case .creativeCopy(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var staticStringPredicates: [StaticStringPredicate] { predicates?.compactMap {
        switch $0 {
        case .staticString(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var customStatePredicates: [CustomStatePredicate] { predicates?.compactMap {
        switch $0 {
        case .customState(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private var placeholderPredicates: [PlaceholderPredicate] { predicates?.compactMap {
        switch $0 {
        case .placeholder(let predicate): return predicate
        default: return nil
        }
    } ?? [] }

    private func progressionPredicatesMatched(currentProgress: Int) -> Bool? {
        // currentProgress refer to currentOffer in Onebyone and current page in carousel

        // don't apply if the predicates is empty
        guard !progressionPredicates.isEmpty else { return nil }

        // Predicates need to applied if all of the preicates are met.
        // The default is true and will be used by && operation on each predicates
        var matched = true

        progressionPredicates.forEach { predicate in
            if let value = Int(predicate.value) {
                // If the predicate value is negative, the value should be calculated from last
                // Eg: Total items = 4, Predicate value = -1 then the result should be 3(last position)
                //     Total items = 4, Predicate value = -2 then the result should be 2(second last position)
                let totalPages = Int(ceil(Double(totalItems))/Double(viewableItems.wrappedValue))
                let progression = value >= 0 ? value : totalPages + value
                switch predicate.condition {
                case .is:
                    matched = matched && currentProgress == progression
                case .isNot:
                    matched = matched && currentProgress != progression
                case .isAbove:
                    matched = matched && currentProgress > progression
                case .isBelow:
                    matched = matched && currentProgress < progression
                }
            }
        }

        return matched
    }

    private func positionPredicatesMatched(offerPosition: Int?, totalOffers: Int) -> Bool? {

        // don't apply if the predicates is empty
        guard !positionPredicates.isEmpty else { return nil }

        // position should not apply on outer layer to match web behaviour
        guard let offerPosition else { return false}

        // Predicates need to applied if all of the preicates are met.
        // The default is true and will be used by && operation on each predicates
        var matched = true

        positionPredicates.forEach { predicate in
            if let value = Int(predicate.value) {
                // If the predicate value is negative, the value should be calculated from last
                // Eg: Total offers = 4, Predicate value = -1 then the result should be 3(last position)
                //     Total offers = 4, Predicate value = -2 then the result should be 2(second last position)
                let position = value >= 0 ? value : totalOffers + value

                switch predicate.condition {
                case .is:
                    matched = matched && offerPosition == position
                case .isNot:
                    matched = matched && offerPosition != position
                case .isAbove:
                    matched = matched && offerPosition > position
                case .isBelow:
                    matched = matched && offerPosition < position
                }
            }
        }

        return matched
    }

    private func breakPointOrientationPredicatesMatched(width: CGFloat) -> Bool? {
        guard !breakPointPredicates.isEmpty,
                let globalBreakPoints, !globalBreakPoints.isEmpty
        else { return nil }

        var matched = true

        breakPointPredicates.forEach { predicate in
            if let globalBreakPointValue = globalBreakPoints[predicate.value] {
                switch predicate.condition {
                case .is:
                    matched = matched && Double(width).precised() == (Double(globalBreakPointValue).precised())
                case .isNot:
                    matched = matched && Double(width).precised() != (Double(globalBreakPointValue).precised())
                case .isAbove:
                    matched = matched && Double(width).precised() > (Double(globalBreakPointValue).precised())
                case .isBelow:
                    matched = matched && Double(width).precised() < (Double(globalBreakPointValue).precised())
                }
            }
        }

        return matched
    }

    private func darkModePredicatesMatched(isDarkMode: Bool) -> Bool? {
        // don't apply if the predicates is empty
        guard !darkModePredicates.isEmpty else { return nil }

        // Predicates need to applied if all of the predicates are met.
        // The default is true and will be used by && operation on each predicate
        var matched = true

        darkModePredicates.forEach { predicate in
            switch predicate.condition {
            case .is:
                matched = matched && isDarkMode == predicate.value
            case .isNot:
                matched = matched && isDarkMode != predicate.value
            }
        }

        return matched
    }

    private func staticBooleanPredicatesMatched() -> Bool? {

        guard !staticBooleanPredicates.isEmpty else { return nil }

        // Predicates need to applied if all of the predicates are met.
        // The default is true and will be used by && operation on each predicate
        var matched = true

        staticBooleanPredicates.forEach { predicate in
            switch predicate.condition {
            case .isTrue:
                matched = matched && predicate.value
            case .isFalse:
                matched = matched && !predicate.value
            }
        }

        return matched
    }

    private func creativeCopyMatched(offerPosition: Int) -> Bool? {
        guard !creativeCopyPredicates.isEmpty else { return nil }

        // Predicates need to applied if all of the predicates are met.
        // The default is true and will be used by && operation on each predicate
        var matched = true

        creativeCopyPredicates.forEach { predicate in
            let value = predicate.value

            switch predicate.condition {
            case .exists:
                matched = matched &&
                    (!(getCreativeCopy(offerPosition)[value] ?? "").isEmpty || !(getCatalogCopy()[value] ?? "").isEmpty)
            case .notExists:
                matched = matched && (getCreativeCopy(offerPosition)[value] == nil && getCatalogCopy()[value] == nil)
            }
        }

        return matched
    }

    private func getCreativeCopy(_ offerPosition: Int) -> [String: String] {
        guard offers.count > offerPosition else { return [:] }
        return offers[offerPosition]?.creative.copy ?? [:]
    }

    private func getCatalogCopy() -> [String: String] {
        return activeCatalogItem?.copy ?? [:]
    }

    private func staticStringPredicatesMatched() -> Bool? {

        guard !staticStringPredicates.isEmpty else { return nil }

        // Predicates need to applied if all of the predicates are met.
        // The default is true and will be used by && operation on each predicate
        var matched = true

        staticStringPredicates.forEach { predicate in
            switch predicate.condition {
            case .is:
                matched = matched && (predicate.input == predicate.value)
            case .isNot:
                matched = matched && (predicate.input != predicate.value)
            }
        }

        return matched
    }

    private func customStatePredicatesMatched(customStateMap: RoktUXCustomStateMap?,
                                              globalCustomStateMap: RoktUXCustomStateMap?,
                                              position: Int?) -> Bool? {
        guard !customStatePredicates.isEmpty else { return nil }

        // Predicates need to applied if all of the predicates are met.
        // The default is true and will be used by && operation on each predicate
        var matched = true

        customStatePredicates.forEach { predicate in
            let localIdentifier = CustomStateIdentifiable(position: position, key: predicate.key)
            let globalIdentifier = CustomStateIdentifiable(position: nil, key: predicate.key)
            let customStateValue: Int
            if let position,
               let localValue = customStateMap?[localIdentifier] {
                customStateValue = localValue
            } else if let globalValue = globalCustomStateMap?[globalIdentifier] {
                customStateValue = globalValue
            } else {
                customStateValue = 0
            }
            switch predicate.condition {
            case .is:
                matched = matched && customStateValue == predicate.value
            case .isNot:
                matched = matched && customStateValue != predicate.value
            case .isAbove:
                matched = matched && customStateValue > predicate.value
            case .isBelow:
                matched = matched && customStateValue < predicate.value
            }
        }

        return matched
    }

    func shouldApply(_ uiState: WhenComponentUIState) -> Bool {

        let progressionMatched = progressionPredicatesMatched(currentProgress: uiState.currentProgress)
        let positionMatched = positionPredicatesMatched(offerPosition: uiState.position,
                                                        totalOffers: uiState.totalOffers)
        let breakPointsMatched = breakPointOrientationPredicatesMatched(width: uiState.width)
        let darkModeMatched = darkModePredicatesMatched(isDarkMode: uiState.isDarkMode)
        let staticBooleanMatched = staticBooleanPredicatesMatched()
        let creativeCopyMatched = creativeCopyMatched(offerPosition: uiState.currentProgress)
        let staticStringMatched = staticStringPredicatesMatched()
        let customStateMatched = customStatePredicatesMatched(customStateMap: uiState.customStateMap,
                                                              globalCustomStateMap: uiState.globalCustomStateMap,
                                                              position: uiState.position)
        let placeholderMatched = placeholderPredicatesMatched(uiState: uiState)

        if progressionMatched == nil &&
            breakPointsMatched == nil &&
            positionMatched == nil &&
            darkModeMatched == nil &&
            staticBooleanMatched == nil &&
            creativeCopyMatched == nil &&
            staticStringMatched == nil &&
            customStateMatched == nil &&
            placeholderMatched == nil { return true }

        var matched = true

        if let progressionMatched {
            matched = matched && progressionMatched
        }

        if let positionMatched {
            matched = matched && positionMatched
        }

        if let breakPointsMatched {
            matched = matched && breakPointsMatched
        }

        if let darkModeMatched {
            matched = matched && darkModeMatched
        }

        if let staticBooleanMatched {
            matched = matched && staticBooleanMatched
        }

        if let creativeCopyMatched {
            matched = matched && creativeCopyMatched
        }

        if let staticStringMatched {
            matched = matched && staticStringMatched
        }

        if let customStateMatched {
            matched = matched && customStateMatched
        }

        if let placeholderMatched {
            matched = matched && placeholderMatched
        }

        return matched
    }

    private func placeholderPredicatesMatched(uiState: WhenComponentUIState) -> Bool? {
        guard !placeholderPredicates.isEmpty else { return nil }

        let context = PlaceholderResolutionContext(offers: offers,
                                                   currentOfferIndex: uiState.currentProgress,
                                                   activeCatalogItem: activeCatalogItem)

        var matched = true

        placeholderPredicates.forEach { predicate in
            switch predicate {
            case .textValue(let stringPredicate):
                let resolved = placeholderResolver.resolveString(placeholder: stringPredicate.input,
                                                                 context: context)
                // Resolve the RHS value as a placeholder too, falling back to the literal string
                let expectedValue = placeholderResolver.resolveString(placeholder: stringPredicate.value,
                                                                      context: context) ?? stringPredicate.value
                switch stringPredicate.condition {
                case .is:
                    matched = matched && resolved == expectedValue
                case .isNot:
                    matched = matched && resolved != expectedValue
                case .exists:
                    matched = matched && resolved != nil && !resolved!.isEmpty
                case .notExists:
                    matched = matched && (resolved == nil || resolved!.isEmpty)
                }
            case .textLength(let lengthPredicate):
                guard let resolvedLength = placeholderResolver.resolveTextLength(placeholder: lengthPredicate.input,
                                                                                 context: context) else {
                    matched = false
                    return
                }
                let expectedInt: Int
                if let resolved = placeholderResolver.resolveInt(placeholder: lengthPredicate.value, context: context) {
                    expectedInt = resolved
                } else if let literal = Int(lengthPredicate.value) {
                    expectedInt = literal
                } else {
                    matched = false
                    return
                }
                switch lengthPredicate.condition {
                case .is:
                    matched = matched && resolvedLength == expectedInt
                case .isNot:
                    matched = matched && resolvedLength != expectedInt
                case .isAbove:
                    matched = matched && resolvedLength > expectedInt
                case .isBelow:
                    matched = matched && resolvedLength < expectedInt
                }
            case .numeric(let numericPredicate):
                guard let resolvedInputDecimal = placeholderResolver.resolveDecimal(placeholder: numericPredicate.input,
                                                                                    context: context) else {
                    matched = false
                    return
                }
                let expectedDecimal: Decimal
                if let resolved = placeholderResolver.resolveDecimal(placeholder: numericPredicate.value, context: context) {
                    expectedDecimal = resolved
                } else if let literal = Decimal(string: numericPredicate.value) {
                    expectedDecimal = literal
                } else {
                    matched = false
                    return
                }
                switch numericPredicate.condition {
                case .is:
                    matched = matched && resolvedInputDecimal == expectedDecimal
                case .isNot:
                    matched = matched && resolvedInputDecimal != expectedDecimal
                case .isAbove:
                    matched = matched && resolvedInputDecimal > expectedDecimal
                case .isBelow:
                    matched = matched && resolvedInputDecimal < expectedDecimal
                }
            }
        }

        return matched
    }
}
