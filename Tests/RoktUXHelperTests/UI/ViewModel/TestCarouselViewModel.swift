import XCTest
import SwiftUI
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15, *)
final class TestCarouselViewModel: XCTestCase {
    var sut: CarouselViewModel!
    var mockLayoutState: MockLayoutState!
    var mockEventService: MockEventService!

    override func setUp() {
        super.setUp()
        mockLayoutState = MockLayoutState()
        mockEventService = MockEventService()

        // Create mock view models that will be converted to LayoutSchemaViewModel enum cases
        let mockViewModels = (0...3).map { index in
            BasicTextViewModel(
                value: "Item \(index)",
                defaultStyle: nil,
                pressedStyle: nil,
                hoveredStyle: nil,
                disabledStyle: nil,
                layoutState: mockLayoutState,
                diagnosticService: nil
            )
        }

        // Convert mock view models to LayoutSchemaViewModel enum cases
        let children = mockViewModels.map { LayoutSchemaViewModel.basicText($0) }

        sut = CarouselViewModel(
            children: children,
            defaultStyle: nil,
            viewableItems: [2], // Show 2 items at a time
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        sut.viewableItems = 2 // Set viewable items to 2 for testing
    }

    override func tearDown() {
        mockEventService.reset()
        sut = nil
        mockLayoutState = nil
        mockEventService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_WhenInitialIndexPlusViewableItemsExceedsTotalChildren_ShouldSetCorrectPage() {
        // Given
        let mockViewModels = (0...4).map { index in
            BasicTextViewModel(
                value: "Item \(index)",
                defaultStyle: nil,
                pressedStyle: nil,
                hoveredStyle: nil,
                disabledStyle: nil,
                layoutState: mockLayoutState,
                diagnosticService: nil
            )
        }
        let children = mockViewModels.map { LayoutSchemaViewModel.basicText($0) }

        mockLayoutState.items[LayoutState.currentProgressKey] = 4

        // When - Create with initialIndex that would exceed bounds
        sut = CarouselViewModel(
            children: children,
            defaultStyle: nil,
            viewableItems: [2], // Show 2 items at a time
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )

        // Then
        XCTAssertEqual(
            sut.currentPage,
            1,
            "Current page should be set to last valid page (total items - viewable items)/viewable items"
        )
        XCTAssertEqual(sut.currentLeadingOfferIndex, 1, "Leading offer index should be set to start of last page")
    }

    func testInitialization_WhenInitialIndexIsValidAndPositive_ShouldSetCorrectPage() {
        // Given
        let mockViewModels = (0...5).map { index in
            BasicTextViewModel(
                value: "Item \(index)",
                defaultStyle: nil,
                pressedStyle: nil,
                hoveredStyle: nil,
                disabledStyle: nil,
                layoutState: mockLayoutState,
                diagnosticService: nil
            )
        }
        let children = mockViewModels.map { LayoutSchemaViewModel.basicText($0) }

        mockLayoutState.items[LayoutState.currentProgressKey] = 2

        // When - Create with valid initialIndex
        sut = CarouselViewModel(
            children: children,
            defaultStyle: nil,
            viewableItems: [2], // Show 2 items at a time
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )

        // Then
        XCTAssertEqual(sut.currentPage, 1, "Current page should be set to initialIndex/viewableItems")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 1, "Leading offer index should match initialIndex")
    }

    func testInitialization_WhenInitialIndexIsNegative_ShouldDefaultToZeroPage() {
        // Given
        let mockViewModels = (0...3).map { index in
            BasicTextViewModel(
                value: "Item \(index)",
                defaultStyle: nil,
                pressedStyle: nil,
                hoveredStyle: nil,
                disabledStyle: nil,
                layoutState: mockLayoutState,
                diagnosticService: nil
            )
        }
        let children = mockViewModels.map { LayoutSchemaViewModel.basicText($0) }

        // Negative index should result in page 0
        mockLayoutState.items[LayoutState.currentProgressKey] = -1

        // When - Create with negative initialIndex
        sut = CarouselViewModel(
            children: children,
            defaultStyle: nil,
            viewableItems: [2], // Show 2 items at a time
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Current page should default to 0 for negative initialIndex")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 0, "Leading offer index should default to 0")
    }

    // MARK: - goToPreviousPage Tests

    func testGoToPreviousPage_WhenIndexWithinPageIsZeroAndNotFirstPage_ShouldDecrementPage() {
        // Given
        sut.currentPage = 1
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 2 // Starting at second page (2 items per page)

        // When
        sut.goToPreviousPage(nil)

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Current page should decrement")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should be reset to 0")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 0, "Leading offer index should be updated to first page")
    }

    func testGoToPreviousPage_WhenIndexWithinPageIsZeroAndFirstPage_ShouldStayOnFirstPage() {
        // Given
        sut.currentPage = 0
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 0

        // When
        sut.goToPreviousPage(nil)

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Current page should remain at 0")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should remain at 0")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 0, "Leading offer index should remain at 0")
    }

    func testGoToPreviousPage_WhenIndexWithinPageIsNotZero_ShouldStayOnSamePage() {
        // Given
        sut.currentPage = 1
        sut.indexWithinPage = 1
        sut.currentLeadingOfferIndex = 2

        // When
        sut.goToPreviousPage(nil)

        // Then
        XCTAssertEqual(sut.currentPage, 1, "Current page should not change")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should be reset to 0")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 2, "Leading offer index should be updated")
    }

    // MARK: - goToNextPage Tests

    func testGoToNextPage_WhenNotOnLastPage_ShouldIncrementPage() {
        // Given
        sut.currentPage = 0
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 0

        // When
        sut.goToNextPage(nil)

        // Then
        XCTAssertEqual(sut.currentPage, 1, "Current page should increment")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should be reset to 0")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 2, "Leading offer index should be updated to next page")
    }

    func testGoToNextPage_WhenOnLastPageAndCloseOnCompleteTrue_ShouldCallCloseOnComplete() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }

        // Set to last page (with 4 items and 2 viewable items, last page is 1)
        sut.currentPage = 1
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 2

        // Enable closeOnComplete
        mockLayoutState.shouldCloseOnComplete = true

        // When
        sut.goToNextPage(nil)

        // Then
        XCTAssertTrue(closeActionCalled, "Close action should be called")
        XCTAssertEqual(sut.currentPage, 1, "Current page should remain unchanged")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should remain unchanged")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 2, "Leading offer index should remain unchanged")
    }

    func testGoToNextPage_WhenOnLastPageAndCloseOnCompleteFalse_ShouldStayOnLastPage() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }

        // Set to last page
        sut.currentPage = 1
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 2

        // Ensure closeOnComplete is false
        mockLayoutState.shouldCloseOnComplete = false

        // When
        sut.goToNextPage(nil)

        // Then
        XCTAssertFalse(closeActionCalled, "Close action should not be called")
        XCTAssertEqual(sut.currentPage, 1, "Current page should remain unchanged")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should remain unchanged")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 2, "Leading offer index should remain unchanged")
    }

    // MARK: - goToNextOffer Tests

    func testGoToNextOffer_WhenViewableItemsIsNotOne_ShouldDoNothing() {
        // Given
        sut.viewableItems = 2
        sut.currentPage = 0
        sut.currentLeadingOfferIndex = 0

        // When
        sut.goToNextOffer(nil)

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Current page should remain unchanged")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 0, "Leading offer index should remain unchanged")
    }

    func testGoToNextOffer_WhenViewableItemsIsOneAndNotLastOffer_ShouldIncrementToNextOffer() {
        // Given
        sut.viewableItems = 1
        sut.currentPage = 0
        sut.currentLeadingOfferIndex = 0

        // When
        sut.goToNextOffer(nil)

        // Then
        XCTAssertEqual(sut.currentPage, 1, "Current page should increment")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 1, "Leading offer index should increment")
    }

    func testGoToNextOffer_WhenOnLastOfferAndCloseOnCompleteTrue_ShouldCallCloseOnComplete() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }

        sut.viewableItems = 1
        // Set to last offer (with 4 items total, last index is 3)
        sut.currentPage = 3
        sut.currentLeadingOfferIndex = 3

        // Enable closeOnComplete
        mockLayoutState.shouldCloseOnComplete = true

        // When
        sut.goToNextOffer(nil)

        // Then
        XCTAssertTrue(closeActionCalled, "Close action should be called")
        XCTAssertEqual(sut.currentPage, 3, "Current page should remain unchanged")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 3, "Leading offer index should remain unchanged")
    }

    func testGoToNextOffer_WhenOnLastOfferAndCloseOnCompleteFalse_ShouldStayOnLastOffer() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }

        sut.viewableItems = 1
        // Set to last offer
        sut.currentPage = 3
        sut.currentLeadingOfferIndex = 3

        // Ensure closeOnComplete is false
        mockLayoutState.shouldCloseOnComplete = false

        // When
        sut.goToNextOffer(nil)

        // Then
        XCTAssertFalse(closeActionCalled, "Close action should not be called")
        XCTAssertEqual(sut.currentPage, 3, "Current page should remain unchanged")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 3, "Leading offer index should remain unchanged")
    }

    // MARK: - CloseOnComplete Tests

    func testCloseOnComplete_WhenEmbeddedLayout_ShouldSendCollapsedEventAndExit() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }
        mockLayoutState.shouldCloseOnComplete = true
        mockLayoutState.setLayoutType(.embeddedLayout)

        sut.viewableItems = 1
        sut.currentPage = 3 // Last offer
        sut.currentLeadingOfferIndex = 3

        // When
        sut.goToNextOffer(nil) // This will trigger closeOnComplete

        // Then
        XCTAssertTrue(closeActionCalled, "Close action should be called")
        XCTAssertTrue(mockEventService.dismissalEventCalled, "Dismissal event should be sent")
        XCTAssertFalse(mockEventService.dismissalNoMoreOfferEventSent, "No more offer event should not be sent")
        XCTAssertEqual(mockEventService.dismissOption, .collapsed)
    }

    func testCloseOnComplete_WhenOverlayLayout_ShouldSendNoMoreOfferEventAndExit() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }
        mockLayoutState.shouldCloseOnComplete = true
        mockLayoutState.setLayoutType(.overlayLayout)

        sut.viewableItems = 1
        sut.currentPage = 3 // Last offer
        sut.currentLeadingOfferIndex = 3

        // When
        sut.goToNextOffer(nil) // This will trigger closeOnComplete

        // Then
        XCTAssertTrue(closeActionCalled, "Close action should be called")
        XCTAssertFalse(mockEventService.dismissalCollapsedEventSent, "Dismissal collapsed event should not be sent")
        XCTAssertEqual(mockEventService.dismissOption, .noMoreOffer)
    }

    // MARK: - Edge Cases

    func testGoToNextOffer_WhenChildrenIsNil_ShouldTreatAsEmpty() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }
        mockLayoutState.shouldCloseOnComplete = true

        // Create a new CarouselViewModel with nil children
        sut = CarouselViewModel(
            children: nil,
            defaultStyle: nil,
            viewableItems: [1],
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        sut.viewableItems = 1

        // When
        sut.goToNextOffer(nil)

        // Then
        XCTAssertTrue(closeActionCalled, "Close action should be called immediately since children is nil")
        XCTAssertEqual(mockEventService.dismissOption, .noMoreOffer)
    }

    func testGoToNextPage_WhenChildrenIsNil_ShouldTreatAsEmpty() {
        // Given
        var closeActionCalled = false
        mockLayoutState.actionCollection = ActionCollection()
        mockLayoutState.actionCollection[.close] = { _ in closeActionCalled = true }
        mockLayoutState.shouldCloseOnComplete = true

        // Create a new CarouselViewModel with nil children
        sut = CarouselViewModel(
            children: nil,
            defaultStyle: nil,
            viewableItems: [2],
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        sut.viewableItems = 2

        // When
        sut.goToNextPage(nil)

        // Then
        XCTAssertTrue(closeActionCalled, "Close action should be called immediately since children is nil")
        XCTAssertEqual(mockEventService.dismissOption, .noMoreOffer)
    }

    // MARK: - UpdateStatesOnDragEnded Tests

    func testUpdateStatesOnDragEnded_WhenViewableItemsGreaterThanOne_ShouldUpdateStatesCorrectly() {
        // Given
        sut.viewableItems = 2
        sut.currentPage = 0
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 0

        // When
        sut.updateStatesOnDragEnded(1) // Move forward by 1

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Current page should remain 0")
        XCTAssertEqual(sut.indexWithinPage, 1, "Index within page should be 1")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 1, "Leading offer index should be 1")
    }

    func testUpdateStatesOnDragEnded_WhenDragExceedsTotalOffers_ShouldSnapToLastPage() {
        // Given
        sut.viewableItems = 2
        sut.currentPage = 0
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 0

        // When
        sut.updateStatesOnDragEnded(4) // Try to move beyond total offers (we have 4 items total)

        // Then
        XCTAssertEqual(sut.currentPage, 1, "Should snap to last page")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should be adjusted")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 2, "Leading offer index should be set to last valid position")
    }

    func testUpdateStatesOnDragEnded_WhenDragIsNegative_ShouldHandleBackwardsMovement() {
        // Given
        sut.viewableItems = 2
        sut.currentPage = 1
        sut.indexWithinPage = 0
        sut.currentLeadingOfferIndex = 2

        // When
        sut.updateStatesOnDragEnded(-2) // Move backwards by 2

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Should move to first page")
        XCTAssertEqual(sut.indexWithinPage, 0, "Index within page should be 0")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 0, "Leading offer index should be 0")
    }

    func testUpdateStatesOnDragEnded_WhenViewableItemsIsOne_ShouldUpdatePageOnly() {
        // Given
        sut.viewableItems = 1
        sut.currentPage = 1
        sut.currentLeadingOfferIndex = 1

        // When
        sut.updateStatesOnDragEnded(1) // Move forward by 1

        // Then
        XCTAssertEqual(sut.currentPage, 2, "Current page should increment")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 2, "Leading offer index should match current page")
    }

    func testUpdateStatesOnDragEnded_WhenViewableItemsIsOne_ShouldClampToValidRange() {
        // Given
        sut.viewableItems = 1
        sut.currentPage = 1
        sut.currentLeadingOfferIndex = 1

        // When - Try to move beyond total pages
        sut.updateStatesOnDragEnded(10)

        // Then
        XCTAssertEqual(sut.currentPage, 3, "Current page should be clamped to last valid page")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 3, "Leading offer index should match current page")

        // When - Try to move before first page
        sut.updateStatesOnDragEnded(-10)

        // Then
        XCTAssertEqual(sut.currentPage, 0, "Current page should be clamped to first page")
        XCTAssertEqual(sut.currentLeadingOfferIndex, 0, "Leading offer index should match current page")
    }

    // MARK: - SetViewableItemsForBreakpoint Tests

    func testSetViewableItemsForBreakpoint_WhenBreakpointIndexInRange_ShouldSetCorrectViewableItems() {
        // Given
        sut = CarouselViewModel(
            children: [LayoutSchemaViewModel]([
                .basicText(BasicTextViewModel(
                    value: "1",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                )),
                .basicText(BasicTextViewModel(
                    value: "2",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                )),
                .basicText(BasicTextViewModel(
                    value: "3",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                ))
            ]),
            defaultStyle: nil,
            viewableItems: [1, 2, 3], // Different viewable items for different breakpoints
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        
        // When
        mockLayoutState.mockBreakpointIndex = 1 // Set mock to return breakpoint index 1
        sut.globalScreenSizeUpdated(0)
        
        // Then
        XCTAssertEqual(sut.viewableItems, 2, "Viewable items should be set to 2 for breakpoint index 1")
    }
    
    func testSetViewableItemsForBreakpoint_WhenBreakpointIndexExceedsMaximum_ShouldUseLastBreakpoint() {
        // Given
        sut = CarouselViewModel(
            children: [LayoutSchemaViewModel]([
                .basicText(BasicTextViewModel(
                    value: "1",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                )),
                .basicText(BasicTextViewModel(
                    value: "2",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                ))
            ]),
            defaultStyle: nil,
            viewableItems: [1, 2], // Only two breakpoints defined
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        
        // When
        mockLayoutState.mockBreakpointIndex = 5 // Set mock to return breakpoint index 5
        sut.globalScreenSizeUpdated(0)
        
        // Then
        XCTAssertEqual(sut.viewableItems, 2, "Should use last available breakpoint value when index exceeds maximum")
    }
    
    func testSetViewableItemsForBreakpoint_WhenBreakpointIndexNegative_ShouldUseFirstBreakpoint() {
        // Given
        sut = CarouselViewModel(
            children: [LayoutSchemaViewModel]([
                .basicText(BasicTextViewModel(
                    value: "1",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                )),
                .basicText(BasicTextViewModel(
                    value: "2",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                ))
            ]),
            defaultStyle: nil,
            viewableItems: [1, 2], // Two breakpoints defined
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        
        // When
        mockLayoutState.mockBreakpointIndex = -1 // Set mock to return breakpoint index -1
        sut.globalScreenSizeUpdated(0)
        
        // Then
        XCTAssertEqual(sut.viewableItems, 1, "Should use first breakpoint value when index is negative")
    }
    
    func testSetViewableItemsForBreakpoint_WhenViewableItemsExceedTotalOffers_ShouldCapAtTotalOffers() {
        // Given
        sut = CarouselViewModel(
            children: [LayoutSchemaViewModel]([
                .basicText(BasicTextViewModel(
                    value: "1",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                )),
                .basicText(BasicTextViewModel(
                    value: "2",
                    defaultStyle: nil,
                    pressedStyle: nil,
                    hoveredStyle: nil,
                    disabledStyle: nil,
                    layoutState: mockLayoutState,
                    diagnosticService: nil
                ))
            ]),
            defaultStyle: nil,
            viewableItems: [1, 4], // Second breakpoint tries to show more items than available
            peekThroughSize: [],
            eventService: mockEventService,
            slots: [],
            layoutState: mockLayoutState
        )
        
        // When
        mockLayoutState.mockBreakpointIndex = 1 // Set mock to return breakpoint index 1
        sut.globalScreenSizeUpdated(1000)
        
        // Then
        XCTAssertEqual(sut.viewableItems, 2, "Should cap viewable items at total number of offers available")
    }
}
