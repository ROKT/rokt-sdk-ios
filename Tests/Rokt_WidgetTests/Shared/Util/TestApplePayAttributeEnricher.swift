import XCTest
@testable import Rokt_Widget

// MARK: - Test Keys (mirroring private keys in ApplePayAttributeEnricher)

private let BE_IS_APPLE_PAY_CAPABLE_KEY = "applePayCapabilities"
private let BE_IS_NEW_TO_APPLE_PAY_KEY = "newToApplePay"

// MARK: - Mock PassKitCapabilityChecker

private class MockPassKitCapabilityChecker: PassKitCapabilityChecker {
    var canDeviceMakePaymentsResult: Bool = false
    var canDeviceMakePaymentsUsingNetworksResult: Bool = false
    var didCallCanDeviceMakePayments = false
    var didCallCanDeviceMakePaymentsUsingNetworks = false
    var receivedNetworks: NSArray? // To verify networks passed

    func canDeviceMakePayments() -> Bool {
        didCallCanDeviceMakePayments = true
        return canDeviceMakePaymentsResult
    }

    func canDeviceMakePayments(usingNetworks networks: NSArray) -> Bool {
        didCallCanDeviceMakePaymentsUsingNetworks = true
        receivedNetworks = networks
        return canDeviceMakePaymentsUsingNetworksResult
    }
}

// MARK: - Test Class

class TestApplePayAttributeEnricher: XCTestCase {

    private var mockCapabilityChecker: MockPassKitCapabilityChecker!
    private var backgroundQueue: DispatchQueue!
    private var sut: ApplePayAttributeEnricher!
    private var mockConfig: RoktConfig!

    override func setUp() {
        super.setUp()
        mockCapabilityChecker = MockPassKitCapabilityChecker()
        backgroundQueue = DispatchQueue(label: "test.applePayAttributeEnricher")
        sut = ApplePayAttributeEnricher(capabilityChecker: mockCapabilityChecker, backgroundQueue: backgroundQueue)
        mockConfig = RoktConfig.Builder().build()
    }

    override func tearDown() {
        mockCapabilityChecker = nil
        backgroundQueue = nil
        sut = nil
        mockConfig = nil
        super.tearDown()
    }

    /// Blocks until any capability-check work already queued on `backgroundQueue` has finished.
    private func waitForCacheWarmup() {
        backgroundQueue.sync {}
    }

    // MARK: - Test Cases

    func testEnrich_beforeWarmUpResolves_returnsNoAttributes() {
        // Given
        mockCapabilityChecker.canDeviceMakePaymentsResult = true
        backgroundQueue.suspend()
        sut.warmUp()

        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then: nothing has resolved yet, so enrich() must not guess a value.
        XCTAssertTrue(attributes.isEmpty)

        backgroundQueue.resume()
    }

    func testEnrich_whenWarmUpNeverCalled_returnsNoAttributesAndNeverTouchesChecker() {
        // When
        let attributes = sut.enrich(config: mockConfig)

        // Then: enrich() is a pure cache read; it never triggers the checker itself.
        XCTAssertTrue(attributes.isEmpty)
        XCTAssertFalse(mockCapabilityChecker.didCallCanDeviceMakePayments)
    }

    func testEnrich_whenSDKNotCapable_returnsNotCapableAndNotNewToApplePay() {
        // Given
        mockCapabilityChecker.canDeviceMakePaymentsResult = false

        // When
        sut.warmUp()
        waitForCacheWarmup()
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertTrue(mockCapabilityChecker.didCallCanDeviceMakePayments, "canDeviceMakePayments should have been called.")
        XCTAssertFalse(
            mockCapabilityChecker.didCallCanDeviceMakePaymentsUsingNetworks,
            "canDeviceMakePaymentsUsingNetworks should not have been called if SDK is not capable."
        )

        XCTAssertEqual(attributes.count, 2, "Should contain two keys.")
        XCTAssertEqual(attributes[BE_IS_APPLE_PAY_CAPABLE_KEY], "false", "BE_IS_APPLE_PAY_CAPABLE_KEY should be false.")
        XCTAssertEqual(
            attributes[BE_IS_NEW_TO_APPLE_PAY_KEY],
            "false",
            "BE_IS_NEW_TO_APPLE_PAY_KEY should be false when not capable."
        )
    }

    func testEnrich_whenSDKCapableAndNoCardsSetup_returnsCapableAndNewToApplePay() {
        // Given
        mockCapabilityChecker.canDeviceMakePaymentsResult = true
        mockCapabilityChecker.canDeviceMakePaymentsUsingNetworksResult = false // No specific cards setup

        // When
        sut.warmUp()
        waitForCacheWarmup()
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertTrue(mockCapabilityChecker.didCallCanDeviceMakePayments, "canDeviceMakePayments should have been called.")
        XCTAssertTrue(
            mockCapabilityChecker.didCallCanDeviceMakePaymentsUsingNetworks,
            "canDeviceMakePaymentsUsingNetworks should have been called when SDK is capable."
        )

        XCTAssertEqual(attributes.count, 2, "Should contain two keys.")
        XCTAssertEqual(attributes[BE_IS_APPLE_PAY_CAPABLE_KEY], "true", "BE_IS_APPLE_PAY_CAPABLE_KEY should be true.")
        XCTAssertEqual(
            attributes[BE_IS_NEW_TO_APPLE_PAY_KEY],
            "true",
            "BE_IS_NEW_TO_APPLE_PAY_KEY should be true when no cards are setup."
        )
        XCTAssertNotNil(mockCapabilityChecker.receivedNetworks, "Should have passed networks to the capability checker.")
    }

    func testEnrich_whenSDKCapableAndCardsAreSetup_returnsCapableAndNotNewToApplePay() {
        // Given
        mockCapabilityChecker.canDeviceMakePaymentsResult = true
        mockCapabilityChecker.canDeviceMakePaymentsUsingNetworksResult = true // Specific cards ARE setup

        // When
        sut.warmUp()
        waitForCacheWarmup()
        let attributes = sut.enrich(config: mockConfig)

        // Then
        XCTAssertTrue(mockCapabilityChecker.didCallCanDeviceMakePayments, "canDeviceMakePayments should have been called.")
        XCTAssertTrue(
            mockCapabilityChecker.didCallCanDeviceMakePaymentsUsingNetworks,
            "canDeviceMakePaymentsUsingNetworks should have been called when SDK is capable."
        )

        XCTAssertEqual(attributes.count, 2, "Should contain two keys.")
        XCTAssertEqual(attributes[BE_IS_APPLE_PAY_CAPABLE_KEY], "true", "BE_IS_APPLE_PAY_CAPABLE_KEY should be true.")
        XCTAssertEqual(
            attributes[BE_IS_NEW_TO_APPLE_PAY_KEY],
            "false",
            "BE_IS_NEW_TO_APPLE_PAY_KEY should be false when cards are setup."
        )
    }

    func testEnrich_calledRepeatedly_onlyQueriesCheckerOnce() {
        // Given
        mockCapabilityChecker.canDeviceMakePaymentsResult = true
        mockCapabilityChecker.canDeviceMakePaymentsUsingNetworksResult = true

        // When
        sut.warmUp()
        waitForCacheWarmup()
        mockCapabilityChecker.didCallCanDeviceMakePayments = false
        mockCapabilityChecker.didCallCanDeviceMakePaymentsUsingNetworks = false
        _ = sut.enrich(config: mockConfig)
        _ = sut.enrich(config: mockConfig)

        // Then: cached results are served without re-querying PassKit.
        XCTAssertFalse(mockCapabilityChecker.didCallCanDeviceMakePayments)
        XCTAssertFalse(mockCapabilityChecker.didCallCanDeviceMakePaymentsUsingNetworks)
    }
}
