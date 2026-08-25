import SwiftUI
import SceneKit

/// SCNView + gestes (orbite libre, roulis, pincement, sélection) — équivalent natif du canvas WebGL
struct SceneContainer: UIViewRepresentable {
    @EnvironmentObject var engine: Engine

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = engine.scene
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true
        view.delegate = engine
        engine.scnView = view

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        // À deux doigts, le déplacement oriente la caméra pendant que le pincement
        // et la torsion restent disponibles simultanément.
        let twoFingerPan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.twoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.delegate = context.coordinator
        view.addGestureRecognizer(twoFingerPan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        context.coordinator.singleFingerPan = pan
        context.coordinator.twoFingerRecognizers = [twoFingerPan, pinch]
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(engine: engine) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let engine: Engine
        weak var singleFingerPan: UIPanGestureRecognizer?
        var twoFingerRecognizers: [UIGestureRecognizer] = []
        private var lastTranslation = CGPoint.zero
        private var lastTwoFingerTranslation = CGPoint.zero
        private var lastRotation: CGFloat = 0
        /// Dernier instant où un geste à deux doigts était en cours : toute fin de
        /// pan à un doigt dans la foulée est un doigt qui traîne, jamais un flick.
        private var lastMultiTouchActivity: TimeInterval = .zero
        init(engine: Engine) { self.engine = engine }

        private func noteMultiTouchActivity() { lastMultiTouchActivity = CACurrentMediaTime() }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Le geste composé à deux doigts doit pouvoir zoomer et s'orienter
            // dans un même mouvement continu.
            !(gestureRecognizer is UITapGestureRecognizer) && !(otherGestureRecognizer is UITapGestureRecognizer)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // Le pan à un doigt ne doit jamais démarrer pendant une manipulation à
            // deux doigts : il suivrait un seul des deux doigts et cumulerait sa
            // rotation (puis son inertie) avec le geste composé.
            if gestureRecognizer === singleFingerPan, isTwoFingerGestureActive { return false }
            return true
        }

        private var isTwoFingerGestureActive: Bool {
            twoFingerRecognizers.contains {
                $0.state == .began || $0.state == .changed || $0.numberOfTouches >= 2
            }
        }

        /// UIKit n'annule pas un pan (max 1 doigt) déjà commencé quand un deuxième
        /// doigt se pose : il continue de suivre le premier doigt. On l'annule donc
        /// explicitement dès qu'un geste à deux doigts prend la main.
        private func cancelSingleFingerPan() {
            guard let pan = singleFingerPan,
                  pan.state == .began || pan.state == .changed else { return }
            pan.isEnabled = false
            pan.isEnabled = true
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                engine.panBegan()
                lastTranslation = .zero
            case .changed:
                let t = recognizer.translation(in: recognizer.view)
                engine.panChanged(dx: Double(t.x - lastTranslation.x), dy: Double(t.y - lastTranslation.y))
                lastTranslation = t
            case .ended:
                let sinceMulti = CACurrentMediaTime() - lastMultiTouchActivity
                let v = recognizer.velocity(in: recognizer.view)
                if sinceMulti < 0.5 {
                    // Doigt restant d'un geste à deux doigts : pas d'inertie.
                    engine.panEnded(velocityX: 0, velocityY: 0, allowsInertia: false)
                } else {
                    engine.panEnded(velocityX: Double(v.x), velocityY: Double(v.y))
                }
            case .cancelled:
                engine.panEnded(velocityX: 0, velocityY: 0, allowsInertia: false)
            default:
                break
            }
        }

        @objc func twoFingerPan(_ recognizer: UIPanGestureRecognizer) {
            noteMultiTouchActivity()
            switch recognizer.state {
            case .began:
                cancelSingleFingerPan()
                engine.panBegan()
                lastTwoFingerTranslation = .zero
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                engine.panChanged(
                    dx: Double(translation.x - lastTwoFingerTranslation.x),
                    dy: Double(translation.y - lastTwoFingerTranslation.y),
                    precision: 0.72
                )
                lastTwoFingerTranslation = translation
            case .ended, .cancelled:
                // Un geste composé doit s'arrêter avec les doigts : les vitesses
                // de plusieurs recognizers ne doivent jamais se cumuler.
                engine.panEnded(velocityX: 0, velocityY: 0, allowsInertia: false)
            default:
                break
            }
        }

        @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
            noteMultiTouchActivity()
            switch recognizer.state {
            case .began:
                cancelSingleFingerPan()
                engine.pinchBegan()
            case .changed:
                engine.pinchChanged(scale: Double(recognizer.scale))
            default:
                break
            }
        }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            engine.tap(at: recognizer.location(in: recognizer.view))
        }
    }
}
