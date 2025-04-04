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

    enum MapStyleOption: String, CaseIterable {
        case standard = "Standard"
        case imagery = "Satellite"
        case hybrid = "Hybrid"
        
        var style: MapStyle {
            switch self {
            case .standard: return .standard
            case .imagery: return .imagery
            case .hybrid: return .hybrid
            }
        }
    }
    
    @State private var selectedMapStyle: MapStyleOption = .hybrid
    @State private var showAnnotations: Bool = true

    private func scaleFactor(for region: MKCoordinateRegion) -> CGFloat {
        let zoomLevel = max(region.span.latitudeDelta, region.span.longitudeDelta)
        let scale = min(50 / zoomLevel, 1)
        return scale
    }
    
    var body: some View {
        ZStack {
            // Map as background
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                annotationItems: showAnnotations ? viewModel.aqiRecords : []) { record in
                MapAnnotation(coordinate: record.coordinate) {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [colorForAQI(record.aqi), colorForAQI(record.aqi).opacity(0)]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100 * scaleFactor(for: viewModel.region), height: 100 * scaleFactor(for: viewModel.region))
                        .opacity(0.6)
                }
            }
            .mapStyle(selectedMapStyle.style)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                viewModel.fetchAQIData()
            }
            
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Spacer()
                    if showAnnotations {
                        AQILegend()
                            .padding(.top, 50)
                    }
                    VStack {
                        // Toggle Annotations Button
                        Button(action: {
                            showAnnotations.toggle()
                        }) {
                            Image(systemName: showAnnotations ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.6)))
                        }
                        
                        // Refresh data button
                        Button(action: {
                            viewModel.fetchAQIData()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.6)))
                        }
                        
                        // Map Style Menu
                        Menu {
                            ForEach(MapStyleOption.allCases, id: \ .self) { option in
                                Button(action: {
                                    selectedMapStyle = option
                                }) {
                                    Label(option.rawValue, systemImage: selectedMapStyle == option ? "checkmark" : "")
                                }
                            }
                        } label: {
                            Image(systemName: "map")
                                .font(.system(size: 16))
                                .foregroundStyle(.black)
                                .padding()
                                .background(Circle().fill(Color.white.opacity(0.6)))
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
//                .padding(.leading, 50)
                .padding(.bottom, 30)
            }
            .shadow(radius: 10)
        }
    }
    
    private func colorForAQI(_ aqi: Int) -> Color {
        switch aqi {
        case 0..<25: return Color.blue
        case 25..<50: return Color.green
        case 50..<75: return Color.yellow
        case 75..<100: return Color.orange
        case 100..<150: return Color.red
        case 150..<200: return Color.crimson
        default: return Color.purple
        }
    }
}
