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
    /// Anneau d'orbite, retracé tant qu'il n'est pas refermé
    let orbitNode = SCNNode()
    var drawnSweep = -1.0
    var drawnRadius = -1.0
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
    /// Avancée de l'apparition, 0 à 1. Progression linéaire — un amortissement
    /// n'atteindrait jamais tout à fait 1 et le cercle resterait ouvert d'un cheveu.
    var appearance = 0.0
    init(planet: Planet) { self.planet = planet }
}

final class Mission {
    let spec: MissionSpec
    let node = SCNNode()
    /// Couleur de la pastille de sa ligne. La maquette et la trace la portent
    /// aussi : c'est ce qui relie la liste au ciel.
    let rampColor: UIColor
    let trail: TrailLine
    var trailCenter = SIMD3<Double>()
    var trailRadius = 0.0
    var lastTrailDay = Double.nan
    init(spec: MissionSpec, ramp: Double) {
        self.spec = spec
        rampColor = RampPalette.uiColor(at: ramp)
        trail = TrailLine(color: rampColor)
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
    /// Recul nécessaire pour tenir toute la constellation dans le cadre. Il n'est
    /// connu qu'une fois les membres propagés — d'où `frameApplied`, qui laisse le
    /// cadrage se corriger à la première mesure.
    var frameDist = 12.0
    var frameApplied = false
    var launchYear: Int?
    var dimmed = false
    var dimmableMaterials: [SCNMaterial] = []
    var constellationDay = Double.nan
    var lastConstellationUpdate: TimeInterval = 0
    var ringDay = Double.nan
    var isConstellation: Bool { spec.group != nil }
    /// Comme pour une sonde : nuage de points et anneau prennent la couleur de
    /// la pastille de la ligne.
    let rampColor: UIColor
    init(spec: SatSpec, ramp: Double) {
        self.spec = spec
        rampColor = RampPalette.uiColor(at: ramp)
    }
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

enum ExploreView: String { case none, missions, crewed, satellites, launches }

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
    private var zoomWaitsForLevel = false
    var panVelocityAz = 0.0, panVelocityElev = 0.0
    var dragging = false
    private var activeOrientationGestures = 0
    // Presque le pôle (89,5°) : la vue zénithale reste accessible, sans jamais
    // rendre l'axe de visée parallèle au vecteur « haut » (look-at dégénéré).
    private static let cameraElevationLimit = 1.562
    // Zoom sur un objet : au-delà de ~57° d'élévation le pôle nord glisse vers le
    // centre du cadre. On redresse d'abord à l'inclinaison de la vue par défaut.
    private static let uprightElevation = 0.58
    private static let uprightElevationThreshold = 1.0
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
    /// Part de la hauteur d'écran que le cartouche déplié recouvre. Elle variait
    /// autrefois : c'était toujours la moitié. Depuis que le cartouche épouse son
    /// texte, la zone libre change avec lui et la scène doit se recentrer dedans.
    private var detailCoverage = 0.5

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
    /// Marge minimale entre le cartouche et le bout de la piste
    static let HANDLE_EDGE = 6.0

    /// Position de repos du cartouche de date. « Aujourd'hui » tient le centre de
    /// la piste et ne bouge pas : c'est le cartouche qui se place par rapport à
    /// lui. Une date passée monte, une date future descend, et au-delà de ce que
    /// couvre l'échelle choisie il se plaque contre la borne — on continue de
    /// voyager dans le temps, mais le sens de lecture reste juste. Sans ça, juillet
    /// 1969 s'affichait sous « Aujourd'hui », comme s'il venait après 2026.
    func restTop(_ targetDay: Double) -> Double {
        let offset = (targetDay - Astro.todayDay) / dayRange * 100
        return max(Self.HANDLE_EDGE, min(100 - Self.HANDLE_EDGE, 50 + offset))
    }

    func restCenter(_ targetDay: Double) -> Double {
        targetDay - (restTop(targetDay) / 100 - 0.5) * dayRange
    }

    // Lancements
    var launchSpecs: [LaunchSpec] = fallbackLaunches
    var selectedLaunch: LaunchSpec?
    private var launchArcPoints: [SIMD3<Double>] = []
    private var launchArcLengths: [Double] = []
    private let launchArcCore = SCNNode()
    private let launchArcGlow = SCNNode()
    private let launchHead = SCNNode()
    private var launchClock = 0.0
    /// Recul, visée et défilement de la date menés ensemble (`arc`), plongée qui
    /// reprend le dézoom en route, puis la mise à feu une fois la caméra en place.
    private enum LaunchPhase { case arc, dive, hold, flight }
    private var launchPhase = LaunchPhase.arc
    private var launchMoonPush = 0.0, launchMoonPushVelocity = 0.0
    private var launchAimAz = 0.0, launchAimElev = 0.0
    private var launchProgressShown = -1.0
    /// Avancée de l'ascension (0…1), relue par le cadrage drone
    private var launchAscentProgress = 0.0
    /// Accrochage du drone : 0 la caméra pivote sur le centre du globe, 1 elle
    /// suit la fusée. Amorti, pour que la prise du pas de tir soit un glissement.
    private var launchFocusBlend = 0.0, launchFocusBlendVelocity = 0.0
    /// Le drone rend la main au globe dès qu'on reprend la timeline : pivoter sur
    /// la fusée pendant un défilement de date ferait valser le globe hors du cadre.
    private var launchDroneReleased = false
    private var launchHoldClock = 0.0
    /// Tremblement de la caméra : enfle pendant la retenue, s'éteint après le lâcher
    private var launchShake = 0.0
    private var timelineHapticStep: Double?
    private var launchCoreColor = UIColor.white
    private var launchTrailColor = UIColor.white
    private var launchTrailCamera = SIMD3<Double>()
    private lazy var flameTexture = ProceduralTexture.flameSprite()
    /// Demi-largeur du panache sous la fusée : plus étroit que la tête (rayon 0,012)
    private static let LAUNCH_TRAIL_WIDTH = 0.009
    // La plongée s'arrête à 4,2, au-delà de l'orbite de la Lune (3,1) : plus près
    // le champ horizontal (22° en portrait) ne tient plus l'écart oblique du
    // cadrage, le pas de tir sort par le bord. C'est donc la Lune qui s'écarte.
    static let LAUNCH_PULLBACK = 10.0, LAUNCH_DIVE_DIST = 4.2
    /// Rayon d'orbite de la Lune pendant un lancement : au-delà de la caméra
    /// (4,2) plus son propre rayon, elle ne peut plus passer devant le pas de tir.
    static let LAUNCH_MOON_RADIUS = 7.0
    /// Écart de visée sous lequel la plongée démarre sans attendre la fin du
    /// pivot : les deux mouvements se recouvrent au lieu de s'enchaîner.
    static let LAUNCH_AIM_HANDOFF = 0.25 // ~14°
    /// Vue drone : distance au pas de tir au moment de la mise à feu. La caméra
    /// s'en écarte ensuite jusqu'à LAUNCH_DIVE_DIST au rythme de l'ascension.
    static let LAUNCH_DRONE_DIST = 0.9
    /// Retenue au sol : le drone est posé, les moteurs montent en puissance, la
    /// fusée n'est pas encore lâchée. Assez long pour que le grondement s'installe.
    static let LAUNCH_HOLD = 1.5
    /// Amplitude du tremblement de caméra à l'instant du lâcher, en unités de scène
    static let LAUNCH_SHAKE = 0.011
    /// Durée du tracé d'une orbite de lune, de la lune au cercle refermé
    static let MOON_REVEAL = 1.6
    /// Effacement au dézoom : bien plus court que le tracé. Ce qu'on quitte n'a
    /// pas à se raconter, et l'anneau ne doit pas traîner sur l'astre suivant.
    static let MOON_HIDE = 0.28
    /// Durée de l'ascension — le grondement haptique court exactement dessus
    static let LAUNCH_RISE = 3.4

    // Rejeu d'un vol habité : même décollage que les lancements, puis la mission
    // se déroule jusqu'au retour.
    var playingMission: Mission?
    private var playedBeats = 0
    private var missionCoastClock = 0.0
    /// Durée du déroulé après l'ascension. Le temps n'y coule pas uniformément :
    /// il suit la répartition par phase du tracé, sinon trois jours de croisière
    /// mangeraient tout et les boucles lunaires passeraient en un éclair.
    static let MISSION_COAST = 38.0
    /// Fondu de la traînée d'ascension : à l'échelle Terre-Lune, les 400 km du
    /// décollage ne sont plus qu'un cil. On l'efface plutôt que de le laisser.
    /// Halo au pas de tir : la lueur qui enfle sous la poussée retenue, puis
    /// s'éteint quand le vaisseau s'arrache. C'est tout ce qui reste du ruban de
    /// lancement — la trajectoire de la mission part maintenant du sol elle-même,
    /// et une seule courbe vaut mieux que deux qui se recouvrent.
    private let padFlare = SCNNode()
    /// Reprise après l'ascension, 0 à 1. Le déroulé part exactement à la vitesse
    /// de sortie de l'ascension, puis monte en régime : sans ça, la capsule
    /// passait de 0,12 rad/s sur son arc à 2,9 rad/s sur l'orbite de parking —
    /// un facteur vingt-quatre en une image.
    private var missionCoastEase = 0.0
    /// Rapport entre la vitesse de sortie de l'ascension et le régime de croisière
    private var missionCoastFloor = 1.0
    /// Durée de la montée en régime, et du repli de la caméra sur la trajectoire
    /// Durée de la montée en régime. Elle couvre le premier tiers de l'orbite de
    /// parking : le vaisseau boucle son tour de Terre pendant que le temps prend
    /// sa vitesse de croisière, et tout est en régime bien avant l'allumage.
    static let COAST_RAMP = 6.0
    /// Exposant de l'ascension d'un vol habité : > 1, donc elle accélère, et sa
    /// vitesse de sortie vaut ce même facteur fois sa vitesse moyenne.
    static let ASCENT_EASE = 2.0
    /// Avancée de l'ascension à laquelle le panache commence à s'éteindre
    static let PLUME_OUT = 0.55
    /// Rayon du halo au pas de tir, à l'échelle 1. Il enfle jusqu'à deux fois
    /// cette taille — soit 3 % du rayon terrestre au plus fort, la lueur d'un
    /// pas de tir et non un champignon.
    static let PAD_FLARE_RADIUS = 0.018
    @Published var missionBeatLabel = ""
    @Published var playbackPaused = false
    /// Vitesse du rejeu. Elle porte aussi les haptiques : à ×4, le grondement du
    /// décollage dure le quart du temps, sinon il déborderait sur la croisière.
    @Published var playbackSpeed = 1.0
    /// ×0,5 existe pour les vols en orbite basse : Apollo-Soyouz boucle cent
    /// quarante-sept révolutions, et à vitesse nominale elles défilent trop vite
    /// pour qu'on en suive une.
    static let PLAYBACK_SPEEDS = [1.0, 2.0, 4.0, 0.5]

    /// La mission habitée en cours de sélection — c'est elle que pilote le
    /// contrôleur, qu'elle soit en train de se jouer ou à l'arrêt.
    var crewedSelection: Mission? {
        guard case .mission(let m) = selected, m.spec.crewed != nil else { return nil }
        return m
    }
    var playbackIsRunning: Bool { playingMission != nil && !playbackPaused }

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
    /// Onglet à rouvrir : on retrouve la section d'où vient la sélection
    private(set) var lastExploreSection: ExploreView = .missions
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
                let moon = MoonBody(spec: spec, phase: Double(index) * 1.7, planet: planet)
                moon.orbitNode.opacity = 0.08
                system.group.addChildNode(moon.orbitNode)
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

        // Sondes, puis vols habités : même maquette, même tracé — seule la
        // trajectoire change d'échelle.
        // Chaque onglet a son propre dégradé : une sonde et un vol habité ne se
        // lisent jamais côte à côte, leurs rangs sont donc comptés à part.
        for (index, spec) in (missionSpecs + crewedSpecs).enumerated() {
            let ramp = index < missionSpecs.count
                ? RampPalette.position(index, of: missionSpecs.count)
                : RampPalette.position(index - missionSpecs.count, of: crewedSpecs.count)
            let mission = Mission(spec: spec, ramp: ramp)
            let core = SCNNode(geometry: Geo.octahedron(radius: 0.75))
            let coreMaterial = SCNMaterial()
            coreMaterial.lightingModel = .blinn
            coreMaterial.diffuse.contents = mission.rampColor
            coreMaterial.emission.contents = mission.rampColor.withAlphaComponent(0.35)
            core.geometry!.materials = [coreMaterial]
            let glow = SCNNode(geometry: SCNSphere(radius: 1.55))
            let glowMaterial = SCNMaterial()
            glowMaterial.lightingModel = .constant
            glowMaterial.diffuse.contents = mission.rampColor
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
        for (index, spec) in satelliteSpecs.enumerated() {
            satModels.append(makeSatelliteModel(spec, ramp: RampPalette.position(index, of: satelliteSpecs.count)))
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
        // Un rayon de 0,055 mis à l'échelle 2,25 donnait une boule de 640 km de
        // rayon posée sur la Floride — une explosion nucléaire, pas un décollage.
        let flare = SCNSphere(radius: Self.PAD_FLARE_RADIUS)
        let flareMaterial = SCNMaterial()
        flareMaterial.lightingModel = .constant
        flareMaterial.diffuse.contents = UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1)
        flareMaterial.writesToDepthBuffer = false
        flareMaterial.blendMode = .add
        flare.materials = [flareMaterial]
        padFlare.geometry = flare
        padFlare.isHidden = true
        earth.node.addChildNode(padFlare)
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

    private func makeSatelliteModel(_ spec: SatSpec, ramp: Double) -> SatModel {
        let model = SatModel(spec: spec, ramp: ramp)
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
        // Avant leur lancement, la liste énumère des objets qui n'existent pas
        // encore : autant le dire plutôt que de laisser un ciel vide.
        if satModels.allSatisfy({ model in
            model.launchYear.map { Astro.decimalYear(day) < Double($0) } ?? false
        }) {
            satelliteNote = "Aucun satellite à cette date · revenir à aujourd'hui"
            return
        }
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

    /// Ligne à ramener sous les yeux quand on rouvre le panneau. Rouvrir la liste
    /// tout en haut alors qu'on suit Cassini oblige à re-parcourir vingt-six
    /// sondes à chaque aller-retour.
    var exploreAnchor: String? {
        switch exploreView {
        case .missions, .crewed:
            if case .mission(let m) = selected { return m.spec.n }
            return nil
        case .satellites:
            if case .satellite(let s) = selected { return s.spec.n }
            return nil
        case .launches: return selectedLaunch?.id
        case .none: return nil
        }
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
            // Pour un vol habité, les dates sont déjà lisibles sur la timeline ;
            // ce qu'on veut sous le nom, c'est qui était à bord.
            selectionSub = m.spec.crewed?.crew ?? m.spec.valid
        case .satellite(let s):
            selectionSub = satelliteMeta(s)
        case nil:
            selectionSub = "Explorer les orbites"
        }
        // Un satellite est cherché dans sa propre table d'abord : « Galileo »
        // nomme aussi bien la constellation que la sonde partie vers Jupiter.
        selectionDetail = selection.flatMap { sel in
            if case .satellite = sel { return satelliteInfo[sel.name] ?? infoText[sel.name] }
            return infoText[sel.name]
        }
        // Le cartouche ne bascule début/fin que pour les sondes. Un vol habité a
        // son contrôleur : deux façons de parcourir la même mission, dont une
        // invisible, ne valent pas mieux qu'une seule.
        selectionIsSpacecraft = {
            if case .mission(let m) = selection { return m.spec.crewed == nil }
            return false
        }()
        switch selection {
        case .mission(let m): lastExploreSection = m.spec.crewed == nil ? .missions : .crewed
        case .satellite: lastExploreSection = .satellites
        default: break
        }
        hasSelection = selection != nil
        // On remet d'abord l'horizon à plat (pôle nord en haut) : la boucle de
        // rendu ne lance le rapprochement qu'une fois le roulis revenu à zéro.
        if selection != nil {
            // L'azimut est conservé : c'est lui qui cadre le bon côté de l'astre.
            if abs(elev) > Self.uprightElevationThreshold {
                goalElev = elev < 0 ? -Self.uprightElevation : Self.uprightElevation
                elevGoalVelocity = 0
            }
            goalRoll = uprightRoll(
                azimuth: goalAz ?? az, elevation: goalElev ?? elev,
                axis: selectionAxis(selection)
            )
            zoomWaitsForLevel = true
        }
        switch selection {
        // La caméra pivote autour de l'astre : on recule assez pour que la lune
        // ou le satellite reste dans le cadre tout au long de son orbite.
        case .moon(let m): goalDist = min(60, max(9, frameDistance(radius: m.spec.radius, margin: 1.08)))
        case .satellite(let s):
            if s.isConstellation, s.frameDist > 0 {
                goalDist = s.frameDist
                // À la première sélection, `frameDist` vaut encore sa valeur par
                // défaut : la constellation n'a jamais été propagée. La boucle de
                // rendu corrigera dès qu'elle l'aura mesurée.
                s.frameApplied = false
            } else {
                // Rayon de l'orbite dans la scène, borné au voisinage terrestre :
                // le nœud du satellite peut encore être à sa position de la veille.
                let orbit = satellitePosition(s, day: propagationDay()).map(simd_length)
                    ?? Astro.orbitSceneRadius(km: Astro.EARTH_KM + (s.altitudeKm ?? 400))
                let radius = min(4, max(Astro.EARTH_RADIUS, orbit))
                goalDist = max(5, frameDistance(radius: radius, margin: 1.15))
            }
        case .mission(let m): goalDist = m.spec.crewed == nil ? 34 : 11
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
        if view != exploreView { view == .none ? Haptics.shared.closed() : Haptics.shared.opened() }
        // Ouvrir l'explorateur, c'est passer à autre chose : le rejeu s'arrête là
        // où il en est. Sinon la mission continue de faire défiler la date
        // derrière le panneau, et « Aujourd'hui » reste caché alors que c'est
        // précisément la sortie dont on a besoin.
        if view != .none { stopMissionPlayback(clearSelection: false) }
        if view != .none { lastExploreSection = view }
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

    /// Rejouer un vol habité : le décollage depuis son vrai pas de tir, puis la
    /// mission jusqu'au retour. C'est la même grammaire qu'un lancement — recul,
    /// plongée du drone, retenue, mise à feu — prolongée par le voyage.
    func playMission(_ mission: Mission) {
        guard let c = mission.spec.crewed else { return selectMission(mission) }
        Haptics.shared.picked()
        Haptics.shared.prepare()
        stopMissionPlayback(clearSelection: false)
        playingMission = mission
        selectedLaunch = nil
        setSelected(.mission(mission))
        exploreView = .none
        lastExploreSection = .crewed
        playedBeats = 0
        missionCoastClock = 0
        missionCoastEase = 0
        missionCoastFloor = 1
        missionBeatLabel = ""
        playbackPaused = false
        // Le décollage se joue à l'échelle de la seconde : la timeline se cale
        // sur la date de tir et s'y arrête.
        let launchDay = c.launchDay
        dateTransition = nil
        timelineVelocity = 0
        edgeDirection = 0
        day = launchDay
        // Une mission se joue à l'heure : c'est l'échelle où la date affiche
        // « 16 juil. 13:32 » plutôt qu'un jour entier, et où l'on voit vraiment
        // le temps avancer pendant le décollage.
        setDayRange(4.2, short: "H")
        timelineCenter = restCenter(day)
        handleTop = restTop(day)
        handleTopPercent = handleTop
        updateDateText(force: true)

        padFlare.position = SCNVector3(Astro.geoToLocal(
            lat: c.site.lat, lon: c.site.lon, radius: Astro.EARTH_RADIUS * 0.995))
        padFlare.isHidden = true
        launchClock = 0
        launchPhase = .arc
        launchProgressShown = -1
        launchAscentProgress = 0
        launchFocusBlend = 0
        launchFocusBlendVelocity = 0
        launchDroneReleased = false
        launchHoldClock = 0

        // Visée : même cadrage oblique que pour un lancement, le pas de tir dans
        // la moitié haute et la montée vers le haut de l'écran.
        let normal = simd_normalize(Astro.geoToLocal(lat: c.site.lat, lon: c.site.lon, radius: 1))
        let arrival = earthTilt * simd_quatd(angle: Astro.gmst(launchDay), axis: SIMD3(0, 1, 0))
        let heading = arrival.act(normal)
        launchAimAz = atan2(heading.x, heading.z) + 0.22
        launchAimElev = max(-1.1, min(1.1, asin(max(-1, min(1, heading.y))) - 0.52))
        goalDist = Self.LAUNCH_PULLBACK
        aimUpright(launchAimAz, launchAimElev)
        zoomWaitsForLevel = false
    }

    /// Lecture / pause. À l'arrêt, la lecture repart du pas de tir : un vol
    /// habité n'a pas de « reprendre » à mi-course une fois terminé.
    func playbackToggle() {
        guard let mission = crewedSelection else { return }
        if playingMission == nil { return playMission(mission) }
        playbackPaused.toggle()
        Haptics.shared.picked()
    }

    /// Revenir au décollage : la séquence entière se rejoue.
    func playbackRestart() {
        guard let mission = crewedSelection else { return }
        playMission(mission)
    }

    /// Aller à la fin : la mission accomplie, trajectoire entière à l'écran.
    func playbackToEnd() {
        guard let mission = crewedSelection, let c = mission.spec.crewed else { return }
        Haptics.shared.picked()
        stopMissionPlayback(clearSelection: false)
        let end = c.launchDay + c.days
        animateDate(to: end, top: restTop(end), center: restCenter(end))
        if let last = crewedBeats(c).last { announce(last.label) }
    }

    /// Vitesse suivante, en boucle.
    func playbackCycleSpeed() {
        Haptics.shared.picked()
        let speeds = Self.PLAYBACK_SPEEDS
        let index = speeds.firstIndex(of: playbackSpeed) ?? 0
        playbackSpeed = speeds[(index + 1) % speeds.count]
    }

    /// Sortir du rejeu : dès qu'on touche à la timeline ou qu'on choisit autre chose.
    func stopMissionPlayback(clearSelection: Bool = true) {
        guard playingMission != nil else { return }
        playingMission = nil
        playedBeats = 0
        playbackPaused = false
        missionBeatLabel = ""
        padFlare.isHidden = true
        launchShake = 0
        if clearSelection, case .mission = selected { setSelected(selected) }
    }

    func selectMission(_ mission: Mission) {
        stopMissionPlayback(clearSelection: false)
        Haptics.shared.picked()
        // Sonde hors de sa période : on cale la date sur sa borne, sinon il n'y a rien à voir
        let bounds = missionDayRange(mission.spec)
        let first = bounds.first
        let last = bounds.last
        let today = Astro.todayDay
        var targetDay = day >= first && day <= last ? day
            : today >= first && today <= last ? today
            : day < first ? first : last
        // Un vol habité se joue en jours, parfois en minutes : à l'échelle de
        // l'année la mission entière tient dans l'épaisseur du curseur. On
        // resserre la timeline, et on part du décollage.
        if let c = mission.spec.crewed {
            targetDay = c.launchDay
            let wanted: (Double, String) = c.days < 0.5 ? (4.2, "H") : (100, "J")
            if dayRange > wanted.0 { setDayRange(wanted.0, short: wanted.1) }
        }
        if targetDay != day {
            animateDate(to: targetDay, top: restTop(targetDay), center: restCenter(targetDay))
        }
        let parentPos = mission.spec.parent.flatMap { name in
            planets.first { $0.spec.name == name }.map { planetPosition($0.spec, day: targetDay) }
        }
        let place = missionPosition(mission.spec, day: targetDay, parentPosition: parentPos)
        aimCamera(atan2(place.x, place.z) + .pi / 2, 0.42)
        setSelected(.mission(mission))
    }

    func selectSatellite(_ model: SatModel) {
        Haptics.shared.picked()
        stopMissionPlayback(clearSelection: false)
        // Satellite hors de son époque : on revient à aujourd'hui, sinon il n'y a
        // rien à voir. Même règle que pour une sonde hors de sa période — et le
        // cas se produit dès qu'on vient de rejouer un vol habité, qui laisse la
        // scène en 1961 où aucun satellite n'a encore été lancé.
        if let born = model.launchYear, Astro.decimalYear(day) < Double(born) {
            // L'échelle d'abord : `setDayRange` remet la transition à zéro, et
            // appelée après elle effacerait le voyage qu'on vient de lancer.
            if dayRange < 100 { setDayRange(100, short: "J") }
            let today = Astro.todayDay
            animateDate(to: today, top: restTop(today), center: restCenter(today))
        }
        setSelected(.satellite(model))
        // se placer du côté du satellite, sinon il se retrouve derrière la Terre
        if !model.isConstellation, let offset = satellitePosition(model, day: propagationDay()), simd_length_squared(offset) > 0 {
            let elevGoal = min(1.25, max(0.12, asin(offset.y / simd_length(offset)) + 0.12))
            aimUpright(atan2(offset.x, offset.z) + 0.3, elevGoal)
        } else {
            aimUpright(1.05, 0.32)
        }
        exploreView = .none
    }

    func selectLaunch(_ launch: LaunchSpec) {
        Haptics.shared.picked()
        Haptics.shared.prepare() // le grondement arrive dans quelques secondes
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
        // Le rang du lancement dans sa liste, pour que l'arc sorte de la même
        // couleur que la pastille qu'on vient de toucher.
        let rank = launchSpecs.firstIndex(of: launch) ?? 0
        buildLaunchArc(points: points,
                       color: RampPalette.uiColor(at: RampPalette.position(rank, of: launchSpecs.count)))
        exploreView = .none
        lastExploreSection = .launches
        launchClock = 0
        launchPhase = .arc
        launchProgressShown = -1
        launchAscentProgress = 0
        launchFocusBlend = 0
        launchFocusBlendVelocity = 0
        launchDroneReleased = false
        launchHoldClock = 0
        let targetDay = Astro.day(from: launch.date)
        animateDate(to: targetDay, top: restTop(targetDay), center: restCenter(targetDay))
        // Le globe aura tourné d'ici la date de tir : on vise son orientation d'arrivée
        let arrival = earthTilt * simd_quatd(angle: Astro.gmst(targetDay), axis: SIMD3(0, 1, 0))
        let heading = arrival.act(normal)
        // La caméra pivote autour du centre du globe : elle se place face au pas
        // de tir, sinon le site part derrière le limbe. Mais franchement de face
        // l'ascension se ferait vers l'œil et la courbe s'écraserait sur le sol,
        // d'où le décalage oblique ci-dessous.
        let siteElevation = asin(max(-1, min(1, heading.y)))
        // Caméra un cran sous le pas de tir : le site remonte dans la moitié haute
        // du cadre et la fusée s'élève vers le haut de l'écran au lieu de venir
        // vers l'œil. ~32° d'écart au total, la courbe se lit sans coller au limbe.
        // L'écart est porté surtout par l'élévation : en portrait le cadre n'offre
        // que ±11° en largeur contre ±23° en hauteur, et le mettre en azimut
        // poussait le pas de tir contre le bord gauche.
        launchAimAz = atan2(heading.x, heading.z) + 0.22
        launchAimElev = max(-1.1, min(1.1, siteElevation - 0.52))
        goalDist = Self.LAUNCH_PULLBACK // on prend du recul le temps que la date défile
        // Le pivot part en même temps que le recul : la caméra contourne le globe
        // pendant qu'elle s'en éloigne, au lieu d'attendre le dézoom. La visée
        // porte déjà le redressement, on lève donc le verrou qui gèle le zoom.
        aimUpright(launchAimAz, launchAimElev)
        zoomWaitsForLevel = false
        launchListVersion += 1
    }

    /// Plus grand écart angulaire restant sur la visée, tous axes confondus.
    /// Vaut 0 quand le pivot est fini — il continue pendant la plongée.
    private var launchAimResidual: Double {
        var worst = 0.0
        if let goal = goalAz { worst = max(worst, abs(atan2(sin(goal - az), cos(goal - az)))) }
        if let goal = goalElev { worst = max(worst, abs(goal - elev)) }
        if let goal = goalRoll { worst = max(worst, abs(atan2(sin(goal - roll), cos(goal - roll)))) }
        return worst
    }

    /// Portion d'orbite déjà tracée. Le trait se déroule *derrière* la lune et se
    /// termine sur elle : à chaque instant la lune coiffe l'extrémité de l'arc.
    ///
    /// L'anneau ne suit pas la vraie trajectoire, et c'est délibéré. L'ondulation
    /// réelle vaut `sin(a · 0,7)` : de période non entière sur un tour, elle ne se
    /// referme pas — après 2π le trait revient à une autre altitude et rate la
    /// lune, ce qui se lit comme un défaut d'affichage. On lui substitue
    /// `y_lune · cos(a − tête)`, un cercle incliné : périodique donc parfaitement
    /// refermé, et qui passe exactement par la lune à l'instant du tracé.
    private func orbitArc(_ moon: MoonBody, radius: Double, sweep: Double) -> SCNGeometry? {
        guard sweep > 0.004 else { return nil }
        let head = moonAngle(phase: moon.phase, period: moon.spec.period, day: day)
        let lift = sin(head * 0.7) * 0.18 // hauteur de la lune à cet instant
        let steps = max(2, Int(72 * sweep))
        let points = (0...steps).map { k -> SIMD3<Double> in
            // k = steps tombe pile sur la lune ; la queue recule à mesure que
            // l'arc s'allonge, et le cercle se referme sur elle.
            let a = head - Astro.TAU * sweep * (1 - Double(k) / Double(steps))
            return SIMD3(cos(a) * radius, lift * cos(a - head), sin(a) * radius)
        }
        return Geo.lineGeometry(points: points, color: uiColor(0xdce0ff))
    }

    private func buildLaunchArc(points: [SIMD3<Double>], color: UIColor) {
        launchArcPoints = points
        launchArcLengths = [0]
        for i in 1..<points.count {
            launchArcLengths.append(launchArcLengths[i - 1] + simd_length(points[i] - points[i - 1]))
        }
        var r = CGFloat(0), g = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let white = 0.55
        launchCoreColor = UIColor(red: r + (1 - r) * white, green: g + (1 - g) * white, blue: b + (1 - b) * white, alpha: 1)
        launchTrailColor = color
        // Rien n'est dessiné avant la mise à feu : la trajectoire se trace
        // derrière la fusée, elle n'est jamais montrée puis effacée.
        launchArcCore.geometry = nil
        launchArcGlow.geometry = nil
        launchArcCore.isHidden = true
        launchArcGlow.isHidden = true
        launchArcGlow.opacity = 1
        launchTrailCamera = SIMD3()
        if let headMaterial = launchHead.geometry?.materials.first { headMaterial.diffuse.contents = launchCoreColor }
        if let haloMaterial = launchHead.childNodes.first?.geometry?.materials.first { haloMaterial.diffuse.contents = color }
    }

    /// Traînée visible : les points parcourus, terminés exactement sous la tête.
    /// Même paramétrage que `launchArcPoint(at:)`, donc aucun décalage entre la
    /// fusée et sa traînée.
    private func launchArcVisiblePoints(upTo progress: Double) -> [SIMD3<Double>] {
        guard let total = launchArcLengths.last, total > 0, launchArcPoints.count >= 2 else { return [] }
        let goal = max(0, min(1, progress)) * total
        var points = [launchArcPoints[0]]
        var i = 1
        while i < launchArcPoints.count, launchArcLengths[i] < goal {
            points.append(launchArcPoints[i])
            i += 1
        }
        points.append(launchArcPoint(at: progress))
        return points
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

    /// Axe de rotation de l'astre visé, en coordonnées de scène. Seule la Terre
    /// est inclinée (23,44°) ; ailleurs l'axe est déjà la verticale du monde.
    private func selectionAxis(_ selection: Selection?) -> SIMD3<Double> {
        switch selection {
        case .planet(let p) where p === earth: return earthTilt.act(SIMD3(0, 1, 0))
        case .moon(let m) where m.planet === earth: return earthTilt.act(SIMD3(0, 1, 0))
        case .satellite: return earthTilt.act(SIMD3(0, 1, 0))
        default: return SIMD3(0, 1, 0)
        }
    }

    /// Roulis qui remet cet axe à la verticale de l'écran : pôle nord en haut,
    /// quelle que soit la position de la caméra autour de l'astre.
    private func uprightRoll(azimuth: Double, elevation: Double, axis: SIMD3<Double>) -> Double {
        let offset = SIMD3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
        let forward = -simd_normalize(offset)
        let right = simd_cross(forward, SIMD3(0.0, 1.0, 0.0))
        guard simd_length_squared(right) > 1e-9 else { return 0 }
        let unitRight = simd_normalize(right)
        let up = simd_cross(unitRight, forward)
        let a = simd_normalize(axis)
        // θ = angle de l'axe à l'écran, compté depuis la verticale vers la droite.
        // Le roulis tourne l'image dans l'autre sens : on rend son opposé.
        return -atan2(simd_dot(a, unitRight), simd_dot(a, up))
    }

    /// Visée + redressement : l'astre arrive cadré, pôle nord en haut.
    func aimUpright(_ targetAz: Double, _ targetElev: Double) {
        aimCamera(targetAz, targetElev)
        goalRoll = uprightRoll(azimuth: targetAz, elevation: targetElev, axis: selectionAxis(selected))
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

    func setDetailCoverage(_ fraction: Double) {
        detailCoverage = max(0, min(0.85, fraction))
    }

    /// Recul nécessaire pour qu'un disque de rayon `radius` centré à l'écran
    /// tienne dans le cadre, portrait compris.
    func frameDistance(radius: Double, margin: Double = 1.1) -> Double {
        // Portrait : c'est la largeur qui contraint, d'où l'aspect réel (et non
        // un plancher à 0,55 qui laissait la lune déborder sur le côté).
        let aspect = Double(scnView.map { $0.bounds.width / max(1, $0.bounds.height) } ?? 1)
        let halfFov = 46.0 / 2 * Astro.DEG
        let vertical = radius / tan(halfFov)
        let horizontal = vertical / max(0.42, aspect)
        return max(vertical, horizontal) * margin
    }

    func placeCamera() {
        var eye = SIMD3(
            target.x + sin(az) * cos(elev) * dist,
            target.y + sin(elev) * dist,
            target.z + cos(az) * cos(elev) * dist
        )
        if launchShake > 1e-5 {
            // Trois fréquences incommensurables (~15 à 21 Hz) : le motif ne se
            // répète pas, la caméra vibre au lieu d'osciller. Le décalage est
            // appliqué avant la visée, donc la scène tangue légèrement aussi.
            let t = lastFrameTime
            eye.x += launchShake * sin(t * 97)
            eye.y += launchShake * sin(t * 131 + 1.7)
            eye.z += launchShake * sin(t * 113 + 3.1)
        }
        cameraNode.position = SCNVector3(eye)
        // Le roulis est ajouté dans le repère local de la caméra, à partir d'une
        // base recalculée du vecteur haut du monde. Sans ce `up:` explicite,
        // `look(at:)` repart de l'orientation déjà roulée et le roulis
        // s'additionne d'une image sur l'autre : la vue part en toupie.
        let localRoll = simd_quatf(angle: Float(roll), axis: SIMD3<Float>(0, 0, 1))
        func aim(at point: SIMD3<Double>) {
            cameraNode.look(
                at: SCNVector3(point),
                up: SCNVector3(0, 1, 0),
                localFront: SCNVector3(0, 0, -1)
            )
            cameraNode.simdOrientation = simd_normalize(cameraNode.simdOrientation * localRoll)
        }
        aim(at: target)

        guard detailExpansionProgress > 0.001, selected != nil else { return }
        // L'astre se cale au centre de ce que le cartouche laisse libre. Viser
        // sous lui d'une hauteur `demi-frustum × recouvrement` l'y amène : avec un
        // recouvrement d'une demi-hauteur, on retrouve exactement l'ancien
        // cadrage au quart supérieur, mais il suit maintenant la taille réelle.
        let verticalHalfSpan = dist * tan(46.0 / 2 * Astro.DEG)
        let offset = verticalHalfSpan * detailCoverage * detailExpansionProgress
        aim(at: target - cameraNode.worldUp.simd3 * offset)
    }

    // Gestes (appelés du fil principal)
    func panBegan() {
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
        activeOrientationGestures = max(0, activeOrientationGestures - 1)
        dragging = activeOrientationGestures > 0
        if allowsInertia, activeOrientationGestures == 0 {
            // Près du pôle, une rotation d'azimut fait tourner la vue sur
            // elle-même : on éteint l'inertie horizontale à mesure qu'on monte,
            // sinon un flick vu de dessus part en toupie.
            let horizonFactor = max(0, cos(elev))
            panVelocityAz = max(-1.8, min(1.8, -velocityX * 0.007)) * horizonFactor
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
        zoomWaitsForLevel = false // un zoom au doigt répond tout de suite
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

        // Une lune en train de s'effacer reste à l'écran un instant : on cesse de
        // la proposer au doigt bien avant qu'elle ait fini de disparaître.
        for system in moonSystems where system.appearance > 0.5 {
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
        if selectedLaunch != nil {
            // Sortir d'un lancement remonte d'un cran, comme pour un satellite :
            // on retrouve la Terre, pas le système solaire.
            Haptics.shared.dismissed()
            dismissLaunch(selecting: best?.selection ?? .planet(earth))
        } else if let best {
            if best.selection != selected {
                Haptics.shared.selected()
                setSelected(best.selection)
            }
        } else if selected != nil {
            Haptics.shared.dismissed()
            reset()
        }
    }

    /// Referme la trajectoire de lancement et rend la main à l'astre.
    func dismissLaunch(selecting selection: Selection) {
        selectedLaunch = nil
        launchArcCore.isHidden = true
        launchArcGlow.isHidden = true
        launchHead.isHidden = true
        launchListVersion += 1
        setSelected(selection)
    }

    // Cartouche : bascule début/fin de mission pour une sonde sélectionnée.
    // Les vols habités en sont exclus — c'est le contrôleur qui les parcourt.
    func infoCardTapped() {
        guard case .mission(let mission) = selected, mission.spec.crewed == nil else { return }
        timelineVelocity = 0
        let bounds = missionDayRange(mission.spec)
        if missionDateEndpoint == "start" {
            let targetDay = bounds.first
            animateDate(to: targetDay, top: restTop(targetDay), center: restCenter(targetDay))
            missionDateEndpoint = "end"
        } else {
            let targetDay = bounds.last
            animateDate(to: targetDay, top: restTop(targetDay), center: restCenter(targetDay))
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
        animateDate(to: targetDay, top: restTop(targetDay), center: restCenter(targetDay))
    }

    private var dragStartTop = 50.0
    private var lastSlideDay = 0.0
    private var lastSlideTime: TimeInterval = 0

    /// Vrai de la sélection du lancement à la fin de l'ascension : la date est
    /// verrouillée sur celle du tir, et le drone garde la main sur le cadrage.
    private var launchSequenceRunning: Bool {
        if playingMission != nil { return launchAscentProgress < 1 }
        return selectedLaunch != nil && !launchArcPoints.isEmpty && launchAscentProgress < 1
    }

    func timelineDragBegan() {
        guard !launchSequenceRunning else { return Haptics.shared.refused() }
        Haptics.shared.grabbed()
        // Reprendre la timeline reprend la main sur le déroulé : le rejeu
        // s'arrête là où il en est, la trajectoire tracée reste affichée.
        stopMissionPlayback(clearSelection: false)
        launchDroneReleased = true
        dateTransition = nil
        timelineVelocity = 0
        dragStartTop = handleTop
        lastSlideDay = day
        lastSlideTime = CACurrentMediaTime()
    }

    func timelineDragChanged(offsetY: Double, height: Double) {
        guard !launchSequenceRunning else { return Haptics.shared.refused() }
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
        guard !launchSequenceRunning else { return }
        edgeDirection = 0
        if abs(timelineVelocity) < 0.003 { timelineVelocity = 0 }
    }

    func setDayRange(_ range: Double, short: String) {
        Haptics.shared.picked()
        dateTransition = nil
        timelineVelocity = 0
        edgeDirection = 0
        dayRange = range
        timelineCenter = restCenter(day)
        handleTop = restTop(day)
        handleTopPercent = handleTop
        scaleShort = short
        updateDateText(force: true)
    }

    func jump(toDay targetDay: Double) {
        animateDate(to: targetDay, top: restTop(targetDay), center: restCenter(targetDay))
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

        // Cran haptique de la timeline : un tic par pas franchi. Nos propres
        // animations de date sont exclues, sinon un saut sur la date de tir
        // déclencherait une rafale.
        if dateTransition == nil, dayRange > 0 {
            let step = (day / (dayRange / 48)).rounded(.down)
            if let previous = timelineHapticStep, previous != step { Haptics.shared.tick() }
            timelineHapticStep = step
        } else {
            timelineHapticStep = nil
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
            let playing = playingMission === mission
            let visible = (isSelected || showAllMissions) && missionIsValid(mission.spec, day: day)
            mission.node.isHidden = !visible
            // Rien de spécial pendant l'ascension : la trajectoire d'un vol habité
            // part du pas de tir, la sonde n'a qu'à la suivre.
            let parentPos = mission.spec.parent.flatMap { name in
                planets.first { $0.spec.name == name }?.node.position.simd3
            }
            mission.node.position = SCNVector3(missionPosition(mission.spec, day: day, parentPosition: parentPos))
            mission.node.eulerAngles.y += Float(dt * 0.8)
            // Taille écran constante. Le plancher de 0,06 existe pour qu'une sonde
            // lointaine ne disparaisse pas ; en vue drone, à 0,9 du pas de tir, il
            // en ferait un rocher posé sur le pas de tir. On le lève pendant le
            // rejeu — la sonde grossit alors au rythme où la caméra s'écarte.
            let screen = min(3, dist * 0.0059)
            let scale = Float((playing ? screen : max(0.06, screen)) * (isSelected ? 1.35 : 1))
            mission.node.scale = SCNVector3(scale, scale, scale)
            guard isSelected, visible else {
                mission.trail.update(points: [], opacity: 0)
                mission.trailRadius = 0
                continue
            }
            if mission.lastTrailDay != day {
                mission.lastTrailDay = day
                let bounds = missionDayRange(mission.spec)
                let endDay = min(day, bounds.last)
                let originDay = bounds.first
                // Une sonde en orbite ne montre que sa dernière révolution — et
                // un vol en orbite basse aussi : les cent quarante-huit tours
                // d'Apollo-Soyouz repassent tous par le même cercle.
                var cycle = mission.spec.orbit.map { $0[3] * 365.25 } ?? mission.spec.local.map { 1 / $0[1] } ?? 0
                // Un vol en orbite basse ne montre que sa dernière révolution : les
                // suivantes repassent exactement par le même cercle. La période
                // prise ici est celle *dessinée*, plafonnée, pas la vraie.
                if case .earthOrbit(_, let period)? = mission.spec.crewed?.profile,
                   let c = mission.spec.crewed {
                    let span = max(1e-9, c.days - crewedAscentDays(c))
                    cycle = span / min(span / (period / 1440), Crewed.MAX_ORBIT_LOOPS)
                }
                let startDay = max(originDay, cycle > 0 ? endDay - cycle * 1.15 : -1e9)
                if endDay >= startDay {
                    // Une boucle lunaire enroulée huit fois demande plus de points
                    // qu'une ellipse d'une décennie.
                    let samples = mission.spec.crewed != nil ? 720 : 320
                    var points: [SIMD3<Double>] = []
                    points.reserveCapacity(samples)
                    // Vol lunaire : les points sont répartis par phase, sinon
                    // l'orbite de parking se réduit à un triangle.
                    let lunarSampling: (crewed: CrewedSpec, from: Double, to: Double)? = {
                        guard let c = mission.spec.crewed, case .lunar = c.profile else { return nil }
                        return (c, crewedSampleProgress(c, day: originDay),
                                crewedSampleProgress(c, day: endDay))
                    }()
                    for k in 0..<samples {
                        let u = Double(k) / Double(samples - 1)
                        let sampleDay = lunarSampling.map {
                            crewedSampleDay($0.crewed, at: $0.from + ($0.to - $0.from) * u)
                        } ?? startDay + (endDay - startDay) * u
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
        // Pendant un lancement la caméra finit à 4,2 du globe, au-delà de l'orbite
        // lunaire : quand la Lune passe dans l'axe elle bouche le pas de tir de
        // tout près. Elle s'écarte donc, en glissant, le temps de la séquence.
        launchMoonPush = smoothDamp(
            launchMoonPush, toward: selectedLaunch == nil ? 0 : 1,
            velocity: &launchMoonPushVelocity, smoothTime: 0.9, deltaTime: dt
        )
        // Le tracé doit se refermer après le rapprochement, dont la durée dépend
        // du chemin parcouru — une durée fixe ne suffirait pas. Plutôt que de le
        // retenir à un palier, ce qui le fige puis le fait repartir, on le
        // ralentit continûment tant que la caméra a du chemin devant elle. Il
        // n'arrête jamais d'avancer et reprend sa cadence à mesure qu'elle se pose.
        let travel = min(1, abs(dist - goalDist) / max(0.001, goalDist))
        let revealRate = dt / (Self.MOON_REVEAL * (1 + 1.5 * travel))
        for system in moonSystems {
            system.group.position = system.planet.node.position
            let parentSelected = selected == .planet(system.planet)
            let moonSelected = system.moons.contains { selected == .moon($0) }
            // Suivre Apollo 11 sans la Lune n'aurait aucun sens : c'est la seule
            // chose vers laquelle la capsule se dirige.
            let lunarFlight: Bool = {
                guard system.planet === earth, case .mission(let m)? = selected,
                      case .lunar? = m.spec.crewed?.profile else { return false }
                return true
            }()
            // Les lunes et leurs orbites ne surgissent pas : la lune paraît, puis
            // son orbite s'enroule devant elle jusqu'à refermer le cercle.
            let wanted = (parentSelected || moonSelected || lunarFlight) ? 1.0 : 0.0
            // Le ralentissement lié au voyage de la caméra ne vaut qu'à l'aller :
            // au dézoom il ferait justement traîner l'anneau le plus longtemps.
            let rate = wanted > 0 ? revealRate : dt / Self.MOON_HIDE
            system.appearance += max(-rate, min(rate, wanted - system.appearance))
            let visible = system.appearance > 0.004
            system.group.isHidden = !visible
            // Le trait accélère puis ralentit en se refermant ; la lune, elle,
            // est là tout de suite — c'est d'elle que part le tracé.
            // Décélération vers la fermeture, sans temps mort au démarrage :
            // le ralentissement du début est déjà porté par `revealRate`.
            let p = system.appearance
            let sweep = p * (2 - p)
            let bodyOpacity = CGFloat(min(1, p * 3))
            let push = system.planet === earth ? launchMoonPush : 0
            for moon in system.moons {
                let radius = moon.spec.radius + (Self.LAUNCH_MOON_RADIUS - moon.spec.radius) * push
                moon.node.position = SCNVector3(moonLocalPosition(phase: moon.phase, period: moon.spec.period, radius: radius, day: day))
                moon.node.opacity = bodyOpacity
                if abs(sweep - moon.drawnSweep) > 0.004 || abs(radius - moon.drawnRadius) > 0.001 {
                    moon.drawnSweep = sweep
                    moon.drawnRadius = radius
                    moon.orbitNode.geometry = orbitArc(moon, radius: radius, sweep: sweep)
                }
                if visible, trailStrength > 0.006 {
                    let span = min(abs(moon.spec.period) * 0.85, 2 + trailEnergy * 0.1)
                    var points: [SIMD3<Double>] = []
                    for k in 0..<72 {
                        let u = Double(k) / 71
                        let trailDay = day - trailDirection * span * u
                        let parent = planetPosition(system.planet.spec, day: trailDay)
                        points.append(parent + moonLocalPosition(phase: moon.phase, period: moon.spec.period, radius: radius, day: trailDay))
                    }
                    moon.trail.update(points: points, opacity: trailStrength * 0.85 * sweep)
                } else {
                    moon.trail.update(points: [], opacity: 0)
                }
            }
        }

        // Rejeu d'un vol habité : le décollage, puis la mission jusqu'au retour
        if let mission = playingMission, let c = mission.spec.crewed {
            updateMissionPlayback(mission, c, dt: dt)
        }

        // Lancement : une seule ascension, puis la trajectoire reste affichée
        if selectedLaunch == nil && playingMission == nil { launchShake = 0 }
        if selectedLaunch != nil, !launchArcPoints.isEmpty {
            // Le drone accroche la fusée au moment de plonger et ne la lâche plus :
            // le plan se referme sur elle, pas sur le globe.
            let following = launchPhase != .arc && !launchDroneReleased
            launchFocusBlend = smoothDamp(
                launchFocusBlend, toward: following ? 1 : 0,
                velocity: &launchFocusBlendVelocity, smoothTime: 0.6, deltaTime: dt
            )
            switch launchPhase {
            case .arc:
                launchShake = 0
                goalDist = Self.LAUNCH_PULLBACK
                // Recul, visée et défilement de la date courent ensemble. C'est
                // le pivot qui commande la suite : dès qu'il ne reste qu'un filet
                // d'écart, la plongée reprend le dézoom en cours de route.
                if launchAimResidual < Self.LAUNCH_AIM_HANDOFF { launchPhase = .dive }
            case .dive:
                // La descente est indexée sur l'accrochage : la distance se compte
                // depuis la cible, et tant qu'elle n'a pas rejoint le pas de tir,
                // se rapprocher ferait passer la caméra sous la surface.
                goalDist = Self.LAUNCH_PULLBACK
                    + (Self.LAUNCH_DRONE_DIST - Self.LAUNCH_PULLBACK) * launchFocusBlend
                // Drone posé : on marque un temps avant d'allumer.
                if launchFocusBlend > 0.97, abs(dist - goalDist) < 0.15 * goalDist {
                    launchPhase = .hold
                    launchHoldClock = 0
                    Haptics.shared.touchdown() // le drone se pose
                    Haptics.shared.spoolUp(duration: Self.LAUNCH_HOLD) // les moteurs montent
                }
            case .hold:
                goalDist = Self.LAUNCH_PULLBACK
                    + (Self.LAUNCH_DRONE_DIST - Self.LAUNCH_PULLBACK) * launchFocusBlend
                launchHoldClock += dt
                // Le sol tremble de plus en plus fort sous la poussée retenue
                launchShake = Self.LAUNCH_SHAKE * pow(min(1, launchHoldClock / Self.LAUNCH_HOLD), 2.2)
                if launchHoldClock >= Self.LAUNCH_HOLD {
                    launchPhase = .flight
                    Haptics.shared.launchRumble(duration: Self.LAUNCH_RISE / playbackSpeed)
                }
            case .flight:
                launchClock += dt // mise à feu : la caméra est en place
                // La secousse s'éteint en ~1 s : la fusée s'arrache, le sol se tait
                launchShake = max(0, launchShake - dt * Self.LAUNCH_SHAKE)
            }
            let rise = Self.LAUNCH_RISE
            let progress = min(1, max(0, launchClock) / rise)
            launchAscentProgress = progress
            if launchPhase == .flight {
                // Le drone s'écarte au rythme de la fusée, en douceur aux deux
                // bouts, jusqu'à retrouver la distance de fin de séquence.
                let eased = progress * progress * (3 - 2 * progress)
                goalDist = Self.LAUNCH_DRONE_DIST
                    + (Self.LAUNCH_DIVE_DIST - Self.LAUNCH_DRONE_DIST) * eased
            }
            // Le panache est un ruban tourné vers l'œil : il se reconstruit à
            // l'avancée de la fusée, et quand la caméra a bougé.
            let eye = earth.node.convertPosition(cameraNode.position, from: nil).simd3
            if progress != launchProgressShown || simd_length(eye - launchTrailCamera) > 0.02 {
                launchProgressShown = progress
                launchTrailCamera = eye
                let trail = progress > 0.001 ? launchArcVisiblePoints(upTo: progress) : []
                if trail.count >= 2 {
                    let widths = (0..<trail.count).map { i -> Double in
                        // Le feu s'évase sous la fusée et s'éteint vers le pas de tir
                        Self.LAUNCH_TRAIL_WIDTH * (0.28 + 0.72 * Double(i) / Double(trail.count - 1))
                    }
                    launchArcGlow.geometry = Geo.ribbonGeometry(
                        points: trail, halfWidths: widths, viewPoint: eye,
                        color: launchTrailColor, texture: flameTexture
                    )
                    launchArcCore.geometry = Geo.lineGeometry(
                        points: trail, color: launchCoreColor, additive: true, texture: flameTexture
                    )
                    launchArcCore.isHidden = false
                    launchArcGlow.isHidden = false
                } else {
                    launchArcCore.isHidden = true
                    launchArcGlow.isHidden = true
                }
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
        if let mission = playingMission {
            // Vue drone : le pivot quitte le centre du globe pour le pas de tir,
            // puis suit le vaisseau. Une fois en orbite, le cadrage se déplie sur
            // la trajectoire au même rythme que le déroulé monte en régime : le
            // mouvement de caméra et l'accélération du temps sont un seul geste.
            let craft = mission.node.position.simd3
            let hub = earth.node.position.simd3
            let onCraft = hub + (craft - hub) * launchFocusBlend
            // Décélération seule : la caméra reprend le repli à la vitesse où
            // l'ascension l'a laissée, puis se pose. Une courbe en S repartirait
            // de zéro — c'est exactement le temps mort qu'on cherche à supprimer.
            let e = missionCoastEase
            let ease = 1 - (1 - e) * (1 - e)
            if launchAscentProgress >= 1, mission.trailRadius > 0, ease > 0 {
                let wide = min(560, max(3, frameDistance(radius: mission.trailRadius) * spacecraftZoomScale))
                focusTarget = onCraft + (mission.trailCenter - onCraft) * ease
                goalDist = Self.LAUNCH_DIVE_DIST + (wide - Self.LAUNCH_DIVE_DIST) * ease
            } else {
                focusTarget = onCraft
            }
            focusIdentity = .selection(.mission(mission))
        } else if case .mission(let mission) = selected, !mission.node.isHidden, mission.trailRadius > 0 {
            focusTarget = mission.trailCenter // on cadre la trajectoire parcourue
            focusIdentity = .selection(.mission(mission))
            goalDist = min(560, max(3, frameDistance(radius: mission.trailRadius) * spacecraftZoomScale))
        } else if case .mission = selected {
            focusTarget = SIMD3()
            goalDist = 230
        } else if let launch = selectedLaunch, !launchArcPoints.isEmpty {
            // Vue drone : le pivot quitte le centre du globe le temps du tir. Il
            // glisse vers le pas de tir pendant la plongée, monte avec la fusée,
            // puis rend la main au globe une fois l'ascension finie.
            // L'identité ne change jamais de toute la séquence : le verrouillage
            // image par image reste actif d'un bout à l'autre, donc aucune remise
            // à zéro de vélocité, et le globe qui dérive sur son orbite pendant un
            // défilement de date est compensé comme pour n'importe quel astre.
            // Toute la forme du mouvement tient dans l'amorti de l'accrochage.
            let center = earth.node.position.simd3
            let local = SCNVector3(launchArcPoint(at: launchAscentProgress))
            let onRocket = earth.node.convertPosition(local, to: nil).simd3
            focusTarget = center + (onRocket - center) * launchFocusBlend
            focusIdentity = .launch(launch.id)
        } else if let selection = selected {
            switch selection {
            case .planet(let p): focusTarget = p.node.position.simd3
            // Lune et satellite : on vise leur astre pour que la caméra tourne
            // autour de lui, l'objet décrivant son orbite dans le cadre.
            case .moon(let m): focusTarget = m.planet.node.position.simd3
            case .mission(let m): focusTarget = m.node.position.simd3
            case .satellite: focusTarget = earth.node.position.simd3
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
        if zoomWaitsForLevel, goalRoll != nil || goalElev != nil {
            distVelocity = 0 // le zoom attend que la scène soit redressée
        } else {
            zoomWaitsForLevel = false
            dist = smoothDamp(
                dist, toward: goalDist, velocity: &distVelocity,
                smoothTime: 0.5, deltaTime: dt
            )
        }
        placeCamera()

        updateDateText()
        updateLabels()

        // Pendant un rejeu, le bouton n'a rien à proposer : on regarde une
        // mission, on ne cherche pas à revenir au présent.
        let showToday = dateTransition == nil && playingMission == nil
            && abs(day - Astro.todayDay) > 30
        if showToday != showTodayButton {
            DispatchQueue.main.async { self.showTodayButton = showToday }
        }
        if uiDirty {
            let top = handleTop
            DispatchQueue.main.async { self.handleTopPercent = top }
        }
    }

    // MARK: Rejeu d'un vol habité

    /// Le décollage réutilise mot pour mot la grammaire des lancements — recul,
    /// plongée du drone, retenue moteurs, mise à feu. Ce qui suit lui est propre :
    /// la mission se déroule ensuite sur ses jours réels, jalonnée par ses
    /// allumages, jusqu'au retour.
    private func updateMissionPlayback(_ mission: Mission, _ c: CrewedSpec, dt rawDt: Double) {
        guard !playbackPaused else { return }
        let dt = rawDt * playbackSpeed
        let following = launchPhase != .arc && !launchDroneReleased
        launchFocusBlend = smoothDamp(
            launchFocusBlend, toward: following ? 1 : 0,
            velocity: &launchFocusBlendVelocity, smoothTime: 0.6, deltaTime: dt
        )
        switch launchPhase {
        case .arc:
            launchShake = 0
            goalDist = Self.LAUNCH_PULLBACK
            if launchAimResidual < Self.LAUNCH_AIM_HANDOFF { launchPhase = .dive }
        case .dive:
            goalDist = Self.LAUNCH_PULLBACK
                + (Self.LAUNCH_DRONE_DIST - Self.LAUNCH_PULLBACK) * launchFocusBlend
            if launchFocusBlend > 0.97, abs(dist - goalDist) < 0.15 * goalDist {
                launchPhase = .hold
                launchHoldClock = 0
                Haptics.shared.touchdown()
                Haptics.shared.spoolUp(duration: Self.LAUNCH_HOLD / playbackSpeed)
            }
        case .hold:
            goalDist = Self.LAUNCH_PULLBACK
                + (Self.LAUNCH_DRONE_DIST - Self.LAUNCH_PULLBACK) * launchFocusBlend
            launchHoldClock += dt
            launchShake = Self.LAUNCH_SHAKE * pow(min(1, launchHoldClock / Self.LAUNCH_HOLD), 2.2)
            if launchHoldClock >= Self.LAUNCH_HOLD {
                launchPhase = .flight
                Haptics.shared.launchRumble(duration: Self.LAUNCH_RISE)
                announce("Décollage")
                playedBeats = 1
            }
        case .flight:
            launchClock += dt
            launchShake = max(0, launchShake - dt * Self.LAUNCH_SHAKE)
        }

        // Un lancement s'arrondit en fin d'ascension : la séquence se termine là,
        // et la courbe en S lui donne sa chute. Ici elle n'a pas de sens — la
        // mission continue. Le vaisseau et la caméra accélèrent donc de bout en
        // bout, et sortent de l'ascension à leur vitesse maximale, celle que le
        // déroulé reprend.
        let raw = min(1, max(0, launchClock) / Self.LAUNCH_RISE)
        let progress = pow(raw, Self.ASCENT_EASE)
        launchAscentProgress = progress
        updatePadFlare()
        if launchPhase == .flight, progress < 1 {
            goalDist = Self.LAUNCH_DRONE_DIST
                + (Self.LAUNCH_DIVE_DIST - Self.LAUNCH_DRONE_DIST) * progress
            // L'ascension est une portion de la mission comme une autre : c'est la
            // date qui avance, et la sonde comme son tracé la suivent. Une seule
            // courbe, du sol au retour.
            day = c.launchDay + crewedAscentDays(c) * progress
            parkTimeline()
        }

        guard progress >= 1 else { return }

        // La mission se déroule. Le temps n'y coule pas uniformément : il suit la
        // répartition par phase du tracé, sinon trois jours de croisière
        // mangeraient tout le plan et les boucles lunaires passeraient en un éclair.
        let isLunar: Bool = { if case .lunar = c.profile { return true }; return false }()
        // Passage de relais : le déroulé reprend exactement là où l'ascension
        // s'est arrêtée — 24° d'orbite déjà parcourus — sinon la capsule saute
        // en arrière au moment où la maquette prend la place de la fusée.
        let handoff = ascentEndDay(c)
        func dayAt(_ k: Double) -> Double {
            isLunar ? crewedSampleDay(c, at: k) : c.launchDay + c.days * k
        }
        if missionCoastClock == 0 {
            let k0 = isLunar ? crewedSampleProgress(c, day: handoff)
                             : (handoff - c.launchDay) / max(1e-9, c.days)
            missionCoastClock = min(Self.MISSION_COAST, k0 * Self.MISSION_COAST)
            // Les deux vitesses sont *mesurées*, pas déduites : la vitesse réelle
            // du vaisseau sur sa dernière fraction de seconde d'ascension, et
            // celle qu'aurait le déroulé à plein régime au même point. Leur
            // rapport donne le régime de départ. Toute estimation analytique
            // laissait un écart — et un écart s'entend.
            let step = 0.02 // s
            // Vitesse de sortie : la date avance de ASCENT_EASE × durée / RISE par
            // seconde à la toute fin de l'ascension (dérivée de day = launchDay +
            // ascent · progress^ASCENT_EASE).
            let exitDayRate = Self.ASCENT_EASE * crewedAscentDays(c) / Self.LAUNCH_RISE
            let ascentSpeed = simd_length(
                crewedLocalPosition(c, day: handoff)
                    - crewedLocalPosition(c, day: handoff - exitDayRate * step)
            ) / step

            let k1 = min(1, missionCoastClock / Self.MISSION_COAST)
            let dk = 0.0005
            let here = crewedLocalPosition(c, day: dayAt(k1))
            let next = crewedLocalPosition(c, day: dayAt(min(1, k1 + dk)))
            let coastSpeed = simd_length(next - here) / dk / Self.MISSION_COAST
            missionCoastFloor = max(0.004, min(1, ascentSpeed / max(1e-9, coastSpeed)))
        }
        missionCoastEase = min(1, missionCoastEase + dt / Self.COAST_RAMP)
        // Montée en régime géométrique. Il y a un facteur vingt entre la vitesse
        // de sortie de l'ascension et le régime de croisière : interpolé
        // linéairement, l'essentiel du gain tombe au milieu de la rampe et se lit
        // comme une secousse. En doublant à intervalle constant, l'accélération
        // est la même à chaque instant — c'est ce qu'on perçoit comme fluide.
        missionCoastClock += dt * pow(missionCoastFloor, 1 - missionCoastEase)
        let k = min(1, missionCoastClock / Self.MISSION_COAST)
        let target = isLunar ? crewedSampleDay(c, at: k) : c.launchDay + c.days * k
        day = target
        parkTimeline()
        // La traînée d'ascension s'efface : 400 km ne pèsent plus rien une fois
        // la Lune dans le cadre.
        launchArcCore.isHidden = true
        launchArcGlow.isHidden = true

        // Jalons : ce que le cartouche annonce, et ce que la main sent
        let beats = crewedBeats(c)
        while playedBeats < beats.count, day >= beats[playedBeats].day {
            let beat = beats[playedBeats]
            playedBeats += 1
            if beat.kind == .liftoff { continue } // déjà joué à la mise à feu
            announce(beat.label)
            switch beat.kind {
            case .burn: Haptics.shared.burn()
            case .brake: Haptics.shared.brake()
            case .splashdown: Haptics.shared.splashdown()
            case .coast, .liftoff: Haptics.shared.selected()
            }
        }
        if k >= 1 {
            // Fin du rejeu : la trajectoire complète reste à l'écran, la timeline
            // rend la main.
            playingMission = nil
            padFlare.isHidden = true
            launchShake = 0
        }
    }

    /// Remettre la timeline au repos sur la date courante : la fenêtre et le
    /// cartouche vont ensemble, sinon le cartouche annonce une date à un endroit
    /// de la piste qui en désigne une autre.
    private func parkTimeline() {
        timelineCenter = restCenter(day)
        handleTop = restTop(day)
        // Appelé depuis la boucle de rendu : la publication passe par le thread
        // principal, comme partout ailleurs pour cette propriété.
        let top = handleTop
        if Thread.isMainThread { handleTopPercent = top }
        else { DispatchQueue.main.async { self.handleTopPercent = top } }
        updateDateText()
    }

    /// Le halo au pas de tir : il enfle sous la poussée retenue, éclate à la mise
    /// à feu, puis s'éteint pendant que le vaisseau prend de l'altitude. Il a
    /// disparu bien avant que la trajectoire ne quitte le voisinage du sol.
    private func updatePadFlare() {
        let heat: Double
        switch launchPhase {
        case .arc, .dive: heat = 0
        case .hold: heat = 0.5 * pow(min(1, launchHoldClock / Self.LAUNCH_HOLD), 1.6)
        case .flight: heat = max(0, 1 - launchAscentProgress / Self.PLUME_OUT)
        }
        padFlare.isHidden = heat <= 0.012
        guard !padFlare.isHidden else { return }
        padFlare.opacity = CGFloat(min(1, heat * 1.3))
        let size = Float(0.5 + heat * 1.5)
        padFlare.scale = SCNVector3(size, size, size)
    }

    /// Le jour de mission atteint à la fin de l'ascension.
    private func ascentEndDay(_ c: CrewedSpec) -> Double {
        c.launchDay + crewedAscentDays(c)
    }

    /// Le chapitre en cours, sous le nom de la mission.
    private func announce(_ label: String) {
        DispatchQueue.main.async {
            self.missionBeatLabel = label
            self.selectionSub = label
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
            // `frameDistance` tient compte du format : en portrait c'est la
            // largeur qui contraint (±11° contre ±23°). Le facteur 2,8 utilisé
            // avant ne cadrait qu'à la verticale — invisible tant que GPS n'avait
            // qu'un seul satellite embarqué, criant avec une vraie constellation.
            model.frameDist = max(5, frameDistance(radius: radiusSum / Double(alive), margin: 1.15))
            if !model.frameApplied, selected == .satellite(model) {
                model.frameApplied = true
                goalDist = model.frameDist
            }
        }
        model.constellationDay = sceneDay
        let pointSize = max(0.02, min(0.35, dist * 0.014))
        model.node.geometry = Geo.pointsGeometry(
            points: points, color: model.rampColor,
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
        orbitNode.geometry = Geo.lineGeometry(points: points, color: model.rampColor)
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
