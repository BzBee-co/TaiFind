//
//  Taiwan_AQIApp.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.
//

import SwiftUI

@main
struct AirQualityMapAppApp: App {
    @StateObject private var viewModel = AQIViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
