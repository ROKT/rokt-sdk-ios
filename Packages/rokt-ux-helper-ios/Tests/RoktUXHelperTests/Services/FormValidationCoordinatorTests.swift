import XCTest
@testable import RoktUXHelper

@available(iOS 15, *)
final class FormValidationCoordinatorTests: XCTestCase {

    func test_validateField_notifiesStatusChanges() {
        let coordinator = FormValidationCoordinator()
        var shouldBeValid = false

        let invalidExpectation = expectation(description: "Receives invalid status")
        let validExpectation = expectation(description: "Receives valid status")

        coordinator.registerField(
            key: "field",
            owner: self,
            validation: { shouldBeValid ? .valid : .invalid },
            onStatusChange: { status in
                switch status {
                case .invalid:
                    invalidExpectation.fulfill()
                case .valid:
                    validExpectation.fulfill()
                }
            }
        )

        XCTAssertFalse(coordinator.validate(field: "field"))
        wait(for: [invalidExpectation], timeout: 1.0)

        shouldBeValid = true
        XCTAssertTrue(coordinator.validate(field: "field"))
        wait(for: [validExpectation], timeout: 1.0)
    }

    func test_validateFields_returnsFalseWhenAnyFieldInvalid() {
        let coordinator = FormValidationCoordinator()
        var firstValid = false
        let secondValid = true

        coordinator.registerField(
            key: "first",
            owner: self,
            validation: { firstValid ? .valid : .invalid },
            onStatusChange: { _ in }
        )

        coordinator.registerField(
            key: "second",
            owner: self,
            validation: { secondValid ? .valid : .invalid },
            onStatusChange: { _ in }
        )

        XCTAssertFalse(coordinator.validate(fields: ["first", "second"]))

        firstValid = true
        XCTAssertTrue(coordinator.validate(fields: ["first", "second"]))
    }
}
