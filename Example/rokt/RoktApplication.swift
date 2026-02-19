import UIKit

class RoktApplication: UIApplication {

#if compiler(>=6)
    override func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:],
                       completionHandler completion: (@MainActor (Bool) -> Void)? = nil) {
        if !options.isEmpty {
            print("Open URL with options: \(options)")
            if let isRokt = options[.isRokt] as? Bool,
               isRokt {
                print("Open URL from Rokt is enabled")
                super.open(url, options: [:], completionHandler: completion)
                return
            }
        }
        super.open(url, options: options, completionHandler: completion)
    }
#else
    override func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:],
                       completionHandler completion: ((Bool) -> Void)? = nil) {
        if !options.isEmpty {
            print("Open URL with options: \(options)")
            if let isRokt = options[.isRokt] as? Bool,
               isRokt {
                print("Open URL from Rokt is enabled")
                super.open(url, options: [:], completionHandler: completion)
                return
            }
        }
        super.open(url, options: options, completionHandler: completion)

    }
#endif
}

public extension UIApplication.OpenExternalURLOptionsKey {
    static let isRokt: UIApplication.OpenExternalURLOptionsKey = .init(rawValue: "isRokt")
}
