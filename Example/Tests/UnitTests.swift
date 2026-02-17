import XCTest
import Nimble
@testable import Rokt_Widget

class UnitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        stubInit()
        Rokt.initWith(roktTagId: "123123123")
    }

    func testInit() {
        expect(Rokt.shared).to(beAKindOf(Rokt.self))
    }

}
