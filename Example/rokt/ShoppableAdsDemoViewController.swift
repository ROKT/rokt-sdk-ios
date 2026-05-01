import UIKit
import Rokt_Widget
import RoktPaymentExtension

struct ShoppableAdsDemoSeed {
    let environment: Environment
    let tagID: String
    let viewName: String

    init(
        environment: Environment = .Stage,
        tagID: String = ShoppableAdsDefaults.tagID,
        viewName: String = ShoppableAdsDefaults.viewName
    ) {
        self.environment = environment
        self.tagID = tagID
        self.viewName = viewName
    }
}

protocol ShoppableAdsRoktClient {
    func setEnvironment(_ environment: RoktEnvironment)
    func globalEvents(onEvent: @escaping (RoktEvent) -> Void)
    func initWith(roktTagId: String)
    func registerPaymentExtension(_ paymentExtension: RoktPaymentExtension, config: [String: String])
    func selectShoppableAds(identifier: String, attributes: [String: String], onEvent: ((RoktEvent) -> Void)?)
    func setSessionId(_ sessionId: String)
}

private struct LiveShoppableAdsRoktClient: ShoppableAdsRoktClient {
    func setEnvironment(_ environment: RoktEnvironment) {
        Rokt.setEnvironment(environment: environment)
    }

    func globalEvents(onEvent: @escaping (RoktEvent) -> Void) {
        Rokt.globalEvents(onEvent: onEvent)
    }

    func initWith(roktTagId: String) {
        Rokt.initWith(roktTagId: roktTagId)
    }

    func registerPaymentExtension(_ paymentExtension: RoktPaymentExtension, config: [String: String]) {
        Rokt.registerPaymentExtension(paymentExtension, config: config)
    }

    func selectShoppableAds(identifier: String, attributes: [String: String], onEvent: ((RoktEvent) -> Void)?) {
        Rokt.selectShoppableAds(identifier: identifier, attributes: attributes, onEvent: onEvent)
    }

    func setSessionId(_ sessionId: String) {
        Rokt.setSessionId(sessionId: sessionId)
    }
}

/// Grouped-table demo screen for exercising Shoppable Ads end-to-end.
///
/// Layout mirrors the public `rokt-demo-ios` Shoppable Ads flow so operators
/// get a consistent experience in either app:
///
/// - **Account** - Tag ID, Stripe publishable key, Apple Pay merchant ID, view name.
/// - **Attributes** - every attribute the Rokt dashboard typically reads,
///   pre-populated with sandbox values and individually editable.
/// - **Actions** - initialize Rokt, register the payment extension, launch
///   Shoppable Ads, reset the form, clear the log.
/// - **Event log** - human-readable stream of `RoktEvent`s delivered by the SDK.
///
/// Apple Pay entitlement is required to actually present the payment sheet;
/// registration and the `selectShoppableAds` call succeed without one.
final class ShoppableAdsDemoViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case account
        case attributes
        case actions
        case log

        var title: String? {
            switch self {
            case .account: return "Account"
            case .attributes: return "Attributes"
            case .actions: return nil
            case .log: return "Event Log"
            }
        }
    }

    private struct Field {
        let key: String
        let label: String
        var value: String
    }

    private let seed: ShoppableAdsDemoSeed
    private let roktClient: ShoppableAdsRoktClient
    private var accountFields: [Field] = []
    private var attributeFields: [Field] = []
    private var logLines: [String] = []
    private var registeredExtension: RoktPaymentExtension?
    private var initializedTagID: String?
    private var initializedEnvironment: Environment?
    private var isGlobalEventsRegistered = false

    private lazy var logView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.backgroundColor = .secondarySystemBackground
        tv.layer.cornerRadius = 6
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.accessibilityIdentifier = "shoppable-ads-demo-log"
        return tv
    }()

    init(
        seed: ShoppableAdsDemoSeed = ShoppableAdsDemoSeed(),
        roktClient: ShoppableAdsRoktClient = LiveShoppableAdsRoktClient()
    ) {
        self.seed = seed
        self.roktClient = roktClient
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        seed = ShoppableAdsDemoSeed()
        roktClient = LiveShoppableAdsRoktClient()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shoppable Ads Demo"
        tableView.keyboardDismissMode = .interactive
        tableView.register(TextEntryCell.self, forCellReuseIdentifier: TextEntryCell.reuseId)
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseId)
        tableView.register(LogCell.self, forCellReuseIdentifier: LogCell.reuseId)
        loadDefaults()
        appendLog("Ready. Environment: \(seed.environment.rawValue). Tag ID defaults from the previous screen.")
    }

    private func loadDefaults() {
        accountFields = [
            Field(key: "tagID", label: "Tag ID", value: seed.tagID),
            Field(key: "stripeKey", label: "Stripe Publishable Key", value: ShoppableAdsDefaults.stripePublishableKey),
            Field(key: "merchantId", label: "Apple Pay Merchant ID", value: ShoppableAdsDefaults.applePayMerchantId),
            Field(key: "viewName", label: "View Name (identifier)", value: seed.viewName)
        ]
        attributeFields = ShoppableAdsDefaults.attributes.map {
            Field(key: $0.key, label: $0.key, value: $0.value)
        }
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .account: return accountFields.count
        case .attributes: return attributeFields.count
        case .actions: return 5
        case .log: return 1
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .account:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextEntryCell.reuseId, for: indexPath) as! TextEntryCell
            let field = accountFields[indexPath.row]
            cell.configure(label: field.label, value: field.value, isSecure: field.key == "stripeKey")
            cell.onChange = { [weak self] newValue in
                guard let self, indexPath.row < self.accountFields.count else { return }
                self.accountFields[indexPath.row].value = newValue
                if field.key == "tagID" {
                    self.initializedTagID = nil
                }
            }
            return cell
        case .attributes:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextEntryCell.reuseId, for: indexPath) as! TextEntryCell
            let field = attributeFields[indexPath.row]
            cell.configure(label: field.label, value: field.value, isSecure: false)
            cell.onChange = { [weak self] newValue in
                self?.attributeFields[indexPath.row].value = newValue
            }
            return cell
        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseId, for: indexPath) as! ActionCell
            switch indexPath.row {
            case 0: cell.configure(title: "Initialize Rokt", destructive: false)
            case 1: cell.configure(title: "Register Payment Extension", destructive: false)
            case 2: cell.configure(title: "Launch Shoppable Ads", destructive: false)
            case 3: cell.configure(title: "Reset to Defaults", destructive: false)
            case 4: cell.configure(title: "Clear Log", destructive: true)
            default: break
            }
            return cell
        case .log:
            let cell = tableView.dequeueReusableCell(withIdentifier: LogCell.reuseId, for: indexPath) as! LogCell
            cell.install(logView: logView)
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Section(rawValue: indexPath.section) == .log ? 200 : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .actions else { return }
        view.endEditing(true)
        switch indexPath.row {
        case 0: initializeRokt()
        case 1: registerExtension()
        case 2: launchShoppableAds()
        case 3: resetToDefaults()
        case 4: clearLog()
        default: break
        }
    }

    // MARK: - Actions

    private func initializeRokt() {
        let tagID = value(for: "tagID", in: accountFields).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tagID.isEmpty else {
            appendLog("Missing tag ID.")
            return
        }
        roktClient.setEnvironment(seed.environment.roktEnvironment)
        appendLog("Set Rokt environment: \(seed.environment.rawValue).")
        if !isGlobalEventsRegistered {
            roktClient.globalEvents { [weak self] roktEvent in
                DispatchQueue.main.async {
                    self?.appendLog("Global event: \(Self.describe(roktEvent))")
                }
            }
            isGlobalEventsRegistered = true
            appendLog("Subscribed to Rokt.globalEvents.")
        }
        roktClient.initWith(roktTagId: tagID)
        initializedTagID = tagID
        initializedEnvironment = seed.environment
        appendLog("Called Rokt.initWith(roktTagId: \"\(tagID)\").")
    }

    private func registerExtension() {
        guard isInitializedForCurrentInputs else {
            appendLog("Initialize Rokt before registering the payment extension.")
            return
        }
        if registeredExtension != nil {
            appendLog("Payment extension already registered; skipping.")
            return
        }
        let stripeKey = value(for: "stripeKey", in: accountFields)
        let merchantId = value(for: "merchantId", in: accountFields)
        guard !stripeKey.isEmpty else {
            appendLog("Missing Stripe publishable key.")
            return
        }
        guard !merchantId.isEmpty else {
            appendLog("Missing Apple Pay merchant ID.")
            return
        }
        guard let ext = RoktPaymentExtension(applePayMerchantId: merchantId) else {
            appendLog("RoktPaymentExtension init returned nil.")
            return
        }
        registeredExtension = ext
        roktClient.registerPaymentExtension(ext, config: ["stripeKey": stripeKey])
        appendLog("Registered RoktPaymentExtension (merchantId=\(merchantId)).")
    }

    private func launchShoppableAds() {
        guard isInitializedForCurrentInputs else {
            appendLog("Initialize Rokt before launching Shoppable Ads.")
            return
        }
        if registeredExtension == nil {
            appendLog("Warning: payment extension not registered in this session - Apple Pay will not be available.")
        }
        let identifier = value(for: "viewName", in: accountFields)
        guard !identifier.isEmpty else {
            appendLog("Missing view name (identifier).")
            return
        }
        var attributes: [String: String] = [:]
        for field in attributeFields where !field.value.isEmpty {
            attributes[field.key] = field.value
        }
        appendLog(
            "Calling selectShoppableAds(identifier: \"\(identifier)\") in \(seed.environment.rawValue) with " +
                "\(attributes.count) attributes ..."
        )
        roktClient.selectShoppableAds(identifier: identifier, attributes: attributes) { [weak self] event in
            DispatchQueue.main.async {
                self?.appendLog(Self.describe(event))
            }
        }
    }

    private func resetToDefaults() {
        loadDefaults()
        appendLog("Form reset to defaults for environment \(seed.environment.rawValue).")
    }

    private func clearLog() {
        roktClient.setSessionId(" ")
        logLines.removeAll()
        logView.text = ""
    }

    // MARK: - Helpers

    private func value(for key: String, in fields: [Field]) -> String {
        fields.first(where: { $0.key == key })?.value ?? ""
    }

    private var isInitializedForCurrentInputs: Bool {
        initializedEnvironment == seed.environment &&
            initializedTagID == value(for: "tagID", in: accountFields).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendLog(_ line: String) {
        DispatchQueue.main.async {
            self.logLines.append(line)
            self.logView.text = self.logLines.joined(separator: "\n")
            let end = NSRange(location: (self.logView.text as NSString).length, length: 0)
            self.logView.scrollRangeToVisible(end)
        }
    }

    static func describe(_ event: RoktEvent) -> String {
        switch event {
        case let e as RoktEvent.InitComplete:
            return "InitComplete(success=\(e.success))"
        case let e as RoktEvent.PlacementReady:
            return "PlacementReady(\(e.identifier ?? "-"))"
        case let e as RoktEvent.PlacementClosed:
            return "PlacementClosed(\(e.identifier ?? "-"))"
        case let e as RoktEvent.PlacementCompleted:
            return "PlacementCompleted(\(e.identifier ?? "-"))"
        case let e as RoktEvent.PlacementFailure:
            return "PlacementFailure(\(e.identifier ?? "-"))"
        case let e as RoktEvent.PlacementInteractive:
            return "PlacementInteractive(\(e.identifier ?? "-"))"
        case let e as RoktEvent.OfferEngagement:
            return "OfferEngagement(\(e.identifier ?? "-"))"
        case let e as RoktEvent.PositiveEngagement:
            return "PositiveEngagement(\(e.identifier ?? "-"))"
        case let e as RoktEvent.FirstPositiveEngagement:
            return "FirstPositiveEngagement(\(e.identifier ?? "-"))"
        case let e as RoktEvent.OpenUrl:
            return "OpenUrl(\(e.url))"
        case let e as RoktEvent.CartItemInstantPurchase:
            return "CartItemInstantPurchase(catalogItemId=\(e.catalogItemId))"
        case let e as RoktEvent.CartItemDevicePay:
            return "CartItemDevicePay(\(e.paymentProvider))"
        default:
            return "RoktEvent: \(type(of: event))"
        }
    }
}

// MARK: - Cells

private final class TextEntryCell: UITableViewCell, UITextFieldDelegate {
    static let reuseId = "TextEntryCell"

    private let labelView = UILabel()
    private let field = UITextField()

    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        labelView.font = .preferredFont(forTextStyle: .caption1)
        labelView.textColor = .secondaryLabel
        labelView.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .none
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.delegate = self
        field.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        field.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(labelView)
        contentView.addSubview(field)

        NSLayoutConstraint.activate([
            labelView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            labelView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            labelView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            field.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 4),
            field.leadingAnchor.constraint(equalTo: labelView.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: labelView.trailingAnchor),
            field.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(label: String, value: String, isSecure: Bool) {
        labelView.text = label
        field.text = value
        field.isSecureTextEntry = isSecure
        field.placeholder = isSecure ? "pk_test_..." : label
    }

    @objc private func editingChanged() {
        onChange?(field.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class ActionCell: UITableViewCell {
    static let reuseId = "ActionCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) { nil }

    func configure(title: String, destructive: Bool) {
        var content = defaultContentConfiguration()
        content.text = title
        content.textProperties.color = destructive ? .systemRed : .systemBlue
        content.textProperties.alignment = .center
        contentConfiguration = content
    }
}

private final class LogCell: UITableViewCell {
    static let reuseId = "LogCell"
    private weak var hostedLogView: UITextView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
    }

    required init?(coder: NSCoder) { nil }

    func install(logView: UITextView) {
        guard logView !== hostedLogView else { return }
        hostedLogView?.removeFromSuperview()
        contentView.addSubview(logView)
        NSLayoutConstraint.activate([
            logView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            logView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            logView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            logView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
        hostedLogView = logView
    }
}
