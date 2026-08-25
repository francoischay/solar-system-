# Scène et objets

## Résumé

Ce document possède le contenu de la scène : quels corps existent, à quelle échelle, quand chacun est visible, ce que chaque type de sélection impose à la caméra, et les éléments passifs (étoiles, point de géolocalisation, étiquettes). Les interactions qui sélectionnent ces corps sont racontées dans [selection/toucher-un-astre.md](../selection/toucher-un-astre.md) et les documents d'`explorer/`.

## L'échelle compressée

La scène n'est pas à l'échelle, et c'est un choix : à l'échelle réelle, on ne verrait rien. Deux compressions logarithmiques cohabitent :

- **Héliocentrique** : la distance au Soleil, en unités astronomiques, devient un rayon de scène entre 12 (à 0 UA) et 100 (à 30,07 UA, l'orbite de Neptune). Mercure orbite donc à ~16 et Neptune à ~100 : l'écart réel de 1 à 78 est ramené à 1 à 6. La *direction* de chaque corps est exacte à tout instant ; seule la distance apparente est compressée. Les sondes lointaines (Voyager, à 170 UA) continuent la même courbe au-delà de 100.
- **Autour de la Terre** : le globe a un rayon de 1,2 ; la Lune orbite à 3,1 ; entre les deux, l'altitude des satellites est compressée pour préserver l'ordre réel — surface < orbite basse (ISS, Hubble, Starlink) < orbite moyenne (GPS) < Lune — sans respecter les proportions.

Les tailles des corps sont elles aussi symboliques (la Terre fait 1,2, Jupiter 2,8) ; les sondes et satellites sont dessinés à taille d'écran à peu près constante, pour rester lisibles à toute distance.

## Les corps et leur visibilité

| Corps | Combien | Visible quand |
| --- | --- | --- |
| Soleil | 1 | Toujours (avec halo) |
| Planètes | 8 | Toujours, avec leurs orbites en filigrane |
| Lunes | 22 | Leur planète ou l'une de ses lunes est sélectionnée |
| Sondes | 26 | (Sélectionnée ou « afficher toutes ») **et** date dans la période de validité |
| Satellites individuels | 3 (ISS, Hubble, Tiangong) | (Sélectionné ou « afficher tous ») **et** lancé à la date simulée **et** TLE chargés |
| Constellations | 2 (GPS, Starlink) | Mêmes conditions ; chaque point du nuage n'apparaît qu'après le lancement du satellite qu'il représente |
| Étoiles | 520 points | Toujours, décor fixe |

Règles de visibilité qui surprennent :

- **La période de validité d'une sonde court de son année de départ à son année de fin + 1** : une sonde « 1977–2030 » disparaît au 1ᵉʳ janvier 2032. Hors période, la sonde n'existe pas — ni visible, ni touchable ; si elle était sélectionnée, la sélection reste (titre et texte au cartouche) mais la caméra revient à la vue d'ensemble.
- **Un satellite « pas encore lancé » à la date simulée n'existe pas non plus** ; la ligne de sa liste affiche « lancé en {année} ». Une constellation dont aucun membre n'est lancé affiche « aucun de ces satellites à cette date ».
- **Les orbites des planètes sont toujours dessinées** (très discrètement) ; celles des lunes n'apparaissent qu'avec elles ; celle d'un satellite individuel n'apparaît qu'avec lui ; les constellations n'ont pas d'orbites dessinées.

## Ce que chaque sélection impose à la caméra

Sélectionner un corps amène la caméra à une distance d'arrivée propre au type ; l'utilisateur peut ensuite zoomer librement.

| Sélection | Distance d'arrivée | Visée |
| --- | --- | --- |
| Planète | 42 | Aucune (l'angle courant est conservé) |
| Lune | 14 | Aucune |
| Sonde | 34, puis cadrage automatique de la trajectoire parcourue | Vers la position de la sonde, légèrement au-dessus du plan |
| Satellite individuel | 5 | Du côté du satellite, pour qu'il ne soit pas derrière la Terre |
| Constellation | Cadrage moyen du nuage (×2,8 du rayon moyen, minimum 5) | Angle fixe |
| Terre via l'onglet Satellites | 9 | Aucune |
| Lancement | 12, puis 10 (recul), puis 1,5 (plongée) | Vers le pas de tir, tel qu'il sera orienté à la date du tir |

La vue d'ensemble (après un tap dans le vide) est à 230, cible au centre, roulis remis à zéro.

## Le globe terrestre

La Terre est le seul corps « daté » finement : le globe tourne selon le temps sidéral (une rotation par jour sidéral, calée sur Greenwich) et porte l'inclinaison réelle de 23,44°. Conséquence visible : à une date et une heure données, la face éclairée-géographie du globe est la vraie — le point de géolocalisation passe au-dessus de l'horizon aux bonnes heures.

**Le point de géolocalisation** : un point bleu pulsant, posé sur le globe à la position de l'utilisateur, solidaire de la rotation. Au premier lancement, l'app demande l'autorisation de localisation ; refusée ou en attente, le point est posé sur Paris (48,8566 N, 2,3522 E). La position est lue une fois par lancement de l'app, sans suivi continu. Le point n'est pas touchable et n'a pas d'étiquette.

## Les étiquettes

Une seule étiquette à la fois, au plus : le badge nommé qui suit à l'écran la sonde sélectionnée ou le satellite individuel sélectionné. Ni les planètes, ni les lunes, ni les constellations, ni les lancements n'ont d'étiquette. L'étiquette disparaît quand l'objet sort du champ ou cesse d'être visible ; elle est purement indicative et ne réagit pas au toucher.

## Les traces

Deux natures de traces, à ne pas confondre :

- **Les traces de défilement** (planètes et lunes visibles) : l'arc de trajectoire récente qui apparaît quand le temps défile vite et s'estompe à l'arrêt. Elles appartiennent à [Temps et timeline](temps-et-timeline.md).
- **La trace de la sonde sélectionnée** : sa trajectoire déjà parcourue, du départ à la date courante, affichée en permanence tant qu'elle est sélectionnée et visible. Une sonde en orbite (Parker, Juno…) ne montre que sa dernière révolution. La caméra cadre cette trace, pas la sonde seule.

## Variantes

Sans objet : ce document ne décrit pas une interaction. Les règles ci-dessus *sont* les variantes que les documents de geste référencent.

## Annulation et interruption

Ce que la liste standard signifie pour le contenu de la scène :

- **Taper le vide** : vue d'ensemble — désélection totale (astre et lancement), lunes cachées, trace de sonde éteinte, étiquette éteinte, roulis à zéro, distance 230.
- **Un deuxième doigt se pose** : sans effet sur le contenu.
- **Une transition de date démarre** : le contenu suit la date — des sondes et satellites peuvent apparaître ou disparaître pendant le voyage.
- **Le système annule le toucher / l'app passe en arrière-plan** : le contenu est figé tel quel et retrouvé tel quel ; les chargements réseau en cours continuent ou reprennent silencieusement.
- **La cible disparaît** (sonde hors période, satellite non lancé) : le corps cesse d'exister dans la scène. La *sélection*, elle, subsiste : le cartouche garde titre et texte, et le corps réapparaît si la date revient dans sa fenêtre. Pour une sonde, la caméra revient à la vue d'ensemble tant qu'elle est invisible, et recadre sa trajectoire à son retour.
- **Le réseau manque** : les corps utilisent leurs replis — voir [Données et réseau](donnees-et-reseau.md) ; aucune silhouette ne manque, seules les textures et la fraîcheur des positions changent.
- **L'appareil pivote** : la scène se recadre dans le nouveau format ; aucune règle de visibilité ne change.

## Questions ouvertes et vérification

- Le retour de caméra à la vue d'ensemble quand la sonde sélectionnée sort de sa période (sélection conservée, cible perdue) est déduit du code ; l'effet à l'œil — un dézoom brutal ou amorti — est à vérifier.
- Le point de géolocalisation ne se met à jour qu'au lancement ; si l'utilisateur autorise la localisation *après* le premier refus (dans Réglages), le point reste sur Paris jusqu'au prochain lancement. À confirmer ; possible sujet de triage.
- La demande d'autorisation de localisation part à l'apparition de l'écran, avant tout geste ; le texte système affiché dépend de la configuration du projet et n'a pas été vérifié.
- Les 520 étoiles sont un décor aléatoire regénéré à chaque lancement ; le ciel n'est pas le vrai ciel. Choix assumé, non signalé à l'utilisateur.

Vérifié contre le dossier natif au commit `ddd8314`.
