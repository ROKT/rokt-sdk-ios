import XCTest
@testable import RoktUXHelper

class TestComponentVisibilityInfo: XCTestCase {

    func test_isInViewAndCorrectSize_whenVisibleNotObscuredNotIncorrectlySized_returnsTrue() {
        let info = ComponentVisibilityInfo(isVisible: true, isObscured: false, incorrectlySized: false)
        XCTAssertTrue(info.isInViewAndCorrectSize)
    }

    func test_isInViewAndCorrectSize_whenObscured_returnsFalse() {
        let info = ComponentVisibilityInfo(isVisible: true, isObscured: true, incorrectlySized: false)
        XCTAssertFalse(info.isInViewAndCorrectSize)
    }

    func test_isInViewAndCorrectSize_whenIncorrectlySized_returnsFalse() {
        let info = ComponentVisibilityInfo(isVisible: true, isObscured: false, incorrectlySized: true)
        XCTAssertFalse(info.isInViewAndCorrectSize)
    }

    func test_isInViewAndCorrectSize_whenNotVisible_returnsFalse() {
        let info = ComponentVisibilityInfo(isVisible: false, isObscured: false, incorrectlySized: false)
        XCTAssertFalse(info.isInViewAndCorrectSize)
    }

    func test_defaultInit_allPropertiesAreFalse() {
        let info = ComponentVisibilityInfo()
        XCTAssertFalse(info.isVisible)
        XCTAssertFalse(info.isObscured)
        XCTAssertFalse(info.incorrectlySized)
    }

    func test_isInViewAndCorrectSize_whenObscuredAndIncorrectlySized_returnsFalse() {
        let info = ComponentVisibilityInfo(isVisible: true, isObscured: true, incorrectlySized: true)
        XCTAssertFalse(info.isInViewAndCorrectSize)
    }

    func test_isInViewAndCorrectSize_whenAllFlagsAreNegative_returnsFalse() {
        let info = ComponentVisibilityInfo(isVisible: false, isObscured: true, incorrectlySized: true)
        XCTAssertFalse(info.isInViewAndCorrectSize)
    }
}
