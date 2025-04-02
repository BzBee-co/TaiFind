import Foundation

class APIService {
    static func fetchAQI(completion: @escaping ([AQIRecord]) -> Void) {
        let urlString = "https://your-api-url.com"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                let decodedResponse = try JSONDecoder().decode(AQIData.self, from: data)
                let records = decodedResponse.records.map { record in
                    AQIRecord(
                        siteName: record.sitename,
                        latitude: Double(record.latitude) ?? 0.0,
                        longitude: Double(record.longitude) ?? 0.0,
                        aqi: Int(record.aqi) ?? 0,
                        status: record.status
                    )
                }
                completion(records)
            } catch {
                print("Failed to decode JSON: \(error)")
            }
        }.resume()
    }
}

struct AQIData: Codable {
    let records: [APIRecord]
}

struct APIRecord: Codable {
    let sitename: String
    let latitude: String
    let longitude: String
    let aqi: String
    let status: String
}
