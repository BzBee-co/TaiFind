import Foundation

class APIService {
	static func fetchAQI(completion: @escaping ([AQIRecord]) -> Void) {
//		let urlString = "https://twaqicache.chabuduo.workers.dev"
		let urlString = "https://air-quality-proxy.antoimn.workers.dev"
		guard let url = URL(string: urlString) else { return }
		
		URLSession.shared.dataTask(with: url) { data, response, error in
			guard let data = data, error == nil else { return }
			do {
				let decodedResponse = try JSONDecoder().decode(AQIData.self, from: data)
				let records = decodedResponse.records.map { record in
					var fixedSiteName = record.sitename
					var fixedCounty = record.county
					
					// Manually correct the incorrect record
					if record.siteID == "201" {
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
	
	// MARK: - Taipei Trashcan Data Fetching
	static func fetchAllTrashcans(completion: @escaping ([TrashcanRecord]) -> Void) {
		let baseURL = "https://data.taipei/api/v1/dataset/267d550f-c6ec-46e0-b8af-fd5a464eb098?scope=resourceAquire"
		let limit = 200
		var allRecords: [TrashcanRecord] = []
		var offset = 0
		
		func fetchPage() {
			let urlString = "\(baseURL)&limit=\(limit)&offset=\(offset)"
			guard let url = URL(string: urlString) else {
				completion(allRecords)
				return
			}
			URLSession.shared.dataTask(with: url) { data, response, error in
				guard let data = data, error == nil else {
					completion(allRecords)
					return
				}
				do {
					let decoded = try JSONDecoder().decode(TaipeiTrashcanResponse.self, from: data)
					let results = decoded.result.results
					allRecords.append(contentsOf: results)
					if results.count == limit {
						offset += limit
						fetchPage()
					} else {
						completion(allRecords)
					}
				} catch {
					print("Failed to decode trashcan JSON: \(error)")
					completion(allRecords)
				}
			}.resume()
		}
		fetchPage()
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

// MARK: - Taipei Trashcan Data Structures
struct TaipeiTrashcanResponse: Codable {
	let result: TaipeiTrashcanResult
}

struct TaipeiTrashcanResult: Codable {
	let results: [TrashcanRecord]
}

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
