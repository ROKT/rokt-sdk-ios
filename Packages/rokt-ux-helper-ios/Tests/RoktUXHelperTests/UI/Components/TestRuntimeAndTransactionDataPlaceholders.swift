import XCTest
import SwiftUI
@testable import RoktUXHelper
import DcuiSchema
import SnapshotTesting

/// End-to-end snapshot coverage for the two new placeholder namespaces and the
/// finalize step that ties them together:
///
/// 1. `DATA.catalogRuntime.*` — host-pushed runtime values resolved reactively from
///    `LayoutState.catalogRuntimeDataKey`.
/// 2. `DATA.transactionData.*` — offer-level transaction data resolved at transform
///    time by `TransactionDataMapper` against the active offer's `TransactionData`.
/// 3. `OrphanedPlaceholderResolver` — fail-loud-on-mandatory-orphan typo guard.
final class TestRuntimeAndTransactionDataPlaceholders: XCTestCase {

    // MARK: - DATA.catalogRuntime.*

    func testSnapshot_basicText_resolvesCatalogRuntimePlaceholders() {
        let layoutState = LayoutState()
        layoutState.items[LayoutState.catalogRuntimeDataKey] = [
            "subtotal": "$24.00",
            "tax": "$1.94",
            "shipping": "$0.00",
            "total": "$26.72"
        ]

        let model = BasicTextViewModel(
            value: """
            Subtotal: %^DATA.catalogRuntime.subtotal | --^%
            Sales Tax: %^DATA.catalogRuntime.tax | --^%
            Shipping: %^DATA.catalogRuntime.shipping | --^%
            Total: %^DATA.catalogRuntime.total | --^%
            """,
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            layoutState: layoutState,
            diagnosticService: nil
        )
        // Prime the post-mapper template so the reactive resolver has something to operate on.
        // In production this is set by the mapper chain; here we simulate "no mapper claimed
        // this text" by feeding the raw value straight through.
        model.updateDataBinding(dataBinding: .value(model.value ?? ""))

        assertBasicTextSnapshot(model)
    }

    func testSnapshot_basicText_catalogRuntimeFallsBackToDefault_whenDataMissing() {
        // No catalogRuntimeDataKey in items — placeholders should resolve to their `--`
        // defaults, NOT zero the line and NOT leave the placeholder visible.
        let layoutState = LayoutState()

        let model = BasicTextViewModel(
            value: "Subtotal: %^DATA.catalogRuntime.subtotal | --^%",
            defaultStyle: nil,
            pressedStyle: nil,
            hoveredStyle: nil,
            disabledStyle: nil,
            layoutState: layoutState,
            diagnosticService: nil
        )
        model.updateDataBinding(dataBinding: .value(model.value ?? ""))

        assertBasicTextSnapshot(model)
    }

    // MARK: - DATA.transactionData.*

    func testSnapshot_basicText_resolvesShippingAddressFromTransactionData() {
        // Drive the full LayoutTransformer so TransactionDataMapper actually runs.
        let layoutState = LayoutState()
        let transactionData = TransactionData(
            shippingAddress: Address(
                name: "Jane Smith",
                address1: "123 Main St",
                address2: "Apt 4B",
                city: "New York",
                state: "NY",
                stateCode: "NY",
                country: "US",
                countryCode: "US",
                zip: "10001"
            ),
            billingAddress: nil,
            paymentType: "paypal",
            supportedPaymentMethods: nil,
            isPartnerManagedPurchase: false,
            partnerPaymentReference: nil,
            confirmationRef: nil,
            metadata: [:]
        )

        // The mapper pulls TransactionData off the active offer via `fullOfferKey`.
        // Stub a minimal OfferModel that carries our test transactionData.
        layoutState.items[LayoutState.fullOfferKey] = makeOffer(transactionData: transactionData)

        let basicText = BasicTextModel<WhenPredicate>(
            styles: nil,
            value: "%^DATA.transactionData.shippingAddress.name | ^%, "
                + "%^DATA.transactionData.shippingAddress.address1 | ^% "
                + "%^DATA.transactionData.shippingAddress.address2 | ^%, "
                + "%^DATA.transactionData.shippingAddress.city | ^%, "
                + "%^DATA.transactionData.shippingAddress.state | ^% "
                + "%^DATA.transactionData.shippingAddress.zip | ^%"
        )

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState
        )
        // Use a catalog-item context so the addToCart mapper runs alongside transactionData.
        let catalogItem = makeCatalogItem()
        let model = try! transformer.getBasicText(
            basicText,
            context: .inner(.addToCart(catalogItem))
        )

        assertBasicTextSnapshot(model)
    }

    // MARK: - OrphanedPlaceholderResolver finalize behaviour

    func testSnapshot_basicText_optionalOrphan_substitutesDefault() {
        let layoutState = LayoutState()

        // Creative-link placeholder isn't claimed by the catalog mapper. With a `|` default
        // the finalize step substitutes the literal — the line stays.
        let basicText = BasicTextModel<WhenPredicate>(
            styles: nil,
            value: "Read our %^DATA.creativeLink.terms | terms^%"
        )

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState
        )
        let model = try! transformer.getBasicText(
            basicText,
            context: .inner(.addToCart(makeCatalogItem()))
        )

        assertBasicTextSnapshot(model)
    }

    func testSnapshot_basicText_mandatoryOrphan_zeroesLine() {
        let layoutState = LayoutState()

        // Creative-link placeholder, no `|` default → mandatory orphan in catalog context.
        // OrphanedPlaceholderResolver should zero the line.
        let basicText = BasicTextModel<WhenPredicate>(
            styles: nil,
            value: "Read our %^DATA.creativeLink.terms^%"
        )

        let transformer = LayoutTransformer(
            layoutPlugin: get_mock_layout_plugin(),
            layoutState: layoutState
        )
        let model = try! transformer.getBasicText(
            basicText,
            context: .inner(.addToCart(makeCatalogItem()))
        )

        XCTAssertEqual(model.boundValue, "")
        assertBasicTextSnapshot(model)
    }

    // MARK: - Helpers

    private func assertBasicTextSnapshot(
        _ model: BasicTextViewModel,
        width: CGFloat = 350,
        height: CGFloat = 200,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let view = TestPlaceHolder(
            layout: LayoutSchemaViewModel.basicText(model),
            layoutState: model.layoutState as? LayoutState ?? LayoutState()
        )
        .frame(width: width, height: height)
        let hostingController = UIHostingController(rootView: view)
        // perceptualPrecision tolerates sub-pixel text rendering differences between
        // simulator iOS versions (CI runs `os_version: ">=18.0"` so the runtime drifts).
        assertSnapshot(
            of: hostingController,
            as: .image(on: snapshotDevice, perceptualPrecision: 0.98),
            file: file,
            testName: testName,
            line: line
        )
    }

    private func makeCatalogItem() -> CatalogItem {
        CatalogItem(
            images: [:],
            catalogItemId: "item-1",
            cartItemId: "cart-1",
            instanceGuid: "instance-1",
            title: "Test Item",
            description: "Description",
            price: nil,
            priceFormatted: nil,
            originalPrice: nil,
            originalPriceFormatted: nil,
            currency: "USD",
            signalType: nil,
            url: nil,
            minItemCount: nil,
            maxItemCount: nil,
            preSelectedQuantity: nil,
            providerData: "provider",
            urlBehavior: nil,
            positiveResponseText: "",
            negativeResponseText: "",
            addOns: nil,
            copy: nil,
            inventoryStatus: nil,
            linkedProductId: nil,
            token: "token"
        )
    }

    /// Construct a minimal `OfferModel` carrying the test `TransactionData` so the
    /// `TransactionDataMapper` can pull it off `LayoutState.fullOfferKey`.
    private func makeOffer(transactionData: TransactionData) -> OfferModel {
        OfferModel(
            campaignId: "test-campaign",
            creative: CreativeModel(
                referralCreativeId: "test-creative",
                instanceGuid: "instance-1",
                copy: [:],
                images: nil,
                links: nil,
                responseOptionsMap: nil,
                jwtToken: "token"
            ),
            catalogItems: [makeCatalogItem()],
            catalogItemGroup: nil,
            transactionData: transactionData
        )
    }
}
