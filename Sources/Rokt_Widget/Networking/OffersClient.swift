// periphery:ignore:all

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

    /// The request — its URL, its headers and the JSON encoding of its body, which grows with the attributes — is built
    /// before `handOff` is asked, so `start` is the send alone: the network task's creation and resume. `handOff`
    /// encloses that one call, which gives the request to the network stack. It either runs `start`, which sends, or
    /// throws without running it, in which case nothing is sent and the caller receives that error. The default sends
    /// unconditionally. A caller uses it to make its decision to send atomic with the send itself, and holding a lock
    /// across it holds it for nothing that grows with the request. `start` sends at most once however many times it is
    /// called, and a hand-off that returns without running it fails the request with
    /// ``OffersClientError/handOffDidNotStart`` rather than leaving the caller waiting.
    func fetchOffers(
        input: OffersInput,
        handOff: (_ start: () -> Void) throws -> Void = { start in start() }
    ) async throws -> (Data?, HTTPURLResponse?) {
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
        headers["rokt-layout-schema-version"] = layoutSchemaVersion
        // Device headers (os, model, locale, app version) and the load-bearing
        // rokt-package-name ride in via NetworkingHelper.txnDeviceHeaders — the
        // gateway's mobile page detection and targeting key off them.
        for (key, value) in deviceHeaders {
            headers[key] = value
        }

        return try await withCheckedThrowingContinuation { continuation in
            // The request is built here, before the hand-off is asked: its URL, its headers and the JSON encoding of
            // its body, the one step that grows with the attributes. `send` is only the network task's creation and
            // resume, so a hand-off that holds a lock holds it for that alone. Nothing is sent unless `send` runs.
            let send = httpClient.prepareRequest(
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
            // The continuation is resumed exactly once: `start` is the only call that arms the completion handler
            // and arms it at most once, so a hand-off that ran `start` leaves the resume to the completion handler,
            // whatever it does afterwards; a hand-off that threw without running it is failed with its error; and a
            // hand-off that returned without running it, which nothing else could ever resume, is failed below.
            var started = false
            do {
                try handOff {
                    // A second call sends nothing more, so the completion handler stays the one resume.
                    guard !started else { return }
                    started = true
                    send()
                }
            } catch {
                if !started { continuation.resume(throwing: error) }
                return
            }
            if !started { continuation.resume(throwing: OffersClientError.handOffDidNotStart) }
        }
    }
}

internal enum OffersClientError: Error, Equatable {
    case bodyEncodingFailed
    /// The hand-off returned without running `start` and without throwing, so no request was sent and no response
    /// will ever arrive for it.
    case handOffDidNotStart
}

internal struct OffersInput {
    let requestId: String
    let pageIdentifier: String
    let attributes: [String: String]
    var privacyControl: SelectPrivacyControl?
    var privacy: SelectPrivacy?
    var events: [SelectEvent]?
}
