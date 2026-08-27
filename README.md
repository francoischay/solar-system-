# Système solaire 3D — React Native

Petite application Expo / React Native basée sur le prototype `systeme-solaire-3d.html`.

> **Port natif iOS** : une version 100 % native Swift (SwiftUI + SceneKit, sans WebView)
> vit dans [`native-ios/`](native-ios/README.md) — iPhone et iPad.

## Architecture du MVP

Le moteur 3D est embarqué dans une `WebView` React Native. La scène conserve l’esprit et les interactions principales du prototype :

- vue 3D du système solaire, orbites képlériennes : éléments J2000 du JPL (demi-grand axe, excentricité, inclinaison, nœud ascendant, périhélie), équation de Kepler résolue par Newton — les orbites sont des ellipses inclinées, plus des cercles coplanaires ;
- vraies textures pour tous les corps : Terre (NASA Blue Marble), Mercure, Vénus, Mars, Jupiter, Saturne et ses anneaux, Uranus, Neptune, la Lune et le Soleil — cartes de James Hastings-Trew (planetpixelemporium) servies via le dépôt MIT `jeromeetienne/threex.planets` ; les textures procédurales restent le repli hors ligne ;
- point de géolocalisation de l'utilisateur posé sur le globe (repli : Paris si la permission est refusée) ;
- fusée placée au vrai pas de tir de chaque lancement (Cap Canaveral, Kourou, Tanegashima), verticale par rapport au sol ;
- zoom et rotation tactile ;
- sélection et suivi des planètes ;
- satellites en propagation SGP4 : TLE réels (Celestrak, cache local 12 h, repli embarqué), direction exacte (la trace au sol est juste) et altitude comprimée en log pour rester cohérente avec la Lune de la scène — surface < LEO < MEO < Lune ; globe calé sur le temps sidéral et incliné de 23,44° ;
- constellations GPS et Starlink affichées en nuage de points lumineux (jeu complet plafonné, sans maquette 3D) ;
- timeline et simulation du temps ;
- 26 sondes : trajectoires temporelles des missions actives et historiques, dont Ulysses et son orbite polaire à 79° du plan des planètes ;
- 8 vols habités dans le port natif iOS, de Vostok 1 à Artemis II : trajectoires à l'échelle du jour dans le voisinage terrestre, profils lunaires reconstruits d'après les repères réels de chaque mission (injection translunaire, mise en orbite lunaire, retour) ;
- rejeu d'un vol habité de bout en bout dans le port natif iOS : décollage depuis le vrai pas de tir avec vue drone et retours haptiques, puis déroulé de la mission jusqu'au retour, avec un contrôleur lecture/pause/vitesse ;
- prochains lancements réels : API Launch Library (thespacedevs), vrais pas de tir avec leurs coordonnées, dates et statuts, cache local d'une heure et repli embarqué ;
- trajectoires reconstruites pour Voyager 1, Voyager 2 et New Horizons : départ de la Terre, assistances gravitationnelles aux dates réelles des survols, latitude écliptique (sortie du plan après Titan pour Voyager 1, plongée sud après Neptune pour Voyager 2) et droite d'échappement calée sur le franchissement de l'héliopause ;
- filtre séparé pour les missions historiques ;
- dézoom à échelle logarithmique jusqu'aux sondes interstellaires ;
- cartouche dépliable : chaque objet sélectionné (planète, lune, sonde, satellite, lancement) a son texte d'explication ;
- thèmes et labels.

Les positions des engins sont calculées localement à partir d'un modèle de trajectoire embarqué et sont présentées comme des estimations, jamais comme de la télémétrie en temps réel. L'interface indique la période de validité propre à chaque mission et renvoie vers JPL Horizons et NAIF/SPICE, qui restent les sources scientifiques de référence pour une intégration d'éphémérides de production.

Pour garder ce premier dépôt léger, Three.js, `satellite.js` (SGP4) et la texture terrestre sont chargés depuis un CDN HTTPS par la WebView (la texture procédurale reste le repli hors ligne). Les TLE sont rafraîchis auprès de Celestrak au chargement ; à défaut, ceux embarqués dans le fichier servent de repli — la précision SGP4 se dégrade au-delà de quelques semaines après l'époque du TLE : hors de cette fenêtre la propagation est gelée à son bord (orbites justes, position non synchronisée), les maquettes sont estompées et le panneau affiche « positions indicatives ». Un satellite n'apparaît jamais avant son année de lancement, lue dans le désignateur international du TLE. Une connexion est donc nécessaire au chargement de la scène. Une prochaine étape pourra embarquer Three.js localement ou porter la scène vers `@react-three/native` pour un fonctionnement entièrement hors ligne.

## Lancer le projet

```bash
npm install
npx expo start
```

Puis ouvrir le QR code dans Expo Go ou lancer une build de développement.

## Structure

```text
.
├── App.tsx
├── app.json
├── assets/
│   └── systeme-solaire-3d.html
├── package.json
└── tsconfig.json
```

## Suite possible

Le MVP privilégie une migration rapide et fidèle. Une seconde étape pourra porter le moteur vers `@react-three/native` / React Three Fiber afin de rendre la scène 3D complètement native côté React Native.
