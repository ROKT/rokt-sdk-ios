import XCTest
@testable import Rokt_Widget
@testable internal import RoktUXHelper

/// Covers `ShippingAttributes.init(from: RoktUXHelper.Address)` branching:
/// `stateCode`/`countryCode` are preferred when populated, falling back to
/// `state`/`country` when empty, and a nil `zip` becomes an empty string.
final class TestShippingAttributesFromAddress: XCTestCase {

    private func makeAddress(
        state: String = "California",
        stateCode: String = "CA",
        country: String = "United States",
        countryCode: String = "US",
        zip: String? = "90210"
    ) -> RoktUXHelper.Address {
        RoktUXHelper.Address(
            name: "Ada Lovelace",
            address1: "123 Mock St",
            address2: "Apt 4B",
            city: "Mock City",
            state: state,
            stateCode: stateCode,
            country: country,
            countryCode: countryCode,
            zip: zip
        )
    }

    func test_prefersStateCodeAndCountryCode_whenPopulated() {
        let attrs = ShippingAttributes(from: makeAddress())

        XCTAssertEqual(attrs.state, "CA")
        XCTAssertEqual(attrs.country, "US")
    }

    func test_fallsBackToState_whenStateCodeEmpty() {
        let attrs = ShippingAttributes(from: makeAddress(stateCode: ""))

        XCTAssertEqual(attrs.state, "California")
    }

    func test_fallsBackToCountry_whenCountryCodeEmpty() {
        let attrs = ShippingAttributes(from: makeAddress(countryCode: ""))

        XCTAssertEqual(attrs.country, "United States")
    }

    func test_postalCodeDefaultsToEmptyString_whenZipNil() {
        let attrs = ShippingAttributes(from: makeAddress(zip: nil))

        XCTAssertEqual(attrs.postalCode, "")
    }

    func test_doesNotEmitNameFields_fromAddress() {
        let attrs = ShippingAttributes(from: makeAddress())

        XCTAssertNil(attrs.firstName)
        XCTAssertNil(attrs.lastName)
        XCTAssertNil(attrs.companyName)
    }
}
