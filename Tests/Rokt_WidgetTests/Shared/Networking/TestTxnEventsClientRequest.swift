import XCTest
@testable import Rokt_Widget

/// Drives `TxnEventsClient` through a real `RoktHTTPClient` whose transport is the URL protocol stub and pins the
/// request the transport is given. The events path sends through `startRequestWith` and takes no hand-off, so this is
/// the control for the offers path: the URL, the method, the header set and the body of a request built and sent in
/// one call.
final class TestTxnEventsClientRequest: XCTestCase {
    /// What the transport saw of one request, read as the request was handed to it. The body stream is read there,
    /// once, because the session owns it afterwards; header names are lowercased, since HTTP compares them that way.
    private struct SentRequest {
        let url: URL?
        let method: String?
        let headers: [String: String]?
        let body: NSDictionary?

        init(_ request: URLRequest) {
            url = request.url
            method = request.httpMethod
            headers = request.allHTTPHeaderFields.map { fields in
                Dictionary(uniqueKeysWithValues: fields.map { ($0.key.lowercased(), $0.value) })
            }
            body = request.bodyStreamAsJSON() as? NSDictionary
        }
    }

    override func tearDown() {
        // The URL protocol stub's observer and canned response are static: a test that installed them leaves none
        // behind for the next.
        RoktHTTPUrlProtocolStub.stopInterceptingRequests()
        super.tearDown()
    }

    func test_recordEvents_sendsOneRequestWithTheExpectedURLHeadersAndBody() async throws {
        RoktHTTPUrlProtocolStub.stub(
            data: Data(#"{ "event_ids": ["event-1"] }"#.utf8),
            response: anyHTTPURLResponse(),
            error: nil
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoktHTTPUrlProtocolStub.self]
        let client = TxnEventsClient(
            baseURL: URL(string: Environment.Prod.gatewayBaseURL)!,
            accountId: "account-1",
            sdkVersion: "1.0.0",
            deviceHeaders: ["rokt-os-type": "iOS"],
            httpClient: RoktHTTPClient(sessionConfiguration: configuration)
        )
        let event = TxnEvent(
            eventType: "impression",
            instanceId: "instance-1",
            timestamp: 1_700_000_000_000,
            data: ["k": "v"]
        )

        let lock = NSLock()
        var sent: [SentRequest] = []
        RoktHTTPUrlProtocolStub.observeRequests { request in
            lock.lock()
            defer { lock.unlock() }
            sent.append(SentRequest(request))
        }

        let (_, response) = try await client.recordEvents(events: [event], authToken: "Bearer token-1")

        XCTAssertEqual(response?.statusCode, 200)
        lock.lock()
        defer { lock.unlock() }
        XCTAssertEqual(sent.count, 1, "one call sends one request")
        let request = try XCTUnwrap(sent.first)
        XCTAssertEqual(request.url, URL(string: "https://apps.rokt.com/v2/sessions/events"))
        XCTAssertEqual(request.method, "POST")
        // No Accept: the body encoder adds none when Content-Type is set.
        XCTAssertEqual(request.headers, [
            "rokt-account-id": "account-1",
            "content-type": "application/json",
            "authorization": "Bearer token-1",
            "rokt-os-type": "iOS"
        ], "the header set is exactly the events request's")
        let expectedBody = try JSONSerialization.jsonObject(with: JSONEncoder().encode(TxnEventsRequest(
            channel: TxnEventsChannel(type: "msdk", sdkVersion: "1.0.0"),
            events: [event]
        ))) as? NSDictionary
        XCTAssertNotNil(expectedBody)
        XCTAssertEqual(request.body, expectedBody, "the body is the encoded events request")
        XCTAssertEqual(request.body?["single_session"] as? Bool, true)
        XCTAssertEqual((request.body?["events"] as? [[String: Any]])?.count, 1)
    }
}
