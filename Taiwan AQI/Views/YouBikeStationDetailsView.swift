//
//  YouBikeStationDetailsView.swift
//  Taiwan AQI
//
//  Created by Antoine Moreau on 2025/6/30.
//

import SwiftUI

struct YouBikeStationDetailsView: View {
	@Environment(\.dismiss) private var dismiss
    let station: YouBikeStation
    
    var body: some View {
		let originalChineseName = station.sna
		let fixedChineseName = originalChineseName
			.replacingOccurrences(of: "YouBike2.0_", with: "")
		let originalEnglishName = station.snaen
		let fixedEnglishName = originalEnglishName
			.replacingOccurrences(of: "YouBike2.0_", with: "")
			.replacingOccurrences(of: "，", with: ",")
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
				Text(fixedEnglishName)
                    .font(.title3)
                    .fontWeight(.bold)
				Text(fixedChineseName)
					.font(.title3)
					.fontWeight(.bold)
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Image(systemName: "bicycle")
							.foregroundStyle(.green)
							.frame(width: 40)
						Text("Available bikes: \(station.available_rent_bikes)")
							.font(.headline)
					}
					HStack {
						Image(systemName: "arrowshape.turn.up.left")
							.foregroundStyle(.blue)
							.frame(width: 40)
						Text("Return slots: \(station.available_return_bikes)")
							.font(.headline)
					}
				}
				.padding(.trailing, 20)
				.padding(.vertical)
				.background(.secondary.opacity(0.1))
				.clipShape(RoundedRectangle(cornerRadius: 8))
				
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Last updated: \(station.updateTime)")
                        .font(.caption)

                    Text("The information displayed is based on the latest available data from the Taipei City Government Open Data platform. While we strive for accuracy, discrepancies may exist between the available data and real-world conditions. We are not responsible for any inaccuracies or outdated information.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("YouBike Station Details")
            .navigationBarTitleDisplayMode(.inline)
			
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark.circle")
					}
				}
				
			}
        }
    }
}

#Preview {
    YouBikeStationDetailsView(station: YouBikeStation(
        sno: "500101003",
		sna: "YouBike2.0_國北教大實小東側門",
        snaen: "YouBike2.0_NTUE Experiment Elementary School (East)",
        longitude: 121.54124,
        latitude: 25.024290000000001,
        available_rent_bikes: 4,
        available_return_bikes: 24,
        updateTime: "2025-06-30 12:58:52",
        infoTime: "2025-06-30 12:50:03",
        srcUpdateTime: "2025-06-30 12:58:29"
    ))
}
