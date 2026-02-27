import SwiftUI
import Quick
import Nimble
import SafariServices
@testable import Rokt_Widget
@testable import RoktUXHelper

let kValidLayoutGroupedFilename = "layout_grouped_distribution"

final class ValidLayoutGroupedTests: QuickSpec {

    override func spec() {
        describe("Rokt modal controller") {

            var testVC: TestViewController!
            var events: [EventModel]!
            var errors: [String]!

            beforeEach {
                // Stub response for init call
                self.stubInit()

                // Stub response for widget call
                self.stubExecute(kValidLayoutGroupedFilename, isLayout: true)

                // Stub response for event call
                self.stubEvents(onEventReceive: { event in
                    events.append(event)
                })

                // Stub response for diagnostic call
                self.stubDiagnostics(onDiagnosticsReceive: { (error) in
                    errors.append(error)
                })
            }

            context("Layout Grouped Overlay UI tests") {

                beforeEach {
                    events = []
                    errors = []
                    testVC = TestViewController()

                    UIApplication.shared.keyWindow!.rootViewController = testVC
                    _ = testVC.view
                }

                it("1. layout is configured") {
                    waitUntil(timeout: .seconds(10)) { done in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                            done()
                        }
                    }
                    expect(Rokt.shared).to(beAKindOf(Rokt.self))
                }

                it("layouts loaded successfully with events") {
                    expect(UIApplication.topViewController()).toEventually(
                        beAnInstanceOf(RoktUXSwiftUIViewController.self),
                        timeout: .seconds(19)
                    )
                    // check callbacks
                    expect(testVC.onShouldShowCallbackCalled).toEventually(beTrue(), timeout: .seconds(2))
                    expect(testVC.onShouldHideCallbackCalled).toEventually(beTrue(), timeout: .seconds(2))
                    expect(testVC.displayedOnce).toEventually(beTrue(), timeout: .seconds(2))

                    // check event
                    // page level events
                    expect(events.contains(EventModel(
                        eventType: "SignalInitialize",
                        parentGuid: "b05a003b-d837-4438-bcc7-1651f1b7048f"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadStart",
                        parentGuid: "b05a003b-d837-4438-bcc7-1651f1b7048f"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadComplete",
                        parentGuid: "b05a003b-d837-4438-bcc7-1651f1b7048f"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // placment level events
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadStart",
                        parentGuid: "9507e151-bde1-4378-b327-692ae5665fe8"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadComplete",
                        parentGuid: "9507e151-bde1-4378-b327-692ae5665fe8"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "9507e151-bde1-4378-b327-692ae5665fe8"
                    ))).toEventually(beTrue(), timeout: .seconds(2))

                    // slot level event for first slot
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "b8a58fe7-1e9b-405b-82b8-485fe6498896"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // creative level event for second creative
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "8bd6d8a3-0eb0-40cc-b1ce-9abacd666873"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // slot level event for second slot
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "3371ff27-bfea-40e0-95d3-ec7fb52ba760"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // creative level event for second creative
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "408881f7-2744-44e0-a94d-f908860ba00f"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                }
            }
        }
    }
}
