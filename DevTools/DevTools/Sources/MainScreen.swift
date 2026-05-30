//
//  MainScreen.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 28.05.2026.
//

import SwiftUI

struct MainScreen: View {
    let simulatorDataViewModel: SimulatorDataViewModel = SimulatorDataViewModel(dataService: SimulatorDataService())
    
    var body: some View {
        SimulatorDataView(viewModel: simulatorDataViewModel)
    }
}

struct SimulatorDataView: View {
    @State var viewModel: SimulatorDataViewModel
    @State var sortOrder = [KeyPathComparator(\DeviceInfo.humanSize)]

    init(viewModel: SimulatorDataViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Button {
                viewModel.load()
            } label: {
                Text("Load")
            }
            Button {
                viewModel.erase()
            } label: {
                Text("Erase")
            }
            Button {
                viewModel.delete()
            } label: {
                Text("Delete")
            }

            Table(viewModel.devices, selection: $viewModel.selectedTableItems, sortOrder: $sortOrder) {
                TableColumn("") { device in
                    Toggle("", isOn: Binding(
                        get: { viewModel.selectedItems.contains(device.udid) },
                        set: { _ in viewModel.toggle(device.udid) }
                    ))
                    .labelsHidden()
                }
                .width(20)
                TableColumn("iOS", value: \.iOS)
                    .width(40)
                TableColumn("Name", value: \.name)
                    .width(min: 100, ideal: 180, max: 250)
                TableColumn("Size", value: \.size) { device in
                    Text(device.humanSize)
                }
                    .width(80)
                TableColumn("UDID", value: \.udid)
            }
            .tableStyle(.inset)
            .alternatingRowBackgrounds(.disabled)
            .onChange(of: sortOrder) { _, sortOrder in
                viewModel.sort(using: sortOrder)
            }
            .onKeyPress(.space) {
                viewModel.onSpaceTap()
                return .handled
            }
            
//            List(viewModel.devices, id: \.udid) { device in
//                let isSelected: Bool = viewModel.selectedItems.contains(device.udid)
//                SimulatorDataRowView(
//                    device: device,
//                    isSelected: isSelected
//                ) {
//                    if isSelected {
//                        viewModel.selectedItems.remove(device.udid)
//                    } else {
//                        viewModel.selectedItems.insert(device.udid)
//                    }
//                }
//            }
        }
    }
}

struct SimulatorDataRowView: View {
    let device: DeviceInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .onTapGesture { onTap() }
            Text(device.name)
                .font(Font.caption)
                .foregroundStyle(Color.primary)
            Text(device.humanSize)
                .font(Font.caption)
                .foregroundStyle(Color.primary)

        }
    }
}
