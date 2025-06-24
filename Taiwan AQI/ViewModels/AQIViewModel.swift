import Foundation
import CoreLocation
import MapKit
import Combine

class AQIViewModel: ObservableObject {
    @Published var aqiRecords: [AQIRecord] = []
    @Published var trashcanRecords: [TrashcanRecord] = []
    @Published var showTrashcans: Bool = false
    @Published var trashcanLoading: Bool = false
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
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
        APIService.fetchAllTrashcans { [weak self] records in
            DispatchQueue.main.async {
                self?.trashcanRecords = records
                self?.trashcanLoading = false
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
        let latGrid = region.span.latitudeDelta / 5
        let lonGrid = region.span.longitudeDelta / 5
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
