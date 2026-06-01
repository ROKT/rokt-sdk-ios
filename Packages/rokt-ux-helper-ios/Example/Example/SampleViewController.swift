//
//  SampleVC.swift
//  Example
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import RoktUXHelper
import SwiftUI
import SafariServices
import UIKit

class SampleViewController: UIViewController {

    private var roktView: RoktLayoutUIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
    }

    @objc func setupView() {
        view.backgroundColor = .white
        guard let experience = String.getExperienceResponse(for: "experience") else {
            return
        }

        RoktUX.setLogLevel(.verbose)
        let roktView = RoktLayoutUIView(
            experienceResponse: experience,
            location: "#target_element" // "targetElementSelector" in experience JSON file
        ) { [weak self] uxEvent in
            guard let self else { return }

            // Handle open URL event
            // Here is a sample how to open different types of URLs
            if let event = uxEvent as? RoktUXEvent.OpenUrl,
               let url = URL(string: event.url) {
                switch event.type {
                case .externally:
                    UIApplication.shared.open(url) { _ in
                        event.onClose?(event.id)
                    }
                default:
                    let safariVC = SFSafariViewController(url: url)
                    safariVC.modalPresentationStyle = .pageSheet
                    present(safariVC, animated: true) {
                        event.onClose?(event.id)
                    }
                }
            } else if uxEvent is RoktUXEvent.LayoutCompleted {
                dismiss(animated: true)
            }

            // Mock the host SDK round-trip for the PayPal device-pay flow.
            // Real flow: rokt-sdk-ios calls /v1/cart/initialize-purchase, opens the PayPal URL,
            // and on auth posts back the breakdown. We fake a 1.5s network delay and ship a
            // hard-coded breakdown so the layout renders the confirmation screen end-to-end.
            if let devicePay = uxEvent as? RoktUXEvent.CartItemDevicePay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.roktView?.devicePayShowConfirmation(
                        layoutId: devicePay.layoutId,
                        catalogItemId: devicePay.catalogItemId,
                        catalogRuntimeData: [
                            "subtotal": "$24.00",
                            "tax": "$1.94",
                            "shipping": "$0.00",
                            "total": "$26.72"
                        ]
                    )
                }
            } else if let forward = uxEvent as? RoktUXEvent.CartItemForwardPayment {
                // Real flow: rokt-sdk-ios calls /purchase to finalize. Here we just succeed
                // after a short delay so the existing paymentResult==1 success screen shows.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.roktView?.forwardPaymentFinalized(
                        layoutId: forward.layoutId,
                        catalogItemId: forward.catalogItemId,
                        success: true
                    )
                }
            }

        } onPlatformEvent: { _ in
            // Send these platform events to Rokt API
        }

        self.roktView = roktView
        view.addSubview(roktView)

        roktView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            roktView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            roktView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roktView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roktView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            roktView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

extension SampleViewController: RoktUXImageLoader {

    func loadImage(urlString: String, completion: @escaping (Result<UIImage?, any Error>) -> Void) {
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            DispatchQueue.main.async {
                completion(.success(UIImage(data: data)))
            }
        }

        task.resume()
    }
}

struct SampleVCRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UIViewController {
        SampleViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
