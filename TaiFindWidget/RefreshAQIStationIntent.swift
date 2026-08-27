//
//  RefreshAQIStationIntent.swift
//  TaiFindWidget
//
//  Created by Antoine Moreau on 2026/8/27.
//
//  Interactive widget button action (iOS 17+), mirroring
//  RefreshYouBikeStationIntent — lets the user force an immediate AQI refresh
//  instead of waiting for the next scheduled timeline reload.
//

import AppIntents
import WidgetKit

struct RefreshAQIStationIntent: AppIntent {
	static var title: LocalizedStringResource = "Refresh Air Quality Data"

	// AQI's fetch isn't per-station (it's a single nationwide feed), so
	// favoriteID isn't actually needed to perform the refresh — kept anyway
	// to match RefreshYouBikeStationIntent's shape, so both buttons can be
	// constructed the same way at their call sites.
	@Parameter(title: "Favorite ID")
	var favoriteID: String

	init() {}

	init(favorite: FavoriteStation) {
		self.favoriteID = favorite.id
	}

	func perform() async throws -> some IntentResult {
		await withCheckedContinuation { continuation in
			AQIWidgetRefresh.refreshCachedAQIData {
				continuation.resume()
			}
		}

		WidgetReloader.reloadFavoritesWidget()
		return .result()
	}
}
