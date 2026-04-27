import RoktContracts
import UIKit
import XCTest
@testable import Rokt_Widget

final class TestShoppableAds: XCTestCase {

    private var mockImplementation: MockRoktInternalImplementation!
    private var originalImplementation: RoktInternalImplementation!

    override func setUp() {
        super.setUp()
        originalImplementation = Rokt.shared.roktImplementation
        mockImplementation = MockRoktInternalImplementation()
        mockImplementation.isInitialized = true
        Rokt.shared.roktImplementation = mockImplementation
    }

    override func tearDown() {
        Rokt.shared.roktImplementation = originalImplementation
        mockImplementation = nil
        originalImplementation = nil
        super.tearDown()
    }

    // MARK: - Feature-flag gate

    func test_selectShoppableAds_doesNotCallExecute_whenPostPurchaseDisabled() {
        mockImplementation.initFeatureFlags = Self.featureFlags(
            postPurchase: false,
            minimumSchema: true
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        Rokt.selectShoppableAds(identifier: "test", attributes: ["email": "test@example.com"])

        XCTAssertEqual(mockImplementation.executeCallCount, 0)
    }

    func test_selectShoppableAds_doesNotCallExecute_whenSchemaDisabled() {
        mockImplementation.initFeatureFlags = Self.featureFlags(
            postPurchase: true,
            minimumSchema: false
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        Rokt.selectShoppableAds(identifier: "test", attributes: ["email": "test@example.com"])

        XCTAssertEqual(mockImplementation.executeCallCount, 0)
    }

    func test_selectShoppableAds_doesNotCallExecute_whenFlagsAbsent() {
        mockImplementation.initFeatureFlags = InitFeatureFlags(
            roktTrackingStatus: true,
            featureFlags: [:]
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        Rokt.selectShoppableAds(identifier: "test", attributes: ["email": "test@example.com"])

        XCTAssertEqual(mockImplementation.executeCallCount, 0)
    }

    // MARK: - Not-initialized fall-through

    func test_selectShoppableAds_fallsThroughToExecute_whenNotInitialized() {
        mockImplementation.isInitialized = false
        mockImplementation.initFeatureFlags = InitFeatureFlags(
            roktTrackingStatus: true,
            featureFlags: [:]
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        Rokt.selectShoppableAds(identifier: "test", attributes: ["email": "test@example.com"])

        XCTAssertEqual(mockImplementation.executeCallCount, 1,
                       "When SDK is not initialized, gate must not short-circuit; execute() handles the NOT_INITIALIZED path.")
    }

    // MARK: - PaymentExtension gate

    func test_selectShoppableAds_doesNotCallExecute_whenNoPaymentExtensionRegistered() {
        mockImplementation.initFeatureFlags = Self.featureFlags(
            postPurchase: true,
            minimumSchema: true
        )

        Rokt.selectShoppableAds(identifier: "test", attributes: ["email": "test@example.com"])

        XCTAssertEqual(mockImplementation.executeCallCount, 0)
    }

    // MARK: - Happy path

    func test_selectShoppableAds_callsExecute_whenBothFlagsOnAndExtensionRegistered() {
        mockImplementation.initFeatureFlags = Self.featureFlags(
            postPurchase: true,
            minimumSchema: true
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        Rokt.selectShoppableAds(identifier: "test", attributes: ["email": "test@example.com"])

        XCTAssertEqual(mockImplementation.executeCallCount, 1)
        XCTAssertEqual(mockImplementation.lastViewName, "test")
        XCTAssertEqual(mockImplementation.lastAttributes, ["email": "test@example.com", "adsExperience": "shoppable"])
    }

    func test_selectShoppableAds_doesNotOverwriteAdsExperience_whenAlreadySet() {
        mockImplementation.initFeatureFlags = Self.featureFlags(
            postPurchase: true,
            minimumSchema: true
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        Rokt.selectShoppableAds(identifier: "test", attributes: ["adsExperience": "custom"])

        XCTAssertEqual(mockImplementation.lastAttributes["adsExperience"], "custom")
    }

    func test_selectShoppableAds_emitsPlacementFailure_whenGateOff() {
        mockImplementation.initFeatureFlags = Self.featureFlags(
            postPurchase: false,
            minimumSchema: true
        )
        mockImplementation.registerPaymentExtension(StubPaymentExtension(), config: [:])

        var receivedEvents: [RoktEvent] = []
        Rokt.selectShoppableAds(
            identifier: "test",
            attributes: [:],
            onEvent: { receivedEvents.append($0) }
        )

        XCTAssertTrue(receivedEvents.contains { $0 is RoktEvent.PlacementFailure })
    }

    // MARK: - selectPlacements with shoppable attribute

    func test_selectPlacements_withShoppableAttribute_emitsPlacementFailure_whenFeatureFlagsDisabled() {
        let impl = RoktInternalImplementation()
        impl.isInitialized = true
        impl.initFeatureFlags = Self.featureFlags(postPurchase: false, minimumSchema: true)
        impl.registerPaymentExtension(StubPaymentExtension(), config: [:])
        Rokt.shared.roktImplementation = impl

        var receivedEvents: [RoktEvent] = []
        Rokt.selectPlacements(
            identifier: "test",
            attributes: ["adsExperience": "shoppable"],
            onEvent: { receivedEvents.append($0) }
        )

        XCTAssertTrue(receivedEvents.contains { $0 is RoktEvent.PlacementFailure })
    }

    func test_selectPlacements_withShoppableAttribute_emitsPlacementFailure_whenNoPaymentExtension() {
        let impl = RoktInternalImplementation()
        impl.isInitialized = true
        impl.initFeatureFlags = Self.featureFlags(postPurchase: true, minimumSchema: true)
        // no payment extension registered
        Rokt.shared.roktImplementation = impl

        var receivedEvents: [RoktEvent] = []
        Rokt.selectPlacements(
            identifier: "test",
            attributes: ["adsExperience": "shoppable"],
            onEvent: { receivedEvents.append($0) }
        )

        XCTAssertTrue(receivedEvents.contains { $0 is RoktEvent.PlacementFailure })
    }

    func test_selectPlacements_withoutShoppableAttribute_doesNotApplyShoppableGate() {
        // Feature flags and payment extension are both invalid for shoppable,
        // but the gate must NOT apply for non-shoppable attributes.
        mockImplementation.initFeatureFlags = Self.featureFlags(postPurchase: false, minimumSchema: false)
        // no payment extension registered

        Rokt.selectPlacements(
            identifier: "test",
            attributes: ["email": "test@example.com"]
        )

        XCTAssertEqual(mockImplementation.executeCallCount, 1)
    }

    // MARK: - Helpers

    private static func featureFlags(
        postPurchase: Bool,
        minimumSchema: Bool
    ) -> InitFeatureFlags {
        InitFeatureFlags(
            roktTrackingStatus: true,
            featureFlags: [
                "is-post-purchase-enabled": FeatureFlagItem(match: postPurchase),
                "minimum-post-purchase-schema": FeatureFlagItem(match: minimumSchema)
            ]
        )
    }
}

// MARK: - Test doubles

final class MockRoktInternalImplementation: RoktInternalImplementation {
    private(set) var executeCallCount = 0
    private(set) var lastViewName: String?
    private(set) var lastAttributes: [String: String] = [:]

    override func execute(
        viewName: String?,
        attributes: [String: String],
        placements: [String: RoktEmbeddedView]?,
        config: RoktConfig?,
        placementOptions: RoktPlacementOptions?,
        onRoktEvent: ((RoktEvent) -> Void)?
    ) {
        executeCallCount += 1
        lastViewName = viewName
        lastAttributes = attributes
    }
}

private final class StubPaymentExtension: PaymentExtension {
    var id: String { "stub" }
    var extensionDescription: String { "Stub Payment Extension" }
    var supportedMethods: [String] { [] }

    func onRegister(parameters: [String: String]) -> Bool { true }
    func onUnregister() {}

    func presentPaymentSheet(
        item: PaymentItem,
        method: PaymentMethodType,
        context: PaymentContext,
        from viewController: UIViewController,
        preparePayment: @escaping (
            _ address: ContactAddress,
            _ completion: @escaping (PaymentPreparation?, Error?) -> Void
        ) -> Void,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {}
}
