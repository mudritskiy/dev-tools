//
//  Formatters.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 01.06.2026.
//

import Foundation

extension ByteCountFormatter {
    static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.isAdaptive = false
        return formatter
    }()
}
