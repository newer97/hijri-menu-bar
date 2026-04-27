import Foundation

struct PrayerLocation: Equatable, Hashable {
    let englishName: String
    let arabicName: String
    let latitude: Double
    let longitude: Double

    static let makkah = PrayerLocation(englishName: "Makkah", arabicName: "مكة المكرمة", latitude: 21.3891, longitude: 39.8579)
    static let madinah = PrayerLocation(englishName: "Madinah", arabicName: "المدينة المنورة", latitude: 24.5247, longitude: 39.5692)
    static let jeddah = PrayerLocation(englishName: "Jeddah", arabicName: "جدة", latitude: 21.4858, longitude: 39.1925)
    static let riyadh = PrayerLocation(englishName: "Riyadh", arabicName: "الرياض", latitude: 24.7136, longitude: 46.6753)
    static let buraydah = PrayerLocation(englishName: "Buraydah", arabicName: "بريدة", latitude: 26.3260, longitude: 43.9750)
    static let alRass = PrayerLocation(englishName: "Al-Rass", arabicName: "الرس", latitude: 25.8693, longitude: 43.4906)
    static let dammam = PrayerLocation(englishName: "Dammam", arabicName: "الدمام", latitude: 26.4207, longitude: 50.0888)
    static let abha = PrayerLocation(englishName: "Abha", arabicName: "أبها", latitude: 18.2164, longitude: 42.5053)
    static let tabuk = PrayerLocation(englishName: "Tabuk", arabicName: "تبوك", latitude: 28.3998, longitude: 36.5715)
    static let hail = PrayerLocation(englishName: "Hail", arabicName: "حائل", latitude: 27.5114, longitude: 41.6900)
    static let arar = PrayerLocation(englishName: "Arar", arabicName: "عرعر", latitude: 30.9753, longitude: 41.0381)
    static let jazan = PrayerLocation(englishName: "Jazan", arabicName: "جازان", latitude: 16.9000, longitude: 42.5500)
    static let najran = PrayerLocation(englishName: "Najran", arabicName: "نجران", latitude: 17.4924, longitude: 44.1277)
    static let bahah = PrayerLocation(englishName: "Al Bahah", arabicName: "الباحة", latitude: 20.0129, longitude: 41.4677)
    static let sakaka = PrayerLocation(englishName: "Sakaka", arabicName: "سكاكا", latitude: 29.9697, longitude: 40.2064)

    static let saudiCities: [PrayerLocation] = [
        .makkah, .madinah, .jeddah, .riyadh, .buraydah, .alRass, .dammam,
        .abha, .tabuk, .hail, .arar, .jazan, .najran, .bahah, .sakaka,
    ]

    /// Sensible default for the configurable Large widget when the user hasn't picked any cities.
    static let defaultLargeCities: [PrayerLocation] = [.makkah, .madinah, .riyadh, .jeddah, .dammam]
}

struct PrayerTimes: Equatable {
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String

    static let placeholder = PrayerTimes(
        fajr: "04:32",
        sunrise: "05:52",
        dhuhr: "12:19",
        asr: "15:41",
        maghrib: "18:45",
        isha: "20:15"
    )

    /// Six-element ordered list (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha).
    var ordered: [Prayer] {
        [
            Prayer(kind: .fajr, time: fajr),
            Prayer(kind: .sunrise, time: sunrise),
            Prayer(kind: .dhuhr, time: dhuhr),
            Prayer(kind: .asr, time: asr),
            Prayer(kind: .maghrib, time: maghrib),
            Prayer(kind: .isha, time: isha),
        ]
    }
}

enum PrayerKind: String, CaseIterable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    var arabic: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    var english: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    /// Sunrise is a time marker, not a prayer — exclude it from "next prayer" logic.
    var isPrayer: Bool { self != .sunrise }
}

struct Prayer: Equatable {
    let kind: PrayerKind
    /// 24-hour "HH:mm" string from the API.
    let time: String

    /// Display string in 12-hour format without AM/PM, matching the reference screenshot.
    var displayTime: String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return time }
        var h = parts[0]
        let m = parts[1]
        if h > 12 { h -= 12 }
        if h == 0 { h = 12 }
        return String(format: "%02d:%02d", h, m)
    }

    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = parts[0]
        comps.minute = parts[1]
        return calendar.date(from: comps)
    }
}

enum PrayerTimesAPI {
    /// Fetches prayer times from the AlAdhan API using method=4 (Umm al-Qura).
    static func fetch(for date: Date, location: PrayerLocation) async throws -> PrayerTimes {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd-MM-yyyy"
        let dateStr = f.string(from: date)

        var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(dateStr)")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "method", value: "4"),
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 8

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(AladhanResponse.self, from: data)
        let t = decoded.data.timings
        return PrayerTimes(
            fajr: clean(t.Fajr),
            sunrise: clean(t.Sunrise),
            dhuhr: clean(t.Dhuhr),
            asr: clean(t.Asr),
            maghrib: clean(t.Maghrib),
            isha: clean(t.Isha)
        )
    }

    /// API sometimes returns "06:03 (UTC+03)" — keep just the HH:mm prefix.
    private static func clean(_ value: String) -> String {
        String(value.prefix(5))
    }
}

private struct AladhanResponse: Decodable {
    let data: AladhanData
}

private struct AladhanData: Decodable {
    let timings: AladhanTimings
}

private struct AladhanTimings: Decodable {
    let Fajr: String
    let Sunrise: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}
