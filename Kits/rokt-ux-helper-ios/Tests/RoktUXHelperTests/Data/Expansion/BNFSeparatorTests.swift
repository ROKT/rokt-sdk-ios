import XCTest
@testable import RoktUXHelper

final class BNFSeparatorTests: XCTestCase {
    func test_charCount_shouldReturnPerDelimiter() {
        XCTAssertEqual(BNFSeparator.startDelimiter.charCount, 2)
        XCTAssertEqual(BNFSeparator.endDelimiter.charCount, 2)
        XCTAssertEqual(BNFSeparator.namespace.charCount, 1)
        XCTAssertEqual(BNFSeparator.alternative.charCount, 1)
    }
}
