import UIKit
import Rokt_Widget
import SVProgressHUD

class OrderCompleteViewController: UIViewController {
    var attributes: [String: String]!
    var pageIdentifier: String!
    var location: String!

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var location1: RoktEmbeddedView!
    @IBOutlet weak var location2: RoktEmbeddedView!
    @IBOutlet weak var location3: RoktEmbeddedView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    var location1Height: CGFloat = 0
    var location2Height: CGFloat = 0
    var location3Height: CGFloat = 0
    var location4Height: CGFloat = 0
    private let contentHeight: CGFloat = 300

    /// Set by an automated run to add the on-screen transcript a UI test reads.
    var showsAutomationTranscript = false
    private weak var location4View: RoktEmbeddedView?

    override func viewDidLoad() {
        super.viewDidLoad()
        locationLabel.text = location
        // sample of creating RoktEmbeddedView programmatically
        let location4: RoktEmbeddedView = RoktEmbeddedView(frame: CGRect(x: 15, y: 200, width: view.bounds.width - 30, height: 0))

        contentView.addSubview(location4)
        location4View = location4
        installAutomationIdentifiers(location4: location4)
        if showsAutomationTranscript {
            installAutomationTranscriptView()
        }

        Rokt.events(identifier: pageIdentifier) {roktEvent in
            print("Received Rokt on event \(roktEvent)")
            AutomationTranscript.shared.record(roktEvent)
            if let event = roktEvent as? RoktEvent.EmbeddedSizeChanged {
                print("Updated height: \(event.updatedHeight)")
                self.onEmbeddedSizeChange(selectedPlacement: event.identifier, widgetHeight: event.updatedHeight)
            } else if roktEvent is RoktEvent.ShowLoadingIndicator {
                self.onShouldShowLoadingIndicator()
            } else if roktEvent is RoktEvent.HideLoadingIndicator {
                self.onShouldHideLoadingIndicator()
            }
        }

        showPlacemnt(location4: location4)
    }

    /// Addresses the embedded views from the accessibility tree so a UI test can read the height
    /// the host actually settled at, independently of the height the SDK published.
    private func installAutomationIdentifiers(location4: RoktEmbeddedView) {
        location1?.accessibilityIdentifier = "rokt-embedded-Location1"
        location2?.accessibilityIdentifier = "rokt-embedded-Location2"
        location3?.accessibilityIdentifier = "rokt-embedded-Location3"
        location4.accessibilityIdentifier = "rokt-embedded-Location4"
    }

    private func installAutomationTranscriptView() {
        let transcriptView = UITextView()
        transcriptView.isEditable = false
        transcriptView.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        transcriptView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transcriptView)
        NSLayoutConstraint.activate([
            transcriptView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transcriptView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transcriptView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            transcriptView.heightAnchor.constraint(equalToConstant: 120)
        ])
        AutomationTranscript.shared.attach(to: transcriptView)
    }

    private func showPlacemnt(location4: RoktEmbeddedView) {
        Rokt.setBuiltInPayPalRedirectURLScheme("myapp")

        let placements: [String: RoktEmbeddedView] = [location: location1,
                                                      "Location2": location2,
                                                      "Location3": location3,
                                                      "Location4": location4]
        let placementAttributes = attributesForSelectPlacements()
        Rokt.selectPlacements(
            identifier: pageIdentifier,
            attributes: placementAttributes,
            placements: placements,
            onEvent: {roktEvent in
                self.onRoktEvent(roktEvent: roktEvent)
            }
        )
    }

    // Sample defaults for order-complete placements; cart `attributes` override on key overlap.
    private func attributesForSelectPlacements() -> [String: String] {
        var base: [String: String] = [
            "email": "j.smith1777386131757@rokt.com",
            "firstname": "Jenny",
            "lastname": "Smith",
            "billingzipcode": "07762",
            "confirmationref": "ORD-12345",
            "paymenttype": "ApplePay",
            "last4digits": "4444",
            "country": "US",
            "sandbox": "true",
            "applePayCapabilities": "true",
            "shippingaddress1": "123 Main St",
            "shippingaddress2": "Apt 4B",
            "shippingcity": "New York",
            "shippingstate": "NY",
            "shippingzipcode": "10001",
            "shippingcountry": "US"
        ]
        base.merge(attributes) { _, fromCart in fromCart }
        return base
    }

    private func onShouldShowLoadingIndicator() {
        print("onShouldShowLoadingIndicator")
        SVProgressHUD.show()
    }

    private func onShouldHideLoadingIndicator() {
        print("onShouldHideLoadingIndicator")
        SVProgressHUD.dismiss()
    }

    private func onEmbeddedSizeChange(selectedPlacement: String, widgetHeight: CGFloat) {
        switch selectedPlacement {
        case self.location:
            self.location1Height = widgetHeight
        case "Location2":
            self.location2Height = widgetHeight
        case "Location3":
            self.location3Height = widgetHeight
        case "Location4":
            self.location4Height = widgetHeight
        default:
            break
        }
        print("\(selectedPlacement) : \(widgetHeight)")
        self.scrollViewHeight.constant = self.contentHeight + self.location1Height +
        self.location2Height + self.location3Height + self.location4Height
        recordObservedHeights()
    }

    /// The heights the host's own views settled at after applying the published height. Recorded
    /// next to it so a published height that never arrives shows up as a divergence rather than
    /// as silence.
    private func recordObservedHeights() {
        view.layoutIfNeeded()
        AutomationTranscript.shared.record("HostHeights", [
            "scrollViewHeight": scrollViewHeight.constant,
            "Location1": location1?.bounds.height ?? -1,
            "Location2": location2?.bounds.height ?? -1,
            "Location3": location3?.bounds.height ?? -1,
            "Location4": location4View?.bounds.height ?? -1
        ])
    }

    private func onRoktEvent(roktEvent: RoktEvent) {

        print("Received Rokt event \(roktEvent)")
    }
}
