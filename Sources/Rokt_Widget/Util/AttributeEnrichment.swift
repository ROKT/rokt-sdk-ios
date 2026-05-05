import Foundation
import UIKit

protocol AttributeEnricher {
    func enrich(config: RoktConfig?) -> [String: String]
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
}
