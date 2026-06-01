//
//  SampleVM.swift
//  Example
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import Combine
import Foundation
import RoktUXHelper
import SwiftUI

class SampleViewModel: ObservableObject {

    let experienceResponse: String = String.getExperienceResponse(for: "experience")!

    @Published var urlToOpen: URL?
    private var cancellable: AnyCancellable?

    func handleURL(_ event: RoktUXEvent.OpenUrl) {
        // Here is a sample how to open different types of URLs
        guard let url = URL(string: event.url) else {
            event.onError?("Fail to load URL", nil)
            return
        }
        switch event.type {
        case .externally:
            UIApplication.shared.open(url)
        default:
            urlToOpen = url
        }
        event.onClose?(event.id)
    }
}

extension SampleViewModel: RoktUXImageLoader {

    func loadImage(
        urlString: String,
        completion: @escaping (Result<UIImage?, any Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(RoktUXError.imageLoading(reason: "Fail to download")))
            return
        }
        cancellable = Just(url)
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .tryMap { try Data(contentsOf: $0) }
            .receive(on: RunLoop.main)
            .sink { result in
                if case let .failure(error) = result {
                    completion(.failure(error))
                }
            } receiveValue: {
                completion(.success(UIImage(data: $0)))
            }
    }
}
