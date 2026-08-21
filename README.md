# Système solaire 3D — React Native

Petite application Expo / React Native basée sur le prototype `systeme-solaire-3d.html`.

## Architecture du MVP

Le moteur 3D est embarqué dans une `WebView` React Native. La scène conserve l’esprit et les interactions principales du prototype :

- vue 3D du système solaire ;
- zoom et rotation tactile ;
- sélection et suivi des planètes ;
- timeline et simulation du temps ;
- positions calculées et trajectoires temporelles pour 12 missions actives ;
- filtre séparé pour les missions historiques ;
- dézoom à échelle logarithmique jusqu'aux sondes interstellaires ;
- thèmes et labels.

Les positions des engins sont calculées localement à partir d'un modèle de trajectoire embarqué et sont présentées comme des estimations, jamais comme de la télémétrie en temps réel. L'interface indique la période de validité propre à chaque mission et renvoie vers JPL Horizons et NAIF/SPICE, qui restent les sources scientifiques de référence pour une intégration d'éphémérides de production.

Pour garder ce premier dépôt léger, Three.js est chargé depuis un CDN HTTPS par la WebView. Une connexion est donc nécessaire au chargement de la scène. Une prochaine étape pourra embarquer Three.js localement ou porter la scène vers `@react-three/native` pour un fonctionnement entièrement hors ligne.

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
