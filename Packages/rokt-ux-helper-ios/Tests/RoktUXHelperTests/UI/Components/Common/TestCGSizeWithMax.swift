import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
class TestCGSizeWithMax: XCTestCase {

    func test_init_sizeIsStoredCorrectly() {
        let size = CGSize(width: 100, height: 200)
        let sizeWithMax = CGSizeWithMax(size: size)
        XCTAssertEqual(sizeWithMax.size, size)
    }

    func test_init_defaultMaxWidthAndMaxHeightAreNil() {
        let sizeWithMax = CGSizeWithMax(size: CGSize(width: 50, height: 50))
        XCTAssertNil(sizeWithMax.maxWidth)
        XCTAssertNil(sizeWithMax.maxHeight)
    }

    func test_settingMaxWidth_storesValue() {
        var sizeWithMax = CGSizeWithMax(size: CGSize(width: 50, height: 50))
        sizeWithMax.maxWidth = .infinity
        XCTAssertEqual(sizeWithMax.maxWidth, .infinity)
    }

    func test_settingMaxHeight_storesValue() {
        var sizeWithMax = CGSizeWithMax(size: CGSize(width: 50, height: 50))
        sizeWithMax.maxHeight = .infinity
        XCTAssertEqual(sizeWithMax.maxHeight, .infinity)
    }
}
