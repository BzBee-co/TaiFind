//
//  MeasurementType.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/5.
//

import SwiftUI

enum MeasurementType: String, CaseIterable, Identifiable {
//	case none = "None"
	case aqi = "AQI"
	case so2 = "SO₂"
	case co = "CO"
	case o3 = "O₃"
	case pm10 = "PM₁₀"
	case pm2_5 = "PM₂.₅"
	case no2 = "NO₂"

	var id: String { rawValue }

	var unit: String {
		switch self {
		case .aqi: return ""
		case .so2, .co: return "ppm"
		case .o3, .no2: return "ppb"
		case .pm10, .pm2_5: return "µg/m³"
		}
	}
}
