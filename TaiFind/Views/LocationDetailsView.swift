//
//  LocationDetailsView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/4/9.
//

import SwiftUI

struct LocationDetailsView: View {
	@EnvironmentObject var viewModel: AQIViewModel
	@Environment(\.dismiss) private var dismiss
	let record: AQIRecord // Receive the selected AQIRecord

	let columns: [GridItem] = [
		GridItem(.flexible(), spacing: 10),
		GridItem(.flexible(), spacing: 10)
	]

	var formattedDateTime: String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
		if let date = dateFormatter.date(from: record.publishtime) {
			let outputFormatter = DateFormatter()
			outputFormatter.dateFormat = "dd MMM HH:mm a"
			return outputFormatter.string(from: date)
		} else {
			return record.publishtime
		}
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				if let pollutant = record.pollutant {
					if !pollutant.isEmpty {
						HStack {
							Text("main pollutant: \(pollutant)")
								.font(.caption)
								.fontWeight(.bold)
								.foregroundStyle(.secondary)
								.padding(.horizontal)
								.padding(.top, 4)

							Spacer()
						}
					}
				}
				GeometryReader { geometry in
					VStack(alignment: .leading) {
						VStack(alignment: .leading, spacing: 10) {
							Text(MeasurementType.aqi.localizedFullName)
								.font(.headline)
							HStack(alignment: .bottom) {
								Text(record.value(for: .aqi) ?? "-")
									.font(.title2)
									.fontWeight(.bold)
								Text(record.status)
									.font(.caption)
									.fontWeight(.bold)
									.offset(x: -4, y: -2)
							}
							.foregroundStyle(colorForValue(value: record.value(for: .aqi), type: .aqi))
						}
						.padding(.horizontal, 8)
						.padding(.vertical, 8)
						.frame(maxWidth: .infinity, alignment: .leading)
						.background(colorForValue(value: record.value(for: .aqi), type: .aqi).opacity(0.2))
						.clipShape(RoundedRectangle(cornerRadius: 8))

						LazyVGrid(columns: columns, spacing: 10) {
							
							ForEach(MeasurementType.allCases.filter { $0 != .aqi }, id: \.self) { type in
								let value = record.value(for: type)
								let color = colorForValue(value: value, type: type)

								VStack(alignment: .leading, spacing: 10) {
									Text(type.localizedFullName)
										.font(.headline)
									HStack(alignment: .bottom) {
										Text(value ?? "-")
											.font(.title2)
											.fontWeight(.bold)
										Text(type.unit.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))
											.font(.caption)
											.fontWeight(.bold)
											.offset(x: -4, y: -2)
									}
									.foregroundStyle(color)
								}
								.padding(.horizontal, 8)
								.padding(.vertical, 8)
								.frame(maxWidth: .infinity, alignment: .leading)
								.background(color.opacity(0.2))
								.clipShape(RoundedRectangle(cornerRadius: 8))
							}
						}
					}
					.padding()
				}
			}
			.toolbar {
				ToolbarItem(placement: .principal) {
					VStack(alignment: .leading, spacing: 2) {
						Text(record.siteName)
							.font(.headline)
							.fontWeight(.semibold)
							.lineLimit(1)
							.truncationMode(.tail)
						HStack(spacing: 4) {
							if !record.county.isEmpty {
								Text(record.county)
							}
							Text("(last updated: \(formattedDateTime))")
						}
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.tail)
					}
					.accessibilityElement(children: .combine)
					.accessibilityLabel("\(record.siteName), \(record.county.isEmpty ? "" : record.county + ", ")last updated \(formattedDateTime)")
				}
				
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						viewModel.toggleFavorite(type: .aqi, stationID: record.siteID, displayName: record.siteName)
					} label: {
						Image(systemName: viewModel.isFavorite(type: .aqi, stationID: record.siteID) ? "star.fill" : "star")
							.foregroundStyle(.yellow)
					}
					.accessibilityLabel(viewModel.isFavorite(type: .aqi, stationID: record.siteID) ? "Remove from favorites" : "Add to favorites")
				}

				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark")
					}
				}
			}
			.toolbarTitleDisplayMode(.inline)
		}
	}

	func colorForValue(value: String?, type: MeasurementType) -> Color {
		guard let valueString = value, let doubleValue = Double(valueString) else {
			return Color.gray.opacity(0.3)
		}

		let thresholds: [Double]

		switch type {
		case .aqi: thresholds = [50, 100, 150, 200, 300, 400]
		case .co: thresholds = [4.4, 9.4, 12.4, 15.4, 30.4, 40.4]
		case .no2: thresholds = [21, 100, 360, 649, 1249, 1649]
		case .o3: thresholds = [54, 70, 134, 204, 404, 504]
		case .pm2_5: thresholds = [12.4, 30.4, 50.4, 125.4, 225.4, 325.4]
		case .pm10: thresholds = [30, 75, 190, 354, 424, 504]
		case .so2: thresholds = [8.0, 65.0, 160.0, 304.0, 604.0, 804.0]
		}
		return color(for: doubleValue, thresholds: thresholds)
	}

	private func color(for value: Double, thresholds: [Double]) -> Color {
		if value <= thresholds[0] { return .green }
		else if value <= thresholds[1] { return .yellow }
		else if value <= thresholds[2] { return .orange }
		else if value <= thresholds[3] { return .red }
		else if value <= thresholds[4] { return .purple }
		else if value <= thresholds[5] { return .crimson }
		else { return .clear }
	}

}

extension AQIRecord {
	func value(for type: MeasurementType) -> String? {
		switch type {
		case .aqi: return "\(aqi)"
		case .co: return co.map { String(format: "%.1f", $0) }
		case .no2: return no2.map { String(format: "%.1f", $0) }
		case .o3: return o3.map { String(format: "%.1f", $0) }
		case .pm2_5: return pm2_5.map { String(format: "%.1f", $0) }
		case .pm10: return pm10.map { String(format: "%.1f", $0) }
		case .so2: return so2.map { String(format: "%.1f", $0) }
		}
	}
}

#Preview {
	let sampleRecord = AQIRecord(
		siteName: "Sample Station",
		county: "Sample County",
		latitude: 25.0,
		longitude: 121.5,
		aqi: 45,
		pollutant: nil,
		status: "Good",
		so2: 2.5,
		co: 0.3,
		o3: 60.0,
		pm10: 25.0,
		pm2_5: 8.0,
		no2: 15.0,
		publishtime: "2025-04-10 11:00",
		siteID: "201"
	)
	return LocationDetailsView(record: sampleRecord)
		.environmentObject(AQIViewModel())
}
