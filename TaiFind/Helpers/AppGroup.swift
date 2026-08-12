//
//  AppGroup.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/10.
//

import Foundation

/// Central place for the App Group identifier shared between TaiFind and its
/// widget extension. Both targets need this exact string added under
/// Signing & Capabilities → App Groups for shared storage (favorites, cached
/// station data) to work — a typo here silently breaks sharing rather than
/// crashing, so keep this the single source of truth rather than repeating
/// the literal string elsewhere.
enum AppGroup {
	static let identifier = "group.com.bzbee.TaiFind"

	/// Shared container URL both processes can read/write. nil if the
	/// entitlement isn't set up correctly on whichever target calls this.
	static var containerURL: URL? {
		FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
	}
}

/// Keys into LocalCache, centralized so the main app (which writes these) and
/// the widget extension (which only reads them) can't drift apart on the
/// literal string. A typo here means the widget silently reads nothing.
enum CacheKeys {
	static let aqiRecords = "aqi_records"
	static let trashcanRecords = "trashcan_records"
	static let youBikeTaipeiStations = "youbike_taipei_stations"
	static let youBikeTaichungStations = "youbike_taichung_stations"
}
