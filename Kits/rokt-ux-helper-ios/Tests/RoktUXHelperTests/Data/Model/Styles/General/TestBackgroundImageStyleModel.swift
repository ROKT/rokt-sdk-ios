import XCTest
import SwiftUI
@testable import RoktUXHelper

@available(iOS 13, *)
final class TestBackgroundImageStyleModel: XCTestCase {

    func test_position_alignment_top() {
        assert_position_alignment(Position.top, alignment: .top)
    }

    func test_position_alignment_right() {
        assert_position_alignment(Position.right, alignment: .trailing)
    }
    
    func test_position_alignment_bottom() {
        assert_position_alignment(Position.bottom, alignment: .bottom)
    }
    
    func test_position_alignment_left() {
        assert_position_alignment(Position.left, alignment: .leading)
    }
    
    func test_position_alignment_topRight() {
        assert_position_alignment(Position.topRight, alignment: .topTrailing)
    }
    
    func test_position_alignment_topLeft() {
        assert_position_alignment(Position.topLeft, alignment: .topLeading)
    }
    
    func test_position_alignment_bottomLeft() {
        assert_position_alignment(Position.bottomLeft, alignment: .bottomLeading)
    }
    
    func test_position_alignment_bottomRight() {
        assert_position_alignment(Position.bottomRight, alignment: .bottomTrailing)
    }
    
    func test_position_alignment_center() {
        assert_position_alignment(Position.center, alignment: .center)
    }
    
    private func assert_position_alignment(_ position: Position, alignment: Alignment) {
        XCTAssertEqual(position.getAlignment(), alignment)
    }

}
