import Foundation
import XCTest
@testable import RoktUXHelper

class TestCGSizeExtension: XCTestCase {

    func testPrecised() {
        let size = CGSize(width: CGFloat(1.12345), height: CGFloat(61.16352))
        XCTAssertEqual(size.precised(2), .init(width: 1.12, height: 61.16))
        XCTAssertEqual(size.precised(3), .init(width: 1.123, height: 61.164))
        XCTAssertEqual(size.precised(4), .init(width: 1.1235, height: 61.1635))
    }
}
