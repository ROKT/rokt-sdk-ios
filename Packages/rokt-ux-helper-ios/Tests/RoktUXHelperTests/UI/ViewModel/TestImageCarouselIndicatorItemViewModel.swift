import Foundation
import XCTest
import SwiftUI
@testable import RoktUXHelper
@testable import DcuiSchema

@available(iOS 15, *)
class TestImageCarouselIndicatorItemViewModel: XCTestCase {

    func testWhenNode(node: LayoutSchemaViewModel, _ block: (WhenViewModel) -> Void) {
        switch node {
        case let .when(whenModel):
            block(whenModel)
        
        default:
            XCTFail("Should be .when")
        }
    }
    
    func testRowNode(node: LayoutSchemaViewModel, _ block: (RowViewModel) -> Void) {
        switch node {
        case let .row(rowModel):
            block(rowModel)
        default:
            XCTFail("Should be .row")
        }
    }

    private func assertCarouselPositionPredicate(
        _ predicate: WhenPredicate,
        expectedCondition: OrderableWhenCondition,
        expectedValue: Int32
    ) {
        switch predicate {
        case .customState(let customStatePredicate):
            XCTAssertEqual(customStatePredicate.key, CustomStateIdentifiable.Keys.imageCarouselPosition.rawValue)
            XCTAssertEqual(customStatePredicate.condition, expectedCondition)
            XCTAssertEqual(customStatePredicate.value, expectedValue)
        default:
            XCTFail("Expected .customState predicate")
        }
    }
    
    func testInit() {
        let index: Int32 = 0
        let sut = ImageCarouselIndicatorItemViewModel(
            index: index,
            duration: 1000,
            progressStyle: [.init(default: .init(), pressed: nil, hovered: nil, focussed: nil, disabled: nil)],
            activeStyle: nil,
            animatableStyle: nil,
            indicatorStyle: nil,
            seenStyle: nil,
            layoutState: nil,
            shouldDisplayProgress: false
        )

        XCTAssertNotNil(sut)
        guard let children = sut.children else {
            XCTFail("Should have children")
            return
        }
        
        XCTAssertEqual(children.count, 3)
        
        testWhenNode(node: children[0]) { whenModel in
            XCTAssertEqual(whenModel.predicates?.count, 1)
            if let predicate = whenModel.predicates?.first {
                self.assertCarouselPositionPredicate(predicate, expectedCondition: .isAbove, expectedValue: index)
            }
            guard let children = whenModel.children else {
                XCTFail("Should have children")
                return
            }
            XCTAssertEqual(children.count, 1)
            testRowNode(node: children[0]) { activeRowItem in
                XCTAssertEqual(activeRowItem.children?.count, 0)
            }
        }
        
        testWhenNode(node: children[1]) { whenModel in
            XCTAssertEqual(whenModel.predicates?.count, 1)
            if let predicate = whenModel.predicates?.first {
                self.assertCarouselPositionPredicate(predicate, expectedCondition: .is, expectedValue: index)
            }
            guard let children = whenModel.children else {
                XCTFail("Should have children")
                return
            }
            XCTAssertEqual(children.count, 1)
            
            testRowNode(node: children[0]) { inactiveRowItem in
                XCTAssertEqual(inactiveRowItem.children?.count, 1)
            }
        }
        
        testWhenNode(node: children[2]) { whenModel in
            XCTAssertEqual(whenModel.predicates?.count, 1)
            if let predicate = whenModel.predicates?.first {
                self.assertCarouselPositionPredicate(predicate, expectedCondition: .isBelow, expectedValue: index)
            }
            guard let children = whenModel.children else {
                XCTFail("Should have children")
                return
            }
            XCTAssertEqual(children.count, 1)
            
            testRowNode(node: children[0]) { notSeenRowItem in
                XCTAssertEqual(notSeenRowItem.children?.count, 0)
            }
        }
    }
}
