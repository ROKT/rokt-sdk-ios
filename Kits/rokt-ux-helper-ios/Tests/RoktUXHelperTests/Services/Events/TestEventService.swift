import XCTest
import DcuiSchema
@testable import RoktUXHelper

@available(iOS 13, *)
final class TestEventService: XCTestCase {
    var events = [RoktEventRequest]()
    var errors = [String]()
    let startDate = Date()
    let responseReceivedDate = Date()
    var stubUXHelper: MockUXHelper!

    override func setUpWithError() throws {
        events = [RoktEventRequest]()
        self.stubUXHelper = MockUXHelper()
    }

    // MARK: Events

    func test_sendEventsOnTransformerSuccess_readyEventsAndLoadCompleteSignals_shouldSend() throws {
        // Arrange
        let eventService = get_mock_event_processor(uxEventDelegate: stubUXHelper, eventHandler: { event in
            self.events.append(event)
        })
        
        // Act
        eventService.sendEventsOnTransformerSuccess()

        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalLoadComplete)
        
        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.PlacementReady))
    }
    
    func test_sendEventsOnLoad_interactiveEventsAndImpressionSignals_shouldSend() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })
        
        // Act
        eventService.sendEventsOnLoad()
        
        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalImpression)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertNotNil(event?.metadata.first{$0.name == BE_PAGE_SIGNAL_LOAD})
        XCTAssertNotNil(event?.metadata.first{$0.value == EventDateFormatter.getDateString(startDate)})
        XCTAssertNotNil(event?.metadata.first{$0.name == BE_PAGE_RENDER_ENGINE})
        XCTAssertNotNil(event?.metadata.first{$0.value == BE_RENDER_ENGINE_LAYOUTS})
        
        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.PlacementInteractive))
    }

    func test_slot_impression_event() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.sendSlotImpressionEvent(instanceGuid: "instanceGuid", jwtToken: "jwt-token")

        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalImpression)
    }

    func test_two_unique_slot_impression_event() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })
        
        // Act
        eventService.sendSlotImpressionEvent(instanceGuid: "instanceGuid1", jwtToken: "jwt-token")
        eventService.sendSlotImpressionEvent(instanceGuid: "instanceGuid2", jwtToken: "jwt-token")

        // Assert
        XCTAssertNotNil(events.first {$0.eventType == .SignalImpression && $0.parentGuid == "instanceGuid1"})
        XCTAssertNotNil(events.first {$0.eventType == .SignalImpression && $0.parentGuid == "instanceGuid2"})
        XCTAssertEqual(events.count, 2)
    }

    func test_plugin_activation_event() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.sendSignalActivationEvent()

        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalActivation)
        XCTAssertEqual(events.first?.pageInstanceGuid, mockPageInstanceGuid)
    }
    
    func test_sendSignalResponse_onPositive_engagementEventsAndSignals_shouldSend() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })
        
        // Act
        eventService.sendSignalResponseEvent(instanceGuid: "instanceGuid", jwtToken: "plugin-token", isPositive: true)

        // Assert
        XCTAssertEqual(events.first?.eventType, .SignalResponse)
        XCTAssertEqual(events.first?.parentGuid, "instanceGuid")
        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 3)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.PositiveEngagement))
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.FirstPositiveEngagement))
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.OfferEngagement))
        XCTAssertEqual(stubUXHelper.sessionId, "session")
        XCTAssertEqual(stubUXHelper.jwtToken, "plugin-config-token")
        XCTAssertEqual(stubUXHelper.pluginInstanceGuid, "pluginInstanceGuid")
        XCTAssertEqual(stubUXHelper.layoutId, "pluginId")
    }

    func test_sendDismissal_onNoMoreOffer_dismissalEventsAndSignals_shouldSend() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.dismissOption = .noMoreOffer
        eventService.sendDismissalEvent()

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalDismissal)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertNotNil(event?.metadata.first{$0.name == kInitiator})
        XCTAssertNotNil(event?.metadata.first{$0.value == kNoMoreOfferToShow})
        
        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.PlacementCompleted))
    }
    
    func test_sendDismissal_onCloseButton_dismissalEventsAndSignals_shouldSend() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })
        
        // Act
        eventService.dismissOption = .closeButton
        eventService.sendDismissalEvent()

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalDismissal)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertNotNil(event?.metadata.first{$0.name == kInitiator})
        XCTAssertNotNil(event?.metadata.first{$0.value == kCloseButton})
        
        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.PlacementClosed))
    }

    func test_sendDismissal_onInstantPurchaseDismissed_dismissalEventsAndSignals_shouldSend() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.dismissOption = .instantPurchaseDismiss
        eventService.sendDismissalEvent()

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalInstantPurchaseDismissal)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertNotNil(event?.metadata.first{$0.name == kInitiator})
        XCTAssertNotNil(event?.metadata.first{$0.value == kInstantPurchaseDismiss})

        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.PlacementClosed))
    }

    func test_dismissal_dimissed_event() throws {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.dismissOption = .defaultDismiss
        eventService.sendDismissalEvent()

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalDismissal)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertNotNil(event?.metadata.first{$0.name == kInitiator})
        XCTAssertNotNil(event?.metadata.first{$0.value == kDismissed})
    }
    
    func test_diagnostic_processing() {
        let expectation = expectation(description: "test diagnostics")
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    useDiagnosticEvents: true,
                                                    eventHandler: { event in
            switch event.eventType {
            case .SignalSdkDiagnostic:
                XCTAssertEqual(event.eventData.first(where: {$0.name == "code" })?.value, "error message")
                XCTAssertEqual(event.eventData.first(where: { $0.name == "stackTrace" })?.value, "stack")
                XCTAssertEqual(event.eventData.first(where: { $0.name == "severity" })?.value, "ERROR")
                expectation.fulfill()
            default:
                XCTFail("Should not be here")
            }
        })
        eventService.sendDiagnostics(message: "error message", callStack: "stack", severity: .error)
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_font_diagnostic_processing() {
        let expectation = expectation(description: "test font diagnostics")
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    useDiagnosticEvents: true,
                                                    eventHandler: { event in
            switch event.eventType {
            case .SignalSdkDiagnostic:
                XCTAssertEqual(event.eventData.first(where: {$0.name == "code" })?.value, "[VIEW]")
                XCTAssertEqual(event.eventData.first(where: { $0.name == "stackTrace" })?.value, "Font family not found: Arial")
                XCTAssertEqual(event.eventData.first(where: { $0.name == "severity" })?.value, "ERROR")
                expectation.fulfill()
            default:
                XCTFail("Should not be here")
            }
        })
        eventService.sendFontDiagnostics("Arial")
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_diagnostic_processing_disabled() {
        let expectation = expectation(description: "test diagnostics")
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    useDiagnosticEvents: false,
                                                    eventHandler: { event in
            switch event.eventType {
            default:
                expectation.fulfill()
            }
        })
        eventService.sendDiagnostics(message: "error message", callStack: "stack", severity: .error)
        let result = XCTWaiter().wait(for: [expectation], timeout: 2)
        XCTAssertEqual(result, .timedOut, "The test should time out since the expectation was not fulfilled.")
    }

    func test_openURL_containsCorrectLayoutId() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    useDiagnosticEvents: false,
                                                    eventHandler: { event in
            switch event.eventType {
            default:
                XCTFail("Should not be here")
            }
        })

        eventService.openURL(url: URL(string: "https://www.rokt.com")!, type: .passthrough, completionHandler: {})

        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.OpenUrl))
        XCTAssertEqual(stubUXHelper.layoutId, "pluginId")
        XCTAssertEqual(stubUXHelper.url, "https://www.rokt.com")
        XCTAssertEqual(stubUXHelper.openUrlType, .passthrough)
    }

    func test_send_instant_purchase_initiated() {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.cartItemInstantPurchase(catalogItem: .mock())

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalCartItemInstantPurchaseInitiated)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertEqual(event?.parentGuid, "catalogInstanceGuid")
        XCTAssertTrue(event?.eventData.isEmpty == true)

        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.CartItemInstantPurchase))
    }

    func test_send_instant_purchase_succeeded() {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.cartItemInstantPurchaseSuccess(itemId: "catalogItemId")

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalCartItemInstantPurchase)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertEqual(event?.parentGuid, "catalogInstanceGuid")
        XCTAssertTrue(event?.eventData.isEmpty == true)

        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 0)
    }

    func test_send_instant_purchase_failed() {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [
                                                        .mock(catalogItemId: "xyz"),
                                                        .mock(catalogItemId: "catalogItemId")
                                                    ],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.cartItemInstantPurchaseFailure(itemId: "catalogItemId")

        // Assert
        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalCartItemInstantPurchaseFailure)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertEqual(event?.parentGuid, "catalogInstanceGuid")
        XCTAssertTrue(event?.eventData.isEmpty == true)

        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 0)
    }

    func test_given_no_catalogItems_then_send_nothing() {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        // Act
        eventService.cartItemInstantPurchaseSuccess(itemId: "catalogItemId")
        eventService.cartItemInstantPurchaseFailure(itemId: "catalogItemId")

        // Assert
        XCTAssertEqual(events.count, 0)

        // Rokt callbacks
        XCTAssertEqual(stubUXHelper.roktEvents.count, 0)
    }

    /// After the two-step flow has transitioned to .pendingConfirmation (devicePayCompletion
    /// cleared), a late cartItemDevicePaySuccess from the SDK must NOT emit SignalCartItemInstantPurchase
    /// — the Step-2 forwardPayment* signals own the terminal state, and double-emitting would
    /// double-count the purchase in analytics.
    func test_devicePaySuccess_afterPendingConfirmation_doesNotEmitInstantPurchaseSignal() {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })
        eventService.cartItemDevicePay(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            paymentProvider: .paypal,
            transactionData: nil,
            completion: { _ in }
        )
        eventService.cartItemDevicePayPendingConfirmation(
            itemId: "catalogItemId",
            catalogRuntimeData: ["total": "USD 10.00"]
        )
        events.removeAll()

        // Act
        eventService.cartItemDevicePaySuccess(itemId: "catalogItemId")
        eventService.cartItemDevicePayFailure(itemId: "catalogItemId")

        // Assert: no terminal device-pay signal emitted after pendingConfirmation cleared the completion.
        XCTAssertFalse(events.contains { $0.eventType == .SignalCartItemInstantPurchase })
        XCTAssertFalse(events.contains { $0.eventType == .SignalCartItemInstantPurchaseFailure })
    }

    /// One-step Apple-Pay-style flow: devicePayCompletion is still pending when the SDK reports
    /// success, so SignalCartItemInstantPurchase must fire and the completion must be invoked.
    func test_devicePaySuccess_whenCompletionPending_emitsInstantPurchaseSignalAndInvokesCompletion() {
        // Arrange
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })
        var completionStatus: DevicePayStatus?
        eventService.cartItemDevicePay(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            paymentProvider: .applePay,
            transactionData: nil,
            completion: { status in completionStatus = status }
        )
        events.removeAll()

        // Act
        eventService.cartItemDevicePaySuccess(itemId: "catalogItemId")

        // Assert
        XCTAssertTrue(events.contains { $0.eventType == .SignalCartItemInstantPurchase })
        if case .success = completionStatus {} else {
            XCTFail("Expected completion to fire with .success, got \(String(describing: completionStatus))")
        }
    }

    func test_device_pay_duplicate_call_short_circuits_with_failure_while_processing() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        var firstStatus: DevicePayStatus?
        var firstCount = 0
        var secondStatus: DevicePayStatus?
        var secondCount = 0
        eventService.cartItemDevicePay(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            paymentProvider: .applePay,
            transactionData: nil,
            completion: { status in firstCount += 1; firstStatus = status }
        )
        let initiatedAfterFirst = events.filter { $0.eventType == .SignalCartItemInstantPurchaseInitiated }.count
        let delegateAfterFirst = stubUXHelper.roktEvents.filter { $0 == .CartItemDevicePay }.count

        eventService.cartItemDevicePay(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            paymentProvider: .applePay,
            transactionData: nil,
            completion: { status in secondCount += 1; secondStatus = status }
        )

        XCTAssertEqual(
            events.filter { $0.eventType == .SignalCartItemInstantPurchaseInitiated }.count,
            initiatedAfterFirst,
            "duplicate device-pay call must not emit a second SignalCartItemInstantPurchaseInitiated"
        )
        XCTAssertEqual(
            stubUXHelper.roktEvents.filter { $0 == .CartItemDevicePay }.count,
            delegateAfterFirst,
            "duplicate device-pay call must not re-invoke the UX-event delegate"
        )
        XCTAssertEqual(secondCount, 1, "duplicate call must invoke its completion so the caller can reset")
        guard case .failure = secondStatus else {
            return XCTFail("expected .failure for dropped call, got \(String(describing: secondStatus))")
        }

        eventService.cartItemDevicePaySuccess(itemId: "catalogItemId")

        XCTAssertEqual(firstCount, 1, "first completion still fires on success")
        guard case .success = firstStatus else {
            return XCTFail("expected .success for first completion, got \(String(describing: firstStatus))")
        }
    }

    func test_send_forward_payment_initiated() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        let transactionData = TransactionData(
            shippingAddress: nil,
            billingAddress: nil,
            paymentType: nil,
            supportedPaymentMethods: nil,
            isPartnerManagedPurchase: false,
            partnerPaymentReference: "ref-1",
            confirmationRef: nil,
            metadata: [:]
        )
        eventService.cartItemForwardPayment(
            catalogItem: .mock(),
            transactionData: transactionData,
            completion: { _ in }
        )

        let event = events.first
        XCTAssertEqual(event?.eventType, .SignalCartItemInstantPurchaseInitiated)
        XCTAssertEqual(event?.pageInstanceGuid, mockPageInstanceGuid)
        XCTAssertEqual(event?.parentGuid, "catalogInstanceGuid")

        XCTAssertEqual(stubUXHelper.roktEvents.count, 1)
        XCTAssertTrue(stubUXHelper.roktEvents.contains(.CartItemForwardPayment))
        XCTAssertEqual(stubUXHelper.forwardPaymentTransactionData?.partnerPaymentReference, "ref-1")
    }

    func test_send_forward_payment_success_invokes_completion_without_emitting_event() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        var capturedStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { capturedStatus = $0 }
        )
        events.removeAll()

        eventService.cartItemForwardPaymentSuccess(itemId: "catalogItemId")

        XCTAssertTrue(events.isEmpty, "success should not emit a platform event; backend emits it")

        guard case .success = capturedStatus else {
            return XCTFail("expected success status, got \(String(describing: capturedStatus))")
        }
    }

    func test_send_forward_payment_failure_invokes_completion_without_emitting_event() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        var capturedStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { capturedStatus = $0 }
        )
        events.removeAll()

        eventService.cartItemForwardPaymentFailure(itemId: "catalogItemId", failureReason: "card declined")

        XCTAssertTrue(events.isEmpty, "failure should not emit a platform event; backend emits it")

        guard case .failure(let reason) = capturedStatus else {
            return XCTFail("expected failure status, got \(String(describing: capturedStatus))")
        }
        XCTAssertEqual(reason, "card declined")
    }

    func test_forward_payment_synchronous_host_finalization_invokes_completion() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { _ in })

        stubUXHelper.onForwardPaymentInvoked = { [weak eventService] _, catalogItem in
            eventService?.cartItemForwardPaymentSuccess(itemId: catalogItem.catalogItemId)
        }

        var capturedStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { capturedStatus = $0 }
        )

        guard case .success = capturedStatus else {
            return XCTFail("expected success, got \(String(describing: capturedStatus))")
        }

        var secondStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { secondStatus = $0 }
        )
        XCTAssertNotNil(secondStatus, "second attempt should not be blocked by stale completion")
    }

    func test_forward_payment_completion_only_invoked_once() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { _ in })

        var invocationCount = 0
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { _ in invocationCount += 1 }
        )

        eventService.cartItemForwardPaymentSuccess(itemId: "catalogItemId")
        eventService.cartItemForwardPaymentSuccess(itemId: "catalogItemId")
        eventService.cartItemForwardPaymentFailure(itemId: "catalogItemId", failureReason: "late")

        XCTAssertEqual(invocationCount, 1)
    }

    func test_forward_payment_duplicate_call_is_ignored_while_processing() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { event in
            self.events.append(event)
        })

        var firstCount = 0
        var secondCount = 0
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { _ in firstCount += 1 }
        )
        let eventsAfterFirst = events.count

        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { _ in secondCount += 1 }
        )

        XCTAssertEqual(events.filter { $0.eventType == .SignalCartItemInstantPurchaseInitiated }.count, eventsAfterFirst)

        eventService.cartItemForwardPaymentSuccess(itemId: "catalogItemId")

        XCTAssertEqual(firstCount, 1, "first completion should still fire")
        XCTAssertEqual(secondCount, 0, "duplicate completion should be dropped")
    }

    func test_forward_payment_success_with_unknown_itemId_unlocks_completion() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { _ in })

        var capturedStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { capturedStatus = $0 }
        )

        eventService.cartItemForwardPaymentSuccess(itemId: "unknownItemId")

        guard case .failure = capturedStatus else {
            return XCTFail("expected failure for unknown itemId, got \(String(describing: capturedStatus))")
        }

        var secondStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { secondStatus = $0 }
        )
        eventService.cartItemForwardPaymentSuccess(itemId: "catalogItemId")

        guard case .success = secondStatus else {
            return XCTFail("subsequent attempt should succeed after prior completion cleared")
        }
    }

    func test_forward_payment_failure_with_unknown_itemId_unlocks_completion() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { _ in })

        var capturedStatus: ForwardPaymentStatus?
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { capturedStatus = $0 }
        )

        eventService.cartItemForwardPaymentFailure(itemId: "unknownItemId", failureReason: "nope")

        guard case .failure(let reason) = capturedStatus else {
            return XCTFail("expected failure for unknown itemId, got \(String(describing: capturedStatus))")
        }
        XCTAssertEqual(reason, "nope")
    }

    func test_forward_payment_completion_cleared_on_dismissal() {
        let eventService = get_mock_event_processor(startDate: startDate,
                                                    catalogItems: [.mock(catalogItemId: "catalogItemId")],
                                                    uxEventDelegate: stubUXHelper,
                                                    eventHandler: { _ in })

        var invocationCount = 0
        eventService.cartItemForwardPayment(
            catalogItem: .mock(catalogItemId: "catalogItemId"),
            transactionData: nil,
            completion: { _ in invocationCount += 1 }
        )

        eventService.sendDismissalEvent()

        eventService.cartItemForwardPaymentSuccess(itemId: "catalogItemId")

        XCTAssertEqual(invocationCount, 0)
    }
}

class MockUXHelper: UXEventsDelegate {
    
    var roktEvents = [RoktEventListenerType]()
    
    func onOfferEngagement(_ pluginId: String) {
        self.roktEvents.append(.OfferEngagement)
    }
    
    var sessionId: String?
    var pluginInstanceGuid: String?
    var jwtToken: String?
    var layoutId: String?
    var url: String?
    var openUrlType: RoktUXOpenURLType?
    func onFirstPositiveEngagement(sessionId: String, pluginInstanceGuid: String, jwtToken: String, layoutId: String) {
        self.sessionId = sessionId
        self.pluginInstanceGuid = pluginInstanceGuid
        self.jwtToken = jwtToken
        self.layoutId = layoutId
        self.roktEvents.append(.FirstPositiveEngagement)
    }
    
    func onPositiveEngagement(_ pluginId: String) {
        self.roktEvents.append(.PositiveEngagement)
    }
    
    func onShowLoadingIndicator(_ pluginId: String) {
        self.roktEvents.append(.ShowLoadingIndicator)
    }
    
    func onHideLoadingIndicator(_ pluginId: String) {
        self.roktEvents.append(.HideLoadingIndicator)
    }
    
    func onPlacementInteractive(_ pluginId: String) {
        self.roktEvents.append(.PlacementInteractive)
    }
    
    func onPlacementReady(_ pluginId: String) {
        self.roktEvents.append(.PlacementReady)
    }
    
    func onPlacementClosed(_ pluginId: String) {
        self.roktEvents.append(.PlacementClosed)
    }
    
    func onPlacementCompleted(_ pluginId: String) {
        self.roktEvents.append(.PlacementCompleted)
    }
    
    func onPlacementFailure(_ pluginId: String) {
        self.roktEvents.append(.PlacementFailure)
    }
    
    func openURL(url: String,
                 id: String,
                 layoutId: String,
                 type: RoktUXOpenURLType,
                 onClose: @escaping (String) -> Void,
                 onError: @escaping (String, Error?) -> Void) {
        self.roktEvents.append(.OpenUrl)
        self.layoutId = layoutId
        self.url = url
        self.openUrlType = type
    }
    
    func onCartItemInstantPurchase(_ layoutId: String, catalogItem: RoktUXHelper.CatalogItem) {
        self.roktEvents.append(.CartItemInstantPurchase)
    }

    func onCartItemDevicePay(_ layoutId: String,
                             catalogItem: RoktUXHelper.CatalogItem,
                             paymentProvider: DcuiSchema.PaymentProvider,
                             transactionData: TransactionData?) {
        self.roktEvents.append(.CartItemDevicePay)
    }

    var forwardPaymentTransactionData: TransactionData?
    var onForwardPaymentInvoked: ((_ layoutId: String, _ catalogItem: RoktUXHelper.CatalogItem) -> Void)?
    func onCartItemForwardPayment(_ layoutId: String,
                                  catalogItem: RoktUXHelper.CatalogItem,
                                  transactionData: TransactionData?) {
        self.roktEvents.append(.CartItemForwardPayment)
        self.forwardPaymentTransactionData = transactionData
        onForwardPaymentInvoked?(layoutId, catalogItem)
    }
}
