import XCTest
import SwiftUI
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15, *)
final class TestWhenViewModel: XCTestCase {
    
    func get_when_view_model(children: [LayoutSchemaViewModel]? = [],
                             predicates: [WhenPredicate]? = [],
                             transition: WhenTransition? = nil,
                             copy: [String: String] = [String: String](),
                             breakPoint: BreakPoint? = nil,
                             layoutState: LayoutState = LayoutState(),
                             catalogItem: CatalogItem? = nil) -> WhenViewModel {
        if let catalogItem = catalogItem {
            layoutState.items[LayoutState.activeCatalogItemKey] = catalogItem
        }
        return WhenViewModel(children: children,
                             predicates: predicates,
                             transition: transition,
                             offers: [get_slot_offer(copy: copy, catalogItems: catalogItem.map { [$0] })],
                             globalBreakPoints: breakPoint,
                             layoutState: layoutState)
    }
    
    func test_should_apply_progression_is_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "0")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_progression_is_invalid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_progression_is_not_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isNot, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_progression_is_not_invalid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isNot, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 1))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_progression_above_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isAbove, value: "0")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 1))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_progression_above_invalid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isAbove, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_progression_below_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isBelow, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_progression_below_invalid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isBelow, value: "2")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 3, totalOffers: 3))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_progression_negative_is_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "-1")
        )
        let layoutState = LayoutState()
        layoutState.items[LayoutState.totalItemsKey] = 3
        let whenVM = get_when_view_model(predicates: [predicate], layoutState: layoutState)
        // Act - totalOffers: 3, currentProgress: 2, expecting progression "-1" to match position 2 (3 + (-1) = 2)
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 2, totalOffers: 3))

        // Assert
        XCTAssertTrue(shouldApply)
    }

    func test_should_apply_progression_negative_is_invalid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "-1")
        )
        let layoutState = LayoutState()
        layoutState.items[LayoutState.totalItemsKey] = 3
        let whenVM = get_when_view_model(predicates: [predicate], layoutState: layoutState)
        // Act - totalOffers: 3, currentProgress: 1, expecting progression "-1" to match position 2 (3 + (-1) = 2), but current is 1
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 1, totalOffers: 3))

        // Assert
        XCTAssertFalse(shouldApply)
    }

    func test_should_apply_progression_negative_above_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isAbove, value: "-2")
        )
        let layoutState = LayoutState()
        layoutState.items[LayoutState.totalItemsKey] = 4
        let whenVM = get_when_view_model(predicates: [predicate], layoutState: layoutState)
        // Act - totalOffers: 4, progression "-2" equals 2 (4 + (-2) = 2), currentProgress: 3 should be above 2
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 3, totalOffers: 4))

        // Assert
        XCTAssertTrue(shouldApply)
    }

    func test_should_apply_progression_negative_below_valid() {
        // Arrange
        let predicate = WhenPredicate.progression(
            ProgressionPredicate(condition: .isBelow, value: "-1")
        )
        let layoutState = LayoutState()
        layoutState.items[LayoutState.totalItemsKey] = 5
        let whenVM = get_when_view_model(predicates: [predicate], layoutState: layoutState)
        // Act - totalOffers: 5, progression "-1" equals 4 (5 + (-1) = 4), currentProgress: 3 should be below 4
        let shouldApply = whenVM.shouldApply(get_mock_uistate(currentProgress: 3, totalOffers: 5))

        // Assert
        XCTAssertTrue(shouldApply)
    }

    // MARK: position

    func test_should_apply_position_is_valid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "0")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_position_negative_is_valid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "-1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(totalOffers: 2, position: 1))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_position_is_invalid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_position_negative_is_invalid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "-1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(totalOffers: 2, position: 0))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_empty_position_false() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "0")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: nil))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_position_is_not_valid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .isNot, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_position_is_not_invalid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .isNot, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 1))
        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_position_above_valid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .isAbove, value: "0")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 1))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_position_above_invalid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .isAbove, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 1))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_position_below_valid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .isBelow, value: "1")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_position_below_invalid() {
        // Arrange
        let predicate = WhenPredicate.position(
            PositionPredicate(condition: .isBelow, value: "2")
        )
        let whenVM = get_when_view_model(predicates: [predicate])
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(totalOffers: 3, position: 3))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    // MARK: Breakpoint
    
    func test_should_apply_breakpoint_is_valid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .is, value: "mobile")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 1))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_invalid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .is, value: "mobile")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 501))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_not_valid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .isNot, value: "mobile")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 501))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_not_invalid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .isNot, value: "mobile")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 1))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_below_valid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .isBelow, value: "tablet")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 200))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_below_invalid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .isBelow, value: "tablet")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 600))

        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_above_valid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .isAbove, value: "tablet")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 1000))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    func test_should_apply_breakpoint_is_above_invalid() {
        // Arrange
        let predicate = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .isAbove, value: "tablet")
        )
        let whenVM = get_when_view_model(predicates: [predicate], breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 400))

        // Assert
        XCTAssertFalse(shouldApply)
    }

    // MARK: - Dark Mode

    func test_shouldNOTApply_whenConditionEqualsIsAndValueEqualsTrue_andDarkModeIsFalse_shouldNotApply() {
        let predicate = WhenPredicate.darkMode(DarkModePredicate(condition: .is, value: true))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsAndValueEqualsFalse_andDarkModeIsFalse_shouldNotApply() {
        let predicate = WhenPredicate.darkMode(DarkModePredicate(condition: .is, value: false))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsNotAndValueEqualsTrue_andDarkModeIsFalse_shouldApply() {
        let predicate = WhenPredicate.darkMode(DarkModePredicate(condition: .isNot, value: true))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIsNotAndValueEqualsFalse_andDarkModeIsFalse_shouldNotApply() {
        let predicate = WhenPredicate.darkMode(DarkModePredicate(condition: .isNot, value: false))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }
    
    // MARK: - StaticBoolean

    func test_shouldNotApply_whenConditionEqualsIsTrue_valueEqualsFalse() {
        let predicate = WhenPredicate.staticBoolean(StaticBooleanPredicate(condition: .isTrue, value: false))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsTrue_valueEqualsTrue() {
        let predicate = WhenPredicate.staticBoolean(StaticBooleanPredicate(condition: .isTrue, value: true))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }
    
    func test_shouldNotApply_whenConditionEqualsIsFalse_valueEqualsTrue() {
        let predicate = WhenPredicate.staticBoolean(StaticBooleanPredicate(condition: .isFalse, value: true))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsFalse_valueEqualsFalse() {
        let predicate = WhenPredicate.staticBoolean(StaticBooleanPredicate(condition: .isFalse, value: false))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }
    
    // MARK: - CreativeCopy

    func test_shouldApply_whenCreativeCopy_exists() {
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let whenVM = get_when_view_model(predicates: [predicate],
                                         copy: [ "creative.title": "Awesome offer"])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }   
    
    func test_shouldNotApply_whenCreativeCopy_notExists() {
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }    
    
    func test_shouldNotApply_whenCreativeCopy_notExists_differentValue() {
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let whenVM = get_when_view_model(predicates: [predicate], copy: ["creative.copy": "Awesome offer"])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }       
    
    func test_shouldNotApply_whenCreativeCopy_notExists_emptyValue() {
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let whenVM = get_when_view_model(predicates: [predicate], copy: ["creative.title": ""])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }    
    
    func test_shouldNotApply_whenCreativeCopy_multiple() {
        let predicate1 = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let predicate2 = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.copy"))
        let whenVM = get_when_view_model(predicates: [predicate1, predicate2], copy: ["creative.title": "Awesome offer"])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }    
    
    func test_shouldApply_whenCreativeCopy_multiple() {
        let predicate1 = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let predicate2 = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.copy"))
        let whenVM = get_when_view_model(
            predicates: [predicate1, predicate2],
            copy: ["creative.title": "Awesome offer", "creative.copy": "For you"]
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }
    
    // MARK: - CreativeCopy with CatalogCopy Fallback

    func test_shouldApply_whenCatalogCopy_exists_creativeNotExists() {
        // When creative copy doesn't have the key but catalog copy does
        let layoutState = LayoutState()
        let catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "key1"))
        let whenVM = get_when_view_model(predicates: [predicate], layoutState: layoutState, catalogItem: catalogItem)

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply, "Should apply when catalog copy contains the key even if creative copy doesn't")
    }

    func test_shouldApply_whenCreativeCopy_exists_catalogNotExists() {
        // When creative copy has the key but catalog copy doesn't
        var catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        catalogItem = CatalogItem(
            images: catalogItem.images,
            catalogItemId: catalogItem.catalogItemId,
            cartItemId: catalogItem.cartItemId,
            instanceGuid: catalogItem.instanceGuid,
            title: catalogItem.title,
            description: catalogItem.description,
            price: catalogItem.price,
            priceFormatted: catalogItem.priceFormatted,
            originalPrice: catalogItem.originalPrice,
            originalPriceFormatted: catalogItem.originalPriceFormatted,
            currency: catalogItem.currency,
            signalType: catalogItem.signalType,
            url: catalogItem.url,
            minItemCount: catalogItem.minItemCount,
            maxItemCount: catalogItem.maxItemCount,
            preSelectedQuantity: catalogItem.preSelectedQuantity,
            providerData: catalogItem.providerData,
            urlBehavior: catalogItem.urlBehavior,
            positiveResponseText: catalogItem.positiveResponseText,
            negativeResponseText: catalogItem.negativeResponseText,
            addOns: catalogItem.addOns,
            copy: [:], // Empty catalog copy
            inventoryStatus: nil,
            linkedProductId: catalogItem.linkedProductId,
            token: catalogItem.token
        )

        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "creative.title"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: ["creative.title": "Awesome offer"],
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply, "Should apply when creative copy contains the key even if catalog copy doesn't")
    }

    func test_shouldApply_whenBoth_creativeCopy_and_catalogCopy_exist() {
        // When both creative and catalog copy have the key
        let layoutState = LayoutState()
        let catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "key1"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: ["key1": "creative value"],
            layoutState: layoutState,
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply, "Should apply when both creative and catalog copy contain the key")
    }

    func test_shouldNotApply_whenNeither_creativeCopy_nor_catalogCopy_exist() {
        // When neither creative nor catalog copy have the key
        var catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        catalogItem = CatalogItem(
            images: catalogItem.images,
            catalogItemId: catalogItem.catalogItemId,
            cartItemId: catalogItem.cartItemId,
            instanceGuid: catalogItem.instanceGuid,
            title: catalogItem.title,
            description: catalogItem.description,
            price: catalogItem.price,
            priceFormatted: catalogItem.priceFormatted,
            originalPrice: catalogItem.originalPrice,
            originalPriceFormatted: catalogItem.originalPriceFormatted,
            currency: catalogItem.currency,
            signalType: catalogItem.signalType,
            url: catalogItem.url,
            minItemCount: catalogItem.minItemCount,
            maxItemCount: catalogItem.maxItemCount,
            preSelectedQuantity: catalogItem.preSelectedQuantity,
            providerData: catalogItem.providerData,
            urlBehavior: catalogItem.urlBehavior,
            positiveResponseText: catalogItem.positiveResponseText,
            negativeResponseText: catalogItem.negativeResponseText,
            addOns: catalogItem.addOns,
            copy: [:], // Empty catalog copy
            inventoryStatus: nil,
            linkedProductId: catalogItem.linkedProductId,
            token: catalogItem.token
        )

        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "nonexistent.key"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: [:], // Empty creative copy
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply, "Should not apply when neither creative nor catalog copy contain the key")
    }

    func test_shouldApply_whenCatalogCopy_exists_withEmptyString_shouldNotApply() {
        // When catalog copy has the key but with empty value
        var catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        catalogItem = CatalogItem(
            images: catalogItem.images,
            catalogItemId: catalogItem.catalogItemId,
            cartItemId: catalogItem.cartItemId,
            instanceGuid: catalogItem.instanceGuid,
            title: catalogItem.title,
            description: catalogItem.description,
            price: catalogItem.price,
            priceFormatted: catalogItem.priceFormatted,
            originalPrice: catalogItem.originalPrice,
            originalPriceFormatted: catalogItem.originalPriceFormatted,
            currency: catalogItem.currency,
            signalType: catalogItem.signalType,
            url: catalogItem.url,
            minItemCount: catalogItem.minItemCount,
            maxItemCount: catalogItem.maxItemCount,
            preSelectedQuantity: catalogItem.preSelectedQuantity,
            providerData: catalogItem.providerData,
            urlBehavior: catalogItem.urlBehavior,
            positiveResponseText: catalogItem.positiveResponseText,
            negativeResponseText: catalogItem.negativeResponseText,
            addOns: catalogItem.addOns,
            copy: ["key1": ""], // Empty string value
            inventoryStatus: nil,
            linkedProductId: catalogItem.linkedProductId,
            token: catalogItem.token
        )

        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .exists, value: "key1"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: [:],
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply, "Should not apply when catalog copy value is empty string")
    }

    // MARK: - CreativeCopy notExists with CatalogCopy

    func test_shouldApply_whenCreativeCopy_notExists_catalogCopy_notExists() {
        // When neither creative nor catalog copy have the key
        var catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        catalogItem = CatalogItem(
            images: catalogItem.images,
            catalogItemId: catalogItem.catalogItemId,
            cartItemId: catalogItem.cartItemId,
            instanceGuid: catalogItem.instanceGuid,
            title: catalogItem.title,
            description: catalogItem.description,
            price: catalogItem.price,
            priceFormatted: catalogItem.priceFormatted,
            originalPrice: catalogItem.originalPrice,
            originalPriceFormatted: catalogItem.originalPriceFormatted,
            currency: catalogItem.currency,
            signalType: catalogItem.signalType,
            url: catalogItem.url,
            minItemCount: catalogItem.minItemCount,
            maxItemCount: catalogItem.maxItemCount,
            preSelectedQuantity: catalogItem.preSelectedQuantity,
            providerData: catalogItem.providerData,
            urlBehavior: catalogItem.urlBehavior,
            positiveResponseText: catalogItem.positiveResponseText,
            negativeResponseText: catalogItem.negativeResponseText,
            addOns: catalogItem.addOns,
            copy: [:], // Empty catalog copy
            inventoryStatus: nil,
            linkedProductId: catalogItem.linkedProductId,
            token: catalogItem.token
        )

        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .notExists, value: "nonexistent.key"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: [:],
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply, "Should apply when key doesn't exist in both creative and catalog copy")
    }

    func test_shouldNotApply_whenCreativeCopy_exists_notExists_condition() {
        // When creative copy has the key but condition is notExists
        var catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        catalogItem = CatalogItem(
            images: catalogItem.images,
            catalogItemId: catalogItem.catalogItemId,
            cartItemId: catalogItem.cartItemId,
            instanceGuid: catalogItem.instanceGuid,
            title: catalogItem.title,
            description: catalogItem.description,
            price: catalogItem.price,
            priceFormatted: catalogItem.priceFormatted,
            originalPrice: catalogItem.originalPrice,
            originalPriceFormatted: catalogItem.originalPriceFormatted,
            currency: catalogItem.currency,
            signalType: catalogItem.signalType,
            url: catalogItem.url,
            minItemCount: catalogItem.minItemCount,
            maxItemCount: catalogItem.maxItemCount,
            preSelectedQuantity: catalogItem.preSelectedQuantity,
            providerData: catalogItem.providerData,
            urlBehavior: catalogItem.urlBehavior,
            positiveResponseText: catalogItem.positiveResponseText,
            negativeResponseText: catalogItem.negativeResponseText,
            addOns: catalogItem.addOns,
            copy: [:], // Empty catalog copy
            inventoryStatus: nil,
            linkedProductId: catalogItem.linkedProductId,
            token: catalogItem.token
        )

        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .notExists, value: "creative.title"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: ["creative.title": "Awesome offer"],
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply, "Should not apply when creative copy contains the key with notExists condition")
    }

    func test_shouldNotApply_whenCatalogCopy_exists_notExists_condition() {
        // When catalog copy has the key but condition is notExists
        let layoutState = LayoutState()
        let catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .notExists, value: "key1"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: [:],
            layoutState: layoutState,
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply, "Should not apply when catalog copy contains the key with notExists condition")
    }

    func test_shouldNotApply_whenBoth_exist_notExists_condition() {
        // When both creative and catalog copy have the key but condition is notExists
        let layoutState = LayoutState()
        let catalogItem = CatalogItem.mock(catalogItemId: "item1", images: nil)
        let predicate = WhenPredicate.creativeCopy(CreativeCopyPredicate(condition: .notExists, value: "key1"))
        let whenVM = get_when_view_model(
            predicates: [predicate],
            copy: ["key1": "creative value"],
            layoutState: layoutState,
            catalogItem: catalogItem
        )

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(
            shouldApply,
            "Should not apply when both creative and catalog copy contain the key with notExists condition"
        )
    }

    // MARK: - StaticString

    func test_shouldApply_whenConditionEqualsIs_inputEqualsTest_valueEqualsTest() {
        let predicate = WhenPredicate.staticString(StaticStringPredicate(input: "test", condition: .is, value: "test"))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIs_inputEqualsTest_valueEqualsNotTest() {
        let predicate = WhenPredicate.staticString(StaticStringPredicate(input: "test", condition: .is, value: "nottest"))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }
    
    func test_shouldApply_whenConditionEqualsIsNot_inputEqualsTest_valueEqualsNotTest() {
        let predicate = WhenPredicate.staticString(StaticStringPredicate(input: "test", condition: .isNot, value: "nottest"))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIsNot_inputEqualsTest_valueEqualsTest() {
        let predicate = WhenPredicate.staticString(StaticStringPredicate(input: "test", condition: .isNot, value: "test"))
        let whenVM = get_when_view_model(predicates: [predicate])

        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }
    
    // MARK: - CustomState

    func test_shouldNotApply_customStateMapNil() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .is, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])
        
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertFalse(shouldApply)
    }
    
    func test_shouldNotApply_whenConditionEqualsIsNot_customStateMapNil() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isNot, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])
        
        let shouldApply = whenVM.shouldApply(get_mock_uistate())

        XCTAssertTrue(shouldApply)
    }
    
    func test_shouldNotApply_customStateMapInvalidKey() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .is, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])
        
        let customStateId = CustomStateIdentifiable(position: nil, key: "otherState")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 1)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIs_valueEqualsCustomState() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .is, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])
        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 1)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIs_valueNotEqualsCustomState() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .is, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 0)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsNot_valueNotEqualsCustomState() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isNot, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 11)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIsNot_valueEqualsCustomState() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isNot, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 1)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsAbove_customStateAboveValue() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isAbove, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 21)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIsAbove_customStateNotAboveValue() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isAbove, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 1)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }

    func test_shouldApply_whenConditionEqualsIsBelow_customStateBelowValue() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isBelow, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 0)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertTrue(shouldApply)
    }

    func test_shouldNotApply_whenConditionEqualsIsBelow_customStateNotBelowValue() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .isAbove, value: 11
        ))
        let whenVM = get_when_view_model(predicates: [predicate])

        let customStateId = CustomStateIdentifiable(position: nil, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 11)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(globalCustomStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }
    
    func test_shouldNotApply_whenConditionEqualsIs_valueEqualsCustomState_positionNotEquals() {
        let predicate = WhenPredicate.customState(CustomStatePredicate(
            key: "state", condition: .is, value: 1
        ))
        let whenVM = get_when_view_model(predicates: [predicate])
        
        // Setup customStateMap with ["state": 1] on position 0
        let customStateId = CustomStateIdentifiable(position: 0, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 1)])
        // Should not apply as uiState on position 1
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 1,
                                                              customStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }

    // MARK: Combination
    
    // Test multiple predicates together
    func test_should_apply_breakpoint_position_progression_is_valid() {
        // Arrange
        let predicate1 = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .is, value: "mobile")
        )
        let predicate2 = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "-1")
        )
        let predicate3 = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "0")
        )
        let predicate4 = WhenPredicate.darkMode(
            DarkModePredicate(condition: .is, value: true)
        )

        let whenVM = get_when_view_model(
            predicates: [predicate1, predicate2, predicate3, predicate4],
            breakPoint: get_shared_data_with_breakpoints()
        )
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0, width: 1, isDarkMode: true))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    // Test multiple predicates together
    func test_should_apply_breakpoint_position_progression_is_invalid() {
        // Arrange
        let predicate1 = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .is, value: "mobile")
        )
        // This one should fail
        let predicate2 = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "-2")
        )
        let predicate3 = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "0")
        )
        let predicate4 = WhenPredicate.darkMode(
            DarkModePredicate(condition: .isNot, value: true)
        )

        let whenVM = get_when_view_model(
            predicates: [predicate1, predicate2, predicate3, predicate4],
            breakPoint: get_shared_data_with_breakpoints()
        )
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0, width: 1))
        
        // Assert
        XCTAssertFalse(shouldApply)
    }
    
    // Test breakpoint, position, progression, darkMode and customState together
    func test_shouldApply_breakpoint_position_progression_darkMode_customState() {
        // Arrange
        let predicate1 = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .is, value: "mobile")
        )
        let predicate2 = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "-1")
        )
        let predicate3 = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "0")
        )
        let predicate4 = WhenPredicate.darkMode(
            DarkModePredicate(condition: .is, value: true)
        )
        let predicate5 = WhenPredicate.customState(
            CustomStatePredicate(key: "state", condition: .is, value: 21)
        )

        let whenVM = get_when_view_model(predicates: [predicate1, predicate2, predicate3, predicate4, predicate5],
                                         breakPoint: get_shared_data_with_breakpoints())
        // Act
        let customStateId = CustomStateIdentifiable(position: 0, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 21)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0,
                                                              width: 1,
                                                              isDarkMode: true,
                                                              customStateMap: customStateMap))

        XCTAssertTrue(shouldApply)
    }
    
    func test_shouldNotApply_breakpoint_position_progression_darkMode_customStateNotEqual() {
        let predicate1 = WhenPredicate.breakpoint(
            BreakpointPredicate(condition: .is, value: "mobile")
        )
        let predicate2 = WhenPredicate.position(
            PositionPredicate(condition: .is, value: "-1")
        )
        let predicate3 = WhenPredicate.progression(
            ProgressionPredicate(condition: .is, value: "0")
        )
        let predicate4 = WhenPredicate.darkMode(
            DarkModePredicate(condition: .is, value: true)
        )
        let predicate5 = WhenPredicate.customState(
            CustomStatePredicate(key: "state", condition: .is, value: 21)
        )
        
        let whenVM = get_when_view_model(predicates: [predicate1, predicate2, predicate3, predicate4, predicate5],
                                         breakPoint: get_shared_data_with_breakpoints())
        // Act
        let customStateId = CustomStateIdentifiable(position: 0, key: "state")
        let customStateMap = RoktUXCustomStateMap(uniqueKeysWithValues: [(key: customStateId,
                                                                          value: 2)])
        let shouldApply = whenVM.shouldApply(get_mock_uistate(position: 0,
                                                              width: 1,
                                                              isDarkMode: true,
                                                              customStateMap: customStateMap))

        XCTAssertFalse(shouldApply)
    }
    
    // MARK: Empty

    // Test empty
    func test_shouldApply_whenPredicatesEmpty() {
        // Arrange
        let whenVM = get_when_view_model(breakPoint: get_shared_data_with_breakpoints())
        // Act
        let shouldApply = whenVM.shouldApply(get_mock_uistate(width: 1, isDarkMode: true))

        // Assert
        XCTAssertTrue(shouldApply)
    }
    
    // MARK: - Transitions

    func test_shouldExtractDuration_whenTransition_fadeInOut() {
        // Arrange
        let whenTransition = WhenTransition(inTransition: [.fadeIn(FadeInTransitionSettings(duration: 200))],
                                            outTransition: [.fadeOut(FadeOutTransitionSettings(duration: 300))])
        let whenVM = get_when_view_model(transition: whenTransition)
        // Act
        let fadeInDuration = whenVM.fadeInDuration
        let fadeOutDuration = whenVM.fadeOutDuration

        // Assert
        XCTAssertEqual(fadeInDuration, 0.2)
        XCTAssertEqual(fadeOutDuration, 0.3)
    }
    
    private func get_slot_offer(copy: [String: String], catalogItems: [CatalogItem]? = nil) -> OfferModel {
        OfferModel(
            campaignId: "campaign1",
            creative: CreativeModel(
                referralCreativeId: "referralCreativeId1",
                instanceGuid: "instanceGuid",
                copy: copy,
                images: nil,
                links: nil,
                responseOptionsMap: nil,
                jwtToken: "jwtToken1"
            ),
            catalogItems: catalogItems,
            catalogItemGroup: nil,
            transactionData: nil
        )
    }
    
    func get_shared_data_with_breakpoints() -> BreakPoint {
        return ["mobile": 1, "tablet": 500, "desktop": 1000] as BreakPoint
    }
}
