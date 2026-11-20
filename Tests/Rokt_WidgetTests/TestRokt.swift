import XCTest
import Foundation
import RoktContracts
@testable internal import RoktUXHelper

@testable import Rokt_Widget

class TestRokt: XCTestCase {

    override func setUp() {
        super.setUp()
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        UserDefaults.standard.removeObject(forKey: "com.rokt.sdk.lastPrivacyControlSignature")
        Rokt.shared.roktImplementation.removeAllGlobalEventListeners()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_setCustomBaseURL_setsCustomEnvironment() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com")
    }

    func test_setCustomBaseURL_stripsPath() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com/api/v2")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com")
    }

    func test_setCustomBaseURL_stripsQueryAndFragment() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com/path?q=1#frag")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com")
    }

    func test_setCustomBaseURL_preservesPort() {
        Rokt.setCustomBaseURL(URL(string: "https://rkt.example.com:8443")!)
        XCTAssertEqual(baseURL, "https://rkt.example.com:8443")
    }

    func test_setCustomBaseURL_rejectsNonHTTPS() {
        let originalBaseURL = baseURL
        Rokt.setCustomBaseURL(URL(string: "http://rkt.example.com")!)
        XCTAssertEqual(baseURL, originalBaseURL)
    }

    func test_setCustomBaseURL_rejectsEmptyHost() {
        let originalBaseURL = baseURL
        Rokt.setCustomBaseURL(URL(string: "https://")!)
        XCTAssertEqual(baseURL, originalBaseURL)
    }

    func test_setEnvironment_valid_Stage() {
        Rokt.setEnvironment(environment: .Stage)
        XCTAssertEqual(config.environment, Environment.Stage)
        XCTAssertEqual(baseURL, Environment.Stage.baseURL)
    }

    func test_setEnvironment_valid_Prod() {
        Rokt.setEnvironment(environment: .Prod)
        XCTAssertEqual(config.environment, Environment.Prod)
        XCTAssertEqual(baseURL, Environment.Prod.baseURL)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

    func test_init_with_callback_success() {
        // Arrange
        let initComplete = XCTestExpectation(description: "Init complete")
        var initStatus = false

        // Act
        Rokt.globalEvents(onEvent: { roktEvent in
            if roktEvent is RoktEvent.InitComplete {
                initStatus = true
                initComplete.fulfill()
            }
        })
        Rokt.initWith(roktTagId: "12345")

        // Assert
        wait(for: [initComplete], timeout: 5)
        XCTAssertTrue(initStatus)
    }

    func test_mparticle_init_callback_success() {
        // Arrange
        let initComplete = XCTestExpectation(description: "Init complete")
        var initStatus = false

        let expectedSdkVersion = "1.2.3"
        let expectedKitVersion = "4.5.6"

        // Act
        Rokt.globalEvents(onEvent: { roktEvent in
            if roktEvent is RoktEvent.InitComplete {
                initStatus = true
                initComplete.fulfill()
            }
        })
        Rokt.initWith(
            roktTagId: "12345",
            mParticleSdkVersion: expectedSdkVersion,
            mParticleKitVersion: expectedKitVersion
        )

        // Assert
        XCTAssertEqual(NetworkingHelper.shared.mParticleKitDetails?.sdkVersion, expectedSdkVersion)
        XCTAssertEqual(NetworkingHelper.shared.mParticleKitDetails?.kitVersion, expectedKitVersion)

        wait(for: [initComplete], timeout: 5)
        XCTAssertTrue(initStatus)
    }

    func testProcessLayoutPageExecutePayload_noPlugins_sessionIdIsSaved() {
        // Arrange
        let roktInternalImplementation = RoktInternalImplementation()
        let sessionId = "test-session-id"
        let response = """
            {
              "session_id": "\(sessionId)",
              "session_token": { "token": "test-token", "expires_at": 32503680000000 },
              "page_instance_guid": "test-guid",
              "page_context": { "page_id": "checkout", "token": "test-token" },
              "plugins": []
            }
            """

        // Act
        _ = roktInternalImplementation.processLayoutPageExecutePayload(
            response, selectionId: "12345", viewName: "test", attributes: [:]
        )

        // Assert
        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            sessionId
        )
    }

    func testProcessLayoutPageExecutePayload_recordsExperienceJsonParseTimes() {
        // Arrange
        let roktInternalImplementation = RoktInternalImplementation()
        let timingsProcessor = TimingsRequestProcessor(apiHelper: RoktAPIHelperSpy.self)
        roktInternalImplementation.processedTimingsRequests = timingsProcessor
        RoktAPIHelperSpy.reset()
        let selectionId = UUID().uuidString
        let response = """
            {
              "session_id": "test-session-id",
              "session_token": { "token": "test-token", "expires_at": 32503680000000 },
              "page_instance_guid": "test-guid",
              "page_context": { "page_id": "checkout", "token": "test-token" },
              "plugins": []
            }
            """

        // Act - parse times are recorded even when the response has no renderable layouts
        _ = roktInternalImplementation.processLayoutPageExecutePayload(
            response, selectionId: selectionId, viewName: "test", attributes: [:]
        )

        // Assert - the parse window flows into the timing events request
        timingsProcessor.setExperiencesRequestStartTime(selectionId: selectionId)
        timingsProcessor.setPlacementInteractiveTime(selectionId: selectionId)
        timingsProcessor.processTimingsRequest(selectionId: selectionId)
        let eventsRequest = RoktAPIHelperSpy.lastTimingEventsRequest
        XCTAssertNotNil(eventsRequest)
        XCTAssertTrue(eventsRequest!.timings.contains { $0.name == .experienceJsonParseStart })
        XCTAssertTrue(eventsRequest!.timings.contains { $0.name == .experienceJsonParseEnd })
        RoktAPIHelperSpy.reset()
    }

    // MARK: - setSession Tests

    func test_setSession_noopWhenNotInitialized() {
        let roktInternalImplementation = RoktInternalImplementation()
        let session = RoktSession(
            sessionId: "sid",
            sessionToken: "jwt",
            expiresAtMilliseconds: Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
        )

        roktInternalImplementation.setSession(session)

        XCTAssertNil(roktInternalImplementation.getSession())
        XCTAssertNil(roktInternalImplementation.getSessionId())
    }

    func test_setSession_persistsForTxnSessionManagerAndMirrorsLegacySessionId() async {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-set-session"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
        let session = RoktSession(
            sessionId: "webview-sid",
            sessionToken: "webview-jwt",
            expiresAtMilliseconds: expiresAt
        )

        roktInternalImplementation.setSession(session)

        let restored = TxnSessionManager(roktTagId: "tag-set-session")
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "webview-sid")
        XCTAssertEqual(header, "Bearer webview-jwt")
        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            "webview-sid"
        )
        XCTAssertEqual(roktInternalImplementation.getSessionId(), "webview-sid")
    }

    func test_setSession_ignoresEmptySessionId() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-empty-id"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)

        roktInternalImplementation.setSession(
            RoktSession(sessionId: "  ", sessionToken: "jwt", expiresAtMilliseconds: expiresAt)
        )

        XCTAssertNil(roktInternalImplementation.getSession())
        XCTAssertNil(roktInternalImplementation.getSessionId())
    }

    func test_setSession_ignoresEmptySessionToken() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-empty-token"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)

        roktInternalImplementation.setSession(
            RoktSession(sessionId: "sid", sessionToken: "", expiresAtMilliseconds: expiresAt)
        )

        XCTAssertNil(roktInternalImplementation.getSession())
        XCTAssertNil(roktInternalImplementation.getSessionId())
    }

    func test_getSession_roundTripsSetSession() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-round-trip"
        let expiresAt = Int64(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
        let session = RoktSession(
            sessionId: "sid-1",
            sessionToken: "jwt-1",
            expiresAtMilliseconds: expiresAt
        )

        roktInternalImplementation.setSession(session)
        let loaded = roktInternalImplementation.getSession()

        XCTAssertEqual(loaded?.sessionId, "sid-1")
        XCTAssertEqual(loaded?.sessionToken, "jwt-1")
        XCTAssertEqual(loaded?.expiresAt?.int64Value, expiresAt)
    }

    func test_setSession_withoutExpiresAt_appliesDefaultTTL() async {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-no-expiry"
        let before = Date()

        roktInternalImplementation.setSession(
            RoktSession(sessionId: "sid", sessionToken: "jwt")
        )

        let loaded = roktInternalImplementation.getSession()
        XCTAssertEqual(loaded?.sessionId, "sid")
        XCTAssertEqual(loaded?.sessionToken, "jwt")
        guard let expiresAtMs = loaded?.expiresAt?.int64Value else {
            XCTFail("Expected default expiresAt after setSession without expiry")
            return
        }
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtMs)/1000)
        // Default TTL is 30 minutes; allow a few seconds of test slack.
        XCTAssertGreaterThan(expiresAt, before.addingTimeInterval(29 * 60))
        XCTAssertLessThan(expiresAt, before.addingTimeInterval(31 * 60))

        let restored = TxnSessionManager(roktTagId: "tag-no-expiry")
        let header = await restored.authorizationHeader
        XCTAssertEqual(header, "Bearer jwt")
    }

    func test_getSession_returnsNilWhenExpired() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-expired-get"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
        roktInternalImplementation.setSession(
            RoktSession(sessionId: "sid", sessionToken: "jwt", expiresAtMilliseconds: expiresAt)
        )
        XCTAssertNotNil(roktInternalImplementation.getSession())

        // Simulate elapsed time after a valid seed without sleeping.
        let pastMs = Int64(Date().addingTimeInterval(-60).timeIntervalSince1970 * 1000)
        UserDefaultsTxnSessionStore().setString(String(pastMs), forKey: TxnSessionStoreKeys.expiresAt)

        XCTAssertNil(roktInternalImplementation.getSession())
        XCTAssertNil(UserDefaultsTxnSessionStore().string(forKey: TxnSessionStoreKeys.token))
    }

    /// The store writes its keys one at a time, so a read that lands before the expiry key is written
    /// must return nil and leave the just-written session in place.
    func test_getSession_missingExpiryKey_returnsNilWithoutClearing() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-missing-expiry-key"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
        roktInternalImplementation.setSession(
            RoktSession(sessionId: "sid", sessionToken: "jwt", expiresAtMilliseconds: expiresAt)
        )
        XCTAssertNotNil(roktInternalImplementation.getSession())

        UserDefaultsTxnSessionStore().removeValue(forKey: TxnSessionStoreKeys.expiresAt)

        XCTAssertNil(roktInternalImplementation.getSession())
        XCTAssertEqual(UserDefaultsTxnSessionStore().string(forKey: TxnSessionStoreKeys.token), "jwt")
        XCTAssertEqual(UserDefaultsTxnSessionStore().string(forKey: TxnSessionStoreKeys.sessionId), "sid")
    }

    /// A persisted expiry outside the accepted range reads as no session and is cleared.
    func test_getSession_outOfRangePersistedExpiry_returnsNilAndClears() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-out-of-range-expiry"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)

        for raw in ["9.223372036854776e+18", "9223372036854775807", "9223372036854774784", "inf", "nan"] {
            roktInternalImplementation.setSession(
                RoktSession(sessionId: "sid", sessionToken: "jwt", expiresAtMilliseconds: expiresAt)
            )
            XCTAssertNotNil(roktInternalImplementation.getSession(), raw)

            UserDefaultsTxnSessionStore().setString(raw, forKey: TxnSessionStoreKeys.expiresAt)

            XCTAssertNil(roktInternalImplementation.getSession(), raw)
            XCTAssertNil(UserDefaultsTxnSessionStore().string(forKey: TxnSessionStoreKeys.token), raw)
            XCTAssertNil(UserDefaultsTxnSessionStore().string(forKey: TxnSessionStoreKeys.expiresAt), raw)
        }
    }

    func test_setSession_farFutureExpiresAt_isCappedAndRoundTrips() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-far-future"
        let before = Date()

        roktInternalImplementation.setSession(
            RoktSession(sessionId: "sid", sessionToken: "jwt", expiresAtMilliseconds: Int64.max)
        )

        let loaded = roktInternalImplementation.getSession()
        XCTAssertEqual(loaded?.sessionId, "sid")
        XCTAssertEqual(loaded?.sessionToken, "jwt")
        guard let expiresAtMs = loaded?.expiresAt?.int64Value else {
            XCTFail("Expected a capped expiresAt after setSession with a far-future expiry")
            return
        }
        // Allow a few seconds of test slack on the cap.
        let capMs = Int64(before.addingTimeInterval(TxnSessionPersistence.maxTokenTTL + 5).timeIntervalSince1970 * 1000)
        XCTAssertLessThanOrEqual(expiresAtMs, capMs)
        XCTAssertGreaterThan(expiresAtMs, Int64(before.timeIntervalSince1970 * 1000))
    }

    func test_setSession_pastExpiresAt_fallsBackToDefaultTTL() async {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-expired"
        let expiredAt = Int64(Date().addingTimeInterval(-60).timeIntervalSince1970 * 1000)

        roktInternalImplementation.setSession(
            RoktSession(sessionId: "sid", sessionToken: "jwt", expiresAtMilliseconds: expiredAt)
        )

        let loaded = roktInternalImplementation.getSession()
        XCTAssertEqual(loaded?.sessionId, "sid")
        XCTAssertEqual(loaded?.sessionToken, "jwt")
        XCTAssertEqual(roktInternalImplementation.getSessionId(), "sid")
        let restored = TxnSessionManager(roktTagId: "tag-expired")
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertEqual(sessionId, "sid")
        XCTAssertEqual(header, "Bearer jwt")
    }

    func test_setSessionId_doesNotWriteTxnSessionToken() async {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-legacy-set"
        roktInternalImplementation.setSessionId(sessionId: "legacy-only-sid")

        let restored = TxnSessionManager(roktTagId: "tag-legacy-set")
        let sessionId = await restored.currentSessionId
        let header = await restored.authorizationHeader
        XCTAssertNil(sessionId)
        XCTAssertNil(header)
        XCTAssertEqual(roktInternalImplementation.getSessionId(), "legacy-only-sid")
        XCTAssertNil(roktInternalImplementation.getSession())
    }

    // MARK: - setSessionId Tests

    func test_setSessionId_updatesSessionManager() {
        let roktInternalImplementation = RoktInternalImplementation()

        roktInternalImplementation.setSessionId(sessionId: "webview-session-id")

        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            "webview-session-id"
        )
    }

    func test_setSessionId_ignoresEmptyString() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.setSessionId(sessionId: "existing-session-id")

        roktInternalImplementation.setSessionId(sessionId: "")

        // Empty string should be a no-op - original session should remain
        XCTAssertEqual(
            roktInternalImplementation.sessionManager.getCurrentSessionIdWithoutExpiring(),
            "existing-session-id"
        )
    }

    // MARK: - availablePaymentMethods Tests

    func test_availablePaymentMethods_excludesPayPalBeforeRedirectSchemeIsSet() {
        let roktInternalImplementation = RoktInternalImplementation()

        let methods = roktInternalImplementation.availablePaymentMethods

        XCTAssertEqual(Set(methods), Set([PaymentMethodType.card]))
    }

    func test_availablePaymentMethods_includesPayPalAfterRedirectSchemeIsSet() {
        let roktInternalImplementation = RoktInternalImplementation()

        XCTAssertTrue(roktInternalImplementation.setBuiltInPayPalRedirectURLScheme("myapp"))

        XCTAssertEqual(Set(roktInternalImplementation.availablePaymentMethods), Set([.card, .paypal]))
    }

    func test_availablePaymentMethods_excludesPayPalAfterRedirectSchemeIsCleared() {
        let roktInternalImplementation = RoktInternalImplementation()
        XCTAssertTrue(roktInternalImplementation.setBuiltInPayPalRedirectURLScheme("myapp"))

        XCTAssertTrue(roktInternalImplementation.setBuiltInPayPalRedirectURLScheme(nil))

        XCTAssertEqual(Set(roktInternalImplementation.availablePaymentMethods), Set([PaymentMethodType.card]))
    }

    // MARK: - getSessionId Tests

    func test_getSessionId_returnsNilWhenNoSession() {
        let roktInternalImplementation = RoktInternalImplementation()

        let sessionId = roktInternalImplementation.getSessionId()

        XCTAssertNil(sessionId)
    }

    func test_getSessionId_returnsSessionIdAfterSetSession() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "tag-get-session-id"
        let expectedSessionId = "test-session-123"
        roktInternalImplementation.setSession(
            RoktSession(
                sessionId: expectedSessionId,
                sessionToken: "jwt",
                expiresAtMilliseconds: Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
            )
        )

        let sessionId = roktInternalImplementation.getSessionId()

        XCTAssertEqual(sessionId, expectedSessionId)
    }

    func test_buildContactAddress_mapsTransactionDataAddress() throws {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes["email"] = "jane@example.com"

        let address = try JSONDecoder().decode(
            Address.self,
            from: Data(
                """
                {
                  "name": "Jane Doe",
                  "address1": "123 Test St",
                  "address2": "Apt 1101",
                  "city": "New York",
                  "state": "New York",
                  "stateCode": "NY",
                  "country": "United States",
                  "countryCode": "US",
                  "zip": "10001"
                }
                """.utf8
            )
        )

        let contactAddress = roktInternalImplementation.buildContactAddress(from: address)

        XCTAssertEqual(contactAddress?.name, "Jane Doe")
        XCTAssertEqual(contactAddress?.email, "jane@example.com")
        XCTAssertEqual(contactAddress?.addressLine1, "123 Test St")
        XCTAssertEqual(contactAddress?.addressLine2, "Apt 1101")
        XCTAssertEqual(contactAddress?.city, "New York")
        XCTAssertEqual(contactAddress?.state, "NY")
        XCTAssertEqual(contactAddress?.postalCode, "10001")
        XCTAssertEqual(contactAddress?.country, "US")
    }

    func test_buildContactAddress_fallsBackToAttributeNameWhenTransactionDataNameIsEmpty() throws {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes = [
            "firstname": "Jane",
            "lastname": "Doe",
            "email": "jane@example.com"
        ]

        let address = try JSONDecoder().decode(
            Address.self,
            from: Data(
                """
                {
                  "name": "",
                  "address1": "123 Test St",
                  "address2": null,
                  "city": "New York",
                  "state": "New York",
                  "stateCode": "NY",
                  "country": "United States",
                  "countryCode": "US",
                  "zip": "10001"
                }
                """.utf8
            )
        )

        let contactAddress = roktInternalImplementation.buildContactAddress(from: address)

        XCTAssertEqual(contactAddress?.name, "Jane Doe")
        XCTAssertEqual(contactAddress?.email, "jane@example.com")
        XCTAssertEqual(contactAddress?.addressLine1, "123 Test St")
    }

    func test_buildContactAddressFromAttributes_mapsLegacyShippingAttributes() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes = [
            "firstname": "Jane",
            "lastname": "Doe",
            "email": "jane@example.com",
            "shippingaddress1": "456 Legacy Rd",
            "shippingaddress2": "Unit 9",
            "shippingcity": "Boston",
            "shippingstate": "MA",
            "shippingzipcode": "02110",
            "shippingcountry": "US"
        ]

        let contactAddress = roktInternalImplementation.buildContactAddressFromAttributes()

        XCTAssertEqual(contactAddress?.name, "Jane Doe")
        XCTAssertEqual(contactAddress?.email, "jane@example.com")
        XCTAssertEqual(contactAddress?.addressLine1, "456 Legacy Rd")
        XCTAssertEqual(contactAddress?.addressLine2, "Unit 9")
        XCTAssertEqual(contactAddress?.city, "Boston")
        XCTAssertEqual(contactAddress?.state, "MA")
        XCTAssertEqual(contactAddress?.postalCode, "02110")
        XCTAssertEqual(contactAddress?.country, "US")
    }

    func test_buildContactAddressFromAttributes_returnsNilWithoutAddressLine1() {
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.attributes = [
            "firstname": "Jane",
            "lastname": "Doe",
            "shippingcity": "Boston"
        ]

        XCTAssertNil(roktInternalImplementation.buildContactAddressFromAttributes())
    }

    // MARK: - Rokt Public API Tests

    func test_Rokt_setSession_roundTrips() {
        Rokt.shared.roktImplementation.roktTagId = "public-tag"
        let expiresAt = Int64(Date().addingTimeInterval(1800).timeIntervalSince1970 * 1000)
        let session = RoktSession(
            sessionId: "public-sid",
            sessionToken: "public-jwt",
            expiresAtMilliseconds: expiresAt
        )

        Rokt.setSession(session)
        let loaded = Rokt.getSession()

        XCTAssertEqual(loaded?.sessionId, "public-sid")
        XCTAssertEqual(loaded?.sessionToken, "public-jwt")
        XCTAssertEqual(loaded?.expiresAt?.int64Value, expiresAt)
    }

    func test_Rokt_setSessionId_updatesSession() {
        let expectedSessionId = "public-api-session-id"

        Rokt.shared.roktImplementation.setSessionId(sessionId: expectedSessionId)

        XCTAssertEqual(Rokt.shared.roktImplementation.getSessionId(), expectedSessionId)
    }

    func test_Rokt_getSessionId_returnsSessionId() {
        let expectedSessionId = "get-session-test-id"
        Rokt.shared.roktImplementation.setSessionId(sessionId: expectedSessionId)

        let sessionId = Rokt.shared.roktImplementation.getSessionId()

        XCTAssertEqual(sessionId, expectedSessionId)
    }

    func test_Rokt_setSessionId_ignoresEmptyString() {
        let originalSessionId = "original-session-id"
        Rokt.shared.roktImplementation.setSessionId(sessionId: originalSessionId)

        Rokt.shared.roktImplementation.setSessionId(sessionId: "")

        // Empty string should be a no-op - original session should remain
        XCTAssertEqual(Rokt.shared.roktImplementation.getSessionId(), originalSessionId)
    }

    // MARK: - setPrivacyControl Tests

    func test_setPrivacyControl_storesInMemoryAndUpdatesOnSubsequentCall() {
        let roktInternalImplementation = RoktInternalImplementation()
        XCTAssertNil(roktInternalImplementation.privacyControl)

        let initial = RoktPrivacyControl(
            noFunctional: true,
            noTargeting: false,
            doNotShareOrSell: true
        )
        roktInternalImplementation.setPrivacyControl(initial)

        XCTAssertEqual(roktInternalImplementation.privacyControl?.noFunctional, true)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, false)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.doNotShareOrSell, true)

        let updated = RoktPrivacyControl(
            noFunctional: false,
            noTargeting: true,
            doNotShareOrSell: false
        )
        roktInternalImplementation.setPrivacyControl(updated)

        XCTAssertEqual(roktInternalImplementation.privacyControl?.noFunctional, false)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, true)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.doNotShareOrSell, false)
    }

    func test_setPrivacyControl_partialCall_keepsOtherFlags() {
        let roktInternalImplementation = RoktInternalImplementation()

        roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noTargeting: true))
        roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noFunctional: true))

        XCTAssertEqual(roktInternalImplementation.privacyControl?.noFunctional, true)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, true)
        XCTAssertNil(roktInternalImplementation.privacyControl?.doNotShareOrSell)
    }

    func test_setPrivacyControl_trueThenFalse_clearsFlag() {
        let roktInternalImplementation = RoktInternalImplementation()

        roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noTargeting: true))
        roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noTargeting: false))

        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, false)
    }

    func test_setPrivacyControl_emptyCall_changesNothing() {
        let signatureKey = "com.rokt.sdk.lastPrivacyControlSignature"
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noTargeting: true))
        let storedSignature = UserDefaults.standard.string(forKey: signatureKey)

        roktInternalImplementation.setPrivacyControl(RoktPrivacyControl())

        XCTAssertNil(roktInternalImplementation.privacyControl?.noFunctional)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, true)
        XCTAssertNil(roktInternalImplementation.privacyControl?.doNotShareOrSell)
        XCTAssertEqual(UserDefaults.standard.string(forKey: signatureKey), storedSignature)
        XCTAssertEqual(storedSignature, "false|true|false")
    }

    func test_setPrivacyControl_emptyCallAfterRestart_keepsStoredSignature() {
        let signatureKey = "com.rokt.sdk.lastPrivacyControlSignature"
        UserDefaults.standard.set("false|true|false", forKey: signatureKey)
        let relaunchedImplementation = RoktInternalImplementation()

        relaunchedImplementation.setPrivacyControl(RoktPrivacyControl())

        XCTAssertNil(relaunchedImplementation.privacyControl)
        XCTAssertEqual(UserDefaults.standard.string(forKey: signatureKey), "false|true|false")
    }

    func test_setPrivacyControl_calledAgainFromDefaultsObserver_doesNotDeadlock() {
        let roktInternalImplementation = RoktInternalImplementation()
        var reentered = false
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            guard !reentered else { return }
            reentered = true
            roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noFunctional: true))
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let finished = expectation(description: "setPrivacyControl returns")
        DispatchQueue.global().async {
            roktInternalImplementation.setPrivacyControl(RoktPrivacyControl(noTargeting: true))
            finished.fulfill()
        }

        wait(for: [finished], timeout: 2.0)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noFunctional, true)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, true)
    }

    func test_setPrivacyControl_concurrentPartialCalls_keepEveryFlag() {
        let roktInternalImplementation = RoktInternalImplementation()

        DispatchQueue.concurrentPerform(iterations: 200) { iteration in
            roktInternalImplementation.setPrivacyControl(
                iteration.isMultiple(of: 2)
                    ? RoktPrivacyControl(noFunctional: true)
                    : RoktPrivacyControl(noTargeting: true)
            )
        }

        XCTAssertEqual(roktInternalImplementation.privacyControl?.noFunctional, true)
        XCTAssertEqual(roktInternalImplementation.privacyControl?.noTargeting, true)
    }

    func test_Rokt_setPrivacyControl_flagOverload_mergesLikeObjectForm() {
        let originalImpl = Rokt.shared.roktImplementation
        let isolatedImpl = RoktInternalImplementation()
        Rokt.shared.roktImplementation = isolatedImpl
        defer { Rokt.shared.roktImplementation = originalImpl }

        Rokt.setPrivacyControl(noTargeting: true)
        Rokt.setPrivacyControl(noFunctional: true)

        XCTAssertEqual(isolatedImpl.privacyControl?.noFunctional, true)
        XCTAssertEqual(isolatedImpl.privacyControl?.noTargeting, true)
        XCTAssertNil(isolatedImpl.privacyControl?.doNotShareOrSell)
    }

    func test_Rokt_setPrivacyControl_updatesSharedImplementation() {
        let originalImpl = Rokt.shared.roktImplementation
        let isolatedImpl = RoktInternalImplementation()
        Rokt.shared.roktImplementation = isolatedImpl
        defer { Rokt.shared.roktImplementation = originalImpl }

        let privacyControl = RoktPrivacyControl(
            noFunctional: true,
            noTargeting: true,
            doNotShareOrSell: false
        )
        Rokt.setPrivacyControl(privacyControl)

        XCTAssertEqual(Rokt.shared.roktImplementation.privacyControl?.noFunctional, true)
        XCTAssertEqual(Rokt.shared.roktImplementation.privacyControl?.noTargeting, true)
        XCTAssertEqual(Rokt.shared.roktImplementation.privacyControl?.doNotShareOrSell, false)
    }

    func test_execute_persistsSetPrivacyControlAcrossRequestsWithOptOutPrecedence() throws {
        final class RecordingOffersHTTPClient: HTTPClientAdapter {
            var recordedParameters: [RoktHTTPParameters] = []
            func updateTimeout(timeout: Double) {}
            @discardableResult
            func startRequestWith(
                urlAddress: String,
                method: RoktHTTPMethod,
                parameters: RoktHTTPParameters?,
                parameterArray: RoktHTTPParameterArray?,
                headers: RoktHTTPHeaders?,
                onRequestStart: (() -> Void)?,
                requestTimeout: TimeInterval?,
                completionQueue: DispatchQueue,
                completionHandler: ((RoktHTTPRequestResult) -> Void)?
            ) -> URLRequest? {
                if let parameters {
                    recordedParameters.append(parameters)
                }
                let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
                let result = RoktHTTPRequestResult(
                    httpURLResponse: HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil),
                    responseData: nil,
                    responseError: nil,
                    jsonSerialisedResponseData: .success(NSNull())
                )
                completionQueue.async { completionHandler?(result) }
                return nil
            }
            func downloadFile(
                source urlAddress: String,
                destinationURL: URL,
                options: [RoktDownloadOptions],
                parameters: RoktHTTPParameters?,
                headers: RoktHTTPHeaders?,
                requestTimeout: TimeInterval?,
                completionQueue: DispatchQueue,
                completionHandler: ((RoktDownloadResult) -> Void)?
            ) {}
        }

        let httpClient = RecordingOffersHTTPClient()
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "test-tag"
        roktInternalImplementation.isInitialized = true
        roktInternalImplementation.diagnosticsSender = { _, _, _ in }
        roktInternalImplementation.makeOffersServiceOverride = { tagId in
            OffersService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "1.0.0",
                layoutSchemaVersion: "2.8",
                sessionManager: TxnSessionManager(),
                httpClient: httpClient,
                maxRetries: 0,
                sleep: { _ in },
                triggeredEvents: { [] },
                captureEvents: { _ in }
            )
        }

        roktInternalImplementation.setPrivacyControl(
            RoktPrivacyControl(
                noFunctional: true,
                noTargeting: false,
                doNotShareOrSell: false
            )
        )

        let firstDone = expectation(description: "first execute completes")
        roktInternalImplementation.execute(
            viewName: "checkout",
            attributes: ["noFunctional": "false", "noTargeting": "true"],
            config: nil
        ) { event in
            if event is RoktEvent.PlacementFailure {
                firstDone.fulfill()
            }
        }
        wait(for: [firstDone], timeout: 5)

        let secondDone = expectation(description: "second execute completes")
        roktInternalImplementation.execute(
            viewName: "confirmation",
            attributes: [:],
            config: nil
        ) { event in
            if event is RoktEvent.PlacementFailure {
                secondDone.fulfill()
            }
        }
        wait(for: [secondDone], timeout: 5)

        XCTAssertEqual(httpClient.recordedParameters.count, 2)
        let firstPrivacy = try XCTUnwrap(httpClient.recordedParameters[0]["privacy_control"] as? [String: Any])
        XCTAssertEqual(firstPrivacy["no_functional"] as? Bool, true)
        XCTAssertEqual(firstPrivacy["no_targeting"] as? Bool, true)
        XCTAssertEqual(firstPrivacy["do_not_share_or_sell"] as? Bool, false)

        let secondPrivacy = try XCTUnwrap(httpClient.recordedParameters[1]["privacy_control"] as? [String: Any])
        XCTAssertEqual(secondPrivacy["no_functional"] as? Bool, true)
        XCTAssertEqual(secondPrivacy["no_targeting"] as? Bool, false)
        XCTAssertEqual(secondPrivacy["do_not_share_or_sell"] as? Bool, false)
    }

    func test_execute_whenPrivacyControlChangesAfterCachedExperience_bypassesCacheAndSendsUpdatedFlags() throws {
        Self.prepareExperienceCacheTestFiles()
        defer { ExperienceCacheManager.clearCache() }

        final class RecordingOffersHTTPClient: HTTPClientAdapter {
            var recordedParameters: [RoktHTTPParameters] = []
            func updateTimeout(timeout: Double) {}
            @discardableResult
            func startRequestWith(
                urlAddress: String,
                method: RoktHTTPMethod,
                parameters: RoktHTTPParameters?,
                parameterArray: RoktHTTPParameterArray?,
                headers: RoktHTTPHeaders?,
                onRequestStart: (() -> Void)?,
                requestTimeout: TimeInterval?,
                completionQueue: DispatchQueue,
                completionHandler: ((RoktHTTPRequestResult) -> Void)?
            ) -> URLRequest? {
                if let parameters {
                    recordedParameters.append(parameters)
                }
                let url = URL(string: urlAddress) ?? URL(string: Environment.Prod.gatewayBaseURL)!
                let result = RoktHTTPRequestResult(
                    httpURLResponse: HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil),
                    responseData: nil,
                    responseError: nil,
                    jsonSerialisedResponseData: .success(NSNull())
                )
                completionQueue.async { completionHandler?(result) }
                return nil
            }
            func downloadFile(
                source urlAddress: String,
                destinationURL: URL,
                options: [RoktDownloadOptions],
                parameters: RoktHTTPParameters?,
                headers: RoktHTTPHeaders?,
                requestTimeout: TimeInterval?,
                completionQueue: DispatchQueue,
                completionHandler: ((RoktDownloadResult) -> Void)?
            ) {}
        }

        let httpClient = RecordingOffersHTTPClient()
        let roktInternalImplementation = RoktInternalImplementation()
        roktInternalImplementation.roktTagId = "test-tag"
        roktInternalImplementation.isInitialized = true
        roktInternalImplementation.initFeatureFlags = TxnFeatureFlags(
            flags: ["mobile-sdk-use-sdk-cache": .bool(true)]
        ).toInitFeatureFlags()
        roktInternalImplementation.diagnosticsSender = { _, _, _ in }
        roktInternalImplementation.makeOffersServiceOverride = { tagId in
            OffersService(
                environment: .Prod,
                accountId: tagId,
                sdkVersion: "1.0.0",
                layoutSchemaVersion: "2.8",
                sessionManager: TxnSessionManager(),
                httpClient: httpClient,
                maxRetries: 0,
                sleep: { _ in },
                triggeredEvents: { [] },
                captureEvents: { _ in }
            )
        }

        let cachedExp = expectation(description: "cached response written")
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: "checkout",
            attributes: [:],
            experienceResponse: "{}",
            generation: UUID().uuidString,
            success: { cachedExp.fulfill() }
        )
        wait(for: [cachedExp], timeout: 2)

        let cacheConfig = RoktConfig.Builder()
            .cacheConfig(RoktConfig.CacheConfig(cacheDuration: 3600, cacheAttributes: nil))
            .build()

        let firstDone = expectation(description: "first execute hits cache")
        roktInternalImplementation.execute(
            viewName: "checkout",
            attributes: [:],
            config: cacheConfig
        ) { event in
            if event is RoktEvent.PlacementFailure {
                firstDone.fulfill()
            }
        }
        wait(for: [firstDone], timeout: 5)
        XCTAssertEqual(
            httpClient.recordedParameters.count,
            0,
            "cached response should satisfy first execute without network request"
        )

        roktInternalImplementation.setPrivacyControl(
            RoktPrivacyControl(
                noFunctional: false,
                noTargeting: true,
                doNotShareOrSell: false
            )
        )

        let secondDone = expectation(description: "second execute bypasses cache after privacy control change")
        roktInternalImplementation.execute(
            viewName: "checkout",
            attributes: [:],
            config: cacheConfig
        ) { event in
            if event is RoktEvent.PlacementFailure {
                secondDone.fulfill()
            }
        }
        wait(for: [secondDone], timeout: 5)

        XCTAssertEqual(httpClient.recordedParameters.count, 1)
        let secondPrivacy = try XCTUnwrap(httpClient.recordedParameters[0]["privacy_control"] as? [String: Any])
        XCTAssertEqual(secondPrivacy["no_functional"] as? Bool, false)
        XCTAssertEqual(secondPrivacy["no_targeting"] as? Bool, true)
        XCTAssertEqual(secondPrivacy["do_not_share_or_sell"] as? Bool, false)

        // Simulate cold launch with the same opt-out flags: the persisted signature matches,
        // so the cached entry stored under those opt-out flags is retained.
        let cachedOptOutExp = expectation(description: "opt-out cached response written")
        ExperienceCacheManager.cacheExperienceResponse(
            viewName: "checkout",
            attributes: ["noTargeting": "true"],
            experienceResponse: "{}",
            generation: UUID().uuidString,
            success: { cachedOptOutExp.fulfill() }
        )
        wait(for: [cachedOptOutExp], timeout: 2)

        let relaunchedImpl = RoktInternalImplementation()
        relaunchedImpl.roktTagId = "test-tag"
        relaunchedImpl.isInitialized = true
        relaunchedImpl.initFeatureFlags = TxnFeatureFlags(
            flags: ["mobile-sdk-use-sdk-cache": .bool(true)]
        ).toInitFeatureFlags()
        relaunchedImpl.diagnosticsSender = { _, _, _ in }
        relaunchedImpl.makeOffersServiceOverride = roktInternalImplementation.makeOffersServiceOverride
        relaunchedImpl.setPrivacyControl(
            RoktPrivacyControl(
                noFunctional: false,
                noTargeting: true,
                doNotShareOrSell: false
            )
        )

        let thirdDone = expectation(description: "third execute hits opt-out cache after cold launch")
        relaunchedImpl.execute(
            viewName: "checkout",
            attributes: [:],
            config: cacheConfig
        ) { event in
            if event is RoktEvent.PlacementFailure {
                thirdDone.fulfill()
            }
        }
        wait(for: [thirdDone], timeout: 5)
        XCTAssertEqual(httpClient.recordedParameters.count, 1)
    }
}
