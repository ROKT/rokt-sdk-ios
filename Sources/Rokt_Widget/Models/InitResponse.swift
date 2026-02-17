import Foundation

struct InitRespose {
    let timeout: Double
    let delay: Double
    let clientSessionTimeout: Double?
    let fonts: [FontModel]
    let featureFlags: InitFeatureFlags
}
