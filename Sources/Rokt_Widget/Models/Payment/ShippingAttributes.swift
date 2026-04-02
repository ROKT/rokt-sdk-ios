import Foundation

struct ShippingAttributes {
    let address1: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let address2: String?
    let firstName: String?
    let lastName: String?
    let companyName: String?
    let countryCode: String?

    init(
        address1: String,
        city: String,
        state: String,
        postalCode: String,
        country: String,
        address2: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        companyName: String? = nil,
        countryCode: String? = nil
    ) {
        self.address1 = address1
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.address2 = address2
        self.firstName = firstName
        self.lastName = lastName
        self.companyName = companyName
        self.countryCode = countryCode
    }

    // periphery:ignore - only used from payment preparation path (see PaymentOrchestrator periphery notes)
    /// Creates ShippingAttributes from a RoktContracts ContactAddress.
    init(from contactAddress: ContactAddress) {
        let nameParts = contactAddress.name.split(separator: " ", maxSplits: 1)
        let firstName = nameParts.first.map(String.init)
        let lastName = nameParts.count > 1 ? String(nameParts[1]) : nil

        self.init(
            address1: contactAddress.addressLine1 ?? "",
            city: contactAddress.city ?? "",
            state: contactAddress.state ?? "",
            postalCode: contactAddress.postalCode ?? "",
            country: contactAddress.country ?? "",
            firstName: firstName,
            lastName: lastName
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "address1": address1,
            "city": city,
            "state": state,
            "country": country,
            "postalCode": postalCode
        ]

        if let firstName { dict["firstName"] = firstName }
        if let lastName { dict["lastName"] = lastName }
        if let companyName { dict["companyName"] = companyName }
        if let address2 { dict["address2"] = address2 }
        if let countryCode { dict["countryCode"] = countryCode }

        return dict
    }
}
