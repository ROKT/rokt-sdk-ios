import XCTest
@testable import Rokt_Widget

// MARK: - Test Keys (mirroring private keys in StripeAttributeEnricher)

private let stripeApplePayContextClassName = "STPApplePayContext"
private let stripeInitSelector = "initWithPaymentRequest:delegate:"

private let BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY = "stripeApplePayAvailable"

// MARK: Mock StripeCapabilityChecker

private class MockStripeCapabilityChecker: StripeCapabilityChecker {
  var isStripeApplePayAvailableResult: Bool = false
  var didCallIsStripeApplePayAvailable = false

  func isStripeApplePayAvailable() -> Bool {
    didCallIsStripeApplePayAvailable = true
    return isStripeApplePayAvailableResult
  }
}

// MARK: - Test Class

class TestStripeAttributeEnricher: XCTestCase {

  private var mockCapabilityChecker: MockStripeCapabilityChecker!
  private var sut: StripeAttributeEnricher!
  private var mockConfig: RoktConfig!

  override func setUp() {
    super.setUp()
    mockCapabilityChecker = MockStripeCapabilityChecker()
    sut = StripeAttributeEnricher(capabilityChecker: mockCapabilityChecker)
    mockConfig = RoktConfig.Builder().build()
  }

  override func tearDown() {
    mockCapabilityChecker = nil
    sut = nil
    mockConfig = nil
    super.tearDown()
  }

  // MARK: - Test Cases

  func testEnrich_withStripeApplePayAvailable_shouldReturnTrue() {
    // Given
    mockCapabilityChecker.isStripeApplePayAvailableResult = true

    // When
    let attributes = sut.enrich(config: mockConfig)

    // Then
    XCTAssertTrue(
      mockCapabilityChecker.didCallIsStripeApplePayAvailable,
      "isStripeApplePayAvailable should have been called."
    )
    XCTAssertEqual(attributes.count, 1, "Should contain one key.")
    XCTAssertEqual(
      attributes[BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY], "true",
      "BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY should be true."
    )
  }

  func testEnrich_withStripeApplePayUnavailable_shouldReturnFalse() {
    // Given
    mockCapabilityChecker.isStripeApplePayAvailableResult = false

    // When
    let attributes = sut.enrich(config: mockConfig)

    // Then
    XCTAssertTrue(
      mockCapabilityChecker.didCallIsStripeApplePayAvailable,
      "isStripeApplePayAvailable should have been called."
    )
    XCTAssertEqual(attributes.count, 1, "Should contain one key.")
    XCTAssertEqual(
      attributes[BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY], "false",
      "BE_IS_STRIPE_APPLE_PAY_AVAILABLE_KEY should be false."
    )
  }
}
