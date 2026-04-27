import AppIntents
import WidgetKit
import SwiftUI

struct CityPrayerTimes: Equatable {
    let location: PrayerLocation
    let times: PrayerTimes?
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let cities: [CityPrayerTimes]
    let selectedCities: [PrayerLocation]
    let didFetchSucceed: Bool

    var primary: CityPrayerTimes {
        let target = selectedCities.first ?? .makkah
        return cities.first { $0.location == target }
            ?? cities.first
            ?? CityPrayerTimes(location: target, times: .placeholder)
    }

    /// First five user-selected cities, joined to the fetched data.
    var largeRows: [CityPrayerTimes] {
        let limited = Array(selectedCities.prefix(5))
        return limited.compactMap { loc in
            cities.first { $0.location == loc }
        }
    }
}

struct PrayerTimesProvider: AppIntentTimelineProvider {
    typealias Entry = PrayerEntry
    typealias Intent = SelectCitiesIntent

    func placeholder(in context: Context) -> PrayerEntry {
        let cities = PrayerLocation.saudiCities.map {
            CityPrayerTimes(location: $0, times: .placeholder)
        }
        return PrayerEntry(
            date: Date(),
            cities: cities,
            selectedCities: PrayerLocation.defaultLargeCities,
            didFetchSucceed: true
        )
    }

    func snapshot(for configuration: SelectCitiesIntent, in context: Context) async -> PrayerEntry {
        var entry = placeholder(in: context)
        let selected = resolveSelectedCities(configuration)
        entry = PrayerEntry(
            date: entry.date,
            cities: entry.cities,
            selectedCities: selected,
            didFetchSucceed: true
        )
        return entry
    }

    func timeline(for configuration: SelectCitiesIntent, in context: Context) async -> Timeline<PrayerEntry> {
        let now = Date()
        let allCities = PrayerLocation.saudiCities
        let selected = resolveSelectedCities(configuration)

        var resultsByLocation: [PrayerLocation: PrayerTimes?] = [:]
        await withTaskGroup(of: (PrayerLocation, PrayerTimes?).self) { group in
            for city in allCities {
                group.addTask {
                    let times = try? await PrayerTimesAPI.fetch(for: now, location: city)
                    return (city, times)
                }
            }
            for await (location, times) in group {
                resultsByLocation[location] = times
            }
        }

        let ordered = allCities.map { city in
            CityPrayerTimes(location: city, times: resultsByLocation[city] ?? nil)
        }
        let success = ordered.contains { $0.times != nil }
        let entry = PrayerEntry(
            date: now,
            cities: ordered,
            selectedCities: selected,
            didFetchSucceed: success
        )
        let cal = Calendar(identifier: .gregorian)
        let nextRefresh = cal.date(
            byAdding: .day,
            value: 1,
            to: cal.startOfDay(for: now)
        ) ?? now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func resolveSelectedCities(_ config: SelectCitiesIntent) -> [PrayerLocation] {
        let mapped = config.cities.map { $0.location }
        return mapped.isEmpty ? PrayerLocation.defaultLargeCities : mapped
    }
}

struct PrayerTimesWidget: Widget {
    let kind = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCitiesIntent.self,
            provider: PrayerTimesProvider()
        ) { entry in
            PrayerTimesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prayer Times")
        .description("Today's prayer times. Tap and edit to pick which cities to show.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct PrayerTimesWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemExtraLarge:
            MultiCityTableView(date: entry.date, rows: entry.cities, didFetchSucceed: entry.didFetchSucceed)
        case .systemLarge:
            MultiCityTableView(date: entry.date, rows: entry.largeRows, didFetchSucceed: entry.didFetchSucceed)
        default:
            SingleCityView(entry: entry)
        }
    }
}

// MARK: - Single city (medium)

private struct SingleCityView: View {
    let entry: PrayerEntry

    private var primary: CityPrayerTimes { entry.primary }
    private var times: PrayerTimes { primary.times ?? .placeholder }

    private var nextPrayerKind: PrayerKind? {
        let cal = Calendar(identifier: .gregorian)
        for prayer in times.ordered where prayer.kind.isPrayer {
            if let date = prayer.date(on: entry.date, calendar: cal), date > entry.date {
                return prayer.kind
            }
        }
        return .fajr
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DateHeaderView(date: entry.date, locationLabel: primary.location.arabicName)
            Divider()
            HStack(alignment: .center, spacing: 0) {
                ForEach(times.ordered, id: \.kind) { prayer in
                    PrayerCell(prayer: prayer, isNext: prayer.kind == nextPrayerKind && prayer.kind.isPrayer)
                        .frame(maxWidth: .infinity)
                }
            }
            if !entry.didFetchSucceed {
                Text("Showing default times — couldn't reach the prayer-times service.")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }
        }
    }
}

private struct PrayerCell: View {
    let prayer: Prayer
    let isNext: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(prayer.kind.arabic)
                .font(.system(size: 11, weight: isNext ? .bold : .medium))
                .foregroundColor(isNext ? .red : .primary)
            Text(prayer.displayTime)
                .font(.system(size: 15, weight: isNext ? .bold : .semibold))
                .foregroundColor(isNext ? .red : .primary)
                .monospacedDigit()
            Text(prayer.kind.english)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isNext ? Color.red.opacity(0.10) : Color.clear)
        )
    }
}

// MARK: - Multi-city table (large + extra large)

private struct MultiCityTableView: View {
    let date: Date
    let rows: [CityPrayerTimes]
    let didFetchSucceed: Bool

    private let prayerOrder: [PrayerKind] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactDateHeader(date: date)

            if rows.isEmpty {
                Spacer()
                Text("لم يتم اختيار مدن — عدّل الويدجت لاختيار المدن.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                table
                Spacer(minLength: 0)
            }

            if !didFetchSucceed {
                Text("⚠︎ تعذّر الوصول إلى خدمة المواقيت")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var table: some View {
        let compact = rows.count > 7
        let rowVerticalPadding: CGFloat = compact ? 3 : 6
        let rowFont: CGFloat = compact ? 11 : 12
        let headerFont: CGFloat = compact ? 10 : 11

        return VStack(spacing: 0) {
            // Header bar (single continuous strip)
            HStack(spacing: 0) {
                tableCell("المدينة")
                ForEach(prayerOrder, id: \.self) { kind in
                    tableCell(kind.arabic)
                }
            }
            .font(.system(size: headerFont, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, rowVerticalPadding + 2)
            .background(Color.primary.opacity(0.10))

            // Data rows with alternating backgrounds
            ForEach(Array(rows.enumerated()), id: \.element.location.englishName) { idx, city in
                HStack(spacing: 0) {
                    Text(city.location.arabicName)
                        .font(.system(size: rowFont, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                    ForEach(prayerOrder, id: \.self) { kind in
                        Text(timeFor(kind: kind, city: city))
                            .font(.system(size: rowFont, weight: .regular))
                            .monospacedDigit()
                            .foregroundColor(city.times == nil ? .secondary.opacity(0.5) : .primary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, rowVerticalPadding)
                .background(idx.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func tableCell(_ text: String) -> some View {
        Text(text).frame(maxWidth: .infinity)
    }

    private func timeFor(kind: PrayerKind, city: CityPrayerTimes) -> String {
        guard let times = city.times else { return "—" }
        let time: String
        switch kind {
        case .fajr: time = times.fajr
        case .sunrise: time = times.sunrise
        case .dhuhr: time = times.dhuhr
        case .asr: time = times.asr
        case .maghrib: time = times.maghrib
        case .isha: time = times.isha
        }
        return Prayer(kind: kind, time: time).displayTime
    }
}

private struct CompactDateHeader: View {
    let date: Date

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(HijriDateUtils.gregorianDay(date))")
                    .font(.system(size: 20, weight: .bold))
                Text(HijriDateUtils.gregorianMonthYear(date))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(HijriDateUtils.weekdayArabic(date))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 4) {
                    Text(HijriDateUtils.hijriDayString(date))
                    Text(HijriDateUtils.hijriMonthName(date))
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(.system(size: 14, weight: .bold))

                Text("\(HijriDateUtils.hijriYearArabic(date)) هـ")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Shared header

private struct DateHeaderView: View {
    let date: Date
    let locationLabel: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(HijriDateUtils.gregorianDay(date))")
                    .font(.system(size: 22, weight: .bold))
                Text(HijriDateUtils.gregorianMonthYear(date))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(HijriDateUtils.weekdayArabic(date))
                    .font(.system(size: 13, weight: .semibold))
                if let locationLabel {
                    Text(locationLabel)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(HijriDateUtils.hijriDayString(date))
                    Text(HijriDateUtils.hijriMonthName(date))
                }
                .environment(\.layoutDirection, .leftToRight)
                .font(.system(size: 13, weight: .bold))

                Text("\(HijriDateUtils.hijriYearArabic(date)) هـ")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}
