// periphery:ignore:all - offers network client

import Foundation

internal struct OffersClient {
    let baseURL: URL
    let accountId: String
    let authToken: String?
    let sdkVersion: String
    let layoutSchemaVersion: String
    let pageInstanceGuid: String
    var deviceHeaders: [String: String] = [:]
    var httpClient: HTTPClientAdapter = RoktHTTPClient()

    func fetchOffers(input: OffersInput) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("offers")

        // Session identity is the JWT `sub` claim in the Authorization header —
        // never the body. `customer` and `page.url` are omitted to mirror the
        // Android offers contract.
        let requestBody = SelectRequest(
            page: SelectPage(pageIdentifier: input.pageIdentifier),
            channel: SelectChannel(sdkVersion: sdkVersion),
            attributes: input.attributes,
            privacyControl: input.privacyControl,
            privacy: input.privacy,
            events: input.events
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw OffersClientError.bodyEncodingFailed
        }

        var headers = TxnRequestHeaders.common(accountId: accountId, authToken: authToken)
        headers["x-request-id"] = input.requestId
        headers["rokt-page-instance-guid"] = pageInstanceGuid
        // Advertise the DCUI layout schema version this client can render, matching the v2 init
        // (TxnInitClient.swift) and v1 (RoktNetworkAPI.swift) requests. Without it the gateway
        // serves a legacy layout schema the pinned DcuiSchema decoder cannot parse, so the
        // placement fails to render (see the layout_schema_version negotiation contract).
        headers["rokt-layout-schema-version"] = layoutSchemaVersion
        // Device headers (os, model, locale, app version) and the load-bearing
        // rokt-package-name ride in via NetworkingHelper.txnDeviceHeaders — the
        // gateway's mobile page detection and targeting key off them.
        for (key, value) in deviceHeaders {
            headers[key] = value
        }

        return try await withCheckedThrowingContinuation { continuation in
            httpClient.startRequestWith(
                urlAddress: url.absoluteString,
                method: .post,
                parameters: bodyParameters,
                parameterArray: nil,
                headers: headers,
                onRequestStart: nil,
                requestTimeout: nil,
                completionQueue: .main,
                completionHandler: { result in
                    if let error = result.responseError {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (result.responseData, result.httpURLResponse))
                    }
                }
            )
        }
    }
}

internal enum OffersClientError: Error {
    case bodyEncodingFailed
}

internal struct OffersInput {
    let requestId: String
    let pageIdentifier: String
    let attributes: [String: String]
    var privacyControl: SelectPrivacyControl?
    var privacy: SelectPrivacy?
    var events: [SelectEvent]?
}
