//
//  ButtonDefaultOutlined.swift
//  Example
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import SwiftUI

struct ButtonDefaultOutlined: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(.white)
            .padding()
            .font(.defaultButtonFont())
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(Color.appColor)
            .cornerRadius(100)
    }
}
