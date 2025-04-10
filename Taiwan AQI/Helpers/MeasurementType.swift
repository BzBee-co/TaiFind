//
//  MeasurementType.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/5.
//

import SwiftUI
enum MeasurementType: String, CaseIterable, Identifiable {
//	case none = "no layer"
	case aqi = "AQI"
	case co = "CO"
	case no2 = "NO₂"
	case o3 = "O₃"
	case pm2_5 = "PM₂.₅"
	case pm10 = "PM₁₀"
	case so2 = "SO₂"
	
	var id: String { rawValue }
	
	var fullName: String {
		switch self {
//		case .none: return "Just the map"
		case .aqi: return "Air Quality Index"
		case .co: return "Carbon Monoxide"
		case .no2: return "Nitrogen Dioxide"
		case .o3: return "Ozone"
		case .pm2_5: return "PM 2.5 µm"
		case .pm10: return "PM 10 µm"
		case .so2: return "Sulfur Dioxide"
		}
	}
	
	var unit: String {
		switch self {
//		case .none: return ""
		case .aqi: return ""
		case .so2, .co: return "(ppm)"
		case .o3, .no2: return "(ppb)"
		case .pm10, .pm2_5: return "(µg/m³)"
		}
	}
}
