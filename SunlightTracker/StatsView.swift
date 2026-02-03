import SwiftUI

/// Statistics and milestones for daylight (winter → spring). Data from Sunrise-Sunset API.
struct StatsView: View {
    @ObservedObject var service: SunlightService
    @State private var showLocationSearch = false

    /// Spacing between content sections (day length, solstice, next key day, rise/set).
    private static let contentSectionSpacing: CGFloat = 16

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                header
                Divider()

                switch service.loadState {
                case .idle, .loading:
                    loadingSection
                case .loaded(let stats):
                    content(stats: stats)
                case .error(let message):
                    errorSection(message: message)
                }
            }
            .frame(width: 280)
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
            .onAppear {
                service.fetchIfNeeded()
            }

            if showLocationSearch {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LocationSearchView(
                        onSelect: { coord in
                            service.setLocation(coord)
                            showLocationSearch = false
                        },
                        onCancel: { showLocationSearch = false }
                    )
                    .frame(width: 252)
                    .padding(20)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Sunlight Tracker")
                .font(.headline)
        }
    }

    private var loadingSection: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func content(stats: SunStats) -> some View {
        VStack(alignment: .leading, spacing: Self.contentSectionSpacing) {
            dayLengthSection(stats: stats)
            solsticeSection(stats: stats)
            nextKeyDaySection(stats: stats)
            riseAndSetSection(stats: stats)
            civilTwilightSection(stats: stats)
        }
        .padding(.top, 10)
    }

    private func dayLengthSection(stats: SunStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Today's day length in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(service.displayName) {
                    showLocationSearch = true
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formattedDayLength(stats.dayLengthMinutes))
                    .font(.title2)
                    .fontWeight(.medium)
                Text(changeFromYesterdayText(stats.minutesChangeFromYesterday))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func solsticeSection(stats: SunStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Since \(stats.recentSolsticeLabel.lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(changeSinceSolsticeText(stats.minutesChangeSinceSolstice, solsticeLabel: stats.recentSolsticeLabel))
                .font(.body)
                .fontWeight(.medium)
            Text(sunriseChangeVsSolsticeText(stats.minutesSunriseChangeVsSolstice))
                .font(.body)
            Text(sunsetChangeVsSolsticeText(stats.minutesSunsetChangeVsSolstice))
                .font(.body)
        }
    }

    private func nextKeyDaySection(stats: SunStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next key day")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if stats.daysUntilNextKeyDay > 1 {
                Text("\(stats.daysUntilNextKeyDay) days until \(stats.nextKeyDayName)")
                    .font(.body)
                    .fontWeight(.medium)
            } else if stats.daysUntilNextKeyDay == 1 {
                Text("Tomorrow is \(stats.nextKeyDayName)")
                    .font(.body)
                    .fontWeight(.medium)
            } else {
                Text("Today is \(stats.nextKeyDayName)!")
                    .font(.body)
                    .fontWeight(.medium)
            }
            Text("\(stats.percentFromShortestToLongestDay)% of the way from shortest to longest day")
                .font(.body)
                .fontWeight(.medium)
        }
    }

    private func riseAndSetSection(stats: SunStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(.orange)
                Text(Self.timeFormatter.string(from: stats.sunrise))
                Spacer()
                
                Image(systemName: "sunset.fill")
                    .foregroundStyle(.orange)
                Text(Self.timeFormatter.string(from: stats.sunset))
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func civilTwilightSection(stats: SunStats) -> some View {
        let begin = stats.today.civilTwilightBegin
        let end = stats.today.civilTwilightEnd
        if begin != nil || end != nil {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.secondary)
                    if let b = begin {
                        Text(Self.timeFormatter.string(from: b))
                    } else {
                        Text("—")
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("Civil Twilight")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(.secondary)
                    if let e = end {
                        Text(Self.timeFormatter.string(from: e))
                    } else {
                        Text("—")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func errorSection(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn’t load data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try again") {
                service.refresh()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func changeFromYesterdayText(_ minutes: Double) -> String {
        let totalSeconds = Int(round(minutes * 60))
        if totalSeconds == 0 {
            return "Same as yesterday"
        }
        let absSeconds = abs(totalSeconds)
        let m = absSeconds / 60
        let s = absSeconds % 60
        let timeStr = "\(m):\(s < 10 ? "0" : "")\(s)"
        if totalSeconds > 0 {
            return "+\(timeStr) longer than yesterday"
        } else {
            return "-\(timeStr) shorter than yesterday"
        }
    }

    private func changeSinceSolsticeText(_ minutes: Double, solsticeLabel: String) -> String {
        let label = solsticeLabel.lowercased()
        let absMin = abs(minutes)
        let formatted = formattedMinutes(absMin)
        if minutes > 0 {
            return "+\(formatted) longer day"
        } else if minutes < 0 {
            return "\(formatted) shorter day"
        } else {
            return "Same as \(label)"
        }
    }

    private func sunriseChangeVsSolsticeText(_ minutes: Int) -> String {
        let absMin = abs(minutes)
        if minutes > 0 {
            return "+\(absMin) min earlier sunrise"
        } else if minutes < 0 {
            return "-\(absMin) min later sunrise"
        } else {
            return "Same sunrise time as winter solstice"
        }
    }

    private func sunsetChangeVsSolsticeText(_ minutes: Int) -> String {
        let absMin = abs(minutes)
        if minutes > 0 {
            return "+\(absMin) min later sunset"
        } else if minutes < 0 {
            return "-\(absMin) min earlier sunset"
        } else {
            return "Same sunset time as winter solstice"
        }
    }

    private func formattedDayLength(_ minutes: Double) -> String {
        let h = Int(minutes / 60)
        let m = Int(minutes.truncatingRemainder(dividingBy: 60))
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m) min"
        }
    }

    private func formattedMinutes(_ minutes: Double) -> String {
        if minutes >= 60 {
            let h = Int(minutes / 60)
            let m = Int(minutes.truncatingRemainder(dividingBy: 60))
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            return "\(Int(minutes)) min"
        }
    }
}

#Preview {
    StatsView(service: SunlightService())
        .frame(height: 400)
}
