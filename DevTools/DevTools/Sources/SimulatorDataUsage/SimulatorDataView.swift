//
//  SimulatorDataView.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 01.06.2026.
//

import SwiftUI

struct SimulatorDataView: View {
    @State var viewModel: SimulatorDataViewModel
    @FocusState private var _isDummyFocused: Bool

    init(viewModel: SimulatorDataViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        _content
            .padding(.all, 16)
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
    }

    private var _content: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            _header
            _loadButtonPanel
                .disabled(viewModel.isLoading)
                .frame(maxWidth: .infinity, alignment: .leading)
            _tableView
            _footer
        }
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

    private var _footer: some View {
        HStack(
            alignment: .center,
            spacing: 8
        ) {
            if !viewModel.summaryText.isEmpty {
                let devicesText = "\(viewModel.selectedItems.count) devices"
                Text("Selected \(Text(devicesText).bold()) to be handled. This can free up to \(Text(viewModel.summaryText).bold())")
            }
            _actionButtonPanel
                .disabled(viewModel.isActionsDisabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var _tableView: some View {
        _tableContentView
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
    }

    private var _tableContentView: some View {
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
        SimulatorDataLoadActionView(
            generalSizeText: viewModel.generalSizeText,
            isHiddenEmptyDevces: $viewModel.isHiddenEmptyDevces,
            isHiddenUnableToEraseDevces: $viewModel.isHiddenUnableToEraseDevces,
            onLoadTap: viewModel.load
        )
    }

    private var _actionButtonPanel: some View {
        SimulatorDataFinalActionView(
            isEraseAlertPresented: $viewModel.isEraseAlertPresented,
            isDeleteAlertPresented: $viewModel.isDeleteAlertPresented
        )
    }
}
