import Foundation
import CoreLocation

struct AQIRecord: Identifiable {
    let id = UUID()
    let siteName: String
    let latitude: Double
    let longitude: Double
    let aqi: Int
    let status: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
