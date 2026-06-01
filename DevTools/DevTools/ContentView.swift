//
//  ContentView.swift
//  DevTools
//
//  Created by Volodymyr Mudrik on 27.05.2026.
//

import SwiftUI

struct ContentView: View {
    let appName =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? ""
    
    var body: some View {
        MainScreen()
            .navigationTitle("\(appName): Developer Tools")
    }
}

#Preview {
    ContentView()
}
