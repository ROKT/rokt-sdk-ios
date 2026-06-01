import XCTest
import SwiftUI
@testable import RoktUXHelper

@available(iOS 15, *)
class TestIfLetViewModifier: XCTestCase {

    func test_ifLet_whenOptionalHasValue_transformIsApplied() {
        var transformCalled = false
        _ = Text("base").ifLet("value") { view, _ in
            transformCalled = true
            return view
        }
        XCTAssertTrue(transformCalled)
    }

    func test_ifLet_whenOptionalIsNil_transformIsNotCalled() {
        var transformCalled = false
        _ = Text("base").ifLet(nil as String?) { view, _ in
            transformCalled = true
            return view
        }
        XCTAssertFalse(transformCalled)
    }

    func test_ifLet_whenOptionalHasValue_unwrappedValueIsPassedToTransform() {
        var receivedValue: String?
        _ = Text("base").ifLet("hello") { view, value in
            receivedValue = value
            return view
        }
        XCTAssertEqual(receivedValue, "hello")
    }

    func test_ifLet_whenOptionalHasIntValue_unwrappedValueIsPassedToTransform() {
        var receivedValue: Int?
        _ = Text("base").ifLet(42) { view, value in
            receivedValue = value
            return view
        }
        XCTAssertEqual(receivedValue, 42)
    }
}
