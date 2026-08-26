# Vérification : explorer

Comment dérouler ce fichier : app lancée sur le simulateur, vue d'ensemble entre les sections (tap dans le vide). Ce fichier couvre le dock, le panneau et les listes Sondes et Satellites ; la séquence de tir (`explorer/lancements.md`, items TIR) a sa table dans [camera-et-selection.md](camera-et-selection.md), avec la zone dure qu'elle prolonge. Valeurs de la colonne Appareil : voir [README.md](README.md#appareils-et-conditions).

## explorer/panneau.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PANN-01 | P1 | simulateur | Le bouton Explorer ouvre le panneau, toujours sur l'onglet Sondes ([levé sans mouvement](../explorer/panneau.md#levé-sans-mouvement)). | Vue d'ensemble. | 1. Toucher le bouton ◎ à gauche du dock.<br>2. Fermer à la croix, passer sur Lancements ? Non : fermer, rouvrir. | Ouverture sur Sondes les deux fois, même si le panneau a été fermé depuis un autre onglet. | pass — ouverture sur Sondes vérifiée |
| PANN-02 | P1 | simulateur | L'onglet Satellites sélectionne la Terre et rapproche la caméra ([levé sans mouvement](../explorer/panneau.md#levé-sans-mouvement)). | Panneau ouvert, aucune sélection. | 1. Toucher l'onglet Satellites. | Cartouche « Terre », rapprochement net (plus près que pour une planète touchée). | pass — cartouche « Terre — 1,00 UA du Soleil », globe amené au premier plan |
| PANN-03 | P2 | simulateur | Le glyphe du bouton Explorer suit l'onglet : ◎ fermé, ✦ Sondes, ▣ Satellites, ↑ Lancements ([le cas simple](../explorer/panneau.md#le-cas-simple)). | — | 1. Passer par les trois onglets, puis fermer. | Le glyphe change à chaque onglet et revient à ◎ fermé. | pass — ◎ fermé, ✦ Sondes, ▣ Satellites, ↑ Lancements |
| PANN-04 | P2 | simulateur | La croix ferme le panneau sans toucher à la sélection ([levé sans mouvement](../explorer/panneau.md#levé-sans-mouvement)). | Onglet Satellites (Terre sélectionnée). | 1. Toucher la croix. | Panneau fermé, cartouche toujours « Terre », caméra inchangée. | — |
| PANN-05 | P2 | simulateur | Retoucher l'onglet Satellites déjà actif ré-impose le rapprochement ([cas limites](../explorer/panneau.md#cas-limites)) (défaut soupçonné). | Onglet Satellites, puis dézoomer largement au pincement. | 1. Retoucher l'onglet Satellites. | Noter : la caméra devrait se rapprocher de nouveau (l'effet de bord rejoue). | — |
| PANN-06 | P3 | simulateur | Les listes défilent dans un panneau à hauteur bornée ([le cas simple](../explorer/panneau.md#le-cas-simple)). | Onglet Sondes. | 1. Faire défiler la liste des 26 sondes. | La liste défile dans le panneau sans le déformer ; le dock reste en place. | — |

Non vérifiable à la main :

- Ce que VoiceOver annonce pour les glyphes ◎ ✦ ▣ ↑ et la croix (nécessite VoiceOver ; à faire sur appareil si possible, sinon consigner `blocked`).

## explorer/sondes.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SOND-01 | P1 | simulateur | Sélectionner une sonde dont la période contient la date courante ne déplace pas la date ([levé sans mouvement](../explorer/sondes.md#levé-sans-mouvement)). | Date d'aujourd'hui, panneau > Sondes. | 1. Toucher « Voyager 1 » (active aujourd'hui). | Le panneau se ferme, la caméra vise la sonde, la date ne bouge pas. | — |
| SOND-02 | P1 | simulateur | Sélectionner une sonde hors période recale la date : aujourd'hui si possible, sinon la borne la plus proche ([levé sans mouvement](../explorer/sondes.md#levé-sans-mouvement)). | Amener la date en 1990 (pas « Année »). | 1. Sélectionner « New Horizons » (2006–2030).<br>2. Lire la date d'arrivée. | Transition ~1 s vers aujourd'hui (2026, dans la période) ; poignée à 62 %. | — |
| SOND-03 | P1 | simulateur | La sonde sélectionnée montre sa trajectoire parcourue, cadrée par la caméra ([après la sélection](../explorer/sondes.md#après-la-sélection--la-sonde-suivie)). | Voyager 1 sélectionnée. | 1. Observer la scène. | Un trait continu du départ (Terre) à la position courante, entièrement dans le cadre, avec étiquette « Voyager 1 ». | — |
| SOND-04 | P2 | simulateur | Une sonde en orbite ne montre que sa dernière révolution ([après la sélection](../explorer/sondes.md#après-la-sélection--la-sonde-suivie)). | Sélectionner « Parker Solar Probe ». | 1. Observer la trace. | Une boucle environ, pas des dizaines de spires. | — |
| SOND-05 | P2 | simulateur | La bascule « Afficher toutes les sondes » montre toutes les sondes valides à la date, sans trace ni étiquette ([la bascule](../explorer/sondes.md#la-bascule--afficher-toutes-les-sondes-)). | Panneau > Sondes, date d'aujourd'hui. | 1. Allumer la bascule, fermer le panneau.<br>2. Compter grossièrement les octaèdres. | Une vingtaine de sondes visibles (les actives d'aujourd'hui), une seule trace (celle de la sélection, s'il y en a une). | — |
| SOND-06 | P2 | simulateur | Faire défiler la date fait apparaître et disparaître les sondes à leurs bornes ([variantes](../explorer/sondes.md#variantes)). | Bascule allumée, pas « Année ». | 1. Descendre vers 1970, remonter vers 2035. | Aucune sonde avant 1977 ; elles s'égrènent à leurs années de départ ; « 1977–2030 » disparaît début 2031. | — |
| SOND-07 | P2 | simulateur | Le pincement sur la sonde sélectionnée règle l'ampleur du cadrage (0,3–3) ([après la sélection](../explorer/sondes.md#après-la-sélection--la-sonde-suivie)). | Voyager 1 sélectionnée. | 1. Pincer dans les deux sens jusqu'aux butées. | Le cadrage se resserre jusqu'à ~un tiers et s'élargit jusqu'à ~trois fois, jamais au-delà. | — |
| SOND-08 | P3 | simulateur | La grille des sondes est triée par année de départ ([les 26 sondes](../explorer/sondes.md#les-26-sondes)). | Panneau > Sondes. | 1. Lire l'ordre des lignes. | Voyager 2 et 1 en tête (1977), les plus récentes à la fin. | pass — Pioneer 10 (1972) en tête, ordre croissant |

Non vérifiable à la main :

- Le champ `status` (« active »/« historic ») sans effet visible — question produit, pas testable.
- L'ordre de tri entre deux sondes au départ identique (dépend d'un tri non stable).

## explorer/satellites.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SATL-01 | P1 | simulateur | Sélectionner l'ISS ferme le panneau, place la caméra du côté de la station, dessine son orbite et son étiquette ([levé sans mouvement](../explorer/satellites.md#levé-sans-mouvement)). | Onglet Satellites. | 1. Toucher « ISS ». | Panneau fermé, maquette visible côté caméra (pas derrière le globe), fin trait d'orbite, étiquette « ISS ». | — |
| SATL-02 | P1 | simulateur | Sélectionner une constellation cadre le nuage entier, sans étiquette ni orbite ([levé sans mouvement](../explorer/satellites.md#levé-sans-mouvement)). | Onglet Satellites. | 1. Toucher « Starlink ». | Nuage de centaines de points autour du globe, cadré en entier ; pas d'étiquette. | — |
| SATL-03 | P1 | simulateur | La méta d'un engin pas encore lancé devient « lancé en {année} » et l'engin disparaît de la scène ([la méta d'une ligne](../explorer/satellites.md#la-méta-dune-ligne)). | Onglet Satellites, bascule allumée, pas « Année ». | 1. Amener la date en 1990.<br>2. Lire la ligne « ISS » et chercher la station. | Méta « lancé en 1998 », aucune maquette ISS dans la scène ; Hubble (1990) selon sa date exacte. | pass — à mai 1940, les cinq lignes affichent « lancé en {année} » |
| SATL-04 | P1 | simulateur | Sélectionner un satellite pas encore lancé cadre une position jamais posée — le Soleil au premier lancement ([questions ouvertes](../explorer/satellites.md#questions-ouvertes-et-vérification)) (défaut soupçonné). | App fraîche, date amenée en 1990, onglet Satellites. | 1. Toucher « Tiangong » (lancé en 2021). | Noter où va la caméra : le défaut prédit un cadrage sur le Soleil/le vide, très près. | fail — défaut confirmé (B-01) : la caméra se plaque dans le Soleil, écran entièrement jaune, cartouche « Tiangong » |
| SATL-05 | P2 | simulateur | La note du panneau suit l'état des données ([la note du bas de panneau](../explorer/satellites.md#la-note-du-bas-de-panneau)). | Onglet Satellites, réseau actif, puis date poussée à +3 mois. | 1. Lire la note à l'ouverture.<br>2. Pousser la date hors fenêtre, relire. | « Propagation SGP4 · TLE du {date} », puis « Positions indicatives · loin du TLE du {date} ». | pass — « Propagation SGP4 · TLE du 23 août 2026 » — mais visible seulement après avoir fait défiler la liste |
| SATL-06 | P2 | simulateur | Hors fenêtre SGP4, maquettes estompées et positions gelées ([variantes](../explorer/satellites.md#variantes)). | ISS sélectionnée, bascule allumée. | 1. Pousser la date à +3 mois.<br>2. Continuer à défiler. | La station cesse de parcourir son orbite et sa silhouette devient translucide. | — |
| SATL-07 | P2 | simulateur | La méta d'une constellation compte ses membres à la date simulée ([la méta d'une ligne](../explorer/satellites.md#la-méta-dune-ligne)). | Onglet Satellites, bascule allumée, Starlink visible. | 1. Lire « {n} satellites » aujourd'hui.<br>2. Amener la date en 2020, relire. | Le nombre baisse nettement en 2020 (moins de Starlink lancés). | pass — métas nominales à août 2026 : ISS 422 km · 51,6°, GPS « 1 satellite », Starlink « 30 satellites » |
| SATL-08 | P3 | réseau coupé | La méta GPS hors ligne : « lancé en 2018 » avant 2018, alors que la vraie constellation est bien plus ancienne ([questions ouvertes](../explorer/satellites.md#questions-ouvertes-et-vérification)) (défaut soupçonné). | Hors ligne, app fraîche, date en 2015. | 1. Lire la ligne GPS, chercher le nuage. | Noter : méta « lancé en 2018 » et nuage absent — l'année vient du premier TLE de repli. | fail — défaut confirmé (B-07), y compris réseau actif : à mai 1940, GPS affiche « lancé en 2018 » |

Non vérifiable à la main :

- Le gel du compte de membres quand le nuage n'est pas affiché (l'observer exige d'afficher le nuage, ce qui le recalcule).
