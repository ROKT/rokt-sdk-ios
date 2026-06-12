import Foundation

extension TxnInitResponse {
    private static let clientTimeoutFlag = "client-timeout-ms"

    // Adapts the v2 response into the legacy InitRespose so downstream init is unchanged.
    // timeout 0 lets the caller keep its existing default; delay and clientSessionTimeout
    // are intentionally dropped (v2 session lifetime is governed by the JWT expiry).
    func toInitRespose(featureFlags: InitFeatureFlags) -> InitRespose {
        InitRespose(
            timeout: self.featureFlags.int(forKey: Self.clientTimeoutFlag).map(Double.init) ?? 0,
            delay: 0,
            clientSessionTimeout: nil,
            fonts: fonts.map {
                FontModel(name: $0.fontName, url: $0.fontURL, postScriptName: $0.fontPostScriptName)
            },
            featureFlags: featureFlags
        )
    }
}
