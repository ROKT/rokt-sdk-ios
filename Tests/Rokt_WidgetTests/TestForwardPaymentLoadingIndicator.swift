import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper
import Mocker

/// Verifies that `handleForwardPayment` emits `ShowLoadingIndicator` before the
/// `/v1/cart/purchase` round-trip and `HideLoadingIndicator` as soon as the
/// network layer returns (success or failure). Without these emissions the
/// partner app can't show its own spinner while we wait on the backend.
final class TestForwardPaymentLoadingIndicator: XCTestCase {

    private let purchaseURL = URL(string: "https://apps.rokt.com/rokt-mobile/v1/cart/purchase")!
    private let executeId = "test-execute-id"

    private var originalTagId: String?

    override func setUp() {
        super.setUp()
        Rokt.setEnvironment(environment: .Prod)
        originalTagId = Rokt.shared.roktImplementation.roktTagId
        Rokt.shared.roktImplementation.roktTagId = "test-tag-id"
    }

    override func tearDown() {
        Rokt.shared.roktImplementation.roktTagId = originalTagId
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeEvent(unitPrice: Decimal? = 9.99,
                           totalPrice: Decimal? = 9.99) -> RoktUXEvent.CartItemForwardPayment {
        RoktUXEvent.CartItemForwardPayment(
            layoutId: "layout-1",
            name: "Test item",
            cartItemId: "cart-1",
            catalogItemId: "catalog-1",
            currency: "USD",
            description: "desc",
            linkedProductId: nil,
            providerData: "provider",
            quantity: 1,
            totalPrice: totalPrice,
            unitPrice: unitPrice,
            transactionData: nil
        )
    }

    /// Seeds a fresh `RoktInternalImplementation` with a state bag whose
    /// `onRoktEvent` appends every emitted event into the supplied array.
    private func makeImplementation(capturing events: EventCapture) -> RoktInternalImplementation {
        let impl = RoktInternalImplementation()
        let bag = ExecuteStateBag(
            uxHelper: nil,
            onRoktEvent: { event in events.append(event) }
        )
        impl.stateManager.addState(id: executeId, state: bag)
        return impl
    }

    private func registerPurchaseMock(statusCode: Int, body: String) {
        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: statusCode,
            data: [.post: Data(body.utf8)]
        )
        mock.register()
    }

    private func installMockingHTTPClient() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self]
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)
    }

    // MARK: - Tests

    func test_showLoadingIndicator_emittedBeforeForwardPaymentNetworkCall() {
        let events = EventCapture()
        let impl = makeImplementation(capturing: events)

        let requestObserved = expectation(description: "forward-payment request received")
        var mock = Mock(
            url: purchaseURL,
            dataType: .json,
            statusCode: 200,
            data: [.post: Data("{\"success\":true}".utf8)]
        )
        mock.onRequest = { _, _ in
            // The network request is fired after handleForwardPayment emits
            // ShowLoadingIndicator — assert the order while the request is in flight.
            XCTAssertEqual(events.types, [.show], "ShowLoadingIndicator must be emitted before the /cart/purchase request")
            requestObserved.fulfill()
        }
        mock.register()

        installMockingHTTPClient()

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [requestObserved], timeout: 2.0)
    }

    func test_hideLoadingIndicator_emittedOnSuccessResponse() {
        let events = EventCapture()
        let impl = makeImplementation(capturing: events)

        registerPurchaseMock(statusCode: 200, body: "{\"success\":true}")
        installMockingHTTPClient()

        let hideEmitted = events.expectation(for: .hide, description: "HideLoadingIndicator on success")

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [hideEmitted], timeout: 2.0)
        XCTAssertEqual(events.types, [.show, .hide])
    }

    func test_hideLoadingIndicator_emittedOnBusinessFailureResponse() {
        let events = EventCapture()
        let impl = makeImplementation(capturing: events)

        registerPurchaseMock(statusCode: 200, body: "{\"success\":false,\"reason\":\"declined\"}")
        installMockingHTTPClient()

        let hideEmitted = events.expectation(for: .hide, description: "HideLoadingIndicator on business failure")

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [hideEmitted], timeout: 2.0)
        XCTAssertEqual(events.types, [.show, .hide])
    }

    func test_hideLoadingIndicator_emittedOnNetworkFailure() {
        let events = EventCapture()
        let impl = makeImplementation(capturing: events)

        registerPurchaseMock(statusCode: 500, body: "{}")
        installMockingHTTPClient()

        let hideEmitted = events.expectation(for: .hide, description: "HideLoadingIndicator on network failure")

        impl.handleForwardPayment(executeId: executeId, event: makeEvent())

        wait(for: [hideEmitted], timeout: 5.0)
        XCTAssertEqual(events.types, [.show, .hide])
    }

    func test_noLoadingIndicatorEmitted_whenPricesAreMissing() {
        let events = EventCapture()
        let impl = makeImplementation(capturing: events)

        // Missing price => handleForwardPayment early-returns without hitting the network,
        // so neither Show nor Hide should be emitted. The partner never saw a spinner request,
        // so there's nothing to dismiss.
        impl.handleForwardPayment(
            executeId: executeId,
            event: makeEvent(unitPrice: nil, totalPrice: nil)
        )

        // Give any accidental async emission a brief window to fire.
        let noAsyncEmission = expectation(description: "no emissions after early return")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { noAsyncEmission.fulfill() }
        wait(for: [noAsyncEmission], timeout: 1.0)

        XCTAssertTrue(
            events.types.isEmpty,
            "Expected no loading-indicator events on the missing-price early-return path, got: \(events.types)"
        )
    }
}

// MARK: - Capture helper

/// Thread-safe collector for `RoktEvent`s emitted by the state bag under test.
/// Also provides an XCTestExpectation that fulfills the first time a given
/// indicator type is observed — so callers can wait on `Hide` after async work
/// without sleeping.
private final class EventCapture {
    enum IndicatorType { case show, hide, other }

    private let queue = DispatchQueue(label: "EventCapture")
    private var _events: [RoktEvent] = []
    private var waiters: [(IndicatorType, XCTestExpectation)] = []

    func append(_ event: RoktEvent) {
        queue.sync {
            _events.append(event)
            let type = Self.classify(event)
            waiters.removeAll { waiter in
                if waiter.0 == type {
                    waiter.1.fulfill()
                    return true
                }
                return false
            }
        }
    }

    var types: [IndicatorType] {
        queue.sync { _events.map(Self.classify) }
    }

    func expectation(for type: IndicatorType, description: String) -> XCTestExpectation {
        let exp = XCTestExpectation(description: description)
        queue.sync {
            if _events.contains(where: { Self.classify($0) == type }) {
                exp.fulfill()
            } else {
                waiters.append((type, exp))
            }
        }
        return exp
    }

    private static func classify(_ event: RoktEvent) -> IndicatorType {
        if event is RoktEvent.ShowLoadingIndicator { return .show }
        if event is RoktEvent.HideLoadingIndicator { return .hide }
        return .other
    }
}
