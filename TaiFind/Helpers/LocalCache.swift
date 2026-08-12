//
//  LocalCache.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/9.
//

import Foundation

/// Simple on-disk JSON cache for "last known good" data.
///
/// Two problems this solves that nothing in the app currently handles:
/// 1. Cold launch with no network — the app has nothing to show until a fetch
///    succeeds, even though it successfully loaded and displayed this exact
///    data five minutes ago in a previous session.
/// 2. A live fetch fails on an already-running app, but nothing was ever
///    fetched this session either (e.g. the trashcan/YouBike layers, which
///    only fetch on demand when the user toggles them on) — so there's no
///    in-memory fallback to preserve, only whatever was last written to disk.
///
/// Each entry is timestamped so callers can tell how stale a cached value is.
enum LocalCache {
	struct Envelope<T: Codable>: Codable {
		let timestamp: Date
		let data: T
	}

	// Shared with the widget extension via App Group, so both processes read
	// the exact same cached snapshots — this is what makes it possible for a
	// widget to show real data without doing its own network fetch. Falls
	// back to the app's own sandboxed caches directory if the App Group
	// container is ever unavailable (e.g. entitlement misconfigured) —
	// degrades gracefully rather than crashing; in that fallback case the
	// widget just won't see this particular cache until it's fixed.
	private static var cacheDirectory: URL {
		if let groupContainer = AppGroup.containerURL?.appendingPathComponent("Cache", isDirectory: true) {
			try? FileManager.default.createDirectory(at: groupContainer, withIntermediateDirectories: true)
			return groupContainer
		}

		print("⚠️ LocalCache: App Group container unavailable — falling back to local caches directory (widget won't see this data)")
		return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
	}

	private static func fileURL(for key: String) -> URL {
		cacheDirectory.appendingPathComponent("\(key).json")
	}

	/// Overwrites the cached value for `key`. Fire-and-forget — a failure to
	/// write the cache (e.g. disk full) shouldn't interrupt the live fetch
	/// that's already succeeded and is being shown on screen.
	static func save<T: Codable>(_ value: T, forKey key: String) {
		let envelope = Envelope(timestamp: Date(), data: value)
		do {
			let encoded = try JSONEncoder().encode(envelope)
			try encoded.write(to: fileURL(for: key), options: .atomic)
		} catch {
			print("⚠️ LocalCache: failed to save cache for key '\(key)': \(error)")
		}
	}

	/// Returns the cached value and when it was saved, or nil if there's no
	/// cache yet, or the on-disk data no longer matches `T` (e.g. after a
	/// model change across app versions) — treated as "no cache" rather than
	/// a crash.
	static func load<T: Codable>(_ type: T.Type, forKey key: String) -> (value: T, timestamp: Date)? {
		guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
		guard let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data) else {
			print("⚠️ LocalCache: cached data for key '\(key)' didn't decode as \(T.self) — ignoring stale cache")
			return nil
		}
		return (envelope.data, envelope.timestamp)
	}
}
