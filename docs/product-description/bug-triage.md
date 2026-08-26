# Bug triage

La liste consolidée des défauts et incohérences que les documents de fonctionnalité ont relevés dans leurs sections « Questions ouvertes et vérification » et dans leurs corps. Chaque entrée est lue depuis le code (`native-ios/SystemeSolaire/`, état `bb3744e`) ; les **trois** qui portent une ligne **Status** ont été confirmées sur l'app qui tourne lors de la passe outillée du 26 août 2026 (voir [verification/README.md](verification/README.md#résultats-à-ce-jour)). La liste existe pour que l'équipe produit décide, entrée par entrée : corriger, documenter comme voulu, ou laisser.

## Résumé

Les documents ont soulevé une vingtaine de soupçons ; après fusion par cause racine il en reste 15 : 2 hautes, 7 moyennes, 6 basses ; 4 sont confirmées sur l'app. Les deux grands foyers sont **l'élan de la timeline** (trois défauts dans la même poignée de lignes de `Engine.swift`) et **l'état « lancement sélectionné »**, qui garde la main sur la caméra plus longtemps et plus fort que l'utilisateur ne s'y attend. Un troisième foyer, plus diffus : des **valeurs figées au chargement** (année de lancement des constellations, effectif des nuages, liste des lancements) qui vieillissent sans se rafraîchir.

| ID | Titre | Gravité | Zone | Décision | Issue |
| --- | --- | --- | --- | --- | --- |
| B-01 | Sélectionner un satellite pas encore lancé cadre le vide (le Soleil) | high | explorer | fix | — |
| B-02 | Le pincement est inopérant tant qu'un lancement est sélectionné | high | camera | fix | — |
| B-03 | Au pas Heure, l'élan de la timeline ne part jamais | medium | timeline | fix | — |
| B-04 | Un élan « fantôme » repart après une pause du doigt | medium | timeline | fix | — |
| B-05 | Lever le doigt au bord relance l'élan sur une vitesse périmée | medium | timeline | fix | — |
| B-06 | La caméra reste prisonnière du tir quand on sélectionne un autre astre | medium | explorer | fix | — |
| B-07 | GPS entier daté du premier TLE : constellation absente avant 2018 | medium | explorer | fix | — |
| B-08 | L'effectif affiché d'une constellation masquée est figé sur une autre date | medium | explorer | fix | — |
| B-09 | Listes de lancements et TLE jamais rafraîchis en session longue | medium | données | product call |  — |
| B-10 | La bascule début/fin de mission est indécouvrable | low | selection | product call | — |
| B-11 | Le menu d'échelle peut rester ouvert sans moyen évident de le fermer | low | timeline | fix | — |
| B-12 | Une transition de date peut se battre avec le doigt sur la poignée | low | timeline | fix | — |
| B-13 | Pincer une sonde sélectionnée invisible règle un cadrage à l'aveugle | low | camera | fix | — |
| B-15 | La note de fraîcheur des TLE est sous la ligne de flottaison | low | explorer | fix | — |
| B-14 | Petites bizarreries assumables (repli des lancements, `status` inutilisé, re-tap d'onglet) | low | divers | product call | — |

## High

### B-01 : Sélectionner un satellite pas encore lancé cadre le vide (le Soleil)

- **Où l'utilisateur le rencontre :** date simulée amenée avant l'année de lancement d'un satellite (par exemple 1990), onglet Satellites, tap sur « Tiangong » (2021). La ligne dit « lancé en 2021 », mais elle reste touchable.
- **Ce qui se passe / ce qui était attendu :** la caméra part cadrer, à distance 5, la dernière position connue de la maquette — jamais posée depuis le lancement de l'app, donc l'origine de la scène : le Soleil, vu de très près. Attendu : un refus de sélection, ou un cadrage sur la Terre.
- **Reproduire :** app fraîche → pas « Année » → tirer la date en 1990 → panneau Explorer → Satellites → toucher Tiangong. Item [SATL-04](verification/explorer.md).
- **Pourquoi (dans le code) :** `Engine.swift:712` (`selectSatellite`) vise `model.node.position`, qui n'est écrite que quand la maquette est affichée (`Engine.swift:1287`) ; cachée depuis le démarrage, elle vaut (0, 0, 0).
- **Gravité :** `high` — l'utilisateur se retrouve plaqué contre le Soleil sans comprendre, à l'opposé de ce qu'il a demandé.
- **Décision :** `fix` — refuser la sélection d'un engin non né (comme la scène le fait déjà pour le tap), ou rabattre sur la Terre.
- **Raised by :** [explorer/satellites.md](explorer/satellites.md#questions-ouvertes-et-vérification).
- **Status :** confirmé le 26 août 2026 sur simulateur iPhone 17 Pro (item SATL-04), et pire que prévu : l'écran se remplit entièrement de la texture du Soleil, sans repère ni horizon. Le cartouche affiche « Tiangong — lancé en 2021 ». Seule issue trouvée : un tap dans le vide (vérifié, item TOUCH-02).

### B-02 : Le pincement est inopérant tant qu'un lancement est sélectionné

- **Où l'utilisateur le rencontre :** après avoir sélectionné un lancement — pendant la séquence de tir et indéfiniment après, tant que le tir est affiché — il pince pour prendre du recul sur la trajectoire.
- **Ce qui se passe / ce qui était attendu :** rien : le geste est reconnu mais la distance revient aussitôt à sa valeur imposée. L'orientation répond, la distance non. Attendu : zoomer librement autour du tir.
- **Reproduire :** onglet Lancements → toucher un tir → attendre la fin de l'ascension → pincer. Item [TIR-02](verification/camera-et-selection.md).
- **Pourquoi (dans le code) :** `Engine.swift:1328` réécrit `goalDist` (10 ou 1,5) à chaque image tant que `selectedLaunch != nil` ; le réglage du pincement est écrasé à l'image suivante.
- **Gravité :** `high` — un geste central du produit est silencieusement sans effet dans un état où l'on reste longtemps.
- **Décision :** `fix` — ne forcer la distance que pendant la séquence (jusqu'à la fin de l'ascension), puis rendre la main au pincement.
- **Raised by :** [explorer/lancements.md](explorer/lancements.md#questions-ouvertes-et-vérification), [camera/geste-compose.md](camera/geste-compose.md#questions-ouvertes-et-vérification).
- **Status :** confirmé le 26 août 2026 (item TIR-02) : après la séquence de tir de « Starlink Group 15-22 », un pincement à deux doigts pour reculer laisse l'image strictement inchangée, au pixel près.

## Medium

### B-03 : Au pas Heure, l'élan de la timeline ne part jamais

- **Où l'utilisateur le rencontre :** pas « Heure », lancer la poignée d'un geste vif : la date s'arrête net au lever, à chaque fois.
- **Ce qui se passe / ce qui était attendu :** le plafond de vitesse au pas Heure (fenêtre/4 par seconde = 4,2/4000 ≈ 0,00105 jour/ms) est inférieur au seuil de déclenchement de l'élan (0,003 jour/ms) : la condition d'élan est mathématiquement inatteignable. Attendu : le même élan qu'aux autres pas, à l'échelle.
- **Reproduire :** menu d'échelle → Heure → lancer la poignée. Item [GLIS-04](verification/timeline.md).
- **Pourquoi (dans le code) :** `Engine.swift:1065` (plafond `dayRange / 4000`) contre `Engine.swift:1078` (seuil fixe `0.003` dans `timelineDragEnded`). Le seuil ne suit pas le pas.
- **Gravité :** `medium` — comportement incohérent entre pas, pas de perte de données.
- **Décision :** `fix` — proportionner le seuil au pas (par exemple `dayRange / 4000 × 0,1`).
- **Raised by :** [timeline/glissement.md](timeline/glissement.md#questions-ouvertes-et-vérification).

### B-04 : Un élan « fantôme » repart après une pause du doigt

- **Où l'utilisateur le rencontre :** tirer la poignée vite, s'immobiliser deux secondes sans lever, lever : la date repart d'elle-même.
- **Ce qui se passe / ce qui était attendu :** la vitesse mesurée n'est mise à jour qu'aux événements de déplacement ; immobile, elle garde sa dernière valeur, et le lever la transforme en élan. Attendu : un lever immobile arrête la date net.
- **Reproduire :** pas « Mois » → tirer vite → pause 2 s → lever. Item [GLIS-05](verification/timeline.md).
- **Pourquoi (dans le code) :** `Engine.swift:1066` (lissage de `timelineVelocity` uniquement dans `timelineDragChanged`) ; `timelineDragEnded` (`Engine.swift:1077`) ne regarde pas depuis combien de temps le doigt est immobile.
- **Gravité :** `medium` — mouvement non commandé, déroutant, mais sans perte.
- **Décision :** `fix` — décrémenter la vitesse sur l'horloge (ou l'annuler si le dernier déplacement date de plus de ~100 ms).
- **Raised by :** [timeline/glissement.md](timeline/glissement.md#questions-ouvertes-et-vérification).

### B-05 : Lever le doigt au bord relance l'élan sur une vitesse périmée

- **Où l'utilisateur le rencontre :** tirer la poignée jusqu'au bord (défilement au bord), puis lever le doigt sans revenir : la date repart sur l'élan de la vitesse d'avant l'entrée au bord.
- **Ce qui se passe / ce qui était attendu :** l'élan est inhibé *pendant* le défilement au bord mais pas *au lever depuis* le bord. Attendu : lever au bord arrête le défilement, point.
- **Reproduire :** pas « Mois » → tirer vite jusqu'en bas → laisser défiler 2 s → lever. Item [GLIS-07](verification/timeline.md).
- **Pourquoi (dans le code) :** `Engine.swift:1076` (`timelineDragEnded`) remet `edgeDirection = 0` puis laisse `timelineVelocity` (dernière valeur mesurée avant le bord) alimenter l'inertie de la boucle de rendu (`Engine.swift:1152`).
- **Gravité :** `medium` — même famille que B-04.
- **Décision :** `fix` — annuler `timelineVelocity` quand le lever survient en défilement au bord.
- **Raised by :** [timeline/glissement.md](timeline/glissement.md#questions-ouvertes-et-vérification).

### B-06 : La caméra reste prisonnière du tir quand on sélectionne un autre astre

- **Où l'utilisateur le rencontre :** tir affiché, il touche une planète (ou la Terre) : le cartouche change, mais la caméra reste collée à la trajectoire de lancement.
- **Ce qui se passe / ce qui était attendu :** le cadrage du lancement garde la priorité sur toute sélection d'astre (sauf une sonde) tant que le lancement n'est pas désélectionné. Attendu : la sélection d'un astre reprend la caméra.
- **Reproduire :** sélectionner un lancement → fin d'ascension → toucher une planète visible. Item [TIR-03](verification/camera-et-selection.md).
- **Pourquoi (dans le code) :** dans la boucle de rendu, la branche de cible `else if let launch = selectedLaunch` (`Engine.swift:1411`) passe avant la branche de la sélection générique ; et rien ne désélectionne le lancement quand `setSelected` reçoit un autre astre (`Engine.swift:632`).
- **Gravité :** `medium` — combiné à B-02 (zoom inopérant), l'utilisateur est réellement coincé jusqu'au tap dans le vide.
- **Décision :** `fix` — désélectionner le lancement dès que la sélection d'astre change (comme le fait déjà la sélection d'une sonde).
- **Raised by :** [explorer/lancements.md](explorer/lancements.md#questions-ouvertes-et-vérification), [selection/toucher-un-astre.md](selection/toucher-un-astre.md#cas-limites).

### B-07 : GPS entier daté du premier TLE : constellation absente avant 2018

- **Où l'utilisateur le rencontre :** date simulée en 2015, bascule « Afficher tous les satellites » : le nuage GPS est absent et sa ligne dit « lancé en 2018 » — alors que la constellation GPS vole depuis 1978.
- **Ce qui se passe / ce qui était attendu :** l'année de « naissance » d'une constellation entière est lue sur la *première ligne* de son TLE de repli et n'est jamais recalculée après le chargement réseau ; elle masque toute la constellation avant cette date. Attendu : chaque membre apparaît à sa propre année (ce que le nuage fait déjà, quand il est affiché).
- **Reproduire :** hors ligne, date en 2015, onglet Satellites. Item [SATL-08](verification/explorer.md).
- **Pourquoi (dans le code) :** `Engine.swift:479` (`launchYear` posé depuis `spec.tleFallback`) ; la mise à jour après chargement (`Engine.swift:586`) ne couvre que les satellites individuels ; le test de naissance (`Engine.swift:1266`) applique cette année au modèle entier.
- **Gravité :** `medium` — donnée fausse affichée, constellation entière escamotée à tort.
- **Décision :** `fix` — pour une constellation, prendre l'année du membre le plus ancien (ou ne pas appliquer de naissance au modèle entier).
- **Raised by :** [explorer/satellites.md](explorer/satellites.md#questions-ouvertes-et-vérification).
- **Status :** confirmé le 26 août 2026 (item SATL-08), **réseau actif** — le défaut ne tient donc pas au seul mode hors ligne : à mai 1940, la ligne GPS affiche « lancé en 2018 » et Starlink « lancé en 2019 ».

### B-08 : L'effectif affiché d'une constellation masquée est figé sur une autre date

- **Où l'utilisateur le rencontre :** onglet Satellites, bascule éteinte : la méta « {n} satellites » de GPS ou Starlink peut refléter la date d'un affichage précédent, pas la date courante.
- **Ce qui se passe / ce qui était attendu :** le compte de membres n'est recalculé que quand le nuage est effectivement affiché. Attendu : la méta suit la date simulée comme les autres lignes.
- **Reproduire :** afficher Starlink en 2020 (compte bas), désélectionner et éteindre la bascule, revenir à aujourd'hui, rouvrir l'onglet : lire le compte.
- **Pourquoi (dans le code) :** `updateConstellation` (`Engine.swift:1463`) n'est appelée que sous condition `shown` dans la boucle de rendu (`Engine.swift:1272`) ; `aliveCount` (`Engine.swift:62`, lu en `Engine.swift:629`) vieillit sinon.
- **Gravité :** `medium` — chiffre faux à l'écran, discret mais réel.
- **Décision :** `fix` — recalculer l'effectif (sans reconstruire le nuage) quand l'onglet est ouvert.
- **Raised by :** [explorer/satellites.md](explorer/satellites.md#questions-ouvertes-et-vérification).

### B-09 : Listes de lancements et TLE jamais rafraîchis en session longue

- **Où l'utilisateur le rencontre :** l'app reste ouverte plusieurs jours (elle n'est jamais tuée) : les comptes à rebours des lancements continuent de se mettre à jour, mais sur une liste figée au démarrage — tirs déjà partis, reportés, nouveaux tirs absents. Les TLE vieillissent de même.
- **Ce qui se passe / ce qui était attendu :** les deux flux ne sont chargés qu'à l'initialisation (`Engine.swift:225`-`226`), jamais au retour au premier plan. Les caches (1 h / 12 h) ne servent qu'entre lancements de l'app.
- **Reproduire :** difficilement à la main (session de plusieurs heures) ; constat de code.
- **Pourquoi (dans le code) :** `Task { await loadSatelliteElements() }` et `Task { await loadLaunches() }` uniquement dans `Engine.init` ; aucun observateur de `scenePhase` ou de `willEnterForeground`.
- **Gravité :** `medium` — l'app affiche du temps réel (« T−3 h ») sur des données mortes ; trompeur, mais sans casse.
- **Décision :** `product call` — rafraîchir au retour au premier plan (simple), ou assumer le cycle de vie court d'une app de démonstration.
- **Raised by :** [foundations/donnees-et-reseau.md](foundations/donnees-et-reseau.md#questions-ouvertes-et-vérification), [explorer/lancements.md](explorer/lancements.md#questions-ouvertes-et-vérification).

## Low

### B-10 : La bascule début/fin de mission est indécouvrable

- **Où l'utilisateur le rencontre :** sonde sélectionnée : un tap sur le titre du cartouche téléporte la date au début, puis à la fin, de la mission. Rien — ni libellé, ni icône, ni état — n'indique que ce tap existe ni ce qu'il fera.
- **Ce qui se passe / ce qui était attendu :** fonctionnalité utile mais invisible ; l'utilisateur qui la déclenche par accident voit la date sauter sans comprendre.
- **Reproduire :** sélectionner Voyager 1 → taper le titre du cartouche. Item [CART-04](verification/camera-et-selection.md).
- **Pourquoi (dans le code) :** `ContentView.swift` (`onTapGesture` sur l'en-tête, `infoCardTapped` en `Engine.swift:1014`) ; aucun affordance.
- **Gravité :** `low` — découvrabilité, pas dysfonctionnement.
- **Décision :** `product call` — ajouter un indice (deux petites bornes « début/fin »), ou déplacer l'action.
- **Raised by :** [selection/cartouche.md](selection/cartouche.md#questions-ouvertes-et-vérification).

### B-11 : Le menu d'échelle peut rester ouvert sans moyen évident de le fermer

- **Où l'utilisateur le rencontre :** menu d'échelle ouvert, puis cartouche déplié : le bouton d'échelle devient intouchable (dock estompé) alors que le menu reste ouvert et actif. Ni le tap sur la scène ni l'ouverture du panneau… si : le bouton Explorer est estompé aussi. Restent : choisir un pas, ou replier le cartouche.
- **Ce qui se passe / ce qui était attendu :** un menu qu'on ne peut plus fermer par son bouton. Attendu : le dépliage du cartouche ferme le menu, ou un tap hors du menu le ferme.
- **Reproduire :** sélectionner une planète → ouvrir le menu d'échelle → déplier le cartouche. Item [ECHE-05](verification/timeline.md).
- **Pourquoi (dans le code) :** `ContentView.swift:5` (`scaleMenuOpen` n'est remis à faux que par le bouton d'échelle, une ligne du menu, ou le bouton Explorer `ContentView.swift:71`) ; aucun lien avec l'état du cartouche ; l'asymétrie menu/panneau vient de là aussi.
- **Gravité :** `low` — état bizarre, sortie possible.
- **Décision :** `fix` — fermer le menu au dépliage du cartouche et au tap sur la scène.
- **Raised by :** [timeline/echelle-et-aujourdhui.md](timeline/echelle-et-aujourdhui.md#questions-ouvertes-et-vérification).

### B-12 : Une transition de date peut se battre avec le doigt sur la poignée

- **Où l'utilisateur le rencontre :** en tirant la poignée d'une main, il touche de l'autre un lien de date (ou une sonde hors période dans le panneau) : la transition et le doigt écrivent la date en alternance.
- **Ce qui se passe / ce qui était attendu :** le contact avec la poignée purge une transition en cours, mais une transition démarrée *après* le début du glissement n'est purgée nulle part. Attendu : le doigt garde la main.
- **Reproduire :** item [GLIS-10](verification/timeline.md) (à deux mains).
- **Pourquoi (dans le code) :** `timelineDragBegan` (`Engine.swift:1051`) purge `dateTransition` ; `timelineDragChanged` (`Engine.swift:1059`) ne le fait pas ; la boucle de rendu applique les deux.
- **Gravité :** `low` — exige deux mains et un timing improbable.
- **Décision :** `fix` — purger `dateTransition` dans `timelineDragChanged` aussi.
- **Raised by :** [timeline/glissement.md](timeline/glissement.md#questions-ouvertes-et-vérification).

### B-13 : Pincer une sonde sélectionnée invisible règle un cadrage à l'aveugle

- **Où l'utilisateur le rencontre :** sonde sélectionnée puis date sortie de sa période (la caméra est revenue à la vue d'ensemble) : un pincement ne fait rien à l'écran, mais règle l'ampleur du futur cadrage ; quand la date revient dans la période, la trajectoire réapparaît cadrée « au hasard ».
- **Ce qui se passe / ce qui était attendu :** l'exception du pincement s'applique à toute sonde sélectionnée, visible ou non. Attendu : hors période, le pincement zoome normalement.
- **Reproduire :** item [COMPO-07](verification/camera-et-selection.md).
- **Pourquoi (dans le code) :** `pinchChanged` (`Engine.swift:948`) teste `case .mission = selected` sans tester la visibilité.
- **Gravité :** `low` — chemin rare, conséquence bénigne.
- **Décision :** `fix` — conditionner l'exception à la visibilité de la sonde.
- **Raised by :** [camera/geste-compose.md](camera/geste-compose.md#questions-ouvertes-et-vérification).

### B-15 : La note de fraîcheur des TLE est sous la ligne de flottaison

- **Où l'utilisateur le rencontre :** onglet Satellites ouvert : la note (« Propagation SGP4 · TLE du 23 août 2026 » / « Positions indicatives · … ») n'est pas visible tant qu'on n'a pas fait défiler la liste vers le bas.
- **Ce qui se passe / ce qui était attendu :** la zone de liste est plafonnée à 360 points et son contenu est plus haut ; la note, placée en dernier, est clippée au repos. C'est le **seul** endroit de l'app qui dit d'où viennent les positions et si elles sont encore fiables — le garde-fou le plus important du produit est celui qu'on ne voit pas.
- **Reproduire :** panneau Explorer → Satellites → lire le bas du panneau sans faire défiler : la bascule est la dernière chose visible. Faire défiler d'une centaine de points : la note apparaît. Item [SATL-05](verification/explorer.md).
- **Pourquoi (dans le code) :** `ExplorerPanel.swift` — la note est le dernier enfant du `VStack` de `SatelliteList`, à l'intérieur du `ScrollView` borné par `frame(maxHeight: 360)`.
- **Gravité :** `low` — l'information existe et reste accessible.
- **Décision :** `fix` — sortir la note du défilement et la fixer sous le panneau, comme la mention « Fenêtres indicatives » de l'onglet Lancements (qui, elle, souffre du même clipping).
- **Raised by :** [explorer/satellites.md](explorer/satellites.md#la-note-du-bas-de-panneau) ; découvert pendant la passe du 26 août 2026.
- **Status :** confirmé le 26 août 2026 (item SATL-05).

### B-14 : Petites bizarreries assumables

Groupées : même décision (`product call`), gravité `low` chacune.

- **Les trois lancements de repli ont des dates relatives au lancement de l'app** : deux sessions montrent des heures de tir différentes pour la « même » mission (`SatelliteData.swift:118` et suivantes, `offsetHours`). Assumable pour un repli illustratif ; le signaler dans la liste serait plus honnête. Item [DATA-05](verification/fondations.md). — [foundations/donnees-et-reseau.md](foundations/donnees-et-reseau.md#questions-ouvertes-et-vérification)
- **Le champ `status` (« active »/« historic ») des sondes n'a aucun effet** (`MissionData.swift`) : probable reliquat du prototype HTML, qui avait un filtre « missions historiques » que l'app native n'a pas. Supprimer le champ ou ajouter le filtre. — [explorer/sondes.md](explorer/sondes.md#questions-ouvertes-et-vérification)
- **Retoucher l'onglet Satellites déjà actif ré-impose la distance 9** (`Engine.swift:674`, `setExploreView` ne teste pas l'onglet courant) : un utilisateur qui a dézoomé se fait ramener. Item [PANN-05](verification/explorer.md). — [explorer/panneau.md](explorer/panneau.md#questions-ouvertes-et-vérification)
- **Une sonde sélectionnée hors période reste « sélectionnée » au cartouche** pendant que la scène est en vue d'ensemble — cohérent (elle revient avec la date) mais troublant ; un sous-titre « hors période » lèverait l'ambiguïté. Item [SCEN-02](verification/fondations.md). — [foundations/scene-et-objets.md](foundations/scene-et-objets.md#questions-ouvertes-et-vérification), [explorer/sondes.md](explorer/sondes.md#annulation-et-interruption)
