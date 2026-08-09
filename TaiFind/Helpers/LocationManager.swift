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
	// Device compass heading (0° = true north), used to draw the facing-direction
	// cone on the map. Stays nil on devices/simulators with no compass — callers
	// should treat that as "just show a plain dot, no cone" rather than an error.
	@Published var heading: CLLocationDirection?
	private var lastUpdatedLocation: CLLocation?
	
	override init() {
		authorizationStatus = locationManager.authorizationStatus
		super.init()
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
		if CLLocationManager.headingAvailable() {
			locationManager.startUpdatingHeading()
		}
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

	func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
		// trueHeading is negative when invalid (no valid true-north reading yet,
		// e.g. right after launch) — fall back to magneticHeading in that case.
		DispatchQueue.main.async {
			self.heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
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
