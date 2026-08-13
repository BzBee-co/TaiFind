//
//  FavoritesListView.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/10.
//

import SwiftUI

struct FavoritesListView: View {
	@EnvironmentObject var viewModel: AQIViewModel
	@Environment(\.dismiss) private var dismiss
	var onSelect: (FavoriteStation) -> Void

	var body: some View {
		NavigationStack {
			Group {
				if viewModel.favorites.isEmpty {
					ContentUnavailableView(
						"No Favorites Yet",
						systemImage: "star.fill",
						description: Text("Tap the star on any air quality or YouBike station to add it here. Favorites can be added to your Home Screen as Widgets, so you can see the latest air quality and YouBike information without having to open the app.")
					)
				} else {
					List {
						Section {
							ForEach(viewModel.favorites) { favorite in
								Button {
									dismiss()
									onSelect(favorite)
								} label: {
									FavoriteRow(favorite: favorite)
								}
								.buttonStyle(.plain)
							}
							.onDelete(perform: viewModel.removeFavorites)
							.onMove(perform: viewModel.moveFavorites)
						} footer: {
							Text("When viewing a station's details, tap the star to add it to your favorites. Tap again to remove it, or swipe left below.")
						}
					}
				}
			}
			.navigationTitle("Favorites")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					if !viewModel.favorites.isEmpty {
						EditButton()
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark")
					}
				}
			}
		}
	}
}

private struct FavoriteRow: View {
	@EnvironmentObject var viewModel: AQIViewModel
	let favorite: FavoriteStation

	var body: some View {
		HStack(spacing: 12) {
			icon
			VStack(alignment: .leading, spacing: 2) {
				Text(favorite.displayName)
					.font(.headline)
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(subtitle)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
		}
		.padding(.vertical, 4)
		.accessibilityElement(children: .combine)
	}

	@ViewBuilder
	private var icon: some View {
		switch favorite.type {
		case .aqi:
			if let record = matchingAQIRecord {
				let color = MeasurementType.aqi.color(for: Double(record.aqi))
				Text("\(record.aqi)")
					.font(.caption)
					.fontWeight(.heavy)
					.fontDesign(.rounded)
					.foregroundStyle(.white)
					.frame(width: 36, height: 36)
					.background(color)
					.clipShape(Circle())
			} else {
				Image(systemName: "aqi.medium")
					.frame(width: 36, height: 36)
					.background(Color(.secondarySystemBackground))
					.clipShape(Circle())
			}
		case .youBikeTaipei, .youBikeTaichung:
			Image(systemName: "bicycle")
				.foregroundStyle(.white)
				.frame(width: 36, height: 36)
				.background(.indigo.gradient)
				.clipShape(Circle())
		}
	}

	private var matchingAQIRecord: AQIRecord? {
		viewModel.aqiRecords.first(where: { $0.siteID == favorite.stationID })
	}

	private var matchingYouBikeStation: YouBikeStation? {
		switch favorite.type {
		case .youBikeTaipei:
			return viewModel.youBikeStations.first(where: { $0.sno == favorite.stationID })
		case .youBikeTaichung:
			guard let s = viewModel.taichungYouBikeStations.first(where: { $0.sno == favorite.stationID }) else { return nil }
			return YouBikeStation(
				sno: s.sno,
				sna: s.sna,
				snaen: s.snaen,
				longitude: s.longitude,
				latitude: s.latitude,
				available_rent_bikes: s.available_rent_bikes,
				available_return_bikes: s.available_return_bikes,
				updateTime: s.updateTime,
				infoTime: s.infoTime,
				srcUpdateTime: s.srcUpdateTime
			)
		case .aqi:
			return nil
		}
	}

	private var subtitle: String {
		switch favorite.type {
		case .aqi:
			guard let record = matchingAQIRecord else { return "No current data — open the layer to refresh" }
			return "AQI \(record.aqi) · \(record.status)"
		case .youBikeTaipei, .youBikeTaichung:
			guard let station = matchingYouBikeStation else { return "No current data — open the layer to refresh" }
			return "\(station.available_rent_bikes) bikes · \(station.available_return_bikes) docks open"
		}
	}
}

#Preview {
	FavoritesListView { _ in }
		.environmentObject(AQIViewModel())
}
