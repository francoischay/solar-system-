# Vérification : timeline

Comment dérouler ce fichier : app lancée sur le simulateur, vue d'ensemble, pas « Jour » (le défaut) sauf mention contraire. Un tap dans le vide entre les sections ramène à l'état propre. Valeurs de la colonne Appareil : voir [README.md](README.md#appareils-et-conditions).

## timeline/glissement.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GLIS-01 | P1 | simulateur | Le contact avec la poignée arrête net toute transition ou élan en cours ([le doigt se pose](../timeline/glissement.md#le-doigt-se-pose)). | Une transition en cours (toucher un lien de date lointain). | 1. Pendant le voyage, poser le doigt sur la poignée sans bouger.<br>2. Lever. | La date s'arrête là où elle était à l'instant du contact et n'en bouge plus. | — |
| GLIS-02 | P1 | simulateur | Le suivi est direct : la date suit exactement la position du doigt dans la fenêtre ([pendant le geste](../timeline/glissement.md#pendant-le-geste)). | Pas « Jour ». | 1. Tirer la poignée du haut de sa course au bas, lentement. | La date traverse ~100 jours, continûment, sans saut ni retard. | — |
| GLIS-03 | P1 | simulateur | Lâcher en mouvement donne un élan qui décélère ; la poignée, elle, ne bouge plus ([le doigt se lève](../timeline/glissement.md#le-doigt-se-lève)). | Pas « Mois ». | 1. Lancer la poignée d'un geste vif, lâcher.<br>2. Observer poignée et date. | La date continue de défiler en ralentissant plusieurs secondes ; la poignée reste immobile à sa hauteur de lâcher. | — |
| GLIS-04 | P1 | simulateur | Au pas Heure, aucun lever ne produit d'élan ([cas limites](../timeline/glissement.md#cas-limites)) (défaut soupçonné). | Pas « Heure ». | 1. Lancer la poignée du geste le plus vif possible, lâcher. | Noter ce qui se passe : la date devrait s'arrêter net à chaque fois. | — |
| GLIS-05 | P1 | simulateur | Immobiliser le doigt puis lever peut relancer un élan « fantôme » ([cas limites](../timeline/glissement.md#cas-limites)) (défaut soupçonné). | Pas « Mois ». | 1. Tirer vite, puis s'immobiliser 2 s sans lever.<br>2. Lever sans bouger. | Noter ce qui se passe : un élan qui repart après la pause confirme le défaut. | — |
| GLIS-06 | P2 | simulateur | Le défilement au bord se déclenche aux extrémités et s'arrête quand le doigt s'en écarte ([pendant le geste](../timeline/glissement.md#pendant-le-geste)). | Pas « Jour ». | 1. Tirer la poignée tout en bas, maintenir 3 s.<br>2. Remonter le doigt de 50 pt sans lever. | Défilement continu vers le futur pendant le maintien ; arrêt et reprise du suivi direct à l'étape 2. | — |
| GLIS-07 | P2 | simulateur | Lâcher au bord peut relancer un élan sur la vitesse d'avant le bord ([cas limites](../timeline/glissement.md#cas-limites)) (défaut soupçonné). | Pas « Mois ». | 1. Tirer vite jusqu'au bord bas, laisser défiler 2 s.<br>2. Lever au bord. | Noter ce qui se passe : un élan au lever confirme le défaut. | — |
| GLIS-08 | P2 | simulateur | La poignée grossit, s'écarte du bord et s'ombre pendant le geste, et reprend sa place au lever ([le doigt se pose](../timeline/glissement.md#le-doigt-se-pose)). | — | 1. Poser le doigt, observer.<br>2. Lever, observer. | Grossissement et décalage à la pose (~0,16 s), retour au lever. | — |
| GLIS-09 | P2 | simulateur | Glissement et geste de scène simultanés se composent sans conflit ([annulation et interruption](../timeline/glissement.md#annulation-et-interruption)). | Une planète sélectionnée. | 1. D'une main tirer la poignée, de l'autre glisser sur la scène. | Le temps défile et la caméra orbite en même temps ; la planète reste centrée. | — |
| GLIS-10 | P3 | simulateur | Une transition déclenchée par un second doigt pendant le glissement crée un conflit visible ([annulation et interruption](../timeline/glissement.md#annulation-et-interruption)) (défaut soupçonné). | Cartouche d'une sonde ouvert, glissement de poignée en cours. | 1. Pendant le glissement, toucher un lien de date du texte de l'autre main. | Noter ce qui se passe (tremblement, alternance de dates). | — |

Non vérifiable à la main :

- La formule exacte de la vitesse mesurée (lissage) et sa décroissance.

## timeline/echelle-et-aujourdhui.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ECHE-01 | P1 | simulateur | Choisir un pas change la fenêtre sans changer la date et replace la poignée à 62 % ([le menu d'échelle](../timeline/echelle-et-aujourdhui.md#le-menu-déchelle)). | Date quelconque notée. | 1. Ouvrir le menu d'échelle.<br>2. Choisir « Année ». | Même date affichée (format « MMM aaaa »), poignée à 62 %, menu refermé, pastille « A ». | — |
| ECHE-02 | P1 | simulateur | « Aujourd'hui » n'apparaît que si l'écart dépasse 30 jours ([le bouton « Aujourd'hui »](../timeline/echelle-et-aujourdhui.md#le-bouton--aujourdhui-)). | Pas « Jour ». | 1. Faire défiler ~20 jours : pas de bouton.<br>2. Continuer au-delà de 30 jours. | Le bouton apparaît au franchissement du seuil, à mi-hauteur du bord droit. | — |
| ECHE-03 | P1 | simulateur | Toucher « Aujourd'hui » ramène la date à maintenant en ~1 s et le bouton disparaît ([le bouton « Aujourd'hui »](../timeline/echelle-et-aujourdhui.md#le-bouton--aujourdhui-)). | Date écartée de plusieurs années. | 1. Toucher le bouton. | Transition ~0,95 s, poignée déposée à 62 %, bouton disparu et non revenu. | — |
| ECHE-04 | P2 | simulateur | Le bouton Explorer referme le menu d'échelle, mais pas l'inverse ([variantes](../timeline/echelle-et-aujourdhui.md#variantes)) (incohérence soupçonnée). | Menu d'échelle ouvert. | 1. Toucher le bouton Explorer : noter.<br>2. Panneau ouvert, ouvrir le menu d'échelle : noter. | 1 : le menu se ferme, le panneau s'ouvre. 2 : les deux restent ouverts, empilés. | — |
| ECHE-05 | P2 | simulateur | Cartouche déplié, le bouton d'échelle est intouchable mais un menu déjà ouvert reste actif ([variantes](../timeline/echelle-et-aujourdhui.md#variantes)) (défaut soupçonné). | Menu d'échelle ouvert, une planète sélectionnée. | 1. Déplier le cartouche.<br>2. Tenter de fermer le menu par son bouton.<br>3. Toucher une ligne du menu. | Noter : bouton inerte, lignes actives — le menu ne se ferme que par le choix d'un pas ou le repli du cartouche. | — |
| ECHE-06 | P2 | simulateur | Re-choisir le pas courant recentre la fenêtre et range la poignée ([cas limites](../timeline/echelle-et-aujourdhui.md#cas-limites)). | Poignée près d'une extrémité (après un glissement). | 1. Ouvrir le menu, retoucher le pas actif. | La poignée revient à 62 %, la date ne change pas. | — |
| ECHE-07 | P3 | simulateur | Le tap sur la scène ne ferme pas le menu ([cas limites](../timeline/echelle-et-aujourdhui.md#cas-limites)). | Menu ouvert. | 1. Toucher une planète, puis le vide. | Le menu reste ouvert dans les deux cas. | — |
| ECHE-08 | P3 | simulateur | L'apparition du bouton « Aujourd'hui » : fondu ou apparition sèche ([questions ouvertes](../timeline/echelle-et-aujourdhui.md#questions-ouvertes-et-vérification)). | Pas « Jour ». | 1. Franchir lentement le seuil des 30 jours en observant le bord droit. | Noter l'effet observé. | — |

Non vérifiable à la main :

- Les valeurs exactes des fenêtres par pas (4,2 / 100 / 3 044 / 36 525 jours) — seuls leurs ordres de grandeur s'observent.
