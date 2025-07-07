//  MapView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.

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
	@State private var selectedLayer: MapLayerType = .aqi
	@State private var selectedMapStyle: MapStyleOption = .standard
	@State private var showAnnotations = true
	@State private var bouncingRecord: AQIRecord?
	@State private var bouncingYouBikeStation: YouBikeStation?

	enum MapStyleOption: String, CaseIterable {
		case standard = "Standard"
		case imagery = "Satellite"
		case hybrid = "Hybrid"

		var style: MapStyle {
			switch self {
			case .standard: return .standard(elevation: .realistic)
			case .imagery: return .imagery(elevation: .realistic)
			case .hybrid: return .hybrid(elevation: .realistic)
			}
		}
	}

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
			withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
				bouncingRecord = nil
				recordToCenter = nil
			}
		}) {
			LocationDetailsView(record: $0)
				.presentationDragIndicator(.visible)
				.presentationDetents([.medium, .large])
		}
		.sheet(item: $selectedYouBikeStation, onDismiss: {
			withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
				bouncingYouBikeStation = nil
				youBikeStationToCenter = nil
			}
		}) {
			YouBikeStationDetailsView(station: $0)
				.presentationDragIndicator(.visible)
				.presentationDetents([.medium, .large])
		}
	}

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

	private var trashcanMap: some View {
		Map(
			coordinateRegion: $viewModel.region,
			showsUserLocation: true,
			annotationItems: viewModel.trashcanAnnotations(for: viewModel.region)
				.filter { isWithin1km(of: viewModel.region.center, coordinate: $0.coordinate) }
		) { cluster in
			MapAnnotation(coordinate: cluster.coordinate) {
				TrashcanPinView(count: cluster.count)
			}
		}
	}

	private var youBikeMap: some View {
		Map(
			coordinateRegion: $viewModel.region,
			showsUserLocation: true,
			annotationItems: viewModel.youBikeAnnotations(for: viewModel.region)
				.filter { isWithin1km(of: viewModel.region.center, coordinate: $0.coordinate) }
		) { cluster in
			MapAnnotation(coordinate: cluster.coordinate) {
				if cluster.count == 1,
					let station = viewModel.youBikeStations.first(where: {
						abs($0.latitude - cluster.coordinate.latitude) < 0.00001 &&
						abs($0.longitude - cluster.coordinate.longitude) < 0.00001
					}) {
					Button {
						withAnimation(.easeInOut(duration: 0.5)) {
							youBikeStationToCenter = station
							bouncingYouBikeStation = station
							viewModel.region = MKCoordinateRegion(
								center: CLLocationCoordinate2D(latitude: station.latitude - 0.002, longitude: station.longitude),
								span: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0055)
							)
						}
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
							selectedYouBikeStation = station
						}
					} label: {
						YouBikePinView(count: nil)
							.scaleEffect(bouncingYouBikeStation == station ? 1.6 : 1.0)
							.animation(.spring(response: 0.3, dampingFraction: 0.3), value: bouncingYouBikeStation == station)
					}
					.buttonStyle(.plain)
				} else {
					YouBikePinView(count: cluster.count)
				}
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
				let color = selectedMeasurement.color(for: selectedMeasurement.value(in: record))
				if displayMode == .heatmap {
					Circle()
						.fill(RadialGradient(gradient: Gradient(colors: [color, color.opacity(0)]), center: .center, startRadius: 10, endRadius: 50))
						.frame(width: 100, height: 100)
						.opacity(0.6)
				} else {
					Button {
						withAnimation(.easeInOut(duration: 0.5)) {
							recordToCenter = record
							bouncingRecord = record
							viewModel.region = MKCoordinateRegion(
								center: CLLocationCoordinate2D(latitude: record.coordinate.latitude - 0.010, longitude: record.coordinate.longitude),
								span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
							)
						}
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
							selectedAirQualityRecord = record
						}
					} label: {
						PinView(color: color, value: selectedMeasurement.displayValue(for: record))
							.scaleEffect(bouncingRecord == record ? 1.6 : 1.0)
							.animation(.spring(response: 0.3, dampingFraction: 0.3), value: bouncingRecord == record)
					}
					.buttonStyle(.plain)
				}
			}
		}
	}

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
				.buttonStyle(.plain)
				.padding(.trailing, 8)
			}
			.padding(.bottom, 30)
		}
	}

	private var menuButton: some View {
		Menu {
			Picker("Layer", selection: $selectedLayer) {
				ForEach(MapLayerType.allCases) { layer in
					Label(layer.rawValue, systemImage: layer.icon).tag(layer)
				}
			}
			Divider()
			Picker("Map style", selection: $selectedMapStyle) {
				ForEach(MapStyleOption.allCases, id: \.self) { type in
					Text(type.rawValue).tag(type)
				}
			}
			.pickerStyle(.menu)
		} label: {
			ControlButton(iconName: "square.3.layers.3d", fontSize: 15, padding: 11)
		}
	}

	private var locationButton: some View {
		Button {
			if let loc = viewModel.locationManager.userLocation {
				viewModel.region = MKCoordinateRegion(center: loc, span: .init(latitudeDelta: 0.005, longitudeDelta: 0.005))
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
			ControlButton(iconName: "info", fontSize: 18, padding: 14)
		}
	}

	private func isWithin1km(of center: CLLocationCoordinate2D, coordinate: CLLocationCoordinate2D) -> Bool {
		let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
		let checkLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
		return centerLocation.distance(from: checkLocation) <= 1000
	}
}

extension MeasurementType {
	func value(in record: AQIRecord) -> Double {
		switch self {
		case .aqi: return Double(record.aqi)
		case .so2: return record.so2 ?? 0
		case .co: return record.co ?? 0
		case .o3: return record.o3 ?? 0
		case .pm10: return record.pm10 ?? 0
		case .pm2_5: return record.pm2_5 ?? 0
		case .no2: return record.no2 ?? 0
		}
	}

	func displayValue(for record: AQIRecord) -> String {
		let value = value(in: record)
		switch self {
		case .aqi: return String(Int(value))
		default: return String(format: "%.1f", value)
		}
	}
}

extension TrashcanRecord: Identifiable, Hashable {
	static func == (lhs: TrashcanRecord, rhs: TrashcanRecord) -> Bool {
		lhs.id == rhs.id
	}
	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
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
