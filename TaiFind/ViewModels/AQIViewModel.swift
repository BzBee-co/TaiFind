import Foundation
import CoreLocation
import MapKit
import Combine


class AQIViewModel: ObservableObject {
    @Published var aqiRecords: [AQIRecord] = []
    @Published var trashcanRecords: [TrashcanRecord] = []
    @Published var youBikeStations: [YouBikeStation] = []
    @Published var showTrashcans: Bool = false
    @Published var showYouBikes: Bool = false
    @Published var trashcanLoading: Bool = false
    @Published var youBikeLoading: Bool = false
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0336, longitude: 121.565),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchAQIData()
        
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                // Update region to user's location with 10 km radius
                let latitudeDelta = 10 / 111.0  // Rough conversion from km to degrees (latitude)
                let longitudeDelta = 10 / 111.0 // Same for longitude, depending on location
                
                self?.region = MKCoordinateRegion(
                    center: newLocation,
                    span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
                )
            }
            .store(in: &cancellables)
    }
    
    func fetchAQIData() {
        APIService.fetchAQI { [weak self] records in
            DispatchQueue.main.async {
                self?.aqiRecords = records
            }
        }
    }
    
    func fetchTrashcanData() {
        trashcanLoading = true
        DispatchQueue.global(qos: .userInteractive).async {
            APIService.fetchAllTrashcans { [weak self] records in
                DispatchQueue.main.async {
                    self?.trashcanRecords = records
                    self?.trashcanLoading = false
                }
            }
        }
    }
    
    func fetchYouBikeStations() {
        youBikeLoading = true
        DispatchQueue.global(qos: .userInteractive).async {
            APIService.fetchYouBikeStations { [weak self] stations in
                DispatchQueue.main.async {
                    self?.youBikeStations = stations
                    self?.youBikeLoading = false
                }
            }
        }
    }
}

extension CLLocationCoordinate2D {
    func gridKey(latGrid: Double, lonGrid: Double) -> String {
        let lat = (latitude / latGrid).rounded(.down) * latGrid
        let lon = (longitude / lonGrid).rounded(.down) * lonGrid
        return "\(lat),\(lon)"
    }
}

struct TrashcanCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
}

extension AQIViewModel {
    // Returns either clusters or individual pins based on zoom/region
    func trashcanAnnotations(for region: MKCoordinateRegion) -> [TrashcanCluster] {
        let latGrid = region.span.latitudeDelta / 10
        let lonGrid = region.span.longitudeDelta / 10
        var clusters: [String: [TrashcanRecord]] = [:]
        for record in trashcanRecords {
            guard let lat = Double(record.latitude), let lon = Double(record.longitude) else { continue }
            let key = CLLocationCoordinate2D(latitude: lat, longitude: lon).gridKey(latGrid: latGrid, lonGrid: lonGrid)
            clusters[key, default: []].append(record)
        }
        let clusterList = clusters.map { (key, records) -> TrashcanCluster in
            let first = records[0]
            let lat = Double(first.latitude) ?? 0
            let lon = Double(first.longitude) ?? 0
            return TrashcanCluster(id: key, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), count: records.count)
        }
        // Only show individuals if each cluster is a single trashcan
        if clusterList.count == trashcanRecords.count {
            return clusterList
        } else {
            return clusterList
        }
    }
}

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
        var clusters: [String: [YouBikeStation]] = [:]
        for station in youBikeStations {
            let key = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude).gridKey(latGrid: latGrid, lonGrid: lonGrid)
            clusters[key, default: []].append(station)
        }
        let clusterList = clusters.map { (key, stations) -> YouBikeCluster in
            let first = stations[0]
            let lat = first.latitude
            let lon = first.longitude
            let totalRent = stations.reduce(0) { $0 + $1.available_rent_bikes }
            let totalReturn = stations.reduce(0) { $0 + $1.available_return_bikes }
            return YouBikeCluster(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                count: stations.count,
                availableRentBikes: totalRent,
                availableReturnBikes: totalReturn,
                updateTime: first.updateTime,
                infoTime: first.infoTime,
                srcUpdateTime: first.srcUpdateTime,
                name: first.snaen
            )
        }
        // Only show individuals if each cluster is a single station
        if clusterList.count == youBikeStations.count {
            return clusterList
        } else {
            return clusterList
        }
    }
}
