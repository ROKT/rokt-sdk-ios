import XCTest
@testable import RoktUXHelper

final class BNFNamespaceTests: XCTestCase {
    func test_withNamespaceSeparator_returnsConcatenatedString() {
        let spaces: [BNFNamespace] = [.dataCreativeCopy, .dataCreativeResponse, .state]

        XCTAssertEqual(spaces[0].withNamespaceSeparator, "DATA.creativeCopy.")
        XCTAssertEqual(spaces[1].withNamespaceSeparator, "DATA.creativeResponse.")
        XCTAssertEqual(spaces[2].withNamespaceSeparator, "STATE.")
    }
}
