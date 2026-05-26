// periphery:ignore:all - referenced from Tests/ContractTests/V2OffersClientPactSpec.swift

import Foundation

internal struct V2OffersClient {
    let baseURL: URL
    let accountId: String
    let authToken: String
    let sessionId: String
    let mpSessionId: String
    let mpid: String
    let sdkVersion: String
    let pageInstanceGuid: String
    let httpClient: HTTPClientAdapter

    init(
        baseURL: URL,
        accountId: String,
        authToken: String,
        sessionId: String,
        mpSessionId: String,
        mpid: String,
        sdkVersion: String,
        pageInstanceGuid: String,
        httpClient: HTTPClientAdapter = RoktHTTPClient()
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.authToken = authToken
        self.sessionId = sessionId
        self.mpSessionId = mpSessionId
        self.mpid = mpid
        self.sdkVersion = sdkVersion
        self.pageInstanceGuid = pageInstanceGuid
        self.httpClient = httpClient
    }

    func fetchOffers(input: V2OffersInput) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("offers")

        let requestBody = V2OffersRequest(
            sessionId: sessionId,
            mpSessionId: mpSessionId,
            mpid: mpid,
            page: V2OffersPage(pageIdentifier: input.pageIdentifier, url: input.pageURL),
            privacy: V2OffersPrivacy(doNotTrack: false, gpcEnabled: false, doNotShareOrSell: false),
            channel: V2OffersChannel(type: "msdk", sdkVersion: sdkVersion),
            customer: V2OffersCustomer(email: input.customerEmail),
            attributes: input.attributes
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw V2OffersClientError.bodyEncodingFailed
        }

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Authorization": authToken,
            "rokt-platform-type": "iOS",
            "rokt-integration-type": "msdk-ios",
            "x-request-id": input.requestId,
            "rokt-page-instance-guid": pageInstanceGuid,
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

internal enum V2OffersClientError: Error {
    case bodyEncodingFailed
}

internal struct V2OffersInput {
    let requestId: String
    let pageIdentifier: String
    let pageURL: String
    let customerEmail: String
    let attributes: [String: String]
}

internal struct V2OffersRequest: Encodable {
    let sessionId: String
    let mpSessionId: String
    let mpid: String
    let page: V2OffersPage
    let privacy: V2OffersPrivacy
    let channel: V2OffersChannel
    let customer: V2OffersCustomer
    let attributes: [String: String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case mpSessionId = "mp_session_id"
        case mpid
        case page
        case privacy
        case channel
        case customer
        case attributes
    }
}

internal struct V2OffersPage: Encodable {
    let pageIdentifier: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case pageIdentifier = "page_identifier"
        case url
    }
}

internal struct V2OffersPrivacy: Encodable {
    let doNotTrack: Bool
    let gpcEnabled: Bool
    let doNotShareOrSell: Bool

    enum CodingKeys: String, CodingKey {
        case doNotTrack = "do_not_track"
        case gpcEnabled = "gpc_enabled"
        case doNotShareOrSell = "do_not_share_or_sell"
    }
}

internal struct V2OffersChannel: Encodable {
    let type: String
    let sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
    }
}

internal struct V2OffersCustomer: Encodable {
    let email: String
}
