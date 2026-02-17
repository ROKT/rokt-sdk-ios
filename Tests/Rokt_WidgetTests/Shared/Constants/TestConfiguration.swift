import XCTest
@testable import Rokt_Widget

class TestConfiguration: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_environment_valid() {
        XCTAssertEqual(Configuration.getEnvironment(.Stage), Environment.Stage)
        XCTAssertEqual(Configuration.getEnvironment(.Prod), Environment.Prod)
        XCTAssertEqual(Configuration.getEnvironment(nil), Environment.Mock)
    }

}
