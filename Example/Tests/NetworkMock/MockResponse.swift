import Foundation
import Quick
import XCTest
import Mocker
@testable import Rokt_Widget

let validInitFilename = "validInit"
let invalidInitFilename = "InvalidInit"

// Derived from the same environment as the live path so the mock URL matches the request.
var txnInitResourceURL: String {
    config.environment.gatewayBaseURL + "/v2/sessions/init"
}

var txnEventResourceURL: String {
    config.environment.gatewayBaseURL + "/v2/sessions/events"
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

    func reshapeResponseOption(_ ro: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        out["id"] = ro["id"]
        out["action"] = ro["action"]
        out["instance_guid"] = ro["instanceGuid"]
        out["token"] = ro["token"]
        out["signal_type"] = ro["signalType"]
        out["short_label"] = ro["shortLabel"]
        out["long_label"] = ro["longLabel"]
        out["short_success_label"] = ro["shortSuccessLabel"]
        out["is_positive"] = ro["isPositive"]
        out["url"] = ro["url"]
        return out
    }

    func reshapeCreative(_ cr: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        out["referral_creative_id"] = cr["referralCreativeId"]
        out["instance_guid"] = cr["instanceGuid"]
        out["token"] = cr["token"]
        out["copy"] = cr["copy"]
        out["images"] = cr["images"]
        out["links"] = cr["links"]
        if let rom = cr["responseOptionsMap"] as? [String: Any] {
            out["response_options_map"] = rom.compactMapValues { ($0 as? [String: Any]).map(reshapeResponseOption) }
        }
        return out
    }

    func reshapeSlot(_ s: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        out["instance_guid"] = s["instanceGuid"]
        out["token"] = s["token"]
        if let lv = s["layoutVariant"] as? [String: Any] {
            var lvOut: [String: Any] = [:]
            lvOut["layout_variant_id"] = lv["layoutVariantId"]
            lvOut["module_name"] = lv["moduleName"]
            lvOut["layout_variant_schema"] = lv["layoutVariantSchema"]
            out["layout_variant"] = lvOut
        }
        if let offer = s["offer"] as? [String: Any] {
            var offerOut: [String: Any] = [:]
            offerOut["campaign_id"] = offer["campaignId"]
            if let cr = offer["creative"] as? [String: Any] {
                offerOut["creative"] = reshapeCreative(cr)
            }
            out["offer"] = offerOut
        }
        return out
    }

    func reshapePlugin(_ container: [String: Any]) -> [String: Any] {
        guard let p = container["plugin"] as? [String: Any] else { return [:] }
        var pluginOut: [String: Any] = [:]
        pluginOut["id"] = p["id"]
        pluginOut["name"] = p["name"]
        pluginOut["target_element_selector"] = p["targetElementSelector"]
        if let cfg = p["config"] as? [String: Any] {
            var cfgOut: [String: Any] = [:]
            cfgOut["instance_guid"] = cfg["instanceGuid"]
            cfgOut["token"] = cfg["token"]
            cfgOut["outer_layout_schema"] = cfg["outerLayoutSchema"]
            cfgOut["slots"] = (cfg["slots"] as? [[String: Any]] ?? []).map(reshapeSlot)
            pluginOut["config"] = cfgOut
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

    // Stubs the v2 endpoint alongside the legacy one; nil legacyData yields a body-less error.
    func registerTxnInitStub(legacyData: Data?, statusCode: Int) {
        guard let url = URL(string: txnInitResourceURL) else { return }
        let v2Data = legacyData.flatMap(makeTxnInitData(fromLegacy:)) ?? Data()
        Mock(url: url, dataType: .json, statusCode: statusCode, data: [.post: v2Data]).register()
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
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        if fileName == invalidInitFilename {
            let mock = Mock(url: URL(string: initResourceURL)!, dataType: .json, statusCode: 500, data: [
                .get: Data()
            ])
            mock.register()
            registerTxnInitStub(legacyData: nil, statusCode: 500)
        } else {
            let initPath = testBundle.path(forResource: fileName, ofType: "json")!
            let initData = NSData(contentsOfFile: initPath)!

            let mock = Mock(url: URL(string: initResourceURL)!, dataType: .json, statusCode: 200, data: [
                .get: initData as Data // Data containing the JSON response
            ])
            mock.register()
            registerTxnInitStub(legacyData: initData as Data, statusCode: 200)
        }
    }

    func stubInit(_ widgetFileName: String) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let initPath = testBundle.path(forResource: widgetFileName, ofType: "json")!
        let initData = NSData(contentsOfFile: initPath)!

        let mock = Mock(url: URL(string: initResourceURL)!, dataType: .json, statusCode: 200, data: [
            .get: initData as Data // Data containing the JSON response
        ])
        mock.register()
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
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        var mock = Mock(url: URL(string: experiencesResourceURL)!,
                        dataType: .json,
                        statusCode: 200,
                        data: [.post: data],
                        additionalHeaders: [experienceTypeHeader: isLayout ? layoutsValue : placementsValue])

        mock.onRequest = { request, _ in
            let header = request.allHTTPHeaderFields
            onSessionReceive?(header?["rokt-session-id"] ?? "")
        }
        mock.delay = DispatchTimeInterval.seconds(delay)
        mock.register()

        // The v2 offers path is the active runtime; stub it from the same fixture.
        registerOffersStub(fromV1ExperienceData: data, statusCode: 200, delay: delay)

        Mocker.ignore(URL(string: "https://avatars.githubusercontent.com/u/6335212")!)
    }

    func stubExecuteError() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let mock = Mock(url: URL(string: experiencesResourceURL)!, dataType: .json, statusCode: 500,
                        data: [.get: Data()])

        mock.register()

        // The v2 offers path is the active runtime; fail it the same way.
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

        var mock = Mock(url: URL(string: eventResourceURL)!,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let reqestDatas = request.httpBodyStream?.readfully() {
                do {
                    let jsonArray = try JSONSerialization.jsonObject(with: reqestDatas, options: []) as? [[String: Any]]
                    for json in jsonArray! {
                        onEventReceive?(
                            EventModel(eventType: json["eventType"] as! String,
                                       parentGuid: json["parentGuid"] as! String,
                                       pageInstanceGuid: json["pageInstanceGuid"] as? String,
                                       metadata: json["metadata"] as? [[String: String]],
                                       attributes: json["attributes"] as? [[String: String]])
                        )
                    }
                } catch {
                }
            }
        }
        mock.register()
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
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        if fileName == invalidInitFilename {
            let mock = Mock(url: URL(string: initResourceURL)!, dataType: .json, statusCode: 500, data: [
                .get: Data()
            ])
            mock.register()
            registerTxnInitStub(legacyData: nil, statusCode: 500)
        } else {
            let initPath = Bundle(for: type(of: self))
                .path(forResource: fileName, ofType: "json")!
            let initData = NSData(contentsOfFile: initPath)!

            let mock = Mock(url: URL(string: initResourceURL)!, dataType: .json, statusCode: 200, data: [
                .get: initData as Data // Data containing the JSON response
            ])
            mock.register()
            registerTxnInitStub(legacyData: initData as Data, statusCode: 200)
        }
    }

    func stubInit(_ widgetFileName: String) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let initPath = Bundle(for: type(of: self))
            .path(forResource: widgetFileName, ofType: "json")!
        let initData = NSData(contentsOfFile: initPath)!

        let mock = Mock(url: URL(string: initResourceURL)!, dataType: .json, statusCode: 200, data: [
            .get: initData as Data // Data containing the JSON response
        ])
        mock.register()
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
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        var mock = Mock(url: URL(string: experiencesResourceURL)!,
                        dataType: .json,
                        statusCode: 200,
                        data: [.post: data],
                        additionalHeaders: [experienceTypeHeader: isLayout ? layoutsValue : placementsValue])

        mock.onRequest = { request, _ in
            let header = request.allHTTPHeaderFields
            onSessionReceive?(header?["rokt-session-id"] ?? "")
        }
        mock.delay = DispatchTimeInterval.seconds(delay)
        mock.register()

        // The v2 offers path is the active runtime; stub it from the same fixture.
        registerOffersStub(fromV1ExperienceData: data, statusCode: 200, delay: delay)

        Mocker.ignore(URL(string: "https://avatars.githubusercontent.com/u/6335212")!)
    }

    func stubExecuteError() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let mock = Mock(url: URL(string: experiencesResourceURL)!, dataType: .json, statusCode: 500,
                        data: [.get: Data()])

        mock.register()

        // The v2 offers path is the active runtime; fail it the same way.
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

        var mock = Mock(url: URL(string: eventResourceURL)!,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let reqestDatas = request.httpBodyStream?.readfully() {
                do {
                    let jsonArray = try JSONSerialization.jsonObject(with: reqestDatas, options: []) as? [[String: Any]]
                    for json in jsonArray! {
                        onEventReceive?(
                            EventModel(eventType: json["eventType"] as! String,
                                       parentGuid: json["parentGuid"] as! String,
                                       pageInstanceGuid: json["pageInstanceGuid"] as? String,
                                       metadata: json["metadata"] as? [[String: String]],
                                       attributes: json["attributes"] as? [[String: String]])
                        )
                    }
                } catch {
                }
            }
        }
        mock.register()
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
