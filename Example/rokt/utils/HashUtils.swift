import Foundation
import CommonCrypto

extension Data {
    public func sha256() -> String {
        return hexStringFromData(input: digest(input: self as NSData))
    }

    private func digest(input: NSData) -> NSData {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(input.bytes, UInt32(input.length), &hash)
        return NSData(bytes: hash, length: Int(CC_SHA256_DIGEST_LENGTH))
    }

    private func hexStringFromData(input: NSData) -> String {
        var bytes = [UInt8](repeating: 0, count: input.length)
        input.getBytes(&bytes, length: input.length)

        return bytes.map { String(format: "%02x", UInt8($0))}.joined()
    }
}

public extension String {
    func sha256() -> String {
        return self.data(using: String.Encoding.utf8)?.sha256() ?? ""
    }

}
