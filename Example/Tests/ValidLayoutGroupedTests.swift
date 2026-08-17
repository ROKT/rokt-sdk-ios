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

                // Initialize event tracking arrays so stub callbacks never
                // touch a `nil` IUO if a request fires before the inner
                // beforeEach assigns fresh arrays.
                events = []
                errors = []

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
                    // Installed per example, not here: installing drives a placement, and
                    // one started here outlived the examples that never waited for it.
                }

                afterEach {
                    if let viewController = UIApplication.topViewController(),
                       viewController is RoktUXSwiftUIViewController {
                        viewController.dismiss(animated: false)
                    }

                    events = []
                    errors = []

                    testVC = nil
                    UIViewController.clearTestWindowRoot()
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
                    testVC.installInTestWindow()

                    expect(UIApplication.topViewController()).toEventually(
                        beAnInstanceOf(RoktUXSwiftUIViewController.self),
                        timeout: .seconds(19)
                    )
                    // check callbacks
                    expect(testVC.onShouldShowCallbackCalled).toEventually(beTrue(), timeout: .seconds(10))
                    expect(testVC.onShouldHideCallbackCalled).toEventually(beTrue(), timeout: .seconds(10))
                    expect(testVC.displayedOnce).toEventually(beTrue(), timeout: .seconds(10))

                    // check event
                    // page level events
                    expectEventuallyRecorded([
                        EventModel(eventType: "SignalInitialize", parentGuid: "b05a003b-d837-4438-bcc7-1651f1b7048f"),
                        EventModel(eventType: "SignalLoadStart", parentGuid: "b05a003b-d837-4438-bcc7-1651f1b7048f"),
                        EventModel(eventType: "SignalLoadComplete", parentGuid: "b05a003b-d837-4438-bcc7-1651f1b7048f"),
                        // placment level events
                        EventModel(eventType: "SignalLoadStart", parentGuid: "9507e151-bde1-4378-b327-692ae5665fe8"),
                        EventModel(eventType: "SignalLoadComplete", parentGuid: "9507e151-bde1-4378-b327-692ae5665fe8"),
                        EventModel(eventType: "SignalImpression", parentGuid: "9507e151-bde1-4378-b327-692ae5665fe8")
                    ], in: events)

                    // slot level event for first slot
                    expectEventuallyRecorded([
                        EventModel(eventType: "SignalImpression", parentGuid: "b8a58fe7-1e9b-405b-82b8-485fe6498896"),
                        // creative level event for second creative
                        EventModel(eventType: "SignalImpression", parentGuid: "8bd6d8a3-0eb0-40cc-b1ce-9abacd666873"),
                        EventModel(eventType: "SignalViewed", parentGuid: "8bd6d8a3-0eb0-40cc-b1ce-9abacd666873"),
                        // slot level event for second slot
                        EventModel(eventType: "SignalImpression", parentGuid: "3371ff27-bfea-40e0-95d3-ec7fb52ba760"),
                        // creative level event for second creative
                        EventModel(eventType: "SignalImpression", parentGuid: "408881f7-2744-44e0-a94d-f908860ba00f"),
                        EventModel(eventType: "SignalViewed", parentGuid: "408881f7-2744-44e0-a94d-f908860ba00f")
                    ], in: events)
                }
            }
        }
    }
}
