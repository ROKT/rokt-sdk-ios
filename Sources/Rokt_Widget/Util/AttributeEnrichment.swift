import Foundation
import UIKit

protocol AttributeEnricher {
    func enrich(config: RoktConfig?) -> [String: String]

    /// Resolves anything `enrich(config:)` needs but must not block its caller to compute.
    /// Called once, at SDK initialization, before any `enrich(config:)` call. Most enrichers
    /// have nothing to resolve ahead of time and use the default no-op below.
    func warmUp()
}

extension AttributeEnricher {
    func warmUp() {}
}

struct AttributeEnrichment {
    static let shared: AttributeEnrichment = AttributeEnrichment(enrichers: [
        ApplePayAttributeEnricher(),
        ColorModeAttributeEnricher(),
        StripeAttributeEnricher(),
        PaymentExtensionAttributeEnricher(
            provider: { Rokt.shared.roktImplementation.isPaymentExtensionRegistered },
            availablePaymentMethodsProvider: { Rokt.shared.roktImplementation.availablePaymentMethods }
        )
    ])
    let enrichers: [AttributeEnricher]

    func enrich(attributes: [String: String], config: RoktConfig?) -> [String: String] {
        var enrichedAttributes = attributes
        for enricher in enrichers {
            let newAttributes = enricher.enrich(config: config)
            enrichedAttributes.merge(newAttributes) { (_, new) in new }
        }

        return enrichedAttributes
    }

    func warmUp() {
        enrichers.forEach { $0.warmUp() }
    }
}
