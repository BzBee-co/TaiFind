//
//  LegendView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/5.
//

import SwiftUI

struct LegendView: View {
	@Binding var displayMode: DisplayMode
	@Binding var selectedMeasurement: MeasurementType
	
	var colors: [Color] {
		switch selectedMeasurement {
			//			case .none: return []
		case .aqi, .so2, .co, .o3, .pm10, .pm2_5, .no2:
			return [.green, .yellow, .orange, .red, .purple, .crimson]
		}
	}
	
	var values: [String] {
		switch selectedMeasurement {
			//			case .none: return []
		case .aqi: return [50, 100, 150, 200, 300, 400].map { "\($0)" }
		case .so2: return [8.0, 65.0, 160.0, 304.0, 604.0, 804.0].map { String(format: "%.1f", $0) }
		case .co: return [4.4, 9.4, 12.4, 15.4, 30.4, 40.4].map { String(format: "%.1f", $0) }
		case .o3: return [54, 70, 134, 204, 404, 504].map { "\($0)" }
		case .pm10: return [30, 75, 190, 354, 424, 504].map { "\($0)" }
		case .pm2_5: return [12.4, 30.4, 50.4, 125.4, 225.4, 325.4].map { "\($0)" }
		case .no2: return [21, 100, 360, 649, 1249, 1649].map { "\($0)" }
		}
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(alignment: .bottom) {
				
				Text("\(selectedMeasurement.rawValue) \(selectedMeasurement.unit)")
					.font(.subheadline)
					.fontWeight(.semibold)
				Spacer()
				Picker("Display Mode", selection: $displayMode) {
					ForEach(DisplayMode.allCases, id: \.self) { mode in
						Text(mode.rawValue)
							.tag(mode)
					}
				}
				.pickerStyle(.segmented)
				.frame(maxWidth: 150)
			}
			.padding(.bottom, 2)
			
			
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
		.background(Color(.secondarySystemBackground).opacity(0.6))
		.cornerRadius(8)
	}
}

#Preview {
	@Previewable @State var previewDisplayMode: DisplayMode = .heatmap
	@Previewable @State var previewSelectedMeasurement: MeasurementType = .aqi
	return LegendView(displayMode: $previewDisplayMode, selectedMeasurement: $previewSelectedMeasurement)
}
