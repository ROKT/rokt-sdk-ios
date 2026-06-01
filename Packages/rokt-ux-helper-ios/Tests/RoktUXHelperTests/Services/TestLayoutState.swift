import Foundation
import XCTest
@testable import RoktUXHelper
import DcuiSchema
import Combine

class TestLayoutState: XCTestCase {

    private var layoutState: LayoutState!
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        layoutState = nil
        super.tearDown()
    }

    func testReceiveUpdateWhenItemsChange() {
        layoutState = LayoutState()
        let expectation = expectation(description: "Test publisher")
        layoutState.itemsPublisher
            .compactMap { $0["test"] as? Int }
            .sink { value in
                XCTAssertEqual(value, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        layoutState.items["test"] = 1
        wait(for: [expectation], timeout: 1)
    }

    func testSubscriberCanReadItemsWhenItemsChange() {
        layoutState = LayoutState()
        let expectation = expectation(description: "Subscriber reads items")
        layoutState.itemsPublisher
            .compactMap { $0["test"] as? Int }
            .sink { [weak self] value in
                XCTAssertEqual(value, 1)
                XCTAssertEqual(self?.layoutState.items["test"] as? Int, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        layoutState.items["test"] = 1

        wait(for: [expectation], timeout: 1)
    }

    func testUpdateLayoutType() {
        layoutState = LayoutState()
        let expectation = expectation(description: "Test layout type")
        var fulfilled = false
        layoutState.itemsPublisher
            .compactMap { $0[LayoutState.layoutType] as? RoktUXPlacementLayoutCode }
            .sink { layoutType in
                if !fulfilled, layoutType == .overlayLayout {
                    fulfilled = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        layoutState.items[LayoutState.layoutType] = RoktUXPlacementLayoutCode.overlayLayout
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(layoutState.layoutType(), .overlayLayout)
    }

    func testCloseOnComplete() {
        layoutState = LayoutState()

        XCTAssertEqual(layoutState.closeOnComplete(), true)

        layoutState.items[LayoutState.layoutSettingsKey] = LayoutSettings(closeOnComplete: nil)
        XCTAssertEqual(layoutState.closeOnComplete(), true)

        layoutState.items[LayoutState.layoutSettingsKey] = LayoutSettings(closeOnComplete: false)
        XCTAssertEqual(layoutState.closeOnComplete(), false)

        layoutState.items[LayoutState.layoutSettingsKey] = LayoutSettings(closeOnComplete: true)
        XCTAssertEqual(layoutState.closeOnComplete(), true)
    }

    func testGlobalBreakpointIndex() {
        layoutState = LayoutState()
        layoutState.items[LayoutState.breakPointsSharedKey] = ["0": Float(100.0), "1": Float(200.0), "2": Float(300.0)]
        XCTAssertEqual(layoutState.getGlobalBreakpointIndex(50.0), 0)
        XCTAssertEqual(layoutState.getGlobalBreakpointIndex(150.0), 1)
        XCTAssertEqual(layoutState.getGlobalBreakpointIndex(250.0), 2)
        XCTAssertEqual(layoutState.getGlobalBreakpointIndex(350.0), 3)
        XCTAssertEqual(layoutState.getGlobalBreakpointIndex(450.0), 3)
    }
}
