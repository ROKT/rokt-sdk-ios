import UIKit
import SwiftUI

class CartViewController: UIViewController, UITextFieldDelegate {
    var pageIdentifier: String!
    var environment: Environment!
    @IBOutlet weak var customerEmailTextField: UITextField!
    @IBOutlet weak var pageIdentifierTextField: UITextField!
    @IBOutlet weak var countryTextField: UITextField!
    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var ageNameTextField: UITextField!
    @IBOutlet weak var ageValueTextField: UITextField!
    @IBOutlet weak var genderNameTextField: UITextField!
    @IBOutlet weak var genderValueTextField: UITextField!
    @IBOutlet weak var customNameTextField: UITextField!
    @IBOutlet weak var customValueTextField: UITextField!
    @IBOutlet weak var customNameTextField2: UITextField!
    @IBOutlet weak var customValueTextField2: UITextField!
    @IBOutlet weak var customNameTextField3: UITextField!
    @IBOutlet weak var customValueTextField3: UITextField!
    @IBOutlet weak var isEventSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        let backItem = UIBarButtonItem()
        backItem.title = "Cart"
        navigationItem.backBarButtonItem = backItem
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        pageIdentifierTextField.text = pageIdentifier
        customerEmailTextField.text = "j.smith\(Int64(Date().timeIntervalSince1970 * 1000))@rokt.com"
        if environment == .Prod {
            customNameTextField.text = "sandbox"
            customValueTextField.text = "true"
        }

        customerEmailTextField.delegate = self
        pageIdentifierTextField.delegate = self
        countryTextField.delegate = self
        locationTextField.delegate = self
        ageNameTextField.delegate = self
        ageValueTextField.delegate = self
        genderNameTextField.delegate = self
        genderValueTextField.delegate = self
        customNameTextField.delegate = self
        customValueTextField.delegate = self
        customNameTextField2.delegate = self
        customValueTextField2.delegate = self
        customNameTextField3.delegate = self
        customValueTextField3.delegate = self

    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let attributes = getAttributes()
        if let orderVC = segue.destination as? OrderCompleteViewController {
            orderVC.attributes = attributes
            orderVC.pageIdentifier = pageIdentifierTextField.text
            orderVC.location = locationTextField.text
        }
        if let orderVC = segue.destination as? OrderCompleteTableViewController {
            orderVC.attributes = attributes
            orderVC.pageIdentifier = pageIdentifierTextField.text
            orderVC.location = locationTextField.text
        }
    }

    private func getAttributes() -> [String: String] {
        var attributes = ["mobile": "1112223333"]
        attributes["email"] = customerEmailTextField.text
        attributes["firstname"] = "Jenny"
        attributes["lastname"] = "Smith"

        if let country = countryTextField.text, !country.isEmpty {
            attributes["country"] = country
        }
        if let ageName = ageNameTextField.text,
            let ageValue = ageValueTextField.text,
            !ageName.isEmpty && !ageValue.isEmpty {
            attributes[ageName] = ageValue
        }
        if let genderName = genderNameTextField.text,
            let genderValue = genderValueTextField.text,
            !genderName.isEmpty && !genderValue.isEmpty {
            attributes[genderName] = genderValue
        }
        if let customName = customNameTextField.text,
            let customValue = customValueTextField.text,
            !customName.isEmpty && !customValue.isEmpty {
            attributes[customName] = customValue
        }
        if let customName2 = customNameTextField2.text,
            let customValue2 = customValueTextField2.text,
            !customName2.isEmpty && !customValue2.isEmpty {
            attributes[customName2] = customValue2
        }
        if let customName3 = customNameTextField3.text,
            let customValue3 = customValueTextField3.text,
            !customName3.isEmpty && !customValue3.isEmpty {
            attributes[customName3] = customValue3
        }
        return attributes
    }

    @IBAction func navigateToLayoutSwiftUI(_ sender: Any) {
        if #available(iOS 15.0, *) {
            let swiftUIViewController =
            UIHostingController(rootView:
                                    OrderCompleteSwiftUI(attributes: getAttributes(),
                                                         pageIndentifier: pageIdentifierTextField.text ?? "",
                                                         location: locationTextField.text ?? "",
                                                         isEvents: isEventSwitch.isOn))
            self.navigationController?.pushViewController(swiftUIViewController, animated: true)
        } else {
            Toast.show("This feature is supported in iOS 15 and above", viewController: self)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
}
