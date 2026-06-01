import Foundation
import Combine

@available(iOS 13.0, *)
protocol LayoutStateRepresenting: Hashable, Equatable, AnyObject {
    var items: [String: Any] { get set }
    var itemsPublisher: CurrentValueSubject<[String: Any], Never> { get }
    var actionCollection: ActionCollecting { get set }
    var imageLoader: RoktUXImageLoader? { get }
    var colorMode: RoktUXConfig.ColorMode? { get }
    var config: RoktUXConfig? { get }
    var initialPluginViewState: RoktPluginViewState? { get }
    var validationCoordinator: FormValidationCoordinating { get }
    func setLayoutType(_ type: RoktUXPlacementLayoutCode)
    func layoutType() -> RoktUXPlacementLayoutCode
    func closeOnComplete() -> Bool
    func getGlobalBreakpointIndex(_ width: CGFloat?) -> Int
    func capturePluginViewState(offerIndex: Int?, dismiss: Bool?)
    func publishStateChange()
    func setGlobalCustomState(key: String, value: Int)
    func resetGlobalCustomState(key: String)
    func globalCustomStateValue(for key: String) -> Int?
}
