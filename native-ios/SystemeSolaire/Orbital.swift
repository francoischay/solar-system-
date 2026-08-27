import Foundation
import simd

// Port direct du moteur du prototype HTML : mêmes unités, mêmes constantes.
// Les distances sont compressées en log (sceneRadius) ; la direction reste exacte.

enum Astro {
    static let DEG = Double.pi / 180
    static let TAU = Double.pi * 2
    /// 2000-01-01T12:00Z en secondes Unix
    static let j2000Epoch: TimeInterval = 946_728_000

    static var todayDay: Double { (Date().timeIntervalSince1970 - j2000Epoch) / 86_400 }

    static func date(fromDay day: Double) -> Date {
        Date(timeIntervalSince1970: j2000Epoch + day * 86_400)
    }

    static func day(from date: Date) -> Double {
        (date.timeIntervalSince1970 - j2000Epoch) / 86_400
    }

    private static var utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Année décimale pour un jour depuis J2000
    static func decimalYear(_ d: Double) -> Double {
        let date = Self.date(fromDay: d)
        let y = utcCalendar.component(.year, from: date)
        let start = utcCalendar.date(from: DateComponents(year: y, month: 1, day: 1))!
        let end = utcCalendar.date(from: DateComponents(year: y + 1, month: 1, day: 1))!
        return Double(y) + date.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    /// Jour depuis J2000 pour une année décimale
    static func dayForYear(_ year: Double) -> Double {
        let y = Int(floor(year))
        let start = utcCalendar.date(from: DateComponents(year: y, month: 1, day: 1))!
        let end = utcCalendar.date(from: DateComponents(year: y + 1, month: 1, day: 1))!
        let t = start.timeIntervalSince1970 + end.timeIntervalSince(start) * (year - Double(y))
        return (t - j2000Epoch) / 86_400
    }

    static func dayFromUTC(year: Int, month: Int, dayOfMonth: Int) -> Double {
        let d = utcCalendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
        return day(from: d)
    }

    /// Compression logarithmique : UA -> rayon de scène
    static func sceneRadius(au: Double) -> Double {
        12 + log1p(max(0, au)) / log1p(30.07) * 88
    }

    /// Temps sidéral de Greenwich (rad) pour un jour depuis J2000
    static func gmst(_ d: Double) -> Double {
        4.894961212735792 + 6.300388098984957 * d
    }

    // Voisinage terrestre : altitudes comprimées en log, cohérentes avec la Lune de la scène
    static let ORBIT_H = 400.0, MOON_KM = 384_400.0, EARTH_KM = 6371.0
    static let EARTH_RADIUS = 1.2   // taille de la Terre dans la scène
    static let MOON_SCENE_RADIUS = 3.1
    static let ORBIT_SCALE = (MOON_SCENE_RADIUS - EARTH_RADIUS) / log1p((MOON_KM - EARTH_KM) / ORBIT_H)

    static func orbitSceneRadius(km: Double) -> Double {
        EARTH_RADIUS + ORBIT_SCALE * log1p(max(0, km - EARTH_KM) / ORBIT_H)
    }

    /// lat/lon (degrés) -> repère local de la sphère (UV équirectangulaire de SCNSphere)
    static func geoToLocal(lat: Double, lon: Double, radius: Double) -> SIMD3<Double> {
        let phi = (lon + 180) * .pi / 180, theta = (90 - lat) * .pi / 180
        return SIMD3(-radius * cos(phi) * sin(theta), radius * cos(theta), radius * sin(phi) * sin(theta))
    }
}

// MARK: - Orbites planétaires (éléments képlériens J2000, JPL)

struct PlanetSpec {
    let name: String
    let a: Double       // demi-grand axe (UA)
    let p: Double       // période (années)
    let L: Double       // longitude moyenne (°)
    let peri: Double    // longitude du périhélie (°)
    let node: Double    // longitude du nœud ascendant (°)
    let inc: Double     // inclinaison (°)
    let e: Double       // excentricité
    let size: Double    // rayon dans la scène
    let color: UInt32
    let index: Int
}

let planetSpecs: [PlanetSpec] = [
    ("Mercure", 0.38709927, 0.2408467, 252.25032, 77.45780, 48.33077, 7.00498, 0.2056359, 0.8, 0xa8a2a4),
    ("Vénus", 0.72333566, 0.6151973, 181.97910, 131.60247, 76.67984, 3.39468, 0.0067767, 1.1, 0xe1c792),
    ("Terre", 1.00000261, 1.0000174, 100.46457, 102.93768, 0.0, 0.0, 0.0167112, 1.2, 0x62a8db),
    ("Mars", 1.52371034, 1.8808476, -4.55343, -23.94363, 49.55954, 1.84969, 0.0933941, 0.95, 0xc66d55),
    ("Jupiter", 5.20288700, 11.862615, 34.39644, 14.72848, 100.47391, 1.30440, 0.0483862, 2.8, 0xd9b68d),
    ("Saturne", 9.53667594, 29.447498, 49.95424, 92.59888, 113.66242, 2.48599, 0.0538618, 2.4, 0xdccaa2),
    ("Uranus", 19.18916464, 84.016846, 313.23810, 170.95428, 74.01693, 0.77264, 0.0472574, 1.8, 0xa2dce2),
    ("Neptune", 30.06992276, 164.79132, 304.87997, 44.96476, 131.78422, 1.77004, 0.0085905, 1.75, 0x677ed5),
].enumerated().map { i, b in
    PlanetSpec(name: b.0, a: b.1, p: b.2, L: b.3, peri: b.4, node: b.5, inc: b.6, e: b.7, size: b.8, color: b.9, index: i)
}

/// Orbite képlérienne : ellipse inclinée, orientée par son nœud et son périhélie.
/// Newton sur E − e·sin E = M ; direction exacte, distance comprimée.
func planetPosition(_ b: PlanetSpec, day d: Double) -> SIMD3<Double> {
    let years = d / 365.25
    let mean = (b.L + (360 * years) / b.p - b.peri) * Astro.DEG
    var E = mean + b.e * sin(mean)
    for _ in 0..<5 {
        E -= (E - b.e * sin(E) - mean) / (1 - b.e * cos(E))
    }
    let xv = b.a * (cos(E) - b.e)
    let yv = b.a * sqrt(1 - b.e * b.e) * sin(E)
    let trueAnomaly = atan2(yv, xv)
    let au = (xv * xv + yv * yv).squareRoot()
    let u = trueAnomaly + (b.peri - b.node) * Astro.DEG
    let node = b.node * Astro.DEG
    let inc = b.inc * Astro.DEG
    let scale = Astro.sceneRadius(au: au) / au
    return SIMD3(
        au * (cos(node) * cos(u) - sin(node) * sin(u) * cos(inc)) * scale,
        au * sin(u) * sin(inc) * scale,
        -au * (sin(node) * cos(u) + cos(node) * sin(u) * cos(inc)) * scale
    )
}

// MARK: - Sondes

struct MissionSpec {
    let n: String
    let status: String          // "active" | "historic"
    let color: UInt32
    let valid: String           // "1977–2030"
    var launch: Double? = nil
    /// [année décimale, UA, longitude écliptique (rad, non repliée), latitude écliptique (°)]
    var route: [[Double]]? = nil
    /// [UA min, UA max, phase, période (années)]
    var orbit: [Double]? = nil
    var parent: String? = nil
    /// [rayon scène, fréquence (tours/jour), phase]
    var local: [Double]? = nil
    /// Vol habité : trajectoire à l'échelle du jour, dans le voisinage terrestre
    var crewed: CrewedSpec? = nil
}

// MARK: - Vols habités

/// Les sondes se lisent à l'échelle de l'année ; un vol habité dure des jours,
/// parfois une heure et demie. Sa trajectoire est donc calculée dans le repère
/// de la Terre, au jour près, à partir du profil réel de la mission.
struct CrewedSpec {
    /// jour J2000 du décollage (UTC)
    let launchDay: Double
    /// durée de la mission, en jours
    let days: Double
    let profile: CrewedProfile
    /// équipage affiché sous le nom
    let crew: String
}

enum CrewedProfile {
    /// Orbite terrestre : altitude (km), période (minutes), inclinaison (°).
    /// La trace ne montre que la dernière révolution — les suivantes se
    /// superposeraient exactement à celle-là.
    case earthOrbit(altitude: Double, period: Double, inclination: Double)
    /// Vol lunaire. `outbound` / `around` / `inbound` sont les durées réelles en
    /// jours des trois temps du voyage ; `loops` le nombre de révolutions
    /// *dessinées* autour de la Lune (0,5 pour un survol en retour libre) —
    /// tracer les trente orbites d'Apollo 11 donnerait un gribouillis.
    /// `periluneKm` fixe l'altitude du passage au plus près.
    case lunar(outbound: Double, around: Double, inbound: Double, loops: Double, periluneKm: Double)
}

enum Crewed {
    /// Orbite de parking avant l'injection translunaire (Apollo : 185 km, 32,5°)
    static let PARKING_KM = 6371.0 + 185
    static let PARKING_INCLINATION = 32.5 * Astro.DEG
    static let PARKING_PERIOD = 88.2 / 1440       // jours
    /// Interface de rentrée : 122 km d'altitude
    static let ENTRY_KM = 6371.0 + 122
    /// Rayon de la Lune telle que la scène la dessine
    static var moonSize: Double { moonSpecs["Terre"]?.first?.size ?? 0.42 }
}

/// Point d'une orbite circulaire inclinée, dans le repère de son primaire.
func inclinedCircle(radius: Double, angle: Double, inclination: Double, node: Double) -> SIMD3<Double> {
    let x = cos(angle), z = sin(angle)
    // basculement du plan orbital, puis rotation du nœud ascendant
    let y2 = -z * sin(inclination), z2 = z * cos(inclination)
    return SIMD3(
        (x * cos(node) + z2 * sin(node)) * radius,
        y2 * radius,
        (-x * sin(node) + z2 * cos(node)) * radius
    )
}

/// Position de la Lune dans le repère de la Terre, telle que la scène la place.
/// Une trajectoire lunaire doit viser la Lune *de la scène*, pas l'éphéméride —
/// sinon la capsule arrive là où il n'y a rien.
func earthMoonLocalPosition(day d: Double) -> SIMD3<Double> {
    guard let moon = moonSpecs["Terre"]?.first else { return SIMD3(Astro.MOON_SCENE_RADIUS, 0, 0) }
    return moonLocalPosition(phase: 0, period: moon.period, radius: moon.radius, day: d)
}

/// Balayage angulaire d'une croisière translunaire : l'essentiel de l'angle est
/// fait tôt, près du périgée, puis la capsule monte presque radialement. Une
/// puissance fractionnaire donnerait la bonne allure mais une pente infinie au
/// raccord — le tracé partirait d'un coup de fouet. Cette parabole est
/// front-loaded et se raccorde proprement des deux côtés.
private func coastSweep(_ u: Double) -> Double {
    let t = max(0, min(1, u))
    return t * (2 - t)
}

/// Interpolation sur la sphère : la direction tourne à vitesse constante.
private func slerpDirection(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double) -> SIMD3<Double> {
    let ua = simd_normalize(a), ub = simd_normalize(b)
    let dot = max(-1, min(1, simd_dot(ua, ub)))
    let omega = acos(dot)
    if omega < 1e-4 { return simd_normalize(ua + (ub - ua) * t) }
    let s = sin(omega)
    return ua * (sin((1 - t) * omega) / s) + ub * (sin(t * omega) / s)
}

/// Rayon de scène pendant la croisière translunaire. Apollo 11 a franchi la
/// moitié de la distance Terre-Lune vingt-quatre heures après l'injection, sur
/// les soixante-treize du trajet : la capsule s'arrache, puis rampe. Sur l'axe
/// comprimé de la scène, cela revient à avoir fait 89 % du chemin au tiers du
/// temps — d'où l'exposant. Une loi en t^(2/3), plus juste en kilomètres, aurait
/// une pente infinie au décollage et couperait le tracé net au raccord.
private func coastRadius(_ u: Double, from rStart: Double, to rEnd: Double) -> Double {
    let progress = 1 - pow(1 - max(0, min(1, u)), 5.4)
    return rStart + (rEnd - rStart) * progress
}

/// Découpage du tracé d'un vol lunaire. Le temps ne se découpe pas en tranches
/// égales : l'orbite de parking boucle en quatre-vingt-huit minutes et les
/// boucles lunaires en deux heures, tandis que la croisière ne bouge presque
/// plus pendant trois jours. À pas constant, le parking d'Apollo 17 n'attrape
/// que trois points sur les sept cent vingt du tracé — un triangle collé à la
/// Terre. Chaque phase reçoit donc son quota de points.
private func crewedPhases(_ c: CrewedSpec) -> [(weight: Double, days: Double)] {
    guard case .lunar(let outbound, let around, let inbound, let loops, _) = c.profile else {
        return [(1, c.days)]
    }
    let park = max(0.02, c.days - (outbound + around + inbound))
    return [(110, park), (190, outbound), (max(40, loops * 70), around), (190, inbound)]
}

/// Jour de la mission pour une fraction `k` du tracé (0 = décollage, 1 = fin).
func crewedSampleDay(_ c: CrewedSpec, at k: Double) -> Double {
    let phases = crewedPhases(c)
    let total = phases.reduce(0) { $0 + $1.weight }
    var remaining = max(0, min(1, k)) * total
    var day = c.launchDay
    for phase in phases {
        if remaining <= phase.weight {
            return day + phase.days * (remaining / phase.weight)
        }
        remaining -= phase.weight
        day += phase.days
    }
    return c.launchDay + c.days
}

/// L'inverse : où en est le tracé à une date donnée. La mission n'est pas
/// toujours finie quand on la regarde — le tracé s'arrête au jour courant.
func crewedSampleProgress(_ c: CrewedSpec, day d: Double) -> Double {
    let phases = crewedPhases(c)
    let total = phases.reduce(0) { $0 + $1.weight }
    var elapsed = max(0, min(c.days, d - c.launchDay))
    var done = 0.0
    for phase in phases {
        if elapsed <= phase.days {
            return (done + phase.weight * (elapsed / max(1e-9, phase.days))) / total
        }
        elapsed -= phase.days
        done += phase.weight
    }
    return 1
}

/// Position d'un vaisseau habité, dans le repère de la Terre.
func crewedLocalPosition(_ c: CrewedSpec, day d: Double) -> SIMD3<Double> {
    let t = max(0, min(c.days, d - c.launchDay))
    switch c.profile {
    case .earthOrbit(let altitude, let period, let inclination):
        let radius = Astro.orbitSceneRadius(km: 6371 + altitude)
        let angle = t / (period / 1440) * Astro.TAU
        return inclinedCircle(radius: radius, angle: angle,
                              inclination: inclination * Astro.DEG, node: 0.9)

    case .lunar(let outbound, let around, let inbound, let loops, let periluneKm):
        let park = max(0.02, c.days - (outbound + around + inbound))
        let rPark = Astro.orbitSceneRadius(km: Crewed.PARKING_KM)
        let rEntry = Astro.orbitSceneRadius(km: Crewed.ENTRY_KM)
        // Le plan de l'orbite lunaire est celui du plan de vol : incliné sur le
        // plan Terre-Lune, ce qui fait passer la boucle derrière la Lune.
        // La Lune de la scène est dessinée trente fois trop grosse : mettre la
        // boucle à l'échelle réelle la ferait passer sous la surface. L'altitude
        // est donc comprimée en log, comme partout ailleurs — Apollo rase la
        // Lune, Artemis passe visiblement au large.
        let lunarRadius = Crewed.moonSize + 0.13 * log1p(periluneKm / 500)
        let entryAngle = 0.0, exitAngle = loops * Astro.TAU
        let arrivalDay = c.launchDay + park + outbound
        let departureDay = arrivalDay + around

        func lunarOffset(_ angle: Double) -> SIMD3<Double> {
            inclinedCircle(radius: lunarRadius, angle: angle, inclination: 1.05, node: 2.4)
        }
        // Injection translunaire : dernier point de l'orbite de parking
        let tliAngle = park / Crewed.PARKING_PERIOD * Astro.TAU
        let tli = inclinedCircle(radius: rPark, angle: tliAngle,
                                 inclination: Crewed.PARKING_INCLINATION, node: 0.35)

        if t < park {
            let angle = t / Crewed.PARKING_PERIOD * Astro.TAU
            return inclinedCircle(radius: rPark, angle: angle,
                                  inclination: Crewed.PARKING_INCLINATION, node: 0.35)
        }
        if t < park + outbound {
            let u = (t - park) / max(1e-6, outbound)
            let target = earthMoonLocalPosition(day: arrivalDay) + lunarOffset(entryAngle)
            // La direction balaie vite (l'essentiel de l'angle est fait près du
            // périgée), le rayon suit la loi de chute : d'abord un coup de reins,
            // puis une longue montée presque radiale.
            let dir = slerpDirection(tli, target, coastSweep(u))
            return dir * coastRadius(u, from: rPark, to: simd_length(target))
        }
        if t < park + outbound + around {
            let v = (t - park - outbound) / max(1e-6, around)
            return earthMoonLocalPosition(day: c.launchDay + t)
                + lunarOffset(entryAngle + (exitAngle - entryAngle) * v)
        }
        let u = (t - park - outbound - around) / max(1e-6, inbound)
        let start = earthMoonLocalPosition(day: departureDay) + lunarOffset(exitAngle)
        // Retour : la Terre a tourné, le point de rentrée n'est pas celui du départ
        let splash = inclinedCircle(radius: rEntry, angle: tliAngle - 0.55,
                                    inclination: Crewed.PARKING_INCLINATION, node: 0.35)
        // Retour : le miroir de l'aller — l'angle s'accélère en tombant vers la Terre
        let dir = slerpDirection(start, splash, 1 - coastSweep(1 - u))
        return dir * coastRadius(1 - u, from: rEntry, to: simd_length(start))
    }
}

struct MissionYears { let start: Double; let end: Double }

func missionYears(_ m: MissionSpec) -> MissionYears {
    // Un vol habité porte ses dates réelles dans `valid` : les chiffres du jour
    // et du mois y traîneraient dans le même panier que l'année.
    if let c = m.crewed {
        return MissionYears(start: Astro.decimalYear(c.launchDay),
                            end: Astro.decimalYear(c.launchDay + c.days))
    }
    let years = m.valid.split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }
    let start = m.launch ?? m.route?.first?[0] ?? years.first ?? 2000
    let end = years.count > 1 ? years[1] : (years.first ?? 2000)
    return MissionYears(start: start, end: end)
}

func missionIsValid(_ m: MissionSpec, day d: Double) -> Bool {
    // Un vol habité se joue au jour près : lui accorder l'année entière comme
    // aux sondes le laisserait planté dans le ciel six mois après l'amerrissage.
    if let c = m.crewed { return d >= c.launchDay && d <= c.launchDay + c.days }
    let y = Astro.decimalYear(d), limits = missionYears(m)
    return y >= limits.start && y <= limits.end + 1
}

/// Bornes d'une mission en jours J2000. Les sondes se calent sur l'année, les
/// vols habités sur leurs dates réelles.
func missionDayRange(_ m: MissionSpec) -> (first: Double, last: Double) {
    if let c = m.crewed { return (c.launchDay, c.launchDay + c.days) }
    let years = missionYears(m)
    return (Astro.dayForYear(years.start), Astro.dayForYear(years.end + 1) - 1)
}

/// Position d'une sonde. `parentPosition` : position de la planète parente si m.parent est défini.
func missionPosition(_ m: MissionSpec, day d: Double, parentPosition: SIMD3<Double>?) -> SIMD3<Double> {
    if let c = m.crewed {
        return (parentPosition ?? SIMD3()) + crewedLocalPosition(c, day: d)
    }
    let limits = missionYears(m)
    let y = max(limits.start, min(limits.end, Astro.decimalYear(d)))
    if let local = m.local, let p = parentPosition {
        let a = d * local[1] * Astro.TAU + local[2]
        return SIMD3(p.x + cos(a) * local[0], sin(a * 0.7) * 1.2, p.z + sin(a) * local[0])
    }
    var au = 0.0, angle = 0.0
    var latitude: Double? = nil
    if let route = m.route {
        var i = 0
        for k in 0..<(route.count - 1) where y >= route[k][0] && y <= route[k + 1][0] { i = k; break }
        if y > route[route.count - 1][0] { i = route.count - 2 }
        let p0 = route[max(0, i - 1)], p1 = route[i], p2 = route[i + 1], p3 = route[min(route.count - 1, i + 2)]
        let u = max(0, min(1, (y - p1[0]) / (p2[0] - p1[0] == 0 ? 1 : p2[0] - p1[0])))
        // Catmull-Rom sur chaque composante : jonctions lissées entre points de passage
        func spline(_ c: Int) -> Double {
            let a0 = p0.count > c ? p0[c] : 0, a1 = p1.count > c ? p1[c] : 0
            let a2 = p2.count > c ? p2[c] : 0, a3 = p3.count > c ? p3[c] : 0
            return 0.5 * ((2 * a1) + (a2 - a0) * u + (2 * a0 - 5 * a1 + 4 * a2 - a3) * u * u + (3 * a1 - a0 - 3 * a2 + a3) * u * u * u)
        }
        func clamp(_ v: Double, _ c: Int) -> Double {
            let v1 = p1.count > c ? p1[c] : 0, v2 = p2.count > c ? p2[c] : 0
            return max(min(v1, v2), min(max(v1, v2), v))
        }
        au = clamp(spline(1), 1); angle = spline(2)
        latitude = clamp(spline(3), 3) * .pi / 180
    } else if let orbit = m.orbit {
        let phase = (y - 2000) * Astro.TAU / orbit[3] + orbit[2]
        let mid = (orbit[0] + orbit[1]) / 2, amp = (orbit[1] - orbit[0]) / 2
        au = mid - amp * cos(phase); angle = phase
    }
    let r = Astro.sceneRadius(au: au)
    guard let lat = latitude else {
        // sondes sans trajectoire détaillée : léger dévers pour ne pas être plates
        let tilt = sin(angle * 0.63 + Double(m.n.count)) * min(8, r * 0.1)
        return SIMD3(cos(angle) * r, tilt, -sin(angle) * r)
    }
    let flat = cos(lat) * r // latitude écliptique réelle : la sortie du plan se voit
    return SIMD3(cos(angle) * flat, sin(lat) * r, -sin(angle) * flat)
}

// MARK: - Lunes

struct MoonSpec {
    let name: String
    let radius: Double  // rayon d'orbite dans la scène
    let size: Double
    let color: UInt32
    let period: Double  // période réelle en jours (négative = rétrograde)
}

let moonSpecs: [String: [MoonSpec]] = [
    "Terre": [MoonSpec(name: "Lune", radius: 3.1, size: 0.42, color: 0xc9cfdf, period: 27.32)],
    "Mars": [
        MoonSpec(name: "Phobos", radius: 2, size: 0.18, color: 0x9c887a, period: 0.319),
        MoonSpec(name: "Deimos", radius: 2.7, size: 0.13, color: 0xa99b91, period: 1.263),
    ],
    "Jupiter": [
        MoonSpec(name: "Io", radius: 4, size: 0.28, color: 0xe2c17e, period: 1.769),
        MoonSpec(name: "Europe", radius: 5.1, size: 0.25, color: 0xd8d2bd, period: 3.551),
        MoonSpec(name: "Ganymède", radius: 6.3, size: 0.34, color: 0xaaa092, period: 7.155),
        MoonSpec(name: "Callisto", radius: 7.6, size: 0.32, color: 0x80776e, period: 16.689),
    ],
    "Saturne": [
        MoonSpec(name: "Mimas", radius: 4, size: 0.16, color: 0xd8d8d2, period: 0.942),
        MoonSpec(name: "Encelade", radius: 4.8, size: 0.18, color: 0xe8eef2, period: 1.37),
        MoonSpec(name: "Téthys", radius: 5.6, size: 0.21, color: 0xd7d5ce, period: 1.888),
        MoonSpec(name: "Dioné", radius: 6.5, size: 0.21, color: 0xbfbdb7, period: 2.737),
        MoonSpec(name: "Rhéa", radius: 7.5, size: 0.26, color: 0xa9a59f, period: 4.518),
        MoonSpec(name: "Titan", radius: 9, size: 0.38, color: 0xd49f54, period: 15.945),
        MoonSpec(name: "Japet", radius: 10.5, size: 0.23, color: 0x8c8175, period: 79.32),
    ],
    "Uranus": [
        MoonSpec(name: "Miranda", radius: 3, size: 0.15, color: 0xc9cbd0, period: 1.413),
        MoonSpec(name: "Ariel", radius: 4, size: 0.2, color: 0xd9d9d4, period: 2.52),
        MoonSpec(name: "Umbriel", radius: 5, size: 0.2, color: 0x7c7a79, period: 4.144),
        MoonSpec(name: "Titania", radius: 6.2, size: 0.25, color: 0xb9afa5, period: 8.706),
        MoonSpec(name: "Obéron", radius: 7.4, size: 0.24, color: 0x8f8984, period: 13.463),
    ],
    "Neptune": [
        MoonSpec(name: "Protée", radius: 3, size: 0.18, color: 0x85827e, period: 1.122),
        MoonSpec(name: "Triton", radius: 5, size: 0.32, color: 0xbec3ca, period: -5.877),
        MoonSpec(name: "Néréide", radius: 7, size: 0.16, color: 0x9e9fa3, period: 360.14),
    ],
]

func moonAngle(phase: Double, period: Double, day d: Double) -> Double {
    phase + (d / period) * Astro.TAU
}

func moonLocalPosition(phase: Double, period: Double, radius: Double, day d: Double) -> SIMD3<Double> {
    let a = moonAngle(phase: phase, period: period, day: d)
    return SIMD3(cos(a) * radius, sin(a * 0.7) * 0.18, sin(a) * radius)
}
