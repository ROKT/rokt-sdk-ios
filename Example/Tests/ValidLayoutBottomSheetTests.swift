import SwiftUI
import Quick
import Nimble
import SafariServices
@testable import Rokt_Widget
@testable import RoktUXHelper

private let kValidLayoutBottomSheetFilename = "layout_bottomsheet"
private let kValidInitWithoutFeatureFlagFilename = "validInitWithoutFeatureFlag"

final class ValidLayoutBottomSheetTests: QuickSpec {
    override func spec() {
        describe("Rokt modal controller") {

            var testVC: TestViewController!
            var events: [EventModel]!
            var errors: [String]!
            var timingsRequests: [MockTimingsRequest] = []
            var partnerEvents: [String] = []

            beforeEach {
                // Stub response for init call
                self.stubInit(kValidInitWithoutFeatureFlagFilename)

                // Stub response for widget call
                self.stubExecute(kValidLayoutBottomSheetFilename, isLayout: true)

                // Initialize event tracking arrays so stub callbacks never
                // touch a `nil` IUO if a request fires before the inner
                // beforeEach assigns fresh arrays.
                events = []
                errors = []
                timingsRequests = []
                partnerEvents = []

                // Stub response for event call
                self.stubEvents(onEventReceive: { event in
                    events.append(event)
                })

                // Stub response for diagnostic call
                self.stubDiagnostics(onDiagnosticsReceive: { (error) in
                    errors.append(error)
                })

                // Mock date
                RoktSDKDateHandler.customDate = timingsDate

                // Stub response for timings call
                self.stubTimings(onTimingsRequestReceive: { request in
                    timingsRequests.append(request)
                })

                Rokt.events(identifier: "Test") { roktEvent in
                    if roktEvent is RoktEvent.FirstPositiveEngagement {
                        partnerEvents.append("FirstPositiveEngagement")
                    } else if roktEvent is RoktEvent.ShowLoadingIndicator {
                        partnerEvents.append("ShowLoadingIndicator")
                    } else if roktEvent is RoktEvent.HideLoadingIndicator {
                        partnerEvents.append("HideLoadingIndicator")
                    } else if roktEvent is RoktEvent.OfferEngagement {
                        partnerEvents.append("OfferEngagement")
                    } else if roktEvent is RoktEvent.PositiveEngagement {
                        partnerEvents.append("PositiveEngagement")
                    } else if roktEvent is RoktEvent.PlacementReady {
                        partnerEvents.append("PlacementReady")
                    } else if roktEvent is RoktEvent.PlacementInteractive {
                        partnerEvents.append("PlacementInteractive")
                    } else if roktEvent is RoktEvent.PlacementFailure {
                        partnerEvents.append("PlacementFailure")
                    } else if roktEvent is RoktEvent.PlacementCompleted {
                        partnerEvents.append("PlacementCompleted")
                    } else if roktEvent is RoktEvent.PlacementClosed {
                        partnerEvents.append("PlacementClosed")
                    }
                }
            }

            context("Layout BottomSheet UI tests") {

                beforeEach {
                    events = []
                    errors = []
                    timingsRequests = []
                    partnerEvents = []
                    testVC = TestViewController()

                    testVC.installInTestWindow()
                }

                afterEach {
                    // Dismiss the bottom sheet modal if it's still on screen so
                    // the next test starts with a clean window hierarchy and
                    // the SDK isn't holding a reference to a presented
                    // controller from a previous run.
                    if let viewController = UIApplication.topViewController(),
                       viewController is RoktUXSwiftUIViewController {
                        viewController.dismiss(animated: false)
                    }

                    // Reset state
                    events = []
                    errors = []
                    timingsRequests = []
                    partnerEvents = []

                    // Reset any global mocking state
                    RoktSDKDateHandler.customDate = nil

                    // Clear the view controller
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
                    expect(UIApplication.topViewController()).toEventually(
                        beAnInstanceOf(RoktUXSwiftUIViewController.self),
                        timeout: .seconds(19)
                    )
                    // check callbacks
                    expect(testVC.onShouldShowCallbackCalled).toEventually(beTrue(), timeout: .seconds(10))
                    expect(testVC.onShouldHideCallbackCalled).toEventually(beTrue(), timeout: .seconds(10))
                    expect(testVC.displayedOnce).toEventually(beTrue(), timeout: .seconds(10))

                    // check events — the whole set shares one budget, because giving each
                    // event its own made the first one absorb all of the pipeline's latency
                    // and fail on its own on slow runners. See `expectEventuallyRecorded`.
                    let pageGuid = "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    let placementGuid = "21b61e93-24bd-4735-995a-2f14d0673ec2"
                    let slotGuid = "f0620e60-279e-475f-8e68-1b3816c0691c"
                    let creativeGuid = "f5987bb9-f7ba-4a89-91e7-80a446c5d29c"
                    expectEventuallyRecorded([
                        // page level events
                        EventModel(eventType: "SignalInitialize", parentGuid: pageGuid),
                        EventModel(eventType: "SignalLoadStart", parentGuid: pageGuid),
                        EventModel(eventType: "SignalLoadComplete", parentGuid: pageGuid),
                        // placement level events
                        EventModel(eventType: "SignalLoadStart", parentGuid: placementGuid),
                        EventModel(eventType: "SignalLoadComplete", parentGuid: placementGuid),
                        EventModel(eventType: "SignalImpression", parentGuid: placementGuid),
                        // slot level event
                        EventModel(eventType: "SignalImpression", parentGuid: slotGuid),
                        // creative level events
                        EventModel(eventType: "SignalImpression", parentGuid: creativeGuid),
                        EventModel(eventType: "SignalViewed", parentGuid: creativeGuid)
                    ], in: events)

                    // validate timings requests — wait for the request to land
                    // first because the stub records asynchronously on the main
                    // queue, so the synchronous reads below would race the
                    // network completion otherwise.
                    expect(timingsRequests.count).toEventually(equal(1), timeout: .seconds(15))
                    expect(timingsRequests.first?.pageId).to(equal("edecb4b2-91a5-4fd7-859f-82347b6e79fd"))
                    expect(timingsRequests.first?.pageInstanceGuid).to(equal("afbc0187-2d0f-4ad4-be6b-7545f9273565"))
                    expect(timingsRequests.first?.pluginId).to(equal("2675781658204502278"))
                    expect(timingsRequests.first?.pluginName).to(equal("test layout"))
                    expect(timingsRequests.first?.timings.count).to(equal(7))
                    expect(timingsRequests.first?.timings[0]["name"]).to(equal("initStart"))
                    expect(timingsRequests.first?.timings[0]["value"]).to(equal(timingsDateEpoch))

                }
            }
        }
    }
}
