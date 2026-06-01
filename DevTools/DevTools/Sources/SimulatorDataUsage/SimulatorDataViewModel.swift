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
    private(set) var selectedItems = Set<String>()  { didSet { _updateInfo() } }

    private(set) var isLoading = false

    var isHiddenEmptyDevces: Bool = true
    var isHiddenUnableToEraseDevces: Bool = true
    var isDeleteAlertPresented: Bool = false
    var isEraseAlertPresented: Bool = false
    var summaryText: String = ""
    var generalSizeText: String = ""

    let textsFactory = SimulatorTextsFactory()

    private var _devices: [DeviceInfo] = []
    private let _dataService: SimulatorDataService
    
    var visibleDevices: [DeviceInfo] {
        _devices.filter {
            if isHiddenEmptyDevces, $0.size < 20_000_000 {
                return false
            } else if isHiddenUnableToEraseDevces, !$0.isAvailableToErase {
                return false
            } else {
                return true
            }
        }
    }
    var isActionsDisabled: Bool {
        isLoading || selectedItems.count == 0
    }

    // MARK: - Init
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
        selectedItems.removeAll()
        _devices.removeAll()

        isLoading = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                await self._dataService.getSimulatorInfo()
            }.value
            _devices = result
            sort(using: sortOrder)
            _updateInfo()
            isLoading = false
        }
    }
    
    func delete() {
        for deviceId in selectedItems {
            Task {
                do {
                    try await _delete(udid: deviceId)
                }
            }
        }
    }

    func erase() {
        for deviceId in selectedItems {
            Task {
                do {
                    try await _erase(udid: deviceId)
                }
            }
        }
    }

    private func _delete(udid: String) async throws {
        try await _runSimctl(args: ["delete", udid])
        _devices.removeAll { $0.udid == udid }
    }

    private func _erase(udid: String) async throws {
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
        return !runtime.isEmpty && !runtime.contains("unavailable")
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
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Sort
    func sort(using sortOrder: [KeyPathComparator<DeviceInfo>]) {
        var finalOrders = sortOrder

        let keyPath: PartialKeyPath<DeviceInfo> = \.humanSize
        if finalOrders.firstIndex(where: { $0.keyPath == keyPath }) != nil {
            let newOrder = [KeyPathComparator(\DeviceInfo.size, order: .forward)]
            finalOrders = newOrder
        }
        
        let fallbacks = [
            KeyPathComparator(\DeviceInfo.name, order: .forward),
            KeyPathComparator(\DeviceInfo.iOS, order: .forward)
        ]
        
        for fallback in fallbacks where !finalOrders.contains(where: { $0.keyPath == fallback.keyPath }) {
            finalOrders.append(fallback)
        }
        _devices.sort(using: finalOrders)
    }

    // MARK: - Update sums
    private func _updateInfo() {
        Task {
            await _updateSummaryText()
            await _updateGeneralText()
        }
    }
    
    private func _updateSummaryText() async {
        let devices = _devices.filter { selectedItems.contains($0.udid) }
        guard !devices.isEmpty else {
            summaryText = ""
            return
        }
        
        let size = devices.reduce(0) { $0 + $1.size }
        let formattedSize = await _dataService.formatSize(size)
        summaryText = formattedSize
    }

    private func _updateGeneralText() async {
        guard !_devices.isEmpty else {
            generalSizeText = ""
            return
        }
        let size = _devices.reduce(0) { $0 + $1.size }
        let formattedSize = await _dataService.formatSize(size)
        generalSizeText = formattedSize
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
