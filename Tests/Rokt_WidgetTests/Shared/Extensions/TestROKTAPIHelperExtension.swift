import RoktContracts
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

    func test_getPrivacyControlPayload_withSetOncePrivacyControlOnly_returnsPrivacyControlPayload() {
        let attributes = ["email": "user@example.com"]
        let privacyControl = RoktPrivacyControl(
            noFunctional: true,
            noTargeting: false,
            doNotShareOrSell: true
        )

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(
            attributes: attributes,
            privacyControl: privacyControl
        )

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: true,
            isNoTargeting: false,
            isDoNotShareOrSell: true,
            isGPCEnabled: nil
        )
    }

    func test_getPrivacyControlPayload_optOutWins_setOnceTrueCannotBeUndoneByPerCallFalse() {
        let attributes = [
            RoktAPIHelper.noFunctionalKey: "false",
            RoktAPIHelper.noTargetingKey: "FALSE",
            RoktAPIHelper.doNotShareOrSellKey: "false",
            RoktAPIHelper.gpcEnabledKey: "true"
        ]
        let privacyControl = RoktPrivacyControl(
            noFunctional: true,
            noTargeting: true,
            doNotShareOrSell: true
        )

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(
            attributes: attributes,
            privacyControl: privacyControl
        )

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: true,
            isNoTargeting: true,
            isDoNotShareOrSell: true,
            isGPCEnabled: true
        )
    }

    func test_getPrivacyControlPayload_setterFalse_perCallTrueAnyCasing_isTrue() {
        let attributes = ["NOTARGETING": "TRUE"]
        let privacyControl = RoktPrivacyControl(noTargeting: false)

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(
            attributes: attributes,
            privacyControl: privacyControl
        )

        XCTAssertEqual(privacyControls[RoktAPIHelper.noTargetingKey], true)
    }

    func test_getPrivacyControlPayload_unsetSetterAndNoPerCall_omitsKey() {
        let attributes = ["email": "user@example.com"]
        let privacyControl = RoktPrivacyControl(noTargeting: true)

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(
            attributes: attributes,
            privacyControl: privacyControl
        )

        XCTAssertEqual(privacyControls, [RoktAPIHelper.noTargetingKey: true])
    }

    func test_getPrivacyControlPayload_setterFalse_noPerCall_sendsFalse() {
        let privacyControl = RoktPrivacyControl(noFunctional: false)

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(
            attributes: [:],
            privacyControl: privacyControl
        )

        XCTAssertEqual(privacyControls, [RoktAPIHelper.noFunctionalKey: false])
    }

    func test_getPrivacyControlPayload_optOutWins_perCallTrueOverridesSetOnceFalse() {
        let attributes = [
            RoktAPIHelper.noFunctionalKey: "true",
            RoktAPIHelper.noTargetingKey: "TRUE",
            RoktAPIHelper.doNotShareOrSellKey: "false"
        ]
        let privacyControl = RoktPrivacyControl(
            noFunctional: false,
            noTargeting: false,
            doNotShareOrSell: false
        )

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(
            attributes: attributes,
            privacyControl: privacyControl
        )

        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: true,
            isNoTargeting: true,
            isDoNotShareOrSell: false,
            isGPCEnabled: nil
        )
    }

    func test_getPrivacyControlPayload_caseInsensitiveKeys_optOutWinsAndStripsAllVariants() {
        let attributes = [
            "NoFunctional": "true",
            "notargeting": "false",
            "noTargeting": "true",
            "DoNotShareOrSell": "TRUE",
            "GPCEnabled": "true",
            "PageInit": "1234567890",
            "email": "user@example.com"
        ]

        let privacyControls = RoktAPIHelper.getPrivacyControlPayload(attributes: attributes)
        assertPrivacyControlValues(
            privacyControls: privacyControls,
            isNoFunctional: true,
            isNoTargeting: true,
            isDoNotShareOrSell: true,
            isGPCEnabled: true
        )
        XCTAssertEqual(RoktAPIHelper.getPageInitData(attributes: attributes), "1234567890")

        let remaining = RoktAPIHelper.removePrivacyControlAttributes(attributes: attributes)
        XCTAssertEqual(remaining, ["email": "user@example.com"])
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
