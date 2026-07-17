import XCTest
import UIKit
@testable import Rokt_Widget

final class TestEventFlushLifecycleObserver: XCTestCase {

    func test_didEnterBackground_triggersFlush() {
        let center = NotificationCenter()
        var flushCount = 0
        let observer = EventFlushLifecycleObserver(notificationCenter: center, flush: { flushCount += 1 })

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertEqual(flushCount, 1)
        withExtendedLifetime(observer) {}
    }

    func test_otherNotifications_doNotTriggerFlush() {
        let center = NotificationCenter()
        var flushCount = 0
        let observer = EventFlushLifecycleObserver(notificationCenter: center, flush: { flushCount += 1 })

        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(flushCount, 0)
        withExtendedLifetime(observer) {}
    }
}
