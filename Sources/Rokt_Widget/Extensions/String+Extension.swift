import Foundation
import CryptoKit

extension String {
    public func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        return CryptoKit.SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
