import SwiftUI

@available(iOS 15, *)
extension Color {
    init(hex: String?) {
        if let hex {
            self.init(uiColor: UIColor(hexString: hex))
        } else {
            self.init(.clear)
        }
    }
}
