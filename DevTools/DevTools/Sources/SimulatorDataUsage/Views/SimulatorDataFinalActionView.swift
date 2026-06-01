//
//  SimulatorDataFinalActionView.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 01.06.2026.
//

import SwiftUI

struct SimulatorDataFinalActionView: View {
    @Binding var isEraseAlertPresented: Bool
    @Binding var isDeleteAlertPresented: Bool

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 8
        ) {
            Button {
                isEraseAlertPresented = true
            } label: {
                Text("Erase")
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            Button {
                isDeleteAlertPresented = true
            } label: {
                Text("Delete")
                    .bold()
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
    }
}
