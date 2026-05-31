//
//  SimulatorDataViewModel.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 31.05.2026.
//

import SwiftUI

@MainActor
@Observable
final class SimulatorDataViewModel {
    var sortOrder = [KeyPathComparator(\DeviceInfo.size, order: .reverse)]
    var selectedTableItems = Set<String>()
    private(set) var selectedItems = Set<String>()  { didSet { updateInfo() } }
    var devices: [DeviceInfo] = []
    private(set) var isLoading = false
    var isHiddenEmptyDevces: Bool = true
    var isHiddenUnableToEraseDevces: Bool = true
    var isDeleteAlertPresented: Bool = false
    var isEraseAlertPresented: Bool = false
    
    @ObservationIgnored let textsFactory = SimulatorTextsFactory()

    private let _dataService: SimulatorDataService
    
    var visibleDevices: [DeviceInfo] {
        devices.filter {
            if isHiddenEmptyDevces, $0.size < 20_000_000 {
                return false
            } else if isHiddenUnableToEraseDevces, !$0.isAvailableToErase {
                return false
            } else {
                return true
            }
        }
    }

    init(dataService: SimulatorDataService) {
        _dataService = dataService
    }
    
    func onViewReady() {
        load()
    }
    
    func toggle(_ id: String) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
    
    func onSpaceTap() {
        for item in  selectedTableItems {
            toggle(item)
        }
    }

    func load() {
        isLoading = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                await self._dataService.getSimulatorInfo()
            }.value
            devices = result
            selectedItems.removeAll()
            sort(using: sortOrder)
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
        var finalOrders = sortOrder

        let keyPath: PartialKeyPath<DeviceInfo> = \.humanSize
        if finalOrders.firstIndex(where: { $0.keyPath == keyPath }) != nil {
            // Replace existing comparator at the same priority level
            let newOrder = [KeyPathComparator(\DeviceInfo.size, order: .forward)]
            finalOrders = newOrder
//            finalOrders[index] = KeyPathComparator(keyPath, order: newOrder)
//        } else {
//            // Otherwise, insert as primary sort
//            finalOrders.insert(KeyPathComparator(keyPath, order: newOrder), at: 0)
        }
        
        // Keep user choice first, then append fallbacks
        let fallbacks = [
            KeyPathComparator(\DeviceInfo.name, order: .forward),
            KeyPathComparator(\DeviceInfo.iOS, order: .forward)
        ]
        
        // Append only if not already controlled by user
        for fallback in fallbacks where !finalOrders.contains(where: { $0.keyPath == fallback.keyPath }) {
            finalOrders.append(fallback)
        }
        devices.sort(using: finalOrders)
    }
    
    var summaryText: String = ""
    var generalSizeText: String = ""
    
    func updateInfo() {
        Task {
            await _updateSummaryText()
            await _updateGeneralText()
        }
    }
    
    private func _updateSummaryText() async {
        let devices = self.devices.filter { selectedItems.contains($0.udid) }
        guard !devices.isEmpty else {
            summaryText = ""
            return
        }
        
        let size = devices.reduce(0) { $0 + $1.size }
        let formattedSize = await _dataService.formatSize(size)
        summaryText = formattedSize //"Selected \(selectedItems.count) devices to be handled. This can free up to \(formattedSize)"
    }

    private func _updateGeneralText() async {
        guard !devices.isEmpty else {
            generalSizeText = ""
            return
        }
        let size = devices.reduce(0) { $0 + $1.size }
        let formattedSize = await _dataService.formatSize(size)
        generalSizeText = formattedSize
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

struct SimulatorTextsFactory {
    let headerTitle = "Simulator Disk Usage"
    let headerSubtitle = "View storage used by installed iOS simulators and remove/erase simulators you no longer need to free disk space."
    let headerAnnotation = "The size shown includes data stored by the simulator, such as installed apps, caches, logs, and device data. \nDeleting a simulator permanently removes its data and cannot be undone."
    
    func actionText(count: Int) -> String {
        "Will be deleted \(count) devices.\nThis action cannot be undone."
    }
    
}
