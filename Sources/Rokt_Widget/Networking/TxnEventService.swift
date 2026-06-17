import Foundation

internal struct TxnEventService {
    enum TxnEventError: Error, Equatable {
        case invalidBaseURL
        case unexpectedStatusCode(Int)
    }

    let environment: Environment
    let accountId: String
    let sdkVersion: String
    let sessionManager: TxnSessionManager
    let httpClient: HTTPClientAdapter
    let deviceHeaders: [String: String]
    let maxRetries: Int
    let requestTimeout: TimeInterval
    let baseBackoff: TimeInterval
    let sleep: (TimeInterval) async throws -> Void

    init(
        environment: Environment,
        accountId: String,
        sdkVersion: String,
        sessionManager: TxnSessionManager,
        httpClient: HTTPClientAdapter = RoktHTTPClient(),
        deviceHeaders: [String: String] = [:],
        maxRetries: Int = 3,
        requestTimeout: TimeInterval = 7,
        baseBackoff: TimeInterval = 0.2,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.environment = environment
        self.accountId = accountId
        self.sdkVersion = sdkVersion
        self.sessionManager = sessionManager
        self.httpClient = httpClient
        self.deviceHeaders = deviceHeaders
        self.maxRetries = maxRetries
        self.requestTimeout = requestTimeout
        self.baseBackoff = baseBackoff
        self.sleep = sleep
    }

    func send(events: [V2Event]) async throws {
        guard !events.isEmpty else { return }
        guard let baseURL = URL(string: environment.gatewayBaseURL) else {
            throw TxnEventError.invalidBaseURL
        }

        httpClient.updateTimeout(timeout: requestTimeout)

        let client = V2EventsClient(
            baseURL: baseURL,
            accountId: accountId,
            authToken: sessionManager.authorizationHeader,
            sdkVersion: sdkVersion,
            deviceHeaders: deviceHeaders,
            httpClient: httpClient
        )

        var attempt = 0
        while true {
            do {
                let (data, response) = try await client.recordEvents(events: events)
                let statusCode = response?.statusCode ?? 0

                if isRetryable(statusCode: statusCode), attempt < maxRetries {
                    try await sleep(backoffDelay(attempt: attempt))
                    attempt += 1
                    continue
                }

                guard (200..<300).contains(statusCode) else {
                    throw TxnEventError.unexpectedStatusCode(statusCode)
                }

                if let data,
                   let decoded = try? JSONDecoder().decode(TxnEventsResponse.self, from: data),
                   let sessionToken = decoded.sessionToken {
                    sessionManager.update(sessionToken: sessionToken)
                }
                return
            } catch let error where isRetryable(error: error) && attempt < maxRetries {
                try await sleep(backoffDelay(attempt: attempt))
                attempt += 1
                continue
            }
        }
    }

    private func isRetryable(statusCode: Int) -> Bool {
        [500, 502, 503, 504].contains(statusCode)
    }

    // Transient transport failures only; a hard-offline device fails fast.
    private func isRetryable(error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return true
        default:
            return false
        }
    }

    // Exponential backoff with jitter to avoid hammering a struggling gateway.
    private func backoffDelay(attempt: Int) -> TimeInterval {
        let base = baseBackoff * pow(2, Double(attempt))
        return base + Double.random(in: 0...(base/2))
    }
}
