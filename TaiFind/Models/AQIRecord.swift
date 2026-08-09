import Foundation
import CoreLocation

struct AQIRecord: Identifiable, Equatable, Codable {
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
	let siteID: String

	// Was `let id = UUID()`, regenerated on every fetch — meaning SwiftUI saw a
	// brand-new identity for every station on every refresh, even when nothing
	// about that station changed. That broke animation continuity on pin
	// updates, forced unnecessary re-renders, and would've made a widget
	// timeline (which needs stable identity across snapshots) unworkable.
	// siteID comes from the upstream API and is stable per monitoring station,
	// so it's used directly as Identifiable's id instead.
	var id: String { siteID }

	var coordinate: CLLocationCoordinate2D {
		CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
	}
}
