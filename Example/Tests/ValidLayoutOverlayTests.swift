import SwiftUI
import Quick
import Nimble
import SafariServices
@testable import Rokt_Widget
@testable import RoktUXHelper

let kValidLayoutOverlayFilename = "partner1_overlay"

// Mocked time to test timings requests
let timingsDate = Date()
let timingsDateString: String = Rokt_Widget.EventDateFormatter.getDateString(timingsDate)
let timingsDateEpoch: String = String(Int(timingsDate.timeIntervalSince1970 * 1000))

final class ValidLayoutOverlayTests: QuickSpec {

    override func spec() {
        describe("Rokt modal controller") {

            var testVC: TestViewController!
            var events: [EventModel]!
            var errors: [String]!
            var timingsRequests: [MockTimingsRequest]!
            var partnerEvents: [String] = []
            var partnerEventsInfo: [String: RoktEvent] = [:]

            beforeEach {
                // Stub response for init call
                self.stubInit()

                // Stub response for widget call
                self.stubExecute(kValidLayoutOverlayFilename, isLayout: true)

                // Initialize event tracking arrays
                events = []
                errors = []
                timingsRequests = []
                partnerEvents = []
                partnerEventsInfo = [:]

                // Stub response for event call
                self.stubEvents(onEventReceive: { event in
                    // Ensure we're adding events on the main thread to avoid race conditions
                    DispatchQueue.main.async {
                        events.append(event)
                    }
                })

                // Mock date
                RoktSDKDateHandler.customDate = timingsDate
                DateHandler.customDate = timingsDate

                // Stub response for timings call
                self.stubTimings(onTimingsRequestReceive: { request in
                    // Ensure we're adding timing requests on the main thread to avoid race conditions
                    DispatchQueue.main.async {
                        timingsRequests.append(request)
                    }
                })

                // Stub response for diagnostic call
                self.stubDiagnostics(onDiagnosticsReceive: { (error) in
                    // Ensure we're adding errors on the main thread to avoid race conditions
                    DispatchQueue.main.async {
                        errors.append(error)
                    }
                })

                Rokt.events(identifier: "Test") { roktEvent in
                    var eventName = ""
                    if roktEvent is RoktEvent.FirstPositiveEngagement {
                        partnerEvents.append("FirstPositiveEngagement")
                        eventName = "FirstPositiveEngagement"
                    } else if roktEvent is RoktEvent.ShowLoadingIndicator {
                        partnerEvents.append("ShowLoadingIndicator")
                        eventName = "ShowLoadingIndicator"
                    } else if roktEvent is RoktEvent.HideLoadingIndicator {
                        partnerEvents.append("HideLoadingIndicator")
                        eventName = "HideLoadingIndicator"
                    } else if roktEvent is RoktEvent.OfferEngagement {
                        partnerEvents.append("OfferEngagement")
                        eventName = "OfferEngagement"
                    } else if roktEvent is RoktEvent.PositiveEngagement {
                        eventName = "PositiveEngagement"
                        partnerEvents.append("PositiveEngagement")
                    } else if roktEvent is RoktEvent.PlacementReady {
                        eventName = "PlacementReady"
                        partnerEvents.append("PlacementReady")
                    } else if roktEvent is RoktEvent.PlacementInteractive {
                        eventName = "PlacementInteractive"
                        partnerEvents.append("PlacementInteractive")
                    } else if roktEvent is RoktEvent.PlacementFailure {
                        eventName = "PlacementFailure"
                        partnerEvents.append("PlacementFailure")
                    } else if roktEvent is RoktEvent.PlacementCompleted {
                        eventName = "PlacementCompleted"
                        partnerEvents.append("PlacementCompleted")
                    } else if roktEvent is RoktEvent.PlacementClosed {
                        eventName = "PlacementClosed"
                        partnerEvents.append("PlacementClosed")
                    }
                    partnerEventsInfo[eventName] = roktEvent
                }
            }

            context("Layout Overlay UI tests") {

                beforeEach {
                    events = []
                    errors = []
                    timingsRequests = []
                    partnerEvents = []
                    partnerEventsInfo = [:]
                    testVC = TestViewController()
                    testVC.pageInitAttr = timingsDateEpoch

                    UIApplication.shared.keyWindow!.rootViewController = testVC
                    _ = testVC.view
                }

                afterEach {
                    // Clean up any view controllers to prevent memory leaks
                    if let viewController = UIApplication.topViewController(),
                       viewController is RoktUXSwiftUIViewController {
                        // Dismiss the Rokt view controller
                        viewController.dismiss(animated: false)
                    }

                    // Reset state
                    events = []
                    errors = []
                    timingsRequests = []
                    partnerEvents = []
                    partnerEventsInfo = [:]

                    // Reset any global mocking state
                    RoktSDKDateHandler.customDate = nil
                    DateHandler.customDate = nil

                    // Clear the view controller
                    testVC = nil
                    UIApplication.shared.keyWindow!.rootViewController = nil
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
                    expect(UIApplication.topViewController()).toEventually(beAnInstanceOf(RoktUXSwiftUIViewController.self),
                                                                           timeout: .seconds(19))
                    // check callbacks
                    expect(testVC.onShouldShowCallbackCalled).toEventually(beTrue(), timeout: .seconds(5))
                    expect(testVC.onShouldHideCallbackCalled).toEventually(beTrue(), timeout: .seconds(5))
                    expect(testVC.displayedOnce).toEventually(beTrue(), timeout: .seconds(5))

                    // check event
                    // page level events
                    expect(events.contains(EventModel(eventType: "SignalInitialize",
                                                      parentGuid: "bfbc0187-2d0f-4ad4-be6b-7545f9273567")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))
                    expect(events.contains(EventModel(eventType: "SignalLoadStart",
                                                      parentGuid: "bfbc0187-2d0f-4ad4-be6b-7545f9273567")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))
                    expect(events.contains(EventModel(eventType: "SignalLoadComplete",
                                                      parentGuid: "bfbc0187-2d0f-4ad4-be6b-7545f9273567")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))
                    // placment level events
                    expect(events.contains(EventModel(eventType: "SignalLoadStart",
                                                      parentGuid: "31b61e93-24bd-4735-995a-2f14d0673ec3")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))
                    expect(events.contains(EventModel(eventType: "SignalLoadComplete",
                                                      parentGuid: "31b61e93-24bd-4735-995a-2f14d0673ec3")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))
                    expect(events.contains(EventModel(eventType: "SignalImpression",
                                                      parentGuid: "31b61e93-24bd-4735-995a-2f14d0673ec3")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))

                    // slot level event
                    expect(events.contains(EventModel(eventType: "SignalImpression",
                                                      parentGuid: "20620e60-279e-475f-8e68-1b3816c0694")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))
                    // creative level event
                    expect(events.contains(EventModel(eventType: "SignalImpression",
                                                      parentGuid: "f5987bb9-f7ba-4a89-91e7-80a446c5d29c")))
                                                      .toEventually(beTrue(), timeout: .seconds(5))

                    // validate partner events
                    expect(partnerEvents.contains("ShowLoadingIndicator")).toEventually(beTrue(), timeout: .seconds(5))
                    expect(partnerEvents.contains("HideLoadingIndicator")).toEventually(beTrue(), timeout: .seconds(5))
                    expect(partnerEvents.contains("PlacementReady")).toEventually(beTrue(), timeout: .seconds(5))
                    // validate placementId(pluginId) in eventInfo
                    if let placementReadyInfo = partnerEventsInfo["PlacementReady"] as? RoktEvent.PlacementReady {
                        expect(placementReadyInfo.identifier).toEventually(equal("2675781658204502278"), timeout: .seconds(5))
                    }
                    expect(partnerEvents.contains("PlacementInteractive")).toEventually(beTrue(), timeout: .seconds(5))
                    // validate placementId(pluginId) in eventInfo
                    if let placementInteractiveInfo = partnerEventsInfo["PlacementInteractive"] as? RoktEvent
                        .PlacementInteractive {
                        expect(placementInteractiveInfo.identifier).toEventually(equal("2675781658204502278"),
                                                                                 timeout: .seconds(5))
                    }
                }

                it("layouts loaded successfully with timings contains pageInit") {
                    expect(UIApplication.topViewController()).toEventually(beAnInstanceOf(RoktUXSwiftUIViewController.self),
                                                                           timeout: .seconds(19))

                    let expectedTimingsRequest = MockTimingsRequest(eventTime: timingsDateString,
                                                                    pageId: "edecb4b2-91a5-4fd7-859f-82347b6e79fd",
                                                                    pageInstanceGuid: "bfbc0187-2d0f-4ad4-be6b-7545f9273567",
                                                                    pluginId: "2675781658204502278",
                                                                    pluginName: "test layout",
                                                                    timings: [])
                    // validate timings request sent
                    expect(timingsRequests.contains(expectedTimingsRequest)).toEventually(beTrue(), timeout: .seconds(10))

                    let matchedTimingsRequest = timingsRequests.first(where: { $0 == expectedTimingsRequest }) ??
                                               (timingsRequests.isEmpty ? nil : timingsRequests.last!)
                    // validate timings request contains all expected metrics
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.initStart.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.initEnd.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.pageInit.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.selectionStart.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.selectionEnd.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.experiencesRequestStart.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.experiencesRequestEnd.rawValue))
                        .toEventually(equal(timingsDateEpoch),
                                      timeout: .seconds(5))
                    // only for placement interactive as this went through UXHelper, thus it gets converted from date -> String -> date -> String,
                    // since its only accurate up to millisecond, the 100th microsecond can be lost
                    let roundedDate = String(Int((timingsDate.timeIntervalSince1970 * 1000).rounded()))
                    expect(matchedTimingsRequest?.getValueInTimings(name: TimingType.placementInteractive.rawValue))
                        .toEventually(equal(roundedDate),
                                      timeout: .seconds(5))
                }
            }
        }
    }
}
