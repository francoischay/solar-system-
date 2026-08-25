# Description produit — Système solaire (app native iOS)

Une description écrite de l'expérience utilisateur de l'app iOS « Système solaire » : ce que l'utilisateur voit, ce qu'il peut faire, et exactement ce qui se passe quand il le fait.

## Objet

Du point de vue de l'utilisateur, l'app est un grand diagramme d'états. On s'y déplace avec des gestes tactiles : glissements à un ou deux doigts, pincements, taps, et quelques boutons. La majeure partie de ce comportement est définie implicitement, répartie entre la boucle de rendu SceneKit, les reconnaisseurs de gestes UIKit et les vues SwiftUI. Aucun endroit ne dit, en langage clair, « quand l'utilisateur fait X, voilà ce qui se passe, et voilà ce qui se passe s'il fait Y au milieu ».

Ce projet est cet endroit. Il décrit l'expérience complète sur l'app native iOS (`native-ios/`), lancée sur iPhone, dans sa configuration par défaut, sans rien de personnalisé, en français.

Ces documents s'adressent à qui doit comprendre ou modifier le produit : designers, ingénieurs, rédacteurs, testeurs, et quiconque évalue si un comportement est intentionnel. Ils sont écrits de l'extérieur vers l'intérieur : ils décrivent l'expérience, pas l'implémentation.

### Ce que ce n'est pas

- Pas une documentation d'API. Le code est sa propre référence (`native-ios/SystemeSolaire/`).
- Pas organisé par fichier ou module. Un comportement est décrit une seule fois, là où l'utilisateur le rencontre.
- Pas un document de conception technique. Quand un détail technique est indispensable pour comprendre l'expérience, il apparaît dans une citation `> Note technique :` et nulle part ailleurs.

## Conventions

- Décrire l'expérience, pas le code. « La scène continue de tourner sur son élan quand le doigt se lève », pas « panEnded transfère la vélocité à panVelocityAz ».
- Le détail technique va dans des citations préfixées `Note technique :`, seulement quand le mécanisme change ce que l'utilisateur attendrait.
- Casse de phrase pour les titres.
- Vocabulaire constant. Le [glossaire](glossary.md) fait foi pour des termes comme *sélection*, *cartouche*, *poignée*, *transition de date*, *fenêtre SGP4*, *geste composé*.
- Chaque document se termine par le commit du dépôt source contre lequel il a été vérifié et une liste de questions ouvertes.
- Un comportement surprenant est énoncé tel quel, avec sa raison si le code la donne. On ne le lisse pas.

## Le travail à faire

Chaque document décrit une fonctionnalité. Grande (la sélection d'un lancement et sa séquence de tir) ou petite (le bouton « Aujourd'hui »), chacune est décrite en entier, avec ses cas limites et ses interactions avec les autres.

### Le squelette des documents

Tous les documents de fonctionnalité suivent le même squelette, pour être comparables et ne rien omettre.

1. **Résumé.** Un paragraphe abstrait. Par exemple : « Un glissement à un doigt fait tourner la caméra autour de la cible ; l'élan continue après le lever du doigt. »
2. **Le cas simple.** Le chemin courant, en prose.
3. **L'interaction, événement par événement.** Les cinq phases du geste : *le doigt se pose* ; *levé sans mouvement* ; *le geste s'engage* ; *pendant le geste* ; *le doigt se lève*. Ce qui démarre, ce qui se passe si ça s'arrête tout de suite, ce qui est décidé au moment où le geste s'engage, ce qui se met à jour en continu, ce qui est acté à la fin. Avec un petit diagramme d'états Mermaid (`stateDiagram-v2`) des états traversés.
4. **Variantes.** Un tableau de ce que l'utilisateur peut avoir « en main » et qui change l'issue du même geste : la sélection courante, le panneau Explorer ouvert, le cartouche déplié, l'échelle de temps choisie. Effet au début du geste et en cours de geste.
5. **Annulation et interruption.** La même liste, dans le même ordre, dans chaque document :
   - Taper le vide (désélection / retour à la vue d'ensemble)
   - Un deuxième doigt se pose (le geste composé prend la main)
   - Une transition de date animée démarre (sélection de sonde ou de lancement, lien de date, « Aujourd'hui »)
   - Le système annule le toucher (appel entrant, centre de contrôle, geste système)
   - L'app passe en arrière-plan ou l'écran se verrouille
   - La cible disparaît (sonde hors de sa période, satellite pas encore lancé, propagation hors fenêtre SGP4)
   - Le réseau manque ou une requête échoue (textures, TLE, lancements)
   - L'appareil pivote ou la fenêtre change de taille
6. **Interactions avec les autres systèmes.** Les préoccupations transverses, toujours dans cet ordre : **Caméra et cadrage.** **Temps simulé.** **Sélection.** **Réseau et replis.** **Échelles compressées.** **Localisation et langue.** **Accessibilité.**
7. **Cas limites.** Tout ce qu'un utilisateur pourrait remarquer et qui n'est pas couvert plus haut.
8. **Questions ouvertes et vérification.** Le commit du dépôt source, et tout comportement qui n'a pas pu être confirmé.

Le point 5 est le plus important : poser les mêmes questions d'interruption à chaque fonctionnalité est ce qui fait apparaître les trous et les incohérences.

### Méthode

Pour chaque document :

1. Lire l'état d'interaction concerné (`Engine.swift` pour la boucle de rendu, la caméra, la timeline et la sélection ; `SceneContainer.swift` pour les gestes).
2. Lire les objets du domaine (`Orbital.swift`, `MissionData.swift`, `SatelliteData.swift`, `SatelliteEngine.swift`).
3. Rédiger le document.
4. Essayer tout ce qui est ambigu dans l'app qui tourne (simulateur iOS). Le code tranche « ce qui se passe » ; l'app qui tourne tranche ce que ça donne à l'œil, ce qui est visible pendant le geste, et les timings ressentis.
5. Noter le commit vérifié.

Il n'y a pas de suite de tests comportementaux dans le dépôt source : tout ce qui n'est pas lisible dans le code doit être vérifié sur l'app qui tourne, sinon aller en « Questions ouvertes ».

### Vérification

La rédaction lit le code ; la vérification regarde le produit. Le dossier `verification/` contient une checklist par groupe de documents, chaque item étant une affirmation observable unique, avec mise en place, étapes, résultat attendu, priorité et matériel requis. Un testeur les déroule sur l'app (simulateur ou appareil), note `pass`, `fail` ou `blocked` dans la colonne Résultat, et consigne chaque échec dans `bug-triage.md` avec l'ID de l'item. Un document ne passe de `drafted` à `verified` dans le tableau de couverture que quand tous ses items P1 et P2 sont passés ou consignés.

`bug-triage.md` est l'autre moitié : chaque comportement que les documents signalent comme défaut probable, dédupliqué, avec reproduction, cause dans le code, gravité, et la décision attendue de l'équipe produit.

### Ordre de travail

1. **Pilote : [camera/orbite-libre.md](camera/orbite-libre.md).** Petit, autonome, un vrai geste avec seuils et inertie. Sert à fixer le squelette, le ton et la profondeur.
2. **Fondations : les quatre documents de `foundations/`.** Tout le reste s'y réfère.
3. **La zone la plus dure : la sélection et ses cadrages** (`selection/`, puis `explorer/lancements.md`). Les états se passent la main entre le tap, le cartouche, les listes et la caméra ; les documents doivent s'accorder sur qui possède quoi.
4. **Le reste.** Une fois le squelette et les exemplaires en place, les documents restants sont indépendants et peuvent être rédigés en parallèle, suivis d'une passe de cohérence et d'une passe de vérification sur l'ensemble.

L'avancement est suivi dans le [tableau de couverture](#couverture) ci-dessous.

### Décisions de périmètre

- **Le MVP Expo/WebView (`App.tsx` + `assets/systeme-solaire-3d.html`) est hors périmètre.** C'est le prototype dont l'app native est le port ; le décrire doublerait chaque document. Il pourra faire l'objet d'un second repo si besoin.
- **iPad est hors périmètre.** L'app y tourne mais la vérification se fait sur iPhone ; les différences de mise en page ne sont pas décrites.
- **La géolocalisation est décrite dans les fondations** ([foundations/scene-et-objets.md](foundations/scene-et-objets.md)) et non dans un document propre : c'est un marqueur passif, sans interaction.
- **Forme de l'interaction.** L'unité d'interaction est le geste tactile ; ses phases sont : le doigt se pose / levé sans mouvement / le geste s'engage / pendant le geste / le doigt se lève. La liste d'interruptions et l'ordre des préoccupations transverses sont figés tels qu'écrits plus haut.
- **Règles en prose.** Ce sont des documents en prose, pas des spécifications numérotées. Les ancres de titres suffisent pour les renvois.
- **Commit de référence.** Le code source vit dans le même dépôt git que ces documents ; le commit cité en pied de page est le dernier commit qui touche `native-ios/` (`git log -1 --format=%h -- native-ios/`), pas HEAD. Le code a bougé pendant la rédaction initiale (suppression du geste de torsion, limite d'élévation ramenée à 77°, fenêtre anti-élan de 0,5 s) : tous les documents décrivent l'état `bb3744e`.

## Structure

```
README.md                        ce fichier
goal.md                          les instructions permanentes pour qui rédige
AGENTS.md, CLAUDE.md             points d'entrée agents : lire README.md puis goal.md
glossary.md                      le vocabulaire partagé
bug-triage.md                    les défauts soupçonnés, dédupliqués, avec repro et décisions attendues

verification/
  README.md                      comment dérouler une passe de vérification et noter les résultats
  fondations.md                  checklist pour foundations/
  camera-et-selection.md         checklist pour camera/ et selection/
  timeline.md                    checklist pour timeline/
  explorer.md                    checklist pour explorer/

foundations/
  gestes-et-camera.md            le modèle d'entrée : reconnaisseurs, seuils, inertie, arbitrage, limites de caméra
  temps-et-timeline.md           le temps simulé : jour J2000, échelles, transitions de date, vitesse, traînées
  scene-et-objets.md             les corps de la scène, la compression log, la visibilité, les étiquettes, la géolocalisation
  donnees-et-reseau.md           TLE Celestrak, Launch Library, textures : caches, TTL, replis embarqués

camera/
  orbite-libre.md                le glissement à un doigt : orbite autour de la cible, inertie  (PILOTE)
  geste-compose.md               le geste à deux doigts : orientation + pincement simultanés

selection/
  toucher-un-astre.md            le tap : priorités lune > sonde/satellite > planète, rayons de saisie, désélection
  cartouche.md                   la feuille dépliable : drag, snap, liens de date, bascule début/fin de mission

timeline/
  glissement.md                  la poignée de date : glissement, élan, défilement au bord
  echelle-et-aujourdhui.md       le menu Heure/Jour/Mois/Année et le bouton « Aujourd'hui »

explorer/
  panneau.md                     le dock et le panneau Explorer : ouverture, onglets, fermeture
  sondes.md                      la liste des 26 sondes : sélection, recadrage de date, « afficher toutes »
  satellites.md                  la liste des satellites : sélection, note SGP4, constellations, « afficher tous »
  lancements.md                  les prochains lancements : compte à rebours, sélection et séquence de tir
```

## Couverture

Le statut est `not started`, `drafted` ou `verified`.

| Document | Statut |
| --- | --- |
| glossary.md | drafted |
| bug-triage.md | not started |
| verification/ (4 checklists) | drafted |
| foundations/gestes-et-camera.md | drafted |
| foundations/temps-et-timeline.md | drafted |
| foundations/scene-et-objets.md | drafted |
| foundations/donnees-et-reseau.md | drafted |
| camera/orbite-libre.md | drafted |
| camera/geste-compose.md | drafted |
| selection/toucher-un-astre.md | drafted |
| selection/cartouche.md | drafted |
| timeline/glissement.md | drafted |
| timeline/echelle-et-aujourdhui.md | drafted |
| explorer/panneau.md | drafted |
| explorer/sondes.md | drafted |
| explorer/satellites.md | drafted |
| explorer/lancements.md | drafted |

## Référence

La source de vérité est ce même dépôt git, dossier `native-ios/`, au commit indiqué en pied de chaque document. Les endroits qui comptent :

- `native-ios/SystemeSolaire/Engine.swift` : la boucle de rendu, la caméra, la timeline, la sélection, les lancements — c'est là que vit l'état d'interaction.
- `native-ios/SystemeSolaire/SceneContainer.swift` : les reconnaisseurs de gestes et leur arbitrage.
- `native-ios/SystemeSolaire/ContentView.swift` : le dock, le cartouche, la barre de timeline, le menu d'échelle, les étiquettes.
- `native-ios/SystemeSolaire/ExplorerPanel.swift` : le panneau Sondes / Satellites / Lancements.
- `native-ios/SystemeSolaire/Orbital.swift` : Kepler, le temps (J2000, GMST), les compressions log, les lunes — les constantes et seuils du domaine.
- `native-ios/SystemeSolaire/MissionData.swift`, `SatelliteData.swift`, `InfoTexts.swift` : les données (sondes, satellites, lancements de repli, textes du cartouche).
- `native-ios/SystemeSolaire/SatelliteEngine.swift` : SGP4, caches Celestrak et Launch Library.
- `native-ios/SystemeSolaire/Textures.swift` : textures procédurales et téléchargées.

Il n'y a pas de tests comportementaux ; la vérification se fait sur l'app qui tourne (voir `native-ios/README.md` pour la build : `xcodebuild -project SystemeSolaire.xcodeproj -scheme SystemeSolaire`, simulateur iPhone).
