import SceneKit
import simd
import CoreLocation
import UIKit

// MARK: - Corps de scène

final class Planet {
    let spec: PlanetSpec
    let node = SCNNode()
    let trail: TrailLine
    var moonSystem: MoonSystem?
    init(spec: PlanetSpec) {
        self.spec = spec
        trail = TrailLine(color: uiColor(spec.color))
    }
    var hitRadius: Double { max(2.8, spec.size * 1.8) }
}

final class MoonBody {
    let spec: MoonSpec
    let node = SCNNode()
    let trail: TrailLine
    let phase: Double
    unowned let planet: Planet
    init(spec: MoonSpec, phase: Double, planet: Planet) {
        self.spec = spec
        self.phase = phase
        self.planet = planet
        trail = TrailLine(color: uiColor(spec.color))
    }
    var hitRadius: Double { max(0.9, spec.size * 3.4) }
}

final class MoonSystem {
    unowned let planet: Planet
    let group = SCNNode()
    var moons: [MoonBody] = []
    init(planet: Planet) { self.planet = planet }
}

final class Mission {
    let spec: MissionSpec
    let node = SCNNode()
    let trail: TrailLine
    var trailCenter = SIMD3<Double>()
    var trailRadius = 0.0
    var lastTrailDay = Double.nan
    init(spec: MissionSpec) {
        self.spec = spec
        trail = TrailLine(color: uiColor(spec.color))
    }
}

final class SatModel {
    let spec: SatSpec
    let node = SCNNode()
    var orbitNode: SCNNode?
    var members: [TLEMember] = []
    var primary: TLEMember? { members.first }
    var altitudeKm: Double?
    var aliveCount = 0
    var inclinationDeg: Double = 0
    var frameDist = 12.0
    var launchYear: Int?
    var dimmed = false
    var dimmableMaterials: [SCNMaterial] = []
    var constellationDay = Double.nan
    var lastConstellationUpdate: TimeInterval = 0
    var ringDay = Double.nan
    var isConstellation: Bool { spec.group != nil }
    init(spec: SatSpec) { self.spec = spec }
    var hitRadius: Double { 0.32 }
}

enum Selection: Equatable {
    case planet(Planet), moon(MoonBody), mission(Mission), satellite(SatModel)
    static func == (a: Selection, b: Selection) -> Bool {
        switch (a, b) {
        case let (.planet(x), .planet(y)): return x === y
        case let (.moon(x), .moon(y)): return x === y
        case let (.mission(x), .mission(y)): return x === y
        case let (.satellite(x), .satellite(y)): return x === y
        default: return false
        }
    }
    var name: String {
        switch self {
        case .planet(let p): return p.spec.name
        case .moon(let m): return m.spec.name
        case .mission(let m): return m.spec.n
        case .satellite(let s): return s.spec.n
        }
    }
}

enum ExploreView: String { case none, missions, satellites, launches }

struct LabelInfo: Identifiable, Equatable {
    let id: String
    let text: String
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Moteur

final class Engine: NSObject, ObservableObject, SCNSceneRendererDelegate, CLLocationManagerDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    weak var scnView: SCNView?

    var planets: [Planet] = []
    var moonSystems: [MoonSystem] = []
    var missions: [Mission] = []
    var satModels: [SatModel] = []
    var earth: Planet { planets[2] }

    // État temps / caméra (lu et écrit par la boucle de rendu)
    var day = Astro.todayDay
    var az = 0.65, elev = 0.58, roll = 0.0, dist = 230.0, goalDist = 230.0
    var goalAz: Double?, goalElev: Double?, goalRoll: Double?
    // --- debug : journal fichier des gestes (Documents/gesture.log) ---
    static let debugLogURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("gesture.log")
    private static let debugLogHandle: FileHandle? = {
        try? "".write(to: debugLogURL, atomically: true, encoding: .utf8)
        return try? FileHandle(forWritingTo: debugLogURL)
    }()
    static func dlog(_ msg: String) {
        let line = String(format: "%.3f ", CACurrentMediaTime()) + msg + "\n"
        print(msg)
        if let d = line.data(using: .utf8) { debugLogHandle?.write(d) }
    }
    private var lastStateDump: TimeInterval = 0

    var panVelocityAz = 0.0, panVelocityElev = 0.0
    var dragging = false
    private var activeOrientationGestures = 0
    private static let cameraElevationLimit = Double.pi / 2 - 0.025
    var target = SIMD3<Double>(), focusTarget = SIMD3<Double>()
    private var targetVelocity = SIMD3<Double>()
    private var previousFocusTarget = SIMD3<Double>()
    private var distVelocity = 0.0
    private var azGoalVelocity = 0.0, elevGoalVelocity = 0.0, rollGoalVelocity = 0.0
    private enum CameraFocusIdentity: Equatable {
        case selection(Selection)
        case launch(String)
    }
    private var trackedFocus: CameraFocusIdentity?
    var spacecraftZoomScale = 1.0
    private var detailExpansionProgress = 0.0
    private var detailExpansionTarget = 0.0

    var selected: Selection? {
        didSet {
            if oldValue != selected { missionDateEndpoint = "start"; spacecraftZoomScale = 1 }
        }
    }
    var missionDateEndpoint = "start"

    // Timeline
    var dayRange = 100.0
    var timelineCenter = Astro.todayDay
    var handleTop = 50.0 // pourcents
    var timelineVelocity = 0.0
    var edgeDirection = 0.0
    private struct DateTransition {
        let startDay, targetDay, startCenter, targetCenter, startTop, targetTop, startTime: Double
    }
    private var dateTransition: DateTransition?
    static let HANDLE_REST = 62.0
    func restCenter(_ targetDay: Double) -> Double { targetDay - (Self.HANDLE_REST / 100 - 0.5) * dayRange }

    // Lancements
    var launchSpecs: [LaunchSpec] = fallbackLaunches
    var selectedLaunch: LaunchSpec?
    private var launchArcPoints: [SIMD3<Double>] = []
    private var launchArcLengths: [Double] = []
    private let launchArcCore = SCNNode()
    private let launchArcGlow = SCNNode()
    private let launchHead = SCNNode()
    private var launchClock = 0.0
    private var launchProgressShown = -1.0
    static let LAUNCH_DIVE = -0.7

    // Satellites
    let satelliteOrbits = SCNNode()
    var tleEpochDay: Double?
    static let SGP4_WINDOW = 45.0 // jours : au-delà, SGP4 diverge (surtout en rétro-propagation)
    func propagationDay() -> Double {
        guard let e = tleEpochDay else { return day }
        return max(e - Self.SGP4_WINDOW, min(e + Self.SGP4_WINDOW, day))
    }
    func tleUsable() -> Bool {
        guard let e = tleEpochDay else { return true }
        return abs(day - e) <= Self.SGP4_WINDOW
    }

    // Divers scène
    private let sunNode = SCNNode()
    private let homeMarker = SCNNode()
    private let homeDot = SCNNode()
    private let homeHalo = SCNNode()
    private let earthTilt = simd_quatd(angle: -23.44 * Astro.DEG, axis: SIMD3(1, 0, 0))
    private let locationManager = CLLocationManager()

    // État publié vers SwiftUI
    @Published var selectionTitle = "Système solaire"
    @Published var selectionSub = "Explorer les orbites"
    @Published var selectionDetail: String?
    @Published var selectionIsSpacecraft = false
    @Published var hasSelection = false
    @Published var dateText = ""
    @Published var showTodayButton = false
    @Published var handleTopPercent = 50.0
    @Published var satelliteNote = "Chargement des éléments orbitaux…"
    @Published var exploreView: ExploreView = .none
    @Published var showAllMissions = false
    @Published var showAllSatellites = false
    @Published var labels: [LabelInfo] = []
    @Published var listVersion = 0
    @Published var launchListVersion = 0
    @Published var scaleShort = "J"

    private var lastFrameTime: TimeInterval = 0
    private var previousDay = Astro.todayDay
    private var timeVelocity = 0.0, trailEnergy = 0.0, trailDirection = 1.0
    private var lastBornSignature = ""
    private var noteOutOfRange = false

    override init() {
        super.init()
        buildScene()
        locationManager.delegate = self
        setHome(lat: 48.8566, lon: 2.3522) // repli si la géolocalisation est refusée
        Task { await loadSatelliteElements() }
        Task { await loadLaunches() }
        updateDateText(force: true)
    }

    func requestLocation() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let c = locations.last?.coordinate { setHome(lat: c.latitude, lon: c.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    // MARK: Construction de la scène

    private func buildScene() {
        scene.background.contents = UIColor.clear

        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 1200
        camera.fieldOfView = 46
        camera.projectionDirection = .vertical
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = uiColor(0x8e96d8)
        ambient.light!.intensity = 900
        scene.rootNode.addChildNode(ambient)

        let sunLight = SCNNode()
        sunLight.light = SCNLight()
        sunLight.light!.type = .omni
        sunLight.light!.color = uiColor(0xfff4d5)
        sunLight.light!.intensity = 2200
        sunLight.light!.attenuationStartDistance = 0
        sunLight.light!.attenuationEndDistance = 500
        scene.rootNode.addChildNode(sunLight)

        // Soleil + halo
        let sunSphere = Geo.sphereGeometry(radius: 3.3)
        let sunMaterial = SCNMaterial()
        sunMaterial.lightingModel = .constant
        sunMaterial.diffuse.contents = uiColor(0xffd77b)
        sunSphere.materials = [sunMaterial]
        sunNode.geometry = sunSphere
        scene.rootNode.addChildNode(sunNode)
        TextureLoader.shared.load(TextureLoader.base + "sunmap.jpg") { image in
            sunMaterial.diffuse.contents = image
        }
        let haloSphere = SCNSphere(radius: 6.2)
        let haloMaterial = SCNMaterial()
        haloMaterial.lightingModel = .constant
        haloMaterial.diffuse.contents = uiColor(0xffd99a)
        haloMaterial.transparency = 0.14
        haloMaterial.writesToDepthBuffer = false
        haloSphere.materials = [haloMaterial]
        let haloNode = SCNNode(geometry: haloSphere)
        scene.rootNode.addChildNode(haloNode)

        // Étoiles
        var starPoints: [SIMD3<Double>] = []
        for _ in 0..<520 {
            let r = 220 + Double.random(in: 0..<300)
            let a = Double.random(in: 0..<Astro.TAU)
            let z = Double.random(in: -1..<1)
            let s = (1 - z * z).squareRoot()
            starPoints.append(SIMD3(r * s * cos(a), r * z, r * s * sin(a)))
        }
        let stars = SCNNode(geometry: Geo.pointsGeometry(
            points: starPoints, color: uiColor(0xdadfff, alpha: 0.58),
            pointSize: 2, minScreenRadius: 0.5, maxScreenRadius: 1.4))
        scene.rootNode.addChildNode(stars)

        // Planètes
        for spec in planetSpecs {
            let planet = Planet(spec: spec)
            var orbitPoints: [SIMD3<Double>] = []
            for k in 0...192 {
                orbitPoints.append(planetPosition(spec, day: Double(k) / 192 * spec.p * 365.25))
            }
            if let g = Geo.lineGeometry(points: orbitPoints, color: uiColor(0xc7ccff)) {
                let orbitNode = SCNNode(geometry: g)
                orbitNode.opacity = 0.065
                scene.rootNode.addChildNode(orbitNode)
            }
            let sphere = Geo.sphereGeometry(radius: spec.size)
            let material = SCNMaterial()
            material.lightingModel = .blinn
            material.diffuse.contents = ProceduralTexture.surface(for: spec)
            material.specular.contents = UIColor(white: 0.12, alpha: 1)
            material.shininess = 8
            sphere.materials = [material]
            planet.node.geometry = sphere
            scene.rootNode.addChildNode(planet.node)
            scene.rootNode.addChildNode(planet.trail.node)
            if spec.name == "Terre" {
                TextureLoader.shared.load(TextureLoader.earthURL) { image in
                    material.diffuse.contents = image
                }
            } else if let map = TextureLoader.planetMaps[spec.name] {
                TextureLoader.shared.load(TextureLoader.base + map) { image in
                    material.diffuse.contents = image
                }
            }
            if spec.name == "Saturne" {
                let ring = SCNNode(geometry: Geo.ringGeometry(inner: 3.1, outer: 4.5, segments: 96))
                let ringMaterial = SCNMaterial()
                ringMaterial.lightingModel = .constant
                ringMaterial.diffuse.contents = uiColor(0xd8c9ab)
                ringMaterial.isDoubleSided = true
                ringMaterial.transparency = 0.76
                ringMaterial.writesToDepthBuffer = false
                ring.geometry!.materials = [ringMaterial]
                planet.node.addChildNode(ring)
                TextureLoader.shared.load(TextureLoader.base + "saturnringcolor.jpg") { image in
                    ringMaterial.diffuse.contents = image
                    ringMaterial.transparency = 0.92
                }
            }
            planets.append(planet)
        }

        // Lunes
        for (planetName, specs) in moonSpecs {
            guard let planet = planets.first(where: { $0.spec.name == planetName }) else { continue }
            let system = MoonSystem(planet: planet)
            scene.rootNode.addChildNode(system.group)
            for (index, spec) in specs.enumerated() {
                var orbitPoints: [SIMD3<Double>] = []
                for k in 0...64 {
                    let a = Double(k) / 64 * Astro.TAU
                    orbitPoints.append(SIMD3(cos(a) * spec.radius, 0, sin(a) * spec.radius))
                }
                if let g = Geo.lineGeometry(points: orbitPoints, color: uiColor(0xdce0ff)) {
                    let orbitNode = SCNNode(geometry: g)
                    orbitNode.opacity = 0.08
                    system.group.addChildNode(orbitNode)
                }
                let moon = MoonBody(spec: spec, phase: Double(index) * 1.7, planet: planet)
                let sphere = Geo.sphereGeometry(radius: spec.size, widthSegments: 20, heightSegments: 14)
                let material = SCNMaterial()
                material.lightingModel = .blinn
                material.diffuse.contents = uiColor(spec.color)
                material.specular.contents = UIColor(white: 0.05, alpha: 1)
                sphere.materials = [material]
                moon.node.geometry = sphere
                system.group.addChildNode(moon.node)
                scene.rootNode.addChildNode(moon.trail.node)
                if spec.name == "Lune" {
                    TextureLoader.shared.load(TextureLoader.base + "moonmap1k.jpg") { image in
                        material.diffuse.contents = image
                    }
                }
                system.moons.append(moon)
            }
            system.group.isHidden = true
            moonSystems.append(system)
            planet.moonSystem = system
        }

        // Sondes
        for spec in missionSpecs {
            let mission = Mission(spec: spec)
            let core = SCNNode(geometry: Geo.octahedron(radius: 0.75))
            let coreMaterial = SCNMaterial()
            coreMaterial.lightingModel = .blinn
            coreMaterial.diffuse.contents = uiColor(spec.color)
            coreMaterial.emission.contents = uiColor(spec.color, alpha: 0.35)
            core.geometry!.materials = [coreMaterial]
            let glow = SCNNode(geometry: SCNSphere(radius: 1.55))
            let glowMaterial = SCNMaterial()
            glowMaterial.lightingModel = .constant
            glowMaterial.diffuse.contents = uiColor(spec.color)
            glowMaterial.transparency = 0.11
            glowMaterial.writesToDepthBuffer = false
            glow.geometry!.materials = [glowMaterial]
            mission.node.addChildNode(core)
            mission.node.addChildNode(glow)
            mission.node.isHidden = true
            scene.rootNode.addChildNode(mission.node)
            scene.rootNode.addChildNode(mission.trail.node)
            missions.append(mission)
        }

        // Satellites
        scene.rootNode.addChildNode(satelliteOrbits)
        for spec in satelliteSpecs {
            satModels.append(makeSatelliteModel(spec))
        }

        // Point de géolocalisation, solidaire de la rotation du globe
        let dotGeometry = SCNSphere(radius: 0.045)
        let dotMaterial = SCNMaterial()
        dotMaterial.lightingModel = .constant
        dotMaterial.diffuse.contents = uiColor(0x4da3ff)
        dotGeometry.materials = [dotMaterial]
        homeDot.geometry = dotGeometry
        let haloGeometry = Geo.ringGeometry(inner: 0.075, outer: 0.115, segments: 28)
        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = .constant
        ringMaterial.diffuse.contents = uiColor(0x4da3ff)
        ringMaterial.isDoubleSided = true
        ringMaterial.writesToDepthBuffer = false
        haloGeometry.materials = [ringMaterial]
        homeHalo.geometry = haloGeometry
        homeHalo.position = SCNVector3(0, 0.005, 0)
        homeMarker.addChildNode(homeDot)
        homeMarker.addChildNode(homeHalo)
        earth.node.addChildNode(homeMarker)

        // Trajectoire de lancement (coeur + halo additive + tête lumineuse)
        launchArcCore.isHidden = true
        launchArcGlow.isHidden = true
        earth.node.addChildNode(launchArcCore)
        earth.node.addChildNode(launchArcGlow)
        let headGeometry = SCNSphere(radius: 0.012)
        let headMaterial = SCNMaterial()
        headMaterial.lightingModel = .constant
        headMaterial.diffuse.contents = UIColor.white
        headGeometry.materials = [headMaterial]
        launchHead.geometry = headGeometry
        let headHalo = SCNNode(geometry: SCNSphere(radius: 0.021))
        let headHaloMaterial = SCNMaterial()
        headHaloMaterial.lightingModel = .constant
        headHaloMaterial.diffuse.contents = UIColor.white
        headHaloMaterial.transparency = 0.35
        headHaloMaterial.blendMode = .add
        headHaloMaterial.writesToDepthBuffer = false
        headHalo.geometry!.materials = [headHaloMaterial]
        launchHead.addChildNode(headHalo)
        launchHead.isHidden = true
        earth.node.addChildNode(launchHead)

        placeCamera()
    }

    private func makeSatelliteModel(_ spec: SatSpec) -> SatModel {
        let model = SatModel(spec: spec)
        model.launchYear = TLEParser.launchYear(line1: spec.tleFallback.components(separatedBy: "\n").first ?? "")
        if spec.group != nil {
            // constellation : un nuage de points, pas de maquette
            model.node.isHidden = true
            scene.rootNode.addChildNode(model.node)
            return model
        }
        let hull = SCNMaterial()
        hull.lightingModel = .blinn
        hull.diffuse.contents = uiColor(0xdfe5f5)
        hull.specular.contents = UIColor(white: 0.5, alpha: 1)
        let panel = SCNMaterial()
        panel.lightingModel = .blinn
        panel.diffuse.contents = uiColor(0x1d2f78)
        panel.emission.contents = uiColor(0x2246c8, alpha: 0.5)
        model.dimmableMaterials = [hull, panel]

        func mesh(_ geometry: SCNGeometry, _ material: SCNMaterial) -> SCNNode {
            geometry.materials = [material]
            return SCNNode(geometry: geometry)
        }
        let body = mesh(SCNBox(width: 0.06, height: 0.055, length: 0.085, chamferRadius: 0), hull)
        let boom = mesh(SCNCylinder(radius: 0.006, height: 0.3), hull)
        boom.eulerAngles.z = .pi / 2
        let left = mesh(SCNBox(width: 0.11, height: 0.005, length: 0.062, chamferRadius: 0), panel)
        let right = mesh(SCNBox(width: 0.11, height: 0.005, length: 0.062, chamferRadius: 0), panel)
        left.position.x = -0.096
        right.position.x = 0.096
        model.node.addChildNode(body)
        model.node.addChildNode(boom)
        model.node.addChildNode(left)
        model.node.addChildNode(right)
        if spec.n == "ISS" { // truss plus long, quatre panneaux
            let l2 = mesh(SCNBox(width: 0.11, height: 0.005, length: 0.062, chamferRadius: 0), panel)
            let r2 = mesh(SCNBox(width: 0.11, height: 0.005, length: 0.062, chamferRadius: 0), panel)
            l2.position = SCNVector3(-0.096, 0, 0.075)
            r2.position = SCNVector3(0.096, 0, 0.075)
            left.position.z = -0.075
            right.position.z = -0.075
            model.node.addChildNode(l2)
            model.node.addChildNode(r2)
        }
        let orbit = SCNNode()
        orbit.opacity = 0.28
        orbit.isHidden = true
        satelliteOrbits.addChildNode(orbit)
        model.orbitNode = orbit
        model.node.isHidden = true
        scene.rootNode.addChildNode(model.node)
        return model
    }

    // MARK: Géolocalisation

    func setHome(lat: Double, lon: Double) {
        let normal = Astro.geoToLocal(lat: lat, lon: lon, radius: 1)
        homeMarker.position = SCNVector3(normal * Astro.EARTH_RADIUS)
        let rotation = simd_quatd(from: SIMD3(0, 1, 0), to: simd_normalize(normal))
        homeMarker.orientation = SCNQuaternion(rotation)
    }

    // MARK: Repère TEME -> scène

    func eciToScene(_ p: SIMD3<Double>) -> SIMD3<Double> {
        var out = SIMD3(p.x, p.z, -p.y)
        let km = simd_length(out)
        guard km > 0 else { return out }
        out *= Astro.orbitSceneRadius(km: km) / km
        return earthTilt.act(out)
    }

    func satellitePosition(_ model: SatModel, day: Double) -> SIMD3<Double>? {
        guard let member = model.primary, let p = TLEParser.position(member, day: day) else { return nil }
        model.altitudeKm = simd_length(p) - Astro.EARTH_KM
        return eciToScene(p)
    }

    // MARK: Chargement TLE / lancements

    private func applySatelliteElements() {
        let epochs = satModels.compactMap { $0.members.isEmpty ? nil : $0.primary?.epochDay }
        tleEpochDay = epochs.isEmpty ? nil : epochs.reduce(0, +) / Double(epochs.count)
        // amorce altitude et effectifs affichés dans les listes
        for model in satModels where !model.members.isEmpty {
            if model.isConstellation {
                updateConstellation(model, propagationDay: propagationDay(), sceneYear: Astro.decimalYear(day), sceneDay: day)
            } else {
                _ = satellitePosition(model, day: propagationDay())
            }
        }
        updateSatelliteNote()
        listVersion += 1
    }

    func loadSatelliteElements() async {
        await withTaskGroup(of: Void.self) { group in
            for model in satModels {
                group.addTask {
                    let text = await TLEStore.shared.fetch(model.spec) ?? model.spec.tleFallback
                    let parsed = TLEParser.parse(text, max: model.spec.maxMembers)
                    let members = parsed.isEmpty ? TLEParser.parse(model.spec.tleFallback, max: model.spec.maxMembers) : parsed
                    await MainActor.run {
                        model.members = members
                        if model.isConstellation {
                            model.inclinationDeg = members.isEmpty ? 0 : members.map(\.inclinationDeg).reduce(0, +) / Double(members.count)
                        } else {
                            model.inclinationDeg = members.first?.inclinationDeg ?? 0
                            model.launchYear = members.first?.launchYear ?? model.launchYear
                        }
                    }
                }
            }
        }
        await MainActor.run { self.applySatelliteElements() }
    }

    func loadLaunches() async {
        guard let list = await LaunchLibrary.load(), !list.isEmpty else { return }
        await MainActor.run {
            launchSpecs = list
            launchListVersion += 1
        }
    }

    func updateSatelliteNote() {
        guard let epoch = tleEpochDay else {
            satelliteNote = "Chargement des éléments orbitaux…"
            return
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM yyyy"
        let epochText = formatter.string(from: Astro.date(fromDay: epoch))
        satelliteNote = tleUsable()
            ? "Propagation SGP4 · TLE du " + epochText
            : "Positions indicatives · loin du TLE du " + epochText
    }

    // MARK: Sélection

    func satelliteMeta(_ s: SatModel) -> String {
        if let launch = s.launchYear, Astro.decimalYear(day) < Double(launch) { return "lancé en \(launch)" }
        if s.isConstellation, s.aliveCount == 0, !s.members.isEmpty { return "aucun de ces satellites à cette date" }
        guard !s.members.isEmpty, let altitude = s.altitudeKm else { return s.spec.meta }
        let kmFormatter = NumberFormatter()
        kmFormatter.locale = Locale(identifier: "fr_FR")
        kmFormatter.numberStyle = .decimal
        let km = kmFormatter.string(from: NSNumber(value: Int(altitude.rounded()))) ?? "0"
        let orbit = "\(km) km · " + String(format: "%.1f°", s.inclinationDeg).replacingOccurrences(of: ".", with: ",")
        if !s.isConstellation { return orbit }
        return "\(s.aliveCount) satellite\(s.aliveCount > 1 ? "s" : "") · " + orbit
    }

    func setSelected(_ selection: Selection?) {
        let changed = selected != selection
        selected = selection
        selectionTitle = selection?.name ?? "Système solaire"
        switch selection {
        case .planet(let p):
            selectionSub = String(format: "%.2f", p.spec.a).replacingOccurrences(of: ".", with: ",") + " UA du Soleil"
        case .moon(let m):
            selectionSub = "Lune de " + m.planet.spec.name
        case .mission(let m):
            selectionSub = m.spec.valid
        case .satellite(let s):
            selectionSub = satelliteMeta(s)
        case nil:
            selectionSub = "Explorer les orbites"
        }
        selectionDetail = selection.flatMap { infoText[$0.name] }
        selectionIsSpacecraft = { if case .mission = selection { return true }; return false }()
        hasSelection = selection != nil
        switch selection {
        case .moon: goalDist = 14
        case .satellite(let s): goalDist = s.frameDist > 0 && s.isConstellation ? s.frameDist : 5
        case .mission: goalDist = 34
        case .planet: goalDist = 42
        case nil: break
        }
        if case .mission = selection { exploreView = .none }
        if changed { listVersion += 1 }
    }

    func reset() {
        selectedLaunch = nil
        launchArcCore.isHidden = true
        launchArcGlow.isHidden = true
        launchHead.isHidden = true
        aimCamera(0.65, 0.58, resetRoll: true)
        goalDist = 230
        setSelected(nil)
    }

    // MARK: Explorer

    func setExploreView(_ view: ExploreView) {
        exploreView = view
        if view == .satellites {
            setSelected(.planet(earth))
            goalDist = 9
            updateSatelliteNote()
        }
        if view != .launches {
            if selectedLaunch != nil {
                selectedLaunch = nil
                launchArcCore.isHidden = true
                launchArcGlow.isHidden = true
                launchHead.isHidden = true
                launchListVersion += 1
            }
        }
    }

    func selectMission(_ mission: Mission) {
        // Sonde hors de sa période : on cale la date sur sa borne, sinon il n'y a rien à voir
        let years = missionYears(mission.spec)
        let first = Astro.dayForYear(years.start)
        let last = Astro.dayForYear(years.end + 1) - 1
        let today = Astro.todayDay
        let targetDay = day >= first && day <= last ? day
            : today >= first && today <= last ? today
            : day < first ? first : last
        if targetDay != day {
            animateDate(to: targetDay, top: Self.HANDLE_REST, center: restCenter(targetDay))
        }
        let parentPos = mission.spec.parent.flatMap { name in
            planets.first { $0.spec.name == name }.map { planetPosition($0.spec, day: targetDay) }
        }
        let place = missionPosition(mission.spec, day: targetDay, parentPosition: parentPos)
        aimCamera(atan2(place.x, place.z) + .pi / 2, 0.42)
        setSelected(.mission(mission))
    }

    func selectSatellite(_ model: SatModel) {
        setSelected(.satellite(model))
        // se placer du côté du satellite, sinon il se retrouve derrière la Terre
        if !model.isConstellation, let offset = satellitePosition(model, day: propagationDay()), simd_length_squared(offset) > 0 {
            let elevGoal = min(1.25, max(0.12, asin(offset.y / simd_length(offset)) + 0.12))
            aimCamera(atan2(offset.x, offset.z) + 0.3, elevGoal)
        } else {
            aimCamera(1.05, 0.32)
        }
        exploreView = .none
    }

    func selectLaunch(_ launch: LaunchSpec) {
        setSelected(.planet(earth))
        selectedLaunch = launch
        selectionTitle = launch.n
        selectionSub = launch.meta
        selectionDetail = launch.detail.isEmpty ? infoText[launch.n] : launch.detail
        goalDist = 12
        let normal = simd_normalize(Astro.geoToLocal(lat: launch.lat, lon: launch.lon, radius: 1))
        var east = simd_cross(SIMD3(0.0, 1.0, 0.0), normal)
        if simd_length_squared(east) < 1e-6 { east = SIMD3(1, 0, 0) }
        east = simd_normalize(east)
        // Ascension réelle : vertical puis basculement, 400 km d'altitude et ~20° de distance au sol
        var points: [SIMD3<Double>] = []
        for k in 0...48 {
            let u = Double(k) / 48
            let altitude = 400 * pow(u, 0.62)
            let downrange = 20 * Astro.DEG * pow(u, 1.9)
            let p = (normal * cos(downrange) + east * sin(downrange)) * Astro.orbitSceneRadius(km: Astro.EARTH_KM + altitude)
            points.append(p)
        }
        buildLaunchArc(points: points, color: uiColor(launch.color))
        exploreView = .none
        launchClock = -1.6 // recul, changement de date, plongée, puis mise à feu
        launchProgressShown = -1
        let targetDay = Astro.day(from: launch.date)
        animateDate(to: targetDay, top: Self.HANDLE_REST, center: restCenter(targetDay))
        // Le globe aura tourné d'ici la date de tir : on vise son orientation d'arrivée
        let arrival = earthTilt * simd_quatd(angle: Astro.gmst(targetDay), axis: SIMD3(0, 1, 0))
        let heading = arrival.act(normal)
        aimCamera(atan2(heading.x, heading.z) + 0.85, 0.28)
        goalDist = 10 // on prend du recul le temps que la date défile
        launchListVersion += 1
    }

    private func buildLaunchArc(points: [SIMD3<Double>], color: UIColor) {
        launchArcPoints = points
        launchArcLengths = [0]
        for i in 1..<points.count {
            launchArcLengths.append(launchArcLengths[i - 1] + simd_length(points[i] - points[i - 1]))
        }
        var white = CGFloat(0), r = CGFloat(0), g = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        white = 0.55
        let core = UIColor(red: r + (1 - r) * white, green: g + (1 - g) * white, blue: b + (1 - b) * white, alpha: 1)
        launchArcCore.geometry = Geo.lineGeometry(points: points, color: core)
        launchArcGlow.geometry = Geo.lineGeometry(points: points, color: color, additive: true)
        launchArcGlow.opacity = 0.5
        if let headMaterial = launchHead.geometry?.materials.first { headMaterial.diffuse.contents = core }
        if let haloMaterial = launchHead.childNodes.first?.geometry?.materials.first { haloMaterial.diffuse.contents = color }
    }

    private func launchArcPoint(at progress: Double) -> SIMD3<Double> {
        guard let total = launchArcLengths.last, total > 0 else { return launchArcPoints.first ?? SIMD3() }
        let goal = max(0, min(1, progress)) * total
        var i = 1
        while i < launchArcLengths.count - 1 && launchArcLengths[i] < goal { i += 1 }
        let l0 = launchArcLengths[i - 1], l1 = launchArcLengths[i]
        let u = l1 > l0 ? (goal - l0) / (l1 - l0) : 0
        return launchArcPoints[i - 1] + (launchArcPoints[i] - launchArcPoints[i - 1]) * u
    }

    // MARK: Caméra

    /// Amortissement critique interrompable : la vitesse est conservée quand la
    /// destination change, sans oscillation ni dépassement de la nouvelle cible.
    private func smoothDamp(
        _ current: Double,
        toward destination: Double,
        velocity: inout Double,
        smoothTime: Double,
        deltaTime: Double
    ) -> Double {
        let omega = 2 / max(0.0001, smoothTime)
        let x = omega * deltaTime
        let decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
        let change = current - destination
        let temporary = (velocity + omega * change) * deltaTime
        velocity = (velocity - omega * temporary) * decay
        var value = destination + (change + temporary) * decay
        if ((destination - current) > 0) == (value > destination) {
            value = destination
            velocity = 0
        }
        return value
    }

    private func smoothDamp(
        _ current: SIMD3<Double>,
        toward destination: SIMD3<Double>,
        velocity: inout SIMD3<Double>,
        smoothTime: Double,
        deltaTime: Double
    ) -> SIMD3<Double> {
        var vx = velocity.x, vy = velocity.y, vz = velocity.z
        let x = smoothDamp(current.x, toward: destination.x, velocity: &vx, smoothTime: smoothTime, deltaTime: deltaTime)
        let y = smoothDamp(current.y, toward: destination.y, velocity: &vy, smoothTime: smoothTime, deltaTime: deltaTime)
        let z = smoothDamp(current.z, toward: destination.z, velocity: &vz, smoothTime: smoothTime, deltaTime: deltaTime)
        velocity = SIMD3(vx, vy, vz)
        return SIMD3(x, y, z)
    }

    func aimCamera(_ targetAz: Double, _ targetElev: Double, resetRoll: Bool = false) {
        goalAz = targetAz
        goalElev = targetElev
        if resetRoll { goalRoll = 0 }
        panVelocityAz = 0
        panVelocityElev = 0
        azGoalVelocity = 0
        elevGoalVelocity = 0
        rollGoalVelocity = 0
    }

    /// Synchronise la sheet SwiftUI et le cadrage SceneKit. Pendant le drag la
    /// progression est directe ; au snap elle est lissée par la boucle de rendu.
    func setDetailExpansionProgress(_ progress: Double, immediate: Bool) {
        let clamped = max(0, min(1, progress))
        detailExpansionTarget = clamped
        if immediate { detailExpansionProgress = clamped }
    }

    func placeCamera() {
        cameraNode.position = SCNVector3(
            Float(target.x + sin(az) * cos(elev) * dist),
            Float(target.y + sin(elev) * dist),
            Float(target.z + cos(az) * cos(elev) * dist)
        )
        cameraNode.look(at: SCNVector3(target))
        // `look(at:)` maintient l'horizon à plat. Le roulis ajouté dans le repère
        // local de la caméra permet d'orienter le plan orbital dans tout l'écran.
        let localRoll = simd_quatf(angle: Float(roll), axis: SIMD3<Float>(0, 0, 1))
        cameraNode.simdOrientation = simd_normalize(cameraNode.simdOrientation * localRoll)

        guard detailExpansionProgress > 0.001, selected != nil else { return }
        // À 100 %, la cible est projetée au centre de la moitié haute (25 % de
        // l'écran). On vise donc sous elle d'une demi-hauteur de frustum.
        let verticalHalfSpan = dist * tan(46.0 / 2 * Astro.DEG)
        let worldUp = cameraNode.worldUp
        let offset = verticalHalfSpan * 0.5 * detailExpansionProgress
        let shiftedTarget = target - SIMD3(
            Double(worldUp.x) * offset,
            Double(worldUp.y) * offset,
            Double(worldUp.z) * offset
        )
        cameraNode.look(
            at: SCNVector3(shiftedTarget),
            up: worldUp,
            localFront: SCNVector3(0, 0, -1)
        )
    }

    // Gestes (appelés du fil principal)
    func panBegan() {
        Self.dlog("[E] panBegan active=\(activeOrientationGestures)")
        goalAz = nil
        goalElev = nil
        goalRoll = nil
        activeOrientationGestures += 1
        dragging = true
        panVelocityAz = 0
        panVelocityElev = 0
        azGoalVelocity = 0
        elevGoalVelocity = 0
        rollGoalVelocity = 0
    }

    func panChanged(dx: Double, dy: Double, precision: Double = 1) {
        az -= dx * 0.007 * precision
        elev = max(-Self.cameraElevationLimit, min(Self.cameraElevationLimit, elev + dy * 0.005 * precision))
    }

    func panEnded(velocityX: Double, velocityY: Double, allowsInertia: Bool = true) {
        Self.dlog("[E] panEnded vx=\(velocityX) vy=\(velocityY) inertia=\(allowsInertia) active=\(activeOrientationGestures)")
        activeOrientationGestures = max(0, activeOrientationGestures - 1)
        dragging = activeOrientationGestures > 0
        if allowsInertia, activeOrientationGestures == 0 {
            panVelocityAz = max(-1.8, min(1.8, -velocityX * 0.007))
            panVelocityElev = max(-1.35, min(1.35, velocityY * 0.005))
        } else {
            panVelocityAz = 0
            panVelocityElev = 0
        }
    }

    func rollBegan() {
        goalAz = nil
        goalElev = nil
        goalRoll = nil
        activeOrientationGestures += 1
        dragging = true
        panVelocityAz = 0
        panVelocityElev = 0
        azGoalVelocity = 0
        elevGoalVelocity = 0
        rollGoalVelocity = 0
    }

    func rollChanged(delta: Double) {
        roll = normalizedAngle(roll + delta)
    }

    func rollEnded() {
        activeOrientationGestures = max(0, activeOrientationGestures - 1)
        dragging = activeOrientationGestures > 0
        // Le roulis est une manipulation directe : aucune rotation ne continue
        // après que les doigts ont quitté l'écran.
        panVelocityAz = 0
        panVelocityElev = 0
    }

    private func normalizedAngle(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }

    private var pinchStartZoom = 230.0
    private var pinchStartScale = 1.0
    func pinchBegan() {
        pinchStartZoom = goalDist
        pinchStartScale = spacecraftZoomScale
        panVelocityAz = 0
        panVelocityElev = 0
    }

    func pinchChanged(scale: Double) {
        guard scale > 0.01 else { return }
        let ratio = 1 / scale
        if case .mission = selected {
            spacecraftZoomScale = max(0.3, min(3, pinchStartScale * ratio))
        } else {
            goalDist = max(1.4, min(560, pinchStartZoom * ratio))
        }
    }

    // Sélection au toucher : projection écran des zones de saisie, priorité lune > sonde > planète
    func tap(at point: CGPoint) {
        guard let view = scnView else { return }
        struct Candidate { let selection: Selection; let priority: Int; let distance: CGFloat }
        var candidates: [Candidate] = []

        func consider(_ selection: Selection, node: SCNNode, radius: Double, priority: Int) {
            guard !node.isHidden, node.parent != nil else { return }
            var hidden = false
            var cursor: SCNNode? = node
            while let n = cursor { if n.isHidden { hidden = true; break }; cursor = n.parent }
            if hidden { return }
            let world = node.worldPosition
            let projected = view.projectPoint(world)
            guard projected.z > 0, projected.z < 1 else { return }
            let center = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            // rayon projeté : on projette un point décalé du rayon de saisie
            let cameraRight = cameraNode.worldRight
            let offsetWorld = SCNVector3(
                world.x + cameraRight.x * Float(radius),
                world.y + cameraRight.y * Float(radius),
                world.z + cameraRight.z * Float(radius)
            )
            let projectedOffset = view.projectPoint(offsetWorld)
            let screenRadius = max(22, hypot(CGFloat(projectedOffset.x) - center.x, CGFloat(projectedOffset.y) - center.y))
            let distance = hypot(point.x - center.x, point.y - center.y)
            if distance <= screenRadius {
                candidates.append(Candidate(selection: selection, priority: priority, distance: distance))
            }
        }

        for system in moonSystems where !system.group.isHidden {
            for moon in system.moons {
                consider(.moon(moon), node: moon.node, radius: moon.hitRadius, priority: 0)
            }
        }
        for mission in missions {
            consider(.mission(mission), node: mission.node, radius: 2.6 * max(0.5, mission.node.scale.x > 0 ? Double(mission.node.scale.x) * 3 : 1), priority: 1)
        }
        for model in satModels where !model.isConstellation {
            consider(.satellite(model), node: model.node, radius: model.hitRadius, priority: 1)
        }
        for planet in planets {
            consider(.planet(planet), node: planet.node, radius: planet.hitRadius, priority: 2)
        }
        let best = candidates.sorted { a, b in
            a.priority != b.priority ? a.priority < b.priority : a.distance < b.distance
        }.first
        if let best {
            if best.selection != selected { setSelected(best.selection) }
        } else if selected != nil || selectedLaunch != nil {
            reset()
        }
    }

    // Cartouche : bascule début/fin de mission pour une sonde sélectionnée
    func infoCardTapped() {
        guard case .mission(let mission) = selected else { return }
        timelineVelocity = 0
        let years = missionYears(mission.spec)
        if missionDateEndpoint == "start" {
            let targetDay = Astro.dayForYear(years.start)
            animateDate(to: targetDay, top: 0, center: targetDay + dayRange / 2)
            missionDateEndpoint = "end"
        } else {
            let targetDay = Astro.dayForYear(years.end + 1) - 1
            animateDate(to: targetDay, top: 100, center: targetDay - dayRange / 2)
            missionDateEndpoint = "start"
        }
    }

    // MARK: Timeline

    func animateDate(to targetDay: Double, top: Double, center: Double) {
        timelineVelocity = 0
        edgeDirection = 0
        dateTransition = DateTransition(
            startDay: day, targetDay: targetDay,
            startCenter: timelineCenter, targetCenter: center,
            startTop: handleTop, targetTop: top,
            startTime: CACurrentMediaTime()
        )
    }

    func goToToday() {
        let targetDay = Astro.todayDay
        animateDate(to: targetDay, top: Self.HANDLE_REST, center: restCenter(targetDay))
    }

    private var dragStartTop = 50.0
    private var lastSlideDay = 0.0
    private var lastSlideTime: TimeInterval = 0

    func timelineDragBegan() {
        dateTransition = nil
        timelineVelocity = 0
        dragStartTop = handleTop
        lastSlideDay = day
        lastSlideTime = CACurrentMediaTime()
    }

    func timelineDragChanged(offsetY: Double, height: Double) {
        let p = max(0, min(1, dragStartTop / 100 + offsetY / height))
        let nextDay = timelineCenter + (p - 0.5) * dayRange
        let now = CACurrentMediaTime()
        let elapsed = max(0.001, now - lastSlideTime) * 1000
        let instantVelocity = (nextDay - lastSlideDay) / elapsed
        let maxVelocity = dayRange / 4000 // l'élan reste proportionnel au pas choisi
        timelineVelocity = max(-maxVelocity, min(maxVelocity, timelineVelocity * 0.55 + instantVelocity * 0.45))
        day = nextDay
        lastSlideDay = day
        lastSlideTime = now
        handleTop = p * 100
        handleTopPercent = handleTop
        edgeDirection = p < 0.025 ? -1 : p > 0.975 ? 1 : 0
        updateDateText()
    }

    func timelineDragEnded() {
        edgeDirection = 0
        if abs(timelineVelocity) < 0.003 { timelineVelocity = 0 }
    }

    func setDayRange(_ range: Double, short: String) {
        dateTransition = nil
        timelineVelocity = 0
        edgeDirection = 0
        dayRange = range
        timelineCenter = restCenter(day)
        handleTop = Self.HANDLE_REST
        handleTopPercent = handleTop
        scaleShort = short
        updateDateText(force: true)
    }

    func jump(toDay targetDay: Double) {
        animateDate(to: targetDay, top: Self.HANDLE_REST, center: restCenter(targetDay))
    }

    private var lastDateText = ""
    private func updateDateText(force: Bool = false) {
        let date = Astro.date(fromDay: day)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        if dayRange <= 5 {
            formatter.dateFormat = "d MMM HH:mm" // au pas de l'heure, c'est l'heure qui porte l'information
        } else if dayRange >= 20000 {
            formatter.dateFormat = "MMM yyyy" // au pas de l'année, le jour n'a plus de sens
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }
        let text = formatter.string(from: date)
        if force || text != lastDateText {
            lastDateText = text
            if Thread.isMainThread { dateText = text }
            else { DispatchQueue.main.async { self.dateText = text } }
        }
    }

    // MARK: Boucle de rendu

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = lastFrameTime == 0 ? 0.016 : min(0.05, time - lastFrameTime)
        lastFrameTime = time

        var uiDirty = false

        if abs(detailExpansionTarget - detailExpansionProgress) > 0.0005 {
            detailExpansionProgress += (detailExpansionTarget - detailExpansionProgress) * (1 - exp(-12 * dt))
        } else {
            detailExpansionProgress = detailExpansionTarget
        }

        if time - lastStateDump > 0.25 {
            lastStateDump = time
            Self.dlog(String(format: "[S] az=%.3f elev=%.3f roll=%.3f vAz=%.3f vEl=%.3f drag=%d active=%d goalAz=%@ goalRoll=%@",
                az, elev, roll, panVelocityAz, panVelocityElev, dragging ? 1 : 0, activeOrientationGestures,
                goalAz.map { String(format: "%.3f", $0) } ?? "nil",
                goalRoll.map { String(format: "%.3f", $0) } ?? "nil"))
        }
        if !dragging {
            az += panVelocityAz * dt
            elev = max(-Self.cameraElevationLimit, min(Self.cameraElevationLimit, elev + panVelocityElev * dt))
            let momentumDecay = exp(-5.2 * dt)
            panVelocityAz *= momentumDecay
            panVelocityElev *= momentumDecay
            if elev <= -Self.cameraElevationLimit || elev >= Self.cameraElevationLimit { panVelocityElev = 0 }
        }

        // Transition de date animée
        if let t = dateTransition {
            let p = min(1, (CACurrentMediaTime() - t.startTime) / 0.95)
            let eased = p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
            day = t.startDay + (t.targetDay - t.startDay) * eased
            timelineCenter = t.startCenter + (t.targetCenter - t.startCenter) * eased
            handleTop = t.startTop + (t.targetTop - t.startTop) * eased
            if p >= 1 { dateTransition = nil }
            uiDirty = true
        }

        // Inertie de la timeline
        if timelineVelocity != 0, edgeDirection == 0, dateTransition == nil {
            let ms = dt * 1000
            day += timelineVelocity * ms
            timelineCenter += timelineVelocity * ms
            timelineVelocity *= exp(-0.0045 * ms)
            if abs(timelineVelocity) <= 0.001 { timelineVelocity = 0 }
            uiDirty = true
        }

        // Défilement au bord pendant le glissement
        if edgeDirection != 0 {
            let step = edgeDirection * dayRange / 200 * (dt / 0.045)
            day += step
            timelineCenter += step
            uiDirty = true
        }

        let rawVelocity = (day - previousDay) / max(dt, 0.001)
        previousDay = day
        if abs(rawVelocity) > 0.02 { trailDirection = rawVelocity > 0 ? 1 : -1 }
        timeVelocity += (abs(rawVelocity) - timeVelocity) * (1 - exp(-10 * dt))
        trailEnergy = max(timeVelocity, trailEnergy * exp(-2.2 * dt))
        let trailStrength = min(1, trailEnergy / 180)

        // Planètes
        for planet in planets {
            planet.node.position = SCNVector3(planetPosition(planet.spec, day: day))
            if planet.spec.name != "Terre" {
                planet.node.eulerAngles.y = Float(day * 0.015 / (1 + Double(planet.spec.index) * 0.15))
            }
            if trailStrength > 0.006 {
                let span = min(planet.spec.p * 365.25 * 0.09, 2 + trailEnergy * 0.13)
                var points: [SIMD3<Double>] = []
                points.reserveCapacity(72)
                for k in 0..<72 {
                    let u = Double(k) / 71
                    points.append(planetPosition(planet.spec, day: day - trailDirection * span * u))
                }
                planet.trail.update(points: points, opacity: trailStrength * 0.72)
            } else {
                planet.trail.update(points: [], opacity: 0)
            }
        }

        // Le globe suit le temps sidéral et porte l'inclinaison de 23,44°
        earth.node.orientation = SCNQuaternion(earthTilt * simd_quatd(angle: Astro.gmst(day), axis: SIMD3(0, 1, 0)))

        // Sondes
        for mission in missions {
            let isSelected = selected == .mission(mission)
            let visible = (isSelected || showAllMissions) && missionIsValid(mission.spec, day: day)
            mission.node.isHidden = !visible
            let parentPos = mission.spec.parent.flatMap { name in
                planets.first { $0.spec.name == name }?.node.position.simd3
            }
            mission.node.position = SCNVector3(missionPosition(mission.spec, day: day, parentPosition: parentPos))
            mission.node.eulerAngles.y += Float(dt * 0.8)
            // taille écran constante : lisible en vue système comme collée à une planète
            let scale = Float(max(0.06, min(3, dist * 0.0059)) * (isSelected ? 1.35 : 1))
            mission.node.scale = SCNVector3(scale, scale, scale)
            guard isSelected, visible else {
                mission.trail.update(points: [], opacity: 0)
                mission.trailRadius = 0
                continue
            }
            if mission.lastTrailDay != day {
                mission.lastTrailDay = day
                let years = missionYears(mission.spec)
                let endDay = min(day, Astro.dayForYear(years.end + 1))
                // Une sonde en orbite ne montre que sa dernière révolution
                let cycle = mission.spec.orbit.map { $0[3] * 365.25 } ?? mission.spec.local.map { 1 / $0[1] } ?? 0
                let startDay = max(Astro.dayForYear(years.start), cycle > 0 ? endDay - cycle * 1.15 : -1e9)
                if endDay >= startDay {
                    let samples = 320
                    var points: [SIMD3<Double>] = []
                    points.reserveCapacity(samples)
                    for k in 0..<samples {
                        let sampleDay = startDay + (endDay - startDay) * Double(k) / Double(samples - 1)
                        let parent = mission.spec.parent.flatMap { name in
                            planets.first { $0.spec.name == name }.map { planetPosition($0.spec, day: sampleDay) }
                        }
                        points.append(missionPosition(mission.spec, day: sampleDay, parentPosition: parent))
                    }
                    mission.trail.update(points: points, opacity: 0.88)
                    var lo = points[0], hi = points[0]
                    for p in points { lo = simd_min(lo, p); hi = simd_max(hi, p) }
                    mission.trailCenter = (lo + hi) / 2
                    mission.trailRadius = max(simd_length(hi - lo) / 2, 1.2)
                }
            }
        }

        // Satellites
        let propagation = propagationDay()
        let currentYear = Astro.decimalYear(day)
        let tleValid = tleUsable()
        satelliteOrbits.position = earth.node.position
        let satelliteScale = max(0.14, min(1.6, dist * 0.08))
        var bornSignature = ""
        for model in satModels {
            if model.isConstellation { bornSignature += "g\(model.aliveCount)" }
            else { bornSignature += (model.launchYear.map { currentYear >= Double($0) } ?? true) ? "1" : "0" }
        }
        if exploreView == .satellites, tleEpochDay != nil,
           (!tleValid) != noteOutOfRange || bornSignature != lastBornSignature {
            noteOutOfRange = !tleValid
            lastBornSignature = bornSignature
            DispatchQueue.main.async {
                self.updateSatelliteNote()
                self.listVersion += 1
                if case .satellite(let s) = self.selected { self.selectionSub = self.satelliteMeta(s) }
            }
        }
        for model in satModels {
            let born = model.launchYear.map { currentYear >= Double($0) } ?? true
            let isSelected = selected == .satellite(model)
            let shown = (isSelected || showAllSatellites) && !model.members.isEmpty && born
            model.node.isHidden = !shown
            model.orbitNode?.isHidden = !shown || model.isConstellation
            guard shown else { continue }
            if model.isConstellation {
                model.node.position = earth.node.position
                if model.constellationDay != day, time - model.lastConstellationUpdate > 0.07 {
                    updateConstellation(model, propagationDay: propagation, sceneYear: currentYear, sceneDay: day)
                    model.lastConstellationUpdate = time
                }
                model.node.opacity = tleValid ? 1 : 0.45
                model.node.isHidden = model.aliveCount == 0
                continue
            }
            guard let position = satellitePosition(model, day: propagation) else {
                model.node.isHidden = true
                model.orbitNode?.isHidden = true
                continue
            }
            model.node.position = SCNVector3(earth.node.position.simd3 + position)
            model.node.look(at: earth.node.position) // panneaux face à la Terre
            model.node.scale = SCNVector3(satelliteScale, satelliteScale, satelliteScale)
            if model.dimmed != !tleValid { // hors domaine SGP4 : silhouette estompée
                model.dimmed = !tleValid
                for m in model.dimmableMaterials { m.transparency = model.dimmed ? 0.45 : 1 }
            }
            if model.ringDay.isNaN || abs(day - model.ringDay) > 0.5 {
                buildSatelliteOrbit(model, aroundDay: propagation)
                model.ringDay = day
            }
        }

        // Lunes
        for system in moonSystems {
            system.group.position = system.planet.node.position
            let parentSelected = selected == .planet(system.planet)
            let moonSelected = system.moons.contains { selected == .moon($0) }
            let visible = parentSelected || moonSelected
            system.group.isHidden = !visible
            for moon in system.moons {
                moon.node.position = SCNVector3(moonLocalPosition(phase: moon.phase, period: moon.spec.period, radius: moon.spec.radius, day: day))
                if visible, trailStrength > 0.006 {
                    let span = min(abs(moon.spec.period) * 0.85, 2 + trailEnergy * 0.1)
                    var points: [SIMD3<Double>] = []
                    for k in 0..<72 {
                        let u = Double(k) / 71
                        let trailDay = day - trailDirection * span * u
                        let parent = planetPosition(system.planet.spec, day: trailDay)
                        points.append(parent + moonLocalPosition(phase: moon.phase, period: moon.spec.period, radius: moon.spec.radius, day: trailDay))
                    }
                    moon.trail.update(points: points, opacity: trailStrength * 0.85)
                } else {
                    moon.trail.update(points: [], opacity: 0)
                }
            }
        }

        // Lancement : une seule ascension, puis la trajectoire reste affichée
        if selectedLaunch != nil, !launchArcPoints.isEmpty {
            launchClock += dt
            goalDist = launchClock < Self.LAUNCH_DIVE ? 10 : 1.5 // recul puis plongée
            let rise = 3.4
            let progress = min(1, max(0, launchClock) / rise)
            if progress != launchProgressShown {
                launchProgressShown = progress
                let count = max(2, Int(Double(launchArcPoints.count) * progress))
                let visiblePoints = Array(launchArcPoints.prefix(count))
                if let core = Geo.lineGeometry(points: visiblePoints, color: (launchArcCore.geometry?.materials.first?.diffuse.contents as? UIColor) ?? .white) {
                    launchArcCore.geometry = core
                }
                if let glow = Geo.lineGeometry(points: visiblePoints, color: (launchArcGlow.geometry?.materials.first?.diffuse.contents as? UIColor) ?? .white, additive: true) {
                    launchArcGlow.geometry = glow
                }
                launchArcCore.isHidden = false
                launchArcGlow.isHidden = false
            }
            launchHead.isHidden = progress <= 0.004
            if !launchHead.isHidden {
                launchHead.position = SCNVector3(launchArcPoint(at: progress))
                let headScale = Float(max(0.35, min(2, dist * 0.28)))
                launchHead.scale = SCNVector3(headScale, headScale, headScale)
            }
        }

        // Battement lent du point de géolocalisation
        let pulse = 0.5 + 0.5 * sin(time * 2.1)
        let haloScale = Float(1 + pulse * 0.6)
        homeHalo.scale = SCNVector3(haloScale, haloScale, haloScale)
        homeHalo.opacity = CGFloat(0.62 - pulse * 0.34)
        let dotScale = Float(1 + pulse * 0.14)
        homeDot.scale = SCNVector3(dotScale, dotScale, dotScale)

        // Visée douce, continue et interrompable de la caméra
        if let goal = goalAz {
            let delta = atan2(sin(goal - az), cos(goal - az))
            az = smoothDamp(
                az, toward: az + delta, velocity: &azGoalVelocity,
                smoothTime: 0.48, deltaTime: dt
            )
            if abs(delta) < 0.0008, abs(azGoalVelocity) < 0.002 {
                az = goal
                goalAz = nil
                azGoalVelocity = 0
            }
        }
        if let goal = goalElev {
            let delta = goal - elev
            elev = smoothDamp(
                elev, toward: goal, velocity: &elevGoalVelocity,
                smoothTime: 0.48, deltaTime: dt
            )
            if abs(delta) < 0.0008, abs(elevGoalVelocity) < 0.002 {
                elev = goal
                goalElev = nil
                elevGoalVelocity = 0
            }
        }
        if let goal = goalRoll {
            let delta = atan2(sin(goal - roll), cos(goal - roll))
            roll = normalizedAngle(smoothDamp(
                roll, toward: roll + delta, velocity: &rollGoalVelocity,
                smoothTime: 0.48, deltaTime: dt
            ))
            if abs(delta) < 0.0008, abs(rollGoalVelocity) < 0.002 {
                roll = normalizedAngle(goal)
                goalRoll = nil
                rollGoalVelocity = 0
            }
        }

        // Cible de la caméra
        var focusIdentity: CameraFocusIdentity?
        if case .mission(let mission) = selected, !mission.node.isHidden, mission.trailRadius > 0 {
            focusTarget = mission.trailCenter // on cadre la trajectoire parcourue
            focusIdentity = .selection(.mission(mission))
            let aspect = Double(scnView.map { $0.bounds.width / max(1, $0.bounds.height) } ?? 1)
            let halfFov = 46.0 / 2 * Astro.DEG
            let verticalDistance = mission.trailRadius / tan(halfFov)
            let horizontalDistance = verticalDistance / max(0.55, aspect)
            goalDist = min(560, max(3, max(verticalDistance, horizontalDistance) * 1.25 * spacecraftZoomScale))
        } else if case .mission = selected {
            focusTarget = SIMD3()
            goalDist = 230
        } else if let launch = selectedLaunch, !launchArcPoints.isEmpty {
            if launchClock < Self.LAUNCH_DIVE {
                focusTarget = earth.node.position.simd3
            } else {
                let local = launchArcPoint(at: 0.45)
                focusTarget = earth.node.convertPosition(SCNVector3(local), to: nil).simd3
            }
            focusIdentity = .launch(launch.id)
        } else if let selection = selected {
            switch selection {
            case .planet(let p): focusTarget = p.node.position.simd3
            case .moon(let m): focusTarget = m.node.worldPosition.simd3
            case .mission(let m): focusTarget = m.node.position.simd3
            case .satellite(let s): focusTarget = s.node.position.simd3
            }
            focusIdentity = .selection(selection)
        } else {
            focusTarget = SIMD3()
        }

        // La cible suivie et le rig reçoivent exactement le même déplacement
        // orbital : l'astre reste verrouillé dans le cadre pendant le scrub.
        if let focusIdentity, focusIdentity == trackedFocus {
            target += focusTarget - previousFocusTarget
        } else if focusIdentity != trackedFocus {
            targetVelocity = SIMD3()
        }
        previousFocusTarget = focusTarget
        trackedFocus = focusIdentity
        target = smoothDamp(
            target, toward: focusTarget, velocity: &targetVelocity,
            smoothTime: focusIdentity == nil ? 0.58 : 0.42, deltaTime: dt
        )
        dist = smoothDamp(
            dist, toward: goalDist, velocity: &distVelocity,
            smoothTime: 0.5, deltaTime: dt
        )
        placeCamera()

        updateDateText()
        updateLabels()

        let showToday = dateTransition == nil && abs(day - Astro.todayDay) > 30
        if showToday != showTodayButton {
            DispatchQueue.main.async { self.showTodayButton = showToday }
        }
        if uiDirty {
            let top = handleTop
            DispatchQueue.main.async { self.handleTopPercent = top }
        }
    }

    private func updateConstellation(_ model: SatModel, propagationDay: Double, sceneYear: Double, sceneDay: Double) {
        var altitudeSum = 0.0, radiusSum = 0.0
        var alive = 0
        var points: [SIMD3<Double>] = []
        points.reserveCapacity(model.members.count)
        for member in model.members {
            var position: SIMD3<Double>? = nil
            if member.launchYear.map({ sceneYear >= Double($0) }) ?? true { // pas encore lancé sinon
                if let p = TLEParser.position(member, day: propagationDay) {
                    altitudeSum += simd_length(p) - Astro.EARTH_KM
                    alive += 1
                    let scenePos = eciToScene(p)
                    radiusSum += simd_length(scenePos)
                    position = scenePos
                }
            }
            points.append(position ?? SIMD3()) // au centre du globe = invisible
        }
        model.aliveCount = alive
        if alive > 0 {
            model.altitudeKm = altitudeSum / Double(alive)
            model.frameDist = max(5, radiusSum / Double(alive) * 2.8)
        }
        model.constellationDay = sceneDay
        let pointSize = max(0.02, min(0.35, dist * 0.014))
        model.node.geometry = Geo.pointsGeometry(
            points: points, color: uiColor(model.spec.color),
            sprite: constellationSprite,
            pointSize: CGFloat(pointSize), minScreenRadius: 1, maxScreenRadius: 7,
            additive: true
        )
    }

    private lazy var constellationSprite = ProceduralTexture.dotSprite()

    private func buildSatelliteOrbit(_ model: SatModel, aroundDay: Double) {
        guard let member = model.primary, let orbitNode = model.orbitNode else { return }
        // Période orbitale (min) déduite du moyen mouvement du TLE
        let n = member.satellite.tle.n₀ // rad/min
        guard n > 0 else { return }
        let minutes = Astro.TAU / n
        var points: [SIMD3<Double>] = []
        for k in 0...180 {
            let d = aroundDay + Double(k) * (minutes / 180) / 1440
            if let p = TLEParser.position(member, day: d) {
                points.append(eciToScene(p))
            }
        }
        guard points.count >= 8 else { return }
        orbitNode.geometry = Geo.lineGeometry(points: points, color: uiColor(model.spec.color))
    }

    // Étiquette de l'objet suivi (sonde ou satellite sélectionné)
    private func updateLabels() {
        var next: [LabelInfo] = []
        if let view = scnView {
            func project(_ node: SCNNode, _ text: String) {
                guard !node.isHidden else { return }
                let p = view.projectPoint(node.worldPosition)
                guard p.z > 0, p.z < 1 else { return }
                let x = CGFloat(p.x), y = CGFloat(p.y)
                guard x > -40, x < view.bounds.width + 40, y > -20, y < view.bounds.height + 20 else { return }
                next.append(LabelInfo(id: text, text: text, x: x, y: y))
            }
            if case .mission(let mission) = selected { project(mission.node, mission.spec.n) }
            if case .satellite(let model) = selected, !model.isConstellation { project(model.node, model.spec.n) }
        }
        if next != labels {
            DispatchQueue.main.async { self.labels = next }
        }
    }
}
