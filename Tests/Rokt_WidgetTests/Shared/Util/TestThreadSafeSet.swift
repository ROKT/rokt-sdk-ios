import XCTest

@testable import Rokt_Widget

class TestThreadSafeSet: XCTestCase {

    var sut: ThreadSafeSet<String>!

    override func setUp() {
        super.setUp()
        sut = ThreadSafeSet()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_concurrentInsert() {
        let expectation = self.expectation(description: "Concurrent Insert")
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(label: "com.rokt.test.concurrent", attributes: .concurrent)
        let iterationCount = 1000

        for i in 0..<iterationCount {
            dispatchGroup.enter()
            queue.async {
                _ = self.sut.insert("item-\(i)")
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0, handler: nil)
        XCTAssertEqual(sut.count, iterationCount)
    }

    func test_concurrentReadWrite() {
        let expectation = self.expectation(description: "Concurrent Read Write")
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(
            label: "com.rokt.test.concurrentReadWrite", attributes: .concurrent)
        let iterationCount = 1000

        // Populate initially
        for i in 0..<iterationCount {
            _ = sut.insert("item-\(i)")
        }

        // Concurrent Remove and Contains
        for i in 0..<iterationCount {
            dispatchGroup.enter()
            queue.async {
                if i % 2 == 0 {
                    _ = self.sut.remove("item-\(i)")
                } else {
                    _ = self.sut.contains("item-\(i)")
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0, handler: nil)

        // Half should be removed
        XCTAssertEqual(sut.count, iterationCount/2)
    }

    func test_initFromArray() {
        let array = ["a", "b", "c", "a"]
        sut = ThreadSafeSet(array)
        XCTAssertEqual(sut.count, 3)
        XCTAssertTrue(sut.contains("a"))
        XCTAssertTrue(sut.contains("b"))
        XCTAssertTrue(sut.contains("c"))
    }

    func test_removeAll() {
        sut.insert("a")
        sut.insert("b")
        sut.removeAll()
        XCTAssertEqual(sut.count, 0)
    }

    func test_allElements() {
        sut.insert("a")
        sut.insert("b")
        let elements = sut.allElements
        XCTAssertEqual(elements.count, 2)
        XCTAssertTrue(elements.contains("a"))
        XCTAssertTrue(elements.contains("b"))
    }
}
