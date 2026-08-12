//
//  TaiFindWidget.swift
//  TaiFindWidget
//
//  Created by Antoine Moreau on 2026/8/10.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline entry

/// A favorite joined with its current live value, computed when the timeline
/// entry is built. AQI reads the shared cache; YouBike favorites trigger a
/// live fetch on each timeline reload so availability stays reasonably fresh.
struct FavoriteStatus: Identifiable {
	let favorite: FavoriteStation
	var id: String { favorite.id }

	// Populated for .aqi favorites only.
	let aqiValue: Int?
	let aqiStatus: String?

	// Populated for .youBikeTaipei / .youBikeTaichung favorites only.
	let bikesAvailable: Int?
	let docksAvailable: Int?

	/// When the joined live value was last fetched into the shared cache.
	let dataUpdatedAt: Date?

	var hasLiveData: Bool {
		aqiValue != nil || bikesAvailable != nil
	}

	var subtitle: String {
		if let aqiValue, let aqiStatus {
			return joinedSubtitle("AQI \(aqiValue) · \(aqiStatus)", age: dataUpdatedAt)
		}
		if let bikesAvailable, let docksAvailable {
			return joinedSubtitle("\(bikesAvailable) bikes · \(docksAvailable) docks", age: dataUpdatedAt)
		}
		return "No data yet"
	}

	private func joinedSubtitle(_ value: String, age: Date?) -> String {
		guard let age else { return value }
		return "\(value) · \(WidgetDataAge.formatted(since: age))"
	}

	var tintColor: Color {
		if let aqiValue {
			return MeasurementType.aqi.color(for: Double(aqiValue))
		}
		return .indigo
	}

	var iconName: String {
		favorite.type == .aqi ? "aqi.medium" : "bicycle"
	}

	var isYouBike: Bool {
		favorite.type == .youBikeTaipei || favorite.type == .youBikeTaichung
	}

	/// Footer line under the station name — for YouBike the counts live in the
	/// icon columns, so this is just freshness (or a no-data fallback).
	var footerSubtitle: String {
		if isYouBike {
			if bikesAvailable != nil, let dataUpdatedAt {
				return WidgetDataAge.formatted(since: dataUpdatedAt)
			}
			return "No data yet"
		}
		return subtitle
	}
}

struct FavoritesEntry: TimelineEntry {
	let date: Date
	let favorites: [FavoriteStatus]
	/// True when favorites exist but none could be joined with cached live values
	/// (empty cache, or cache not yet populated by the main app).
	let isLiveDataUnavailable: Bool
}

// MARK: - Timeline provider

struct FavoritesProvider: TimelineProvider {
	func placeholder(in context: Context) -> FavoritesEntry {
		FavoritesEntry(date: Date(), favorites: Self.placeholderFavorites, isLiveDataUnavailable: false)
	}

	func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
		if context.isPreview {
			completion(FavoritesEntry(date: Date(), favorites: Self.placeholderFavorites, isLiveDataUnavailable: false))
			return
		}
		refreshThenLoadEntry(completion: completion)
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
		refreshThenLoadEntry { entry in
			let favorites = FavoritesStore.load()
			let interval = YouBikeWidgetRefresh.timelineIntervalMinutes(for: favorites)
			let nextUpdate = Calendar.current.date(byAdding: .minute, value: interval, to: Date())
				?? Date().addingTimeInterval(TimeInterval(interval * 60))
			completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
		}
	}

	/// YouBike availability goes stale quickly — when favorites include a YouBike
	/// station, fetch live feeds here (widget extensions are allowed network
	/// access during timeline reloads) before reading the shared cache.
	private func refreshThenLoadEntry(completion: @escaping (FavoritesEntry) -> Void) {
		let favorites = FavoritesStore.load()
		guard YouBikeWidgetRefresh.hasYouBikeFavorites(favorites) else {
			completion(loadEntry())
			return
		}

		YouBikeWidgetRefresh.refreshCachedYouBikeData(for: favorites) {
			completion(loadEntry())
		}
	}

	private func loadEntry() -> FavoritesEntry {
		let favorites = FavoritesStore.load()

		let aqiCache = LocalCache.load([AQIRecord].self, forKey: CacheKeys.aqiRecords)
		let taipeiCache = LocalCache.load([YouBikeStation].self, forKey: CacheKeys.youBikeTaipeiStations)
		let taichungCache = LocalCache.load([TaichungYouBikeStation].self, forKey: CacheKeys.youBikeTaichungStations)

		let aqiRecords = aqiCache?.value ?? []
		let taipeiStations = taipeiCache?.value ?? []
		let taichungStations = taichungCache?.value ?? []

		let statuses = favorites.map { favorite -> FavoriteStatus in
			switch favorite.type {
			case .aqi:
				if let record = aqiRecords.first(where: { $0.siteID == favorite.stationID }) {
					return FavoriteStatus(
						favorite: favorite,
						aqiValue: record.aqi,
						aqiStatus: record.status,
						bikesAvailable: nil,
						docksAvailable: nil,
						dataUpdatedAt: aqiCache?.timestamp
					)
				}
			case .youBikeTaipei:
				if let station = taipeiStations.first(where: { $0.sno == favorite.stationID }) {
					return FavoriteStatus(
						favorite: favorite,
						aqiValue: nil,
						aqiStatus: nil,
						bikesAvailable: station.available_rent_bikes,
						docksAvailable: station.available_return_bikes,
						dataUpdatedAt: taipeiCache?.timestamp
					)
				}
			case .youBikeTaichung:
				if let station = taichungStations.first(where: { $0.sno == favorite.stationID }) {
					return FavoriteStatus(
						favorite: favorite,
						aqiValue: nil,
						aqiStatus: nil,
						bikesAvailable: station.available_rent_bikes,
						docksAvailable: station.available_return_bikes,
						dataUpdatedAt: taichungCache?.timestamp
					)
				}
			}
			return FavoriteStatus(
				favorite: favorite,
				aqiValue: nil,
				aqiStatus: nil,
				bikesAvailable: nil,
				docksAvailable: nil,
				dataUpdatedAt: nil
			)
		}

		return FavoritesEntry(
			date: Date(),
			favorites: statuses,
			isLiveDataUnavailable: !favorites.isEmpty && !statuses.contains(where: \.hasLiveData)
		)
	}

	static let placeholderFavorites: [FavoriteStatus] = [
		FavoriteStatus(favorite: FavoriteStation(type: .aqi, stationID: "12", displayName: "Zhongshan"), aqiValue: 46, aqiStatus: "Good", bikesAvailable: nil, docksAvailable: nil, dataUpdatedAt: Date().addingTimeInterval(-120)),
		FavoriteStatus(favorite: FavoriteStation(type: .youBikeTaipei, stationID: "500101001", displayName: "NTU Main Gate"), aqiValue: nil, aqiStatus: nil, bikesAvailable: 6, docksAvailable: 10, dataUpdatedAt: Date().addingTimeInterval(-180))
	]
}

// MARK: - Views

struct TaiFindWidgetEntryView: View {
	@Environment(\.widgetFamily) private var family
	var entry: FavoritesProvider.Entry

	var body: some View {
		if entry.favorites.isEmpty {
			emptyState
		} else if entry.isLiveDataUnavailable {
			noDataState
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

	private var noDataState: some View {
		VStack(spacing: 6) {
			Image(systemName: "exclamationmark.triangle")
				.font(.title2)
				.foregroundStyle(.secondary)
			Text("No Data Yet")
				.font(.caption)
				.fontWeight(.semibold)
			Text("Open TaiFind to refresh station data.")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
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

private enum FavoriteTileMetrics {
	static let iconSize: CGFloat = 17
	static let iconRowHeight: CGFloat = 20
	static let columnSpacing: CGFloat = 6
	static let rowSpacing: CGFloat = 2
	static let slotWidth: CGFloat = 26
	static let valueFont: Font = .title3.bold()
}

/// Icon row + value row with fixed heights so mixed YouBike/AQI tiles in a
/// medium widget keep their numbers on the same baseline.
private struct FavoriteTileMetricsHeader: View {
	let status: FavoriteStatus

	var body: some View {
		VStack(alignment: .leading, spacing: FavoriteTileMetrics.rowSpacing) {
			HStack(spacing: FavoriteTileMetrics.columnSpacing) {
				if status.isYouBike {
					metricIcon("bicycle", color: .indigo)
					metricIcon("parkingsign.circle", color: .indigo)
				} else {
					metricIcon(status.iconName, color: status.tintColor)
				}
			}
			.frame(height: FavoriteTileMetrics.iconRowHeight, alignment: .leading)

			HStack(spacing: FavoriteTileMetrics.columnSpacing) {
				if status.isYouBike {
					metricValue(status.bikesAvailable)
					metricValue(status.docksAvailable)
				} else if let aqiValue = status.aqiValue {
					metricValue(aqiValue, color: status.tintColor)
				}
			}
		}
	}

	private func metricIcon(_ name: String, color: Color) -> some View {
		Image(systemName: name)
			.font(.system(size: FavoriteTileMetrics.iconSize, weight: .semibold))
			.foregroundStyle(color)
			.frame(width: FavoriteTileMetrics.slotWidth, height: FavoriteTileMetrics.iconRowHeight)
	}

	private func metricValue(_ value: Int?, color: Color = .primary) -> some View {
		Text(value.map(String.init) ?? "—")
			.font(FavoriteTileMetrics.valueFont)
			.fontWeight(.bold)
			.foregroundStyle(color)
			.frame(width: FavoriteTileMetrics.slotWidth, alignment: .center)
			.minimumScaleFactor(0.7)
			.lineLimit(1)
	}

	private func metricValue(_ value: Int, color: Color) -> some View {
		metricValue(Optional(value), color: color)
	}
}

private struct YouBikeAvailabilityMetrics: View {
	let bikes: Int?
	let docks: Int?
	var iconSize: CGFloat
	var valueFont: Font
	var spacing: CGFloat

	init(bikes: Int?, docks: Int?, iconSize: CGFloat = 17, valueFont: Font = .headline.bold(), spacing: CGFloat = 10) {
		self.bikes = bikes
		self.docks = docks
		self.iconSize = iconSize
		self.valueFont = valueFont
		self.spacing = spacing
	}

	var body: some View {
		HStack(spacing: spacing) {
			metricColumn(symbol: "bicycle", value: bikes)
			metricColumn(symbol: "parkingsign.circle", value: docks)
		}
	}

	private func metricColumn(symbol: String, value: Int?) -> some View {
		VStack(spacing: 4) {
			Image(systemName: symbol)
				.font(.system(size: iconSize, weight: .semibold))
				.foregroundStyle(.indigo)
			Text(value.map(String.init) ?? "—")
				.font(valueFont)
				.foregroundStyle(.primary)
				.minimumScaleFactor(0.7)
				.lineLimit(1)
		}
	}
}

private struct FavoriteTile: View {
	let status: FavoriteStatus

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			FavoriteTileMetricsHeader(status: status)
			Spacer(minLength: 0)
			Text(status.favorite.displayName)
				.font(.caption)
				.fontWeight(.semibold)
				.lineLimit(1)
			Text(status.footerSubtitle)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.padding(8)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
	}
}

private struct FavoriteRow: View {
	let status: FavoriteStatus

	var body: some View {
		HStack(spacing: 10) {
			if status.isYouBike {
				YouBikeAvailabilityMetrics(
					bikes: status.bikesAvailable,
					docks: status.docksAvailable,
					iconSize: 17,
					spacing: 10
				)
			} else {
				Image(systemName: status.iconName)
					.foregroundStyle(.white)
					.frame(width: 30, height: 30)
					.padding(4)
					.background(status.tintColor)
					.clipShape(Circle())
			}
			VStack(alignment: .leading, spacing: 1) {
				Text(status.favorite.displayName)
					.font(.subheadline)
					.fontWeight(.semibold)
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(status.footerSubtitle)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
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
	FavoritesEntry(date: .now, favorites: FavoritesProvider.placeholderFavorites, isLiveDataUnavailable: false)
}

#Preview(as: .systemMedium) {
	TaiFindWidget()
} timeline: {
	FavoritesEntry(
		date: .now,
		favorites: [
			FavoriteStatus(favorite: FavoriteStation(type: .youBikeTaipei, stationID: "500101001", displayName: "NTU Main Gate"), aqiValue: nil, aqiStatus: nil, bikesAvailable: 6, docksAvailable: 10, dataUpdatedAt: .now.addingTimeInterval(-180)),
			FavoriteStatus(favorite: FavoriteStation(type: .aqi, stationID: "12", displayName: "Zhongshan"), aqiValue: 46, aqiStatus: "Good", bikesAvailable: nil, docksAvailable: nil, dataUpdatedAt: .now.addingTimeInterval(-120)),
			FavoriteStatus(favorite: FavoriteStation(type: .youBikeTaichung, stationID: "500101002", displayName: "Taichung Station"), aqiValue: nil, aqiStatus: nil, bikesAvailable: 3, docksAvailable: 8, dataUpdatedAt: .now.addingTimeInterval(-90))
		],
		isLiveDataUnavailable: false
	)
}

#Preview(as: .systemLarge) {
	TaiFindWidget()
} timeline: {
	FavoritesEntry(date: .now, favorites: FavoritesProvider.placeholderFavorites, isLiveDataUnavailable: false)
}
