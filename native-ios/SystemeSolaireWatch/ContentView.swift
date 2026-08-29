import SwiftUI

struct WatchContentView: View {
    @StateObject private var player = MissionPlayer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var crownFocused: Bool
    @State private var chooserOpen = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !player.isPlaying)) { timeline in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Button {
                        chooserOpen = true
                    } label: {
                        VStack(spacing: 1) {
                            Text(player.mission.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(player.mission.elapsed(at: player.progress))
                                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.52))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choisir une autre mission")

                    MissionScene(
                        mission: player.mission,
                        progress: player.progress,
                        launchStage: player.launchStage,
                        ignitionProgress: player.ignitionProgress,
                        ascentProgress: player.ascentProgress,
                        reduceMotion: reduceMotion
                    )
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)
                        .clipped()

                    VStack(spacing: 2) {
                        Text(player.mission.moment(at: player.progress).title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(player.mission.accent)
                            .contentTransition(.opacity)
                        Text(player.mission.moment(at: player.progress).detail)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 37, alignment: .top)
                }
                .padding(.vertical, 3)
            }
            .contentShape(Rectangle())
            .onTapGesture { player.togglePlayback() }
            .focusable()
            .focused($crownFocused)
            .digitalCrownRotation(
                player.crownProgress,
                from: 0,
                through: 1,
                by: 0.0025,
                sensitivity: .high,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: timeline.date) { _, date in player.advanceFrame(at: date) }
            .onAppear { crownFocused = true }
            .sheet(isPresented: $chooserOpen, onDismiss: { crownFocused = true }) {
                MissionChooser(player: player)
            }
            .accessibilityAction(named: player.isPlaying ? "Mettre en pause" : "Lire") {
                player.togglePlayback()
            }
        }
    }
}

private struct MissionChooser: View {
    @ObservedObject var player: MissionPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(WatchMission.featured) { mission in
            Button {
                player.select(mission)
                dismiss()
            } label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(mission.accent)
                        .frame(width: 9, height: 9)
                        .shadow(color: mission.accent.opacity(0.7), radius: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title)
                            .font(.headline)
                        Text(mission.elapsed(at: 1))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Missions")
    }
}
