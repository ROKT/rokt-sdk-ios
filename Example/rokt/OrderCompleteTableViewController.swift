import Foundation
import UIKit
import Rokt_Widget

class OrderCompleteTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var attributes: [String: String]!
    var pageIdentifier: String!
    var location: String!
    @IBOutlet weak var table: UITableView!

    var roktWidget: RoktEmbeddedView?
    private var hasRequestedPlacement = false

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

        // The embedded view is a table cell, which exists only after viewDidLoad. viewDidAppear runs
        // again on every reappearance and each selectPlacements call starts a new selection, so request once.
        guard !hasRequestedPlacement else { return }
        hasRequestedPlacement = true
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
