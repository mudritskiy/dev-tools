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
    @FocusState private var _isDummyFocused: Bool

    init(viewModel: SimulatorDataViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            _header
            _loadButtonPanel
                .frame(maxWidth: .infinity, alignment: .leading)
            _tableView
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            Color.gray.opacity(0.5) ,
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                        )
                }
                .overlay {
                    if viewModel.isLoading {
                        ZStack {
                            Color(NSColor.windowBackgroundColor).opacity(0.5)
                            ProgressView("Syncing devices...")
                                .controlSize(.large)
                        }
                    }
                }
            HStack(
                alignment: .center,
                spacing: 8
            ) {
                if !viewModel.summaryText.isEmpty {
                    let devicesText = "\(viewModel.selectedItems.count) devices"
                    Text("Selected \(Text(devicesText).bold()) to be handled. This can free up to \(Text(viewModel.summaryText).bold())")
                }
                _actionButtonPanel
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .onAppear {
            Task {
                _isDummyFocused = true
            }
            viewModel.onViewReady()
        }
        .alert("Erase devices?", isPresented: $viewModel.isEraseAlertPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Erase", role: .destructive) {
                viewModel.erase()
            }
        } message: {
            Text(viewModel.textsFactory.actionText(count: viewModel.selectedItems.count))
        }
        .alert("Delete devices?", isPresented: $viewModel.isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.delete()
            }
        } message: {
            Text(viewModel.textsFactory.actionText(count: viewModel.selectedItems.count))
        }
        .padding(.all, 16)
    }
    
    private var _header: some View {
        VStack(
            alignment: .leading,
            spacing: 0
        ) {
            Text(viewModel.textsFactory.headerTitle)
                .font(.title2)
                .bold()
            Text(viewModel.textsFactory.headerSubtitle)
                .font(.body)
                .padding(.top, 12)
            Text(viewModel.textsFactory.headerAnnotation)
                .font(.body)
                .foregroundStyle(.gray)
                .padding(.top, 8)
        }
    }
    
    private var _tableView: some View {
        Table(
            viewModel.visibleDevices,
            selection: $viewModel.selectedTableItems,
            sortOrder: $viewModel.sortOrder
        ) {
            TableColumn("") { device in
                Toggle("", isOn: Binding(
                    get: { viewModel.selectedItems.contains(device.udid) },
                    set: { _ in viewModel.toggle(device.udid) }
                ))
                .labelsHidden()
            }
            .width(20)
            TableColumn("iOS", value: \.iOS) { device in
                Text(device.iOS)
                    .font(.callout.monospaced())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(36)
            TableColumn("Name", value: \.name)
            { device in
                Text(device.name)
                    .font(.body)
            }
                .width(min: 100, ideal: 150, max: 180)
            TableColumn("Size", value: \.size) { device in
                Text(device.humanSize)
                    .font(device.sizeFont.monospaced())
                    .foregroundStyle(device.sizeColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
                .width(80)
            TableColumn("UDID", value: \.udid)
            { device in
                Text(device.udid)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .focused($_isDummyFocused)
        .tableStyle(.inset)
        .alternatingRowBackgrounds(.disabled)
        .onChange(of: viewModel.sortOrder) { _, sortOrder in
            viewModel.sort(using: sortOrder)
        }
        .onKeyPress(.space) {
            viewModel.onSpaceTap()
            return .handled
        }
        .disabled(viewModel.isLoading)
    }
    
    private var _loadButtonPanel: some View {
        HStack(
            alignment: .center,
            spacing: 8
        ) {
            Button {
                viewModel.load()
            } label: {
                Text("Load")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            Toggle(isOn: $viewModel.isHiddenEmptyDevces) {
                Text("Hide empty devices")
            }
            Toggle(isOn: $viewModel.isHiddenUnableToEraseDevces) {
                Text("Hide devices, that can't be erased")
            }
            if !viewModel.generalSizeText.isEmpty {
                Text("All devices size: \(Text(viewModel.generalSizeText).bold())")
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    private var _actionButtonPanel: some View {
        HStack(
            alignment: .center,
            spacing: 8
        ) {
            Button {
                viewModel.isEraseAlertPresented = true
            } label: {
                Text("Erase")
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            Button {
                viewModel.isDeleteAlertPresented = true
            } label: {
                Text("Delete")
                    .bold()
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .disabled(viewModel.isLoading || viewModel.selectedItems.count == 0)
    }
}
