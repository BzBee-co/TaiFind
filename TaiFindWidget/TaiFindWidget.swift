//
//  TaiFindWidget.swift
//  TaiFindWidget
//
//  Created by Antoine Moreau on 2026/8/10.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline entry

/// A favorite joined with its current live value, computed once when the
/// timeline entry is built. The widget process never fetches over the
/// network — it only reads what the main app already cached (see
/// TaiFind_widget_tracker.md's architecture notes).
struct FavoriteStatus: Identifiable {
	let favorite: FavoriteStation
	var id: String { favorite.id }

	// Populated for .aqi favorites only.
	let aqiValue: Int?
	let aqiStatus: String?

	// Populated for .youBikeTaipei / .youBikeTaichung favorites only.
	let bikesAvailable: Int?
	let docksAvailable: Int?

	var hasLiveData: Bool {
		aqiValue != nil || bikesAvailable != nil
	}

	var subtitle: String {
		if let aqiValue, let aqiStatus {
			return "AQI \(aqiValue) · \(aqiStatus)"
		}
		if let bikesAvailable, let docksAvailable {
			return "\(bikesAvailable) bikes · \(docksAvailable) docks"
		}
		return "No data yet"
	}

	var tintColor: Color {
		if let aqiValue {
			return MeasurementType.aqi.color(for: Double(aqiValue))
		}
		return .secondary
	}

	var iconName: String {
		favorite.type == .aqi ? "aqi.medium" : "bicycle"
	}
}

struct FavoritesEntry: TimelineEntry {
	let date: Date
	let favorites: [FavoriteStatus]
}

// MARK: - Timeline provider

struct FavoritesProvider: TimelineProvider {
	func placeholder(in context: Context) -> FavoritesEntry {
		FavoritesEntry(date: Date(), favorites: Self.placeholderFavorites)
	}

	func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
		// context.isPreview is true in the widget gallery — show placeholder
		// data there rather than whatever (possibly empty) real data exists.
		completion(context.isPreview ? FavoritesEntry(date: Date(), favorites: Self.placeholderFavorites) : loadEntry())
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
		let entry = loadEntry()
		// Data only changes as often as the main app's own fetches (AQI's soft
		// TTL is 15 min; YouBike/trashcans refresh on demand). Asking for 15
		// minutes lines up with that — WidgetKit may grant it or throttle
		// further depending on its system-wide refresh budget, which the app
		// can't control precisely.
		let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(15 * 60)
		completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
	}

	private func loadEntry() -> FavoritesEntry {
		let favorites = FavoritesStore.load()

		let aqiRecords = LocalCache.load([AQIRecord].self, forKey: CacheKeys.aqiRecords)?.value ?? []
		let taipeiStations = LocalCache.load([YouBikeStation].self, forKey: CacheKeys.youBikeTaipeiStations)?.value ?? []
		let taichungStations = LocalCache.load([TaichungYouBikeStation].self, forKey: CacheKeys.youBikeTaichungStations)?.value ?? []

		let statuses = favorites.map { favorite -> FavoriteStatus in
			switch favorite.type {
			case .aqi:
				if let record = aqiRecords.first(where: { $0.siteID == favorite.stationID }) {
					return FavoriteStatus(favorite: favorite, aqiValue: record.aqi, aqiStatus: record.status, bikesAvailable: nil, docksAvailable: nil)
				}
			case .youBikeTaipei:
				if let station = taipeiStations.first(where: { $0.sno == favorite.stationID }) {
					return FavoriteStatus(favorite: favorite, aqiValue: nil, aqiStatus: nil, bikesAvailable: station.available_rent_bikes, docksAvailable: station.available_return_bikes)
				}
			case .youBikeTaichung:
				if let station = taichungStations.first(where: { $0.sno == favorite.stationID }) {
					return FavoriteStatus(favorite: favorite, aqiValue: nil, aqiStatus: nil, bikesAvailable: station.available_rent_bikes, docksAvailable: station.available_return_bikes)
				}
			}
			// No live match yet — cache hasn't been populated for this layer, or
			// the station is temporarily missing from the feed. Still show the
			// favorite with its saved display name rather than dropping it.
			return FavoriteStatus(favorite: favorite, aqiValue: nil, aqiStatus: nil, bikesAvailable: nil, docksAvailable: nil)
		}

		return FavoritesEntry(date: Date(), favorites: statuses)
	}

	static let placeholderFavorites: [FavoriteStatus] = [
		FavoriteStatus(favorite: FavoriteStation(type: .aqi, stationID: "12", displayName: "Zhongshan"), aqiValue: 46, aqiStatus: "Good", bikesAvailable: nil, docksAvailable: nil),
		FavoriteStatus(favorite: FavoriteStation(type: .youBikeTaipei, stationID: "500101001", displayName: "NTU Main Gate"), aqiValue: nil, aqiStatus: nil, bikesAvailable: 6, docksAvailable: 10)
	]
}

// MARK: - Views

struct TaiFindWidgetEntryView: View {
	@Environment(\.widgetFamily) private var family
	var entry: FavoritesProvider.Entry

	var body: some View {
		if entry.favorites.isEmpty {
			emptyState
		} else {
			switch family {
			case .systemSmall:
				smallView
			case .systemMedium:
				mediumView
			default:
				largeView
			}
		}
	}

	private var emptyState: some View {
		VStack(spacing: 6) {
			Image(systemName: "star")
				.font(.title2)
				.foregroundStyle(.secondary)
			Text("No Favorites Yet")
				.font(.caption)
				.fontWeight(.semibold)
			Text("Star a station in TaiFind")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	// Small: just the first favorite. (A configurable "pick which one" version
	// is a natural follow-up via AppIntentTimelineProvider — see the tracker's
	// open questions — this v1 just always shows the first one added.)
	private var smallView: some View {
		Group {
			if let first = entry.favorites.first {
				Link(destination: first.favorite.deepLinkURL) {
					FavoriteTile(status: first)
				}
			} else {
				emptyState
			}
		}
	}

	private var mediumView: some View {
		HStack(spacing: 8) {
			ForEach(entry.favorites.prefix(3)) { status in
				Link(destination: status.favorite.deepLinkURL) {
					FavoriteTile(status: status)
				}
			}
		}
	}

	private var largeView: some View {
		VStack(alignment: .leading, spacing: 10) {
			ForEach(entry.favorites.prefix(8)) { status in
				Link(destination: status.favorite.deepLinkURL) {
					FavoriteRow(status: status)
				}
			}
			Spacer(minLength: 0)
		}
	}
}

private struct FavoriteTile: View {
	let status: FavoriteStatus

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Image(systemName: status.iconName)
					.foregroundStyle(status.tintColor)
				Spacer()
			}
			Spacer(minLength: 0)
			Text(status.favorite.displayName)
				.font(.caption)
				.fontWeight(.semibold)
				.lineLimit(1)
			Text(status.subtitle)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.padding(10)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
	}
}

private struct FavoriteRow: View {
	let status: FavoriteStatus

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: status.iconName)
				.foregroundStyle(.white)
				.frame(width: 30, height: 30)
				.background(status.tintColor)
				.clipShape(Circle())
			VStack(alignment: .leading, spacing: 1) {
				Text(status.favorite.displayName)
					.font(.subheadline)
					.fontWeight(.semibold)
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(status.subtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			Spacer()
		}
	}
}

// MARK: - Widget declaration

struct TaiFindWidget: Widget {
	let kind: String = "TaiFindWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
			TaiFindWidgetEntryView(entry: entry)
				.containerBackground(.fill.tertiary, for: .widget)
		}
		.configurationDisplayName("Favorites")
		.description("Track your favorited air quality and YouBike stations.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
	}
}

#Preview(as: .systemSmall) {
	TaiFindWidget()
} timeline: {
	FavoritesEntry(date: .now, favorites: FavoritesProvider.placeholderFavorites)
}

#Preview(as: .systemMedium) {
	TaiFindWidget()
} timeline: {
	FavoritesEntry(date: .now, favorites: FavoritesProvider.placeholderFavorites)
}

#Preview(as: .systemLarge) {
	TaiFindWidget()
} timeline: {
	FavoritesEntry(date: .now, favorites: FavoritesProvider.placeholderFavorites)
}
