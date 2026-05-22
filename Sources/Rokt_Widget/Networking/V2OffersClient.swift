import Foundation

/// Client for the v2 sessions offers endpoint on transactions-api.
///
/// Not yet called from any production code path — the SDK still uses
/// `/rokt-mobile/v1/*` via `RoktNetWorkAPI`. This client describes the
/// v2 wire contract that mobile will satisfy when v1→v2 migration lands;
/// at that point the existing networking code switches over to call this.
///
/// Lives in Sources/ rather than Tests/ so the consumer pact spec in
/// `Tests/ContractTests/V2OffersClientPactSpec.swift` constrains the
/// actual shipping SDK code. A pact contract describing test-only code
/// can silently diverge from production at migration time; describing
/// real SDK code closes that gap.
///
/// The client owns wire-shape construction — header and body assembly —
/// based on domain inputs. The pact spec describes the expected wire
/// shape via matchers, and any drift here will be caught by the pact
/// mock service. See [[pact-consumer-conventions]] §10a for the rule.
internal struct V2OffersClient {
    let baseURL: URL
    let accountId: String
    let authToken: String
    let sessionId: String
    let mpSessionId: String
    let mpid: String
    let sdkVersion: String
    let pageInstanceGuid: String
    let urlSession: URLSession

    init(
        baseURL: URL,
        accountId: String,
        authToken: String,
        sessionId: String,
        mpSessionId: String,
        mpid: String,
        sdkVersion: String,
        pageInstanceGuid: String,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accountId = accountId
        self.authToken = authToken
        self.sessionId = sessionId
        self.mpSessionId = mpSessionId
        self.mpid = mpid
        self.sdkVersion = sdkVersion
        self.pageInstanceGuid = pageInstanceGuid
        self.urlSession = urlSession
    }

    func fetchOffers(input: V2OffersInput) async throws -> (Data, URLResponse) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("offers")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(accountId, forHTTPHeaderField: "rokt-account-id")
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("iOS", forHTTPHeaderField: "rokt-platform-type")
        request.setValue("msdk-ios", forHTTPHeaderField: "rokt-integration-type")
        request.setValue(input.requestId, forHTTPHeaderField: "x-request-id")
        request.setValue(pageInstanceGuid, forHTTPHeaderField: "rokt-page-instance-guid")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = V2OffersRequest(
            sessionId: sessionId,
            mpSessionId: mpSessionId,
            mpid: mpid,
            page: V2OffersPage(pageIdentifier: input.pageIdentifier, url: input.pageURL),
            privacy: V2OffersPrivacy(doNotTrack: false, gpcEnabled: false, doNotShareOrSell: false),
            channel: V2OffersChannel(type: "msdk", sdkVersion: sdkVersion),
            customer: V2OffersCustomer(email: input.customerEmail),
            attributes: input.attributes
        )
        request.httpBody = try JSONEncoder().encode(body)

        return try await urlSession.data(for: request)
    }
}

/// Per-call domain inputs for `V2OffersClient.fetchOffers`.
///
/// Holds only the values that vary per-request from a caller's perspective.
/// Session-shaped values (account id, session token, mp ids, etc.) are
/// injected at client construction time, mirroring how a production iOS
/// service resolves them from session / config services.
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
