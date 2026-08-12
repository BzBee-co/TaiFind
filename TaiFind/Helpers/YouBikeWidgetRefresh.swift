//
//  YouBikeWidgetRefresh.swift
//  TaiFind
//
//  Shared between the app and widget extension: keeps YouBike data in the
//  App Group cache fresh enough for home-screen widgets.
//

import Foundation

enum YouBikeWidgetRefresh {
	static let widgetKind = "TaiFindWidget"
	static let youBikeTimelineMinutes = 5
	static let defaultTimelineMinutes = 15

	static func hasYouBikeFavorites(_ favorites: [FavoriteStation]) -> Bool {
		favorites.contains { $0.type == .youBikeTaipei || $0.type == .youBikeTaichung }
	}

	static func timelineIntervalMinutes(for favorites: [FavoriteStation]) -> Int {
		hasYouBikeFavorites(favorites) ? youBikeTimelineMinutes : defaultTimelineMinutes
	}

	/// Fetches live YouBike feeds for whichever cities appear in `favorites`,
	/// writing successful results into `LocalCache`. Failures are ignored so an
	/// existing cache entry can still be shown.
	static func refreshCachedYouBikeData(for favorites: [FavoriteStation], completion: @escaping () -> Void) {
		let needsTaipei = favorites.contains { $0.type == .youBikeTaipei }
		let needsTaichung = favorites.contains { $0.type == .youBikeTaichung }
		guard needsTaipei || needsTaichung else {
			completion()
			return
		}

		let group = DispatchGroup()

		if needsTaipei {
			group.enter()
			APIService.fetchYouBikeStations { result in
				if case .success(let stations) = result, !stations.isEmpty {
					LocalCache.save(stations, forKey: CacheKeys.youBikeTaipeiStations)
				}
				group.leave()
			}
		}

		if needsTaichung {
			group.enter()
			APIService.fetchTaichungYouBikeStations { result in
				if case .success(let stations) = result, !stations.isEmpty {
					LocalCache.save(stations, forKey: CacheKeys.youBikeTaichungStations)
				}
				group.leave()
			}
		}

		group.notify(queue: .global(qos: .utility), execute: completion)
	}
}

enum WidgetDataAge {
	static func formatted(since date: Date) -> String {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .abbreviated
		return formatter.localizedString(for: date, relativeTo: Date())
	}
}
