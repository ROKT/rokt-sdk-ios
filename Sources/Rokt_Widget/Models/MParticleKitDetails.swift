import Foundation

class MParticleKitDetails: NSObject {
    let sdkVersion: String
    let kitVersion: String

    init(sdkVersion: String, kitVersion: String) {
        self.sdkVersion = sdkVersion
        self.kitVersion = kitVersion
    }
}
