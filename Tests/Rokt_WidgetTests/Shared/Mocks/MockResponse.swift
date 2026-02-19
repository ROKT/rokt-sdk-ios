import XCTest
import Mocker
@testable import Rokt_Widget

extension XCTestCase {
    func stubEvents(onEventReceive: ((EventModel) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
            configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let originalURL = URL(string: kEventResourceUrl) else { return }

        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let reqestDatas = request.httpBodyStream?.readfully() {
                do {
                    let jsonArray = try JSONSerialization.jsonObject(with: reqestDatas, options: []) as? [[String: Any]]
                    for json in jsonArray! {
                        onEventReceive?(
                            EventModel(eventType: json[BE_EVENT_TYPE_KEY] as! String,
                                       parentGuid: json[BE_PARENT_GUID_KEY] as! String,
                                       pageInstanceGuid: json[BE_PAGE_INSTANCE_GUID_KEY] as? String,
                                       metadata: json[BE_METADATA_KEY] as? [[String: String]],
                                       attributes: json[BE_ATTRIBUTES_KEY] as? [[String: String]],
                                       jwtToken: json["token"] as! String)
                        )
                    }
                } catch {
                }
            }
        }
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
                    onDiagnosticsReceive?(json![BE_ERROR_CODE_KEY] as! String)
                } catch {
                }
            }
        }
        mock.register()
    }

    func stubDiagnostics(onDiagnosticsModelReceive: ((StubbedDiagnosticsModel) -> Void)? = nil) {
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
                    let diagnostics = StubbedDiagnosticsModel(code: json![BE_ERROR_CODE_KEY] as! String,
                                                              stackTrace: json![BE_ERROR_STACK_TRACE_KEY] as! String,
                                                              severity: json![BE_ERROR_SEVERITY_KEY] as! String)
                    onDiagnosticsModelReceive?(diagnostics)
                } catch { }
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

    struct StubbedDiagnosticsModel: Equatable {
        let code: String
        let stackTrace: String
        let severity: String
    }
}
