//
//  Sources.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 28.05.2026.
//

import Combine
import SwiftUI

@MainActor
@Observable
final class SimulatorDataViewModel {
    var selectedTableItems = Set<String>()
    private(set) var selectedItems = Set<String>()
    /*private(set)*/ var devices: [DeviceInfo] = []
    private(set) var isLoading = false

    private let _dataService: SimulatorDataService

    init(dataService: SimulatorDataService) {
        _dataService = dataService
    }
    
    func toggle(_ id: String) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
    
    func onSpaceTap() {
        guard let item = selectedTableItems.first else { return }
        toggle(item)
    }

    func load() {
        isLoading = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                await self._dataService.getSimulatorInfo().sorted { $0.size > $1.size }
            }.value
            devices = result
            isLoading = false
        }
    }
    
    func delete() {
        for deviceId in selectedItems {
            Task {
                do {
                    try await delete(udid: deviceId)
                }
            }
        }
    }

    func erase() {
        for deviceId in selectedItems {
            Task {
                do {
                    try await erase(udid: deviceId)
                }
            }
        }
    }

    func delete(udid: String) async throws {
        try await _runSimctl(args: ["delete", udid])
        devices.removeAll { $0.udid == udid }
    }

    func erase(udid: String) async throws {
        let isValid = await _isRuntimeValid(udid: udid)
        guard isValid else { return }
        
        try? await _runSimctl(args: ["shutdown", udid])
        try await _runSimctl(args: ["erase", udid])
    }
    
    private func _isRuntimeValid(udid: String) async -> Bool {
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices")
            .appendingPathComponent(udid)
            .appendingPathComponent("device.plist")
        let plist = NSDictionary(contentsOf: plistURL)
        let runtime = plist?["runtime"] as? String ?? ""
        // runtime is missing or marked unavailable
        return !runtime.isEmpty && !runtime.contains("unavailable")
    }
    
    func sort(using sortOrder: [KeyPathComparator<DeviceInfo>]) {
        devices.sort(using: sortOrder)
    }

    private func _runSimctl(args: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            task.arguments = ["simctl"] + args
            task.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SimctlError.failed(code: process.terminationStatus))
                }
            }
            do    { try task.run() }
            catch { continuation.resume(throwing: error) }
        }
    }
}

enum SimctlError: Error {
    case failed(code: Int32)
}

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
        return total
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

            deviceInfos.append(DeviceInfo(
                size: size,
                humanSize: formatSize(size),
                name: deviceName,
                iOS: iOSVersion,
                udid: udid
            ))
        }

        return deviceInfos
    }
}
