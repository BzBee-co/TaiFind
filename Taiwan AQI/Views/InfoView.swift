import SwiftUI

struct InfoView: View {
	var body: some View {
		List {
			Section {
				
				VStack(alignment: .leading, spacing: 15) {
					Text("The Air Quality Index (AQI) developed by Taiwan's Ministry of Environment runs on a scale from 0 to 500, with 0 being considered clean air and 500 being hazardous.")
					Text("The AQI reflects the highest concentration of the major pollutants. It provides a single number and a corresponding category to communicate the level of air pollution and its potential health effects.")
					Link(destination: URL(string: "https://airtw.moenv.gov.tw/ENG/Information/Standard/AirQualityIndicator.aspx")!, label: {
						HStack {
							Text("Learn more on Taiwan MoE's website")
							Image(systemName: "arrow.up.forward")
						}
					})
						.font(.subheadline)
				}

				VStack(alignment: .leading) {
					Text("AQI levels:")
						.font(.headline)
						.padding(.bottom, 5)
					ForEach(sortedAQILevels, id: \.0) { range, description in
						HStack {
							Circle()
								.fill(colorForAQIRange(range: range))
								.frame(width: 12, height: 12)
							Text(range)
								.fontWeight(.semibold)
							Spacer()
							Text(description)
								.foregroundStyle(.secondary)
						}
						.padding(.vertical, 2)
					}
				}
				.padding(.top, 8)
				
			} header: {
				Text("Understanding Taiwan's AQI")
					.font(.headline)
					.fontWeight(.bold)
			}

			ForEach(sortedPollutants, id: \.0) { name, description in
				Section {
					Text(description)
				} header: {
					Text(name)
						.font(.headline)
						.fontWeight(.bold)
				}
			}
			
			Section {
				VStack(alignment: .leading) {
					Text("Disclaimer")
						.fontWeight(.semibold)
					Text("While we strive to keep all information accurate and up-to-date, this app makes no guarantees about the accuracy, completeness, or reliability of the data provided. The original data is provided by third parties (including the Taiwan government) and may contain errors or become outdated. Use of this data is at your own risk.")

					Text("Data Sources")
						.fontWeight(.semibold)
						.padding(.top, 8)
					Text("This app uses datasets provided by the Taiwan Government Open Data Platform at https://data.moenv.gov.tw/")
					Text("Licensed under: Open Government Data License v1.0")
						.font(.caption)
				}
				
			}

		}
		.fontDesign(.rounded)
	}

	private let AQIlevels: [String: String] = [
		"0-50": "Clean",
		"51-100": "Moderate",
		"101-150": "Unhealthy for Sensitive Groups",
		"151-200": "Unhealthy",
		"201-300": "Very Unhealthy",
		"301-500": "Hazardous"
	]

	private var sortedAQILevels: [(String, String)] {
		AQIlevels.sorted {
			guard let val1 = $0.key.components(separatedBy: "-").first.flatMap(Int.init),
				  let val2 = $1.key.components(separatedBy: "-").first.flatMap(Int.init) else {
				return false
			}
			return val1 < val2
		}
	}

	private let pollutants: [String: String] = [
		"Carbon monoxide (CO)": "A colorless, odorless gas from incomplete burning of fossil fuels. It reduces oxygen flow in the blood, causing dizziness, headaches, and potentially death.",
		"Nitrogen dioxide (NO₂)": "A reddish-brown gas from burning fossil fuels. It irritates the respiratory system and contributes to ozone and acid rain formation.",
		"Ozone (O₃)": "A gas formed by reactions of pollutants (like nitrogen oxides and VOCs) in sunlight. In the lower atmosphere, it's a harmful pollutant that irritates the respiratory system and damages vegetation.",
		"Particulate matter (PM)": "Tiny particles of solid or liquid matter suspended in the air. This includes coarser particles (PM₁₀ are 10 micrometers or smaller) and fine particles (PM₂.₅ are 2.5 micrometers or smaller), both of which can penetrate deep into the lungs and cause health problems. Sources include vehicle exhaust, industrial emissions, and wildfires.",
		"Sulfur dioxide (SO₂)": "A colorless gas with a pungent odor, primarily from burning fossil fuels (coal and oil) or volcanic activity. It irritates the respiratory system and contributes to acid rain."
	]

	private var sortedPollutants: [(String, String)] {
		pollutants.sorted { $0.key < $1.key }
	}

	func colorForAQIRange(range: String) -> Color {
		let values = range.components(separatedBy: "-").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
		guard let lowerBound = values.first else { return .gray }

		switch lowerBound {
		case 0...50:
			return .green
		case 51...100:
			return .yellow
		case 101...150:
			return .orange
		case 151...200:
			return .red
		case 201...300:
			return .purple
		case 301...500:
			return .crimson
		default:
			return .gray
		}
	}
}

#Preview {
	InfoView()
}
