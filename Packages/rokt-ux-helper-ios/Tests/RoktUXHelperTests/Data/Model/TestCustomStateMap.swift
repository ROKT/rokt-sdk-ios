import XCTest
@testable import RoktUXHelper

class CustomStateMapTests: XCTestCase {

    func testToggleValueFor_existingKey() {
        var customStateMap: RoktUXCustomStateMap = [CustomStateIdentifiable(position: 1, key: "testKey"): 1]
        let customStateId = CustomStateIdentifiable(position: 1, key: "testKey")
        
        customStateMap = customStateMap.toggleValueFor(customStateId)
        
        XCTAssertEqual(customStateMap[customStateId], 0)
    }
    
    func testToggleValueFor_nonExistingKey() {
        var customStateMap: RoktUXCustomStateMap = [:]
        let customStateId = CustomStateIdentifiable(position: 1, key: "testKey")
        
        customStateMap = customStateMap.toggleValueFor(customStateId)
        
        XCTAssertEqual(customStateMap[customStateId], 1)
    }
    
    func testToggleValueFor_invalidKey() {
        var customStateMap: RoktUXCustomStateMap = [CustomStateIdentifiable(position: 1, key: "testKey"): 1]
        
        customStateMap = customStateMap.toggleValueFor(nil)
        
        XCTAssertEqual(customStateMap[CustomStateIdentifiable(position: 1, key: "testKey")], 1)
    }
}
