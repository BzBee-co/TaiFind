import Foundation

// Errors fetchAQI can report back to callers so the UI can eventually
// distinguish "no internet", "bad URL", "server sent garbage", etc.,
// instead of just silently hanging in a loading state.
enum APIServiceError: LocalizedError {
	case invalidURL
	case network(Error)
	case noData
	case decoding(Error)

	var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "Invalid request URL."
		case .network(let error):
			return "Network error: \(error.localizedDescription)"
		case .noData:
			return "No data received from server."
		case .decoding(let error):
			return "Failed to read server response: \(error.localizedDescription)"
		}
	}
}

class APIService {
	// MARK: - Air Quality Data Fetching
	// Always calls completion exactly once, on success or failure — previously
	// this returned early (without calling completion at all) on an invalid URL
	// or a decode failure, which left AQIViewModel stuck in a permanent loading
	// state with isLoadingAirQualityData never reset back to false.
	static func fetchAQI(completion: @escaping (Result<[AQIRecord], APIServiceError>) -> Void) {
		let locale = Locale.current.language.languageCode?.identifier == "zh" ? "zh" : "en"
		let urlString = "https://air-quality-proxy.antoimn.workers.dev/air-quality?locale=\(locale)"
		guard let url = URL(string: urlString) else {
			completion(.failure(.invalidURL))
			return
		}

		let request = URLRequest(url: url)

		URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				completion(.failure(.network(error)))
				return
			}
			guard let data = data else {
				completion(.failure(.noData))
				return
			}
			do {
				let decodedResponse = try JSONDecoder().decode(RootResponse.self, from: data)
				let records = decodedResponse.data.records.map { record in
					var fixedSiteName = record.sitename
					var fixedCounty = record.county

					if record.siteID == "201" && locale == "en" {
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
				completion(.success(records))
			} catch {
				print("Failed to decode AQI JSON: \(error)")
				completion(.failure(.decoding(error)))
			}
		}.resume()
	}

	// MARK: - Trashcan Data Fetching
	// The Worker (see index.js) is now self-healing: it lazily populates and
	// refreshes its own KV cache, so there's no need for a client-side fallback
	// to a separate upstream API here anymore. The old fallback to Taipei's
	// legacy v1 dataset API has been removed — it pointed at a stale endpoint
	// and, combined with an empty Worker cache, was the original cause of
	// trashcans not appearing on the map at all.
	//
	// Returns nil on failure (rather than an empty array) so callers can choose
	// to keep showing the last-known-good data instead of wiping the map.
	static func fetchTrashcans(completion: @escaping ([TrashcanRecord]?) -> Void) {
		let urlString = "https://air-quality-proxy.antoimn.workers.dev/trashcans"
		guard let url = URL(string: urlString) else {
			print("⚠️ Invalid Worker URL")
			completion(nil)
			return
		}
		URLSession.shared.dataTask(with: url) { data, response, error in
			if let error = error {
				print("❌ Error fetching trashcans from Worker: \(error)")
				completion(nil)
				return
			}
			guard let data = data else {
				print("❌ No data from Worker")
				completion(nil)
				return
			}
			do {
				let decoded = try JSONDecoder().decode([TrashcanRecord].self, from: data)
				print("✅ Loaded trashcan data from Worker: \(decoded.count) records")
				completion(decoded)
			} catch {
				print("❌ Failed to decode trashcan JSON from Worker: \(error)")
				completion(nil)
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
				print("❌ Taipei YouBike fetch error: \(error?.localizedDescription ?? "unknown")")
				completion([])
				return
			}
			do {
				let stations = try JSONDecoder().decode([YouBikeStation].self, from: data)
				print("✅ Decoded Taipei YouBike stations: \(stations.count)")
				completion(stations)
			} catch {
				print("❌ Failed to decode Taipei YouBike JSON: \(error)")
				completion([])
			}
		}.resume()
	}

	// MARK: - Taichung YouBike Data Fetching
	static func fetchTaichungYouBikeStations(completion: @escaping ([TaichungYouBikeStation]) -> Void) {
		let urlString = "https://datacenter.taichung.gov.tw/swagger/OpenData/bc27c2f7-6ed7-4f1a-b3cc-1a3cc9cda34e"
		guard let url = URL(string: urlString) else {
			completion([])
			return
		}
		URLSession.shared.dataTask(with: url) { data, response, error in
			guard let data = data, error == nil else {
				print("❌ Taichung YouBike fetch error: \(error?.localizedDescription ?? "unknown")")
				completion([])
				return
			}
			do {
				let response = try JSONDecoder().decode(TaichungYouBikeResponse.self, from: data)
				print("✅ Decoded Taichung YouBike stations: \(response.retVal.count)")
				completion(response.retVal)
			} catch {
				print("❌ Failed to decode Taichung YouBike JSON: \(error)")
				completion([])
			}
		}.resume()
	}
}

// MARK: - Decodable Data Structures for AQI API

struct RootResponse: Codable {
	let timestamp: Int64
	let data: AQIData
}

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

	enum CodingKeys: String, CodingKey {
		case sitename, county, latitude, longitude, aqi, pollutant, status, so2, co, o3, pm10, no2, publishtime
		case pm2_5 = "pm2.5"
		case siteID = "siteid"
	}
}

// MARK: - Trashcan Data Structures

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

// MARK: - YouBike Data Structures

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

// MARK: - Taichung YouBike Data Structures

struct TaichungYouBikeResponse: Codable {
	let retCode: Int
	let updated_at: String
	let retVal: [TaichungYouBikeStation]
}

struct TaichungYouBikeStation: Codable, Identifiable, Equatable {
	var id: String { sno }
	let scity: String
	let scityen: String
	let sna: String
	let sarea: String
	let ar: String
	let snaen: String
	let sareaen: String
	let aren: String
	let sno: String
	let tot: String
	let sbi: String
	let mday: String
	let lat: String
	let lng: String
	let bemp: String
	let act: IntOrString?
	let sbi_detail: TaichungBikeDetail
	
	var latitude: Double { Double(lat) ?? 0.0 }
	var longitude: Double { Double(lng) ?? 0.0 }
	var available_rent_bikes: Int { Int(sbi) ?? 0 }
	var available_return_bikes: Int { Int(bemp) ?? 0 }
	var total_docks: Int { Int(tot) ?? 0 }
	var updateTime: String { mday }
	var infoTime: String { mday }
	var srcUpdateTime: String { mday }
}

struct TaichungBikeDetail: Codable, Equatable {
	let yb2: String
	let eyb: String
}

// Supports Taichung 'act' coming as either an Int or a String
enum IntOrString: Codable, Equatable {
	case int(Int)
	case string(String)
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if let i = try? container.decode(Int.self) {
			self = .int(i)
			return
		}
		if let s = try? container.decode(String.self) {
			self = .string(s)
			return
		}
		throw DecodingError.typeMismatch(IntOrString.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String"))
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .int(let i): try container.encode(i)
		case .string(let s): try container.encode(s)
		}
	}
}
