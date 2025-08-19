//
//  MeasurementType.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/5.
//

import SwiftUI
enum MeasurementType: String, CaseIterable, Identifiable {
	case aqi = "AQI"
	case co = "CO"
	case no2 = "NO₂"
	case o3 = "O₃"
	case pm2_5 = "PM₂.₅"
	case pm10 = "PM₁₀"
	case so2 = "SO₂"
	
	var id: String { rawValue }
	
	var localizedShortName: LocalizedStringKey {
		switch self {
		case .aqi: return "AQI"
		case .co: return "CO"
		case .no2: return "NO₂"
		case .o3: return "O₃"
		case .pm2_5: return "PM₂.₅"
		case .pm10: return "PM₁₀"
		case .so2: return "SO₂"
		}
	}
	
	var localizedFullName: LocalizedStringKey {
		switch self {
		case .aqi: return "AQI"
		case .co: return "Carbon Monoxide"
		case .no2: return "Nitrogen Dioxide"
		case .o3: return "Ozone"
		case .pm2_5: return "PM₂.₅"
		case .pm10: return "PM₁₀"
		case .so2: return "Sulfur Dioxide"
		}
	}

	var localizedFullNameWithUnit: LocalizedStringKey {
		switch self {
		case .aqi: return "AQI"
		case .co: return "Carbon Monoxide (ppm)"
		case .no2: return "Nitrogen Dioxide (ppb)"
		case .o3: return "Ozone (ppb)"
		case .pm2_5: return "PM₂.₅ (µg/m³)"
		case .pm10: return "PM₁₀ (µg/m³)"
		case .so2: return "Sulfur Dioxide (ppm)"
		}
	}
	
	var unit: String {
		switch self {
		case .aqi: return ""
		case .so2, .co: return "(ppm)"
		case .o3, .no2: return "(ppb)"
		case .pm10, .pm2_5: return "(µg/m³)"
		}
	}
	
	var thresholds: [Double] {
		switch self {
		case .aqi: return [50, 100, 150, 200, 300, 400]
		case .so2: return [8, 65, 160, 304, 604, 804]
		case .co: return [4.4, 9.4, 12.4, 15.4, 30.4, 40.4]
		case .o3: return [54, 70, 134, 204, 404, 504]
		case .pm10: return [30, 75, 190, 354, 424, 504]
		case .pm2_5: return [12.4, 30.4, 50.4, 125.4, 225.4, 325.4]
		case .no2: return [21, 100, 360, 649, 1249, 1649]
		}
	}

	func color(for value: Double) -> Color {
		let t = thresholds
		if value <= t[0] { return .green }
		else if value <= t[1] { return .yellow }
		else if value <= t[2] { return .orange }
		else if value <= t[3] { return .red }
		else if value <= t[4] { return .purple }
		else if value <= t[5] { return .crimson }
		else { return .gray }
	}
}
