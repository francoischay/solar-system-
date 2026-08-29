import Combine
import Foundation
import SwiftUI
import WatchKit

enum WatchLaunchStage: Equatable {
    case ready
    case ignition
    case ascent
    case mission
}

@MainActor
final class MissionPlayer: ObservableObject {
    @Published private(set) var progress = 0.0
    @Published private(set) var isPlaying = false
    @Published private(set) var launchStage: WatchLaunchStage = .ready
    @Published private(set) var ignitionProgress = 0.0
    @Published private(set) var ascentProgress = 0.0
    @Published var mission: WatchMission

    private var lastFrame = Date()
    private var lastScrubbedMomentID: String?
    private var launchClock: TimeInterval = 0
    private var nextIgnitionPulse = 0
    private var nextAscentPulse = 0
    private let screenDuration: TimeInterval = 72
    private let ignitionDuration: TimeInterval = 1.5
    private let ascentDuration: TimeInterval = 3.4
    private let ascentMissionProgress = 0.055
    private let ignitionPulseTimes = [0.45, 0.68, 0.83, 0.92, 0.97]
    private let ascentPulseTimes = [0.08, 0.19, 0.33, 0.52, 0.78]

    init(mission: WatchMission = .apollo11) {
        self.mission = mission
        lastScrubbedMomentID = mission.moment(at: 0).id
    }

    var crownProgress: Binding<Double> {
        Binding(get: { self.progress }, set: { self.scrub(to: $0) })
    }

    func togglePlayback() {
        if progress >= 0.999 {
            resetLaunch()
            progress = 0
        }
        isPlaying.toggle()
        lastFrame = Date()
        if isPlaying {
            if progress <= 0.0001 && launchStage == .ready {
                launchStage = .ignition
                launchClock = 0
                nextIgnitionPulse = 0
            }
            WKInterfaceDevice.current().play(.start)
        } else {
            WKInterfaceDevice.current().play(.stop)
        }
    }

    func advanceFrame(at date: Date) {
        defer { lastFrame = date }
        guard isPlaying else { return }
        let delta = min(0.1, max(0, date.timeIntervalSince(lastFrame)))

        switch launchStage {
        case .ready:
            launchStage = .ignition
            launchClock = 0

        case .ignition:
            launchClock += delta
            ignitionProgress = min(1, launchClock / ignitionDuration)
            playCrossedIgnitionPulses()
            if launchClock >= ignitionDuration {
                launchStage = .ascent
                launchClock = 0
                ignitionProgress = 1
                WKInterfaceDevice.current().play(.notification)
            }
            return

        case .ascent:
            launchClock += delta
            ascentProgress = min(1, launchClock / ascentDuration)
            progress = ascentMissionProgress * pow(ascentProgress, 2)
            playCrossedAscentPulses()
            if launchClock >= ascentDuration {
                launchStage = .mission
                progress = ascentMissionProgress
            }
            return

        case .mission:
            progress = min(1, progress + delta / screenDuration)
        }

        if progress >= 1 {
            isPlaying = false
            WKInterfaceDevice.current().play(.success)
        }
    }

    func scrub(to value: Double) {
        let next = min(1, max(0, value))
        let old = progress
        isPlaying = false
        progress = next
        if next <= 0.0001 {
            resetLaunch()
        } else {
            launchStage = .mission
            ignitionProgress = 1
            ascentProgress = 1
        }

        let moment = mission.moment(at: next)
        guard moment.id != lastScrubbedMomentID else { return }
        let crossed = mission.moments.contains {
            ($0.progress > old && $0.progress <= next) || ($0.progress < old && $0.progress >= next)
        }
        if crossed { WKInterfaceDevice.current().play(.click) }
        lastScrubbedMomentID = moment.id
    }

    func select(_ newMission: WatchMission) {
        mission = newMission
        progress = 0
        isPlaying = false
        resetLaunch()
        lastFrame = Date()
        lastScrubbedMomentID = newMission.moment(at: 0).id
        WKInterfaceDevice.current().play(.click)
    }

    private func resetLaunch() {
        launchStage = .ready
        launchClock = 0
        ignitionProgress = 0
        ascentProgress = 0
        nextIgnitionPulse = 0
        nextAscentPulse = 0
    }

    private func playCrossedIgnitionPulses() {
        while nextIgnitionPulse < ignitionPulseTimes.count,
              ignitionProgress >= ignitionPulseTimes[nextIgnitionPulse] {
            WKInterfaceDevice.current().play(nextIgnitionPulse < 2 ? .click : .directionUp)
            nextIgnitionPulse += 1
        }
    }

    private func playCrossedAscentPulses() {
        while nextAscentPulse < ascentPulseTimes.count,
              launchClock >= ascentPulseTimes[nextAscentPulse] {
            WKInterfaceDevice.current().play(nextAscentPulse < 2 ? .directionUp : .click)
            nextAscentPulse += 1
        }
    }
}
