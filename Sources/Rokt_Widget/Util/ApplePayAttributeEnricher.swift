import Foundation
import ObjectiveC

// MARK: - Constants (kept file-private or internal as appropriate)

private let passKitClassName = "PKPaymentAuthorizationViewController"
private let canMakePaymentsFunctionName = "canMakePayments"
private let canMakePaymentsWithCardTypeFunctionName = "canMakePaymentsUsingNetworks:"

/// Note these are case sensitive due to the internal checkes used by PassKit.
/// When testing adding new payment networks it's important to validate the name on a physical device with that card setup.
private let requiredPaymentNetworks: NSArray = [
    NSString(string: "Visa"),
    NSString(string: "AmEx"),
    NSString(string: "MasterCard"),
    NSString(string: "Discover")
]

private let BE_IS_APPLE_PAY_CAPABLE_KEY = "applePayCapabilities"
private let BE_IS_NEW_TO_APPLE_PAY_KEY = "newToApplePay"

// MARK: - PassKit Capability Checker Protocol and Implementation

protocol PassKitCapabilityChecker {
    func canDeviceMakePayments() -> Bool
    func canDeviceMakePayments(usingNetworks networks: NSArray) -> Bool
}

/**
 Runtime implementation of PassKit capability checking.

 Uses Objective-C runtime reflection to detect PassKit classes and methods without importing the PassKit framework.

 See [PassKit iOS Documentation](https://developer.apple.com/documentation/passkit/apple-pay).
 */

class RuntimePassKitCapabilityChecker: PassKitCapabilityChecker {

    func canDeviceMakePayments() -> Bool {
        guard let paymentClass = NSClassFromString(passKitClassName) else {
            return false
        }

        let selector = NSSelectorFromString(canMakePaymentsFunctionName)

        guard paymentClass.responds(to: selector) else {
            return false
        }

        guard let method = class_getClassMethod(paymentClass, selector) else {
            return false
        }
        let implementation = method_getImplementation(method)

        typealias CanMakePaymentsIMP = @convention(c) (AnyClass, Selector) -> Bool
        let canMakePaymentsFunction = unsafeBitCast(implementation, to: CanMakePaymentsIMP.self)

        return canMakePaymentsFunction(paymentClass, selector)
    }

    func canDeviceMakePayments(usingNetworks networks: NSArray) -> Bool {
        guard let paymentClass = NSClassFromString(passKitClassName) else {
            return false
        }

        let selector = NSSelectorFromString(canMakePaymentsWithCardTypeFunctionName)

        guard paymentClass.responds(to: selector) else {
            return false
        }

        guard let method = class_getClassMethod(paymentClass, selector) else {
            return false
        }
        let implementation = method_getImplementation(method)

        typealias CanMakePaymentsUsingNetworksIMP = @convention(c) (AnyClass, Selector, NSArray) -> Bool
        let canMakePaymentsFunction = unsafeBitCast(implementation, to: CanMakePaymentsUsingNetworksIMP.self)

        return canMakePaymentsFunction(paymentClass, selector, networks)
    }
}

// MARK: - ApplePayAttributeEnricher

/**
 Detects Apple Pay integration availability using runtime reflection.

 Enriches attributes sent to Rokt's backend to customize user experience based on payment capabilities.

 - Returns:
  - `false` for `applePayCapabilities` when Apple Pay is not available.
  - `true` for `applePayCapabilities` when Apple Pay is available.
  - `true` for `newToApplePay` when Apple Pay is available and the user has no cards setup.
  - `false` for `newToApplePay` when Apple Pay is not available or Apple Pay is available and the user has cards setup.
  - neither key when capability hasn't resolved yet (see `warmUp()`).

 `canDeviceMakePayments()` performs synchronous IPC with the system daemon (`passd`) and Secure
 Element, which can block the calling thread for over a second on first use, so it must never run
 on `enrich(config:)`'s caller (frequently the host app's main thread, via `Rokt.selectPlacements`).
 `warmUp()` resolves it once on a background queue, at SDK initialization; `enrich(config:)` only
 ever reads the cached result. If `enrich(config:)` is called before `warmUp()` has resolved, it
 omits both attributes rather than guessing a value.
 */

class ApplePayAttributeEnricher: AttributeEnricher {
    private let capabilityChecker: PassKitCapabilityChecker
    private let backgroundQueue: DispatchQueue
    private let cacheLock = NSLock()
    private var cachedIsCapable: Bool?
    private var cachedHasSpecificCardsSetup: Bool?

    init(
        capabilityChecker: PassKitCapabilityChecker = RuntimePassKitCapabilityChecker(),
        backgroundQueue: DispatchQueue = DispatchQueue(label: "com.rokt.applePayAttributeEnricher", qos: .utility)
    ) {
        self.capabilityChecker = capabilityChecker
        self.backgroundQueue = backgroundQueue
    }

    func enrich(config: RoktConfig?) -> [String: String] {
        cacheLock.lock()
        let isSDKCapable = cachedIsCapable
        let hasSpecificCardsSetup = cachedHasSpecificCardsSetup
        cacheLock.unlock()

        guard let isSDKCapable else {
            return [:]
        }

        return [
            BE_IS_APPLE_PAY_CAPABLE_KEY: String(isSDKCapable),
            BE_IS_NEW_TO_APPLE_PAY_KEY: String(isSDKCapable && !(hasSpecificCardsSetup ?? false))
        ]
    }

    func warmUp() {
        let checker = capabilityChecker
        backgroundQueue.async { [weak self] in
            let isCapable = checker.canDeviceMakePayments()
            let hasSpecificCardsSetup = isCapable
                ? checker.canDeviceMakePayments(usingNetworks: requiredPaymentNetworks)
                : false

            guard let self else { return }
            self.cacheLock.lock()
            self.cachedIsCapable = isCapable
            self.cachedHasSpecificCardsSetup = hasSpecificCardsSetup
            self.cacheLock.unlock()
        }
    }
}
