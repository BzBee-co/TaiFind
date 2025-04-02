import Foundation
import CoreLocation
import MapKit
import Combine

class AQIViewModel: ObservableObject {
    @Published var aqiRecords: [AQIRecord] = []
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
}
