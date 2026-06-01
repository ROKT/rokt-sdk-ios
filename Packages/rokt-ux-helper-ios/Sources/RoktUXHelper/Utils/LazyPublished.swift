import Foundation
import Combine

@available(iOS 14.0, *)
@propertyWrapper
class LazyPublished<Value: Equatable>: ObservableObject {

    static subscript<T: ObservableObject>(
        _enclosingInstance instance: T,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<T, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<T, LazyPublished>
    ) -> Value {
        get {
            instance[keyPath: storageKeyPath].storage
        }
        set {
            let oldValue = instance[keyPath: storageKeyPath].storage
            if oldValue != newValue {
                (instance.objectWillChange as? ObservableObjectPublisher)?.send()
            }
            instance[keyPath: storageKeyPath].storage = newValue
        }
    }

    @available(
        *, unavailable,
        message: "@LazyPublished can only be applied to classes"
    )
    var wrappedValue: Value {
        get { storage }
        set { assertionFailure("Can only be applied to classes") } // swiftlint:disable:this unused_setter_value
    }

    var projectedValue: Published<Value>.Publisher {
        get { $storage }
        set { $storage = newValue }
    }

    @Published private var storage: Value

    init(wrappedValue: Value) {
        storage = wrappedValue
    }
}
