//
//  FavoritesStore.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/10.
//

import Foundation

/// Persists the favorites list to the shared App Group container so both the
/// app and the widget extension read the same list. Deliberately separate
/// from LocalCache: favorites are a user's explicit, durable choice, not a
/// "last known good" snapshot with a freshness/staleness concept.
enum FavoritesStore {
	private static var fileURL: URL? {
		AppGroup.containerURL?.appendingPathComponent("favorites.json")
	}

	/// Empty array if there's no saved file yet, the App Group entitlement is
	/// misconfigured, or the on-disk data fails to decode — all treated the
	/// same as "no favorites" rather than crashing.
	static func load() -> [FavoriteStation] {
		guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
		return (try? JSONDecoder().decode([FavoriteStation].self, from: data)) ?? []
	}

	static func save(_ favorites: [FavoriteStation]) {
		guard let fileURL else {
			print("⚠️ FavoritesStore: App Group container unavailable — favorites won't persist")
			return
		}
		do {
			let data = try JSONEncoder().encode(favorites)
			try data.write(to: fileURL, options: .atomic)
		} catch {
			print("⚠️ FavoritesStore: failed to save favorites: \(error)")
		}
	}
}
