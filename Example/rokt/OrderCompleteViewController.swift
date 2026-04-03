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

    override func viewDidLoad() {
        super.viewDidLoad()
        locationLabel.text = location
        // sample of creating RoktEmbeddedView programmatically
        let location4: RoktEmbeddedView = RoktEmbeddedView(frame: CGRect(x: 15, y: 200, width: view.bounds.width - 30, height: 0))

        contentView.addSubview(location4)

        Rokt.events(identifier: pageIdentifier) {roktEvent in
            print("Received Rokt on event \(roktEvent)")
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

    private func showPlacemnt(location4: RoktEmbeddedView) {
        let placements: [String: RoktEmbeddedView] = [location: location1,
                                                      "Location2": location2,
                                                      "Location3": location3,
                                                      "Location4": location4]
        Rokt.selectPlacements(
            identifier: pageIdentifier,
            attributes: attributes, placements: placements,
            onEvent: {roktEvent in
                self.onRoktEvent(roktEvent: roktEvent)
            }
        )
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
    }

    private func onRoktEvent(roktEvent: RoktEvent) {

        print("Received Rokt event \(roktEvent)")
    }
}
