//
//  FavoriteStation.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2026/8/10.
//

import Foundation

enum FavoriteType: String, Codable {
	case aqi
	case youBikeTaipei
	case youBikeTaichung
}

/// A user-starred station. Only stores enough to identify and label the
/// station — the actual live values (AQI number, bikes available, etc.) are
/// always looked up fresh from the current data rather than frozen at the
/// moment it was favorited. `displayName` is kept so there's still something
/// reasonable to show before that live join has happened (e.g. a cold widget
/// launch, before the shared cache has been read).
struct FavoriteStation: Identifiable, Codable, Equatable {
	let type: FavoriteType
	let stationID: String  // siteID for AQI; sno for YouBike (either city)
	let displayName: String

	var id: String { "\(type.rawValue):\(stationID)" }
}

// MARK: - Deep linking

/// Widget tap targets. The widget builds these; the app's .onOpenURL parses
/// them back into (type, stationID) via `FavoriteType.init(urlPathComponent:)`
/// below — kept in one place so the two ends can't drift out of sync on the
/// URL shape.
extension FavoriteType {
	/// Path segment used in the deep link, e.g. "taifind://station/aqi/204".
	var urlPathComponent: String {
		switch self {
		case .aqi: return "aqi"
		case .youBikeTaipei: return "youbike-taipei"
		case .youBikeTaichung: return "youbike-taichung"
		}
	}

	init?(urlPathComponent: String) {
		switch urlPathComponent {
		case "aqi": self = .aqi
		case "youbike-taipei": self = .youBikeTaipei
		case "youbike-taichung": self = .youBikeTaichung
		default: return nil
		}
	}
}

extension FavoriteStation {
	/// e.g. "taifind://station/youbike-taipei/500101003". stationID is always
	/// a plain numeric string from the upstream APIs, so this is safe without
	/// percent-encoding — falls back to a bare scheme URL in the (should be
	/// impossible) case construction ever fails, rather than crashing.
	var deepLinkURL: URL {
		URL(string: "taifind://station/\(type.urlPathComponent)/\(stationID)") ?? URL(string: "taifind://")!
	}
}
