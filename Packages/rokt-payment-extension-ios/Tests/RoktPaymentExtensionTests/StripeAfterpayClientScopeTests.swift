import RoktContracts
import StripePayments
import XCTest
@testable import RoktPaymentExtension

/// Test double for the Stripe payment handler: records what the Afterpay flow hands it and
/// replays a scripted status, immediately or when the test releases it.
private final class SpyConfirmer: AfterpayPaymentConfirming {
    var apiClient: STPAPIClient
    var scriptedStatus: STPPaymentHandlerActionStatus = .succeeded
    var completesImmediately = true

    private(set) var confirmCallCount = 0
    private(set) var confirmedParams: STPPaymentIntentParams?
    private(set) var clientUsedForConfirmation: STPAPIClient?
    private var pendingCompletion: STPPaymentHandlerActionPaymentIntentCompletionBlock?

    init(apiClient: STPAPIClient) {
        self.apiClient = apiClient
    }

    func confirmPaymentIntent(
        params: STPPaymentIntentParams,
        authenticationContext: STPAuthenticationContext,
        completion: @escaping STPPaymentHandlerActionPaymentIntentCompletionBlock
    ) {
        confirmCallCount += 1
        confirmedParams = params
        clientUsedForConfirmation = apiClient
        if completesImmediately {
            completion(scriptedStatus, nil, nil)
        } else {
            pendingCompletion = completion
        }
    }

    func finish() {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(scriptedStatus, nil, nil)
    }
}

private extension PaymentSheetResult {
    var succeededTransactionId: String? {
        if case .succeeded(let transactionId) = self { return transactionId }
        return nil
    }

    var isCanceledResult: Bool {
        if case .canceled = self { return true }
        return false
    }
}

/// Verifies that the Afterpay flow confirms through the extension-owned `STPAPIClient` and
/// leaves the host app's process-global Stripe configuration untouched.
final class StripeAfterpayClientScopeTests: XCTestCase {

    private static let hostPublishableKey = "pk_test_host"
    private static let hostStripeAccount = "acct_1HostAccount"
    private static let extensionPublishableKey = "pk_test_dummy"
    private static let preparationAccount = "acct_1TestAccount"
    private static let clientSecret = "pi_1Test_secret_abc"
    private static let returnURL = "testapp://rokt-payment-return"
    private static let terminalStatuses: [STPPaymentHandlerActionStatus] = [.succeeded, .canceled, .failed]

    private var savedSharedPublishableKey: String?
    private var savedSharedStripeAccount: String?

    private var extensionClient: STPAPIClient!
    private var hostHandlerClient: STPAPIClient!
    private var spy: SpyConfirmer!
    private var manager: StripeAfterpayManager!

    override func setUp() {
        super.setUp()
        savedSharedPublishableKey = STPAPIClient.shared.publishableKey
        savedSharedStripeAccount = STPAPIClient.shared.stripeAccount
        STPAPIClient.shared.publishableKey = Self.hostPublishableKey
        STPAPIClient.shared.stripeAccount = Self.hostStripeAccount

        extensionClient = STPAPIClient(publishableKey: Self.extensionPublishableKey)
        hostHandlerClient = STPAPIClient(publishableKey: Self.hostPublishableKey)
        let spy = SpyConfirmer(apiClient: hostHandlerClient)
        self.spy = spy
        manager = StripeAfterpayManager(
            apiClient: extensionClient,
            returnURL: Self.returnURL,
            makeConfirmer: { spy }
        )
    }

    override func tearDown() {
        STPAPIClient.shared.publishableKey = savedSharedPublishableKey
        STPAPIClient.shared.stripeAccount = savedSharedStripeAccount
        manager = nil
        spy = nil
        hostHandlerClient = nil
        extensionClient = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeItem() -> PaymentItem {
        PaymentItem(id: "item-1", name: "Widget", amount: 10.00, currency: "USD")
    }

    private func makeContext() -> PaymentContext {
        PaymentContext(
            billingAddress: ContactAddress(
                name: "Jane Smith",
                email: "jane@example.com",
                addressLine1: "123 Main St",
                addressLine2: nil,
                city: "New York",
                state: "NY",
                postalCode: "10001",
                country: "US"
            ),
            shippingAddress: nil,
            returnURL: Self.returnURL
        )
    }

    private func makePreparation(
        merchantId: String = StripeAfterpayClientScopeTests.preparationAccount
    ) -> PaymentPreparation {
        PaymentPreparation(
            clientSecret: Self.clientSecret,
            merchantId: merchantId,
            totalAmount: 10,
            shippingCost: 0,
            tax: 0,
            approvalUrl: nil
        )
    }

    /// Drives a full Afterpay flow whose preparation step yields `preparation` (or `error`)
    /// and returns the terminal result.
    @discardableResult
    private func runFlow(
        preparation: PaymentPreparation?,
        error: Error? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> PaymentSheetResult? {
        let expect = expectation(description: "completion")
        var received: PaymentSheetResult?

        manager.presentPayment(
            item: makeItem(),
            context: makeContext(),
            from: UIViewController(),
            preparePayment: { _, done in done(preparation, error) }
        ) { result in
            received = result
            expect.fulfill()
        }

        wait(for: [expect], timeout: 1)
        XCTAssertNotNil(received, "flow never completed", file: file, line: line)
        return received
    }

    private func assertSharedClientUntouched(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(STPAPIClient.shared.publishableKey, Self.hostPublishableKey, file: file, line: line)
        XCTAssertEqual(STPAPIClient.shared.stripeAccount, Self.hostStripeAccount, file: file, line: line)
    }

    private struct PrepError: LocalizedError {
        var errorDescription: String? { "Backend error" }
    }

    // MARK: - Shared client is never mutated

    func testAfterpayLeavesSharedStripeClientUnchangedOnEveryOutcome() {
        for status in Self.terminalStatuses {
            spy.scriptedStatus = status
            runFlow(preparation: makePreparation())
            assertSharedClientUntouched()
        }

        let result = runFlow(preparation: nil, error: PrepError())
        XCTAssertEqual(result?.outcome, .failed)
        assertSharedClientUntouched()
    }

    // MARK: - Confirmation runs on the extension-owned client

    func testAfterpayConfirmsThroughExtensionOwnedClient() {
        runFlow(preparation: makePreparation())

        XCTAssertEqual(spy.confirmCallCount, 1)
        let used = spy.clientUsedForConfirmation
        XCTAssertTrue(used === extensionClient)
        XCTAssertFalse(used === STPAPIClient.shared)
        XCTAssertEqual(used?.publishableKey, Self.extensionPublishableKey)
        XCTAssertEqual(used?.stripeAccount, Self.preparationAccount)
    }

    func testAfterpayConfirmParamsAndOutcomeMappingAreUnchanged() {
        spy.scriptedStatus = .succeeded
        let succeeded = runFlow(preparation: makePreparation())
        XCTAssertEqual(succeeded?.succeededTransactionId, "pi_1Test")

        let params = spy.confirmedParams
        XCTAssertEqual(params?.clientSecret, Self.clientSecret)
        XCTAssertEqual(params?.returnURL, Self.returnURL)
        XCTAssertNotNil(params?.paymentMethodParams?.afterpayClearpay)
        XCTAssertEqual(params?.paymentMethodParams?.billingDetails?.name, "Jane Smith")

        spy.scriptedStatus = .canceled
        XCTAssertEqual(runFlow(preparation: makePreparation())?.isCanceledResult, true)

        spy.scriptedStatus = .failed
        let failed = runFlow(preparation: makePreparation())
        XCTAssertEqual(failed?.outcome, .failed)
        XCTAssertEqual(failed?.errorMessage, "Afterpay payment failed")
    }

    // MARK: - Borrowed handler is handed back with the host's client

    func testAfterpayHandsHandlerBackAndReleasesItOnEveryOutcome() {
        for status in Self.terminalStatuses {
            spy.scriptedStatus = status
            runFlow(preparation: makePreparation())

            XCTAssertTrue(spy.apiClient === hostHandlerClient, "handler client not restored after \(status)")
            XCTAssertNil(hostHandlerClient.stripeAccount)
            XCTAssertEqual(hostHandlerClient.publishableKey, Self.hostPublishableKey)
            XCTAssertNil(manager.activeConfirmer, "confirmer still retained after \(status)")
        }
    }

    func testAfterpayUsesExtensionClientOnlyWhileConfirming() {
        spy.completesImmediately = false
        let expect = expectation(description: "completion")

        manager.presentPayment(
            item: makeItem(),
            context: makeContext(),
            from: UIViewController(),
            preparePayment: { _, done in done(self.makePreparation(), nil) }
        ) { _ in expect.fulfill() }

        let confirmStarted = expectation(description: "confirm dispatched")
        DispatchQueue.main.async { confirmStarted.fulfill() }
        wait(for: [confirmStarted], timeout: 1)

        XCTAssertEqual(spy.confirmCallCount, 1)
        XCTAssertTrue(spy.apiClient === extensionClient, "in-flight confirmation should use the extension client")
        XCTAssertTrue(manager.activeConfirmer === spy, "handler must stay retained across the redirect")
        assertSharedClientUntouched()

        spy.finish()
        wait(for: [expect], timeout: 1)

        XCTAssertTrue(spy.apiClient === hostHandlerClient)
        XCTAssertNil(manager.activeConfirmer)
    }

    func testAfterpayPreparationFailureTouchesNoClient() {
        let result = runFlow(preparation: nil, error: PrepError())

        XCTAssertEqual(result?.outcome, .failed)
        XCTAssertEqual(result?.errorMessage, "Backend error")
        XCTAssertEqual(spy.confirmCallCount, 0)
        XCTAssertNil(manager.activeConfirmer)
        XCTAssertNil(extensionClient.stripeAccount)
        XCTAssertTrue(spy.apiClient === hostHandlerClient)
        assertSharedClientUntouched()
    }

    // MARK: - Connected-account id shape

    func testAfterpayRejectsMalformedMerchantAccountId() {
        let malformed = ["merchant.com.test", "acct_", "", "acct_x;drop", String(repeating: "a", count: 200)]

        for merchantId in malformed {
            let result = runFlow(preparation: makePreparation(merchantId: merchantId))

            XCTAssertEqual(result?.outcome, .failed, "expected \(merchantId.debugDescription) to fail")
            XCTAssertTrue(result?.errorMessage?.contains("merchant account id") ?? false)
            XCTAssertEqual(spy.confirmCallCount, 0)
            XCTAssertNil(manager.activeConfirmer)
            XCTAssertNil(extensionClient.stripeAccount, "client must not be scoped to a rejected id")
            XCTAssertTrue(spy.apiClient === hostHandlerClient)
            assertSharedClientUntouched()
        }
    }

    func testAfterpayAcceptsWellFormedMerchantAccountId() {
        let result = runFlow(preparation: makePreparation(merchantId: "acct_mock_123"))

        XCTAssertNotNil(result?.succeededTransactionId)
        XCTAssertEqual(spy.confirmCallCount, 1)
        XCTAssertEqual(spy.clientUsedForConfirmation?.stripeAccount, "acct_mock_123")
    }
}
