//  MapView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/3/30.

import SwiftUI
import MapKit
import CoreLocation
import UIKit

enum DisplayMode: String, CaseIterable {
	case pins = "Pins"
	case heatmap = "Heatmap"

	var localizedName: LocalizedStringKey {
		switch self {
		case .pins: return "Pins"
		case .heatmap: return "Heatmap"
		}
	}
}


enum MapLayerType: String, CaseIterable, Identifiable {
	case trashCans = "Public trash cans"
	case youBikesTaipei = "YouBike Taipei"
	case youBikesTaichung = "YouBike Taichung"
	case aqi = "Air Quality"
	
	var localizedName: LocalizedStringKey {
		switch self {
		case .trashCans: return "Public trash cans"
		case .youBikesTaipei: return "YouBike Taipei"
		case .youBikesTaichung: return "YouBike Taichung"
		case .aqi: return "Air Quality"
		}
	}

	var id: Self { self }

	var icon: String {
		switch self {
		case .trashCans: return "trash"
		case .youBikesTaipei, .youBikesTaichung: return "bicycle"
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
	@State private var selectedYouBikeStation: YouBikeStation?
	@State private var youBikeStationToCenter: YouBikeStation?
	@State private var selectedLayer: MapLayerType = .aqi
	@State private var selectedMapStyle: MapStyleOption = .standard
	@State private var showAnnotations = true
	@State private var bouncingRecord: AQIRecord?
	@State private var bouncingYouBikeStation: YouBikeStation?
	// Shown when the location button is tapped but permission is denied/restricted —
	// previously this case just silently did nothing (roadmap item #11).
	@State private var isShowingLocationPermissionAlert = false
	@State private var isShowingFavorites = false
	@State private var userHeading: CLLocationDirection = 0
	@Namespace private var mapScope

	enum MapStyleOption: String, CaseIterable {
		case standard = "Standard"
		case imagery = "Satellite"
		case hybrid = "Hybrid"

		var localizedName: LocalizedStringKey {
			switch self {
			case .standard: return "Standard"
			case .imagery: return "Satellite"
			case .hybrid: return "Hybrid"
			}
		}
		
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
			// the compass does not move to adjust to map being rotated. Needs fixing before we make it visible
//			 compassOverlay
			overlayControls
			// Only block the map with the full-screen spinner when there's nothing
			// to show yet. With on-disk caching (#9), a cached snapshot can already
			// be on screen while a background refresh is in flight — blocking that
			// with an overlay would hide perfectly good data for no reason.
			if viewModel.showTrashcans && viewModel.trashcanLoading && viewModel.trashcanRecords.isEmpty {
				Color.black.opacity(0.2).ignoresSafeArea()
				ProgressView("Loading locations…")
					.padding(30)
					.background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
					.shadow(radius: 10)
			}
			if viewModel.showYouBikes && viewModel.youBikeLoading && !hasYouBikeDataForCurrentCity {
				Color.black.opacity(0.2).ignoresSafeArea()
				ProgressView("Loading YouBike stations…")
					.padding(30)
					.background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
					.shadow(radius: 10)
			}
			// AQI previously had no loading indicator at all — the very first
			// launch (before init()'s cache preload and the first live fetch both
			// have a chance to complete) showed a totally blank map with nothing
			// to explain why. Same "only block if nothing to show" rule as above.
			if !viewModel.showTrashcans && !viewModel.showYouBikes,
			   viewModel.isLoadingAirQualityData, viewModel.aqiRecords.isEmpty {
				Color.black.opacity(0.2).ignoresSafeArea()
				ProgressView("Loading air quality data…")
					.padding(30)
					.background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
					.shadow(radius: 10)
			}
			// Surfaces fetch failures and empty upstream responses on the AQI layer.
			// When cached data is still on screen (preferred fallback), aqiFetchError
			// stays nil and this banner is hidden.
			if !viewModel.showTrashcans && !viewModel.showYouBikes,
			   !viewModel.isLoadingAirQualityData,
			   viewModel.aqiRecords.isEmpty {
				VStack {
					if viewModel.aqiFetchError != nil {
						aqiErrorBanner(viewModel.aqiFetchError ?? "")
					} else {
						emptyAreaBanner("No air quality data yet. Pull to refresh or tap the refresh button.")
					}
					Spacer()
				}
			}
			// Same pattern for YouBike. Particularly relevant for Taichung, whose
			// endpoint (roadmap item #6) couldn't be independently confirmed as
			// still valid — if it's gone stale or dead, this is the fallback UX
			// rather than a silent empty map.
			if viewModel.showYouBikes, let error = viewModel.youBikeFetchError {
				VStack {
					youBikeErrorBanner(error)
					Spacer()
				}
			}
			// Completes the error-surfacing pattern across all three data layers
			// (AQI, YouBike, trashcans — roadmap item #7).
			if viewModel.showTrashcans, let error = viewModel.trashcanFetchError {
				VStack {
					trashcanErrorBanner(error)
					Spacer()
				}
			}
			// Trashcans only cover Taipei, and YouBike coverage is city-specific —
			// removing the auto-recenter-on-layer-switch behavior (so panning/zoom
			// the user already did isn't discarded) means it's now possible to
			// select a layer while looking at an area with genuinely zero pins.
			// These let the user know that's what's happening, rather than a
			// silently empty map that looks identical to a loading or error state.
			if viewModel.showTrashcans, viewModel.trashcanFetchError == nil, !viewModel.trashcanLoading,
			   !viewModel.trashcanRecords.isEmpty, visibleTrashcanAnnotations.isEmpty {
				VStack {
					emptyAreaBanner("No trash cans in this area. Trash cans are only mapped in Taipei. Pan the map and/or adjust zoom level to find one.")
					Spacer()
				}
			}
			if viewModel.showYouBikes, viewModel.youBikeFetchError == nil, !viewModel.youBikeLoading,
			   hasYouBikeDataForCurrentCity, visibleYouBikeAnnotations.isEmpty {
				VStack {
					emptyAreaBanner("No YouBike stations in this area. Pan the map to \(viewModel.youBikeCity == .taichung ? "Taichung" : "Taipei") and/or adjust zoom level.")
					Spacer()
				}
			}
		}
		.onAppear {
			viewModel.fetchAQIData()
		}
		.onOpenURL { url in
			handleDeepLink(url)
		}
		.onReceive(viewModel.locationManager.$heading) { heading in
			userHeading = heading
		}
		.onChange(of: selectedLayer) { oldValue, newValue in
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
				case .youBikesTaipei:
					viewModel.youBikeCity = .taipei
					viewModel.fetchYouBikeStations()
					viewModel.showYouBikes = true
					viewModel.showTrashcans = false
					showAnnotations = false
				case .youBikesTaichung:
					viewModel.youBikeCity = .taichung
					viewModel.fetchYouBikeStations()
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
	
	private var compassOverlay: some View {
		VStack {
			HStack {
				Spacer()

				MapCompass(scope: mapScope)
					.mapControlVisibility(.automatic)
					.padding(.top, 100)
					.padding(.trailing, 8)
			}

			Spacer()
		}
	}
	private var visibleTrashcanAnnotations: [TrashcanCluster] {
		viewModel.trashcanAnnotations(for: viewModel.region)
			.filter { isWithin1km(of: viewModel.region.center, coordinate: $0.coordinate) }
	}

	private var visibleYouBikeAnnotations: [YouBikeCluster] {
		viewModel.youBikeAnnotations(for: viewModel.region)
			.filter { isWithin1km(of: viewModel.region.center, coordinate: $0.coordinate) }
	}

	// Whether the currently-selected YouBike city actually has any data loaded
	// (as opposed to visibleYouBikeAnnotations being empty just because nothing
	// has loaded yet, or the request failed).
	private var hasYouBikeDataForCurrentCity: Bool {
		switch viewModel.youBikeCity {
		case .taipei: return !viewModel.youBikeStations.isEmpty
		case .taichung: return !viewModel.taichungYouBikeStations.isEmpty
		}
	}

	// Bridges the legacy MKCoordinateRegion (viewModel.region — still the single
	// source of truth for the clustering math, the empty-area banners, and
	// isWithin1km) to the MapCameraPosition the modern, non-deprecated Map API
	// expects. Reading this always reflects the current viewModel.region;
	// writing to it (e.g. from the tap-to-center pin handlers below) writes
	// straight back into viewModel.region.
	//
	// NOTE: this binding's `set` is only reliably invoked for *programmatic*
	// camera moves (like the tap-to-center handlers). It is NOT a channel for
	// observing the user's own interactive pan/zoom gestures — that requires
	// .onMapCameraChange below. Without it, viewModel.region (and therefore
	// every pin/cluster filtered off it) stays frozen at whatever it was last
	// set to programmatically, ignoring anything the user does by hand.
	private var cameraPositionBinding: Binding<MapCameraPosition> {
		Binding(
			get: { .region(viewModel.region) },
			set: { newPosition in
				if let newRegion = newPosition.region {
					viewModel.region = newRegion
				}
			}
		)
	}

	// The actual channel for keeping viewModel.region in sync with the user's
	// own panning/zooming. .onEnd (rather than .continuous) means clustering
	// and the visible-annotation lists only recompute once a gesture settles,
	// not on every intermediate frame while dragging — cheaper, and avoids
	// pins/clusters visibly reshuffling mid-drag. Device heading is tracked
	// separately through LocationManager and rotates only the custom user-location
	// annotation; it never changes the map camera.
	private func syncRegionOnCameraChange<V: View>(_ view: V) -> some View {
		view.onMapCameraChange(frequency: .onEnd) { context in
			viewModel.region = context.region
		}
	}

	// Named constants for what were previously magic numbers (0.6, 1.6, 0.3, 0.3)
	// scattered across the per-layer tap handlers below.
	private enum PinInteraction {
		static let centerAnimation = Animation.easeInOut(duration: 0.5)
		static let bounceAnimation = Animation.spring(response: 0.3, dampingFraction: 0.3)
		static let bounceScale: CGFloat = 1.6
		static let sheetPresentDelay: TimeInterval = 0.6
	}

	// Shared by youBikeMap and aqiMap — both previously had their own near-identical
	// copy of "bounce the pin, recenter the map, then present a detail sheet after
	// the animation finishes" with the same magic numbers duplicated in each place.
	// Trashcan pins don't use this: they aren't individually tappable at all (see
	// roadmap item — there's no per-can detail worth showing, just a shared address/
	// fine-notice message identical across all 691 records).
	@ViewBuilder
	private func bouncingPinButton<Item: Equatable, Pin: View>(
		item: Item,
		coordinate: CLLocationCoordinate2D,
		centerLatitudeOffset: CLLocationDegrees,
		centerSpan: MKCoordinateSpan,
		accessibilityLabel: String,
		bouncing: Binding<Item?>,
		centering: Binding<Item?>,
		selection: Binding<Item?>,
		@ViewBuilder pin: () -> Pin
	) -> some View {
		Button {
			withAnimation(PinInteraction.centerAnimation) {
				centering.wrappedValue = item
				bouncing.wrappedValue = item
				viewModel.region = MKCoordinateRegion(
					center: CLLocationCoordinate2D(latitude: coordinate.latitude + centerLatitudeOffset, longitude: coordinate.longitude),
					span: centerSpan
				)
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + PinInteraction.sheetPresentDelay) {
				selection.wrappedValue = item
			}
		} label: {
			pin()
				.scaleEffect(bouncing.wrappedValue == item ? PinInteraction.bounceScale : 1.0)
				.animation(PinInteraction.bounceAnimation, value: bouncing.wrappedValue == item)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(accessibilityLabel)
	}

	private var trashcanMap: some View {
		syncRegionOnCameraChange(
			Map(position: cameraPositionBinding, scope: mapScope) {
				userLocationAnnotation
				ForEach(visibleTrashcanAnnotations) { cluster in
					Annotation(
						cluster.count == 1 ? "Trash can" : "\(cluster.count) trash cans",
						coordinate: cluster.coordinate
					) {
						TrashcanPinView(count: cluster.count)
					}
				}
			}
			.mapControlVisibility(.hidden)
		)
	}

	private var youBikeMap: some View {
		syncRegionOnCameraChange(
			Map(position: cameraPositionBinding, scope: mapScope) {
				userLocationAnnotation
				ForEach(visibleYouBikeAnnotations) { cluster in
					Annotation(
						cluster.count == 1 ? cluster.name : "\(cluster.count) YouBike stations",
						coordinate: cluster.coordinate
					) {
						if cluster.count == 1,
							let station = findStationAtCoordinate(cluster.coordinate) {
							bouncingPinButton(
								item: station,
								coordinate: cluster.coordinate,
								centerLatitudeOffset: -0.002,
								centerSpan: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0055),
								accessibilityLabel: "\(cluster.name.replacingOccurrences(of: "YouBike2.0_", with: "")), \(station.available_rent_bikes) bikes available, \(station.available_return_bikes) docks open",
								bouncing: $bouncingYouBikeStation,
								centering: $youBikeStationToCenter,
								selection: $selectedYouBikeStation
							) {
								YouBikePinView(count: nil)
							}
						} else {
							YouBikePinView(count: cluster.count)
						}
					}
				}
			}
				.mapControlVisibility(.hidden)
		)
	}
	
	private func findStationAtCoordinate(_ coordinate: CLLocationCoordinate2D) -> YouBikeStation? {
		switch viewModel.youBikeCity {
		case .taipei:
			return viewModel.youBikeStations.first(where: {
				abs($0.latitude - coordinate.latitude) < 0.00001 &&
				abs($0.longitude - coordinate.longitude) < 0.00001
			})
		case .taichung:
			if let s = viewModel.taichungYouBikeStations.first(where: {
				abs($0.latitude - coordinate.latitude) < 0.00001 &&
				abs($0.longitude - coordinate.longitude) < 0.00001
			}) {
				return YouBikeStation(
					sno: s.sno,
					sna: s.sna,
					snaen: s.snaen,
					longitude: s.longitude,
					latitude: s.latitude,
					available_rent_bikes: s.available_rent_bikes,
					available_return_bikes: s.available_return_bikes,
					updateTime: s.updateTime,
					infoTime: s.infoTime,
					srcUpdateTime: s.srcUpdateTime
				)
			}
			return nil
		}
	}

	private var aqiMap: some View {
		syncRegionOnCameraChange(
			Map(position: cameraPositionBinding, scope: mapScope) {
				userLocationAnnotation
				ForEach(viewModel.aqiRecords) { record in
					Annotation(record.siteName, coordinate: record.coordinate) {
						let color = selectedMeasurement.color(for: selectedMeasurement.value(in: record))
						if displayMode == .heatmap {
							Circle()
								.fill(RadialGradient(gradient: Gradient(colors: [color, color.opacity(0)]), center: .center, startRadius: 10, endRadius: 50))
								.frame(width: 100, height: 100)
								.opacity(0.6)
						} else {
							bouncingPinButton(
								item: record,
								coordinate: record.coordinate,
								centerLatitudeOffset: -0.010,
								centerSpan: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05),
								accessibilityLabel: "\(record.siteName), \(selectedMeasurement.rawValue) \(selectedMeasurement.displayValue(for: record)), \(record.status)",
								bouncing: $bouncingRecord,
								centering: $recordToCenter,
								selection: $selectedAirQualityRecord
							) {
								PinView(color: color, value: selectedMeasurement.displayValue(for: record))
							}
						}
					}
				}
			}
				.mapControlVisibility(.hidden)
		)
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
					favoritesButton
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
					switch layer {
					case .youBikesTaipei, .youBikesTaichung:
						Label(layer.localizedName, systemImage: layer.icon).tag(layer)
					default:
						Label(layer.localizedName, systemImage: layer.icon).tag(layer)
					}
				}
			}
			Divider()
			Picker("Map style", selection: $selectedMapStyle) {
				ForEach(MapStyleOption.allCases, id: \.self) { type in
					Text(type.localizedName).tag(type)
				}
			}
			.pickerStyle(.menu)
		} label: {
			ControlButton(iconName: "square.3.layers.3d", fontSize: 15, padding: 11)
		}
		.accessibilityLabel("Map layers and style")
	}

	private var locationButton: some View {
		Button {
			switch viewModel.locationManager.authorizationStatus {
			case .authorizedWhenInUse, .authorizedAlways:
				// Authorized but userLocation can still be nil briefly (first
				// fix hasn't arrived yet) — nothing useful to center on yet,
				// so this stays a no-op rather than showing an alert.
				if let loc = viewModel.locationManager.userLocation {
					viewModel.region = MKCoordinateRegion(center: loc, span: .init(latitudeDelta: 0.005, longitudeDelta: 0.005))
				}
			case .denied, .restricted:
				isShowingLocationPermissionAlert = true
			case .notDetermined:
				// Shouldn't normally happen post-launch (already requested in
				// LocationManager.init()), but re-prompt rather than no-op if
				// the system somehow hasn't resolved it yet.
				viewModel.locationManager.requestLocationPermission()
			@unknown default:
				break
			}
		} label: {
			ControlButton(iconName: "location", fontSize: 16, padding: 11)
		}
		.accessibilityLabel("Center on my location")
		.alert("Location Access Needed", isPresented: $isShowingLocationPermissionAlert) {
			Button("Open Settings") {
				if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
					UIApplication.shared.open(settingsURL)
				}
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("TaiFind needs location access to show your position on the map. You can enable this in Settings.")
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
		.accessibilityLabel("Refresh data")
	}

	private var infoButton: some View {
		Button {
			isShowingInfo.toggle()
		} label: {
			ControlButton(iconName: "info", fontSize: 18, padding: 14)
		}
		.accessibilityLabel("Information")
	}

	private var favoritesButton: some View {
		Button {
			isShowingFavorites = true
		} label: {
			ControlButton(iconName: "star", fontSize: 15, padding: 11)
		}
		.accessibilityLabel("Favorites")
		.sheet(isPresented: $isShowingFavorites) {
			FavoritesListView { favorite in
				navigateTo(type: favorite.type, stationID: favorite.stationID)
			}
			.presentationDragIndicator(.visible)
		}
	}

	// Switches to the correct layer and recenters the map on a station —
	// used both by the in-app Favorites list (tap a row) and by widget deep
	// links (tap a favorite in the widget, which opens the app via .onOpenURL
	// below). Deliberately doesn't force-open the station's detail sheet —
	// just gets the user looking at the right pin; they can tap it themselves
	// if they want the full detail view.
	private func navigateTo(type: FavoriteType, stationID: String) {
		switch type {
		case .aqi:
			selectedLayer = .aqi
			if let record = viewModel.aqiRecords.first(where: { $0.siteID == stationID }) {
				withAnimation(PinInteraction.centerAnimation) {
					viewModel.region = MKCoordinateRegion(
						center: record.coordinate,
						span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
					)
				}
			}
		case .youBikeTaipei:
			selectedLayer = .youBikesTaipei
			if let station = viewModel.youBikeStations.first(where: { $0.sno == stationID }) {
				withAnimation(PinInteraction.centerAnimation) {
					viewModel.region = MKCoordinateRegion(
						center: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude),
						span: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0055)
					)
				}
			}
		case .youBikeTaichung:
			selectedLayer = .youBikesTaichung
			if let station = viewModel.taichungYouBikeStations.first(where: { $0.sno == stationID }) {
				withAnimation(PinInteraction.centerAnimation) {
					viewModel.region = MKCoordinateRegion(
						center: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude),
						span: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0055)
					)
				}
			}
		}
	}

	// Parses "taifind://station/<type>/<stationID>" from a widget tap and
	// routes to the same navigateTo(...) the in-app Favorites list uses.
	// Malformed/unrecognized URLs are ignored rather than crashing — a stale
	// or manually-typed URL shouldn't be able to take down the app.
	private func handleDeepLink(_ url: URL) {
		guard url.scheme == "taifind",
			  url.host == "station",
			  let type = FavoriteType(urlPathComponent: url.pathComponents.dropFirst().first ?? "") else {
			return
		}
		let stationID = url.pathComponents.dropFirst(2).first ?? ""
		guard !stationID.isEmpty else { return }
		if isShowingFavorites { isShowingFavorites = false }
		navigateTo(type: type, stationID: stationID)
	}

	private func aqiErrorBanner(_ message: String) -> some View {
		Button {
			viewModel.fetchAQIData()
		} label: {
			HStack(spacing: 8) {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
				Text("Couldn't update air quality data. Tap to retry.")
					.font(.caption)
					.fontWeight(.semibold)
					.foregroundStyle(.primary)
					.multilineTextAlignment(.leading)
				Spacer()
				if viewModel.isLoadingAirQualityData {
					ProgressView()
						.controlSize(.small)
				}
			}
			.padding(10)
			.background(Color(.secondarySystemBackground).opacity(0.95))
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.shadow(radius: 2)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
		.padding(.top, 8)
	}

	private func youBikeErrorBanner(_ message: String) -> some View {
		Button {
			viewModel.fetchYouBikeStations()
		} label: {
			HStack(spacing: 8) {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
				Text("Couldn't load \(viewModel.youBikeCity == .taichung ? "Taichung" : "Taipei") YouBike stations. Tap to retry.")
					.font(.caption)
					.fontWeight(.semibold)
					.foregroundStyle(.primary)
					.multilineTextAlignment(.leading)
				Spacer()
				if viewModel.youBikeLoading {
					ProgressView()
						.controlSize(.small)
				}
			}
			.padding(10)
			.background(Color(.secondarySystemBackground).opacity(0.95))
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.shadow(radius: 2)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
		.padding(.top, 8)
	}

	// Informational only (not a Button, unlike the error banners) — there's
	// nothing to retry here, the fetch succeeded, the data just isn't near the
	// current map position. Disappears automatically as the user pans into an
	// area that has pins, since visibleTrashcanAnnotations/visibleYouBikeAnnotations
	// recompute live off viewModel.region.
	private func emptyAreaBanner(_ message: String) -> some View {
		HStack(spacing: 8) {
			Image(systemName: "mappin.slash")
				.foregroundStyle(.secondary)
			Text(message)
				.font(.caption)
				.fontWeight(.semibold)
				.foregroundStyle(.primary)
				.multilineTextAlignment(.leading)
			Spacer()
		}
		.padding(10)
		.background(Color(.secondarySystemBackground).opacity(0.95))
		.clipShape(RoundedRectangle(cornerRadius: 10))
		.shadow(radius: 2)
		.padding(.horizontal)
		.padding(.top, 8)
	}

	private func trashcanErrorBanner(_ message: String) -> some View {
		Button {
			viewModel.fetchTrashcanData()
		} label: {
			HStack(spacing: 8) {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.orange)
				Text("Couldn't load trash can locations. Tap to retry.")
					.font(.caption)
					.fontWeight(.semibold)
					.foregroundStyle(.primary)
					.multilineTextAlignment(.leading)
				Spacer()
				if viewModel.trashcanLoading {
					ProgressView()
						.controlSize(.small)
				}
			}
			.padding(10)
			.background(Color(.secondarySystemBackground).opacity(0.95))
			.clipShape(RoundedRectangle(cornerRadius: 10))
			.shadow(radius: 2)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
		.padding(.top, 8)
	}

	private func isWithin1km(of center: CLLocationCoordinate2D, coordinate: CLLocationCoordinate2D) -> Bool {
		let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
		let checkLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
		return centerLocation.distance(from: checkLocation) <= 1000
	}
	
	@MapContentBuilder
	private var userLocationAnnotation: some MapContent {
		if let coordinate = viewModel.locationManager.userLocation {
			Annotation("Your location", coordinate: coordinate, anchor: .center) {
				UserHeadingCone(heading: userHeading)
			}
		}
	}
}

private struct UserHeadingCone: View {
	let heading: CLLocationDirection

	var body: some View {
		ZStack {
			Image(systemName: "cone.fill")
				.font(.system(size: 34, weight: .semibold))
				.symbolRenderingMode(.monochrome)
				.foregroundStyle(
					LinearGradient(
						gradient: Gradient(stops: [
							.init(color: .blue.opacity(0.28), location: 0.0),
							.init(color: .blue.opacity(0.28), location: 0.5),
							.init(color: .blue.opacity(0.05), location: 1.0)
						]),
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.offset(x: 0, y: 10)

			Circle()
				.fill(.blue)
				.frame(width: 16, height: 16)
				.overlay {
					Circle()
						.stroke(.white, lineWidth: 3)
				}
		}
		// 0° is north/up; 90° points east/right on the fixed north-up map.
		.rotationEffect(.degrees(heading + 180))
		.accessibilityLabel("Your location and heading")
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

#Preview("Traditional Chinese") {
	let viewModel = AQIViewModel()
	viewModel.region = MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: 25.0336, longitude: 121.565),
		span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
	)
	return MapView()
		.environmentObject(viewModel)
		.environment(\.locale, Locale(identifier: "zh-Hant"))
}

#Preview("Heading View") {
	UserHeadingCone(heading: 45)
}
