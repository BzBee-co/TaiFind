//
//  MapView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.
//

import SwiftUI
import MapKit
import CoreLocation

enum DisplayMode: String, CaseIterable {
	case pins = "Pins"
	case heatmap = "Heatmap"
}

enum MapLayerType: String, CaseIterable, Identifiable {
	case trashCans = "Public trash cans"
	case youBikes = "YouBike stations"
	case aqi = "Air Quality"

	var id: Self { self }

	var icon: String {
		switch self {
		case .trashCans: return "trash"
		case .youBikes: return "bicycle"
		case .aqi: return "aqi.medium"
		}
	}
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
	@State private var pendingAQIRecord: AQIRecord?
	@State private var pendingYouBikeStation: YouBikeStation?
	@State private var selectedLayer: MapLayerType = .aqi

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
		.onChange(of: selectedLayer) { newValue in
			withAnimation {
				switch newValue {
				case .aqi:
					viewModel.showTrashcans = false
					viewModel.showYouBikes = false
					showAnnotations = true
				case .trashCans:
					if !viewModel.showTrashcans {
						viewModel.fetchTrashcanData()
					}
					viewModel.showTrashcans = true
					viewModel.showYouBikes = false
					showAnnotations = false
				case .youBikes:
					if !viewModel.showYouBikes {
						viewModel.fetchYouBikeStations()
					}
					viewModel.showYouBikes = true
					viewModel.showTrashcans = false
					showAnnotations = false
				}
			}
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
				trashcanMap
			} else if viewModel.showYouBikes {
				youBikeMap
			} else {
				aqiMap
			}
		}
		.mapStyle(selectedMapStyle.style)
		.edgesIgnoringSafeArea(.all)
		.sheet(isPresented: $isShowingInfo) {
			InfoView()
				.presentationDragIndicator(.visible)
		}
	}

	// MARK: - Smaller map components

	private var trashcanMap: some View {
		let clusters = viewModel.trashcanAnnotations(for: viewModel.region)
		let center = viewModel.region.center
		let filteredClusters = clusters.filter { cluster in
			let clusterLocation = CLLocation(latitude: cluster.coordinate.latitude, longitude: cluster.coordinate.longitude)
			let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
			return clusterLocation.distance(from: centerLocation) <= 1000
		}
		return Map(
			coordinateRegion: $viewModel.region,
			showsUserLocation: true,
			annotationItems: filteredClusters
		) { cluster in
			MapAnnotation(coordinate: cluster.coordinate) {
				TrashcanPinView(count: cluster.count)
			}
		}
	}

	private var youBikeMap: some View {
		let clusters = viewModel.youBikeAnnotations(for: viewModel.region)
		let center = viewModel.region.center
		let filteredClusters = clusters.filter { cluster in
			let clusterLocation = CLLocation(latitude: cluster.coordinate.latitude, longitude: cluster.coordinate.longitude)
			let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
			return clusterLocation.distance(from: centerLocation) <= 1000
		}
		return Map(
			coordinateRegion: $viewModel.region,
			showsUserLocation: true,
			annotationItems: filteredClusters
		) { cluster in
			MapAnnotation(coordinate: cluster.coordinate) {
				youBikePin(for: cluster)
			}
		}
	}

	private var aqiMap: some View {
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
								pendingAQIRecord = record
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
			Picker("Layer", selection: $selectedLayer) {
				ForEach(MapLayerType.allCases) { layer in
					Label(layer.rawValue, systemImage: layer.icon)
						.tag(layer)
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
		
		switch selectedMeasurement {
		case .aqi:
			value = Double(record.aqi)
		case .so2:
			value = record.so2 ?? 0
		case .co:
			value = record.co ?? 0
		case .o3:
			value = record.o3 ?? 0
		case .pm10:
			value = record.pm10 ?? 0
		case .pm2_5:
			value = record.pm2_5 ?? 0
		case .no2:
			value = record.no2 ?? 0
		}
		
		return selectedMeasurement.color(for: value)
	}

	private func valueForPin(record: AQIRecord) -> String {
		let value: Double?
		switch selectedMeasurement {
		case .aqi:
			return "\(record.aqi)"
		case .so2:
			value = record.so2
		case .co:
			value = record.co
		case .o3:
			value = record.o3
		case .pm10:
			value = record.pm10
		case .pm2_5:
			value = record.pm2_5
		case .no2:
			value = record.no2
		}

		guard let v = value else { return "" }
		switch selectedMeasurement {
		case .pm10, .no2:
			return String(format: "%.0f", v)
		default:
			return String(format: "%.1f", v)
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
	let viewModel = AQIViewModel()
	viewModel.region = MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: 25.0336, longitude: 121.565),
		span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
	)
	return MapView()
		.environmentObject(viewModel)
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
