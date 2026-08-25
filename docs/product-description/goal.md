# Goal : compléter la description produit de Système solaire (iOS natif)

Tu travailles dans `docs/product-description/` du dépôt `solar-system-`. Lis d'abord `README.md`, `glossary.md`, `foundations/gestes-et-camera.md` et `camera/orbite-libre.md`. Le README définit l'objet, le squelette des documents, la méthode, la structure et le tableau de couverture. Les autres sont les exemplaires : reproduis exactement leur profondeur, leur ton et leur structure. Ton travail : écrire chaque document de la structure du README jusqu'à ce que le tableau de couverture n'ait plus de ligne `not started`, puis faire une passe de cohérence.

Tout est rédigé **en français**, la langue du produit.

## Source de vérité

Le code source est dans le même dépôt, dossier `native-ios/SystemeSolaire/`. Décris l'expérience de l'app native iOS lancée sur iPhone, configuration par défaut, sans rien de personnalisé. Le MVP Expo/WebView (`App.tsx`, `assets/systeme-solaire-3d.html`) et l'iPad sont hors périmètre.

Pour chaque document, lire dans cet ordre avant d'écrire :

1. `Engine.swift` — l'état d'interaction : boucle de rendu, caméra, timeline, sélection, lancements, satellites. C'est le fichier central ; presque tout comportement y aboutit.
2. `SceneContainer.swift` — les reconnaisseurs de gestes et leur arbitrage (qui prend la main sur qui).
3. `ContentView.swift` et `ExplorerPanel.swift` — l'interface SwiftUI : dock, cartouche, timeline, menu d'échelle, panneau et listes.
4. Les objets du domaine selon le sujet : `Orbital.swift` (Kepler, temps, compressions log, lunes), `MissionData.swift` (26 sondes), `SatelliteData.swift` (satellites, lancements de repli), `SatelliteEngine.swift` (SGP4, caches), `Textures.swift`, `InfoTexts.swift`.
5. Il n'y a pas de tests comportementaux. Ce que le code ne dit pas clairement se vérifie sur l'app qui tourne (simulateur), sinon va en « Questions ouvertes ».

Ne décris pas le code. Décris ce que l'utilisateur voit et fait. Le détail technique va uniquement dans des citations `> Note technique :`, et seulement quand le mécanisme change ce que l'utilisateur attendrait.

## Règles d'écriture

- Suis le squelette en huit sections du README pour chaque document de fonctionnalité. Les fondations peuvent omettre les sections sans objet (une constante n'a pas de phase « pendant le geste ») mais doivent couvrir l'interruption partout où il y a interaction.
- Variantes et annulation/interruption vont dans des tableaux, à deux colonnes de phase (« au début du geste » / « pendant le geste »), comme dans `camera/orbite-libre.md`. Les lignes d'interruption et l'ordre des préoccupations transverses sont figés dans le README ; ne les ajoute, retire ou réordonne jamais dans un document isolé.
- Utilise les mots du glossaire. S'il te manque un terme, ajoute-le dans `glossary.md` à la bonne section avec une définition complète, puis utilise-le. N'invente pas de synonyme.
- Casse de phrase pour tous les titres. Langue directe et concrète. Pas de flou, pas de marketing.
- Énonce les comportements surprenants tels quels, avec la raison si le code ou un commentaire la donne. Si ça ressemble à un bug, dis-le en « Questions ouvertes » au lieu de le lisser.
- Renvoie vers les autres documents par des liens relatifs au lieu de répéter leur contenu. Les fondations possèdent les seuils, les constantes et les définitions d'événements d'interruption ; ne les redonne pas, lie.
- Chaque document se termine par « ## Questions ouvertes et vérification » listant ce qui a été lu dans le code sans être confirmé à la main, puis `Vérifié contre le dossier natif au commit \`ddd8314\`` (le `git rev-parse --short HEAD` courant si le code a bougé).
- Un diagramme Mermaid `stateDiagram-v2` par interaction, limité aux états traversés par l'utilisateur ; pas d'états de comptabilité interne.

## Faits établis (ne pas re-dériver, ne pas contredire)

Fondations — gestes et caméra :

- Le pan à un doigt oriente la caméra : azimut −0,007 rad/pt, élévation +0,005 rad/pt, élévation bornée à ±(π/2 − 0,025).
- L'élan du pan à un doigt est plafonné (±1,8 rad/s en azimut, ±1,35 en élévation) et décroît en exp(−5,2·t) ; il ne démarre que si aucun autre geste d'orientation n'est actif.
- Le geste composé (2 doigts) combine orientation (précision 0,72), pincement et torsion, sans élan à la fin ; il annule immédiatement le pan à un doigt en cours (« prendre la main »).
- Le zoom borne la distance de caméra à [1,4 ; 560] ; sur une sonde sélectionnée il règle l'ampleur du cadrage [0,3 ; 3] au lieu de la distance.
- Toute visée programmée de caméra (recadrage) est abandonnée dès qu'un geste d'orientation commence ; les visées rejoignent leur but par amortissement (temps caractéristique 0,48 s), la distance en 0,5 s, la cible en 0,42 s (0,58 s sans sélection).
- Le tap ne déclenche jamais pendant un geste ; les gestes de scène se reconnaissent simultanément entre eux mais jamais avec le tap.

Fondations — temps et timeline :

- La date simulée se mesure en jours depuis J2000 (2000-01-01T12:00 UTC) ; l'app démarre à maintenant.
- Les pas : Heure = 4,2 jours de fenêtre, Jour = 100, Mois = 3 044, Année = 36 525. Changer de pas recentre la fenêtre sans changer la date et replace la poignée à 62 %.
- La poignée au repos après recadrage est à 62 % de sa course (constante HANDLE_REST) ; le bouton « Aujourd'hui » n'apparaît que si |date − aujourd'hui| > 30 jours, poignée à plus de 9 pts de % du centre, et hors transition.
- La transition de date dure 0,95 s (cubique entrée-sortie) ; le défilement au bord se déclenche sous 2,5 % des bords de course ; l'élan de timeline est plafonné à (pas/4000) jours/ms et décroît en exp(−0,0045·ms) ; il est annulé s'il est inférieur à 0,003 en fin de geste.
- Format de date affiché : « j MMM HH:mm » au pas Heure, « MMM aaaa » au pas Année, « j MMM aaaa » entre les deux.
- Les traces apparaissent quand le temps défile (l'énergie de traînée suit la vitesse de défilement et décroît en exp(−2,2·t)) et s'estompent à l'arrêt.

Fondations — scène et objets :

- Compression log des distances héliocentriques : rayon de scène = 12 + log1p(UA)/log1p(30,07) × 88 ; autour de la Terre : Terre = 1,2, Lune à 3,1, altitude compressée en log1p((km − 6371)/400).
- Sélection → distance d'arrivée : planète 42, lune 14, sonde 34 (puis cadrage sur la trajectoire), satellite 5 (constellation : cadrage moyen ×2,8, min 5), Terre depuis l'onglet Satellites 9, lancement 12 puis 10 puis 1,5 (plongée).
- Les lunes ne sont visibles que si leur planète ou l'une d'elles est sélectionnée. Une sonde n'est visible que si (sélectionnée ou « afficher toutes ») et date dans sa période de validité (année de début à année de fin + 1). Un satellite n'est visible que si (sélectionné ou « afficher tous ») et lancé et TLE chargé.
- Priorité du tap : lune (0) > sonde = satellite (1) > planète (2) ; à priorité égale, distance écran minimale ; rayon écran minimal 22 pt. Taper le vide = tout désélectionner (retour vue d'ensemble, roulis remis à zéro, distance 230).
- Le globe terrestre est calé sur le temps sidéral (GMST) et incliné de 23,44° ; le point de géolocalisation (repli : Paris 48,8566/2,3522) est solidaire de sa rotation et pulse en continu.
- Étiquettes : uniquement la sonde sélectionnée ou le satellite individuel sélectionné ; jamais les planètes, lunes ou constellations.

Fondations — données et réseau :

- TLE : Celestrak par groupe ou numéro de catalogue, cache disque 12 h, repli embarqué (époque 2026-08-23), Starlink tronqué à 600 membres, GPS à 40. Fenêtre SGP4 : ±45 jours autour de l'époque moyenne des TLE ; au-delà : positions gelées au bord, maquettes estompées (transparence 0,45), note « Positions indicatives ».
- Lancements : Launch Library (10 max), cache 1 h, repli = 3 lancements illustratifs à heures relatives ; compte à rebours en « J−n · h h » ou « T−h h », « En cours » passé la date, ou le statut brut s'il n'est pas « Go ».
- Textures : cartes téléchargées (CDN jsdelivr), cache disque sans TTL, repli procédural dessiné localement. Aucun indicateur de chargement ; les textures se substituent silencieusement.

Zone dure — qui possède quoi :

- `selection/toucher-un-astre.md` possède le tap, les priorités, les rayons de saisie et la désélection par le vide.
- `selection/cartouche.md` possède la feuille (drag, snap à 42 %, chevron, liens de date, recadrage vertical de la scène, bascule début/fin par tap sur l'en-tête d'une sonde).
- `explorer/sondes.md` possède le recadrage de date à la sélection d'une sonde (si la date courante est hors période : aller à aujourd'hui si dedans, sinon à la borne la plus proche).
- `explorer/lancements.md` possède la séquence de tir entière (recul, transition de date, plongée, ascension 3,4 s, LAUNCH_DIVE = −0,7 s).
- `camera/orbite-libre.md` et `camera/geste-compose.md` possèdent les gestes ; `foundations/gestes-et-camera.md` possède les constantes et l'arbitrage.

## Ordre de travail

1. `foundations/` d'abord, dans l'ordre : gestes-et-camera, temps-et-timeline, scene-et-objets, donnees-et-reseau.
2. La zone dure ensuite : `selection/toucher-un-astre.md`, `selection/cartouche.md`, `explorer/lancements.md`. Lis tout `Engine.swift` avant de commencer, les états se passent la main.
3. Le reste (`camera/geste-compose.md`, `timeline/`, `explorer/panneau.md`, `explorer/sondes.md`, `explorer/satellites.md`) : indépendants, parallélisables avec des sous-agents. Donne à chacun ce fichier, les quatre exemplaires et le document à écrire ; relis chaque résultat contre le glossaire et les faits établis avant de l'accepter.
4. Passe de cohérence sur l'ensemble : même mot pour la même chose partout, pas deux documents décrivant différemment le même comportement, chaque lien relatif résout, chaque document a son pied de page, chaque terme employé est au glossaire.
5. Tiens à jour le tableau de couverture du README : `drafted` à l'écriture, jamais `verified` (la vérification à la main est une passe séparée).

## Règles de travail

- Commit après chaque document ou groupe cohérent : `docs: add {chemin}` ou `docs: revise {chemin}`. Pas d'attribution IA dans les messages (le dépôt n'en utilise pas).
- Ne modifie rien dans `native-ios/` ni ailleurs hors de `docs/product-description/`. Le code est une référence en lecture seule.
- N'ajoute pas de fichier hors de la structure du README sans mettre à jour structure et tableau de couverture.
- Quand un comportement ne peut pas être déterminé depuis le code, écris ce qui peut l'être, mets le reste en « Questions ouvertes », avance. Ne devine pas, ne bloque pas.
- Barre de profondeur : `camera/orbite-libre.md` fait environ 150–200 lignes pour un petit geste. Les documents de la zone dure seront plus longs ; les documents d'interface souvent plus courts. La complétude compte plus que la longueur : chaque état, chaque variante, chaque ligne d'interruption doit avoir une réponse, même « aucun effet ».
- Si la structure du README se révèle fausse (un document à scinder, deux à fusionner), change-la, mets à jour structure et couverture, et dis pourquoi dans le message de commit.

Tu as fini quand le tableau de couverture n'a plus de `not started`, que la passe de cohérence est faite et que tout est commité.
