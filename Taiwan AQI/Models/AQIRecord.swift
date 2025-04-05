import Foundation
import CoreLocation

struct AQIRecord: Identifiable {
	let id = UUID()
	let siteName: String
	let county: String
	let latitude: Double
	let longitude: Double
	let aqi: Int
	let pollutant: String?
	let status: String
	let so2: Double?
	let co: Double?
	let o3: Double?
	let pm10: Double?
	let pm2_5: Double?
	let no2: Double?
	let publishtime: String
	
	var coordinate: CLLocationCoordinate2D {
		CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
	}
}
