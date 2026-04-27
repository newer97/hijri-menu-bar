import WidgetKit
import SwiftUI

@main
struct HijriWidgetBundle: WidgetBundle {
    var body: some Widget {
        HijriDateWidget()
        PrayerTimesWidget()
    }
}

struct HijriEntry: TimelineEntry {
    let date: Date
}

struct HijriProvider: TimelineProvider {
    func placeholder(in context: Context) -> HijriEntry {
        HijriEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HijriEntry) -> Void) {
        completion(HijriEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HijriEntry>) -> Void) {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOfTomorrow = cal.date(
            byAdding: .day,
            value: 1,
            to: cal.startOfDay(for: now)
        ) ?? now.addingTimeInterval(3600)
        let entries = [HijriEntry(date: now)]
        completion(Timeline(entries: entries, policy: .after(startOfTomorrow)))
    }
}

struct HijriDateWidget: Widget {
    let kind = "HijriDateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HijriProvider()) { entry in
            HijriWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hijri Date")
        .description("Today's date in Hijri and Gregorian.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct HijriWidgetView: View {
    let entry: HijriEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(date: entry.date)
        case .systemLarge:
            CalendarWidgetView(date: entry.date, dayCellHeight: 38, headerScale: 1.0)
        case .systemExtraLarge:
            CalendarWidgetView(date: entry.date, dayCellHeight: 48, headerScale: 1.25)
        default:
            MediumWidgetView(date: entry.date)
        }
    }
}

private struct MediumWidgetView: View {
    let date: Date

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(HijriDateUtils.weekdayArabic(date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(HijriDateUtils.gregorianDay(date))")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(HijriDateUtils.gregorianMonthYear(date))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(HijriDateUtils.hijriDayString(date))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(HijriDateUtils.hijriMonthName(date))
                    .font(.system(size: 14, weight: .semibold))
                Text("\(HijriDateUtils.hijriYearArabic(date)) هـ")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct CalendarWidgetView: View {
    let date: Date
    let dayCellHeight: CGFloat
    let headerScale: CGFloat

    private let weekdays: [(ar: String, en: String)] = [
        ("الأحد", "Sun"), ("الإثنين", "Mon"), ("الثلاثاء", "Tue"),
        ("الأربعاء", "Wed"), ("الخميس", "Thu"), ("الجمعة", "Fri"), ("السبت", "Sat")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * headerScale) {
            header
            Divider()
            weekdayRow
            grid
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HijriDateUtils.hijriMonthArabic(for: date))
                    .font(.system(size: 18 * headerScale, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11 * headerScale))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var subtitle: String {
        let g = HijriDateUtils.gregorianMonthYear(date)
        let h = HijriDateUtils.hijriYears(for: date).map(String.init).joined(separator: "/")
        return "\(g)  ·  \(h) هـ"
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.en) { label in
                Text(label.ar)
                    .font(.system(size: 10 * headerScale, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let dates = HijriDateUtils.calendarGrid(for: date)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 1) {
            ForEach(dates, id: \.self) { d in
                WidgetDayCell(
                    date: d,
                    inMonth: HijriDateUtils.isInMonth(d, month: date),
                    isToday: HijriDateUtils.isToday(d),
                    height: dayCellHeight
                )
            }
        }
    }
}

private struct WidgetDayCell: View {
    let date: Date
    let inMonth: Bool
    let isToday: Bool
    let height: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.red)
                        .frame(width: height * 0.7, height: height * 0.7)
                }
                Text("\(HijriDateUtils.gregorianDay(date))")
                    .font(.system(size: height * 0.36, weight: isToday ? .semibold : .regular))
                    .foregroundColor(gregorianColor)
            }
            .frame(height: height * 0.7)

            Text("\(HijriDateUtils.hijriDay(date))")
                .font(.system(size: height * 0.22, weight: .medium))
                .foregroundColor(hijriColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var gregorianColor: Color {
        if isToday { return .white }
        return inMonth ? .primary : .secondary.opacity(0.4)
    }

    private var hijriColor: Color {
        if isToday { return .red }
        return inMonth ? .secondary : .secondary.opacity(0.35)
    }
}
