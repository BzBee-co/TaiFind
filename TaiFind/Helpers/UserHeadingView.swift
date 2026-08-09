//
//  UserHeadingView.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/9.
//

import SwiftUI
import CoreLocation

/// A narrow pie-slice shape pointing "up" within its frame, apex at the
/// bottom-center. Rotate it to point in any direction.
private struct HeadingCone: Shape {
	// Full angular width of the cone, in degrees.
	var spread: Double = 50

	func path(in rect: CGRect) -> Path {
		let apex = CGPoint(x: rect.midX, y: rect.maxY)
		let radius = rect.height
		let startAngle = Angle(degrees: -90 - spread / 2)
		let endAngle = Angle(degrees: -90 + spread / 2)

		var path = Path()
		path.move(to: apex)
		path.addArc(center: apex, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
		path.closeSubpath()
		return path
	}
}

/// Replaces `UserAnnotation()` with a version that shows a facing-direction
/// cone without requiring the map to lock into heading-follow (rotating)
/// mode. `mapHeading` is the map's own current rotation (0 if north-up,
/// which is the common case here) — subtracting it keeps the cone pointing
/// the correct real-world direction even if the user manually twists the map.
struct UserHeadingView: View {
	var heading: CLLocationDirection?
	var mapHeading: Double

	var body: some View {
		ZStack {
			if let heading {
				HeadingCone()
					.fill(
						LinearGradient(
							colors: [.blue.opacity(0.35), .blue.opacity(0.0)],
							startPoint: .bottom,
							endPoint: .top
						)
					)
					.frame(width: 60, height: 60)
					.rotationEffect(.degrees(heading - mapHeading))
					.offset(y: -22) // apex sits on the dot below
			}
			Circle()
				.fill(.blue)
				.frame(width: 16, height: 16)
				.overlay(Circle().stroke(.white, lineWidth: 2.5))
				.shadow(color: .black.opacity(0.25), radius: 2)
		}
		// No heading data (e.g. Simulator, or a device with no compass) — still
		// show a plain dot, matching the old UserAnnotation()'s baseline behavior,
		// just without the cone rather than showing nothing at all.
		.accessibilityLabel("Your location")
	}
}

#Preview {
	VStack(spacing: 40) {
		UserHeadingView(heading: 45, mapHeading: 0)
		UserHeadingView(heading: nil, mapHeading: 0)
	}
	.padding()
	.background(Color(.systemGray5))
}
