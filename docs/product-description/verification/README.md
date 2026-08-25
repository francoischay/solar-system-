# Vérification à la main

Les documents de fonctionnalité ont été rédigés depuis le code (il n'y a pas de tests comportementaux dans le dépôt). Ce dossier est le protocole pour les vérifier contre l'app qui tourne, une affirmation observable à la fois.

## Ce qu'il y a ici

| Fichier | Couvre |
| --- | --- |
| [fondations.md](fondations.md) | `foundations/*` |
| [camera-et-selection.md](camera-et-selection.md) | `camera/*` et `selection/*` |
| [timeline.md](timeline.md) | `timeline/*` |
| [explorer.md](explorer.md) | `explorer/*` |

Chaque fichier a un tableau par document. Chaque ligne est un item avec un ID stable (`ORBIT-03`, `TIR-12`), une priorité, ce qu'il exige (simulateur ou appareil, réseau coupé, autorisation refusée…), l'affirmation avec un lien vers la section du document, la mise en place, les étapes numérotées, le résultat attendu, et une colonne Résultat pour le testeur. Ce qui n'est pas vérifiable à la main (questions de design, décisions produit) est listé sous chaque document en « Non vérifiable à la main ».

Priorités : **P1** un fait établi dont beaucoup de documents dépendent, ou un défaut soupçonné ; **P2** une affirmation ordinaire ; **P3** un nombre, une couleur, un timing.

## Dérouler une passe

1. Construire et lancer l'app : `cd native-ios && xcodebuild -project SystemeSolaire.xcodeproj -scheme SystemeSolaire -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`, puis installer et lancer la build dans le simulateur (ou ouvrir le projet dans Xcode ≥ 16 et lancer). État propre : supprimer l'app du simulateur remet à zéro les caches (TLE, lancements, textures) et l'autorisation de localisation.
2. Confirmer le commit. Chaque document se termine par « Vérifié contre le dossier natif au commit `{sha}` ». Exécuter `git rev-parse --short HEAD` à la racine du dépôt ; s'il diffère, les documents décrivent une autre build et certains échecs seront de la dérive, pas des défauts.
3. Garder les documents ouverts à côté de l'app. Lire la section liée avant chaque item ; l'item est un résumé, la section fait foi.
4. Traiter tous les P1 d'abord, tous fichiers confondus, puis les P2, puis les P3.
5. Noter `pass`, `fail` ou `blocked` dans la colonne Résultat, avec une note pour tout ce qui n'est pas un pass net. Un fail : le document affirme quelque chose que le produit ne fait pas. Un blocked : l'item n'a pas pu être joué (pas d'appareil, autorisation impossible à simuler, échec précédent qui bloque).
6. Consigner chaque fail dans [`bug-triage.md`](../bug-triage.md) : si l'entrée existe, ajouter une ligne Status citant l'ID de l'item ; sinon, créer l'entrée avec l'ID en « Raised by ». Un fail n'est pas automatiquement un bug produit : parfois c'est le document qui a tort, et le correctif est documentaire. La ligne Status dit lequel.
7. Quand tous les P1 et P2 d'un document sont passés ou consignés, passer sa ligne du [tableau de couverture](../README.md#couverture) de `drafted` à `verified`.

## Appareils et conditions

- **simulateur** : le simulateur iOS (iPhone). Suffit pour presque tout ; les gestes se font à la souris (clic-glisser), le geste composé avec ⌥ (deux doigts symétriques) et ⌥⇧ (déplacement parallèle). La torsion à deux doigts est pénible mais possible en ⌥-glisser circulaire.
- **appareil** : un iPhone réel. Requis pour ce qui touche au ressenti (élan, vivacité des gestes), au multi-touch réel (poser un deuxième doigt en plein glissement), au touch cancel système (appel entrant), et à la vraie géolocalisation.
- **réseau coupé** : couper le réseau du Mac (le simulateur suit) ou activer le mode avion sur l'appareil *avant de lancer l'app*, pour tester les replis. Supprimer l'app d'abord si l'item exige des caches vides — un cache présent masque le repli.
- **localisation refusée** : refuser l'autorisation à la première demande, ou la retirer dans Réglages > Confidentialité ; supprimer l'app pour re-déclencher la demande.
- **date réelle** : certains items (bouton « Aujourd'hui », comptes à rebours) dépendent de l'heure réelle ; aucun réglage nécessaire, mais noter l'heure du test.

## Piloter l'app depuis un outil

L'app n'expose ni console ni poignée d'état : pas de moyen de lire l'état interne ou de poser une scène précise autrement qu'en manipulant l'interface. Une passe outillée (agent pilotant le simulateur : captures d'écran, taps, glissements) peut vérifier ce qui se voit — présence des éléments, textes, enchaînements — mais pas les valeurs internes (angles, vitesses) ni le ressenti (amortissements, élan). Les timings s'y mesurent grossièrement (comparaison de captures datées). Toute passe outillée doit être décrite ici avec ses limites, et ne suffit jamais à passer un document en `verified`.

## Résultats à ce jour

Aucune passe n'a encore été déroulée.
