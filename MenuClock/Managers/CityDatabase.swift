import Foundation

struct City: Identifiable, Hashable {
    let id: Int
    let name: String         // Display, may contain accents: "Reykjavík"
    let asciiName: String    // ASCII fallback for search: "Reykjavik"
    let countryCode: String  // ISO 3166-1 alpha-2: "IS"
    let admin1: String       // Full state/province/region name: "Idaho" (may be empty)
    let population: Int
    let timeZoneIdentifier: String
    let latitude: Double
    let longitude: Double

    var countryName: String {
        Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    /// "Idaho, United States" or "United States" when admin1 is empty.
    var subtitle: String {
        if admin1.isEmpty { return countryName }
        return "\(admin1), \(countryName)"
    }
}

/// Loads and searches the bundled GeoNames cities5000 dataset.
///
/// Data © GeoNames (https://www.geonames.org) — CC BY 4.0.
final class CityDatabase {
    static let shared = CityDatabase()

    private(set) var cities: [City] = []
    private var loaded = false

    /// Most populous city per IANA time zone. Built lazily on first lookup.
    private var tzToCity: [String: City] = [:]
    private var tzIndexBuilt = false

    private init() {}

    /// Load synchronously from the main bundle. Cheap (~40ms) for ~68k rows.
    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "cities", withExtension: "tsv"),
              let data = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("MenuClock: cities.tsv not found in bundle")
            return
        }

        var result: [City] = []
        result.reserveCapacity(70_000)
        var id = 0

        data.enumerateLines { line, _ in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 8 else { return }
            let population = Int(fields[4]) ?? 0
            let lat = Double(fields[6]) ?? 0
            let lng = Double(fields[7]) ?? 0
            result.append(City(
                id: id,
                name: String(fields[0]),
                asciiName: String(fields[1]),
                countryCode: String(fields[2]),
                admin1: String(fields[3]),
                population: population,
                timeZoneIdentifier: String(fields[5]),
                latitude: lat,
                longitude: lng
            ))
            id += 1
        }

        self.cities = result
    }

    /// Return the most populous city for an IANA time zone identifier, if any.
    /// Useful for deriving a sensible "local" city from the system time zone.
    func city(forTimeZone identifier: String) -> City? {
        loadIfNeeded()
        if !tzIndexBuilt {
            // Cities are already sorted by population descending, so the first
            // time we see a given timezone is the most populous match.
            var map: [String: City] = [:]
            map.reserveCapacity(500)
            for city in cities where map[city.timeZoneIdentifier] == nil {
                map[city.timeZoneIdentifier] = city
            }
            self.tzToCity = map
            self.tzIndexBuilt = true
        }
        return tzToCity[identifier]
    }

    /// Accent- and case-insensitive search across city name, admin1, and country.
    /// Prefix matches on the city name rank above substring matches; within each
    /// group order is preserved from the source (sorted by population desc).
    func search(_ query: String, limit: Int = 200) -> [City] {
        loadIfNeeded()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(cities.prefix(limit))
        }

        let folded = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        var prefix: [City] = []
        var contains: [City] = []
        prefix.reserveCapacity(limit)

        for city in cities {
            let asciiLower = city.asciiName.lowercased()
            if asciiLower.hasPrefix(folded) {
                prefix.append(city)
                if prefix.count >= limit { break }
                continue
            }
            if asciiLower.contains(folded) {
                if contains.count < limit { contains.append(city) }
                continue
            }
            let admin1Lower = city.admin1
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            if !admin1Lower.isEmpty && admin1Lower.contains(folded) {
                if contains.count < limit { contains.append(city) }
                continue
            }
            let countryLower = city.countryName
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            if countryLower.contains(folded) {
                if contains.count < limit { contains.append(city) }
            }
        }

        var combined = prefix
        if combined.count < limit {
            combined.append(contentsOf: contains.prefix(limit - combined.count))
        }
        return combined
    }
}
