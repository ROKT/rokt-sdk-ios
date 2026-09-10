import RoktContracts
import StripePayments
import XCTest
@testable import RoktPaymentExtension

/// Drives a real Afterpay confirmation through Stripe's shared `STPPaymentHandler` and checks that
/// the host app's shared `STPAPIClient` is left exactly as it was.
///
/// The extension is registered with a fake publishable key and the preparation returns a well-formed
/// but fake client secret. Stripe's handler sends one real HTTPS request to Stripe's API from the test
/// runner; Stripe rejects the fake key (with no network, the request fails in the network layer
/// instead), so no real payment is involved and the wait for the outcome is bounded at 30 seconds.
/// A malformed secret is deliberately not used: in debug builds Stripe's handler stops on an
/// assertion for that before it reports the failure.
final class StripeAfterpaySharedClientTests: XCTestCase {

    private static let hostPublishableKey = "pk_test_host"
    private static let hostStripeAccount = "acct_1HostAccount"
    private static let extensionPublishableKey = "pk_test_dummy"
    private static let preparationAccount = "acct_1TestAccount"

    private var savedSharedPublishableKey: String?
    private var savedSharedStripeAccount: String?
    private var ext: RoktPaymentExtension!

    override func setUp() {
        super.setUp()
        savedSharedPublishableKey = STPAPIClient.shared.publishableKey
        savedSharedStripeAccount = STPAPIClient.shared.stripeAccount
        STPAPIClient.shared.publishableKey = Self.hostPublishableKey
        STPAPIClient.shared.stripeAccount = Self.hostStripeAccount

        ext = RoktPaymentExtension(urlScheme: "testapp", bundle: makeBundle(withSchemes: ["testapp"]))!
        ext.onRegister(parameters: ["stripeKey": Self.extensionPublishableKey])
    }

    override func tearDown() {
        STPPaymentHandler.shared().apiClient = STPAPIClient.shared
        STPAPIClient.shared.publishableKey = savedSharedPublishableKey
        STPAPIClient.shared.stripeAccount = savedSharedStripeAccount
        ext = nil
        super.tearDown()
    }

    func testAfterpayConfirmationLeavesTheHostsSharedStripeClientUnchanged() {
        XCTAssertTrue(STPPaymentHandler.shared().apiClient === STPAPIClient.shared, "precondition")

        let item = PaymentItem(id: "item-1", name: "Widget", amount: 10.00, currency: "USD")
        let context = PaymentContext(
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
            returnURL: "testapp://rokt-payment-return"
        )
        let preparation = PaymentPreparation(
            clientSecret: "pi_1Test_secret_abc",
            merchantId: Self.preparationAccount,
            totalAmount: 10,
            shippingCost: 0,
            tax: 0,
            approvalUrl: nil
        )
        let completed = expectation(description: "Afterpay flow completed")
        var result: PaymentSheetResult?

        ext.presentPaymentSheet(
            item: item,
            method: .afterpay,
            context: context,
            from: UIViewController(),
            preparePayment: { _, done in done(preparation, nil) },
            completion: { received in
                result = received
                completed.fulfill()
            }
        )

        // The extension hands the confirmation to the main queue; this block runs right after that
        // hop, while Stripe's request is still in flight.
        let confirming = expectation(description: "confirmation handed to Stripe")
        var extensionClient: STPAPIClient?
        DispatchQueue.main.async {
            let handlerClient = STPPaymentHandler.shared().apiClient
            extensionClient = handlerClient
            XCTAssertFalse(
                handlerClient === STPAPIClient.shared,
                "the confirmation should run on the extension's own client"
            )
            XCTAssertEqual(handlerClient.publishableKey, Self.extensionPublishableKey)
            XCTAssertEqual(handlerClient.stripeAccount, Self.preparationAccount)
            XCTAssertEqual(STPAPIClient.shared.publishableKey, Self.hostPublishableKey)
            XCTAssertEqual(STPAPIClient.shared.stripeAccount, Self.hostStripeAccount)
            confirming.fulfill()
        }
        wait(for: [confirming], timeout: 1)

        // Stripe answers the fake key with an error; offline, the network layer fails the request.
        wait(for: [completed], timeout: 30)

        XCTAssertEqual(result?.outcome, .failed)
        XCTAssertEqual(STPAPIClient.shared.publishableKey, Self.hostPublishableKey)
        XCTAssertEqual(STPAPIClient.shared.stripeAccount, Self.hostStripeAccount)
        XCTAssertTrue(
            STPPaymentHandler.shared().apiClient === STPAPIClient.shared,
            "the handler should be back on the shared client once the flow ends"
        )
        XCTAssertNil(
            extensionClient?.stripeAccount,
            "the connected-account scope should be cleared from the extension's client once the flow ends"
        )
    }
}
