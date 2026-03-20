import Foundation
internal import RoktUXHelper

// MARK: - RoktConfig SDK Extensions

extension RoktConfig {
    @available(iOS 15, *)
    func getUXConfig() -> RoktUXConfig {
        let builder = RoktUXConfig.Builder().logLevel(RoktLogger.shared.logLevel.toUXLogLevel())
        switch self.colorMode {
        case .light:
            _ = builder.colorMode(.light)
        case .dark:
            _ = builder.colorMode(.dark)
        default:
            _ = builder.colorMode(.system)
        }
        return builder.build()
    }
}
