# Système solaire — app native iOS (SwiftUI + SceneKit)

Port natif Swift du prototype `assets/systeme-solaire-3d.html` : plus de WebView ni d'iframe.
La scène 3D est rendue par SceneKit (Metal), l'interface par SwiftUI. iPhone et iPad.

## Prototype Apple Watch

Le target `SystemeSolaireWatch` propose un rejeu contemplatif des vols habités :
interface SwiftUI, astres, véhicule et trajectoire rendus en 3D par SceneKit. La
Digital Crown déplace directement le temps :
vers le haut pour avancer, vers le bas pour revenir en arrière. La lecture se met
en pause dès que la Crown bouge ; un tap la reprend depuis l'instant choisi. Les
grandes étapes de la mission produisent un cran haptique. La caméra suit le
véhicule et change de cadrage selon la phase du voyage ; la Terre et la Lune
réutilisent les cartes et le mapping UV de l'app iPhone.

Le prototype embarque trois formes de voyage volontairement différentes :
Apollo 11 (orbite lunaire), Apollo 13 (retour libre) et Vostok 1 (orbite terrestre).
Toucher le nom de la mission ouvre le sélecteur.

## Ce qui est porté (parité avec le prototype)

- Orbites képlériennes J2000 (éléments JPL, équation de Kepler résolue par Newton), ellipses inclinées, distances comprimées en log, direction exacte.
- 8 planètes texturées (vraies cartes équirectangulaires téléchargées + textures procédurales CoreGraphics en repli hors ligne), anneaux de Saturne, 22 lunes avec leurs périodes réelles.
- 26 sondes : trajectoires reconstruites (routes interpolées Catmull-Rom, latitude écliptique réelle — Ulysses sort du plan), orbites paramétriques, sondes en orbite planétaire ; traînée de la trajectoire parcourue et cadrage caméra automatique.
- 8 vols habités, de Vostok 1 à Artemis II : trajectoire calculée au jour près dans le repère de la Terre — orbite de parking, injection translunaire, boucles autour de la Lune, retour — d'après les repères réels de chaque mission. Les points du tracé sont répartis par phase, sinon l'orbite de parking (88 min) disparaîtrait dans un tracé de douze jours.
- Rejeu d'un vol habité, du décollage au retour : la trajectoire part du **vrai pas de tir**, au sol (Kennedy LC-39A, Baïkonour), et monte d'une seule pièce jusqu'à l'orbite — l'orbite initiale est construite à partir du site et de la date de tir, via cos i = cos φ · sin A. Séquence : plongée du drone sur le pas de tir, 1,5 s de poussée retenue, mise à feu, ascension, puis la mission se déroule jusqu'à l'amerrissage, jalonnée par ses allumages (haptique propre à chaque type de manœuvre). La vitesse au passage ascension → croisière est *mesurée* des deux côtés et la montée en régime est géométrique : sans ça le facteur vingt entre les deux s'entendait comme une secousse. Contrôleur lecture/pause/vitesse/début/fin au-dessus du cartouche.
- Satellites en propagation SGP4 (SatelliteKit) : TLE réels rafraîchis depuis Celestrak (cache disque 12 h, repli embarqué), altitude comprimée en log (surface < LEO < MEO < Lune), globe calé sur le temps sidéral (GMST) et incliné de 23,44°, fenêtre SGP4 de ±45 jours (au-delà : positions gelées au bord et maquettes estompées).
- Constellations GPS et Starlink en nuage de points, avec année de lancement lue dans le TLE (un satellite n'apparaît jamais avant son lancement).
- Prochains lancements réels (API Launch Library / thespacedevs, cache 1 h, repli embarqué) : vrais pas de tir posés à leur lat/lon, arc d'ascension animé (vertical puis basculement vers l'est), plongée caméra sur le site à la date du tir.
- Timeline verticale : glissement, inertie, défilement au bord, pas Heure/Jour/Mois/Année, bouton « Aujourd'hui », transitions de date animées.
- Sélection tactile (priorité lunes > sondes > planètes), cartouche dépliable avec textes explicatifs, dates cliquables dans les textes (calent la timeline).
- Point de géolocalisation posé sur le globe (repli : Paris), pulsation, solidaire de la rotation sidérale.

Détail important du rendu : les sphères texturées utilisent une géométrie custom au
mapping UV identique à `THREE.SphereGeometry` (voir `Geo.sphereGeometry`) — le mapping
de `SCNSphere` est différent, ce qui décalait lat/lon (pas de tir, point de géoloc).

## Non porté (choix)

- Thème jour et affichage des étiquettes de toutes les planètes : ces contrôles sont masqués par le CSS du prototype (l'UI effective ne les expose pas).
- Le tube néon du lancement est rendu en polyligne + tête lumineuse (pas de tube extrudé à alpha par sommet).

## Build

```bash
cd native-ios
xcodebuild -project SystemeSolaire.xcodeproj -scheme SystemeSolaire \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Ou ouvrir `SystemeSolaire.xcodeproj` dans Xcode (≥ 16) et lancer. Dépendance SPM :
[SatelliteKit](https://github.com/gavineadie/SatelliteKit) (SGP4/SDP4), résolue automatiquement.

## Structure

```text
SystemeSolaire/
├── App.swift              # point d'entrée SwiftUI
├── Orbital.swift          # Kepler, temps (J2000, GMST), compressions log, lunes
├── MissionData.swift      # les 26 sondes et les 8 vols habités
├── SatelliteData.swift    # specs satellites + TLE de repli, lancements de repli
├── InfoTexts.swift        # textes du cartouche
├── SatelliteEngine.swift  # pont SGP4 (SatelliteKit), caches Celestrak & Launch Library
├── Textures.swift         # textures procédurales (port du canvas 2D) + téléchargement
├── GeometryHelpers.swift  # lignes, nuages de points, sphère UV Three, anneau, octaèdre
├── Engine.swift           # scène SceneKit, boucle de rendu, caméra, timeline, sélection
├── SceneContainer.swift   # SCNView + gestes (rotation, pincement, sélection)
├── ContentView.swift      # dock, cartouche, timeline, menu d'échelle, fond
└── ExplorerPanel.swift    # panneau Sondes / Satellites / Lancements

SystemeSolaireWatch/
├── SystemeSolaireWatchApp.swift # point d'entrée watchOS
├── ContentView.swift             # Crown, lecture/pause et sélection
├── MissionPlayer.swift           # temps simulé et crans haptiques
├── MissionScene.swift            # scène, astres, véhicule et trace 3D SceneKit
└── WatchMission.swift            # missions et étapes narratives
```
