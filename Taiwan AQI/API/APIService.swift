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
