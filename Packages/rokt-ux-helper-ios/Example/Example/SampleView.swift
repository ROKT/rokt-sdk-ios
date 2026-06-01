//
//  SampleView.swift
//  Example
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import Foundation
import SwiftUI
import RoktUXHelper

import SafariServices

struct SampleView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: SampleViewModel = .init()

    let onLayoutFailure: (() -> Void)?

    init(onLayoutFailure: (() -> Void)? = nil) {
        self.onLayoutFailure = onLayoutFailure
    }

    var body: some View {
        RoktLayoutView(
            experienceResponse: vm.experienceResponse,
            location: "#target_element", // "targetElementSelector" in experience JSON file
            config: RoktUXConfig.Builder().colorMode(.system).imageLoader(vm).build()
        ) { uxEvent in
            if uxEvent is RoktUXEvent.LayoutCompleted {
                dismiss()
            } else if uxEvent is RoktUXEvent.LayoutFailure {
                onLayoutFailure?()
                dismiss()
            } else if let uxEvent = (uxEvent as? RoktUXEvent.OpenUrl) {
                // Handle open URL event
                vm.handleURL(uxEvent)
            }
            // Handle UX events here

        } onPlatformEvent: { _ in
            // Send these platform events to Rokt API
        }.sheet(item: $vm.urlToOpen) {
            SafariWebView(url: $0)
        }
    }
}

#Preview {
    SampleView()
}
