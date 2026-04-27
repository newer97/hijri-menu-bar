import AppIntents
import Foundation

struct CityEntity: AppEntity {
    var id: String
    let englishName: String
    let arabicName: String
    let latitude: Double
    let longitude: Double

    init(_ location: PrayerLocation) {
        self.id = location.englishName
        self.englishName = location.englishName
        self.arabicName = location.arabicName
        self.latitude = location.latitude
        self.longitude = location.longitude
    }

    var location: PrayerLocation {
        PrayerLocation(
            englishName: englishName,
            arabicName: arabicName,
            latitude: latitude,
            longitude: longitude
        )
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "City")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(arabicName)", subtitle: "\(englishName)")
    }

    static var defaultQuery = CityQuery()
}

struct CityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        PrayerLocation.saudiCities
            .filter { identifiers.contains($0.englishName) }
            .map(CityEntity.init)
    }

    func suggestedEntities() async throws -> [CityEntity] {
        PrayerLocation.saudiCities.map(CityEntity.init)
    }
}

struct SelectCitiesIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Cities"
    static var description = IntentDescription(
        "Pick the cities to show. The first city is used in the medium widget; up to five appear in large; the extra-large widget always shows the full Saudi table."
    )

    @Parameter(title: "Cities")
    var cities: [CityEntity]

    init() {
        self.cities = PrayerLocation.defaultLargeCities.map(CityEntity.init)
    }

    init(cities: [CityEntity]) {
        self.cities = cities
    }
}
