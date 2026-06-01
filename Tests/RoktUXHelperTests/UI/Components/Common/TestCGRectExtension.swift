import Foundation
import XCTest
import SwiftUI
@testable import RoktUXHelper

@available(iOS 15, *)
class TestCGRectExtension: XCTestCase {

    func testIntersectPercentWithFrame_NoIntersection() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 200, y: 200, width: 50, height: 50)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.0, "Should return 0 when rectangles don't intersect")
    }

    func testIntersectPercentWithFrame_FullIntersection() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 100, height: 100)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 1.0, "Should return 1.0 when rectangles fully overlap")
    }

    func testIntersectPercentWithFrame_PartialIntersection() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 50, height: 50)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.25, "Should return 0.25 when rect2 is 1/4 the size of rect1")
    }

    func testIntersectPercentWithFrame_QuarterIntersection() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 50, y: 50, width: 50, height: 50)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.25, "Should return 0.25 when rect2 overlaps in bottom-right quarter")
    }

    func testIntersectPercentWithFrame_EdgeCase_ZeroSize() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 0, height: 0)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.0, "Should return 0 when rect2 has zero size")
    }

    func testIntersectPercentWithFrame_EdgeCase_SelfZeroSize() {
        let rect1 = CGRect(x: 0, y: 0, width: 0, height: 0)
        let rect2 = CGRect(x: 0, y: 0, width: 100, height: 100)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.0, "Should return 0 when self has zero size to prevent divide by zero")
    }

    func testIntersectPercentWithFrame_EdgeCase_SelfZeroWidth() {
        let rect1 = CGRect(x: 0, y: 0, width: 0, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 100, height: 100)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.0, "Should return 0 when self has zero width to prevent divide by zero")
    }

    func testIntersectPercentWithFrame_EdgeCase_SelfZeroHeight() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 0)
        let rect2 = CGRect(x: 0, y: 0, width: 100, height: 100)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.0, "Should return 0 when self has zero height to prevent divide by zero")
    }

    func testIntersectPercentWithFrame_EdgeCase_NegativeCoordinates() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: -50, y: -50, width: 100, height: 100)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.25, "Should return 0.25 when rect2 extends into negative coordinates")
    }

    func testIntersectPercentWithFrame_EdgeCase_ExactHalf() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 100, height: 50)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.5, "Should return 0.5 when rect2 covers exactly half of rect1")
    }

    func testIntersectPercentWithFrame_EdgeCase_ExactQuarter() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 50, height: 50)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.25, "Should return 0.25 when rect2 covers exactly quarter of rect1")
    }

    func testIntersectPercentWithFrame_EdgeCase_ExactEighth() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 0, y: 0, width: 25, height: 50)

        let result = rect1.intersectPercentWithFrame(rect2)
        XCTAssertEqual(result, 0.125, "Should return 0.125 when rect2 covers exactly 1/8 of rect1")
    }

    func testIntersectPercentWithFrame_DependsOnReceiverArea() {
        let screenRect = CGRect(x: 0, y: 0, width: 400, height: 800)
        let viewRect = CGRect(x: 0, y: 0, width: 200, height: 200)

        let visiblePercentOfView = viewRect.intersectPercentWithFrame(screenRect)
        let coveredPercentOfScreen = screenRect.intersectPercentWithFrame(viewRect)

        XCTAssertEqual(visiblePercentOfView, 1.0, "Using the view rect as receiver should measure visible percent of the view")
        XCTAssertEqual(
            coveredPercentOfScreen,
            0.125,
            "Using the screen rect as receiver should measure covered percent of the screen"
        )
    }
}
