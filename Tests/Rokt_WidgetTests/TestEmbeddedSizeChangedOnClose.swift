import SwiftUI
import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

/// Dismissal unloads the execute before the embedded view reports its final height, so the 0 that
/// tells a host to collapse has to survive that teardown and must not sit behind the debounce.
final class TestEmbeddedSizeChangedOnClose: XCTestCase {

    private let executeId = "test-execute-id"
    private let location = "Location1"

    private func makeImplementation() -> RoktInternalImplementation {
        let impl = RoktInternalImplementation()
        impl.stateManager.addState(id: executeId,
                                   state: ExecuteStateBag(uxHelper: nil, onRoktEvent: nil))
        return impl
    }

    func test_heightZero_isDeliveredAfterPlacementUnload() {
        let impl = makeImplementation()
        var sizeEvents: [RoktEvent.EmbeddedSizeChanged] = []
        impl.setEventHandler({ event in
            if let size = event as? RoktEvent.EmbeddedSizeChanged { sizeEvents.append(size) }
        }, for: executeId)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutInteractive(layoutId: "l1"))
        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutCompleted(layoutId: "l1"))
        XCTAssertNil(impl.stateManager.getState(id: executeId))

        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: location, widgetHeight: 0)

        XCTAssertEqual(sizeEvents.count, 1)
        XCTAssertEqual(sizeEvents.first?.identifier, location)
        XCTAssertEqual(sizeEvents.first?.updatedHeight, 0)
    }

    func test_heightZero_bypassesTheDebounceAndCancelsAPendingHeight() {
        let impl = makeImplementation()
        var heights: [CGFloat] = []
        impl.setEventHandler({ event in
            if let size = event as? RoktEvent.EmbeddedSizeChanged { heights.append(size.updatedHeight) }
        }, for: executeId)

        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: location, widgetHeight: 240)
        XCTAssertTrue(heights.isEmpty, "A non-zero height should still be debounced")

        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: location, widgetHeight: 0)
        XCTAssertEqual(heights, [0])

        waitForDebounceToDrain()
        XCTAssertEqual(heights, [0], "The superseded height must not arrive after the collapse")
    }

    func test_pendingHeight_isNotCancelledByAnotherPlacement() {
        let impl = makeImplementation()
        var heightsByPlacement: [String: CGFloat] = [:]
        impl.setEventHandler({ event in
            if let size = event as? RoktEvent.EmbeddedSizeChanged {
                heightsByPlacement[size.identifier] = size.updatedHeight
            }
        }, for: executeId)

        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: "Location1", widgetHeight: 120)
        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: "Location2", widgetHeight: 240)

        waitForDebounceToDrain()

        XCTAssertEqual(heightsByPlacement, ["Location1": 120, "Location2": 240])
    }

    func test_closeEmbedded_onSwiftUILayout_reportsZeroHeight() {
        let viewModel = RoktLayoutViewModel(
            identifier: "page-identifier",
            location: location,
            attributes: [:],
            config: nil,
            placementOptions: nil,
            onRoktEvent: nil
        )
        var reportedHeights: [CGFloat] = []

        viewModel.load(onSizeChanged: { reportedHeights.append($0) }, injectedView: {
            Text("Embedded placement")
        })
        viewModel.closeEmbedded()

        XCTAssertEqual(reportedHeights, [0])
    }

    /// A second execute can render into the same location while the first is still on screen, so
    /// the older execute collapsing must not cancel the newer one's pending height and leave the
    /// host collapsed over a visible placement.
    func test_collapseOfOneExecute_doesNotCancelAnotherExecutesPendingHeight() {
        let impl = makeImplementation()
        let laterExecuteId = "later-execute-id"
        impl.stateManager.addState(id: laterExecuteId,
                                   state: ExecuteStateBag(uxHelper: nil, onRoktEvent: nil))
        var heights: [CGFloat] = []
        impl.setEventHandler({ event in
            if let size = event as? RoktEvent.EmbeddedSizeChanged { heights.append(size.updatedHeight) }
        }, for: laterExecuteId)
        impl.setEventHandler({ event in
            if let size = event as? RoktEvent.EmbeddedSizeChanged { heights.append(size.updatedHeight) }
        }, for: executeId)

        impl.callOnEmbeddedSizeChange(laterExecuteId, selectedPlacementName: location, widgetHeight: 240)
        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: location, widgetHeight: 0)
        XCTAssertEqual(heights, [0])

        waitForDebounceToDrain()
        XCTAssertEqual(heights, [0, 240], "The newer execute's height must still arrive")
    }

    /// `initWith` discards the execution state, so a handler retained for a placement that was on
    /// screen at the time would otherwise be held for the life of the process and keep forwarding
    /// that placement's events.
    func test_reinitialising_releasesRetainedHandlersAndPendingHeights() {
        let impl = makeImplementation()
        impl.makeTxnInitServiceOverride = { tagId in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: FailingInitHTTPClient(),
                maxRetries: 0,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
        var received: [RoktEvent] = []
        impl.setEventHandler({ received.append($0) }, for: executeId)
        impl.callOnEmbeddedSizeChange(executeId, selectedPlacementName: location, widgetHeight: 240)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        XCTAssertNil(impl.eventHandler(for: executeId))
        waitForDebounceToDrain()
        XCTAssertTrue(received.isEmpty, "A reset must not keep forwarding the previous layout's events")
    }

    /// The bag is already gone after a reset, so the unload guard has to release the handler
    /// itself rather than returning early and leaking it.
    func test_unloadWithoutAStateBag_stillReleasesTheRetainedHandler() {
        let impl = makeImplementation()
        impl.setEventHandler({ _ in }, for: executeId)
        impl.stateManager.removeState(id: executeId)

        impl.callOnRoktUXEvent(executeId, uxEvent: RoktUXEvent.LayoutCompleted(layoutId: "l1"))

        let released = expectation(description: "retained handler released")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { released.fulfill() }
        wait(for: [released], timeout: 2)
        XCTAssertNil(impl.eventHandler(for: executeId))
    }

    private func waitForDebounceToDrain() {
        let drained = expectation(description: "debounced size changes delivered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

/// Keeps `initWith` off the network; the response is irrelevant to what these tests assert.
private final class FailingInitHTTPClient: HTTPClientAdapter {
    func updateTimeout(timeout: Double) {}

    @discardableResult
    func startRequestWith(
        urlAddress: String,
        method: RoktHTTPMethod,
        parameters: RoktHTTPParameters?,
        parameterArray: RoktHTTPParameterArray?,
        headers: RoktHTTPHeaders?,
        onRequestStart: (() -> Void)?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktHTTPRequestResult) -> Void)?
    ) -> URLRequest? {
        let url = URL(string: urlAddress)!
        completionQueue.async {
            completionHandler?(
                RoktHTTPRequestResult(
                    httpURLResponse: HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil),
                    responseData: nil,
                    responseError: nil,
                    jsonSerialisedResponseData: .success(NSNull())
                )
            )
        }
        return nil
    }

    func downloadFile(
        source urlAddress: String,
        destinationURL: URL,
        options: [RoktDownloadOptions],
        parameters: RoktHTTPParameters?,
        headers: RoktHTTPHeaders?,
        requestTimeout: TimeInterval?,
        completionQueue: DispatchQueue,
        completionHandler: ((RoktDownloadResult) -> Void)?
    ) {}
}
