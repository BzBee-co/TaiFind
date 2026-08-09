import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
	private let locationManager = CLLocationManager()
	
	@Published var region = MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654), // Default to Taipei city center
		span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
	)
	@Published var userLocation: CLLocationCoordinate2D?
	// Lets the UI distinguish "still waiting on a location fix" from "the user
	// said no" — previously nothing tracked this, so the location button just
	// silently did nothing if permission was denied (roadmap item #11).
	@Published var authorizationStatus: CLAuthorizationStatus
	private var lastUpdatedLocation: CLLocation?
	
	override init() {
		authorizationStatus = locationManager.authorizationStatus
		super.init()
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.last else { return }
		
		// Convert CLLocationCoordinate2D to CLLocation for distance calculation
		let newLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
		
		// Check if the location has changed significantly (e.g., 100 meters)
		if let lastLocation = lastUpdatedLocation {
			let distance = lastLocation.distance(from: newLocation) // Calculate the distance from the last location
			if distance > 100 { // Only update if moved more than 100 meters
				DispatchQueue.main.async {
					self.userLocation = location.coordinate
					self.region = MKCoordinateRegion(
						center: location.coordinate,
						span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
					)
					self.lastUpdatedLocation = newLocation // Update the last known location
				}
			}
		} else {
			// Set the initial location when lastUpdatedLocation is nil
			DispatchQueue.main.async {
				self.userLocation = location.coordinate
				self.region = MKCoordinateRegion(
					center: location.coordinate,
					span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
				)
				self.lastUpdatedLocation = newLocation
			}
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		DispatchQueue.main.async {
			self.authorizationStatus = status
		}
		if status == .authorizedWhenInUse || status == .authorizedAlways {
			locationManager.startUpdatingLocation()
		}
	}

	// Exposed so the location button can re-prompt in the (rare, post-launch)
	// case where authorization is still .notDetermined — init() already
	// requests it once, but this covers the edge case explicitly rather than
	// silently no-oping.
	func requestLocationPermission() {
		locationManager.requestWhenInUseAuthorization()
	}
}
