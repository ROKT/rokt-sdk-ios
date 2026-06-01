import Foundation
import XCTest
import SwiftUI
@testable import RoktUXHelper
@testable import DcuiSchema

@available(iOS 15, *)
class TestRowViewModel: XCTestCase {

    func testShouldAnimateInBegining() {
        let layoutState = LayoutState()
        let sut = RowViewModel(
            children: nil,
            stylingProperties: nil,
            animatableStyle: .init(duration: 1, style: .init()),
            accessibilityGrouped: false,
            layoutState: layoutState,
            predicates: [WhenPredicate.progression(ProgressionPredicate(condition: .is, value: "0"))],
            globalBreakPoints: nil,
            offers: []
        )

        XCTAssertTrue(sut.animate)
    }

    func testShouldAnimate() {
        let layoutState = LayoutState()
        let sut = RowViewModel(
            children: nil,
            stylingProperties: nil,
            animatableStyle: .init(duration: 1, style: .init()),
            accessibilityGrouped: false,
            layoutState: layoutState,
            predicates: [WhenPredicate.progression(ProgressionPredicate(condition: .is, value: "1"))],
            globalBreakPoints: nil,
            offers: []
        )

        XCTAssertFalse(sut.animate)
        layoutState.items[LayoutState.currentProgressKey] = Binding.constant(1)
        var expectation: XCTestExpectation? = expectation(description: "test animate")
        let cancellable = sut.$animate.dropFirst().sink { newValue in
            XCTAssertTrue(newValue)
            expectation?.fulfill()
            expectation = nil
        }
        wait(for: [expectation!], timeout: 1)
    }
}
