import UIKit
import Rokt_Widget
import RoktStripePaymentExtension

/// Minimal demo screen for exercising the Shoppable Ads flow.
///
/// The screen exposes three steps:
/// 1. Fill in the Stripe publishable key, Apple Pay merchant ID, view identifier, and (optional) email.
/// 2. Tap **Register Payment Extension** — constructs `RoktStripePaymentExtension` and registers it via `Rokt.registerPaymentExtension(_:config:)`.
/// 3. Tap **Trigger Shoppable Ads** — calls `Rokt.selectShoppableAds(identifier:attributes:onEvent:)` and logs events.
///
/// Requires `Rokt.initWith(roktTagId:)` to have completed first (done from `TagIdSelectionTableViewController`).
/// A valid Apple Pay entitlement is required to actually present the payment sheet; registration and the
/// `selectShoppableAds` call succeed without one, but the Apple Pay transaction will fail.
final class ShoppableAdsDemoViewController: UIViewController {

    private let stripeKeyField = makeDemoTextField(placeholder: "Stripe publishable key (pk_test_...)")
    private let merchantIdField = makeDemoTextField(placeholder: "Apple Pay merchant ID (merchant.com.example)")
    private let identifierField = makeDemoTextField(placeholder: "Shoppable Ads identifier (e.g. ConfirmationPage)")
    private let emailField = makeDemoTextField(placeholder: "Email (optional)")
    private let registerButton = UIButton(type: .system)
    private let triggerButton = UIButton(type: .system)
    private let logView = UITextView()

    private var registeredExtension: RoktStripePaymentExtension?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shoppable Ads Demo"
        view.backgroundColor = .systemBackground

        registerButton.setTitle("Register Payment Extension", for: .normal)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)

        triggerButton.setTitle("Trigger Shoppable Ads", for: .normal)
        triggerButton.addTarget(self, action: #selector(triggerTapped), for: .touchUpInside)

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.backgroundColor = .secondarySystemBackground
        logView.layer.cornerRadius = 6
        logView.accessibilityIdentifier = "shoppable-ads-demo-log"

        let stack = UIStackView(arrangedSubviews: [
            stripeKeyField,
            merchantIdField,
            identifierField,
            emailField,
            registerButton,
            triggerButton,
            logView
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            logView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])

        identifierField.text = "ConfirmationPage"
        appendLog("Ready. Rokt.initWith(roktTagId:) must already have been called.")
    }

    @objc private func registerTapped() {
        view.endEditing(true)
        if registeredExtension != nil {
            appendLog("Payment extension already registered; skipping.")
            return
        }
        let stripeKey = stripeKeyField.text ?? ""
        let merchantId = merchantIdField.text ?? ""
        guard !stripeKey.isEmpty, !merchantId.isEmpty else {
            appendLog("Missing Stripe key or Apple Pay merchant ID.")
            return
        }
        guard let ext = RoktStripePaymentExtension(applePayMerchantId: merchantId) else {
            appendLog("RoktStripePaymentExtension init returned nil (merchant ID was empty).")
            return
        }
        registeredExtension = ext
        Rokt.registerPaymentExtension(ext, config: ["stripeKey": stripeKey])
        appendLog("Registered RoktStripePaymentExtension (merchantId=\(merchantId)).")
    }

    @objc private func triggerTapped() {
        view.endEditing(true)
        if registeredExtension == nil {
            appendLog("Warning: payment extension not registered in this session — Apple Pay will not be available.")
        }
        let identifier = identifierField.text ?? ""
        guard !identifier.isEmpty else {
            appendLog("Missing Shoppable Ads identifier.")
            return
        }
        var attributes: [String: String] = [:]
        if let email = emailField.text, !email.isEmpty {
            attributes["email"] = email
        }
        appendLog("Calling selectShoppableAds(identifier: \"\(identifier)\", attributes: \(attributes)) …")
        Rokt.selectShoppableAds(identifier: identifier, attributes: attributes) { [weak self] event in
            self?.appendLog("RoktEvent: \(type(of: event))")
        }
    }

    private func appendLog(_ line: String) {
        DispatchQueue.main.async {
            let existing = self.logView.text ?? ""
            self.logView.text = existing.isEmpty ? line : existing + "\n" + line
        }
    }

}

private func makeDemoTextField(placeholder: String) -> UITextField {
    let field = UITextField()
    field.placeholder = placeholder
    field.borderStyle = .roundedRect
    field.autocorrectionType = .no
    field.autocapitalizationType = .none
    field.spellCheckingType = .no
    return field
}
