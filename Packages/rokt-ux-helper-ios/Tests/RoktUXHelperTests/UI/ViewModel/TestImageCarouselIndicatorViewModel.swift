import Foundation
import XCTest
import SwiftUI
@testable import RoktUXHelper
@testable import DcuiSchema

@available(iOS 15, *)
class TestImageCarouselIndicatorViewModel: XCTestCase {
    func testInit() {
        let sut = ImageCarouselIndicatorViewModel(
            positions: 4,
            duration: 1000,
            stylingProperties: [],
            indicatorStyle: [
                .init(
                    default: .init(
                        container: nil,
                        background: nil,
                        border: nil,
                        dimension: nil,
                        flexChild: nil,
                        spacing: nil
                    ),
                    pressed: nil,
                    hovered: nil,
                    focussed: nil,
                    disabled: nil
                )
            ],
            seenIndicatorStyle: [],
            activeIndicatorStyle: [
                .init(
                    default: .init(
                        container: nil,
                        background: nil,
                        border: nil,
                        dimension: nil,
                        flexChild: nil,
                        spacing: nil
                    ),
                    pressed: nil,
                    hovered: nil,
                    focussed: nil,
                    disabled: nil
                )
            ],
            layoutState: nil,
            shouldDisplayProgress: true
        )
        XCTAssertNotNil(sut)
        let rowViewModels = sut.rowViewModels
        
        XCTAssertEqual(rowViewModels.count, 4)
        
        XCTAssertEqual(rowViewModels[0].children?.count, 3)
        XCTAssertEqual(rowViewModels[1].children?.count, 3)
        XCTAssertEqual(rowViewModels[2].children?.count, 3)
        XCTAssertEqual(rowViewModels[3].children?.count, 3)
    }
    
}
