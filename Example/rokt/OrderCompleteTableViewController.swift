import Foundation
import UIKit
import Rokt_Widget

class OrderCompleteTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var attributes: [String: String]!
    var pageIdentifier: String!
    var location: String!
    @IBOutlet weak var table: UITableView!

    var roktWidget: RoktEmbeddedView?

    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        // Do any additional setup after loading the view.
        table.reloadData()
        table.allowsSelection = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        showPlacement()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "roktCell") as? RoktCell {
            if roktWidget == nil {
                roktWidget = cell.roktWidget
            }
            return cell
        }
        return UITableViewCell()
    }

    private func showPlacement() {
        let placements: [String: RoktEmbeddedView] = [location: roktWidget!, "Location2": roktWidget!]
        Rokt.selectPlacements(
            identifier: pageIdentifier,
            attributes: attributes, placements: placements,
            onEvent: { event in
                self.onRoktEvent(roktEvent: event)
            }
        )
    }

    private func onRoktEvent(roktEvent: RoktEvent) {

        print("Received Rokt event \(roktEvent)")
        
        if roktEvent is RoktEvent.EmbeddedSizeChanged {
            onEmbeddedSizeChange()
        }
    }
    private func onEmbeddedSizeChange() {

        self.table.beginUpdates()
        self.table.endUpdates()
    }
}
