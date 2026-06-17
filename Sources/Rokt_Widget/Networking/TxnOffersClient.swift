// periphery:ignore:all - referenced from Tests/ContractTests/TxnOffersClientPactSpec.swift

import Foundation

internal struct TxnOffersClient {
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

    func fetchOffers(input: TxnOffersInput) async throws -> (Data?, HTTPURLResponse?) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("offers")

        let requestBody = TxnOffersRequest(
            sessionId: sessionId,
            mpSessionId: mpSessionId,
            mpid: mpid,
            page: TxnOffersPage(pageIdentifier: input.pageIdentifier, url: input.pageURL),
            privacy: TxnOffersPrivacy(doNotTrack: false, gpcEnabled: false, doNotShareOrSell: false),
            channel: TxnOffersChannel(type: "msdk", sdkVersion: sdkVersion),
            customer: TxnOffersCustomer(email: input.customerEmail),
            attributes: input.attributes
        )
        let bodyData = try JSONEncoder().encode(requestBody)
        guard let bodyParameters = try JSONSerialization.jsonObject(with: bodyData) as? RoktHTTPParameters else {
            throw TxnOffersClientError.bodyEncodingFailed
        }

        let headers: RoktHTTPHeaders = [
            "rokt-account-id": accountId,
            "Authorization": authToken,
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

internal enum TxnOffersClientError: Error {
    case bodyEncodingFailed
}

internal struct TxnOffersInput {
    let requestId: String
    let pageIdentifier: String
    let pageURL: String
    let customerEmail: String
    let attributes: [String: String]
}

internal struct TxnOffersRequest: Encodable {
    let sessionId: String
    let mpSessionId: String
    let mpid: String
    let page: TxnOffersPage
    let privacy: TxnOffersPrivacy
    let channel: TxnOffersChannel
    let customer: TxnOffersCustomer
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

internal struct TxnOffersPage: Encodable {
    let pageIdentifier: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case pageIdentifier = "page_identifier"
        case url
    }
}

internal struct TxnOffersPrivacy: Encodable {
    let doNotTrack: Bool
    let gpcEnabled: Bool
    let doNotShareOrSell: Bool

    enum CodingKeys: String, CodingKey {
        case doNotTrack = "do_not_track"
        case gpcEnabled = "gpc_enabled"
        case doNotShareOrSell = "do_not_share_or_sell"
    }
}

internal struct TxnOffersChannel: Encodable {
    let type: String
    let sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case type
        case sdkVersion = "sdk_version"
    }
}

internal struct TxnOffersCustomer: Encodable {
    let email: String
}
