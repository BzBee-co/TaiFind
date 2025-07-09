import SwiftUI

struct InfoView: View {
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		NavigationStack {
			List {
				Section {
					
					Text("The AQI (Air Quality Index) is a way to measure the quality of the air you breathe, like a score based on the amounts of various pollutants in the air (typically those listed below). The values shown in this app are given by Taiwan's Ministry of Environment and run on a scale from 0 to 500, with 0 being considered clean air and 500 being hazardous.*")
					
					VStack(alignment: .leading, spacing: 12) {
						Text("Air Quality Indicators")
							.font(.title3)
							.fontWeight(.bold)
						
						ScrollView(.horizontal, showsIndicators: false) {
							HStack(spacing: 16) {
								ForEach(MeasurementType.allCases, id: \.self) { type in
									VStack(alignment: .leading, spacing: 4) {
										
										Text(type.fullName)
											.font(.headline)
											.fontWeight(.bold)
										
										let tierDescriptions = [
											"Clean",
											"Moderate",
											"Unhealthy for Sensitive Groups",
											"Unhealthy",
											"Very Unhealthy",
											"Hazardous"
										]
										
										ForEach(Array(type.thresholds.enumerated()), id: \.offset) { index, value in
											HStack(alignment: .top) {
												Circle()
													.fill(type.color(for: value))
													.frame(width: 10, height: 10)
												
												Text(
													formatted(value, for: type)
														.replacingOccurrences(of: "(", with: "")
														.replacingOccurrences(of: ")", with: "")
												)
												.font(.caption)
												Text(tierDescriptions[index])
													.font(.caption2)
													.foregroundColor(.secondary)
												
											}
										}
									}
									
									.padding()
									.frame(maxWidth: .infinity * 0.8)
									.frame(alignment: .leading)
									.background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
									.shadow(radius: 1)
								}
							}
							.padding(8)
						}
						.padding(.horizontal, -20)
					}

					
					ForEach(pollutants.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
						VStack(alignment: .leading) {
							Text(key)
								.font(.headline)
							Text(value[0])
							Text(value[1])
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
					
					
					Link(destination: URL(string: "https://airtw.moenv.gov.tw/ENG/Information/Standard/AirQualityIndicator.aspx")!, label: {
						HStack {
							Text("Learn more on Taiwan MoE's website")
							Image(systemName: "arrow.up.forward")
						}
					})
					.font(.subheadline)
					
					
				} header: {
					Text("Air Quality in Taiwan")
						.font(.title2)
						.fontWeight(.bold)
				}
				
				Section {
					Text("See the number of available bikes and open parking docks at each YouBike 2.0 station in Taipei City.*")
				} header: {
					Text("YouBike")
						.font(.title2)
						.fontWeight(.bold)
				}
				
				Section {
					VStack(alignment: .leading) {
						Text("Finding a public trash can in Taipei City can be challenging. This app displays their location so you can easily find those closest to you.*")
							.padding(.bottom, 4)
						Text("Disposing of domestic waste in these trash cans is not allowed and doing so may result in fines.")
							.font(.caption)
					}
				} header: {
					Text("Public trash cans")
						.font(.title2)
						.fontWeight(.bold)
				}
				
				Section {
					Text("This app uses datasets provided by the Taiwan Government Open Data Platform and by the Taipei City Government Open Data Platform, licensed under: Open Government Data License v1.0.")
					
					Link(destination: URL(string: "https://data.moenv.gov.tw/")!) {
						HStack {
							Text("Taiwan Government Open Data")
							Image(systemName: "arrow.up.forward")
						}
						.font(.subheadline)
					}
					
					Link(destination: URL(string: "https://data.taipei")!) {
						HStack {
							Text("Open Taipei")
							Image(systemName: "arrow.up.forward")
						}
						.font(.subheadline)
					}
					
					VStack(alignment: .leading) {
						Text("* Disclaimer")
							.font(.title3)
							.fontWeight(.bold)
							.padding(.top, 8)
						Text("While we strive to keep all information accurate and up-to-date, this app makes no guarantees about the accuracy, completeness, or reliability of the data provided. The original data is provided by third parties (including the Taiwan government) and may contain errors or become outdated. Use of this data is at your own risk.")
							.padding(.bottom, 8)
					}
					
					
					
					
				} header: {
					Text("Data Sources")
						.font(.title2)
						.fontWeight(.bold)
				}
				
				Section {
					Text("Contact us at contact@bzbee.co")
				} header: {
					Text("Contact")
						.font(.title2)
						.fontWeight(.bold)
				}
				
			}
			.fontDesign(.rounded)
			.navigationTitle("Information")
			.navigationBarTitleDisplayMode(.inline)
			
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark.circle")
					}
				}
			}
		}
	}
	
	
	
	
	private let pollutants: [String: [String]] = [
		"Carbon monoxide (CO)": ["A colorless, odorless gas from incomplete burning of fossil fuels. It reduces oxygen flow in the blood, causing dizziness, headaches, and potentially death.", "Carbon Monoxide is measured in parts per million (ppm), which means one CO molecule per million air molecules."],
		"Nitrogen dioxide (NO₂)": ["A reddish-brown gas from burning fossil fuels. It irritates the respiratory system and contributes to ozone and acid rain formation.", "Nitrogen dioxide is measured in parts per billion (ppb), which means one NO₂ molecule per billion air molecules."],
		"Ozone (O₃)": ["A gas formed by reactions of pollutants (like nitrogen oxides and VOCs) in sunlight. In the lower atmosphere, it's a harmful pollutant that irritates the respiratory system and damages vegetation.", "Ozone is measured in parts per billion (ppb)."],
		"Particulate matter (PM)": ["Tiny particles of solid or liquid matter suspended in the air. This includes coarser particles (PM₁₀ are 10 micrometers or smaller) and fine particles (PM₂.₅ are 2.5 micrometers or smaller), both of which can penetrate deep into the lungs and cause health problems. Sources include vehicle exhaust, industrial emissions, and wildfires.", "Particulate matter is measured in micrograms per cubic meter (µg/m³), which means the weight of particles in a cubic meter of air."],
		"Sulfur dioxide (SO₂)": ["A colorless gas with a pungent odor, primarily from burning fossil fuels (coal and oil) or volcanic activity. It irritates the respiratory system and contributes to acid rain.", "Sulfure Dioxide is measured in parts per billion (ppb)."]
	]
	

	
	private func formatted(_ value: Double, for type: MeasurementType) -> String {
		switch type {
		case .pm10, .no2:
			return String(format: "%.0f %@", value, type.unit)
		case .aqi:
			return String(format: "%.0f", value)
		default:
			return String(format: "%.1f %@", value, type.unit)
		}
	}
	
}

#Preview {
	InfoView()
}
