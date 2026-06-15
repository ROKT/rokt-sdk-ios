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

        Mocker.ignore(URL(string: "https://avatars.githubusercontent.com/u/6335212")!)
    }

    func stubExecuteError() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let mock = Mock(url: URL(string: experiencesResourceURL)!, dataType: .json, statusCode: 500,
                        data: [.get: Data()])

        mock.register()
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

        Mocker.ignore(URL(string: "https://avatars.githubusercontent.com/u/6335212")!)
    }

    func stubExecuteError() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let mock = Mock(url: URL(string: experiencesResourceURL)!, dataType: .json, statusCode: 500,
                        data: [.get: Data()])

        mock.register()
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
