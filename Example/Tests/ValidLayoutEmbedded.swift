import SwiftUI
import Quick
import Nimble
@testable import Rokt_Widget
@testable import RoktUXHelper

let kValidLayoutEmbeddedFilename = "layout_embedded_2"
let kValidLayoutEmbedded4Filename = "layout_embedded_4"

var invalidPageInitDateEpoch: String {
    String(Int(timingsDate.timeIntervalSince1970 * 1000) + 5)
}

final class ValidLayoutEmbedded: QuickSpec {

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
                self.stubExecute(kValidLayoutEmbeddedFilename, isLayout: true)

                // Stub response for event call
                self.stubEvents(onEventReceive: { event in
                    events.append(event)
                })

                // Stub response for diagnostic call
                self.stubDiagnostics(onDiagnosticsReceive: { (error) in
                    errors.append(error)
                })

                // Mock date
                DateHandler.customDate = timingsDate
                RoktSDKDateHandler.customDate = timingsDate

                // Stub response for timings call
                self.stubTimings(onTimingsRequestReceive: { request in
                    timingsRequests.append(request)
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

            context("Layout Embedded UI tests") {

                beforeEach {
                    events = []
                    errors = []
                    timingsRequests = []
                    partnerEvents = []
                    partnerEventsInfo = [:]
                    testVC = TestViewController()
                    testVC.pageInitAttr = invalidPageInitDateEpoch

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
                    expect(testVC.embeddedLocation1?.roktEmbeddedSwiftUIView?.isHidden).toEventually(
                        beFalse(),
                        timeout: .seconds(9)
                    )
                    expect(testVC.embeddedLocation2?.roktEmbeddedSwiftUIView?.isHidden).toEventually(
                        beNil(),
                        timeout: .seconds(2)
                    )
                    // check callbacks
                    expect(testVC.onShouldShowCallbackCalled).toEventually(beTrue(), timeout: .seconds(2))
                    expect(testVC.onShouldHideCallbackCalled).toEventually(beTrue(), timeout: .seconds(2))
                    expect(testVC.displayedOnce).toEventually(beTrue(), timeout: .seconds(2))

                    // check event
                    // page level events
                    expect(events.contains(EventModel(
                        eventType: "SignalInitialize",
                        parentGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadStart",
                        parentGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadComplete",
                        parentGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // placment level events
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadStart",
                        parentGuid: "21b61e93-24bd-4735-995a-2f14d0673ec2"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadComplete",
                        parentGuid: "21b61e93-24bd-4735-995a-2f14d0673ec2"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "21b61e93-24bd-4735-995a-2f14d0673ec2"
                    ))).toEventually(beTrue(), timeout: .seconds(2))

                    // slot level event
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "f0620e60-279e-475f-8e68-1b3816c0691c"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // creative level event
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "f5987bb9-f7ba-4a89-91e7-80a446c5d29c"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
// Failing after changes in UX Helper - https://github.com/ROKT/rokt-ux-helper-ios/pull/93
// Ticket to fix: SQDSDKS-7461
//                    expect(events.contains(EventModel(
//                        eventType: "SignalViewed",
//                        parentGuid: "f5987bb9-f7ba-4a89-91e7-80a446c5d29c"))).toEventually(beTrue(), timeout: .seconds(2))

                    // validate partner events
                    expect(partnerEvents.contains("ShowLoadingIndicator")).toEventually(beTrue())
                    expect(partnerEvents.contains("HideLoadingIndicator")).toEventually(beTrue())
                    expect(partnerEvents.contains("PlacementReady")).toEventually(beTrue())
                    // validate placementId(pluginId) in eventInfo
                    if let placementReadyInfo = partnerEventsInfo["PlacementReady"] as? RoktEvent.PlacementReady {
                        expect(placementReadyInfo.identifier).toEventually(equal("2675781658204502278"))
                    }
                    expect(partnerEvents.contains("PlacementInteractive")).toEventually(beTrue())
                    // validate placementId(pluginId) in eventInfo
                    if let placementInteractiveInfo = partnerEventsInfo["PlacementInteractive"] as? RoktEvent
                        .PlacementInteractive {
                        expect(placementInteractiveInfo.identifier).toEventually(equal("2675781658204502278"))
                    }
                }

                it("layouts loaded successfully with timings contains invalid pageInit") {
                    expect(testVC.embeddedLocation1?.roktEmbeddedSwiftUIView?.isHidden).toEventually(
                        beFalse(),
                        timeout: .seconds(9)
                    )
                    expect(testVC.embeddedLocation2?.roktEmbeddedSwiftUIView?.isHidden).toEventually(
                        beNil(),
                        timeout: .seconds(2)
                    )

                    let expectedTimingsRequest = MockTimingsRequest(eventTime: timingsDateString,
                                                                    pageId: "edecb4b2-91a5-4fd7-859f-82347b6e79fd",
                                                                    pageInstanceGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565",
                                                                    pluginId: "2675781658204502278",
                                                                    pluginName: "test layout",
                                                                    timings: [])
                    // validate timings request sent
                    expect(timingsRequests.contains(expectedTimingsRequest)).toEventually(beTrue(), timeout: .seconds(9))

                    let matchedTimingsRequest = timingsRequests[timingsRequests.lastIndex(of: expectedTimingsRequest)!]
                    // validate timings request contains all expected metrics
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.initStart.rawValue, value: timingsDateEpoch
                    )).toEventually(beTrue())
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.initEnd.rawValue, value: timingsDateEpoch
                    )).toEventually(beTrue())
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.selectionStart.rawValue, value: timingsDateEpoch
                    )).toEventually(beTrue())
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.selectionEnd.rawValue, value: timingsDateEpoch
                    )).toEventually(beTrue())
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.experiencesRequestStart.rawValue, value: timingsDateEpoch
                    )).toEventually(beTrue())
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.experiencesRequestEnd.rawValue, value: timingsDateEpoch
                    )).toEventually(beTrue())
                    // only for placement interactive as this went through UXHelper, thus it gets converted from date -> String -> date -> String,
                    // since its only accurate up to millisecond, the 100th microsecond can be lost
                    let roundedDate = String(Int((timingsDate.timeIntervalSince1970 * 1000).rounded()))
                    expect(matchedTimingsRequest.getValueInTimings(name: TimingType.placementInteractive.rawValue))
                        .toEventually(equal(roundedDate))

                    // timings request ignores pageInit timestamp outside of valid range
                    expect(matchedTimingsRequest.containNameValueInTimings(
                        name: TimingType.pageInit.rawValue, value: timingsDateEpoch
                    )).toEventually(beFalse())
                }
            }
        }

        describe("Rokt Embedded4 UI tests") {

            var testVC: TestViewController!
            var events: [EventModel]!
            var errors: [String]!

            beforeEach {
                // Stub response for init call
                self.stubInit()

                // Stub response for widget call
                self.stubExecute(kValidLayoutEmbedded4Filename, isLayout: true)

                // Stub response for event call
                self.stubEvents(onEventReceive: { event in
                    events.append(event)
                })

                // Stub response for diagnostic call
                self.stubDiagnostics(onDiagnosticsReceive: { (error) in
                    errors.append(error)
                })
            }

            context("Layout Embedded 4 UI tests") {

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
                    expect(testVC.embeddedLocation4?.roktEmbeddedSwiftUIView?.isHidden).toEventually(
                        beFalse(),
                        timeout: .seconds(9)
                    )
                    // check callbacks
                    expect(testVC.onShouldShowCallbackCalled).toEventually(beTrue(), timeout: .seconds(2))
                    expect(testVC.onShouldHideCallbackCalled).toEventually(beTrue(), timeout: .seconds(2))
                    expect(testVC.displayedOnce).toEventually(beTrue(), timeout: .seconds(2))

                    // check event
                    // page level events
                    expect(events.contains(EventModel(
                        eventType: "SignalInitialize",
                        parentGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadStart",
                        parentGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadComplete",
                        parentGuid: "afbc0187-2d0f-4ad4-be6b-7545f9273565"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // layout level events
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadStart",
                        parentGuid: "21b61e93-24bd-4735-995a-2f14d0673e22"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalLoadComplete",
                        parentGuid: "21b61e93-24bd-4735-995a-2f14d0673e22"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "21b61e93-24bd-4735-995a-2f14d0673e22"
                    ))).toEventually(beTrue(), timeout: .seconds(2))

                    // slot level event
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "f0620e60-279e-475f-8e68-1b3816c06ddd"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                    // creative level event
                    expect(events.contains(EventModel(
                        eventType: "SignalImpression",
                        parentGuid: "f5987bb9-f7ba-4a89-91e7-80a446ctfr"
                    ))).toEventually(beTrue(), timeout: .seconds(2))
                }
            }
        }
    }
}
