import SwiftUI

/// Panneau « Explorer » : Sondes / Satellites / Lancements
struct ExplorerPanel: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(spacing: 7) {
            header
            ScrollView {
                switch engine.exploreView {
                case .missions: MissionList()
                case .satellites: SatelliteList()
                case .launches: LaunchList()
                case .none: EmptyView()
                }
            }
            .frame(maxHeight: 360)
            .padding(.horizontal, 9)
            .padding(.bottom, 10)
        }
        .padding(.top, 6)
        .background(GlassStyle.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(GlassStyle.border, lineWidth: 1))
        .transition(.scale(scale: 0.94, anchor: .bottomLeading).combined(with: .opacity))
    }

    private var header: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                tab("Sondes", .missions)
                tab("Satellites", .satellites)
                tab("Lancements", .launches)
            }
            .padding(3)
            .background(Color(red: 0.043, green: 0.05, blue: 0.2).opacity(0.34), in: RoundedRectangle(cornerRadius: 16))
            Button {
                withAnimation(.easeOut(duration: 0.18)) { engine.setExploreView(.none) }
            } label: {
                Image(systemName: "xmark")
                    .font(TypeScale.label)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 8)
    }

    /// L'onglet actif garde l'inversion blanche : c'est l'idiome du sélecteur
    /// segmenté d'iOS, et il ne concurrence rien puisqu'il n'y en a qu'un.
    private func tab(_ title: String, _ view: ExploreView) -> some View {
        let active = engine.exploreView == view
        return Button {
            engine.setExploreView(view)
        } label: {
            Text(title)
                .font(TypeScale.label)
                .foregroundStyle(active ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(active ? Color(red: 0.96, green: 0.95, blue: 1) : .clear, in: RoundedRectangle(cornerRadius: 13))
        }
    }
}

// MARK: - Ligne commune

enum RowGlyph {
    case symbol(String)
    case text(String)
}

/// Ligne d'explorateur. Les trois onglets partagent exactement la même anatomie —
/// pastille, nom, méta, appendice optionnel — pour que la grille ne change pas
/// sous le doigt quand on passe de l'un à l'autre.
struct ExplorerRow<Trailing: View>: View {
    let color: UInt32
    let glyph: RowGlyph
    let title: String
    let meta: String
    let selected: Bool
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: RowStyle.gap) {
            Group {
                switch glyph {
                case .symbol(let name): Image(systemName: name)
                case .text(let value): Text(value)
                }
            }
            .font(TypeScale.glyph)
            .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.22))
            .frame(width: RowStyle.chip, height: RowStyle.chip)
            .background(Color(uiColor: uiColor(color)), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypeScale.row)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(meta)
                    .font(TypeScale.meta)
                    .foregroundStyle(RowStyle.meta)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: RowStyle.minHeight)
        // La sélection se signale par un liseré et un fond à peine teinté. Un
        // aplat blanc ferait de la ligne choisie l'objet le plus lumineux de
        // l'écran — plus que l'astre, qui est pourtant le sujet.
        .background(selected ? RowStyle.selectedFill : RowStyle.idleFill,
                    in: RoundedRectangle(cornerRadius: RowStyle.radius))
        .overlay(
            RoundedRectangle(cornerRadius: RowStyle.radius)
                .strokeBorder(selected ? RowStyle.selectedBorder : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: RowStyle.radius))
    }
}

extension ExplorerRow where Trailing == EmptyView {
    init(color: UInt32, glyph: RowGlyph, title: String, meta: String, selected: Bool) {
        self.init(color: color, glyph: glyph, title: title, meta: meta, selected: selected) { EmptyView() }
    }
}

/// Note de bas de liste
private struct ListNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(TypeScale.meta)
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sondes

struct MissionList: View {
    @EnvironmentObject var engine: Engine

    private var robotic: [Mission] { engine.missions.filter { $0.spec.crewed == nil } }
    private var crewed: [Mission] { engine.missions.filter { $0.spec.crewed != nil } }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 7) {
                ForEach(robotic, id: \.spec.n) { row($0, glyph: "paperplane.fill") }
            }
            // Les vols habités sont à part : ce ne sont pas des années de
            // croisière mais quelques jours, et ils tiennent tous dans le
            // voisinage de la Terre.
            SectionLabel(text: "Vols habités")
            VStack(spacing: 7) {
                ForEach(crewed, id: \.spec.n) { row($0, glyph: "person.fill") }
            }
            ListNote(text: "Choisir un vol le rejoue, du décollage au retour")
        }
        .padding(.top, 4)
    }

    private func row(_ mission: Mission, glyph: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                // Choisir un vol habité, c'est le rejouer : même idiome qu'un
                // lancement, où la sélection déclenche la séquence.
                if mission.spec.crewed != nil { engine.playMission(mission) }
                else { engine.selectMission(mission) }
            }
        } label: {
            ExplorerRow(
                color: mission.spec.color,
                glyph: .symbol(glyph),
                title: mission.spec.n,
                meta: mission.spec.valid,
                selected: engine.selected == .mission(mission)
            )
        }
    }
}

/// Intertitre de liste : sépare deux familles sans ajouter un onglet de plus.
private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(TypeScale.meta)
            .foregroundStyle(.white.opacity(0.45))
            .textCase(.uppercase)
            .kerning(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

// MARK: - Satellites

struct SatelliteList: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 7) {
                ForEach(Array(engine.satModels.enumerated()), id: \.offset) { _, model in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { engine.selectSatellite(model) }
                    } label: {
                        ExplorerRow(
                            color: model.spec.color,
                            glyph: .text(model.spec.icon),
                            title: model.spec.n,
                            meta: engine.satelliteMeta(model),
                            selected: engine.selected == .satellite(model)
                        )
                    }
                }
            }
            Toggle(isOn: $engine.showAllSatellites) {
                Text("Afficher tous les satellites")
                    .font(TypeScale.label)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .tint(Color(red: 0.46, green: 0.44, blue: 0.94))
            ListNote(text: engine.satelliteNote)
        }
        .padding(.top, 4)
        .id(engine.listVersion)
    }
}

// MARK: - Lancements

struct LaunchList: View {
    @EnvironmentObject var engine: Engine
    @State private var now = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 7) {
                ForEach(engine.launchSpecs) { launch in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { engine.selectLaunch(launch) }
                    } label: {
                        ExplorerRow(
                            color: launch.color,
                            glyph: .symbol("arrow.up"),
                            title: launch.n,
                            meta: launch.meta,
                            selected: engine.selectedLaunch == launch
                        ) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(countdown(launch))
                                    .font(TypeScale.label)
                                    .foregroundStyle(Color(red: 0.62, green: 0.95, blue: 0.86))
                                Text(launch.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                                    .font(TypeScale.meta)
                                    .foregroundStyle(RowStyle.meta)
                            }
                        }
                    }
                }
            }
            ListNote(text: "Fenêtres indicatives · trajectoire non télémétrique")
        }
        .padding(.top, 4)
        .id(engine.launchListVersion)
        .onReceive(ticker) { now = $0 }
    }

    private func countdown(_ launch: LaunchSpec) -> String {
        if !launch.status.isEmpty, launch.status != "Go" { return launch.status }
        let seconds = launch.date.timeIntervalSince(now)
        if seconds <= 0 { return "En cours" }
        let hours = Int(seconds / 3600)
        let days = hours / 24
        return days > 0 ? "J−\(days) · \(hours % 24) h" : "T−\(hours) h"
    }
}
