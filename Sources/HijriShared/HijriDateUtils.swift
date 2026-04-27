import Foundation

enum HijriDateUtils {
    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        c.firstWeekday = 1
        return c
    }()

    static let hijriArabic: Calendar = {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "ar")
        return c
    }()

    static let hijriEnglish: Calendar = {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "en")
        return c
    }()

    static func calendarGrid(for month: Date) -> [Date] {
        let monthStart = gregorian.dateInterval(of: .month, for: month)!.start
        let weekday = gregorian.component(.weekday, from: monthStart)
        let gridStart = gregorian.date(byAdding: .day, value: -(weekday - 1), to: monthStart)!
        return (0..<42).map { gregorian.date(byAdding: .day, value: $0, to: gridStart)! }
    }

    static func gregorianDay(_ date: Date) -> Int {
        gregorian.component(.day, from: date)
    }

    static func hijriDay(_ date: Date) -> Int {
        hijriEnglish.component(.day, from: date)
    }

    static func isInMonth(_ date: Date, month: Date) -> Bool {
        gregorian.isDate(date, equalTo: month, toGranularity: .month)
    }

    static func isToday(_ date: Date) -> Bool {
        gregorian.isDateInToday(date)
    }

    static func gregorianMonthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = gregorian
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    static func gregorianYear(_ date: Date) -> Int {
        gregorian.component(.year, from: date)
    }

    /// Arabic Hijri month name(s) covering the displayed Gregorian month.
    /// If the Gregorian month spans two Hijri months, both are joined with " / ".
    static func hijriMonthArabic(for gregorianMonth: Date) -> String {
        let interval = gregorian.dateInterval(of: .month, for: gregorianMonth)!
        let lastDay = gregorian.date(byAdding: .day, value: -1, to: interval.end)!
        let f = DateFormatter()
        f.calendar = hijriArabic
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "MMMM"
        let first = f.string(from: interval.start)
        let last = f.string(from: lastDay)
        return first == last ? first : "\(first) / \(last)"
    }

    static func hijriMonthsSpan(for gregorianMonth: Date) -> [String] {
        let interval = gregorian.dateInterval(of: .month, for: gregorianMonth)!
        let lastDay = gregorian.date(byAdding: .day, value: -1, to: interval.end)!
        let f = DateFormatter()
        f.calendar = hijriEnglish
        f.locale = Locale(identifier: "en")
        f.dateFormat = "MMMM"
        let first = f.string(from: interval.start)
        let last = f.string(from: lastDay)
        return first == last ? [first] : [first, last]
    }

    static func hijriYears(for gregorianMonth: Date) -> [Int] {
        let interval = gregorian.dateInterval(of: .month, for: gregorianMonth)!
        let lastDay = gregorian.date(byAdding: .day, value: -1, to: interval.end)!
        let startYear = hijriEnglish.component(.year, from: interval.start)
        let endYear = hijriEnglish.component(.year, from: lastDay)
        return startYear == endYear ? [startYear] : [startYear, endYear]
    }

    static func menuBarString(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = hijriArabic
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }

    static func weekdayArabic(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = gregorian
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    static func gregorianMonthYear(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = gregorian
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    static func hijriDayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = hijriArabic
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "d"
        return f.string(from: date)
    }

    static func hijriMonthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = hijriArabic
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    static func hijriYearArabic(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = hijriArabic
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }
}
