import CoreHaptics
import UIKit

/// Retours haptiques de la scène.
///
/// Les impacts courts passent par UIKit ; le grondement du décollage demande une
/// enveloppe (montée, tenue, extinction) que seuls les motifs Core Haptics savent
/// décrire. Tout est silencieux sur les appareils sans Taptic Engine et dans le
/// simulateur — aucun appelant n'a à s'en soucier.
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let picker = UISelectionFeedbackGenerator()
    private var lastRefusal: TimeInterval = 0
    private var lastTick: TimeInterval = 0

    private init() {}

    // MARK: Impacts courts

    /// Un astre entre dans le cadre
    func selected() { onMain { self.light.impactOccurred(intensity: 0.8) } }

    /// Choix dans une liste de l'explorateur
    func picked() { onMain { self.picker.selectionChanged() } }

    /// Retour au système solaire, sélection abandonnée
    func dismissed() { onMain { self.soft.impactOccurred(intensity: 0.5) } }

    /// Le drone se pose sur le pas de tir, juste avant la mise à feu
    func touchdown() { onMain { self.soft.impactOccurred(intensity: 0.65) } }

    /// Geste refusé — la timeline est verrouillée le temps du lancement. Étouffé
    /// à un par demi-seconde : un glissement continu déclencherait une mitraille.
    func refused() {
        let now = CACurrentMediaTime()
        guard now - lastRefusal > 0.5 else { return }
        lastRefusal = now
        onMain { self.rigid.impactOccurred(intensity: 0.45) }
    }

    /// La poignée de date est saisie. Un `medium` bien franc — c'est une prise en
    /// main, pas une sélection — et on préchauffe la foulée de crans qui suit.
    func grabbed() {
        onMain {
            self.medium.impactOccurred(intensity: 0.6)
            self.picker.prepare()
        }
    }

    /// Un menu s'ouvre
    func opened() { onMain { self.light.impactOccurred(intensity: 0.55) } }

    /// Un menu se referme — plus mat que l'ouverture
    func closed() { onMain { self.soft.impactOccurred(intensity: 0.4) } }

    /// Un cran de timeline franchi. Étouffé à un par 30 ms : en glissement rapide
    /// on traverse plusieurs crans par image, et le Taptic Engine sature.
    func tick() {
        let now = CACurrentMediaTime()
        guard now - lastTick > 0.03 else { return }
        lastTick = now
        onMain { self.picker.selectionChanged() }
    }

    /// À appeler avant une salve : le Taptic Engine répond sans latence s'il a été
    /// préchauffé, sinon le premier retour arrive avec un temps de retard.
    func prepare() {
        onMain {
            self.light.prepare()
            self.soft.prepare()
            self.picker.prepare()
            self.medium.prepare()
            self.startEngine()
        }
    }

    // MARK: Grondement du décollage

    /// La montée en puissance avant le décollage : les moteurs poussent, la fusée
    /// est encore retenue au sol. Vibration très sourde (netteté 0,03, le plus
    /// grave que rende le Taptic Engine) qui enfle lentement, ponctuée de
    /// secousses dont la cadence s'accélère jusqu'au lâcher.
    func spoolUp(duration: TimeInterval) {
        guard supported else { return }
        onMain {
            guard let engine = self.startEngine() else { return }
            let span = max(0.4, duration)
            var events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.03),
                ], relativeTime: 0, duration: span),
            ]
            for (fraction, intensity) in [(0.45, 0.22), (0.68, 0.3), (0.83, 0.4), (0.92, 0.5), (0.97, 0.62)] {
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                ], relativeTime: span * fraction))
            }
            // Presque rien au début, presque tout à la fin : c'est la retenue.
            let envelope = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.04),
                    .init(relativeTime: span * 0.3, value: 0.12),
                    .init(relativeTime: span * 0.6, value: 0.3),
                    .init(relativeTime: span * 0.85, value: 0.62),
                    .init(relativeTime: span, value: 0.9),
                ],
                relativeTime: 0
            )
            do {
                let pattern = try CHHapticPattern(events: events, parameterCurves: [envelope])
                try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
            } catch {
                self.soft.impactOccurred(intensity: 0.5)
            }
        }
    }

    /// Le sol qui gronde sous la fusée, sur toute la durée de l'ascension.
    ///
    /// Trois couches superposées :
    /// - le coup d'allumage, un transitoire plein et sourd ;
    /// - une vibration continue de faible netteté (le grave du Taptic Engine),
    ///   dont l'intensité enfle en un tiers de seconde puis retombe à mesure que
    ///   la fusée s'éloigne — c'est cette enveloppe qui fait le « gronde » ;
    /// - quelques secousses irrégulières dans la première seconde, sinon le
    ///   continu tout seul s'entend comme un bourdonnement de moteur.
    func launchRumble(duration: TimeInterval) {
        guard supported else { return }
        onMain {
            guard let engine = self.startEngine() else { return }
            let span = max(0.6, duration)
            var events: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08),
                ], relativeTime: 0, duration: span),
            ]
            // Secousses du sol : de plus en plus espacées et faibles, elles
            // s'éteignent quand la fusée a pris de l'altitude.
            for (offset, intensity) in [(0.08, 0.7), (0.19, 0.62), (0.33, 0.5), (0.52, 0.4), (0.78, 0.28)]
            where offset < span {
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
                ], relativeTime: offset))
            }
            // L'enveloppe : creux au repos, plein sous la poussée, puis fuite.
            let envelope = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.35),
                    .init(relativeTime: span * 0.09, value: 1),
                    .init(relativeTime: span * 0.32, value: 0.85),
                    .init(relativeTime: span * 0.68, value: 0.45),
                    .init(relativeTime: span, value: 0.04),
                ],
                relativeTime: 0
            )
            do {
                let pattern = try CHHapticPattern(events: events, parameterCurves: [envelope])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                // Un motif refusé ne doit jamais interrompre le lancement à l'écran
                self.soft.impactOccurred(intensity: 1)
            }
        }
    }

    // MARK: Manœuvres d'un vol habité

    /// Un allumage franc — injection translunaire, retour vers la Terre. Une
    /// poussée qui monte d'un coup et se coupe net : ce sont des minutes de feu,
    /// pas un grondement de décollage.
    func burn() { rumble(duration: 1.1, intensity: 0.85, sharpness: 0.12, attack: 0.06) }

    /// Un freinage — la mise en orbite lunaire se fait moteur en avant. Plus
    /// sourd et plus long à s'installer que l'allumage : on retient, on ne pousse pas.
    func brake() { rumble(duration: 1.4, intensity: 0.62, sharpness: 0.04, attack: 0.35) }

    /// Le retour : l'impact, puis le clapot.
    func splashdown() {
        guard supported else { return onMain { self.medium.impactOccurred(intensity: 1) } }
        onMain {
            guard let engine = self.startEngine() else { return }
            var events: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ], relativeTime: 0),
            ]
            for (offset, intensity) in [(0.13, 0.5), (0.27, 0.34), (0.44, 0.2)] {
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
                ], relativeTime: offset))
            }
            self.play(events, curves: [])
        }
    }

    /// Poussée continue : `attack` dit en quelle fraction de la durée elle
    /// atteint son plein — bref pour un allumage, étalé pour un freinage.
    private func rumble(duration: TimeInterval, intensity: Float, sharpness: Float, attack: Double) {
        guard supported else { return onMain { self.medium.impactOccurred(intensity: CGFloat(intensity)) } }
        onMain {
            guard self.startEngine() != nil else { return }
            let span = max(0.3, duration)
            let events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ], relativeTime: 0, duration: span),
            ]
            let envelope = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.2),
                    .init(relativeTime: span * attack, value: 1),
                    .init(relativeTime: span * 0.75, value: 0.7),
                    .init(relativeTime: span, value: 0.03),
                ],
                relativeTime: 0
            )
            self.play(events, curves: [envelope])
        }
    }

    /// Un motif refusé ne doit jamais interrompre ce qui se joue à l'écran.
    private func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve]) {
        guard let engine = self.engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            self.medium.impactOccurred(intensity: 0.9)
        }
    }

    // MARK: Moteur

    @discardableResult
    private func startEngine() -> CHHapticEngine? {
        guard supported else { return nil }
        if let engine { return engine }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            // Le système coupe le moteur en arrière-plan ou sur appel entrant :
            // on le relance à la demande plutôt que de le garder allumé pour rien.
            engine.stoppedHandler = { [weak self] _ in self?.engine = nil }
            engine.resetHandler = { [weak self] in
                self?.engine = nil
            }
            try engine.start()
            self.engine = engine
            return engine
        } catch {
            return nil
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
