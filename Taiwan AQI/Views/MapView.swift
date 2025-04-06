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

	@State private var selectedMapStyle: MapStyleOption = .standard
	@State private var showAnnotations: Bool = true
	@State private var selectedMeasurement: MeasurementType = .aqi

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
								gradient: Gradient(colors: [colorFor(record: record), colorFor(record: record).opacity(0)]),
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
					if selectedMeasurement != .none && showAnnotations {
						LegendView(type: selectedMeasurement)
							.padding(.top, 50)
					}
					VStack(spacing: 12) {
						// Measurement picker
						Menu {
							ForEach(MeasurementType.allCases, id: \.self) { type in
								Button {
									selectedMeasurement = type
								} label: {
									Label(type.rawValue, systemImage: selectedMeasurement == type ? "checkmark" : "")
								}
							}
						} label: {
							Image(systemName: "square.3.layers.3d")
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
							ForEach(MapStyleOption.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { option in
								Button {
									selectedMapStyle = option
								} label: {
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
				.padding(.leading, 40)
				.padding(.bottom, 30)
			}
			.shadow(radius: 10)
		}
	}

	private func colorFor(record: AQIRecord) -> Color {
		switch selectedMeasurement {
		case .none: return Color.gray.opacity(0.0)
		case .aqi: return color(for: Double(record.aqi), thresholds: [50, 100, 150, 200, 300, 500])
		case .so2: return color(for: record.so2 ?? 0.0, thresholds: [0.4, 0.8, 1.5, 2.5, 3.6, 5.0])
		case .co:  return color(for: record.co ?? 0.0, thresholds: [0.2, 0.4, 0.6, 0.8, 1.0, 1.2])
		case .o3:  return color(for: record.o3 ?? 0.0, thresholds: [20, 35, 50, 70, 85, 100])
		case .pm10: return color(for: record.pm10 ?? 0.0, thresholds: [20, 40, 60, 80, 100, 120])
		case .pm2_5: return color(for: record.pm2_5 ?? 0.0, thresholds: [10, 20, 30, 40, 50, 60])
		case .no2: return color(for: record.no2 ?? 0.0, thresholds: [1, 2.5, 4, 6, 8, 10])
		}
	}

	private func color(for value: Double, thresholds: [Double]) -> Color {
		switch value {
		case ..<thresholds[0]: return .green
		case ..<thresholds[1]: return .yellow
		case ..<thresholds[2]: return .orange
		case ..<thresholds[3]: return .red
		case ..<thresholds[4]: return .purple
		case ..<thresholds[5]: return .crimson
		default: return .gray.opacity(0.0)
		}
	}
}
