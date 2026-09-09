import Foundation

/// Shape check for the connected-account id a payment preparation supplies. The id
/// becomes the account scope of the extension's Stripe requests for that payment, so
/// a value that does not look like a Stripe account id fails the payment before any
/// client is configured with it.
enum StripeAccountId {
    private static let prefix = "acct_"
    private static let maxSuffixLength = 64

    static func isValid(_ id: String) -> Bool {
        guard id.hasPrefix(prefix) else { return false }
        let suffix = id.dropFirst(prefix.count)
        guard !suffix.isEmpty, suffix.count <= maxSuffixLength else { return false }
        return suffix.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
    }
}
