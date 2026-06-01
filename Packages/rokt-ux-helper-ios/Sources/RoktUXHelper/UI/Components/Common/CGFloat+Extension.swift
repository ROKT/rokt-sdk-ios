import Foundation

extension CGFloat {
    func precised(_ value: Int = 2) -> CGFloat {
        (self * pow(10.0, CGFloat(value))).rounded()/pow(10.0, CGFloat(value))
    }
}
