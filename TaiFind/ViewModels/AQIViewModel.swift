import Foundation
import CoreLocation
import MapKit
import Combine
import SwiftUI

class AQIViewModel: ObservableObject {
	@Published var aqiRecords: [AQIRecord] = []
	@Published var trashcanRecords: [TrashcanRecord] = []
	@Published var youBikeStations: [YouBikeStation] = []
	@Published var taichungYouBikeStations: [TaichungYouBikeStation] = []
	@Published var showTrashcans: Bool = false
	@Published var showYouBikes: Bool = false
	@Published var youBikeCity: YouBikeCity = .taipei
	@Published var trashcanLoading: Bool = false
	@Published var youBikeLoading: Bool = false
	@Published var region = MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: 25.0336, longitude: 121.565),
		span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
	)
	
	@Published var isLoadingAirQualityData: Bool = false
	// Set on a failed AQI fetch, cleared on the next successful one. Surfaced via
	// aqiErrorBanner in MapView.
	@Published var aqiFetchError: String? = nil
	// Same idea, for whichever YouBike city is currently selected. Taichung's
	// endpoint in particular couldn't be independently verified as still valid
	// (see roadmap item #6), so this is the safety net if it's gone stale/dead.
	@Published var youBikeFetchError: String? = nil
	// Same pattern for trashcans — completes the error-surfacing work started
	// with AQI (#4/#5) and YouBike (#6) across all three data layers (#7).
	@Published var trashcanFetchError: String? = nil
	// User-starred stations, persisted via FavoritesStore to the shared App
	// Group container so a widget extension can read them too.
	@Published var favorites: [FavoriteStation] = []

	enum YouBikeCity: String, CaseIterable {
		case taipei = "Taipei City"
		case taichung = "Taichung City"
		
		var localizedName: LocalizedStringKey {
			switch self {
			case .taipei: return "Taipei City"
			case .taichung: return "Taichung City"
			}
		}
	}


	let locationManager = LocationManager()
	private var cancellables = Set<AnyCancellable>()

	init() {
		// Show last-known-good data immediately on cold launch, even before the
		// network round-trip in fetchAQIData() below completes — otherwise the
		// map is empty until the first fetch resolves, and stays empty forever
		// if the device is offline at launch.
		if let cached = LocalCache.load([AQIRecord].self, forKey: CacheKeys.aqiRecords) {
			aqiRecords = cached.value
		}

		favorites = FavoritesStore.load()

		fetchAQIData()

		locationManager.$userLocation
			.compactMap { $0 }
			.sink { [weak self] newLocation in
				let latitudeDelta = 10 / 111.0
				let longitudeDelta = 10 / 111.0

				self?.region = MKCoordinateRegion(
					center: newLocation,
					span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
				)
			}
			.store(in: &cancellables)
	}

	// Cache key constants moved to the shared CacheKeys enum (AppGroup.swift)
	// so the widget extension reads the exact same keys the app writes.

	// MARK: - Favorites

	func isFavorite(type: FavoriteType, stationID: String) -> Bool {
		favorites.contains { $0.type == type && $0.stationID == stationID }
	}

	func toggleFavorite(type: FavoriteType, stationID: String, displayName: String) {
		if let index = favorites.firstIndex(where: { $0.type == type && $0.stationID == stationID }) {
			favorites.remove(at: index)
		} else {
			favorites.append(FavoriteStation(type: type, stationID: stationID, displayName: displayName))
		}
		FavoritesStore.save(favorites)
	}

	func removeFavorite(_ favorite: FavoriteStation) {
		favorites.removeAll { $0.id == favorite.id }
		FavoritesStore.save(favorites)
	}

	func removeFavorites(at offsets: IndexSet) {
		favorites.remove(atOffsets: offsets)
		FavoritesStore.save(favorites)
	}

	func fetchAQIData() {
		isLoadingAirQualityData = true
		APIService.fetchAQI { [weak self] result in
			DispatchQueue.main.async {
				switch result {
				case .success(let records):
					self?.aqiRecords = records
					self?.aqiFetchError = nil
					LocalCache.save(records, forKey: CacheKeys.aqiRecords)
				case .failure(let error):
					// Keep whatever aqiRecords already has rather than clearing the
					// map on a transient failure; just surface the error. (If this
					// is a cold, offline launch, aqiRecords may already hold the
					// cached snapshot loaded in init() above — nothing further to
					// do here in that case either.)
					self?.aqiFetchError = error.localizedDescription
					print("❌ AQI fetch failed: \(error.localizedDescription)")
				}
				self?.isLoadingAirQualityData = false
			}
		}
	}


	func fetchTrashcanData() {
		// Trashcans (unlike AQI) only fetch on demand when the user toggles the
		// layer on, so there's no init()-time preload. If this is the first
		// time this session the layer's been opened, show the cached snapshot
		// immediately rather than a blank map while the live fetch is in flight.
		if trashcanRecords.isEmpty,
		   let cached = LocalCache.load([TrashcanRecord].self, forKey: CacheKeys.trashcanRecords) {
			trashcanRecords = cached.value
		}

		trashcanLoading = true
		// On failure, keep whatever trashcanRecords already has instead of
		// wiping pins the user can already see off the map — just surface
		// the error via trashcanFetchError.
		APIService.fetchTrashcans { [weak self] result in
			DispatchQueue.main.async {
				switch result {
				case .success(let records):
					self?.trashcanRecords = records
					self?.trashcanFetchError = nil
					LocalCache.save(records, forKey: CacheKeys.trashcanRecords)
				case .failure(let error):
					self?.trashcanFetchError = error.localizedDescription
					print("❌ Trashcan fetch failed: \(error.localizedDescription)")
				}
				self?.trashcanLoading = false
			}
		}
	}

	func fetchYouBikeStations() {
		// Same on-demand cache preload as trashcans, per city.
		switch youBikeCity {
		case .taipei:
			if youBikeStations.isEmpty,
			   let cached = LocalCache.load([YouBikeStation].self, forKey: CacheKeys.youBikeTaipeiStations) {
				youBikeStations = cached.value
			}
		case .taichung:
			if taichungYouBikeStations.isEmpty,
			   let cached = LocalCache.load([TaichungYouBikeStation].self, forKey: CacheKeys.youBikeTaichungStations) {
				taichungYouBikeStations = cached.value
			}
		}

		youBikeLoading = true
		switch youBikeCity {
		case .taipei:
			APIService.fetchYouBikeStations { [weak self] result in
				DispatchQueue.main.async {
					switch result {
					case .success(let stations):
						self?.youBikeStations = stations
						self?.youBikeFetchError = nil
						LocalCache.save(stations, forKey: CacheKeys.youBikeTaipeiStations)
					case .failure(let error):
						// Keep existing stations on screen; just surface the error.
						self?.youBikeFetchError = error.localizedDescription
						print("❌ Taipei YouBike fetch failed: \(error.localizedDescription)")
					}
					self?.youBikeLoading = false
				}
			}
		case .taichung:
			APIService.fetchTaichungYouBikeStations { [weak self] result in
				DispatchQueue.main.async {
					switch result {
					case .success(let stations):
						self?.taichungYouBikeStations = stations
						self?.youBikeFetchError = nil
						LocalCache.save(stations, forKey: CacheKeys.youBikeTaichungStations)
					case .failure(let error):
						self?.youBikeFetchError = error.localizedDescription
						print("❌ Taichung YouBike fetch failed: \(error.localizedDescription)")
					}
					self?.youBikeLoading = false
				}
			}
		}
	}
}

// MARK: - Helpers

extension CLLocationCoordinate2D {
	func gridKey(latGrid: Double, lonGrid: Double) -> String {
		let lat = (latitude / latGrid).rounded(.down) * latGrid
		let lon = (longitude / lonGrid).rounded(.down) * lonGrid
		return "\(lat),\(lon)"
	}
}

// MARK: - Trashcan Clustering

struct TrashcanCluster: Identifiable {
	let id: String
	let coordinate: CLLocationCoordinate2D
	let count: Int
}

extension AQIViewModel {
	func trashcanAnnotations(for region: MKCoordinateRegion) -> [TrashcanCluster] {
		let latGrid = region.span.latitudeDelta / 10
		let lonGrid = region.span.longitudeDelta / 10
		var clusters: [String: [TrashcanRecord]] = [:]

		for record in trashcanRecords {
			guard let lat = Double(record.latitude),
				  let lon = Double(record.longitude) else { continue }

			let key = CLLocationCoordinate2D(latitude: lat, longitude: lon)
				.gridKey(latGrid: latGrid, lonGrid: lonGrid)

			clusters[key, default: []].append(record)
		}

		return clusters.map { (key, records) in
			let first = records[0]
			let lat = Double(first.latitude) ?? 0
			let lon = Double(first.longitude) ?? 0
			return TrashcanCluster(
				id: key,
				coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
				count: records.count
			)
		}
	}
}

// MARK: - YouBike Clustering

struct YouBikeCluster: Identifiable {
	let id: String
	let coordinate: CLLocationCoordinate2D
	let count: Int
	let availableRentBikes: Int
	let availableReturnBikes: Int
	let updateTime: String
	let infoTime: String
	let srcUpdateTime: String
	let name: String
}

extension AQIViewModel {
	func youBikeAnnotations(for region: MKCoordinateRegion) -> [YouBikeCluster] {
		let latGrid = region.span.latitudeDelta / 10
		let lonGrid = region.span.longitudeDelta / 10
		var clusters: [String: [AnyYouBikeStation]] = [:]

		switch youBikeCity {
		case .taipei:
			for station in youBikeStations {
				let anyStation = AnyYouBikeStation.taipei(station)
				let key = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
					.gridKey(latGrid: latGrid, lonGrid: lonGrid)
				clusters[key, default: []].append(anyStation)
			}
		case .taichung:
			for station in taichungYouBikeStations {
				let anyStation = AnyYouBikeStation.taichung(station)
				let key = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
					.gridKey(latGrid: latGrid, lonGrid: lonGrid)
				clusters[key, default: []].append(anyStation)
			}
		}

		return clusters.map { (key, stations) in
			let first = stations[0]
			let totalRent = stations.reduce(0) { $0 + $1.available_rent_bikes }
			let totalReturn = stations.reduce(0) { $0 + $1.available_return_bikes }

			return YouBikeCluster(
				id: key,
				coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
				count: stations.count,
				availableRentBikes: totalRent,
				availableReturnBikes: totalReturn,
				updateTime: first.updateTime,
				infoTime: first.infoTime,
				srcUpdateTime: first.srcUpdateTime,
				name: first.name
			)
		}
	}
}

// MARK: - Unified YouBike Station Type

enum AnyYouBikeStation {
	case taipei(YouBikeStation)
	case taichung(TaichungYouBikeStation)
	
	var latitude: Double {
		switch self {
		case .taipei(let station): return station.latitude
		case .taichung(let station): return station.latitude
		}
	}
	
	var longitude: Double {
		switch self {
		case .taipei(let station): return station.longitude
		case .taichung(let station): return station.longitude
		}
	}
	
	var available_rent_bikes: Int {
		switch self {
		case .taipei(let station): return station.available_rent_bikes
		case .taichung(let station): return station.available_rent_bikes
		}
	}
	
	var available_return_bikes: Int {
		switch self {
		case .taipei(let station): return station.available_return_bikes
		case .taichung(let station): return station.available_return_bikes
		}
	}
	
	var updateTime: String {
		switch self {
		case .taipei(let station): return station.updateTime
		case .taichung(let station): return station.updateTime
		}
	}
	
	var infoTime: String {
		switch self {
		case .taipei(let station): return station.infoTime
		case .taichung(let station): return station.infoTime
		}
	}
	
	var srcUpdateTime: String {
		switch self {
		case .taipei(let station): return station.srcUpdateTime
		case .taichung(let station): return station.srcUpdateTime
		}
	}
	
	var name: String {
		switch self {
		case .taipei(let station): return station.snaen
		case .taichung(let station): return station.snaen
		}
	}
	
	var originalStation: Any {
		switch self {
		case .taipei(let station): return station
		case .taichung(let station): return station
		}
	}
}
