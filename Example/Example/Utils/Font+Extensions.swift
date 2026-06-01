//
//  Font+Extensions.swift
//  Example
//
//  Licensed under the Rokt Software Development Kit (SDK) Terms of Use
//  Version 2.0 (the "License");
//
//  You may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at https://rokt.com/sdk-license-2-0/

import SwiftUI

extension Font {

    static func defaultFont(_ fontSize: FontSize) -> Font {
        return defaultFont(size: fontSize.rawValue)
    }

    static func defaultButtonFont() -> Font {
        return defaultBoldFont(size: 18)
    }

    static func defaultHeadingFont(_ fontSize: FontSize) -> Font {
        return defaultHeadingFont(size: fontSize.rawValue)
    }

    static func defaultBoldFont(_ fontSize: FontSize) -> Font {
        return defaultBoldFont(size: fontSize.rawValue)
    }

    static func defaultFont(size: CGFloat) -> Font {
        return .custom("Archivo-Regular", size: size)
    }

    static func defaultBoldFont(size: CGFloat) -> Font {
        return .custom("Archivo-SemiBold", size: size)
    }

    static func defaultHeadingFont(size: CGFloat) -> Font {
        return .custom("balto-bold", size: size)
    }

    static func arialFont(size: CGFloat, isBold: Bool = false) -> Font {
        return .custom(isBold ? "Arial-BoldMT" : "ArialMT", size: size)
    }

    static func latoFont(size: CGFloat, isBold: Bool = false) -> Font {
        return .custom(isBold ? "Lato-Bold" : "Lato", size: size)
    }
}

public enum FontSize: CGFloat {
    case header1 = 32
    case header2 = 28
    case header3 = 18
    case title = 22
    case button = 20
    case text = 16
    case subtitle1 = 14
    case subtitle2 = 12
}
