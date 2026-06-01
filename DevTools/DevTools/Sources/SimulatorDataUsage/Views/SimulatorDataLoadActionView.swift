//
//  SimulatorDataLoadActionView.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 01.06.2026.
//

import SwiftUI

struct SimulatorDataLoadActionView: View {
    let generalSizeText: String
    @Binding var isHiddenEmptyDevces: Bool
    @Binding var isHiddenUnableToEraseDevces: Bool
    let onLoadTap: () -> Void

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 8
        ) {
            Button {
                onLoadTap()
            } label: {
                Text("Load")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            Toggle(isOn: $isHiddenEmptyDevces) {
                Text("Hide empty devices")
            }
            Toggle(isOn: $isHiddenUnableToEraseDevces) {
                Text("Hide devices, that can't be erased")
            }
            if !generalSizeText.isEmpty {
                Text("All devices size: \(Text(generalSizeText).bold())")
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
