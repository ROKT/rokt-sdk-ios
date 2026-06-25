// periphery:ignore:all - offers network client

import Foundation

internal struct OffersClient {
    let baseURL: URL
    let accountId: String
    let authToken: String
    let sdkVersion: String
    let pageInstanceGuid: String
    let httpClient: HTTPClientAdapter

    init(
        baseURL: URL,
        accountId: String,
        authToken: String,
        sdkVersion: String,
        pageInstanceGuid: String,
        httpClient: HTTPClientAdapter = RoktHTTPClient()
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.authToken = authToken
        self.sdkVersion = sdkVersion
        self.pageInstanceGuid = pageInstanceGuid
        self.httpClient = httpClient
    }

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
            privacyControl: input.privacyControl
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw OffersClientError.bodyEncodingFailed
        }

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Authorization": authToken,
            "x-request-id": input.requestId,
            "rokt-page-instance-guid": pageInstanceGuid,
            // The app bundle id scopes server-side page detection for mobile.
            "rokt-package-name": Bundle.main.bundleIdentifier ?? "",
            "Content-Type": "application/json"
        ]

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
    let privacyControl: SelectPrivacyControl?

    init(
        requestId: String,
        pageIdentifier: String,
        attributes: [String: String],
        privacyControl: SelectPrivacyControl? = nil
    ) {
        self.requestId = requestId
        self.pageIdentifier = pageIdentifier
        self.attributes = attributes
        self.privacyControl = privacyControl
    }
}
