//
//  MapView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.
//

import SwiftUI
import MapKit

enum DisplayMode: String, CaseIterable {
	case pins = "Pins"
	case heatmap = "Heatmap"
}

struct MapView: View {
	@EnvironmentObject var viewModel: AQIViewModel
	@Environment(\.dismiss) var dismiss
	@State var isShowingInfo: Bool = false
	@State private var displayMode: DisplayMode = .pins
	@State private var selectedMeasurement: MeasurementType = .aqi
	@State private var selectedRecord: AQIRecord?
	
	enum MapStyleOption: String, CaseIterable {
		case standard = "Standard"
		case imagery = "Satellite"
		case hybrid = "Hybrid"
		
		var style: MapStyle {
			switch self {
			case .standard: .standard
			case .imagery: .imagery
			case .hybrid: .hybrid
			}
		}
	}
	
	@State private var selectedMapStyle: MapStyleOption = .standard
	@State private var showAnnotations = true
	
	var body: some View {
		ZStack {
			mapLayer
			overlayControls
		}
		.onAppear {
			viewModel.fetchAQIData()
		}
		.sheet(item: $selectedRecord) { record in
			LocationDetailsView(record: record)
				.presentationDragIndicator(.visible)
				.presentationDetents([.medium])
		}
	}
	
	// MARK: - Map Layer
	private var mapLayer: some View {
		Map(
			coordinateRegion: $viewModel.region,
			showsUserLocation: true,
			annotationItems: showAnnotations ? viewModel.aqiRecords : []
		) { record in
			MapAnnotation(coordinate: record.coordinate) {
				let color = colorFor(record: record)
				Group {
					if displayMode == .heatmap {
						Circle()
							.fill(
								RadialGradient(
									gradient: Gradient(colors: [color, color.opacity(0)]),
									center: .center,
									startRadius: 10,
									endRadius: 50
								)
							)
							.frame(
								width: 100 * scaleFactor(for: viewModel.region),
								height: 100 * scaleFactor(for: viewModel.region)
							)
							.opacity(0.6)
					} else if displayMode == .pins {
						if !valueForPin(record: record).isEmpty {
							Button {
								selectedRecord = record
							} label: {
								PinView(color: color, value: valueForPin(record: record))
							}
							.buttonStyle(.plain)
						}
					}
				}
			}
		}
		.mapStyle(selectedMapStyle.style)
		.edgesIgnoringSafeArea(.all)
		.sheet(isPresented: $isShowingInfo) {
			InfoView()
				.presentationDragIndicator(.visible)
		}
	}
	
	// MARK: - Controls
	private var overlayControls: some View {
		VStack {
			Spacer()
			HStack(alignment: .bottom) {
				Spacer()
				if showAnnotations {
					LegendView(displayMode: $displayMode, selectedMeasurement: $selectedMeasurement)
				}
				
				VStack(spacing: 2) {
					twButton
					menuButton
					refreshButton
					infoButton
				}
				.padding(.trailing, 8)
				.buttonStyle(.plain)
			}
			.padding(.bottom, 30)
		}
		.shadow(radius: 10)
	}
	
	// MARK: - Control Buttons
	private var menuButton: some View {
		Menu {
			ForEach(MeasurementType.allCases.reversed(), id: \.rawValue) { layer in
				Button {
					selectedMeasurement = layer
				} label: {
					HStack {
						Image(systemName: layer == selectedMeasurement ? "checkmark" : "")
							.font(.caption)
						Text(layer.fullName)
					}
				}
			}
			Divider()
			Picker("Map style", selection: $selectedMapStyle) {
				ForEach(MapStyleOption.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { mapType in
					Text(mapType.rawValue)
						.tag(mapType)
				}
			}
			.pickerStyle(.menu)
			
		} label: {
			ControlButton(iconName: "square.3.layers.3d", fontSize: 14, padding: 11)
		}
	}
	
	private var twButton: some View {
		Button {
			withAnimation {
				viewModel.region = MKCoordinateRegion(
					center: CLLocationCoordinate2D(latitude: 25.033964, longitude: 121.564468),
					span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1) // adjust for zoom level
				)
			}
		} label: {
			Image("twSilhouette")
				.resizable()
				.scaledToFit()
				.frame(width: 24, height: 24)
				.padding(8)
				.background(Circle().fill(Color(.secondarySystemBackground).opacity(0.6)))
				.clipShape(Circle())
				.padding(.bottom, 2)
		}
	}
	
	private var refreshButton: some View {
		Button {
			viewModel.fetchAQIData()
		} label: {
			ControlButton(iconName: "arrow.clockwise", fontSize: 14, padding: 12)
		}
	}
	
	private var infoButton: some View {
		Button {
			isShowingInfo.toggle()
		} label: {
			ControlButton(iconName:"info", fontSize: 18, padding: 14)
		}
	}
	
	
	// MARK: - Helpers
	
	private func scaleFactor(for region: MKCoordinateRegion) -> CGFloat {
		let zoomLevel = max(region.span.latitudeDelta, region.span.longitudeDelta)
		return min(50 / zoomLevel, 1)
	}
	
	private func colorFor(record: AQIRecord) -> Color {
		let value: Double
		let thresholds: [Double]
		
		switch selectedMeasurement { // Use the bound selectedMeasurement
			//        case .none: return .clear
		case .aqi:
			value = Double(record.aqi)
			thresholds = [50, 100, 150, 200, 300, 400]
		case .so2:
			value = record.so2 ?? 0
			thresholds = [8.0, 65.0, 160.0, 304.0, 604.0, 804.0]
		case .co:
			value = record.co ?? 0
			thresholds = [4.4, 9.4, 12.4, 15.4, 30.4, 40.4]
		case .o3:
			value = record.o3 ?? 0
			thresholds = [54, 70, 134, 204, 404, 504]
		case .pm10:
			value = record.pm10 ?? 0
			thresholds = [30, 75, 190, 354, 424, 504]
		case .pm2_5:
			value = record.pm2_5 ?? 0
			thresholds = [12.4, 30.4, 50.4, 125.4, 225.4, 325.4]
		case .no2:
			value = record.no2 ?? 0
			thresholds = [21, 100, 360, 649, 1249, 1649]
		}
		
		return color(for: value, thresholds: thresholds)
	}
	
	private func color(for value: Double, thresholds: [Double]) -> Color {
		switch value {
		case ..<thresholds[0]: return .green
		case ..<thresholds[1]: return .yellow
		case ..<thresholds[2]: return .orange
		case ..<thresholds[3]: return .red
		case ..<thresholds[4]: return .purple
		case ..<thresholds[5]: return .crimson
		default: return .clear
		}
	}
	
	private func valueForPin(record: AQIRecord) -> String {
		switch selectedMeasurement { // Use the bound selectedMeasurement
		case .aqi: return "\(record.aqi)"
		case .so2: return record.so2.map { String(format: "%.1f", $0) } ?? ""
		case .co: return record.co.map { String(format: "%.1f", $0) } ?? ""
		case .o3: return record.o3.map { String(format: "%.1f", $0) } ?? ""
		case .pm10: return record.pm10.map { String(format: "%.0f", $0) } ?? ""
		case .pm2_5: return record.pm2_5.map { String(format: "%.1f", $0) } ?? ""
		case .no2: return record.no2.map { String(format: "%.0f", $0) } ?? ""
			//        case .none: return "-"
		}
	}
}

#Preview {
	MapView()
		.environmentObject(AQIViewModel())
}
