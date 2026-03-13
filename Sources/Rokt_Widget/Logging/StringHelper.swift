import Foundation

/// String helper class to get localized versions of strings
class StringHelper {
    class func localizedStringFor(_ key: String, comment: String) -> String {
        NSLocalizedString(key, bundle: Bundle.module, comment: comment)
    }
}
