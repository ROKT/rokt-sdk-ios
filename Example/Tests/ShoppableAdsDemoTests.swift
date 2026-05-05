import UIKit
import XCTest
import RoktPaymentExtension
@testable import Rokt_Widget

final class ShoppableAdsDemoTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testDefaultsUseSandboxShoppableAdsValues() {
        XCTAssertEqual(ShoppableAdsDefaults.tagID, "3068704822624787054")
        XCTAssertEqual(ShoppableAdsDefaults.viewName, "StgRoktShoppableAds")
        XCTAssertEqual(ShoppableAdsDefaults.stripePublishableKey, "")
        XCTAssertFalse(ShoppableAdsDefaults.applePayMerchantId.isEmpty)
        XCTAssertTrue(ShoppableAdsDefaults.attributes.contains { $0.key == "sandbox" && $0.value == "true" })
        XCTAssertTrue(ShoppableAdsDefaults.attributes.contains { $0.key == "paymenttype" && $0.value == "ApplePay" })
        XCTAssertEqual(Environment.Stage.roktEnvironment, .Stage)
        XCTAssertEqual(Environment.Prod.roktEnvironment, .Prod)
    }

    func testDemoRendersDefaultSectionsAndRows() {
        let controller = ShoppableAdsDemoViewController(
            seed: ShoppableAdsDemoSeed(environment: .Prod, tagID: "previous-tag-id"),
            roktClient: SpyShoppableAdsRoktClient()
        )
        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.numberOfSections(in: controller.tableView), 4)
        XCTAssertEqual(controller.tableView(controller.tableView, titleForHeaderInSection: 0), "Account")
        XCTAssertEqual(controller.tableView(controller.tableView, titleForHeaderInSection: 1), "Attributes")
        XCTAssertNil(controller.tableView(controller.tableView, titleForHeaderInSection: 2))
        XCTAssertEqual(controller.tableView(controller.tableView, titleForHeaderInSection: 3), "Event Log")
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), 4)
        XCTAssertEqual(
            controller.tableView(controller.tableView, numberOfRowsInSection: 1),
            ShoppableAdsDefaults.attributes.count
        )
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 2), 5)
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 3), 1)

        let tagCell = controller.tableView(
            controller.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        XCTAssertTrue(tagCell.descendants(of: UILabel.self).contains { $0.text == "Tag ID" })
        XCTAssertEqual(tagCell.descendants(of: UITextField.self).first?.text, "previous-tag-id")

        let actionCell = controller.tableView(
            controller.tableView,
            cellForRowAt: IndexPath(row: 0, section: 2)
        )
        let actionContent = actionCell.contentConfiguration as? UIListContentConfiguration
        XCTAssertEqual(actionContent?.text, "Initialize Rokt")
    }

    func testDemoActionsWriteValidationMessagesAndClearLog() {
        let roktClient = SpyShoppableAdsRoktClient()
        let controller = ShoppableAdsDemoViewController(roktClient: roktClient)
        controller.loadViewIfNeeded()
        let logView = installedLogView(for: controller)

        waitForLog(logView, contains: "Ready.")

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 1, section: 2)
        )
        waitForLog(logView, contains: "Initialize Rokt before registering")

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 2, section: 2)
        )
        waitForLog(logView, contains: "Initialize Rokt before launching")

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 4, section: 2)
        )
        XCTAssertEqual(logView.text, "")
        XCTAssertEqual(roktClient.sessionIDs, [" "])
    }

    func testInitializeSetsEnvironmentAndCallsInitWithEditableTag() throws {
        let roktClient = SpyShoppableAdsRoktClient()
        let controller = ShoppableAdsDemoViewController(
            seed: ShoppableAdsDemoSeed(environment: .Prod, tagID: "previous-tag-id"),
            roktClient: roktClient
        )
        controller.loadViewIfNeeded()
        let logView = installedLogView(for: controller)

        let tagCell = controller.tableView(
            controller.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        let tagField = try XCTUnwrap(tagCell.descendants(of: UITextField.self).first)
        tagField.text = "edited-tag-id"
        tagField.sendActions(for: .editingChanged)

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 0, section: 2)
        )

        XCTAssertEqual(roktClient.environments, [.Prod])
        XCTAssertEqual(roktClient.initializedTagIDs, ["edited-tag-id"])
        XCTAssertNotNil(roktClient.globalEventHandler)
        waitForLog(logView, contains: "Set Rokt environment: Prod.")
        waitForLog(logView, contains: "Called Rokt.initWith(roktTagId: \"edited-tag-id\")")

        roktClient.globalEventHandler?(RoktEvent.InitComplete(success: true))
        waitForLog(logView, contains: "Global event: InitComplete(success=true)")
    }

    func testRegisterAfterInitValidatesBlankStripeKey() {
        let roktClient = SpyShoppableAdsRoktClient()
        let controller = ShoppableAdsDemoViewController(roktClient: roktClient)
        controller.loadViewIfNeeded()
        let logView = installedLogView(for: controller)

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 0, section: 2)
        )
        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 1, section: 2)
        )

        waitForLog(logView, contains: "Missing Stripe publishable key.")
    }

    func testLaunchAfterInitLogsEnvironmentAndUnregisteredPaymentWarning() {
        let roktClient = SpyShoppableAdsRoktClient()
        let controller = ShoppableAdsDemoViewController(
            seed: ShoppableAdsDemoSeed(environment: .Stage, tagID: "tag-id", viewName: "ViewName"),
            roktClient: roktClient
        )
        controller.loadViewIfNeeded()
        let logView = installedLogView(for: controller)

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 0, section: 2)
        )
        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 2, section: 2)
        )

        XCTAssertEqual(roktClient.selections.count, 1)
        XCTAssertEqual(roktClient.selections.first?.identifier, "ViewName")
        waitForLog(logView, contains: "payment extension not registered")
        waitForLog(logView, contains: "in Stage")
    }

    func testResetRestoresDefaultAccountValues() throws {
        let controller = ShoppableAdsDemoViewController()
        controller.loadViewIfNeeded()

        let tagCell = controller.tableView(
            controller.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        let tagField = try XCTUnwrap(tagCell.descendants(of: UITextField.self).first)
        tagField.text = "changed"
        tagField.sendActions(for: .editingChanged)

        controller.tableView(
            controller.tableView,
            didSelectRowAt: IndexPath(row: 3, section: 2)
        )

        let resetCell = controller.tableView(
            controller.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        XCTAssertEqual(resetCell.descendants(of: UITextField.self).first?.text, ShoppableAdsDefaults.tagID)
    }

    func testDescribeFormatsCommonRoktEvents() {
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.InitComplete(success: true)),
            "InitComplete(success=true)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.PlacementReady(identifier: "layout")),
            "PlacementReady(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.PlacementClosed(identifier: nil)),
            "PlacementClosed(-)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.PlacementCompleted(identifier: "layout")),
            "PlacementCompleted(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.PlacementFailure(identifier: "layout")),
            "PlacementFailure(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.PlacementInteractive(identifier: "layout")),
            "PlacementInteractive(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.OfferEngagement(identifier: "layout")),
            "OfferEngagement(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.PositiveEngagement(identifier: "layout")),
            "PositiveEngagement(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.FirstPositiveEngagement(identifier: "layout")),
            "FirstPositiveEngagement(layout)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.OpenUrl(identifier: "layout", url: "https://example.com")),
            "OpenUrl(https://example.com)"
        )
        XCTAssertEqual(
            ShoppableAdsDemoViewController.describe(RoktEvent.ShowLoadingIndicator()),
            "RoktEvent: ShowLoadingIndicator"
        )
    }

    func testTagSelectionInstallsDemoButtonAndPushesDemo() throws {
        let controller = TagIdSelectionTableViewController()
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let initializeButton = UIButton(type: .system)
        initializeButton.accessibilityIdentifier = "InitializeButton"
        initializeButton.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(initializeButton)
        NSLayoutConstraint.activate([
            initializeButton.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            initializeButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            initializeButton.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor),
            initializeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        let environmentPicker = UIPickerView()
        let tagIdPicker = UIPickerView()
        let customTagIdLabel = UILabel()
        let customTagIdTextField = UITextField()
        [environmentPicker, tagIdPicker, customTagIdLabel, customTagIdTextField].forEach(rootView.addSubview)
        controller.environmentPicker = environmentPicker
        controller.tagIdPicker = tagIdPicker
        controller.customTagIdLabel = customTagIdLabel
        controller.customTagIdTextField = customTagIdTextField
        controller.view = rootView
        controller.viewDidLoad()
        environmentPicker.selectRow(1, inComponent: 0, animated: false)
        controller.pickerView(environmentPicker, didSelectRow: 1, inComponent: 0)
        customTagIdTextField.text = "previous-screen-tag"

        let navigationController = UINavigationController(rootViewController: controller)
        showInWindow(navigationController)
        controller.view.layoutIfNeeded()

        let demoButton = try XCTUnwrap(
            controller.view.firstDescendant(
                of: UIButton.self,
                where: { $0.accessibilityIdentifier == "ShoppableAdsDemoButton" }
            )
        )

        XCTAssertEqual(demoButton.title(for: .normal), "Shoppable Ads Demo")
        XCTAssertLessThanOrEqual(demoButton.frame.maxY, initializeButton.frame.minY + 0.5)

        demoButton.sendActions(for: .touchUpInside)
        let demoController = try XCTUnwrap(navigationController.topViewController as? ShoppableAdsDemoViewController)
        let tagCell = demoController.tableView(
            demoController.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        )
        XCTAssertEqual(tagCell.descendants(of: UITextField.self).first?.text, "previous-screen-tag")
        waitForLog(installedLogView(for: demoController), contains: "Environment: Prod")
    }

    private func installedLogView(for controller: ShoppableAdsDemoViewController) -> UITextView {
        let logCell = controller.tableView(
            controller.tableView,
            cellForRowAt: IndexPath(row: 0, section: 3)
        )
        return logCell.descendants(of: UITextView.self).first!
    }

    private func waitForLog(
        _ logView: UITextView,
        contains expectedText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = expectation(description: "Log contains \(expectedText)")
        pollUntil(
            timeout: Date().addingTimeInterval(2),
            condition: { logView.text.contains(expectedText) },
            onSuccess: { expectation.fulfill() }
        )
        wait(for: [expectation], timeout: 2.5)
        XCTAssertTrue(logView.text.contains(expectedText), file: file, line: line)
    }

    private func pollUntil(timeout: Date, condition: @escaping () -> Bool, onSuccess: @escaping () -> Void) {
        if condition() {
            onSuccess()
        } else if Date() < timeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.pollUntil(timeout: timeout, condition: condition, onSuccess: onSuccess)
            }
        }
    }

    private func showInWindow(_ viewController: UIViewController) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        self.window = window
    }
}

private final class SpyShoppableAdsRoktClient: ShoppableAdsRoktClient {
    struct Selection {
        let identifier: String
        let attributes: [String: String]
    }

    var environments: [RoktEnvironment] = []
    var initializedTagIDs: [String] = []
    var sessionIDs: [String] = []
    var selections: [Selection] = []
    var registeredConfigs: [[String: String]] = []
    var globalEventHandler: ((RoktEvent) -> Void)?

    func setEnvironment(_ environment: RoktEnvironment) {
        environments.append(environment)
    }

    func globalEvents(onEvent: @escaping (RoktEvent) -> Void) {
        globalEventHandler = onEvent
    }

    func initWith(roktTagId: String) {
        initializedTagIDs.append(roktTagId)
    }

    func registerPaymentExtension(_ paymentExtension: RoktPaymentExtension, config: [String: String]) {
        registeredConfigs.append(config)
    }

    func selectShoppableAds(identifier: String, attributes: [String: String], onEvent: ((RoktEvent) -> Void)?) {
        selections.append(Selection(identifier: identifier, attributes: attributes))
    }

    func setSessionId(_ sessionId: String) {
        sessionIDs.append(sessionId)
    }
}

private extension UIView {
    func descendants<T: UIView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview -> [T] in
            var matches = subview.descendants(of: type)
            if let typedSubview = subview as? T {
                matches.insert(typedSubview, at: 0)
            }
            return matches
        }
    }

    func firstDescendant<T: UIView>(of type: T.Type, where predicate: (T) -> Bool) -> T? {
        for descendant in descendants(of: type) where predicate(descendant) {
            return descendant
        }
        return nil
    }
}
