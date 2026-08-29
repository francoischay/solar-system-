import CoreGraphics
import SwiftUI

enum WatchMissionProfile: Hashable {
    case earthOrbit(turns: Double)
    case lunarOrbit(loops: Double)
    case lunarFlyby
}

struct WatchMissionMoment: Identifiable, Hashable {
    let id: String
    let progress: Double
    let title: String
    let detail: String
}

struct WatchMission: Identifiable, Hashable {
    let id: String
    let title: String
    let duration: TimeInterval
    let accent: Color
    let profile: WatchMissionProfile
    let moments: [WatchMissionMoment]

    static let apollo11 = WatchMission(
        id: "apollo-11",
        title: "Apollo 11",
        duration: 8.1375 * 86_400,
        accent: Color(red: 0.906, green: 0.363, blue: 0.729),
        profile: .lunarOrbit(loops: 2.25),
        moments: [
            .init(id: "launch", progress: 0.00, title: "Décollage", detail: "Kennedy · LC-39A"),
            .init(id: "parking", progress: 0.10, title: "Orbite terrestre", detail: "Mise en attente"),
            .init(id: "tli", progress: 0.18, title: "Vers la Lune", detail: "Injection translunaire"),
            .init(id: "arrival", progress: 0.40, title: "Arrivée lunaire", detail: "Freinage"),
            .init(id: "orbit", progress: 0.50, title: "Orbite lunaire", detail: "La Lune remplit le ciel"),
            .init(id: "return", progress: 0.68, title: "Retour", detail: "Cap sur la Terre"),
            .init(id: "entry", progress: 0.94, title: "Rentrée", detail: "Atmosphère terrestre"),
            .init(id: "splashdown", progress: 1.00, title: "Amerrissage", detail: "Océan Pacifique"),
        ]
    )

    static let apollo13 = WatchMission(
        id: "apollo-13",
        title: "Apollo 13",
        duration: 5.9542 * 86_400,
        accent: Color(red: 0.98, green: 0.42, blue: 0.72),
        profile: .lunarFlyby,
        moments: [
            .init(id: "launch", progress: 0.00, title: "Décollage", detail: "Kennedy · LC-39A"),
            .init(id: "tli", progress: 0.17, title: "Vers la Lune", detail: "Injection translunaire"),
            .init(id: "incident", progress: 0.30, title: "Explosion", detail: "Réservoir d’oxygène"),
            .init(id: "flyby", progress: 0.53, title: "Derrière la Lune", detail: "Retour libre"),
            .init(id: "correction", progress: 0.70, title: "Correction", detail: "Cap sur la Terre"),
            .init(id: "entry", progress: 0.94, title: "Rentrée", detail: "Silence radio"),
            .init(id: "splashdown", progress: 1.00, title: "Amerrissage", detail: "Équipage sain et sauf"),
        ]
    )

    static let vostok1 = WatchMission(
        id: "vostok-1",
        title: "Vostok 1",
        duration: 108 * 60,
        accent: Color(red: 0.42, green: 0.20, blue: 0.88),
        profile: .earthOrbit(turns: 1.04),
        moments: [
            .init(id: "launch", progress: 0.00, title: "Поехали !", detail: "Décollage de Baïkonour"),
            .init(id: "orbit", progress: 0.16, title: "En orbite", detail: "Youri Gagarine"),
            .init(id: "night", progress: 0.48, title: "Côté nuit", detail: "La Terre défile"),
            .init(id: "retro", progress: 0.82, title: "Freinage", detail: "Retour vers l’atmosphère"),
            .init(id: "landing", progress: 1.00, title: "Atterrissage", detail: "108 minutes plus tard"),
        ]
    )

    static let featured: [WatchMission] = [.apollo11, .apollo13, .vostok1]

    func moment(at progress: Double) -> WatchMissionMoment {
        moments.last(where: { $0.progress <= progress + 0.000_001 }) ?? moments[0]
    }

    func elapsed(at progress: Double) -> String {
        let seconds = max(0, min(1, progress)) * duration
        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return String(format: "%d j  %02d h", days, hours) }
        if hours > 0 { return String(format: "%d h  %02d min", hours, minutes) }
        return String(format: "%d min", minutes)
    }
}
