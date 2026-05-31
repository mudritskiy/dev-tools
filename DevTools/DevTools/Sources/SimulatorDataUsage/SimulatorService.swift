//
//  Sources.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 28.05.2026.
//

import SwiftUI

actor SimulatorDataService {
    // MARK: - Directory Size
    func directorySize(url: URL) -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return (total / 1_000) * 1_000
    }

    // MARK: - Format Size
    func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.isAdaptive = false

        let raw = formatter.string(fromByteCount: size)
        let parts = raw.split(separator: " ").map(String.init)
        guard parts.count == 2,
              let value = Double(parts[0].replacingOccurrences(of: ",", with: "."))
        else { return raw }
        return String(format: "%.2f %@", value, parts[1])
    }

    // MARK: - Simulator Info
    func getSimulatorInfo() -> [DeviceInfo] {
        let fm = FileManager.default
        let simulatorsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices").path

        guard fm.fileExists(atPath: simulatorsPath),
              let entries = try? fm.contentsOfDirectory(atPath: simulatorsPath) else {
            print("❌ Simulator directory not found: \(simulatorsPath)")
            return []
        }

        var deviceInfos: [DeviceInfo] = []
        let availabilityMap = _fetchAvailabilityMap()
        
        for udid in entries {
            let devicePath = (simulatorsPath as NSString).appendingPathComponent(udid)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: devicePath, isDirectory: &isDir), isDir.boolValue else { continue }

            let size = directorySize(url: URL(fileURLWithPath: devicePath))
//            guard size > 100_000_000 else { continue }

            // Read device.plist — written by CoreSimulator, always present
            let plistURL = URL(fileURLWithPath: devicePath).appendingPathComponent("device.plist")
            let plist    = NSDictionary(contentsOf: plistURL)

            let deviceName = plist?["name"] as? String ?? "Unknown"

            // runtime value looks like "com.apple.CoreSimulator.SimRuntime.iOS-17-0"
            let runtime    = plist?["runtime"] as? String ?? ""
            let iOSVersion = runtime
                .components(separatedBy: "iOS-").last?
                .replacingOccurrences(of: "-", with: ".") ?? "unknown"

            let isAvailable = availabilityMap[udid] ?? false

            deviceInfos.append(DeviceInfo(
                size: size,
                humanSize: formatSize(size),
                name: deviceName,
                iOS: iOSVersion,
                udid: udid,
                isAvailableToErase: isAvailable
            ))
        }

        return deviceInfos
    }
    
    func _fetchAvailabilityMap() -> [String: Bool] {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["simctl", "list", "devices", "-j"]
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtimes = json["devices"] as? [String: [[String: Any]]]
        else { return [:] }

        var map: [String: Bool] = [:]
        for (_, deviceList) in runtimes {
            for device in deviceList {
                guard let udid = device["udid"] as? String else { continue }
                let isAvailable = device["isAvailable"] as? Bool ?? false
                let state = device["state"] as? String ?? ""
                map[udid] = isAvailable && state != "Creating"
            }
        }
        return map
    }
}
