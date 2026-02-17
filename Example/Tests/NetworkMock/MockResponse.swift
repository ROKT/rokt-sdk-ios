import Foundation
import Quick
import XCTest
import Mocker
@testable import Rokt_Widget

let kValidInitFilename = "validInit"
let kInvalidInitFilename = "InvalidInit"

// Protocol to share stub methods between QuickSpec and XCTestCase
protocol StubMethodsProvider: AnyObject {
    var testBundle: Bundle { get }
}

extension StubMethodsProvider {
    
    func stubInit(fileName: String = kValidInitFilename) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        if fileName == kInvalidInitFilename {
            let mock = Mock(url: URL(string: kInitResourceUrl)!, dataType: .json, statusCode: 500, data: [
                .get: Data()
            ])
            mock.register()
        } else {
            let initPath = testBundle.path(forResource: fileName, ofType: "json")!
            let initData = NSData(contentsOfFile: initPath)!

            let mock = Mock(url: URL(string: kInitResourceUrl)!, dataType: .json, statusCode: 200, data: [
                .get: initData as Data // Data containing the JSON response
            ])
            mock.register()
        }
    }

    func stubInit(_ widgetFileName: String) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let initPath = testBundle.path(forResource: widgetFileName, ofType: "json")!
        let initData = NSData(contentsOfFile: initPath)!

        let mock = Mock(url: URL(string: kInitResourceUrl)!, dataType: .json, statusCode: 200, data: [
            .get: initData as Data // Data containing the JSON response
        ])
        mock.register()
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

        var mock = Mock(url: URL(string: kExperiencesResourceURL)!,
                        dataType: .json,
                        statusCode: 200,
                        data: [.post: data],
                        additionalHeaders: [kExperienceType: isLayout ? kLayoutsValue : kPlacementsValue])

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

        let mock = Mock(url: URL(string: kExperiencesResourceURL)!, dataType: .json, statusCode: 500,
                        data: [.get: Data()])

        mock.register()
    }

    func stubDiagnostics(onDiagnosticsReceive: ((String) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: kDiagnosticsResourceUrl) else { return }
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

        var mock = Mock(url: URL(string: kEventResourceUrl)!,
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

        guard let originalURL = URL(string: kTimingsResourceUrl) else { return }

        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let requestBodyStream = request.httpBodyStream?.readfully(),
               let requestHeaders = request.allHTTPHeaderFields {
                do {
                    let requestBody = try JSONSerialization.jsonObject(with: requestBodyStream, options: []) as! [String: Any]
                    onTimingsRequestReceive?(
                        MockTimingsRequest(eventTime: requestBody[BE_TIMINGS_EVENT_TIME_KEY] as! String,
                                           pageId: requestHeaders[BE_HEADER_PAGE_ID_KEY],
                                           pageInstanceGuid: requestHeaders[BE_HEADER_PAGE_INSTANCE_GUID_KEY],
                                           pluginId: requestBody[BE_TIMINGS_PLUGIN_ID_KEY] as? String,
                                           pluginName: requestBody[BE_TIMINGS_PLUGIN_NAME_KEY] as? String,
                                           timings: requestBody[BE_TIMINGS_TIMING_METRICS_KEY] as! [[String: String]])
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

    func stubInit(fileName: String = kValidInitFilename) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        if fileName == kInvalidInitFilename {
            let mock = Mock(url: URL(string: kInitResourceUrl)!, dataType: .json, statusCode: 500, data: [
                .get: Data()
            ])
            mock.register()
        } else {
            let initPath = Bundle(for: type(of: self))
                .path(forResource: fileName, ofType: "json")!
            let initData = NSData(contentsOfFile: initPath)!

            let mock = Mock(url: URL(string: kInitResourceUrl)!, dataType: .json, statusCode: 200, data: [
                .get: initData as Data // Data containing the JSON response
            ])
            mock.register()
        }
    }

    func stubInit(_ widgetFileName: String) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        let initPath = Bundle(for: type(of: self))
            .path(forResource: widgetFileName, ofType: "json")!
        let initData = NSData(contentsOfFile: initPath)!

        let mock = Mock(url: URL(string: kInitResourceUrl)!, dataType: .json, statusCode: 200, data: [
            .get: initData as Data // Data containing the JSON response
        ])
        mock.register()
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

        var mock = Mock(url: URL(string: kExperiencesResourceURL)!,
                        dataType: .json,
                        statusCode: 200,
                        data: [.post: data],
                        additionalHeaders: [kExperienceType: isLayout ? kLayoutsValue : kPlacementsValue])

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

        let mock = Mock(url: URL(string: kExperiencesResourceURL)!, dataType: .json, statusCode: 500,
                        data: [.get: Data()])

        mock.register()
    }

    func stubDiagnostics(onDiagnosticsReceive: ((String) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: kDiagnosticsResourceUrl) else { return }
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

        var mock = Mock(url: URL(string: kEventResourceUrl)!,
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

        guard let originalURL = URL(string: kTimingsResourceUrl) else { return }

        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let requestBodyStream = request.httpBodyStream?.readfully(),
               let requestHeaders = request.allHTTPHeaderFields {
                do {
                    let requestBody = try JSONSerialization.jsonObject(with: requestBodyStream, options: []) as! [String: Any]
                    onTimingsRequestReceive?(
                        MockTimingsRequest(eventTime: requestBody[BE_TIMINGS_EVENT_TIME_KEY] as! String,
                                           pageId: requestHeaders[BE_HEADER_PAGE_ID_KEY],
                                           pageInstanceGuid: requestHeaders[BE_HEADER_PAGE_INSTANCE_GUID_KEY],
                                           pluginId: requestBody[BE_TIMINGS_PLUGIN_ID_KEY] as? String,
                                           pluginName: requestBody[BE_TIMINGS_PLUGIN_NAME_KEY] as? String,
                                           timings: requestBody[BE_TIMINGS_TIMING_METRICS_KEY] as! [[String: String]])
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
