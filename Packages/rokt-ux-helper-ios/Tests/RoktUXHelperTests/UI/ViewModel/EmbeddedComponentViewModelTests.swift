import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
final class EmbeddedComponentViewModelTests: XCTestCase {

    func test_updateHeight_roundsUpAndEmitsOnlyOnStepUp() {
        // Arrange
        var received: [CGFloat] = []
        let viewModel = get_model { received.append($0) }

        // Act
        viewModel.updateHeight(100.1)
        viewModel.updateHeight(100.9)
        viewModel.updateHeight(101.01)

        // Assert
        XCTAssertEqual(received, [100.1, 101.01],
                       "Should only fire when the rounded-up integer actually steps up")
    }

    func test_updateHeight_doesNotEmitForSameRoundedUpValue() {
        // Arrange
        var callCount = 0
        let viewModel = get_model { _ in callCount += 1 }

        // Act
        viewModel.updateHeight(50.0)
        viewModel.updateHeight(50.2)
        viewModel.updateHeight(50.8)
        viewModel.updateHeight(50.1)

        // Assert
        XCTAssertEqual(callCount, 2,
                       "Should fire at 50.0 and 50.2 only, not for further sub-pixel tweaks")
    }
    
    private func get_model(
        eventService: EventService? = nil,
        layoutState: LayoutState = LayoutState(),
        onSizeChange: @escaping (CGFloat) -> Void
    ) -> EmbeddedComponentViewModel {
        EmbeddedComponentViewModel(
            layout: .empty,
            layoutState: layoutState,
            eventService: eventService,
            onLoad: nil,
            onSizeChange: onSizeChange
        )
    }
}
