import Foundation

enum ValidationStatus: Equatable {
    case valid
    case invalid
}

protocol FormValidationCoordinating: AnyObject {
    typealias ValidationClosure = () -> ValidationStatus

    func registerField(
        key: String,
        owner: AnyObject,
        validation: @escaping ValidationClosure,
        onStatusChange: @escaping (ValidationStatus) -> Void
    )

    func unregisterField(for key: String, owner: AnyObject)

    @discardableResult
    func validate(fields keys: [String]) -> Bool

    @discardableResult
    func validate(field key: String) -> Bool
}

final class FormValidationCoordinator: FormValidationCoordinating {
    private struct Registration {
        var validation: ValidationClosure
        var onStatusChange: (ValidationStatus) -> Void
        var lastStatus: ValidationStatus?
        var owner: ObjectIdentifier
    }

    private var registrations: [String: Registration] = [:]
    private let queue = DispatchQueue(label: "com.roktuxhelper.validation", attributes: .concurrent)

    func registerField(
        key: String,
        owner: AnyObject,
        validation: @escaping ValidationClosure,
        onStatusChange: @escaping (ValidationStatus) -> Void
    ) {
        queue.async(flags: .barrier) {
            self.registrations[key] = Registration(
                validation: validation,
                onStatusChange: onStatusChange,
                lastStatus: nil,
                owner: ObjectIdentifier(owner)
            )
        }
    }

    func unregisterField(for key: String, owner: AnyObject) {
        queue.async(flags: .barrier) {
            guard let registration = self.registrations[key] else { return }
            if registration.owner == ObjectIdentifier(owner) {
                self.registrations.removeValue(forKey: key)
            }
        }
    }

    @discardableResult
    func validate(fields keys: [String]) -> Bool {
        // Eagerly validate every field so all onStatusChange callbacks fire,
        // even after the first failure (allSatisfy alone would short-circuit).
        keys.map { validate(field: $0) }.allSatisfy { $0 }
    }

    @discardableResult
    func validate(field key: String) -> Bool {
        var registration: Registration?
        queue.sync {
            registration = registrations[key]
        }

        guard var registration else { return true }

        let status = registration.validation()
        registration.lastStatus = status

        queue.async(flags: .barrier) {
            // Only update if the field is still registered to the same owner
            if self.registrations[key]?.owner == registration.owner {
                self.registrations[key] = registration
            }
        }

        DispatchQueue.main.async {
            registration.onStatusChange(status)
        }

        return status == .valid
    }
}
