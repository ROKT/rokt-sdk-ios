import Foundation
import RoktContracts
import UIKit

extension RoktAPIHelper {
    static let noFunctionalKey = "noFunctional"
    static let noTargetingKey = "noTargeting"
    static let doNotShareOrSellKey = "doNotShareOrSell"
    static let gpcEnabledKey = "gpcEnabled"
    static let attributesPageInitKey = "pageinit"

    /// Extracts all privacy control KVPs from the partner's attributes and combines them with the
    /// flags set through ``Rokt/setPrivacyControl(_:)``. Opt-out wins: a flag is `true` if either
    /// source says `true`, `false` if either says `false`, and left out when neither sets it.
    /// - Parameters:
    ///   - attributes: a hashmap of additional information sent by the partner
    ///   - privacyControl: the merged flags configured via ``Rokt/setPrivacyControl(_:)``
    /// - Returns: a hashmap of all privacy KVP sent by the partner
    class func getPrivacyControlPayload(
        attributes: [String: Any],
        privacyControl: RoktPrivacyControl? = nil
    ) -> [String: Bool] {
        var payload: [String: Bool] = [:]
        if let castedAttrs = attributes as? [String: String] {
            for privacyKey in [noFunctionalKey, noTargetingKey, doNotShareOrSellKey, gpcEnabledKey] {
                if let parsed = parseCaseInsensitiveBool(in: castedAttrs, forKey: privacyKey) {
                    payload[privacyKey] = parsed
                }
            }
        }

        payload[noFunctionalKey] = optOutWins(
            setter: privacyControl?.noFunctional?.boolValue,
            perCall: payload[noFunctionalKey]
        )
        payload[noTargetingKey] = optOutWins(
            setter: privacyControl?.noTargeting?.boolValue,
            perCall: payload[noTargetingKey]
        )
        payload[doNotShareOrSellKey] = optOutWins(
            setter: privacyControl?.doNotShareOrSell?.boolValue,
            perCall: payload[doNotShareOrSellKey]
        )

        return payload
    }

    /// `true` if either source opts out, else `false` if either sets the flag, else `nil`.
    class func optOutWins(setter: Bool?, perCall: Bool?) -> Bool? {
        if setter == true || perCall == true { return true }
        if setter == false || perCall == false { return false }
        return nil
    }

    private class func parseCaseInsensitiveBool(
        in attributes: [String: String],
        forKey targetKey: String
    ) -> Bool? {
        var sawFalse = false
        for (key, rawValue) in attributes where key.caseInsensitiveCompare(targetKey) == .orderedSame {
            guard let parsed = Bool(rawValue.lowercased()) else { continue }
            if parsed {
                return true
            }
            sawFalse = true
        }
        return sawFalse ? false : nil
    }

    class func getPageInitData(attributes: [String: Any]) -> String? {
        guard let castedAttrs = attributes as? [String: String] else { return nil }
        if let exact = castedAttrs[attributesPageInitKey] {
            return exact
        }
        return castedAttrs.first { $0.key.caseInsensitiveCompare(attributesPageInitKey) == .orderedSame }?.value
    }

    /// Removes all privacy control KVPs from partner attributes
    /// - Parameter attributes: a hashmap of additional information sent by the partner
    /// - Returns: partner `attributes` without privacy control and pageInit KVPs
    class func removePrivacyControlAttributes(attributes: [String: String]) -> [String: String] {
        let strippedKeys = [
            noFunctionalKey,
            noTargetingKey,
            doNotShareOrSellKey,
            gpcEnabledKey,
            attributesPageInitKey
        ]

        return attributes.filter { entry in
            !strippedKeys.contains { $0.caseInsensitiveCompare(entry.key) == .orderedSame }
        }
    }
}
