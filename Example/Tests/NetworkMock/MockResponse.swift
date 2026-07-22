import Foundation
import Quick
import XCTest
import Mocker
@testable import Rokt_Widget

let validInitFilename = "validInit"
let invalidInitFilename = "InvalidInit"

// Derived from the same environment as the live path so the mock URL matches the request.
var txnInitResourceURL: String {
    config.environment.gatewayBaseURL + "/v2/init"
}

var txnEventResourceURL: String {
    config.environment.gatewayBaseURL + "/v2/sessions/events"
}

// The UI test harness drives the SDK through Mocker-intercepted network calls. In the
// `.Mock` environment the SDK swaps in offline transports (init/offers/events) that never
// touch the network, and diagnostics/timings short-circuit via `RoktAPIHelper.isMock()` —
// so none of the registered stubs would fire and nothing would render or be captured.
// Pin a networked environment so every call flows through the stubbed URLs. Both the stub
// URLs and the SDK's request URLs derive from `config.environment`, so they stay in lockstep.
//
// Also clear mocks left over from a previous spec (mocks are global to the process) so each
// spec starts from its own freshly-registered stubs rather than an earlier spec's.
func useNetworkedMockEnvironment() {
    config.environment = .Prod
    Mocker.removeAll()
}

// Reverse of TxnEventMapper's vocabulary so the v2 events stub can surface legacy EventModel names.
let txnEventTypeToLegacyName: [String: String] = [
    "impression": "SignalImpression",
    "viewed": "SignalViewed",
    "signal_initialize": "SignalInitialize",
    "load_start": "SignalLoadStart",
    "load_complete": "SignalLoadComplete",
    "signal_response": "SignalResponse",
    "dismissal": "SignalDismissal",
    "user_interaction": "SignalUserInteraction",
    "capture_attributes": "CaptureAttributes",
    "cart_item_instant_purchase_initiated": "SignalCartItemInstantPurchaseInitiated",
    "cart_item_instant_purchase": "SignalCartItemInstantPurchase",
    "cart_item_instant_purchase_failure": "SignalCartItemInstantPurchaseFailure"
]

// Reshapes a legacy init fixture into the v2 response so existing fixtures still drive init.
func makeTxnInitData(fromLegacy legacyData: Data) -> Data? {
    guard let legacy = try? JSONSerialization.jsonObject(with: legacyData) as? [String: Any] else {
        return nil
    }

    var featureFlags: [String: Any] = [:]
    if let legacyFlags = legacy["featureFlags"] as? [String: Any] {
        for (key, value) in legacyFlags {
            if let flag = value as? [String: Any], let match = flag["match"] as? Bool {
                featureFlags[key] = match
            }
        }
    }
    featureFlags["rokt-tracking-status"] = (legacy["roktTrackingStatus"] as? Bool) ?? true
    if let clientTimeout = legacy["clientTimeoutMilliseconds"] as? Int {
        featureFlags["client-timeout-ms"] = clientTimeout
    }

    let fonts: [[String: Any]] = (legacy["fonts"] as? [[String: Any]] ?? []).compactMap { font in
        guard let name = font["fontName"] as? String, let url = font["fontUrl"] as? String else { return nil }
        return ["font_name": name, "font_url": url]
    }

    let v2Response: [String: Any] = [
        "session_id": "mock-session-00000000-0000-7000-8000-000000000000",
        "session_token": ["token": "mock-session-token", "expires_at": 32_503_680_000_000],
        "feature_flags": featureFlags,
        "fonts": fonts
    ]
    return try? JSONSerialization.data(withJSONObject: v2Response)
}

// Derived from the same environment as the live path so the mock URL matches the request.
var txnOffersResourceURL: String {
    config.environment.gatewayBaseURL + "/v2/sessions/offers"
}

// Reshapes a legacy v1 experience fixture into the v2 offers response so existing
// layout fixtures still drive offers rendering through the v2 path. Structural keys
// are re-homed to snake_case; the DCUI schema strings and copy/images/links maps pass
// through verbatim. The render-side adapter re-buckets response options by is_positive.
func makeOffersData(fromV1Experience legacyData: Data) -> Data? {
    guard let v1 = try? JSONSerialization.jsonObject(with: legacyData) as? [String: Any] else {
        return nil
    }

    func reshapeResponseOption(_ responseOption: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = responseOption["id"]
        out["action"] = responseOption["action"]
        out["instance_guid"] = responseOption["instanceGuid"]
        out["token"] = responseOption["token"]
        out["signal_type"] = responseOption["signalType"]
        out["short_label"] = responseOption["shortLabel"]
        out["long_label"] = responseOption["longLabel"]
        out["short_success_label"] = responseOption["shortSuccessLabel"]
        out["is_positive"] = responseOption["isPositive"]
        out["url"] = responseOption["url"]
        return out
    }

    func reshapeCreative(_ creative: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        out["referral_creative_id"] = creative["referralCreativeId"]
        out["instance_guid"] = creative["instanceGuid"]
        out["token"] = creative["token"]
        out["copy"] = creative["copy"]
        out["images"] = creative["images"]
        out["links"] = creative["links"]
        if let responseOptionsMap = creative["responseOptionsMap"] as? [String: Any] {
            out["response_options_map"] = responseOptionsMap
                .compactMapValues { ($0 as? [String: Any]).map(reshapeResponseOption) }
        }
        return out
    }

    func reshapeSlot(_ slot: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        out["instance_guid"] = slot["instanceGuid"]
        out["token"] = slot["token"]
        if let layoutVariant = slot["layoutVariant"] as? [String: Any] {
            var layoutVariantOut: [String: Any] = [:]
            layoutVariantOut["layout_variant_id"] = layoutVariant["layoutVariantId"]
            layoutVariantOut["module_name"] = layoutVariant["moduleName"]
            layoutVariantOut["layout_variant_schema"] = layoutVariant["layoutVariantSchema"]
            out["layout_variant"] = layoutVariantOut
        }
        if let offer = slot["offer"] as? [String: Any] {
            var offerOut: [String: Any] = [:]
            offerOut["campaign_id"] = offer["campaignId"]
            if let creative = offer["creative"] as? [String: Any] {
                offerOut["creative"] = reshapeCreative(creative)
            }
            out["offer"] = offerOut
        }
        return out
    }

    func reshapePlugin(_ container: [String: Any]) -> [String: Any] {
        guard let plugin = container["plugin"] as? [String: Any] else { return [:] }
        var pluginOut: [String: Any] = [:]
        pluginOut["id"] = plugin["id"]
        pluginOut["name"] = plugin["name"]
        pluginOut["target_element_selector"] = plugin["targetElementSelector"]
        if let config = plugin["config"] as? [String: Any] {
            var configOut: [String: Any] = [:]
            configOut["instance_guid"] = config["instanceGuid"]
            configOut["token"] = config["token"]
            configOut["outer_layout_schema"] = config["outerLayoutSchema"]
            configOut["slots"] = (config["slots"] as? [[String: Any]] ?? []).map(reshapeSlot)
            pluginOut["config"] = configOut
        }
        return ["plugin": pluginOut]
    }

    let placementContext = v1["placementContext"] as? [String: Any]
    let pageInstanceGuid = placementContext?["pageInstanceGuid"] as? String ?? ""

    var pageContext: [String: Any] = ["page_instance_guid": pageInstanceGuid]
    pageContext["page_id"] = (v1["page"] as? [String: Any])?["pageId"]
    pageContext["token"] = placementContext?["token"]

    let response: [String: Any] = [
        "session_id": v1["sessionId"] as? String ?? "mock-session",
        "session_token": [
            "token": v1["token"] as? String ?? "mock-session-token",
            "expires_at": 32_503_680_000_000
        ],
        "page_instance_guid": pageInstanceGuid,
        "page_context": pageContext,
        "plugins": (v1["plugins"] as? [[String: Any]] ?? []).map(reshapePlugin)
    ]

    return try? JSONSerialization.data(withJSONObject: response)
}

// Stubs the v2 offers endpoint from a v1 experience fixture; nil legacyData yields a body-less error.
func registerOffersStub(fromV1ExperienceData legacyData: Data?, statusCode: Int, delay: Int = 0) {
    guard let url = URL(string: txnOffersResourceURL) else { return }
    let body = legacyData.flatMap(makeOffersData(fromV1Experience:)) ?? Data()
    var mock = Mock(url: url, dataType: .json, statusCode: statusCode, data: [.post: body])
    mock.delay = DispatchTimeInterval.seconds(delay)
    mock.register()
}

// Protocol to share stub methods between QuickSpec and XCTestCase
protocol StubMethodsProvider: AnyObject {
    var testBundle: Bundle { get }
}

extension StubMethodsProvider {

    // Stubs the v2 init endpoint; nil legacyData yields a body-less error response.
    func registerTxnInitStub(legacyData: Data?, statusCode: Int) {
        guard let url = URL(string: txnInitResourceURL) else { return }
        let v2Data = legacyData.flatMap(makeTxnInitData(fromLegacy:)) ?? Data()
        // The v2 init endpoint is a GET (see TxnInitClient), so the mock must be
        // registered for .get — a .post mock never matches and the request falls
        // through to the real network.
        Mock(url: url, dataType: .json, statusCode: statusCode, data: [.get: v2Data]).register()
    }

    // Mirrors the legacy events stub for the v2 endpoint, translating the wire shape back into EventModel
    // so the same assertions hold whether events flow through the legacy or txn path.
    func registerTxnEventsStub(onEventReceive: ((EventModel) -> Void)?) {
        guard let url = URL(string: txnEventResourceURL) else { return }
        var mock = Mock(url: url, dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            guard let body = request.httpBodyStream?.readfully(),
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let events = json["events"] as? [[String: Any]] else { return }
            for event in events {
                guard let txnType = event["event_type"] as? String,
                      let legacyType = txnEventTypeToLegacyName[txnType] else { continue }
                let data = event["data"] as? [String: Any]
                onEventReceive?(
                    EventModel(eventType: legacyType,
                               parentGuid: data?["parent_id"] as? String ?? "",
                               pageInstanceGuid: data?["page_instance_guid"] as? String)
                )
            }
        }
        mock.register()
    }

    func stubInit(fileName: String = validInitFilename) {
        useNetworkedMockEnvironment()
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        if fileName == invalidInitFilename {
            registerTxnInitStub(legacyData: nil, statusCode: 500)
        } else {
            let initPath = testBundle.path(forResource: fileName, ofType: "json")!
            let initData = NSData(contentsOfFile: initPath)!
            registerTxnInitStub(legacyData: initData as Data, statusCode: 200)
        }
    }

    func stubInit(_ widgetFileName: String) {
        useNetworkedMockEnvironment()
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let initPath = testBundle.path(forResource: widgetFileName, ofType: "json")!
        let initData = NSData(contentsOfFile: initPath)!
        registerTxnInitStub(legacyData: initData as Data, statusCode: 200)
    }

    func stubExecute(_ widgetFileName: String,
                     delay: Int = 0,
                     isLayout: Bool = false,
                     onSessionReceive: ((String) -> Void)? = nil) {
        let widgetPath = testBundle.path(forResource: widgetFileName, ofType: "json")!
        let widgetData = NSData(contentsOfFile: widgetPath)!

        stubExecute(data: widgetData as Data, delay: delay, isLayout: isLayout, onSessionReceive: onSessionReceive)
    }

    private func stubExecute(data: Data,
                             delay: Int = 0,
                             isLayout: Bool = false,
                             onSessionReceive: ((String) -> Void)?) {
        _ = (isLayout, onSessionReceive)
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        registerOffersStub(fromV1ExperienceData: data, statusCode: 200, delay: delay)

        Mocker.ignore(URL(string: "https://avatars.githubusercontent.com/u/6335212")!)
    }

    func stubExecuteError() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        registerOffersStub(fromV1ExperienceData: nil, statusCode: 500)
    }

    func stubDiagnostics(onDiagnosticsReceive: ((String) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: diagnosticsResourceURL) else { return }
        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let reqestDatas = request.httpBodyStream?.readfully() {
                do {
                    let json = try JSONSerialization.jsonObject(with: reqestDatas, options: []) as? [String: Any]
                    onDiagnosticsReceive?(json?["code"] as? String ?? "")
                } catch {
                }
            }
        }
        mock.register()
    }

    func stubEvents(onEventReceive: ((EventModel) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        registerTxnEventsStub(onEventReceive: onEventReceive)
    }

    func stubTimings(onTimingsRequestReceive: ((MockTimingsRequest) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: timingsResourceURL) else { return }

        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let requestBodyStream = request.httpBodyStream?.readfully(),
               let requestHeaders = request.allHTTPHeaderFields {
                do {
                    let requestBody = try JSONSerialization.jsonObject(with: requestBodyStream, options: []) as! [String: Any]
                    onTimingsRequestReceive?(
                        MockTimingsRequest(eventTime: requestBody[timingsEventTimeKey] as! String,
                                           pageId: requestHeaders[headerPageIdKey],
                                           pageInstanceGuid: requestHeaders[headerPageInstanceGuidKey],
                                           pluginId: requestBody[timingsPluginIdKey] as? String,
                                           pluginName: requestBody[timingsPluginNameKey] as? String,
                                           timings: requestBody[TimingsRequest.timingsMetricsKey] as! [[String: String]])
                    )
                } catch {
                }
            }
        }
        mock.register()
    }

    func stubFontFileUrl(_ fontUrl: String) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let mock = Mock(url: URL(string: fontUrl)!, dataType: .zip, statusCode: 200, data: [.get: Data()])
        mock.register()
    }
}

// Make QuickSpec conform to the protocol
extension QuickSpec: StubMethodsProvider {
    override var testBundle: Bundle {
        return Bundle(for: type(of: self))
    }
}

// Make XCTestCase conform to the protocol for backward compatibility
extension XCTestCase: StubMethodsProvider {
    var testBundle: Bundle {
        return Bundle(for: type(of: self))
    }

    func stubInit(fileName: String = validInitFilename) {
        useNetworkedMockEnvironment()
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        if fileName == invalidInitFilename {
            registerTxnInitStub(legacyData: nil, statusCode: 500)
        } else {
            let initPath = Bundle(for: type(of: self))
                .path(forResource: fileName, ofType: "json")!
            let initData = NSData(contentsOfFile: initPath)!
            registerTxnInitStub(legacyData: initData as Data, statusCode: 200)
        }
    }

    func stubInit(_ widgetFileName: String) {
        useNetworkedMockEnvironment()
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let initPath = Bundle(for: type(of: self))
            .path(forResource: widgetFileName, ofType: "json")!
        let initData = NSData(contentsOfFile: initPath)!
        registerTxnInitStub(legacyData: initData as Data, statusCode: 200)
    }

    func stubExecute(_ widgetFileName: String,
                     delay: Int = 0,
                     isLayout: Bool = false,
                     onSessionReceive: ((String) -> Void)? = nil) {
        let widgetPath = Bundle(for: type(of: self)).path(forResource: widgetFileName, ofType: "json")!
        let widgetData = NSData(contentsOfFile: widgetPath)!

        stubExecute(data: widgetData as Data, delay: delay, isLayout: isLayout, onSessionReceive: onSessionReceive)
    }

    private func stubExecute(data: Data,
                             delay: Int = 0,
                             isLayout: Bool = false,
                             onSessionReceive: ((String) -> Void)?) {
        _ = (isLayout, onSessionReceive)
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        registerOffersStub(fromV1ExperienceData: data, statusCode: 200, delay: delay)

        Mocker.ignore(URL(string: "https://avatars.githubusercontent.com/u/6335212")!)
    }

    func stubExecuteError() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        registerOffersStub(fromV1ExperienceData: nil, statusCode: 500)
    }

    func stubDiagnostics(onDiagnosticsReceive: ((String) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: diagnosticsResourceURL) else { return }
        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let reqestDatas = request.httpBodyStream?.readfully() {
                do {
                    let json = try JSONSerialization.jsonObject(with: reqestDatas, options: []) as? [String: Any]
                    onDiagnosticsReceive?(json?["code"] as? String ?? "")
                } catch {
                }
            }
        }
        mock.register()
    }

    func stubEvents(onEventReceive: ((EventModel) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        registerTxnEventsStub(onEventReceive: onEventReceive)
    }

    func stubTimings(onTimingsRequestReceive: ((MockTimingsRequest) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: timingsResourceURL) else { return }

        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let requestBodyStream = request.httpBodyStream?.readfully(),
               let requestHeaders = request.allHTTPHeaderFields {
                do {
                    let requestBody = try JSONSerialization.jsonObject(with: requestBodyStream, options: []) as! [String: Any]
                    onTimingsRequestReceive?(
                        MockTimingsRequest(eventTime: requestBody[timingsEventTimeKey] as! String,
                                           pageId: requestHeaders[headerPageIdKey],
                                           pageInstanceGuid: requestHeaders[headerPageInstanceGuidKey],
                                           pluginId: requestBody[timingsPluginIdKey] as? String,
                                           pluginName: requestBody[timingsPluginNameKey] as? String,
                                           timings: requestBody[TimingsRequest.timingsMetricsKey] as! [[String: String]])
                    )
                } catch {
                }
            }
        }
        mock.register()
    }

    func stubFontFileUrl(_ fontUrl: String) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let mock = Mock(url: URL(string: fontUrl)!, dataType: .zip, statusCode: 200, data: [.get: Data()])
        mock.register()
    }
}

internal extension InputStream {
    func readfully() -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        open()

        var amount = 0
        repeat {
            amount = read(&buffer, maxLength: buffer.count)
            if amount > 0 {
                result.append(buffer, count: amount)
            }
        } while amount > 0

        close()

        return result
    }
}
