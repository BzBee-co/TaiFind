//
//  AQIWidgetRefresh.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/27.
//
//  Shared between the app and widget extension: mirrors YouBikeWidgetRefresh,
//  but AQI's upstream feed is a single nationwide fetch (no per-city split
//  needed), so this is a little simpler.
//

import Foundation

enum AQIWidgetRefresh {
	/// Fetches the live AQI feed and writes it into LocalCache. Failure is
	/// ignored so an existing cache entry can still be shown — same pattern
	/// as YouBikeWidgetRefresh.refreshCachedYouBikeData.
	static func refreshCachedAQIData(completion: @escaping () -> Void) {
		APIService.fetchAQI { result in
			if case .success(let records) = result, !records.isEmpty {
				LocalCache.save(records, forKey: CacheKeys.aqiRecords)
			}
			completion()
		}
	}
}
