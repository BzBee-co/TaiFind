import Foundation
import Combine
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
	private let locationManager = CLLocationManager()

	@Published var region = MKCoordinateRegion(
		center: CLLocationCoordinate2D(
			latitude: 25.0330,
			longitude: 121.5654
		),
		span: MKCoordinateSpan(
			latitudeDelta: 0.05,
			longitudeDelta: 0.05
		)
	)

	@Published var userLocation: CLLocationCoordinate2D?
	@Published var heading: CLLocationDirection = 0
	@Published var authorizationStatus: CLAuthorizationStatus

	private var lastUpdatedLocation: CLLocation?

	override init() {
		authorizationStatus = locationManager.authorizationStatus
		super.init()

		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.requestWhenInUseAuthorization()
	}

	func locationManager(
		_ manager: CLLocationManager,
		didUpdateLocations locations: [CLLocation]
	) {
		guard let location = locations.last else { return }

		let newLocation = CLLocation(
			latitude: location.coordinate.latitude,
			longitude: location.coordinate.longitude
		)

		if let lastLocation = lastUpdatedLocation {
			let distance = lastLocation.distance(from: newLocation)

			if distance > 100 {
				DispatchQueue.main.async {
					self.userLocation = location.coordinate
					self.region = MKCoordinateRegion(
						center: location.coordinate,
						span: MKCoordinateSpan(
							latitudeDelta: 0.02,
							longitudeDelta: 0.02
						)
					)
					self.lastUpdatedLocation = newLocation
				}
			}
		} else {
			DispatchQueue.main.async {
				self.userLocation = location.coordinate
				self.region = MKCoordinateRegion(
					center: location.coordinate,
					span: MKCoordinateSpan(
						latitudeDelta: 0.02,
						longitudeDelta: 0.02
					)
				)
				self.lastUpdatedLocation = newLocation
			}
		}
	}

	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		let status = manager.authorizationStatus

		DispatchQueue.main.async {
			self.authorizationStatus = status
		}

		guard status == .authorizedWhenInUse || status == .authorizedAlways else {
			return
		}

		manager.startUpdatingLocation()

		if CLLocationManager.headingAvailable() {
			manager.headingFilter = 1
			manager.startUpdatingHeading()
		}
	}

	func locationManager(
		_ manager: CLLocationManager,
		didUpdateHeading newHeading: CLHeading
	) {
		let updatedHeading = newHeading.trueHeading >= 0
			? newHeading.trueHeading
			: newHeading.magneticHeading

		guard updatedHeading >= 0 else { return }

		DispatchQueue.main.async {
			self.heading = updatedHeading
		}
	}

	func requestLocationPermission() {
		locationManager.requestWhenInUseAuthorization()
	}
}
