import XCTest
import SwiftUI
@testable import RoktUXHelper

@available(iOS 13, *)
final class TestStyleModel: XCTestCase {
    
    // MARK: ImageScaleProperty

    func test_image_scale_property_fill() {
        // Arrange
        let imageScale = ImageScaleProperty.fill
        // Act
        let contentModeScale = imageScale.getScale()
        // Assert
        XCTAssertEqual(contentModeScale, .fill)
    }
    
    func test_image_scale_property_fit() {
        // Arrange
        let imageScale = ImageScaleProperty.fit
        // Act
        let contentModeScale = imageScale.getScale()
        // Assert
        XCTAssertEqual(contentModeScale, .fit)
    }
    
    // MARK: VerticalAlignmentProperty

    func test_vertical_alignment_property_alignment_top() {
        assert_alignment(VerticalAlignmentProperty.top, alignmnent: .top)
    }
    
    func test_vertical_alignment_property_alignment_bottom() {
        assert_alignment(VerticalAlignmentProperty.bottom, alignmnent: .bottom)
    }
    
    func test_vertical_alignment_property_alignment_center() {
        assert_alignment(VerticalAlignmentProperty.center, alignmnent: .center)
    }
    
    func test_vertical_alignment_property_vertical_alignment_top() {
        assert_vertical_alignment(VerticalAlignmentProperty.top,
                                  verticalAlignment: .top)
    }
    
    func test_vertical_alignment_property_vertical_alignment_bottom() {
        assert_vertical_alignment(VerticalAlignmentProperty.bottom,
                                  verticalAlignment: .bottom)
    }
    
    func test_vertical_alignment_property_vertical_alignment_center() {
        assert_vertical_alignment(VerticalAlignmentProperty.center,
                                  verticalAlignment: .center)
    }
    
    // MARK: HorizontalAlignmentProperty

    func test_horizontal_alignment_property_alignment_start() {
        assert_alignment(HorizontalAlignmentProperty.start, alignmnent: .leading)
    }
    
    func test_horizontal_alignment_property_alignment_end() {
        assert_alignment(HorizontalAlignmentProperty.end, alignmnent: .trailing)
    }
    
    func test_horizontal_alignment_property_alignment_center() {
        assert_alignment(HorizontalAlignmentProperty.center, alignmnent: .center)
    }
    
    func test_horizontal_alignment_property_horizontal_alignment_start() {
        assert_horizontal_alignment(HorizontalAlignmentProperty.start,
                                    horizontalAlignmnent: .leading)
    }
    
    func test_horizontal_alignment_property_horizontal_alignment_end() {
        assert_horizontal_alignment(HorizontalAlignmentProperty.end,
                                    horizontalAlignmnent: .trailing)
    }
    
    func test_horizontal_alignment_property_horizontal_alignment_center() {
        assert_horizontal_alignment(HorizontalAlignmentProperty.center,
                                    horizontalAlignmnent: .center)
    }
    
    // MARK: HorizontalTextAlignmentProperty

    func test_horizontal_text_alignment_property_horizontal_alignment_start() {
        assert_horizontal_text_alignment(HorizontalTextAlignmentProperty.start,
                                         horizontalTextAlignmnent: .leading)
    }
    
    func test_horizontal_text_alignment_property_horizontal_alignment_end() {
        assert_horizontal_text_alignment(HorizontalTextAlignmentProperty.end,
                                         horizontalTextAlignmnent: .trailing)
    }
    
    func test_horizontal_text_alignment_property_horizontal_alignment_center() {
        assert_horizontal_text_alignment(HorizontalTextAlignmentProperty.center,
                                         horizontalTextAlignmnent: .center)
    }

    // MARK: FrameAlignmentProperty
    
    func test_frame_alignmnet_valid() {
        // Arrange
        let padding = "10 20 30 40"
        // Act
        let alignment = FrameAlignmentProperty.getFrameAlignment(padding)
        // Assert
        XCTAssertEqual(alignment, FrameAlignmentProperty(top: 10, right: 20, bottom: 30, left: 40))
    }
    
    func test_frame_alignment_valid_three_count() {
        // Arrange
        let padding = "10 20 30"
        // Act
        let alignment = FrameAlignmentProperty.getFrameAlignment(padding)
        // Assert
        XCTAssertEqual(alignment, FrameAlignmentProperty(top: 10, right: 20, bottom: 30, left: 20))
    }
    
    func test_frame_alignment_valid_two_count() {
        // Arrange
        let padding = "10 20"
        // Act
        let alignment = FrameAlignmentProperty.getFrameAlignment(padding)
        // Assert
        XCTAssertEqual(alignment, FrameAlignmentProperty(top: 10, right: 20, bottom: 10, left: 20))
    }
    
    func test_frame_alignment_valid_one_count() {
        // Arrange
        let padding = "10"
        // Act
        let alignment = FrameAlignmentProperty.getFrameAlignment(padding)
        // Assert
        XCTAssertEqual(alignment, FrameAlignmentProperty(top: 10, right: 10, bottom: 10, left: 10))
    }
    
    func test_frame_alignmnet_invalid_type_default() {
        // Arrange
        let padding = "m m m m"
        // Act
        let alignment = FrameAlignmentProperty.getFrameAlignment(padding)
        // Assert
        XCTAssertEqual(alignment, FrameAlignmentProperty(top: 0, right: 0, bottom: 0, left: 0))
    }
    
    func test_frame_alignmnet_invalid_zero_dimension() {
        // Arrange & Act
        let alignment = FrameAlignmentProperty.zeroDimension
        // Assert
        XCTAssertEqual(alignment, FrameAlignmentProperty(top: 0, right: 0, bottom: 0, left: 0))
    }
    
    // MARK: OffsetProperty
    
    func test_offset_valid() {
        // Arrange
        let offsetString = "20 40"
        // Act
        let offset = OffsetProperty.getOffset(offsetString)
        // Assert
        XCTAssertEqual(offset, OffsetProperty(x: 20, y: 40))
    }
    
    func test_offset_invalid_count_default() {
        // Arrange
        let offsetString = "10 20 30 40"
        // Act
        let offset = OffsetProperty.getOffset(offsetString)
        // Assert
        XCTAssertEqual(offset, OffsetProperty(x: 0, y: 0))
    }
    
    func test_offset_invalid_type_default() {
        // Arrange
        let offsetString = "x y"
        // Act
        let offset = OffsetProperty.getOffset(offsetString)
        // Assert
        XCTAssertEqual(offset, OffsetProperty(x: 0, y: 0))
    }
    
    private func assert_alignment(_ horizonAlignment: HorizontalAlignmentProperty,
                                  alignmnent: Alignment) {
        XCTAssertEqual(horizonAlignment.getAlignment(), alignmnent)
    }
    
    private func assert_alignment(_ verticalAlignment: VerticalAlignmentProperty,
                                  alignmnent: Alignment) {
        XCTAssertEqual(verticalAlignment.getAlignment(), alignmnent)
    }
    
    private func assert_horizontal_alignment(_ horizontalAlignmentProperty: HorizontalAlignmentProperty,
                                             horizontalAlignmnent: HorizontalAlignment) {
        XCTAssertEqual(horizontalAlignmentProperty.getHorizontalAlignment(), horizontalAlignmnent)
    }
    
    private func assert_horizontal_text_alignment(_ horizonTextAlignment: HorizontalTextAlignmentProperty,
                                                  horizontalTextAlignmnent: TextAlignment) {
        XCTAssertEqual(horizonTextAlignment.getTextAlignment(), horizontalTextAlignmnent)
    }
    
    private func assert_vertical_alignment(_ verticalAlignmentProperty: VerticalAlignmentProperty,
                                           verticalAlignment: VerticalAlignment) {
        XCTAssertEqual(verticalAlignmentProperty.getVerticalAlignment(), verticalAlignment)
    }
    
}
