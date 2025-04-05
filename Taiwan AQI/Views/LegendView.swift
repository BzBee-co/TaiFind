//
//  LegendView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/5.
//

import SwiftUI

struct LegendView: View {
	let type: MeasurementType

	var colors: [Color] {
		[.blue, .green, .yellow, .orange, .red, .crimson]
	}

	var values: [String] {
		switch type {
//		case .none: return [25, 50, 75, 100, 150, 200].map { "\($0)" }
		case .aqi: return [25, 50, 75, 100, 150, 200].map { "\($0)" }
		case .so2: return [0.4, 0.8, 1.5, 2.5, 3.6, 5.0].map { String(format: "%.1f", $0) }
		case .co: return [0.2, 0.4, 0.6, 0.8, 1.0, 1.2].map { String(format: "%.1f", $0) }
		case .o3: return [20, 35, 50, 70, 85, 100].map { "\($0)" }
		case .pm10: return [20, 40, 60, 80, 100, 120].map { "\($0)" }
		case .pm2_5: return [10, 20, 30, 40, 50, 60].map { "\($0)" }
		case .no2: return [1, 2.5, 4, 6, 8, 10].map { String(format: "%.1f", $0) }
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(type == .aqi ? type.rawValue : "\(type.rawValue) (\(type.unit))")
				.font(.caption)
				.fontWeight(.semibold)
				.foregroundStyle(.white)

			ZStack {
				// Colored blocks
				HStack(spacing: 0) {
					ForEach(colors, id: \.self) { color in
						Rectangle()
							.fill(color)
							.frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
					}
				}
				.clipShape(RoundedRectangle(cornerRadius: 10))
				.frame(height: 20)

				// Threshold labels
				HStack {
					ForEach(values.indices, id: \.self) { index in
						Text(values[index])
							.font(.caption2)
							.foregroundStyle(.white)
							.frame(maxWidth: .infinity, alignment: .bottomTrailing)
							.padding(.trailing, index == values.count - 1 ? 5 : 0)
					}
				}
			}
		}
		.padding(6)
		.background(Color.black.opacity(0.6))
		.cornerRadius(8)
	}
}

#Preview {
	LegendView(type: .co)
}
