//
//  DeviceInfo.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 28.05.2026.
//

import SwiftUI

struct DeviceInfo {
    let size: Int64
    let humanSize: String
    let name: String
    let iOS: String
    let udid: String
    let isAvailableToErase: Bool
}

// MARK: - Identifiable
extension DeviceInfo: Identifiable {
    var id: String { udid }
}

// MARK: - UI Details
extension DeviceInfo {
    var sizeColor: Color {
        switch size {
            case let size where size > 10_000_000_000: .red
            case let size where size > 1_000_000_000: .orange
            default: .primary
        }
    }
    
    var sizeFont: Font {
        switch size {
            case let size where size > 1_000_000_000: .callout
            default: .subheadline
        }
    }
}
