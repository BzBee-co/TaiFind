//
//  TrashCanData.swift
//  TaiFind
//
//  Created by Antoine Moreau on 2025/7/20.
//

import Foundation
import SwiftUI

struct TrashCanData: Codable {
	let timestamp: String
	let result: ResultData

	struct ResultData: Codable {
		let results: [TrashCan]
	}

	struct TrashCan: Codable, Identifiable {
		let id = UUID()
		let name: String
		let address: String
		let longitude: String
		let latitude: String

		enum CodingKeys: String, CodingKey {
			case name = "name"
			case address = "address"
			case longitude = "longitude"
			case latitude = "latitude"
		}
	}
}

@Observable
class TrashCanService {
	private let endpoint = URL(string: "https://air-quality-proxy.antoimn.workers.dev/trashcans")!
	private let cacheKey = "cachedTrashCans"
	private let cacheDateKey = "lastTrashCanFetch"

	var trashCans: [TrashCanData.TrashCan] = []

	init() {
		loadCachedData()
		Task {
			await refreshIfNeeded()
		}
	}

	private func loadCachedData() {
		if let data = UserDefaults.standard.data(forKey: cacheKey),
		   let decoded = try? JSONDecoder().decode(TrashCanData.self, from: data) {
			trashCans = decoded.result.results
		}
	}

	private func save(_ data: TrashCanData) {
		if let encoded = try? JSONEncoder().encode(data) {
			UserDefaults.standard.set(encoded, forKey: cacheKey)
			UserDefaults.standard.set(Date(), forKey: cacheDateKey)
		}
	}

	private func shouldRefresh() -> Bool {
		guard let lastFetch = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else {
			return true
		}
		return Calendar.current.isDateInYesterday(lastFetch)
	}

	func refreshIfNeeded() async {
		guard shouldRefresh() else { return }

		do {
			let (data, _) = try await URLSession.shared.data(from: endpoint)
			let decoded = try JSONDecoder().decode(TrashCanData.self, from: data)
			DispatchQueue.main.async {
				self.trashCans = decoded.result.results
				self.save(decoded)
			}
		} catch {
			print("Failed to fetch trash cans:", error)
		}
	}
}


