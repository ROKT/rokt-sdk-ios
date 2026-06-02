import Foundation
import SwiftUI
import Combine
@testable import RoktUXHelper
import DcuiSchema

@available(iOS 15, *)
class MockLayoutState: LayoutStateRepresenting {
    var items: [String: Any] = [:]
    var itemsPublisher: CurrentValueSubject<[String: Any], Never> = .init([:])
    var actionCollection: ActionCollecting = ActionCollection()
    var imageLoader: RoktUXImageLoader?
    var colorMode: RoktUXConfig.ColorMode?
    var config: RoktUXConfig?
    var initialPluginViewState: RoktPluginViewState?
    var validationCoordinator: FormValidationCoordinating = FormValidationCoordinator()
    private var currentLayoutType: RoktUXPlacementLayoutCode = .overlayLayout
    var shouldCloseOnComplete: Bool = false
    var mockBreakpointIndex: Int = 0
    private var globalStates: RoktUXCustomStateMap = [:]
    private var layoutVariantStates: RoktUXCustomStateMap = [:]

    init() {
        items[LayoutState.globalCustomStateMapKey] = Binding<RoktUXCustomStateMap?>(
            get: { [weak self] in
                guard let self else { return nil }
                return self.globalStates.isEmpty ? nil : self.globalStates
            },
            set: { [weak self] newValue in
                self?.globalStates = newValue ?? [:]
            }
        )

        items[LayoutState.customStateMap] = Binding<RoktUXCustomStateMap?>(
            get: { [weak self] in
                guard let self else { return nil }
                return self.layoutVariantStates.isEmpty ? nil : self.layoutVariantStates
            },
            set: { [weak self] newValue in
                self?.layoutVariantStates = newValue ?? [:]
            }
        )
    }

    func setLayoutType(_ type: RoktUXPlacementLayoutCode) {
        currentLayoutType = type
    }

    func layoutType() -> RoktUXPlacementLayoutCode {
        return currentLayoutType
    }

    func closeOnComplete() -> Bool {
        return shouldCloseOnComplete
    }

    func getGlobalBreakpointIndex(_ width: CGFloat?) -> Int {
        return mockBreakpointIndex
    }

    func capturePluginViewState(offerIndex: Int?, dismiss: Bool?) {
        // No-op for mock
    }

    func publishStateChange() {
        // No-op for mock
    }

    func setGlobalCustomState(key: String, value: Int) {
        let identifier = CustomStateIdentifiable(position: nil, key: key)
        globalStates[identifier] = value
        itemsPublisher.send(items)
    }

    func resetGlobalCustomState(key: String) {
        let identifier = CustomStateIdentifiable(position: nil, key: key)
        globalStates.removeValue(forKey: identifier)
        itemsPublisher.send(items)
    }

    func globalCustomStateValue(for key: String) -> Int? {
        let identifier = CustomStateIdentifiable(position: nil, key: key)
        return globalStates[identifier]
    }

    func layoutVariantCustomStateValue(for key: String, position: Int?) -> Int? {
        let identifier = CustomStateIdentifiable(position: position, key: key)
        return layoutVariantStates[identifier]
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    static func == (lhs: MockLayoutState, rhs: MockLayoutState) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}
