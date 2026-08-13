//
//  RefreshYouBikeStationIntent.swift
//  TaiFindWidgetExtension
//
//  Created by Antoine Moreau on 2026/8/13.
//
//  Interactive widget button action (iOS 17+): lets the user force an
//  immediate refresh of one YouBike station's city data, rather than waiting
//  for the next scheduled timeline reload. Reuses the same
//  fetch-and-cache-with-fallback logic the timeline provider already uses,
//  so a failed live fetch just leaves the existing cached value in place
//  rather than showing an error.


import AppIntents
import WidgetKit

struct RefreshYouBikeStationIntent: AppIntent {
	static var title: LocalizedStringResource = "Refresh YouBike Station"

	// AppIntent requires a parameterless init; @Parameter carries the favorite's
	// stable id (see FavoriteStation.id) across the App Intents serialization
	// boundary — a plain FavoriteStation isn't guaranteed encodable that way.
	@Parameter(title: "Favorite ID")
	var favoriteID: String

	init() {}

	init(favorite: FavoriteStation) {
		self.favoriteID = favorite.id
	}

	func perform() async throws -> some IntentResult {
		guard let favorite = FavoritesStore.load().first(where: { $0.id == favoriteID }) else {
			return .result()
		}

		await withCheckedContinuation { continuation in
			// Passing just this one favorite means only its city gets refetched —
			// refreshCachedYouBikeData derives which city(ies) to hit from the
			// favorites array it's given.
			YouBikeWidgetRefresh.refreshCachedYouBikeData(for: [favorite]) {
				continuation.resume()
			}
		}

		WidgetReloader.reloadFavoritesWidget()
		return .result()
	}
}
