import SceneKit
import SwiftUI

struct MissionScene: View {
    let mission: WatchMission
    let progress: Double
    let launchStage: WatchLaunchStage
    let ignitionProgress: Double
    let ascentProgress: Double
    let reduceMotion: Bool

    @StateObject private var renderer = MissionSceneRenderer()

    var body: some View {
        SceneView(
            scene: renderer.scene,
            pointOfView: renderer.camera,
            options: [],
            preferredFramesPerSecond: reduceMotion ? 20 : 30,
            antialiasingMode: .multisampling2X
        )
        .onAppear { updateRenderer(reconfigure: true) }
        .onChange(of: mission.id) { _, _ in updateRenderer(reconfigure: true) }
        .onChange(of: progress) { _, _ in updateRenderer() }
        .onChange(of: launchStage) { _, _ in updateRenderer() }
        .onChange(of: ignitionProgress) { _, _ in updateRenderer() }
        .onChange(of: ascentProgress) { _, _ in updateRenderer() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trajectoire 3D de \(mission.title), \(Int(progress * 100)) pour cent parcourus")
    }

    private func updateRenderer(reconfigure: Bool = false) {
        if reconfigure {
            renderer.configure(
                mission: mission,
                progress: progress,
                launchStage: launchStage,
                ignitionProgress: ignitionProgress,
                ascentProgress: ascentProgress
            )
        } else {
            renderer.setState(
                progress: progress,
                launchStage: launchStage,
                ignitionProgress: ignitionProgress,
                ascentProgress: ascentProgress
            )
        }
    }
}

@MainActor
private final class MissionSceneRenderer: ObservableObject {
    let scene = SCNScene()
    let camera = SCNNode()

    private let earth = SCNNode()
    private let moon = SCNNode()
    private let craft = SCNNode()
    private let padFlare = SCNNode()
    private let launchPlume = SCNNode()
    private let trailRoot = SCNNode()
    private var trailSegments: [SCNNode] = []
    private var points: [SCNVector3] = []
    private var accent = UIColor.white
    private var profile: WatchMissionProfile = .lunarOrbit(loops: 1)
    private var configuredMissionID: String?

    init() {
        scene.background.contents = UIColor.black
        scene.rootNode.addChildNode(camera)
        scene.rootNode.addChildNode(trailRoot)
        scene.rootNode.addChildNode(earth)
        scene.rootNode.addChildNode(moon)
        scene.rootNode.addChildNode(craft)
        scene.rootNode.addChildNode(padFlare)
        scene.rootNode.addChildNode(launchPlume)
        configureCameraAndLight()
        configureLaunchEffects()
    }

    func configure(
        mission: WatchMission,
        progress: Double,
        launchStage: WatchLaunchStage,
        ignitionProgress: Double,
        ascentProgress: Double
    ) {
        if configuredMissionID != mission.id {
            configuredMissionID = mission.id
            accent = UIColor(mission.accent)
            profile = mission.profile
            points = trajectory(for: mission, samples: 150)
            configureBodies(for: mission)
            configureCraft()
            rebuildTrail()
        }
        setState(
            progress: progress,
            launchStage: launchStage,
            ignitionProgress: ignitionProgress,
            ascentProgress: ascentProgress
        )
    }

    func setState(
        progress value: Double,
        launchStage: WatchLaunchStage,
        ignitionProgress: Double,
        ascentProgress: Double
    ) {
        guard !points.isEmpty else { return }
        let p = max(0, min(1, value))
        let pointIndex = min(points.count - 1, Int(p * Double(points.count - 1)))
        let activeSegment = max(0, pointIndex - 1)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        for (index, segment) in trailSegments.enumerated() {
            let material = segment.geometry?.firstMaterial
            if index <= activeSegment {
                let age = Double(index) / Double(max(1, activeSegment))
                material?.diffuse.contents = accent.withAlphaComponent(0.34 + 0.66 * age)
                material?.emission.contents = accent.withAlphaComponent(0.22 + 0.68 * age)
            } else {
                material?.diffuse.contents = UIColor.white.withAlphaComponent(0.055)
                material?.emission.contents = UIColor.white.withAlphaComponent(0.018)
            }
        }

        let craftPosition = points[pointIndex]
        craft.position = craftPosition
        craft.eulerAngles = SCNVector3(
            Float(p * .pi * 3),
            Float(p * .pi * 5),
            Float(p * .pi * 2)
        )
        updateLaunchEffects(
            stage: launchStage,
            ignitionProgress: ignitionProgress,
            ascentProgress: ascentProgress,
            pointIndex: pointIndex
        )
        updateCamera(
            progress: p,
            craftPosition: craftPosition,
            launchStage: launchStage,
            ignitionProgress: ignitionProgress,
            ascentProgress: ascentProgress
        )
        SCNTransaction.commit()
    }

    private func configureCameraAndLight() {
        let cameraBody = SCNCamera()
        // Même focale verticale que l'app iPhone. Le cadrage change, pas la
        // perspective : on évite l'effet de zoom optique pendant le voyage.
        cameraBody.fieldOfView = 46
        cameraBody.zNear = 0.05
        cameraBody.zFar = 100
        camera.camera = cameraBody
        camera.position = SCNVector3(0, 4.8, 10.2)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 900
        ambient.light?.color = UIColor(red: 0.557, green: 0.588, blue: 0.847, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .omni
        sun.light?.intensity = 2_200
        sun.light?.color = UIColor(red: 1.0, green: 0.957, blue: 0.835, alpha: 1)
        sun.position = SCNVector3(-5.5, 5.5, 8)
        scene.rootNode.addChildNode(sun)
    }

    private func configureBodies(for mission: WatchMission) {
        earth.childNodes.forEach { $0.removeFromParentNode() }
        moon.childNodes.forEach { $0.removeFromParentNode() }

        let earthSphere = texturedSphere(radius: 0.92, widthSegments: 56, heightSegments: 36)
        let earthMaterial = SCNMaterial()
        earthMaterial.lightingModel = .blinn
        earthMaterial.diffuse.contents = UIImage(named: "earth_atmos_4096-cosmic-v2.jpg")
            ?? UIColor(red: 0.025, green: 0.28, blue: 0.72, alpha: 1)
        earthMaterial.specular.contents = UIColor(white: 0.12, alpha: 1)
        earthMaterial.shininess = 8
        earthSphere.materials = [earthMaterial]
        earth.addChildNode(SCNNode(geometry: earthSphere))

        let atmosphere = SCNSphere(radius: 0.98)
        atmosphere.segmentCount = 40
        let atmosphereMaterial = SCNMaterial()
        atmosphereMaterial.lightingModel = .constant
        atmosphereMaterial.diffuse.contents = UIColor.clear
        atmosphereMaterial.emission.contents = UIColor(red: 0.15, green: 0.62, blue: 1, alpha: 0.10)
        atmosphereMaterial.transparency = 0.18
        atmosphereMaterial.isDoubleSided = true
        atmosphere.materials = [atmosphereMaterial]
        earth.addChildNode(SCNNode(geometry: atmosphere))

        switch mission.profile {
        case .earthOrbit:
            earth.position = SCNVector3(0, 0, 0)
            moon.isHidden = true
        case .lunarOrbit, .lunarFlyby:
            earth.position = SCNVector3(-3.35, -0.45, 0.35)
            moon.position = SCNVector3(3.35, 0.55, -0.95)
            moon.isHidden = false
        }

        let moonSphere = texturedSphere(radius: 0.43, widthSegments: 40, heightSegments: 28)
        let moonMaterial = SCNMaterial()
        moonMaterial.lightingModel = .blinn
        moonMaterial.diffuse.contents = UIImage(named: "moonmap1k-cosmic.jpg")
            ?? UIColor(white: 0.54, alpha: 1)
        moonMaterial.specular.contents = UIColor(white: 0.05, alpha: 1)
        moonSphere.materials = [moonMaterial]
        moon.addChildNode(SCNNode(geometry: moonSphere))
    }

    /// La caméra reprend la grammaire du rejeu iPhone : elle s'accroche d'abord
    /// au véhicule, se déplie pour donner la destination, puis resserre le cadre
    /// sur le corps rejoint. Le mouvement est une fonction du temps de mission ;
    /// la Crown peut donc avancer ou reculer sans état caché ni rattrapage.
    private func updateCamera(
        progress p: Double,
        craftPosition: SCNVector3,
        launchStage: WatchLaunchStage,
        ignitionProgress: Double,
        ascentProgress: Double
    ) {
        let earthCenter: SCNVector3
        var context: SCNVector3
        var distance: Float

        switch profile {
        case .earthOrbit:
            earthCenter = SCNVector3(0, 0, 0)
            context = mix(earthCenter, craftPosition, 0.68)
            distance = 4.0

        case .lunarOrbit, .lunarFlyby:
            earthCenter = SCNVector3(-3.35, -0.45, 0.35)
            let moonCenter = SCNVector3(3.35, 0.55, -0.95)
            if p < 0.14 {
                let t = smoothstep(p / 0.14)
                context = mix(earthCenter, craftPosition, 0.58 + 0.24 * t)
                distance = Float(3.0 + 1.4 * t)
            } else if p < 0.40 {
                let t = smoothstep((p - 0.14) / 0.26)
                context = mix(craftPosition, moonCenter, 0.10 + 0.22 * t)
                distance = Float(4.4 + 1.5 * t)
            } else if p < 0.66 {
                let t = smoothstep((p - 0.40) / 0.26)
                context = mix(craftPosition, moonCenter, 0.42 + 0.18 * sin(t * .pi))
                distance = 3.65
            } else if p < 0.92 {
                let t = smoothstep((p - 0.66) / 0.26)
                context = mix(craftPosition, earthCenter, 0.10 + 0.22 * t)
                distance = Float(5.8 - 1.2 * t)
            } else {
                let t = smoothstep((p - 0.92) / 0.08)
                context = mix(craftPosition, earthCenter, 0.28 + 0.42 * t)
                distance = Float(4.6 - 1.4 * t)
            }
        }

        if launchStage == .ready || launchStage == .ignition || launchStage == .ascent {
            let launchBlend = smoothstep(ascentProgress)
            context = mix(craftPosition, earthCenter, 0.18 + 0.22 * launchBlend)
            distance = Float(2.05 + 1.15 * launchBlend)
        }

        // Léger arc latéral : la profondeur de la trajectoire reste lisible sans
        // que l'horizon roule. Même convention que l'app iPhone, toujours droite.
        let azimuth = 0.24 + 0.10 * sin(p * .pi * 2)
        var offset = SCNVector3(
            Float(sin(azimuth)) * distance,
            distance * 0.44,
            Float(cos(azimuth)) * distance
        )
        if launchStage == .ignition {
            let shake = Float(pow(ignitionProgress, 2) * 0.025)
            offset.x += sin(Float(ignitionProgress * 83)) * shake
            offset.y += cos(Float(ignitionProgress * 71)) * shake * 0.55
        }
        camera.position = context + offset
        camera.look(at: context, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }

    /// Même maillage UV que `Geo.sphereGeometry` sur iPhone. Les continents et
    /// le relief lunaire gardent donc la même orientation dans les deux apps.
    private func texturedSphere(radius: Double, widthSegments: Int, heightSegments: Int) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        for iy in 0...heightSegments {
            let v = Double(iy) / Double(heightSegments)
            let theta = v * .pi
            for ix in 0...widthSegments {
                let u = Double(ix) / Double(widthSegments)
                let phi = u * .pi * 2
                let point = SCNVector3(
                    Float(-cos(phi) * sin(theta) * radius),
                    Float(cos(theta) * radius),
                    Float(sin(phi) * sin(theta) * radius)
                )
                vertices.append(point)
                normals.append(point * Float(1 / radius))
                uvs.append(CGPoint(x: u, y: v))
            }
        }
        let stride = widthSegments + 1
        for iy in 0..<heightSegments {
            for ix in 0..<widthSegments {
                let a = Int32(iy * stride + ix)
                let b = a + 1
                let c = a + Int32(stride)
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        return SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    private func configureCraft() {
        craft.childNodes.forEach { $0.removeFromParentNode() }

        let core = SCNNode(geometry: octahedron(radius: 0.072))
        let coreMaterial = SCNMaterial()
        coreMaterial.lightingModel = .blinn
        coreMaterial.diffuse.contents = accent
        coreMaterial.emission.contents = accent.withAlphaComponent(0.35)
        core.geometry?.materials = [coreMaterial]
        craft.addChildNode(core)

        let glow = SCNSphere(radius: 0.145)
        glow.segmentCount = 18
        let glowMaterial = SCNMaterial()
        glowMaterial.lightingModel = .constant
        glowMaterial.diffuse.contents = accent
        glowMaterial.emission.contents = accent.withAlphaComponent(0.2)
        glowMaterial.transparency = 0.11
        glowMaterial.writesToDepthBuffer = false
        glowMaterial.blendMode = .add
        glow.materials = [glowMaterial]
        craft.addChildNode(SCNNode(geometry: glow))
        craft.scale = SCNVector3(1, 1, 1)
    }

    private func configureLaunchEffects() {
        let flare = SCNSphere(radius: 0.105)
        flare.segmentCount = 16
        let flareMaterial = SCNMaterial()
        flareMaterial.lightingModel = .constant
        flareMaterial.diffuse.contents = UIColor(red: 1, green: 0.42, blue: 0.12, alpha: 1)
        flareMaterial.emission.contents = UIColor(red: 1, green: 0.20, blue: 0.04, alpha: 1)
        flareMaterial.transparency = 0.72
        flareMaterial.writesToDepthBuffer = false
        flareMaterial.blendMode = .add
        flare.materials = [flareMaterial]
        padFlare.geometry = flare
        padFlare.isHidden = true
        launchPlume.isHidden = true
    }

    private func updateLaunchEffects(
        stage: WatchLaunchStage,
        ignitionProgress: Double,
        ascentProgress: Double,
        pointIndex: Int
    ) {
        guard let first = points.first else { return }
        padFlare.position = first
        padFlare.isHidden = stage == .ready || stage == .mission
        let flareScale = Float(0.45 + 1.45 * pow(ignitionProgress, 2))
        padFlare.scale = SCNVector3(flareScale, flareScale, flareScale)

        guard stage == .ascent, pointIndex > 0 else {
            launchPlume.isHidden = true
            return
        }
        let startIndex = max(0, pointIndex - 3)
        let start = points[startIndex]
        let end = points[pointIndex]
        let plume = cylinder(from: start, to: end, radius: CGFloat(0.035 * (1 - 0.55 * ascentProgress)))
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(red: 1, green: 0.48, blue: 0.13, alpha: 0.86)
        material.emission.contents = UIColor(red: 1, green: 0.18, blue: 0.03, alpha: 0.92)
        material.writesToDepthBuffer = false
        material.blendMode = .add
        plume.geometry?.materials = [material]
        launchPlume.geometry = plume.geometry
        launchPlume.position = plume.position
        launchPlume.orientation = plume.orientation
        launchPlume.isHidden = false
    }

    private func octahedron(radius r: Float) -> SCNGeometry {
        let vertices: [SCNVector3] = [
            SCNVector3(r, 0, 0), SCNVector3(-r, 0, 0),
            SCNVector3(0, r, 0), SCNVector3(0, -r, 0),
            SCNVector3(0, 0, r), SCNVector3(0, 0, -r),
        ]
        let indices: [Int32] = [
            0, 2, 4, 0, 4, 3, 0, 3, 5, 0, 5, 2,
            1, 4, 2, 1, 3, 4, 1, 5, 3, 1, 2, 5,
        ]
        return SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
    }

    private func rebuildTrail() {
        trailRoot.childNodes.forEach { $0.removeFromParentNode() }
        trailSegments = []
        guard points.count > 1 else { return }
        for index in 0..<(points.count - 1) {
            let segment = cylinder(from: points[index], to: points[index + 1], radius: 0.018)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.055)
            material.emission.contents = UIColor.white.withAlphaComponent(0.018)
            material.blendMode = .add
            segment.geometry?.materials = [material]
            trailRoot.addChildNode(segment)
            trailSegments.append(segment)
        }
    }

    private func cylinder(from start: SCNVector3, to end: SCNVector3, radius: CGFloat) -> SCNNode {
        let vector = end - start
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(vector.length))
        cylinder.radialSegmentCount = 6
        let node = SCNNode(geometry: cylinder)
        node.position = (start + end) * 0.5
        node.look(at: end, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return node
    }

    private func trajectory(for mission: WatchMission, samples: Int) -> [SCNVector3] {
        (0...samples).map { point(for: mission.profile, progress: Double($0) / Double(samples)) }
    }

    private func point(for profile: WatchMissionProfile, progress p: Double) -> SCNVector3 {
        switch profile {
        case .earthOrbit(let turns):
            let angle = -0.45 + p * .pi * 2 * turns
            return SCNVector3(cos(angle) * 2.35, sin(angle) * 1.55, sin(angle * 0.72) * 0.72)
        case .lunarOrbit(let loops):
            return lunarPoint(progress: p, loops: loops, flyby: false)
        case .lunarFlyby:
            return lunarPoint(progress: p, loops: 0.55, flyby: true)
        }
    }

    private func lunarPoint(progress p: Double, loops: Double, flyby: Bool) -> SCNVector3 {
        let earth = SCNVector3(-3.35, -0.45, 0.35)
        let launch = SCNVector3(-2.75, 0.18, 0.74)
        let moon = SCNVector3(3.35, 0.55, -0.95)
        if p < 0.40 {
            return quadratic(launch, SCNVector3(-0.55, 2.15, 1.75), SCNVector3(2.70, 0.55, -0.74), p / 0.40)
        }
        if p < 0.66 {
            let t = (p - 0.40) / 0.26
            let angle = .pi + t * .pi * 2 * loops
            let radius = flyby ? 0.86 : 0.62
            return SCNVector3(moon.x + Float(cos(angle) * radius),
                              moon.y + Float(sin(angle) * radius * 0.78),
                              moon.z + Float(sin(angle + 0.8) * radius * 0.46))
        }
        let start = lunarPoint(progress: 0.659_999, loops: loops, flyby: flyby)
        return quadratic(start, SCNVector3(0.15, -2.35, -1.65), earth, (p - 0.66) / 0.34)
    }

    private func quadratic(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3, _ t: Double) -> SCNVector3 {
        let u = 1 - t
        return a * Float(u * u) + b * Float(2 * u * t) + c * Float(t * t)
    }

    private func mix(_ a: SCNVector3, _ b: SCNVector3, _ t: Double) -> SCNVector3 {
        a * Float(1 - t) + b * Float(t)
    }

    private func smoothstep(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}

private extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 { SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z) }
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 { SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z) }
    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 { SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs) }
    var length: Float { sqrt(x * x + y * y + z * z) }
}
