import XCTest
@testable import RoktUXHelper

final class TestActionCollection: XCTestCase {
    
    var actionCollection: ActionCollection!
    
    override func setUp() {
        actionCollection = ActionCollection()
        super.setUp()
    }

    func test_event_collection_valid() {
        // Arrange
        var closeCalled = false
        func closeOverlay(_: Any? = nil) {
            closeCalled = true
        }
        actionCollection[.close] = closeOverlay
        // Act
        actionCollection[.close](nil)
        
        // Assert
        XCTAssertTrue(closeCalled)
    }
    
    func test_event_collection_invalid() {
        // Arrange
        var closeCalled = false
        func closeOverlay(_: Any? = nil) {
            closeCalled = true
        }
        actionCollection[.close] = closeOverlay
        // Act
        actionCollection[.nextOffer](nil)
        
        // Assert
        XCTAssertFalse(closeCalled)
    }
}
