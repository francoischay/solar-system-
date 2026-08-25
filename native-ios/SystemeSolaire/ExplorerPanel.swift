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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 8)
    }

    private func tab(_ title: String, _ view: ExploreView) -> some View {
        let active = engine.exploreView == view
        return Button {
            engine.setExploreView(view)
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: .heavy))
                .foregroundStyle(active ? Color(red: 0.13, green: 0.14, blue: 0.32) : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(active ? Color(red: 0.96, green: 0.95, blue: 1) : .clear, in: RoundedRectangle(cornerRadius: 13))
        }
    }
}

// MARK: - Sondes

struct MissionList: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())], spacing: 6) {
                ForEach(Array(engine.missions.enumerated()), id: \.offset) { _, mission in
                    let selected = engine.selected == .mission(mission)
                    Button {
                        engine.selectMission(mission)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mission.spec.n)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32) : .white.opacity(0.8))
                                .lineLimit(1)
                            Text(mission.spec.valid)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32).opacity(0.58) : .white.opacity(0.48))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selected ? Color(red: 0.96, green: 0.95, blue: 1) : Color(red: 0.047, green: 0.055, blue: 0.216).opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Toggle(isOn: $engine.showAllMissions) {
                Text("Afficher toutes les sondes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .tint(Color(red: 0.46, green: 0.44, blue: 0.94))
        }
        .padding(.top, 4)
        .id(engine.listVersion)
    }
}

// MARK: - Satellites

struct SatelliteList: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 7) {
                ForEach(Array(engine.satModels.enumerated()), id: \.offset) { _, model in
                    let selected = engine.selected == .satellite(model)
                    Button {
                        engine.selectSatellite(model)
                    } label: {
                        HStack(spacing: 11) {
                            Text(model.spec.icon)
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.22))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: uiColor(model.spec.color)), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.spec.n)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32) : .white)
                                Text(engine.satelliteMeta(model))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32).opacity(0.58) : .white.opacity(0.58))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(selected ? Color(red: 0.96, green: 0.95, blue: 1) : Color(red: 0.043, green: 0.05, blue: 0.2).opacity(0.28), in: RoundedRectangle(cornerRadius: 15))
                    }
                }
            }
            Toggle(isOn: $engine.showAllSatellites) {
                Text("Afficher tous les satellites")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .tint(Color(red: 0.46, green: 0.44, blue: 0.94))
            Text(engine.satelliteNote)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.48))
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    let selected = engine.selectedLaunch == launch
                    Button {
                        engine.selectLaunch(launch)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.22))
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: uiColor(launch.color)), in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(launch.n)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32) : .white)
                                    .lineLimit(1)
                                Text(launch.meta)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32).opacity(0.58) : .white.opacity(0.58))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(countdown(launch))
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(selected ? Color(red: 0.24, green: 0.48, blue: 0.43) : Color(red: 0.62, green: 0.95, blue: 0.86))
                                Text(launch.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                                    .font(.system(size: 9))
                                    .foregroundStyle(selected ? Color(red: 0.145, green: 0.145, blue: 0.32).opacity(0.55) : .white.opacity(0.55))
                            }
                        }
                        .padding(10)
                        .background(selected ? Color(red: 0.96, green: 0.95, blue: 1) : Color(red: 0.043, green: 0.05, blue: 0.2).opacity(0.28), in: RoundedRectangle(cornerRadius: 15))
                    }
                }
            }
            Text("Fenêtres indicatives · trajectoire non télémétrique")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.48))
                .frame(maxWidth: .infinity, alignment: .leading)
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
