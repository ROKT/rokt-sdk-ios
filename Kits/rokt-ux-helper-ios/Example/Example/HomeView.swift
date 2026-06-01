//
//  HomeView.swift
//  Example
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import SwiftUI
import RoktUXHelper

struct HomeView: View {

    @State private var isShowingSwiftUIView = false
    @State private var isShowingUIKitView = false
    @State private var showToast = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                VStack {
                    Image("RoktLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, alignment: .center)
                        .padding(.top, 100)

                    Text("Seize the Transaction Moment")
                        .font(.defaultFont(.header3))
                        .foregroundColor(.titleColor)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()

                    Button {
                        isShowingSwiftUIView = true
                    } label: {
                        Text("Load SwiftUI")
                    }
                    .padding(.top)
                    .buttonStyle(ButtonDefaultOutlined())

                    Button {
                        isShowingUIKitView = true
                    } label: {
                        Text("Load UIKit")
                    }
                    .padding(.top)
                    .buttonStyle(ButtonDefaultOutlined())

                    Spacer()
                    Text("® Rokt 2024 — All rights reserved")
                        .font(.defaultFont(.subtitle2))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.textColor)
                        .padding(.bottom)
                        .padding(.top, 48)
                }
                .padding()

                // Toast overlay
                if showToast {
                    LayoutFailureToastView(showToast: $showToast)
                }
            }

        }
        .background(Color.white)
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $isShowingSwiftUIView) {
            SampleView(onLayoutFailure: {
                showToastMessage()
            })
        }
        .sheet(isPresented: $isShowingUIKitView) {
            SampleVCRepresentable()
        }
    }

    private func showToastMessage() {
        withAnimation(.easeIn(duration: 0.3)) {
            showToast = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

struct LayoutFailureToastView: View {
    @Binding var showToast: Bool
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("Layout failed to load")
                    .font(.defaultFont(.subtitle1))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                showToast = false
                            }
                        }
                    }
                Spacer()
            }
            .padding(.bottom, 100)
        }
        .transition(.opacity)
    }
}
