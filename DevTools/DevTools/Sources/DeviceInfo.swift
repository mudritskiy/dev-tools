//
//  DeviceInfo.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 28.05.2026.
//

import Foundation

struct DeviceInfo {
    let size: Int64
    let humanSize: String
    let name: String
    let iOS: String
    let udid: String

    func format() -> String {
        let truncatedName = String(name.prefix(25)).padding(toLength: 25, withPad: " ", startingAt: 0)
        let truncatedIOS = String(iOS.prefix(10)).padding(toLength: 10, withPad: " ", startingAt: 0)
        let truncatedHumanSize = String(humanSize.prefix(10)).padding(toLength: 10, withPad: " ", startingAt: 0)
        let truncatedUDID = String(udid.prefix(40)).padding(toLength: 40, withPad: " ", startingAt: 0)
        return String(
            format: "%@%@%@%@",
            truncatedHumanSize,
            truncatedName,
            truncatedIOS,
            truncatedUDID
        )
    }
}


extension DeviceInfo: Identifiable {
    var id: String {
        udid
    }
}
