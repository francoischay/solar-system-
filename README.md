# Système solaire 3D — React Native

Petite application Expo / React Native basée sur le prototype `systeme-solaire-3d.html`.

## Architecture du MVP

Le moteur 3D Three.js existant est embarqué comme asset local et exécuté dans une `WebView`. Cela permet de conserver immédiatement :

- la vue 3D du système solaire ;
- le zoom, pan et gestes tactiles ;
- la sélection et le suivi des planètes ;
- la timeline et la simulation du temps ;
- les thèmes et labels du prototype.

L'application fonctionne donc hors ligne une fois installée, sans serveur web.

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
