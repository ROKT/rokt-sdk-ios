import Foundation

extension TxnInitResponse {
    private static let clientTimeoutFlag = "client-timeout-ms"

    // Maps init response into InitRespose for downstream init handling.
    func toInitRespose(featureFlags: InitFeatureFlags) -> InitRespose {
        InitRespose(
            timeout: self.featureFlags.int(forKey: Self.clientTimeoutFlag).map(Double.init) ?? 0,
            delay: 0,
            fonts: fonts.map {
                FontModel(name: $0.fontName, url: $0.fontURL, postScriptName: $0.fontPostScriptName)
            },
            featureFlags: featureFlags
        )
    }
}
