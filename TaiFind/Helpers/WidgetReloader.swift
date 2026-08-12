//
//  WidgetReloader.swift
//  TaiFind
//
//  Main app only — nudges WidgetKit to re-read the shared cache after a fetch.
//

import WidgetKit

enum WidgetReloader {
	static func reloadFavoritesWidget() {
		WidgetCenter.shared.reloadTimelines(ofKind: YouBikeWidgetRefresh.widgetKind)
	}
}
