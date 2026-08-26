# Vérification : fondations

Comment dérouler ce fichier : app fraîchement installée sur le simulateur (supprimer l'app d'abord pour vider caches et autorisations), sauf mention contraire dans la mise en place. Les valeurs de la colonne Appareil sont celles de [README.md](README.md#appareils-et-conditions) : `simulateur`, `appareil`, `réseau coupé`, `localisation refusée`, `date réelle`.

## foundations/gestes-et-camera.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GEST-01 | P1 | simulateur | L'élévation est bornée avant la verticale : l'image ne bascule jamais tête en bas ([le rig de caméra](../foundations/gestes-et-camera.md#le-rig-de-caméra)). | Vue d'ensemble. | 1. Glisser vers le haut jusqu'à la butée, insister.<br>2. Recommencer vers le bas. | La vue s'arrête nettement avant la verticale (≈ 77°), dans les deux sens ; les orbites ne se retournent jamais. | — |
| GEST-02 | P1 | appareil | Un deuxième doigt posé pendant un glissement à un doigt l'annule sans élan ([l'arbitrage](../foundations/gestes-et-camera.md#larbitrage--qui-prend-la-main-sur-qui)). | Vue d'ensemble. | 1. Glisser vivement à un doigt, garder le doigt posé.<br>2. Poser un deuxième doigt.<br>3. Lever les deux d'un coup. | Aucun élan au lever : la caméra s'arrête net. Aucune rotation cumulée bizarre pendant la transition. | — |
| GEST-03 | P1 | simulateur | Le geste composé n'a jamais d'élan ([l'arbitrage](../foundations/gestes-et-camera.md#larbitrage--qui-prend-la-main-sur-qui)). | Vue d'ensemble. | 1. ⌥⇧-glisser vivement (orientation à deux doigts).<br>2. Relâcher en plein mouvement. | La rotation s'arrête exactement au relâchement. | — |
| GEST-04 | P2 | simulateur | Commencer un glissement abandonne une visée programmée, mais pas l'animation de distance ([élan et amortissements](../foundations/gestes-et-camera.md#élan-et-amortissements)). | Panneau Explorer > Sondes. | 1. Toucher « Voyager 1 » (la caméra part en visée).<br>2. Pendant le voyage de caméra, glisser à un doigt. | La rotation suit le doigt immédiatement ; le rapprochement (distance) continue tout seul. | — |
| GEST-05 | P2 | simulateur | Le pincement sur une sonde sélectionnée règle l'ampleur du cadrage, pas la distance libre ([le zoom et son exception](../foundations/gestes-et-camera.md#le-zoom-et-son-exception)). | Voyager 1 sélectionnée, trace visible. | 1. Pincer pour « zoomer » et « dézoomer ».<br>2. Comparer avec le même geste sur une planète. | Sur la sonde, le cadrage se resserre/s'élargit autour de la trajectoire avec des bornes nettes (0,3×–3×) ; sur la planète, zoom libre. | — |
| GEST-06 | P3 | simulateur | La sensibilité à deux doigts est réduite (72 %) ([les gestes de la scène](../foundations/gestes-et-camera.md#les-gestes-de-la-scène)). | Vue d'ensemble. | 1. Glisser 200 pt à un doigt, noter la rotation.<br>2. Même distance en ⌥⇧-glisser. | La rotation à deux doigts est visiblement plus courte (≈ trois quarts). | — |
| GEST-07 | P2 | simulateur | Il n'y a pas de geste de torsion : l'horizon reste toujours à plat ([les gestes de la scène](../foundations/gestes-et-camera.md#les-gestes-de-la-scène)). | Vue d'ensemble. | 1. ⌥-glisser circulaire (torsion à deux doigts) sur la scène. | L'horizon ne s'incline jamais ; seuls l'orientation et le zoom répondent. | — |

Non vérifiable à la main :

- Les constantes numériques exactes (0,007 rad/pt, exp(−5,2·t)…) — seules leurs conséquences visibles le sont.

## foundations/temps-et-timeline.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TEMP-01 | P1 | simulateur | Le temps ne s'écoule jamais tout seul ([la date simulée](../foundations/temps-et-timeline.md#la-date-simulée)). | App ouverte, aucune action. | 1. Noter la date de la poignée.<br>2. Attendre 3 minutes. | La date affichée n'a pas bougé (les minutes réelles ne défilent pas). | — |
| TEMP-02 | P1 | simulateur | Toute transition de date dépose la poignée à 62 % de sa course ([la fenêtre, la poignée et le pas](../foundations/temps-et-timeline.md#la-fenêtre-la-poignée-et-le-pas)). | Date écartée de plusieurs mois. | 1. Toucher « Aujourd'hui ».<br>2. Observer la position finale de la poignée. | La poignée finit un peu sous le milieu de sa course (62 %), pas au centre. | — |
| TEMP-03 | P1 | simulateur | Toucher la poignée pendant une transition l'arrête net ([les vitesses](../foundations/temps-et-timeline.md#les-vitesses)). | Sélectionner un lien de date lointain dans le cartouche d'une sonde. | 1. Pendant le voyage (moins d'une seconde), toucher la poignée. | Le défilement s'arrête à la date atteinte ; la poignée suit le doigt. | — |
| TEMP-04 | P2 | simulateur | Le défilement au bord : la fenêtre défile tant que le doigt reste au bord ([les vitesses](../foundations/temps-et-timeline.md#les-vitesses)). | Pas « Jour ». | 1. Tirer la poignée tout en bas et l'y maintenir 3 s.<br>2. Écarter légèrement le doigt du bord sans le lever. | Pendant le maintien, la date défile continûment vers le futur ; elle s'arrête dès que le doigt s'écarte du bord. | — |
| TEMP-05 | P2 | simulateur | Les traces apparaissent au défilement rapide et s'estompent à l'arrêt ([les traces de défilement](../foundations/temps-et-timeline.md#les-traces-de-défilement)). | Pas « Année », vue d'ensemble. | 1. Glisser vivement la poignée.<br>2. S'arrêter. | Des arcs colorés suivent les planètes pendant le défilement, disparaissent en ~une demi-seconde à l'arrêt. | — |
| TEMP-06 | P3 | simulateur | Le format de date suit le pas : heure au pas Heure, mois-année au pas Année ([l'affichage de la date](../foundations/temps-et-timeline.md#laffichage-de-la-date)). | — | 1. Passer par les quatre pas au menu d'échelle.<br>2. Lire la poignée à chaque fois. | « 25 août 14:30 » (Heure), « 25 août 2026 » (Jour, Mois), « août 2026 » (Année). | pass — « 26 août 2026 » au pas Jour, « août 2026 » au pas Année ; pas Heure non joué |
| TEMP-07 | P3 | simulateur | L'élan de timeline est plafonné proportionnellement au pas ([les vitesses](../foundations/temps-et-timeline.md#les-vitesses)). | Pas « Heure », puis pas « Année ». | 1. Lancer la poignée du même geste vif aux deux pas.<br>2. Comparer la durée traversée. | Au pas Heure, quelques heures défilent ; au pas Année, des décennies. Même ressenti de vitesse à l'écran. | — |

Non vérifiable à la main :

- La poursuite d'une transition sur l'horloge réelle pendant un passage en arrière-plan (trop rapide pour être observée fiablement).

## foundations/scene-et-objets.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SCEN-01 | P1 | simulateur | Les lunes n'apparaissent que quand leur planète (ou l'une d'elles) est sélectionnée ([les corps et leur visibilité](../foundations/scene-et-objets.md#les-corps-et-leur-visibilité)). | Vue d'ensemble. | 1. Vérifier qu'aucune lune n'est visible.<br>2. Toucher Jupiter.<br>3. Taper le vide. | Les quatre lunes et leurs orbites apparaissent à l'étape 2, disparaissent à l'étape 3. | pass |
| SCEN-02 | P1 | simulateur | Une sonde hors période disparaît mais reste « sélectionnée » au cartouche ([les corps et leur visibilité](../foundations/scene-et-objets.md#les-corps-et-leur-visibilité)). | Sélectionner New Horizons (2006–2030). | 1. Amener la date en 2000 (liens ou timeline, pas « Année »).<br>2. Observer scène et cartouche. | La sonde et sa trace disparaissent ; le cartouche garde « New Horizons » et son texte ; la caméra revient à la vue d'ensemble. (Défaut soupçonné : noter le comportement exact.) | — |
| SCEN-03 | P1 | localisation refusée | Sans autorisation, le point de géolocalisation est sur Paris ([le globe terrestre](../foundations/scene-et-objets.md#le-globe-terrestre)). | App fraîche, refuser la localisation. | 1. Onglet Satellites (la Terre s'approche).<br>2. Chercher le point bleu pulsant. | Le point est sur la France, et tourne avec le globe. | — |
| SCEN-04 | P2 | simulateur | Le globe est à l'heure : la géographie sous le point suit l'heure simulée ([le globe terrestre](../foundations/scene-et-objets.md#le-globe-terrestre)). | Terre sélectionnée, de près, pas « Heure ». | 1. Faire défiler quelques heures.<br>2. Observer la rotation du globe. | Le globe tourne d'environ 15° par heure simulée, entraînant le point. | — |
| SCEN-05 | P2 | simulateur | Une seule étiquette au plus : sonde ou satellite individuel sélectionné ([les étiquettes](../foundations/scene-et-objets.md#les-étiquettes)). | — | 1. Sélectionner une planète, une lune, une sonde, l'ISS, Starlink (tour à tour). | Étiquette seulement pour la sonde et l'ISS ; jamais pour planète, lune, constellation. | — |
| SCEN-06 | P3 | simulateur | Les directions sont exactes, les distances compressées ([l'échelle compressée](../foundations/scene-et-objets.md#léchelle-compressée)). | Vue de dessus (glisser jusqu'à la butée d'élévation). | 1. Comparer les écarts apparents Mercure–Soleil et Neptune–Soleil. | Neptune est nettement plus loin, mais bien moins que 78 fois plus. | — |

Non vérifiable à la main :

- Le rayon de scène exact (formule log) — seul l'ordre relatif se vérifie.
- Le ciel d'étoiles aléatoire regénéré à chaque lancement (comparer deux lancements est possible mais fragile).

## foundations/donnees-et-reseau.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DATA-01 | P1 | réseau coupé | L'app démarre et fonctionne entièrement hors ligne sur ses replis ([résumé](../foundations/donnees-et-reseau.md#résumé)). | App fraîche, réseau coupé avant lancement. | 1. Lancer l'app.<br>2. Parcourir : planètes, sondes, onglet Satellites, onglet Lancements. | Tout fonctionne ; textures schématiques ; satellites présents ; trois lancements illustratifs ; aucune erreur affichée. | — |
| DATA-02 | P1 | réseau coupé | Hors fenêtre SGP4 : positions gelées, maquettes estompées, note « Positions indicatives » ([les TLE et la fenêtre SGP4](../foundations/donnees-et-reseau.md#les-tle-et-la-fenêtre-sgp4)). | Hors ligne (TLE de repli, époque 23 août 2026), onglet Satellites, « Afficher tous ». | 1. Amener la date à décembre 2026.<br>2. Scruber encore : observer l'ISS.<br>3. Lire la note du panneau. | L'ISS cesse de bouger au-delà de la limite, sa maquette s'estompe, la note dit « Positions indicatives · loin du TLE du 23 août 2026 ». | — |
| DATA-03 | P2 | simulateur | Les textures se substituent silencieusement dans les premières secondes ([les textures](../foundations/donnees-et-reseau.md#les-textures)). | App fraîche, réseau actif. | 1. Lancer, toucher la Terre aussitôt.<br>2. Observer 10 s. | Le globe passe d'un dessin schématique à la vraie carte, sans indicateur ni transition. | pass — cartes réelles en place dès la première capture |
| DATA-04 | P2 | date réelle | Le compte à rebours des lancements se rafraîchit toutes les minutes ([les lancements](../foundations/donnees-et-reseau.md#les-lancements)). | Onglet Lancements ouvert. | 1. Noter un compte à rebours en heures.<br>2. Attendre le passage d'une heure pleine (jusqu'à 60 min) ou comparer à 5 min d'intervalle. | La valeur se met à jour sans action. | — |
| DATA-05 | P3 | réseau coupé | Les trois lancements de repli ont des dates relatives au lancement de l'app ([questions ouvertes](../foundations/donnees-et-reseau.md#questions-ouvertes-et-vérification)) (défaut soupçonné). | Hors ligne, app fraîche. | 1. Noter l'heure du premier tir.<br>2. Relancer l'app une heure plus tard, renoter. | Noter ce qui se passe : l'heure du « même » tir a glissé d'une heure. | — |

Non vérifiable à la main :

- Les TTL de cache (12 h / 1 h) — vérifiables seulement en manipulant l'horloge du système.
- La troncature des flux Starlink/GPS en octets.
