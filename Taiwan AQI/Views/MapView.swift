//
//  MapView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var viewModel: AQIViewModel
    
    // Calculate scale factor based on latitude delta
    private func scaleFactor(for region: MKCoordinateRegion) -> CGFloat {
        // You can adjust this formula to get the desired scaling effect
        let zoomLevel = max(region.span.latitudeDelta, region.span.longitudeDelta)
        let scale = min(20 / zoomLevel, 1) // Set a cap for the max circle size
        return scale
    }
    
    var body: some View {
        Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.aqiRecords) { record in
            MapAnnotation(coordinate: record.coordinate) {
                // Scale the circle size based on the zoom level
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [colorForAQI(record.aqi), colorForAQI(record.aqi).opacity(0)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 50 // Adjust this value to control how far the fade reaches
                        )
                    )
                    .frame(width: 100 * scaleFactor(for: viewModel.region), height: 100 * scaleFactor(for: viewModel.region))
                    .opacity(0.6)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewModel.fetchAQIData()
        }
    }
    
    private func colorForAQI(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<50: return Color.green
        case 50..<100: return Color.yellow
        case 100..<150: return Color.orange
        case 150..<200: return Color.red
        default: return Color.purple
        }
    }
}

#Preview {
    MapView()
}
