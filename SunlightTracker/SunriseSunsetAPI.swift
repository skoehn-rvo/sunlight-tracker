import Foundation
import CoreLocation

/// Response from https://api.sunrise-sunset.org/json (formatted=0).
/// Times are in UTC; day_length is in seconds.
struct SunriseSunsetResponse: Decodable {
    let results: Results
    let status: String

    struct Results: Decodable {
        let sunrise: String
        let sunset: String
        let day_length: Int
        let civil_twilight_begin: String?
        let civil_twilight_end: String?
    }
}

/// One day's solar data from the API (times as Date in UTC; display in local with formatter).
struct DayData {
    let sunrise: Date
    let sunset: Date
    let dayLengthSeconds: Int
    /// Civil twilight begin/end (optional; API may omit in polar regions).
    let civilTwilightBegin: Date?
    let civilTwilightEnd: Date?

    var dayLengthMinutes: Double { Double(dayLengthSeconds) / 60 }

    /// Minutes of civil twilight before sunrise (nil if not available).
    var morningCivilTwilightMinutes: Double? {
        guard let begin = civilTwilightBegin else { return nil }
        return sunrise.timeIntervalSince(begin) / 60
    }

    /// Minutes of civil twilight after sunset (nil if not available).
    var eveningCivilTwilightMinutes: Double? {
        guard let end = civilTwilightEnd else { return nil }
        return end.timeIntervalSince(sunset) / 60
    }
}

enum SunriseSunsetError: Error {
    case invalidURL
    case network(Error)
    case invalidResponse
    case apiError(String)
}

/// Fetches sunrise/sunset and day length from the free API (no key required).
final class SunriseSunsetAPI {

    private static let base = "https://api.sunrise-sunset.org/json"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch solar data for a given date at a location. Times in response are UTC.
    func fetch(lat: Double, lng: Double, date: Date) async throws -> DayData {
        let calendar = Calendar.current
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comp.year, let m = comp.month, let d = comp.day else {
            throw SunriseSunsetError.invalidResponse
        }
        let dateStr = String(format: "%04d-%02d-%02d", y, m, d)

        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "date", value: dateStr),
            URLQueryItem(name: "formatted", value: "0"),
        ]
        guard let url = components.url else { throw SunriseSunsetError.invalidURL }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(SunriseSunsetResponse.self, from: data)

        guard decoded.status == "OK" else {
            throw SunriseSunsetError.apiError(decoded.status)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        guard let sunrise = iso.date(from: decoded.results.sunrise) ?? fallback.date(from: decoded.results.sunrise),
              let sunset = iso.date(from: decoded.results.sunset) ?? fallback.date(from: decoded.results.sunset) else {
            throw SunriseSunsetError.invalidResponse
        }

        let civilBegin = decoded.results.civil_twilight_begin.flatMap { iso.date(from: $0) ?? fallback.date(from: $0) }
        let civilEnd = decoded.results.civil_twilight_end.flatMap { iso.date(from: $0) ?? fallback.date(from: $0) }

        return DayData(
            sunrise: sunrise,
            sunset: sunset,
            dayLengthSeconds: decoded.results.day_length,
            civilTwilightBegin: civilBegin,
            civilTwilightEnd: civilEnd
        )
    }
}
