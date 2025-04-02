import Foundation
import CoreLocation
import MapKit

class AQIViewModel: ObservableObject {
    @Published var aqiRecords: [AQIRecord] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    private let locationManager = LocationManager()
    
    init() {
        fetchAQIData()
        locationManager.$userLocation
            .compactMap { $0 }
            .assign(to: &$region.center)
    }
    
    func fetchAQIData() {
        APIService.fetchAQI { [weak self] records in
            DispatchQueue.main.async {
                self?.aqiRecords = records
            }
        }
    }
}
