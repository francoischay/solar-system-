import Foundation
import simd
import SatelliteKit

// Pont SGP4 (SatelliteKit) + chargement/caches des TLE Celestrak.

struct TLEMember {
    let name: String
    let satellite: Satellite
    /// époque du TLE en jours depuis J2000
    let epochDay: Double
    /// année de lancement, lue dans le désignateur international (colonnes 10-11 de la ligne 1)
    let launchYear: Int?
    let inclinationDeg: Double
}

enum TLEParser {
    static func looksLikeTLE(_ text: String) -> Bool {
        text.range(of: #"(^|\n)1 \d{5}"#, options: .regularExpression) != nil
    }

    static func launchYear(line1: String) -> Int? {
        guard line1.count > 11 else { return nil }
        let start = line1.index(line1.startIndex, offsetBy: 9)
        let end = line1.index(line1.startIndex, offsetBy: 11)
        guard let yy = Int(line1[start..<end].trimmingCharacters(in: .whitespaces)) else { return nil }
        return yy >= 57 ? 1900 + yy : 2000 + yy
    }

    /// JD(J2000) = 2451545.0 ; SatelliteKit compte en jours depuis 1950 (JD 2433281.5)
    static let days1950toJ2000 = 2_451_545.0 - 2_433_281.5

    static func parse(_ text: String, max: Int) -> [TLEMember] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        var members: [TLEMember] = []
        var i = 0
        while i + 1 < lines.count, members.count < max {
            if lines[i].hasPrefix("1 "), lines[i + 1].hasPrefix("2 ") {
                let name = i > 0 && !lines[i - 1].hasPrefix("1 ") && !lines[i - 1].hasPrefix("2 ") ? lines[i - 1] : ""
                if let elements = try? Elements(name, lines[i], lines[i + 1]) {
                    let sat = Satellite(withTLE: elements)
                    members.append(TLEMember(
                        name: name,
                        satellite: sat,
                        epochDay: sat.t₀Days1950 - days1950toJ2000,
                        launchYear: launchYear(line1: lines[i]),
                        inclinationDeg: elements.i₀ * 180 / .pi
                    ))
                }
                i += 2
            } else {
                i += 1
            }
        }
        return members
    }

    /// Position TEME (km) au jour de scène donné (jours depuis J2000). nil si la propagation échoue.
    static func position(_ member: TLEMember, day: Double) -> SIMD3<Double>? {
        let jd = 2_451_545.0 + day
        guard let v = try? member.satellite.position_throwz(julianDays: jd) else { return nil }
        let p = SIMD3(v.x, v.y, v.z)
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return nil }
        return p
    }
}

// MARK: - Cache disque + rafraîchissement Celestrak (TTL 12 h)

final class TLEStore {
    static let shared = TLEStore()
    private let ttl: TimeInterval = 43_200
    private var dir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tle")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func fileURL(_ key: String) -> URL { dir.appendingPathComponent(key + ".txt") }

    func cached(_ key: String, allowStale: Bool = false) -> String? {
        let url = fileURL(key)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              let text = try? String(contentsOf: url, encoding: .utf8),
              TLEParser.looksLikeTLE(text) else { return nil }
        return allowStale || Date().timeIntervalSince(modified) < ttl ? text : nil
    }

    func cache(_ key: String, text: String) {
        try? text.write(to: fileURL(key), atomically: true, encoding: .utf8)
    }

    /// Le jeu Starlink pèse 1,8 Mo : on tronque à maxBytes une fois téléchargé.
    func fetch(_ spec: SatSpec) async -> String? {
        let key = spec.group ?? String(spec.catnr ?? 0)
        if let text = cached(key) { return text }
        let query = spec.group.map { "GROUP=\($0)" } ?? "CATNR=\(spec.catnr ?? 0)"
        let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?\(query)&FORMAT=TLE")!
        var text: String? = nil
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            var fetched = String(decoding: data, as: UTF8.self)
            if spec.group != nil {
                let maxBytes = spec.maxMembers * 180
                if fetched.count > maxBytes { fetched = String(fetched.prefix(maxBytes)) }
            }
            // Celestrak répond « data has not updated » si on redemande trop tôt : on garde alors la copie locale
            if TLEParser.looksLikeTLE(fetched) { text = fetched; cache(key, text: fetched) }
        }
        return text ?? cached(key, allowStale: true)
    }
}

// MARK: - Prochains lancements (Launch Library, cache 1 h)

enum LaunchLibrary {
    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("launches.json")
    }

    static func load() async -> [LaunchSpec]? {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < 3600,
           let data = try? Data(contentsOf: cacheURL),
           let list = decode(data), !list.isEmpty {
            return list
        }
        let url = URL(string: "https://ll.thespacedevs.com/2.3.0/launches/upcoming/?limit=10&hide_recent_previous=true")!
        guard let (data, _) = try? await URLSession.shared.data(from: url), let list = decode(data), !list.isEmpty else {
            if let data = try? Data(contentsOf: cacheURL) { return decode(data) }
            return nil
        }
        try? data.write(to: cacheURL)
        return list
    }

    private static func decode(_ data: Data) -> [LaunchSpec]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return nil }
        var list: [LaunchSpec] = []
        for (index, item) in results.enumerated() {
            let pad = item["pad"] as? [String: Any] ?? [:]
            let place = pad["location"] as? [String: Any] ?? [:]
            let mission = item["mission"] as? [String: Any] ?? [:]
            let lat = Double(pad["latitude"] as? String ?? "") ?? (pad["latitude"] as? Double ?? .nan)
            let lon = Double(pad["longitude"] as? String ?? "") ?? (pad["longitude"] as? Double ?? .nan)
            guard lat.isFinite, lon.isFinite else { continue }
            let fullName = item["name"] as? String ?? ""
            let rocket = fullName.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? ""
            let payload = (mission["name"] as? String) ?? fullName.components(separatedBy: "|").last?.trimmingCharacters(in: .whitespaces) ?? "Mission"
            let site = ((place["name"] as? String) ?? (pad["name"] as? String) ?? "").components(separatedBy: ",").first ?? ""
            let status = (item["status"] as? [String: Any])?["abbrev"] as? String ?? ""
            list.append(LaunchSpec(
                n: payload,
                meta: site + " · " + rocket,
                detail: mission["description"] as? String ?? "",
                lat: lat, lon: lon,
                iso: item["net"] as? String,
                status: status,
                color: launchColors[index % launchColors.count]
            ))
        }
        return list
    }
}
