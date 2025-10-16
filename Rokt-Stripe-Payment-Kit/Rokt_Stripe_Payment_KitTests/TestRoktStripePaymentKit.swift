//
//  TestRoktStripePaymentKit.swift
//
//  Copyright 2020 Rokt Pte Ltd
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import XCTest
import UIKit
@testable import Rokt_Widget

class TestRoktStripePaymentKit: XCTestCase {

    var mockViewController: UIViewController!

    override func setUp() {
        super.setUp()
        mockViewController = UIViewController()
    }

    override func tearDown() {
        mockViewController = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithInvalidKey() {
        let kit = RoktStripePaymentKit()
        XCTAssertNil(kit, "Should return nil with placeholder Stripe key")
    }

    func testInitializationWithApplePayMerchantId() {
        let kit = RoktStripePaymentKit(applePayMerchantId: "merchant.test")
        XCTAssertNil(kit, "Should return nil with invalid Stripe key")
    }

    func testInitializationWithCustomParameters() {
        let kit = RoktStripePaymentKit(
            applePayMerchantId: "merchant.test",
            countryCode: "AU",
            currencyCode: "AUD"
        )
        XCTAssertNil(kit, "Should return nil with invalid Stripe key")
    }
}
