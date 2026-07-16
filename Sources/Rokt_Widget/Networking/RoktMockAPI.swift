import Foundation

internal class RoktMockAPI {

    class func downloadFonts(_ fonts: [FontModel]) {}

    class func sendEvent(paramsArray: [[String: Any]],
                         sessionId: String?,
                         success: (() -> Void)? = nil,
                         failure: ((Error, Int?, String) -> Void)? = nil) {
        do {
            let params = try JSONSerialization.data(withJSONObject: paramsArray, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
        success?()
    }

    class func sendDiagnostics(params: [String: Any],
                               success: (() -> Void)? = nil,
                               failure: ((Error, Int?, String) -> Void)? = nil) {
        do {
            let params = try JSONSerialization.data(withJSONObject: params, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
        success?()
    }

    class func initializePurchase(upsellItems: [UpsellItem],
                                  shippingAttributes: ShippingAttributes? = nil,
                                  returnURL: String? = nil,
                                  cancelURL: String? = nil,
                                  paymentMethodType: String? = nil,
                                  paymentProvider: String? = nil,
                                  success: ((InitializePurchaseResponse) -> Void)? = nil,
                                  failure: ((Error, Int?, String) -> Void)? = nil) {
        _ = (returnURL, cancelURL, paymentMethodType, paymentProvider, shippingAttributes, failure)
        let mockResponse = InitializePurchaseResponse(
            success: true,
            totalUpsellPrice: upsellItems.reduce(Decimal.zero) { $0 + $1.totalPrice },
            currency: upsellItems.first?.currency ?? "USD",
            upsellItems: upsellItems,
            paymentDetails: PaymentDetails(
                gateway: "stripe",
                merchantName: "Mock Merchant",
                merchantAccountId: "acct_mock_123",
                paymentIntentId: "pi_mock_1234567890",
                clientSecret: "pi_mock_1234567890_secret_mock",
                shippingCost: 0,
                tax: 0,
                totalAmount: upsellItems.reduce(Decimal.zero) { $0 + $1.totalPrice }
            ),
            paypalData: nil
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            success?(mockResponse)
        }
    }

    class func forwardPayment(request: PurchaseRequest,
                              success: ((PurchaseResponse) -> Void)? = nil,
                              failure: ((Error, Int?, String) -> Void)? = nil) {
        do {
            let params = try JSONSerialization.data(
                withJSONObject: request.toDictionary(),
                options: []
            )
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch let error {
            failure?(error, nil, error.localizedDescription)
            return
        }
        let mockResponse = PurchaseResponse(success: true, reason: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            success?(mockResponse)
        }
    }

    class func sendTimings(timingsRequest: TimingsRequest, selectionId: String) {
        do {
            var requestData = timingsRequest.toDictionary()
            requestData["selectionId"] = selectionId
            let params = try JSONSerialization.data(withJSONObject: requestData, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
    }

    class func sendTimingEvents(timingEventsRequest: TimingEventsRequest, selectionId: String) {
        do {
            var requestData = timingEventsRequest.toDictionary()
            requestData["selectionId"] = selectionId
            let params = try JSONSerialization.data(withJSONObject: requestData, options: [])
            RoktLogger.shared.verbose(String(bytes: params, encoding: .utf8) ?? "")
        } catch {}
    }
}
