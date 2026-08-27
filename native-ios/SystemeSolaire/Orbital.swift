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
    /// Inclinaison de l'axe terrestre. Le moteur oriente le globe avec ;
    /// une trajectoire qui part d'un pas de tir en a besoin aussi.
    static let earthTilt = simd_quatd(angle: -23.44 * Double.pi / 180, axis: SIMD3(1, 0, 0))
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
    /// le vrai pas de tir : c'est de là que part la trajectoire
    let site: LaunchSite
    /// inclinaison de l'orbite initiale (°). Elle ne peut pas être inférieure à
    /// la latitude du pas de tir — on ne lance pas vers le sud de l'équateur
    /// depuis la Floride.
    let inclination: Double
    let profile: CrewedProfile
    /// équipage affiché sous le nom
    let crew: String
}

struct LaunchSite {
    let name: String
    let lat: Double
    let lon: Double
}

enum CrewedProfile {
    /// Orbite terrestre : altitude (km), période (minutes).
    /// La trace ne montre que la dernière révolution — les suivantes se
    /// superposeraient exactement à celle-là.
    case earthOrbit(altitude: Double, period: Double)
    /// Vol lunaire. `outbound` / `around` / `inbound` sont les durées réelles en
    /// jours des trois temps du voyage ; `loops` le nombre de révolutions
    /// *dessinées* autour de la Lune (0,5 pour un survol en retour libre) —
    /// tracer les trente orbites d'Apollo 11 donnerait un gribouillis.
    /// `periluneKm` fixe l'altitude du passage au plus près.
    case lunar(outbound: Double, around: Double, inbound: Double, loops: Double, periluneKm: Double)
}

enum Crewed {
    /// Orbite de parking avant l'injection translunaire (Apollo : 185 km)
    static let PARKING_KM = 6371.0 + 185
    static let PARKING_PERIOD = 88.2 / 1440       // jours
    /// Interface de rentrée : 122 km d'altitude
    static let ENTRY_KM = 6371.0 + 122
    /// Angle parcouru au sol pendant l'ascension. Un lanceur bascule vite mais ne
    /// fait pas un quart de tour avant d'être en orbite. C'est aussi le point où
    /// le déroulé de la mission reprend : l'ascension et l'orbite doivent se
    /// raccorder sur le même point, sinon la capsule saute au passage de relais.
    static let ASCENT_DOWNRANGE = 0.42
    /// Révolutions terrestres *dessinées* au plus, quelle que soit la durée du
    /// vol. Essayé sans : Apollo-Soyouz en boucle cent quarante-sept, soit quatre
    /// tours et demi par seconde — un stroboscope, pas un vol. Et elles repassent
    /// exactement par le même cercle, donc on ne perd rien à les plafonner. Même
    /// principe que les boucles lunaires : le tracé est un dessin, la durée réelle
    /// est portée par la date.
    static let MAX_ORBIT_LOOPS = 6.0
    /// Rayon de la Lune telle que la scène la dessine
    static var moonSize: Double { moonSpecs["Terre"]?.first?.size ?? 0.42 }
}

/// Repère de l'orbite initiale, déduit du pas de tir et de la date de tir.
/// `u` pointe vers le pas de tir à l'instant du décollage, `v` vers là où le
/// lanceur file. L'azimut de tir vient de la relation classique
/// cos i = cos φ · sin A : c'est elle qui fait qu'on tire plein est depuis la
/// Floride pour une orbite à 28°, et vers le nord-est depuis Baïkonour.
/// La trajectoire part donc du vrai pas de tir, et l'ascension s'y raccorde.
func crewedFrame(_ c: CrewedSpec) -> (u: SIMD3<Double>, v: SIMD3<Double>) {
    let spin = simd_quatd(angle: Astro.gmst(c.launchDay), axis: SIMD3(0, 1, 0))
    let toScene = Astro.earthTilt * spin
    let u = simd_normalize(toScene.act(Astro.geoToLocal(lat: c.site.lat, lon: c.site.lon, radius: 1)))
    let north = simd_normalize(Astro.earthTilt.act(SIMD3(0, 1, 0)))
    var east = simd_cross(north, u)
    if simd_length_squared(east) < 1e-9 { east = simd_cross(SIMD3(1, 0, 0), u) }
    east = simd_normalize(east)
    let localNorth = simd_normalize(simd_cross(u, east))
    let cosPhi = max(1e-6, cos(c.site.lat * Astro.DEG))
    let sinAzimuth = max(-1, min(1, cos(c.inclination * Astro.DEG) / cosPhi))
    let azimuth = asin(sinAzimuth)
    return (u, simd_normalize(east * sin(azimuth) + localNorth * cos(azimuth)))
}

/// Durée de l'ascension, en jours de mission. Elle vaut exactement le temps que
/// met l'orbite initiale à parcourir `ASCENT_DOWNRANGE` : la montée débouche
/// donc sur l'orbite au bon endroit *et* au bon instant, sans raccord à négocier.
func crewedAscentDays(_ c: CrewedSpec) -> Double {
    let period: Double = {
        if case .earthOrbit(_, let p) = c.profile { return p / 1440 }
        return Crewed.PARKING_PERIOD
    }()
    return Crewed.ASCENT_DOWNRANGE / Astro.TAU * period
}

/// Point de l'orbite initiale, `angle` compté depuis le pas de tir.
func crewedOrbitPoint(_ c: CrewedSpec, radius: Double, angle: Double) -> SIMD3<Double> {
    let frame = crewedFrame(c)
    return (frame.u * cos(angle) + frame.v * sin(angle)) * radius
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
    return moonLocalPosition(moon, phase: 0, radius: moon.radius, day: d)
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
    let ascentDays = crewedAscentDays(c)
    guard case .lunar(let outbound, let around, let inbound, let loops, _) = c.profile else {
        // L'ascension a son propre quota : partagée au prorata de sa durée, une
        // montée de six minutes n'attraperait qu'un point sur un vol de neuf jours.
        return [(70, ascentDays), (400, max(0, c.days - ascentDays))]
    }
    let park = max(0.02, c.days - (outbound + around + inbound))
    // L'orbite de parking pèse plus lourd que sa durée : une révolution et demie
    // en quatre secondes se lisait comme une accélération brutale juste après
    // l'ascension. Elle a maintenant le temps de se voir.
    return [(70, ascentDays), (165, max(0, park - ascentDays)), (190, outbound),
            (max(40, loops * 70), around), (190, inbound)]
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

// MARK: Jalons

/// Un temps fort de la mission : ce que le cartouche annonce, et ce que la main
/// sent. Un vol habité n'est pas une courbe continue mais une suite d'allumages.
struct CrewedBeat {
    let day: Double
    let label: String
    let kind: Kind
    enum Kind {
        case liftoff    // décollage
        case burn       // allumage franc : TLI, TEI, désorbitation
        case brake      // freinage : mise en orbite lunaire
        case coast      // rien à sentir, on change juste de chapitre
        case splashdown // retour au sol ou à la mer
    }
}

/// Le découpage d'une mission en chapitres, aux dates réelles de ses manœuvres.
func crewedBeats(_ c: CrewedSpec) -> [CrewedBeat] {
    let start = c.launchDay
    switch c.profile {
    case .earthOrbit(_, let period):
        let deorbit = start + max(0, c.days - period / 1440 * 0.75)
        return [
            CrewedBeat(day: start, label: "Décollage", kind: .liftoff),
            CrewedBeat(day: start + 0.006, label: "En orbite", kind: .coast),
            CrewedBeat(day: deorbit, label: "Désorbitation", kind: .burn),
            CrewedBeat(day: start + c.days, label: "Retour", kind: .splashdown),
        ]
    case .lunar(let outbound, let around, let inbound, let loops, _):
        let park = max(0.02, c.days - (outbound + around + inbound))
        let flyby = loops <= 0.75
        return [
            CrewedBeat(day: start, label: "Décollage", kind: .liftoff),
            CrewedBeat(day: start + 0.006, label: "Orbite de parking", kind: .coast),
            CrewedBeat(day: start + park, label: "Injection translunaire", kind: .burn),
            CrewedBeat(day: start + park + outbound,
                       label: flyby ? "Survol de la Lune" : "Mise en orbite lunaire",
                       kind: flyby ? .coast : .brake),
            CrewedBeat(day: start + park + outbound + around,
                       label: flyby ? "Retour libre" : "Injection trans-Terre",
                       kind: flyby ? .coast : .burn),
            CrewedBeat(day: start + c.days, label: "Amerrissage", kind: .splashdown),
        ]
    }
}

/// Position d'un vaisseau habité, dans le repère de la Terre.
func crewedLocalPosition(_ c: CrewedSpec, day d: Double) -> SIMD3<Double> {
    let t = max(0, min(c.days, d - c.launchDay))
    let orbitRadius: Double = {
        if case .earthOrbit(let altitude, _) = c.profile {
            return Astro.orbitSceneRadius(km: 6371 + altitude)
        }
        return Astro.orbitSceneRadius(km: Crewed.PARKING_KM)
    }()
    // Ascension. La trajectoire d'un vol habité part du sol, au vrai pas de tir :
    // c'est une seule courbe du décollage au retour, pas une trajectoire orbitale
    // à laquelle on aurait recollé un lancement.
    let ascent = crewedAscentDays(c)
    if t < ascent {
        let u = t / ascent
        // Vertical d'abord, basculement ensuite : l'altitude monte vite, la
        // distance au sol se rattrape en fin de course.
        return crewedOrbitPoint(
            c,
            radius: Astro.EARTH_RADIUS + (orbitRadius - Astro.EARTH_RADIUS) * pow(u, 0.62),
            angle: Crewed.ASCENT_DOWNRANGE * pow(u, 1.9)
        )
    }
    switch c.profile {
    case .earthOrbit(_, let period):
        // Sous le plafond — Vostok 1 et son unique tour, Friendship 7 et ses
        // trois — la cadence reste exacte. Au-dessus, elle est étalée.
        let span = max(1e-9, c.days - ascent)
        let loops = min(span / (period / 1440), Crewed.MAX_ORBIT_LOOPS)
        return crewedOrbitPoint(
            c, radius: orbitRadius,
            angle: Crewed.ASCENT_DOWNRANGE + (t - ascent) / span * loops * Astro.TAU
        )

    case .lunar(let outbound, let around, let inbound, let loops, let periluneKm):
        let park = max(0.02, c.days - (outbound + around + inbound))
        let rPark = orbitRadius
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
        let tli = crewedOrbitPoint(c, radius: rPark, angle: tliAngle)

        if t < park {
            return crewedOrbitPoint(c, radius: rPark, angle: t / Crewed.PARKING_PERIOD * Astro.TAU)
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
        let splash = crewedOrbitPoint(c, radius: rEntry, angle: tliAngle - 0.55)
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
    /// Seule la Lune a une éphéméride : c'est la seule dont on puisse vérifier
    /// la position à l'œil nu, un soir, depuis un jardin.
    var hasEphemeris: Bool { name == "Lune" }
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

/// Longitude et latitude écliptiques géocentriques de la Lune, en degrés.
/// Série tronquée de Meeus (*Astronomical Algorithms*, ch. 47) : les dix-huit
/// plus gros termes en longitude, les dix plus gros en latitude, soit environ
/// 0,3° — de quoi faire tomber les nouvelles lunes au bon jour et aligner les
/// éclipses, ce qu'un angle uniforme ne peut pas faire.
///
/// La latitude compte autant que la longitude : l'orbite est inclinée de 5,14°,
/// et c'est le passage de la Lune par un nœud qui décide s'il y a éclipse ou
/// simple nouvelle lune. Sans elle, la Lune couperait le plan à chaque tour.
func moonEcliptic(day d: Double) -> (lon: Double, lat: Double, km: Double) {
    let t = d / 36525
    let t2 = t * t
    let lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t2  // longitude moyenne
    let dd = 297.8501921 + 445267.1114034 * t - 0.0018819 * t2   // élongation moyenne
    let m  = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2    // anomalie du Soleil
    let mp = 134.9633964 + 477198.8675055 * t + 0.0087414 * t2   // anomalie de la Lune
    let f  =  93.2720950 + 483202.0175233 * t - 0.0036539 * t2   // argument de latitude
    func s(_ deg: Double) -> Double { sin(deg * Astro.DEG) }

    let lon = lp
        + 6.288774 * s(mp)
        + 1.274027 * s(2 * dd - mp)
        + 0.658314 * s(2 * dd)
        + 0.213618 * s(2 * mp)
        - 0.185116 * s(m)
        - 0.114332 * s(2 * f)
        + 0.058793 * s(2 * dd - 2 * mp)
        + 0.057066 * s(2 * dd - m - mp)
        + 0.053322 * s(2 * dd + mp)
        + 0.045758 * s(2 * dd - m)
        - 0.040923 * s(m - mp)
        - 0.034720 * s(dd)
        - 0.030383 * s(m + mp)
        + 0.015327 * s(2 * dd - 2 * f)
        - 0.012528 * s(mp + 2 * f)
        + 0.010980 * s(mp - 2 * f)
        + 0.010675 * s(4 * dd - mp)
        + 0.010034 * s(3 * mp)

    let lat = 5.128122 * s(f)
        + 0.280602 * s(mp + f)
        + 0.277693 * s(mp - f)
        + 0.173237 * s(2 * dd - f)
        + 0.055413 * s(2 * dd - mp + f)
        + 0.046271 * s(2 * dd - mp - f)
        + 0.032573 * s(2 * dd + f)
        + 0.017198 * s(2 * mp + f)
        + 0.009266 * s(2 * dd + mp - f)
        + 0.008822 * s(2 * mp - f)

    // Distance : c'est elle qui décide de la taille de l'ombre, et si l'éclipse
    // est totale ou annulaire — le cône d'ombre n'atteint pas toujours le sol.
    func c(_ deg: Double) -> Double { cos(deg * Astro.DEG) }
    let km = 385_000.56
        - 20905.355 * c(mp)
        - 3699.111 * c(2 * dd - mp)
        - 2955.968 * c(2 * dd)
        - 569.925 * c(2 * mp)
        + 246.158 * c(2 * dd - 2 * mp)
        - 204.586 * c(2 * dd - m)
        - 170.733 * c(2 * dd + mp)
        - 152.138 * c(2 * dd - m - mp)
        - 129.620 * c(m - mp)
        + 108.743 * c(dd)
        + 104.755 * c(m + mp)
        + 79.661 * c(mp - 2 * f)
        + 48.888 * c(m)
        + 10.321 * c(2 * dd - 2 * f)

    return (lon.truncatingRemainder(dividingBy: 360), lat, km)
}

/// Longitude écliptique géocentrique du Soleil et sa distance, en degrés et en
/// kilomètres. La scène a déjà une Terre képlérienne, mais elle rend une
/// position *comprimée en log* : pour une ombre, il faut les vraies unités.
func sunEcliptic(day d: Double) -> (lon: Double, km: Double) {
    let t = d / 36525
    let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
    let e = 0.016708634 - 0.000042037 * t
    let mr = m * Astro.DEG
    let c = (1.914602 - 0.004817 * t) * sin(mr)
        + (0.019993 - 0.000101 * t) * sin(2 * mr)
        + 0.000289 * sin(3 * mr)
    let nu = mr + c * Astro.DEG
    let r = 1.000001018 * (1 - e * e) / (1 + e * cos(nu))
    return ((l0 + c).truncatingRemainder(dividingBy: 360), r * 149_597_870.7)
}

/// Ombre d'une éclipse de Soleil, dans les vraies unités.
///
/// L'axe d'ombre est la droite qui part du centre du Soleil et passe par le
/// centre de la Lune. Là où elle perce le globe, il fait nuit en plein jour.
/// Si elle le manque, il n'y a pas d'éclipse centrale — au mieux une partielle
/// quelque part, qu'on ne dessine pas.
///
/// Les deux rayons sont ceux des cônes à cette distance : la pénombre s'ouvre,
/// l'ombre se referme. Quand l'ombre se referme *avant* d'arriver au sol, son
/// rayon devient négatif : l'éclipse est annulaire, un anneau de Soleil reste
/// visible. On garde alors sa valeur absolue, et `annulaire` le dit.
struct EclipseShadow {
    let lat: Double, lon: Double       // degrés, coordonnées géographiques
    let umbraKm: Double                // rayon de l'ombre au sol
    let penumbraKm: Double             // rayon de la pénombre au sol
    let annular: Bool
}

func solarEclipse(day d: Double) -> EclipseShadow? {
    let sunRadiusKm = 696_000.0, moonRadiusKm = 1737.4, earthRadiusKm = 6378.14

    let sun = sunEcliptic(day: d)
    let moon = moonEcliptic(day: d)
    let sl = sun.lon * Astro.DEG
    let ml = moon.lon * Astro.DEG, mb = moon.lat * Astro.DEG

    // Repère écliptique géocentrique rectangulaire, en km
    let s = SIMD3(cos(sl), sin(sl), 0.0) * sun.km
    let mo = SIMD3(cos(mb) * cos(ml), cos(mb) * sin(ml), sin(mb)) * moon.km

    let axis = mo - s
    let dsm = simd_length(axis)
    guard dsm > 0 else { return nil }
    let u = axis / dsm

    // Intersection de l'axe avec le globe : la racine la plus proche du Soleil
    let b = simd_dot(mo, u)
    let disc = b * b - (simd_dot(mo, mo) - earthRadiusKm * earthRadiusKm)
    guard disc >= 0 else { return nil }
    let t = -b - disc.squareRoot()
    guard t > 0 else { return nil }
    let p = mo + u * t

    // Rayons des cônes à la distance parcourue depuis la Lune
    let umbra = moonRadiusKm - t * (sunRadiusKm - moonRadiusKm) / dsm
    let penumbra = moonRadiusKm + t * (sunRadiusKm + moonRadiusKm) / dsm

    // Écliptique -> équatorial, puis on retranche le temps sidéral
    let eps = 23.4393 * Astro.DEG
    let xe = p.x
    let ye = p.y * cos(eps) - p.z * sin(eps)
    let ze = p.y * sin(eps) + p.z * cos(eps)
    let r = simd_length(SIMD3(xe, ye, ze))
    let lat = asin(ze / r) / Astro.DEG
    var lon = (atan2(ye, xe) - Astro.gmst(d)) / Astro.DEG
    lon = lon.truncatingRemainder(dividingBy: 360)
    if lon > 180 { lon -= 360 }
    if lon < -180 { lon += 360 }

    return EclipseShadow(lat: lat, lon: lon, umbraKm: abs(umbra),
                         penumbraKm: penumbra, annular: umbra < 0)
}

/// Position d'une lune dans le repère de sa planète.
///
/// Le repère est celui des planètes : une longitude écliptique λ se pose en
/// `(cos λ, ·, −sin λ)`. Le signe de z importe — avec `+sin λ` les lunes
/// tournaient à l'envers, à contresens de tout le reste de la scène.
///
/// La Lune suit son éphéméride. Les vingt et une autres gardent un angle
/// uniforme de période réelle et une phase d'écartement : leur longitude vraie
/// ne se vérifie pas d'en bas, et une série par lune n'apprendrait rien.
func moonLocalPosition(_ spec: MoonSpec, phase: Double, radius: Double, day d: Double) -> SIMD3<Double> {
    if spec.hasEphemeris {
        let e = moonEcliptic(day: d)
        let l = e.lon * Astro.DEG, b = e.lat * Astro.DEG
        return SIMD3(cos(b) * cos(l) * radius, sin(b) * radius, -cos(b) * sin(l) * radius)
    }
    let a = moonAngle(phase: phase, period: spec.period, day: d)
    return SIMD3(cos(a) * radius, sin(a * 0.7) * 0.18, -sin(a) * radius)
}
