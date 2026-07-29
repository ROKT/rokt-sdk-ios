import XCTest
@testable import Rokt_Widget

final class TestROKTAPIHelperExtension: XCTestCase {
    // MARK: - Get Privacy Control Payload

    func test_getPrivacyControlPayload_attributeIsIncorrectType_returnsEmptyPayload() {
        let attributes = ["test": 123]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        XCTAssertTrue(privacyControls.isEmpty)
    }

    func test_getPrivacyControlPayload_noPrivacyKVPs_returnsEmptyPayload() {
        let attributes = ["email": "user@rokt.com"]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        XCTAssertTrue(privacyControls.isEmpty)
    }

    func test_getPrivacyControlPayload_allKVPsExist_returnsFullPayload() {
        let attributes = [
            RoktAPIHelper.noFunctionalKey: "true",
            RoktAPIHelper.noTargetingKey: "false",
            RoktAPIHelper.doNotShareOrSellKey: "tRue",
            RoktAPIHelper.gpcEnabledKey: "fALse"
        ]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: true,
            isNoTargeting: false,
            isDoNotShareOrSell: true,
            isGPCEnabled: false
        )
    }

    func test_getPrivacyControlPayload_incompleteKVPsExist_returnsPartialPayload() {
        let attributes = [RoktAPIHelper.noTargetingKey: "true"]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: nil,
            isNoTargeting: true,
            isDoNotShareOrSell: nil,
            isGPCEnabled: nil
        )
    }

    func test_getPrivacyControlPayload_withIncorrectValues_returnsEmptyPayload() {
        let attributes = [
            RoktAPIHelper.noFunctionalKey: "hello",
            RoktAPIHelper.noTargetingKey: "world",
            RoktAPIHelper.doNotShareOrSellKey: "foo",
            RoktAPIHelper.gpcEnabledKey: "bar"
        ]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)

        XCTAssertTrue(privacyControls.isEmpty)
    }

    private func assertPrivacyControlValues(
        privacyControls: [String: Bool],
        isNoFunctional: Bool?,
        isNoTargeting: Bool?,
        isDoNotShareOrSell: Bool?,
        isGPCEnabled: Bool?
    ) {
        XCTAssertEqual(privacyControls[RoktAPIHelper.noFunctionalKey], isNoFunctional)
        XCTAssertEqual(privacyControls[RoktAPIHelper.noTargetingKey], isNoTargeting)
        XCTAssertEqual(privacyControls[RoktAPIHelper.doNotShareOrSellKey], isDoNotShareOrSell)
        XCTAssertEqual(privacyControls[RoktAPIHelper.gpcEnabledKey], isGPCEnabled)
    }
}

// MARK: - Remove Privacy KVP

extension TestROKTAPIHelperExtension {
    func test_removeAllPrivacyControlData_removesRelevantData() {
        let attributes = [
            RoktAPIHelper.noFunctionalKey: "true",
            RoktAPIHelper.noTargetingKey: "true",
            RoktAPIHelper.doNotShareOrSellKey: "true",
            RoktAPIHelper.gpcEnabledKey: "false",
            "extraData": "true"
        ]

        let sanitisedPayload = RoktAPIHelper.removePrivacyControlAttributes(attributes: attributes)

        XCTAssertEqual(sanitisedPayload.count, 1)
    }
}
