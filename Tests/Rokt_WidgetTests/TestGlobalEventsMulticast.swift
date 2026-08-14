import XCTest
@testable import Rokt_Widget

final class TestGlobalEventsMulticast: XCTestCase {

    private var impl: RoktInternalImplementation!
    private var stub: StubGlobalEventsInitHTTPClient!

    override func setUp() {
        super.setUp()
        impl = RoktInternalImplementation()
        stub = StubGlobalEventsInitHTTPClient()
        impl.makeTxnInitServiceOverride = { [stub] tagId in
            TxnInitService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "5.3.2",
                layoutSchemaVersion: "1.0",
                httpClient: stub!,
                baseBackoff: 0,
                sleep: { _ in }
            )
        }
    }

    override func tearDown() {
        impl = nil
        stub = nil
        super.tearDown()
    }

    private func stubInitSuccess() {
        stub.result = .success(data: Data(
            """
            {
              "session_id": "sess-1",
              "session_token": { "token": "jwt", "expires_at": 32503680000000 },
              "feature_flags": {},
              "fonts": []
            }
            """.utf8
        ))
    }

    func test_globalEvents_bothKitAndClientReceiveInitComplete() {
        stubInitSuccess()
        var kitEvents: [RoktEvent] = []
        var clientEvents: [RoktEvent] = []

        impl.mapEvents(isGlobal: true, onEvent: { kitEvents.append($0) })
        impl.mapEvents(isGlobal: true, onEvent: { clientEvents.append($0) })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { !kitEvents.isEmpty && !clientEvents.isEmpty }
        XCTAssertEqual(kitEvents.count, 1)
        XCTAssertEqual(clientEvents.count, 1)
        XCTAssertTrue((kitEvents.first as? RoktEvent.InitComplete)?.success == true)
        XCTAssertTrue((clientEvents.first as? RoktEvent.InitComplete)?.success == true)
    }

    // Subscriptions accumulate: a caller that subscribes N times is called back N times per event,
    // where previously every subscription but the last was silently dropped.
    func test_globalEvents_subscriptionsAccumulateSoEachOneIsCalledBack() {
        stubInitSuccess()
        let subscriptionCount = 3
        var received: [RoktEvent] = []

        for _ in 0..<subscriptionCount {
            impl.mapEvents(isGlobal: true, onEvent: { received.append($0) })
        }

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { received.count == subscriptionCount }
        XCTAssertEqual(received.count, subscriptionCount)
        XCTAssertTrue(received.allSatisfy { ($0 as? RoktEvent.InitComplete)?.success == true })
    }

    func test_globalEvents_bothSubscribersReceiveInitFailure() {
        stub.result = .status(400)
        var kitEvents: [RoktEvent] = []
        var clientEvents: [RoktEvent] = []

        impl.mapEvents(isGlobal: true, onEvent: { kitEvents.append($0) })
        impl.mapEvents(isGlobal: true, onEvent: { clientEvents.append($0) })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { !kitEvents.isEmpty && !clientEvents.isEmpty }
        XCTAssertTrue((kitEvents.first as? RoktEvent.InitComplete)?.success == false)
        XCTAssertTrue((clientEvents.first as? RoktEvent.InitComplete)?.success == false)
    }

    func test_globalEvents_nilOnEventRemovesAllSubscribers() {
        stubInitSuccess()
        var received: [RoktEvent] = []

        impl.mapEvents(isGlobal: true, onEvent: { received.append($0) })
        impl.mapEvents(isGlobal: true, onEvent: { received.append($0) })
        impl.mapEvents(isGlobal: true, onEvent: nil)

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { self.impl.isInitialized }
        XCTAssertTrue(received.isEmpty)
    }

    func test_globalEvents_perViewListenersAreUnaffected() {
        stubInitSuccess()
        var globalEvents: [RoktEvent] = []
        var viewEvents: [RoktEvent] = []

        impl.mapEvents(isGlobal: true, onEvent: { globalEvents.append($0) })
        impl.mapEvents(viewName: "checkout", onEvent: { viewEvents.append($0) })

        impl.initWith(roktTagId: "tag-1", mParticleKitDetails: nil)

        waitUntil { !globalEvents.isEmpty }
        XCTAssertEqual(globalEvents.count, 1)
        XCTAssertTrue(viewEvents.isEmpty)
    }
}

private final class StubGlobalEventsInitHTTPClient: HTTPClientAdapter {
    enum Result {
        case success(data: Data)
        case status(Int)
    }

    var result: Result = .status(500)

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
        let httpResult: RoktHTTPRequestResult
        switch result {
        case .success(let data):
            httpResult = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil),
                responseData: data,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        case .status(let code):
            httpResult = RoktHTTPRequestResult(
                httpURLResponse: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil),
                responseData: nil,
                responseError: nil,
                jsonSerialisedResponseData: .success(NSNull())
            )
        }
        completionQueue.async { completionHandler?(httpResult) }
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
