import Foundation
import Combine
@testable import RoktUXHelper

@available(iOS 13.0, *)
class MockEventProcessor: EventProcessing {
    var publisher: PassthroughSubject<(RoktEventRequest, EventProcessor?), Never> = .init()
    var handler: ((RoktEventRequest) -> Void)?
    
    init(handler: ((RoktEventRequest) -> Void)? = nil) {
        self.handler = handler
    }
    
    func handle(event: RoktEventRequest) {
        handler?(event)
    }
}
