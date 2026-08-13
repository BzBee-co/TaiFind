//
//  WidgetReloader.swift
//  TaiFind
//
//  Nudges WidgetKit to re-read the shared cache and redraw. Called from the
//  main app after its own successful fetches, and from the widget extension
//  itself (see RefreshYouBikeStationIntent) after a user-triggered refresh —
//  needs target membership in both.
//

import WidgetKit

enum WidgetReloader {
	static func reloadFavoritesWidget() {
		WidgetCenter.shared.reloadTimelines(ofKind: YouBikeWidgetRefresh.widgetKind)
	}
}
