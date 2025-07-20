import Foundation

class APIService {
	static func fetchAQI(completion: @escaping ([AQIRecord]) -> Void) {
		let locale = Locale.current.language.languageCode?.identifier == "zh" ? "zh" : "en"
		let urlString = "https://air-quality-proxy.antoimn.workers.dev?locale=\(locale)"
		guard let url = URL(string: urlString) else { return }

		var request = URLRequest(url: url)

		URLSession.shared.dataTask(with: request) { data, response, error in
			guard let data = data, error == nil else { return }
			do {
				let decodedResponse = try JSONDecoder().decode(AQIData.self, from: data)
				let records = decodedResponse.records.map { record in
					var fixedSiteName = record.sitename
					var fixedCounty = record.county
					
					if record.siteID == "201" && locale != "zh" {
						fixedSiteName = "Yilan (Sanxing)"
						fixedCounty = "Yilan County"
					}
					
					return AQIRecord(
						siteName: fixedSiteName,
						county: fixedCounty,
						latitude: Double(record.latitude) ?? 0.0,
						longitude: Double(record.longitude) ?? 0.0,
						aqi: Int(record.aqi) ?? 0,
						pollutant: record.pollutant,
						status: record.status,
						so2: Double(record.so2 ?? ""),
						co: Double(record.co ?? ""),
						o3: Double(record.o3 ?? ""),
						pm10: Double(record.pm10 ?? ""),
						pm2_5: Double(record.pm2_5 ?? ""),
						no2: Double(record.no2 ?? ""),
						publishtime: record.publishtime,
						siteID: record.siteID
					)
				}

				completion(records)
			} catch {
				print("Failed to decode JSON: \(error)")
			}
		}.resume()
	}

	
	// MARK: - Cached Trashcan Fetching from Proxy with 1-day cache

	private static let trashcanCacheKey = "cachedTrashcanData"
	private static let trashcanCacheDateKey = "cachedTrashcanDataDate"
	private static let trashcanURL = URL(string: "https://air-quality-proxy.antoimn.workers.dev/trashcans")!

	static func fetchAllTrashcans(completion: @escaping ([TrashcanRecord]) -> Void) {
		// Always check for any cached data (fresh or stale)
		let cachedData = UserDefaults.standard.data(forKey: trashcanCacheKey)
		let cacheDate = UserDefaults.standard.object(forKey: trashcanCacheDateKey) as? Date
		let cachedRecords: [TrashcanRecord]? = {
			guard let data = cachedData else { return nil }
			return try? JSONDecoder().decode([TrashcanRecord].self, from: data)
		}()
		let isCacheFresh = cacheDate != nil && !Calendar.current.isDateInYesterday(cacheDate!)

		// If cache is fresh, use it immediately
		if isCacheFresh, let cachedRecords = cachedRecords {
			completion(cachedRecords)
			return
		}

		// Otherwise, fetch fresh data from proxy endpoint
		let request = URLRequest(url: trashcanURL)
		URLSession.shared.dataTask(with: request) { data, response, error in
			if let data = data, error == nil {
				do {
					let trashcans = try JSONDecoder().decode([TrashcanRecord].self, from: data)
					if !trashcans.isEmpty {
						// Cache the data and date
						UserDefaults.standard.set(data, forKey: trashcanCacheKey)
						UserDefaults.standard.set(Date(), forKey: trashcanCacheDateKey)
						completion(trashcans)
						return
					}
					// If API returns empty, fall through to use cache if available
				} catch {
					print("Failed to decode trashcan JSON from proxy:", error)
					// Fall through to use cache if available
				}
			}
			// If API fails or returns empty, use cache (even if stale)
			if let cachedRecords = cachedRecords {
				completion(cachedRecords)
			} else {
				completion([]) // No cache at all, signal service down
			}
		}.resume()
	}
	
	// MARK: - YouBike Data Fetching
	static func fetchYouBikeStations(completion: @escaping ([YouBikeStation]) -> Void) {
		let urlString = "https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json"
		guard let url = URL(string: urlString) else {
			completion([])
			return
		}
		URLSession.shared.dataTask(with: url) { data, response, error in
			guard let data = data, error == nil else {
				completion([])
				return
			}
			do {
				let stations = try JSONDecoder().decode([YouBikeStation].self, from: data)
				completion(stations)
			} catch {
				print("Failed to decode YouBike JSON: \(error)")
				completion([])
			}
		}.resume()
	}
}

// MARK: - Decodable Data Structures
struct AQIData: Codable {
	let records: [APIRecord]
}

struct APIRecord: Codable {
	let sitename: String
	let county: String
	let latitude: String
	let longitude: String
	let aqi: String
	let pollutant: String?
	let status: String
	let so2: String?
	let co: String?
	let o3: String?
	let pm10: String?
	let pm2_5: String?
	let no2: String?
	let publishtime: String
	let siteID: String
	
	// Use CodingKeys to match JSON keys to Swift properties if needed.
	enum CodingKeys: String, CodingKey {
		case sitename, county, latitude, longitude, aqi, pollutant, status, so2, co, o3, pm10, no2, publishtime
		case pm2_5 = "pm2.5"
		case siteID = "siteid"
	}
}

// MARK: - Trashcan Data Structure (flat array assumed)
struct TrashcanRecord: Codable {
	let id: Int
	let district: String
	let address: String
	let longitude: String
	let latitude: String
	let note: String
	
	enum CodingKeys: String, CodingKey {
		case id = "_id"
		case district = "行政區"
		case address = "地址"
		case longitude = "經度"
		case latitude = "緯度"
		case note = "備註"
	}
}

// MARK: - YouBike Data Structure
struct YouBikeStation: Codable, Identifiable, Equatable {
	var id: String { sno }
	let sno: String
	let sna: String
	let snaen: String
	let longitude: Double
	let latitude: Double
	let available_rent_bikes: Int
	let available_return_bikes: Int
	let updateTime: String
	let infoTime: String
	let srcUpdateTime: String

	enum CodingKeys: String, CodingKey {
		case sno, sna, snaen, longitude, latitude, available_rent_bikes, available_return_bikes, updateTime, infoTime, srcUpdateTime
	}
}
