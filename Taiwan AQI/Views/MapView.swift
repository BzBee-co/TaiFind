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
	@State private var selectedAirQualityRecord: AQIRecord?
	@State private var recordToCenter: AQIRecord?
	@State private var cameraPosition: MapCameraPosition = .automatic
	@State private var selectedYouBikeStation: YouBikeStation?
	@State private var youBikeStationToCenter: YouBikeStation?
	
	
	enum MapStyleOption: String, CaseIterable {
		case standard = "Standard"
		case imagery = "Satellite"
		case hybrid = "Hybrid"
		
		var style: MapStyle {
			switch self {
			case .standard: .standard(elevation: .realistic)
			case .imagery: .imagery(elevation: .realistic)
			case .hybrid: .hybrid(elevation: .realistic)
			}
		}
	}
	
	@State private var selectedMapStyle: MapStyleOption = .standard
	@State private var showAnnotations = true
	
	var body: some View {
		ZStack {
			mapLayer
			overlayControls
			if viewModel.showTrashcans && viewModel.trashcanLoading {
				Color.black.opacity(0.2).ignoresSafeArea()
				ProgressView("Loading locations…")
					.padding(30)
					.background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
					.shadow(radius: 10)
			}
			if viewModel.showYouBikes && viewModel.youBikeLoading {
				Color.black.opacity(0.2).ignoresSafeArea()
				ProgressView("Loading YouBike stations…")
					.padding(30)
					.background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
					.shadow(radius: 10)
			}
		}
		.onAppear {
			viewModel.fetchAQIData()
		}
		.sheet(item: $selectedAirQualityRecord, onDismiss: {
			recordToCenter = nil
		}) { record in
			LocationDetailsView(record: record)
				.presentationDragIndicator(.visible)
				.presentationDetents([.medium, .large])
		}
		.sheet(item: $selectedYouBikeStation, onDismiss: {
			youBikeStationToCenter = nil
		}) { station in
			YouBikeStationDetailsView(station: station)
				.presentationDragIndicator(.visible)
				.presentationDetents([.medium, .large])
		}
	}
	
	// MARK: - Map Layer
	private var mapLayer: some View {
		Group {
			if viewModel.showTrashcans {
				let clusters = viewModel.trashcanAnnotations(for: viewModel.region)
				Map(
					coordinateRegion: $viewModel.region,
					showsUserLocation: true,
					annotationItems: clusters
				) { cluster in
					MapAnnotation(coordinate: cluster.coordinate) {
						TrashcanPinView(count: cluster.count)
					}
				}
			} else if viewModel.showYouBikes {
				let clusters = viewModel.youBikeAnnotations(for: viewModel.region)
				Map(
					coordinateRegion: $viewModel.region,
					showsUserLocation: true,
					annotationItems: clusters
				) { cluster in
					MapAnnotation(coordinate: cluster.coordinate) {
						youBikePin(for: cluster)
					}
				}
			} else {
				Map(
					coordinateRegion: $viewModel.region,
					showsUserLocation: true,
					annotationItems: viewModel.aqiRecords
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
										withAnimation {
											recordToCenter = record
										}
									} label: {
										PinView(color: color, value: valueForPin(record: record))
											.scaleEffect(recordToCenter == record ? 1.6 : 1.0)
											.animation(.spring(response: 0.3, dampingFraction: 0.3), value: recordToCenter == record)
									}
									.buttonStyle(.plain)
								}
							}
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
		
		.onChange(of: recordToCenter) { oldRecord, newRecord in
			if let record = newRecord {
				withAnimation {
					viewModel.region = MKCoordinateRegion(
						center: CLLocationCoordinate2D(
							latitude: record.coordinate.latitude - 0.010,  // Shift upward
							longitude: record.coordinate.longitude
						),
						span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
					)
				}
				
				// Delay sheet presentation to give the map time to animate
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
					selectedAirQualityRecord = record
				}
			}
		}
		.onChange(of: youBikeStationToCenter) { oldStation, newStation in
			if let station = newStation {
				APIService.fetchYouBikeStations { stations in
					DispatchQueue.main.async {
						viewModel.youBikeStations = stations
						withAnimation {
							viewModel.region = MKCoordinateRegion(
								center: CLLocationCoordinate2D(
									latitude: station.latitude - 0.002,  // Shift upward
									longitude: station.longitude
								),
								span: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0055)
							)
						}
						// Delay sheet presentation to give the map time to animate
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
							selectedYouBikeStation = stations.first(where: { $0.sno == station.sno }) ?? station
						}
					}
				}
			}
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
					menuButton
					if !viewModel.showTrashcans {
						refreshButton
					}
					locationButton
					infoButton
				}
				.animation(.easeInOut(duration: 0.25), value: showAnnotations)

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
					viewModel.showTrashcans = false
					viewModel.showYouBikes = false
					showAnnotations = true
				} label: {
					HStack {
						Image(systemName: (!viewModel.showTrashcans && !viewModel.showYouBikes && layer == selectedMeasurement) ? "checkmark" : "")
							.font(.caption)
						Text(layer.fullName)
					}
				}
			}
			Divider()
			Button {
				withAnimation {
					if !viewModel.showTrashcans {
						viewModel.fetchTrashcanData()
					}
					viewModel.showTrashcans = true
					viewModel.showYouBikes = false
					showAnnotations = false
				}
			} label: {
				HStack {
					Image(systemName: viewModel.showTrashcans ? "checkmark" : "")
						.font(.caption)
					Text("Public trash cans")
				}
			}
			Divider()
			Button {
				withAnimation {
					if !viewModel.showYouBikes {
						viewModel.fetchYouBikeStations()
					}
					viewModel.showYouBikes = true
					viewModel.showTrashcans = false
					showAnnotations = false
				}
			} label: {
				HStack {
					Image(systemName: viewModel.showYouBikes ? "checkmark" : "")
						.font(.caption)
					Text("YouBike stations")
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
			ControlButton(iconName: "square.3.layers.3d", fontSize: 15, padding: 11)
		}
	}
	
	private var locationButton: some View {
		Button {
			withAnimation {
				if let userLocation = viewModel.locationManager.userLocation {
					viewModel.region = MKCoordinateRegion(
						center: userLocation,
						span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
					)
				} else {
					viewModel.region = MKCoordinateRegion(
						center: CLLocationCoordinate2D(latitude: 25.033964, longitude: 121.564468),
						span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
					)
				}
			}
		} label: {
			ControlButton(iconName: "location", fontSize: 16, padding: 11)
		}
	}

	
	private var refreshButton: some View {
		Button {
			if viewModel.showYouBikes {
				viewModel.fetchYouBikeStations()
			} else {
				viewModel.fetchAQIData()
			}
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
		if value <= thresholds[0] { return .green }
		else if value <= thresholds[1] { return .yellow }
		else if value <= thresholds[2] { return .orange }
		else if value <= thresholds[3] { return .red }
		else if value <= thresholds[4] { return .purple }
		else if value <= thresholds[5] { return .crimson }
		else { return .clear }
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
	
	@ViewBuilder
	private func youBikePin(for cluster: YouBikeCluster) -> some View {
		if cluster.count == 1,
		   let station = viewModel.youBikeStations.first(where: {
			   $0.latitude == cluster.coordinate.latitude && $0.longitude == cluster.coordinate.longitude
		   }) {
			
			Button {
				withAnimation {
					youBikeStationToCenter = station
				}
			} label: {
				YouBikePinView(count: nil)
					.scaleEffect(youBikeStationToCenter == station ? 1.6 : 1.0)
					.animation(.spring(response: 0.3, dampingFraction: 0.3), value: youBikeStationToCenter == station)
			}
			.buttonStyle(.plain)
			
		} else {
			YouBikePinView(count: cluster.count)
		}
	}
}

#Preview {
	MapView()
		.environmentObject(AQIViewModel())
}

// Add Identifiable and Hashable conformance to TrashcanRecord
extension TrashcanRecord: Identifiable, Hashable {
	static func == (lhs: TrashcanRecord, rhs: TrashcanRecord) -> Bool {
		lhs.id == rhs.id
	}
	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}
