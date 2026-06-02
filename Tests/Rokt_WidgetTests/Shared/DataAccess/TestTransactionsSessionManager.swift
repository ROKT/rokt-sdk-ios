import XCTest
@testable import Rokt_Widget

final class TestTransactionsSessionManager: XCTestCase {

    private var now: Date!
    private var manager: TransactionsSessionManager!

    override func setUp() {
        super.setUp()
        now = Date(timeIntervalSince1970: 1_000_000)
        manager = TransactionsSessionManager(clock: { self.now })
    }

    override func tearDown() {
        now = nil
        manager = nil
        super.tearDown()
    }

    private func token(_ value: String, expiresInSeconds seconds: TimeInterval) -> V2SessionToken {
        let expiryMs = Int64(now.addingTimeInterval(seconds).timeIntervalSince1970 * 1000)
        return V2SessionToken(token: value, expiresAt: expiryMs)
    }

    func test_initialState_hasNoSession() {
        XCTAssertNil(manager.currentSessionId)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }

    func test_update_storesSessionIdAndAuthorizationHeader() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        XCTAssertEqual(manager.currentSessionId, "sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer jwt")
        XCTAssertFalse(manager.isExpired)
    }

    func test_expiredToken_dropsAuthorizationHeader_butRetainsSessionId() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
        XCTAssertEqual(manager.currentSessionId, "sid")
    }

    func test_expiryBoundary_isExpiredAtExactExpiry() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(60)
        XCTAssertTrue(manager.isExpired)
        XCTAssertNil(manager.authorizationHeader)
    }

    func test_tokenOnlyUpdate_keepsSessionId_andRefreshesToken() {
        manager.update(sessionId: "sid", sessionToken: token("old", expiresInSeconds: 10))
        manager.update(sessionToken: token("new", expiresInSeconds: 1800))
        XCTAssertEqual(manager.currentSessionId, "sid")
        XCTAssertEqual(manager.authorizationHeader, "Bearer new")
        XCTAssertFalse(manager.isExpired)
    }

    func test_refresh_extendsExpiryOnAnExpiredSession() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 60))
        now = now.addingTimeInterval(61)
        XCTAssertTrue(manager.isExpired)

        manager.update(sessionToken: token("jwt2", expiresInSeconds: 1800))
        XCTAssertFalse(manager.isExpired)
        XCTAssertEqual(manager.authorizationHeader, "Bearer jwt2")
    }

    func test_clear_resetsAllState() {
        manager.update(sessionId: "sid", sessionToken: token("jwt", expiresInSeconds: 1800))
        manager.clear()
        XCTAssertNil(manager.currentSessionId)
        XCTAssertNil(manager.authorizationHeader)
        XCTAssertTrue(manager.isExpired)
    }
}
