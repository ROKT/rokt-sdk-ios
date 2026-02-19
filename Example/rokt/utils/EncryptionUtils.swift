import Foundation
import CommonCrypto

public extension String {

    func encryptRSA(publicKey: String) -> String? {

        let keyString = publicKey.replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----\n", with: "")
            .replacingOccurrences(of: "\n-----END PUBLIC KEY-----", with: "")
        guard let keyData = Data(base64Encoded: keyString) else { return nil }

        var attributes: CFDictionary {
            return [kSecAttrKeyType: kSecAttrKeyTypeRSA,
                    kSecAttrKeyClass: kSecAttrKeyClassPublic,
                    kSecAttrKeySizeInBits: 2048,
                    kSecReturnPersistentRef: kCFBooleanTrue ?? true as Any] as CFDictionary
        }

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes, &error) else {
            return nil
        }
        return encryptRSA(publicKey: secKey)
    }

    func encryptRSA(publicKey: SecKey) -> String? {
        let error: UnsafeMutablePointer<Unmanaged<CFError>?>? = nil

        if let stringData = self.data(using: .utf8),
           let encryptedMessageData: Data = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionOAEPSHA256,
                                                                      stringData as CFData, error) as Data? {
            return encryptedMessageData.base64EncodedString()
        }
        return nil
    }
}
