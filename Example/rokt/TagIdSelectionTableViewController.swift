import UIKit
import Rokt_Widget
import AppTrackingTransparency

let tagIdCellIdentifier = "tagIdCell"

class TagIdSelectionTableViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    var roktTagIds = [String]()
    var roktTagTitles = [String]()
    @IBOutlet weak var environmentPicker: UIPickerView!
    @IBOutlet weak var tagIdPicker: UIPickerView!
    @IBOutlet weak var customTagIdLabel: UILabel!
    @IBOutlet weak var customTagIdTextField: UITextField!
    var roktTags: [RoktTag] = [RoktTag]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setTagIds(.Stage)
        title = "Rokt Tag Selection"
        customTagIdTextField.delegate = self
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cartVC = segue.destination as? CartViewController {
            cartVC.pageIdentifier = roktTags[tagIdPicker.selectedRow(inComponent: 0)].pageIdentifier
            cartVC.environment = Environment.all[environmentPicker.selectedRow(inComponent: 0)]
        }
    }

    func setTagIds(_ environment: Environment) {
        roktTags = [RoktTag]()
        roktTags.append(RoktTag(id: "1", name: "Custom", pageIdentifier: "test"))
        switch environment {
        case .Stage:
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff1111",
                name: "Layout playground",
                pageIdentifier: "RoktLayout"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8213",
                name: "Layout overlay",
                pageIdentifier: "RoktLayout"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc48444333222",
                name: "Layout bottomSheet",
                pageIdentifier: "TestView1"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8214",
                name: "Layout overlay1",
                pageIdentifier: "TestView2"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8215",
                name: "Layout Carousel",
                pageIdentifier: "TestView2"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8216",
                name: "Layout Grouped",
                pageIdentifier: "Grouped"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8300",
                name: "Layout Embedded1",
                pageIdentifier: "TestView3"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8302",
                name: "Layout Embedded2",
                pageIdentifier: "TestView4"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8453",
                name: "Layout Mutiple1",
                pageIdentifier: "TestView5"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8411",
                name: "Layout Mutiple2",
                pageIdentifier: "TestView6"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_3331d443712b433587bc4813b8ff8777",
                name: "Layout Embedded4",
                pageIdentifier: "TestView7"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_ab489c69bb9f4ab2ab972e117bd7e555",
                name: "Lightbox",
                pageIdentifier: "iOSLightbox"
            ))
            roktTags.append(RoktTag(
                id: "2731619347947643042_22bde905d7f14db8a6e4fab89210b124",
                name: "QA",
                pageIdentifier: "iOSEmailQA"
            ))
        case .Prod, .ProdDemo:
            roktTags.append(RoktTag(id: "2754655826098840951", name: "Layout Overlay", pageIdentifier: "RoktLayout"))
            roktTags.append(RoktTag(
                id: "2754655826098840951",
                name: "Layout BottomSheet",
                pageIdentifier: "iOSTemplateBottomSheet"
            ))
            roktTags.append(RoktTag(id: "2754655826098840951", name: "Layout Embedded", pageIdentifier: "iOSTemplateEmbedded"))
            roktTags.append(RoktTag(id: "2754655826098840951", name: "MobileTeam LightBox", pageIdentifier: "tesLightboxiOS"))
            roktTags.append(RoktTag(id: "2754655826098840951", name: "MobileTeam Embedded", pageIdentifier: "testiOS"))
            roktTags.append(RoktTag(id: "2754655826098840951", name: "MobileTeam Overlay", pageIdentifier: "iOSOverlay"))
            roktTags.append(RoktTag(id: "2754655826098840951", name: "MobileTeam BottomSheet", pageIdentifier: "iOSBottomSheet"))
            roktTags.append(RoktTag(
                id: "2754655826098840951",
                name: "MobileTeam Multiple1",
                pageIdentifier: "TwoiOStestLboxAndE"
            ))
            roktTags.append(RoktTag(id: "2754655826098840951", name: "MobileTeam Multiple2", pageIdentifier: "testTwoEmbedded"))
            roktTags.append(RoktTag(id: "338", name: "Rent Resume", pageIdentifier: "RentResume"))
            roktTags.append(RoktTag(id: "338", name: "Rent Enquire", pageIdentifier: "RentEnquire"))
        default: break
        }
        tagIdPicker.reloadAllComponents()
    }

    func setEnvironment(_ environment: Environment) {
        switch environment {
        case .Stage: Rokt.setEnvironment(environment: .Stage)
        case .Prod: Rokt.setEnvironment(environment: .Prod)
        case .ProdDemo: Rokt.setEnvironment(environment: .ProdDemo)
        case .Local: Rokt.setEnvironment(environment: .Local)
        }
    }

    @IBAction func initialRokt(_ sender: Any) {
        let selectedRow = tagIdPicker.selectedRow(inComponent: 0)
        let selectedTag = selectedRow == 0 ? customTagIdTextField.text ?? "" : roktTags[selectedRow].id
        Rokt.globalEvents { roktEvent in
            if let initEvent = roktEvent as? RoktEvent.InitComplete {
                print("Received Rokt global event InitComplete with status: \(initEvent.success)")
            } else {
                print("Received Rokt global event \(roktEvent)")
            }
        }
        Rokt.initWith(roktTagId: selectedTag)
    }

    @IBAction func getTrackingConsent(_ sender: Any) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .notDetermined:
                    Toast.show("notDetermined", viewController: self)
                case .restricted:
                    Toast.show("restricted", viewController: self)
                case .denied:
                    Toast.show("denied", viewController: self)
                case .authorized:
                    Toast.show("authorized", viewController: self)
                @unknown default:
                    Toast.show("unknown", viewController: self)
                }
            }
        } else {
            Toast.show("Below iOS 14!! not supported", viewController: self)
        }
    }

    private func showAlert(_ message: String, viewController: UIViewController) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    // MARK: Picker view

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == environmentPicker {
            return Environment.all.count
        } else {
            return roktTags.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == environmentPicker {
            return Environment.names[row]
        } else {
            return roktTags[row].name
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == environmentPicker {
            let selectedEnvironment = Environment.all[row]
            setEnvironment(selectedEnvironment)
            setTagIds(selectedEnvironment)
        } else {
            // hide if the selected row is not custom
            customTagIdLabel.isHidden = row != 0
            customTagIdTextField.isHidden = row != 0
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }

}
