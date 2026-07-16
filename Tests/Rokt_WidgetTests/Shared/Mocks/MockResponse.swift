import XCTest
import Mocker
@testable import Rokt_Widget

private var txnEventResourceURL: String {
    config.environment.gatewayBaseURL + "/v2/sessions/events"
}

extension XCTestCase {
    func stubEvents(onEventReceive: ((EventModel) -> Void)? = nil) {
        let configuration = URLSessionConfiguration.default
            configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        NetworkingHelper.shared.httpClient = RoktHTTPClient(sessionConfiguration: configuration)

        guard let url = URL(string: txnEventResourceURL) else { return }
        var mock = Mock(url: url, dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            guard let body = request.httpBodyStream?.readfully(),
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let events = json["events"] as? [[String: Any]] else { return }
            for event in events {
                let data = event["data"] as? [String: Any]
                onEventReceive?(
                    EventModel(eventType: event["event_type"] as? String ?? "",
                               parentGuid: data?["parent_id"] as? String ?? "",
                               pageInstanceGuid: data?["page_instance_guid"] as? String,
                               jwtToken: "")
                )
            }
        }
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
                    onDiagnosticsReceive?(json![RoktAPIHelper.errorCodeDiagnosticKey] as! String)
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

        guard let originalURL = URL(string: diagnosticsResourceURL) else { return }
        var mock = Mock(url: originalURL,
                        dataType: .json, statusCode: 200, data: [.post: Data()])

        mock.onRequest = { request, _ in
            if let reqestDatas = request.httpBodyStream?.readfully() {
                do {
                    let json = try JSONSerialization.jsonObject(with: reqestDatas, options: []) as? [String: Any]
                    let diagnostics = StubbedDiagnosticsModel(code: json![RoktAPIHelper.errorCodeDiagnosticKey] as! String,
                                                              stackTrace: json![RoktAPIHelper
                                                              .errorStackTraceDiagnosticKey] as! String,
                                                              severity: json![RoktAPIHelper
                                                              .errorSeverityDiagnosticKey] as! String)
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

    struct StubbedDiagnosticsModel: Equatable {
        let code: String
        let stackTrace: String
        let severity: String
    }
}
