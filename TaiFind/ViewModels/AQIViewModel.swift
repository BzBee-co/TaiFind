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
	// Set on a failed AQI fetch, cleared on the next successful one. Not yet
	// surfaced in any view — wiring up an actual error UI is a separate item —
	// but the signal now exists instead of the fetch silently hanging forever.
	@Published var aqiFetchError: String? = nil

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

	func fetchAQIData() {
		isLoadingAirQualityData = true
		APIService.fetchAQI { [weak self] result in
			DispatchQueue.main.async {
				switch result {
				case .success(let records):
					self?.aqiRecords = records
					self?.aqiFetchError = nil
				case .failure(let error):
					// Keep whatever aqiRecords already has rather than clearing the
					// map on a transient failure; just surface the error.
					self?.aqiFetchError = error.localizedDescription
					print("❌ AQI fetch failed: \(error.localizedDescription)")
				}
				self?.isLoadingAirQualityData = false
			}
		}
	}


	func fetchTrashcanData() {
		trashcanLoading = true
		// APIService.fetchTrashcans returns nil on failure (network error, bad
		// decode, etc.) rather than an empty array — on failure we keep whatever
		// trashcanRecords already has instead of wiping pins the user can already
		// see off the map.
		APIService.fetchTrashcans { [weak self] records in
			DispatchQueue.main.async {
				if let records = records {
					self?.trashcanRecords = records
				}
				self?.trashcanLoading = false
			}
		}
	}

	func fetchYouBikeStations() {
		youBikeLoading = true
		switch youBikeCity {
		case .taipei:
			APIService.fetchYouBikeStations { [weak self] stations in
				DispatchQueue.main.async {
					self?.youBikeStations = stations
					self?.youBikeLoading = false
				}
			}
		case .taichung:
			APIService.fetchTaichungYouBikeStations { [weak self] stations in
				DispatchQueue.main.async {
					self?.taichungYouBikeStations = stations
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
