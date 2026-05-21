import Foundation

/// Test-only client for the v2 sessions offers endpoint on transactions-api.
///
/// Mobile is not yet a consumer of this surface — production code still calls
/// `/rokt-mobile/v1/*`. This client exists so the consumer-driven pact spec can
/// describe the v2 contract that mobile will satisfy at v1→v2 migration. Lift
/// into `Sources/Rokt_Widget/Networking/` at cutover. See architecture plan in
/// rokt-pact-mobile-runner.
struct V2OffersClient {
    let baseURL: URL
    let urlSession: URLSession

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    struct Headers {
        let accountId: String
        let authorization: String
        let platformType: String
        let integrationType: String
        let requestId: String
        let pageInstanceGuid: String

        static func iOSDefaults(
            accountId: String,
            authorization: String,
            requestId: String,
            pageInstanceGuid: String
        ) -> Headers {
            Headers(
                accountId: accountId,
                authorization: authorization,
                platformType: "iOS",
                integrationType: "msdk-ios",
                requestId: requestId,
                pageInstanceGuid: pageInstanceGuid
            )
        }
    }

    struct Request: Encodable {
        let sessionId: String
        let mpSessionId: String
        let mpid: String
        let page: Page
        let privacy: Privacy
        let channel: Channel
        let customer: Customer
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

        struct Page: Encodable {
            let pageIdentifier: String
            let url: String

            enum CodingKeys: String, CodingKey {
                case pageIdentifier = "page_identifier"
                case url
            }
        }

        struct Privacy: Encodable {
            let doNotTrack: Bool
            let gpcEnabled: Bool
            let doNotShareOrSell: Bool

            enum CodingKeys: String, CodingKey {
                case doNotTrack = "do_not_track"
                case gpcEnabled = "gpc_enabled"
                case doNotShareOrSell = "do_not_share_or_sell"
            }
        }

        struct Channel: Encodable {
            let type: String
            let sdkVersion: String

            enum CodingKeys: String, CodingKey {
                case type
                case sdkVersion = "sdk_version"
            }
        }

        struct Customer: Encodable {
            let email: String
        }
    }

    func sendOffers(headers: Headers, body: Request) async throws -> (Data, URLResponse) {
        let url = baseURL
            .appendingPathComponent("v2")
            .appendingPathComponent("sessions")
            .appendingPathComponent("offers")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(headers.accountId, forHTTPHeaderField: "rokt-account-id")
        request.setValue(headers.authorization, forHTTPHeaderField: "Authorization")
        request.setValue(headers.platformType, forHTTPHeaderField: "rokt-platform-type")
        request.setValue(headers.integrationType, forHTTPHeaderField: "rokt-integration-type")
        request.setValue(headers.requestId, forHTTPHeaderField: "x-request-id")
        request.setValue(headers.pageInstanceGuid, forHTTPHeaderField: "rokt-page-instance-guid")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(body)

        return try await urlSession.data(for: request)
    }
}
