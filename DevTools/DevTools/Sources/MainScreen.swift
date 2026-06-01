//
//  MainScreen.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 28.05.2026.
//

import SwiftUI

struct MainScreen: View {
    let simulatorDataViewModel: SimulatorDataViewModel

    init() {
        let service = SimulatorDataServiceImpl()
        simulatorDataViewModel = SimulatorDataViewModel(dataService: service)
    }

    var body: some View {
        SimulatorDataView(viewModel: simulatorDataViewModel)
    }
}
