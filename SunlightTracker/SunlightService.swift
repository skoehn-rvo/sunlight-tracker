import Foundation
import CoreLocation

private let kSavedLatKey = "SunlightTracker.latitude"
private let kSavedLngKey = "SunlightTracker.longitude"

/// Loaded sunlight stats for the popover (all from API except days-until-equinox).
struct SunStats {
    let today: DayData
    let dayLengthMinutes: Double
    let sunrise: Date
    let sunset: Date
    /// Day length change vs yesterday (positive = longer today, negative = shorter).
    let minutesChangeFromYesterday: Double
    /// Day length change vs most recent solstice (positive = longer today, negative = shorter).
    let minutesChangeSinceSolstice: Double
    /// Sunrise change vs most recent solstice in minutes (positive = earlier today, negative = later today).
    let minutesSunriseChangeVsSolstice: Int
    /// Sunset change vs most recent solstice in minutes (positive = later today, negative = earlier today).
    let minutesSunsetChangeVsSolstice: Int
    /// "Winter Solstice" or "Summer Solstice" — whichever happened more recently.
    let recentSolsticeLabel: String
    /// Next key day name: "Spring Equinox", "Summer Solstice", "Fall Equinox", or "Winter Solstice".
    let nextKeyDayName: String
    /// Days until nextKeyDayName (0 = today is that day).
    let daysUntilNextKeyDay: Int
    /// 0...100 = percent of the way from shortest day (winter solstice) to longest day (summer solstice).
    let percentFromShortestToLongestDay: Int
}

/// Fetches and holds sunlight data; used by the menu bar popover.
final class SunlightService: ObservableObject {
    enum LoadState {
        case idle
        case loading
        case loaded(SunStats)
        case error(String)
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published var displayName: String = "Current location"

    private let api = SunriseSunsetAPI()
    private let geocoder = CLGeocoder()
    private let calendar = Calendar.current
    private(set) var coordinate: CLLocationCoordinate2D

    static let defaultCoordinate = CLLocationCoordinate2D(latitude: 44.9383968, longitude: -92.668729)

    init(coordinate: CLLocationCoordinate2D? = nil) {
        if let lat = UserDefaults.standard.object(forKey: kSavedLatKey) as? Double,
           let lng = UserDefaults.standard.object(forKey: kSavedLngKey) as? Double {
            self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            self.coordinate = coordinate ?? Self.defaultCoordinate
        }
        Task { @MainActor in
            await updateDisplayName()
        }
    }

    func setLocation(_ newCoordinate: CLLocationCoordinate2D) {
        coordinate = newCoordinate
        UserDefaults.standard.set(newCoordinate.latitude, forKey: kSavedLatKey)
        UserDefaults.standard.set(newCoordinate.longitude, forKey: kSavedLngKey)
        Task { @MainActor in
            await updateDisplayName()
            refresh()
        }
    }

    private func updateDisplayName() async {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(loc)
            let name: String
            if let p = placemarks.first {
                let parts = [p.locality, p.administrativeArea].compactMap { $0 }
                name = parts.isEmpty ? (p.country ?? "Current location") : parts.joined(separator: ", ")
            } else {
                name = "Current location"
            }
            await MainActor.run { displayName = name }
        } catch {
            await MainActor.run { displayName = "Current location" }
        }
    }

    func fetchIfNeeded() {
        guard case .idle = loadState else { return }
        loadState = .loading

        Task { @MainActor in
            await performFetch()
        }
    }

    func refresh() {
        loadState = .idle
        fetchIfNeeded()
    }

    private func performFetch() async {
        let today = Date()
        let (solsticeDate, solsticeLabel) = mostRecentSolstice(from: today)
        let (nextKeyName, daysUntilNext) = nextKeyDay(from: today)
        let (winterDate, summerDate) = winterAndSummerSolstice(for: today)

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            await MainActor.run { loadState = .error("Invalid date") }
            return
        }

        do {
            async let todayData = api.fetch(lat: coordinate.latitude, lng: coordinate.longitude, date: today)
            async let yesterdayData = api.fetch(lat: coordinate.latitude, lng: coordinate.longitude, date: yesterday)
            async let solsticeData = api.fetch(lat: coordinate.latitude, lng: coordinate.longitude, date: solsticeDate)
            async let winterData = api.fetch(lat: coordinate.latitude, lng: coordinate.longitude, date: winterDate)
            async let summerData = api.fetch(lat: coordinate.latitude, lng: coordinate.longitude, date: summerDate)

            let todayResult = try await todayData
            let yesterdayResult = try await yesterdayData
            let solsticeResult = try await solsticeData
            let winterResult = try await winterData
            let summerResult = try await summerData

            await MainActor.run {
                let changeFromYesterday = todayResult.dayLengthMinutes - yesterdayResult.dayLengthMinutes
                let changeSinceSolstice = todayResult.dayLengthMinutes - solsticeResult.dayLengthMinutes
                let (sunriseChange, sunsetChange) = sunriseSunsetChangeVsSolstice(today: todayResult, solstice: solsticeResult)
                let percent = percentFromShortestToLongest(
                    today: todayResult.dayLengthMinutes,
                    winter: winterResult.dayLengthMinutes,
                    summer: summerResult.dayLengthMinutes
                )
                loadState = .loaded(SunStats(
                    today: todayResult,
                    dayLengthMinutes: todayResult.dayLengthMinutes,
                    sunrise: todayResult.sunrise,
                    sunset: todayResult.sunset,
                    minutesChangeFromYesterday: changeFromYesterday,
                    minutesChangeSinceSolstice: changeSinceSolstice,
                    minutesSunriseChangeVsSolstice: sunriseChange,
                    minutesSunsetChangeVsSolstice: sunsetChange,
                    recentSolsticeLabel: solsticeLabel,
                    nextKeyDayName: nextKeyName,
                    daysUntilNextKeyDay: daysUntilNext,
                    percentFromShortestToLongestDay: percent
                ))
            }
        } catch {
            await MainActor.run { loadState = .error(error.localizedDescription) }
        }
    }

    /// Winter and summer solstice dates for the year (shortest and longest day).
    private func winterAndSummerSolstice(for date: Date) -> (Date, Date) {
        let year = calendar.component(.year, from: date)
        let winter: Date
        if let w = keyDayDate(month: 12, day: 21, year: year),
           calendar.startOfDay(for: date) >= calendar.startOfDay(for: w) {
            winter = w
        } else if let w = keyDayDate(month: 12, day: 21, year: year - 1) {
            winter = w
        } else {
            winter = date
        }
        let summer = keyDayDate(month: 6, day: 21, year: year) ?? date
        return (winter, summer)
    }

    /// 0...100 = percent from shortest (winter) to longest (summer) day.
    private func percentFromShortestToLongest(today: Double, winter: Double, summer: Double) -> Int {
        let range = summer - winter
        guard range > 0 else { return 50 }
        let p = (today - winter) / range * 100
        return min(100, max(0, Int(round(p))))
    }

    // MARK: - Key days (Northern Hemisphere approximate dates)

    /// Winter Dec 21, Spring Mar 20, Summer Jun 21, Fall Sep 22.
    private func keyDayDate(month: Int, day: Int, year: Int) -> Date? {
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = day
        return calendar.date(from: comp)
    }

    /// Solstice that happened most recently (on or before today). Returns (date, "Winter Solstice" or "Summer Solstice").
    private func mostRecentSolstice(from date: Date) -> (Date, String) {
        let year = calendar.component(.year, from: date)
        guard let summerThisYear = keyDayDate(month: 6, day: 21, year: year),
              let winterLastYear = keyDayDate(month: 12, day: 21, year: year - 1),
              let winterThisYear = keyDayDate(month: 12, day: 21, year: year) else {
            return (date, "Winter Solstice")
        }
        let startOfToday = calendar.startOfDay(for: date)
        if startOfToday >= summerThisYear && startOfToday < winterThisYear {
            return (summerThisYear, "Summer Solstice")
        }
        if startOfToday >= winterThisYear {
            return (winterThisYear, "Winter Solstice")
        }
        return (winterLastYear, "Winter Solstice")
    }

    /// Next key day (Spring Equinox, Summer Solstice, Fall Equinox, Winter Solstice) and days until it.
    private func nextKeyDay(from date: Date) -> (name: String, daysUntil: Int) {
        let year = calendar.component(.year, from: date)
        let startOfToday = calendar.startOfDay(for: date)
        let keyDays: [(String, Int, Int)] = [
            ("Spring Equinox", 3, 20),
            ("Summer Solstice", 6, 21),
            ("Fall Equinox", 9, 22),
            ("Winter Solstice", 12, 21),
        ]
        for (name, month, day) in keyDays {
            if let d = keyDayDate(month: month, day: day, year: year) {
                let keyDayStart = calendar.startOfDay(for: d)
                if keyDayStart >= startOfToday {
                    let days = calendar.dateComponents([.day], from: startOfToday, to: keyDayStart).day ?? 0
                    return (name, days)
                }
            }
        }
        if let nextSpring = keyDayDate(month: 3, day: 20, year: year + 1) {
            let days = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: nextSpring)).day ?? 0
            return ("Spring Equinox", days)
        }
        return ("Spring Equinox", 0)
    }

    /// Time of day in minutes from midnight (local).
    private func minutesFromMidnight(_ date: Date) -> Int {
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        return h * 60 + m
    }

    /// (sunrise change vs solstice in min: positive = earlier today, sunset change vs solstice in min: positive = later today).
    private func sunriseSunsetChangeVsSolstice(today: DayData, solstice: DayData) -> (Int, Int) {
        let todayRise = minutesFromMidnight(today.sunrise)
        let todaySet = minutesFromMidnight(today.sunset)
        let solsticeRise = minutesFromMidnight(solstice.sunrise)
        let solsticeSet = minutesFromMidnight(solstice.sunset)
        let sunriseChange = solsticeRise - todayRise
        let sunsetChange = todaySet - solsticeSet
        return (sunriseChange, sunsetChange)
    }

}
