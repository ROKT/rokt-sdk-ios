import Foundation
import XCTest

@available(iOS 15, *)

extension XCTestCase {
    func waitForViewController(
        _ jsonFilename: String,
        timeout: TimeInterval = 0.1,
        _ onComplete: ((UIViewController) -> Void)? = nil
    ) {
        // Create a RoktLayoutUIView
        let testViewController = TestViewController
            .createVC(ModelTestData.PageModelData.getJsonString(jsonFilename: jsonFilename))
        
        let expectation = XCTestExpectation(description: "Wait for SwiftUI rendering")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            onComplete?(testViewController)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout + 0.05)
    }
    
}
