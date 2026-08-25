# Vérification : caméra et sélection

Comment dérouler ce fichier : app lancée sur le simulateur, état par défaut (vue d'ensemble, aucune sélection) entre chaque section sauf mention contraire — un tap dans le vide y ramène. Valeurs de la colonne Appareil : voir [README.md](README.md#appareils-et-conditions).

## camera/orbite-libre.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ORBIT-01 | P1 | simulateur | Le glissement oriente la caméra dans le sens naturel, azimut sans limite ([pendant le geste](../camera/orbite-libre.md#pendant-le-geste)). | Vue d'ensemble. | 1. Glisser à gauche, puis faire trois tours complets. | La scène défile vers la droite du regard ; aucun blocage en azimut. | — |
| ORBIT-02 | P1 | simulateur | Lâcher en mouvement donne un élan qui s'amortit en une à deux secondes ([le doigt se lève](../camera/orbite-libre.md#le-doigt-se-lève)). | Vue d'ensemble. | 1. Glisser vivement et lâcher.<br>2. Chronométrer l'arrêt. | La rotation continue et s'éteint d'elle-même en ~1–2 s. | — |
| ORBIT-03 | P1 | simulateur | Reposer le doigt pendant l'élan l'arrête net ([le cas simple](../camera/orbite-libre.md#le-cas-simple)). | Élan en cours (ORBIT-02). | 1. Poser le doigt sans bouger. | La rotation s'arrête à l'instant du contact et suit ensuite le doigt. | — |
| ORBIT-04 | P2 | simulateur | Avec une sélection, la caméra orbite autour de l'astre, qui reste centré ([le cas simple](../camera/orbite-libre.md#le-cas-simple)). | Mars sélectionnée. | 1. Glisser dans tous les sens. | Mars reste au centre du cadre. | — |
| ORBIT-05 | P2 | simulateur | La butée d'élévation tue la composante verticale de l'élan, l'horizontale survit ([cas limites](../camera/orbite-libre.md#cas-limites)). | Vue d'ensemble. | 1. Glisser en diagonale vers le haut jusqu'à la butée, lâcher vivement en diagonale. | Après la butée, la vue continue de tourner horizontalement seulement. | — |
| ORBIT-06 | P2 | simulateur | Glisser pendant une séquence de tir libère l'angle sans casser la plongée ni l'ascension ([cas limites](../camera/orbite-libre.md#cas-limites)). | Un lancement sélectionné, séquence en cours. | 1. Dès la plongée, glisser à un doigt. | L'angle suit le doigt ; le rapprochement continue ; la fusée monte quand même. | — |
| ORBIT-07 | P3 | simulateur | Le glissement ne change ni la date, ni la sélection, ni la distance ([résumé](../camera/orbite-libre.md#résumé)). | Saturne sélectionnée, date notée. | 1. Glisser longuement dans tous les sens.<br>2. Relire cartouche et poignée. | Titre, date et distance apparente inchangés. | — |

Non vérifiable à la main :

- La valeur exacte du seuil d'engagement système (~10 pt).

## camera/geste-compose.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| COMPO-01 | P1 | simulateur | Orientation et zoom se combinent dans un même mouvement continu ([pendant le geste](../camera/geste-compose.md#pendant-le-geste)). | Vue d'ensemble. | 1. ⌥-glisser en écartant et en déplaçant les deux points à la fois. | La caméra tourne et s'approche en même temps, sans à-coups ni bascule de mode. | — |
| COMPO-02 | P1 | simulateur | Il n'y a pas de geste de torsion : l'horizon reste à plat ([le cas simple](../camera/geste-compose.md#le-cas-simple)). | Vue d'ensemble. | 1. ⌥-glisser circulaire (rotation des deux doigts l'un autour de l'autre). | L'image ne pivote jamais autour de l'axe de visée ; seuls orientation et zoom répondent. | — |
| COMPO-03 | P1 | simulateur | Fin de geste sans élan, quelle que soit la vivacité ([les doigts se lèvent](../camera/geste-compose.md#les-doigts-se-lèvent)). | Vue d'ensemble. | 1. ⌥⇧-glisser vivement, relâcher en plein mouvement. | Arrêt exactement au relâchement. | — |
| COMPO-04 | P1 | appareil | Le doigt restant après un geste à deux doigts ne déclenche pas d'élan (fenêtre 0,5 s) ([les doigts se lèvent](../camera/geste-compose.md#les-doigts-se-lèvent)). | Vue d'ensemble. | 1. Manipuler à deux doigts, lever un seul doigt.<br>2. Continuer à glisser avec l'autre et le lever vivement dans la demi-seconde. | Aucun élan au lever. Noter aussi si le doigt restant oriente encore (question ouverte du document). | — |
| COMPO-05 | P2 | simulateur | Revenir à l'écartement initial rend la distance initiale (pas de dérive) ([pendant le geste](../camera/geste-compose.md#pendant-le-geste)). | Une planète sélectionnée. | 1. Pincer pour approcher, puis revenir exactement à l'écartement de départ sans lever. | La distance apparente revient à celle du début du pincement. | — |
| COMPO-06 | P2 | simulateur | Pincement pur pendant un recadrage : la visée d'orientation se finit, la distance obéit aux doigts ([cas limites](../camera/geste-compose.md#cas-limites)). | Panneau > Sondes. | 1. Sélectionner une sonde.<br>2. Pendant le voyage de caméra, pincer sans glisser. | La rotation programmée continue ; la distance répond au pincement. | — |
| COMPO-07 | P2 | simulateur | Pincer sur une sonde sélectionnée invisible règle une ampleur sans retour visuel ([cas limites](../camera/geste-compose.md#cas-limites)) (défaut soupçonné). | Sonde sélectionnée, puis date tirée hors de sa période. | 1. Pincer largement.<br>2. Ramener la date dans la période. | Noter : rien ne bouge à l'étape 1 ; au retour de la sonde, le cadrage applique l'ampleur réglée « à l'aveugle ». | — |
| COMPO-08 | P3 | simulateur | Un troisième doigt est ignoré ([annulation et interruption](../camera/geste-compose.md#annulation-et-interruption)). | Vue d'ensemble, sur appareil de préférence. | 1. Manipuler à deux doigts, poser un troisième. | Le geste continue sur les deux premiers, sans saut. | — |

## selection/toucher-un-astre.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TOUCH-01 | P1 | simulateur | Toucher une planète la sélectionne : approche caméra sans changement d'angle, cartouche renseigné, lunes affichées ([le doigt se lève](../selection/toucher-un-astre.md#le-doigt-se-lève)). | Vue d'ensemble. | 1. Toucher Saturne. | La caméra s'approche tout droit ; « Saturne — 9,54 UA du Soleil » ; sept lunes visibles. | — |
| TOUCH-02 | P1 | simulateur | Un tap dans le vide désélectionne tout et rend la vue d'ensemble ([levé sans mouvement](../selection/toucher-un-astre.md#levé-sans-mouvement)). | Une lune sélectionnée. | 1. Toucher le fond étoilé. | Désélection, lunes cachées, recul à la vue d'ensemble. | — |
| TOUCH-03 | P1 | simulateur | En cas de chevauchement, la lune gagne sur la planète ([levé sans mouvement](../selection/toucher-un-astre.md#levé-sans-mouvement)). | Jupiter sélectionnée, une lune devant le disque. | 1. Attendre/scruber jusqu'à ce qu'une lune passe devant Jupiter.<br>2. La toucher. | La lune est sélectionnée, pas Jupiter. | — |
| TOUCH-04 | P2 | simulateur | Retoucher l'astre sélectionné ne fait rien ([levé sans mouvement](../selection/toucher-un-astre.md#levé-sans-mouvement)). | Mars sélectionnée, caméra arrivée. | 1. Retoucher Mars. | Aucun mouvement de caméra, aucun changement au cartouche. | — |
| TOUCH-05 | P2 | simulateur | Les constellations ne sont pas touchables ([cas limites](../selection/toucher-un-astre.md#cas-limites)). | Starlink sélectionnée (nuage visible autour de la Terre). | 1. Toucher un point du nuage à l'écart de la Terre. | Rien n'est sélectionné (ou désélection si le tap tombe dans le vide) ; jamais de sélection « Starlink » par tap. | — |
| TOUCH-06 | P2 | simulateur | Un petit corps reste touchable de loin (rayon minimal 22 pt) ([levé sans mouvement](../selection/toucher-un-astre.md#levé-sans-mouvement)). | « Afficher toutes les sondes », vue d'ensemble dézoomée. | 1. Toucher précisément une sonde lointaine (petit octaèdre). | La sonde est sélectionnée malgré sa taille minuscule. | — |
| TOUCH-07 | P2 | simulateur | Sélectionner une sonde par tap ferme le panneau Explorer ; une planète le laisse ouvert ([note technique](../selection/toucher-un-astre.md#le-doigt-se-lève)). | Panneau ouvert (Sondes), « Afficher toutes les sondes ». | 1. Toucher une sonde dans la scène : le panneau se ferme.<br>2. Rouvrir, toucher une planète. | Fermé à l'étape 1 ; resté ouvert à l'étape 2. | — |
| TOUCH-08 | P3 | simulateur | Un tap dans le vide sans sélection ne fait rien du tout ([cas limites](../selection/toucher-un-astre.md#cas-limites)). | Vue d'ensemble propre. | 1. Taper le fond étoilé plusieurs fois. | Aucun mouvement, aucun changement. | — |

Non vérifiable à la main :

- La formule du rayon de saisie des sondes aux distances extrêmes (seul TOUCH-06 en teste la conséquence).

## selection/cartouche.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CART-01 | P1 | simulateur | Tirer la feuille au-delà de ~42 % l'ouvre ; en deçà, elle se replie ; l'élan compte ([le doigt se lève](../selection/cartouche.md#le-doigt-se-lève)). | Neptune sélectionnée. | 1. Tirer lentement à mi-course moins un doigt, lâcher : repli.<br>2. Tirer d'un petit geste vif, lâcher. | 1 : elle redescend. 2 : elle s'ouvre en grand malgré la faible distance. | — |
| CART-02 | P1 | simulateur | L'ouverture recadre la scène : l'astre remonte dans la moitié haute ([pendant le geste](../selection/cartouche.md#pendant-le-geste)). | Neptune sélectionnée, centrée. | 1. Tirer la feuille en observant Neptune. | Neptune glisse vers le haut du cadre, proportionnellement à l'ouverture ; redescend à la fermeture. | — |
| CART-03 | P1 | simulateur | Un lien de date du texte lance une transition vers ce jour ([levé sans mouvement](../selection/cartouche.md#levé-sans-mouvement)). | Uranus sélectionnée, feuille ouverte. | 1. Toucher « janvier 1986 » dans le texte. | La date voyage en ~1 s vers janvier 1986 ; la feuille reste ouverte ; la poignée finit à 62 %. | — |
| CART-04 | P1 | simulateur | Le tap sur l'en-tête d'une sonde bascule la date entre début et fin de mission ([levé sans mouvement](../selection/cartouche.md#levé-sans-mouvement)) (découvrabilité en question). | Voyager 1 sélectionnée, feuille repliée. | 1. Taper une fois sur le titre du cartouche.<br>2. Retaper. | 1 : la date part vers 1977, poignée en haut de course. 2 : vers la fin de mission, poignée en bas. | — |
| CART-05 | P2 | simulateur | Changer de sélection replie la feuille ([variantes](../selection/cartouche.md#variantes)). | Feuille ouverte sur Jupiter. | 1. Toucher Mars dans la scène. | La feuille se replie et affiche Mars. | — |
| CART-06 | P2 | simulateur | Les boutons du dock s'estompent et deviennent intouchables dès que la feuille s'ouvre ([pendant le geste](../selection/cartouche.md#pendant-le-geste)). | Feuille ouverte. | 1. Tenter de toucher le bouton Explorer et le bouton d'échelle. | Aucun ne répond ; ils sont estompés. | — |
| CART-07 | P2 | simulateur | Le chevron ouvre et ferme entièrement, et pivote de 180° ([levé sans mouvement](../selection/cartouche.md#levé-sans-mouvement)). | Planète sélectionnée. | 1. Taper le chevron, observer.<br>2. Retaper. | Ouverture complète en ressort, chevron retourné ; puis fermeture. | — |
| CART-08 | P3 | simulateur | Sans sélection, la feuille n'est pas dépliable ([cas limites](../selection/cartouche.md#cas-limites)). | Vue d'ensemble. | 1. Tenter de tirer le cartouche « Système solaire ». | Rien : ni pastille, ni chevron, ni tirage. | — |
| CART-09 | P3 | simulateur | Une année seule dans un texte est un lien vers le 1ᵉʳ juillet de l'année ([levé sans mouvement](../selection/cartouche.md#levé-sans-mouvement)). | Sonde au texte mentionnant une année seule, feuille ouverte. | 1. Toucher l'année.<br>2. Lire la date d'arrivée. | Autour du 1ᵉʳ juillet de cette année. | — |

Non vérifiable à la main :

- La cohabitation exacte tap/tirage sur l'en-tête (seuil de 2 pt) — seule la conséquence (CART-04 fonctionne sans ouvrir la feuille) se vérifie.

## explorer/lancements.md

| ID | P | Appareil | Affirmation | Mise en place | Étapes | Attendu | Résultat |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TIR-01 | P1 | simulateur | La sélection d'un lancement déroule la séquence : fermeture du panneau, voyage de date, recul, plongée, ascension ([le cas simple](../explorer/lancements.md#le-cas-simple)). | Onglet Lancements. | 1. Toucher un lancement.<br>2. Observer sans toucher pendant ~6 s. | Panneau fermé ; date en voyage ; la caméra recule puis plonge sur le pas de tir ; un trait lumineux s'élève en ~3,4 s et reste affiché. | — |
| TIR-02 | P1 | simulateur | Le zoom est inopérant tant qu'un lancement est sélectionné ([cas limites](../explorer/lancements.md#cas-limites)) (défaut soupçonné). | Tir affiché (TIR-01 terminé). | 1. Pincer pour dézoomer, plusieurs fois. | Noter ce qui se passe : la caméra devrait rester collée (distance imposée). | — |
| TIR-03 | P1 | simulateur | Toucher un astre pendant le tir change le cartouche mais pas le cadrage ([cas limites](../explorer/lancements.md#cas-limites)) (défaut soupçonné). | Tir affiché. | 1. Dézoomer impossible (TIR-02) : glisser pour trouver une planète visible, la toucher — sinon toucher la Terre. | Noter : le cartouche change, la caméra reste sur la trajectoire. | — |
| TIR-04 | P1 | simulateur | Un tap dans le vide efface tout : trajectoire, sélection, vue d'ensemble ([le doigt se lève](../explorer/lancements.md#le-doigt-se-lève)). | Tir affiché. | 1. Taper le fond étoilé. | Trajectoire éteinte, cartouche « Système solaire », vue d'ensemble. | — |
| TIR-05 | P2 | simulateur | Changer d'onglet ou fermer le panneau efface le tir mais garde la Terre sélectionnée ([le doigt se lève](../explorer/lancements.md#le-doigt-se-lève)). | Tir affiché. | 1. Rouvrir le panneau.<br>2. Toucher l'onglet Sondes. | La trajectoire disparaît ; le cartouche affiche « Terre ». | — |
| TIR-06 | P2 | simulateur | La visée anticipe l'orientation du globe à la date du tir ([levé sans mouvement](../explorer/lancements.md#levé-sans-mouvement)). | Onglet Lancements, date écartée de la date du tir de plusieurs jours. | 1. Sélectionner un lancement.<br>2. Attendre la fin du voyage de date. | À l'arrivée, le pas de tir fait face à la caméra (pas un point aléatoire du globe). | — |
| TIR-07 | P2 | date réelle | Le compte à rebours : « J−n · h h » ou « T−h h », statut affiché s'il n'est pas « Go », « En cours » passé l'heure ([interactions avec les autres systèmes](../explorer/lancements.md#interactions-avec-les-autres-systèmes)). | Onglet Lancements, réseau actif. | 1. Lire les comptes à rebours de la liste. | Formats conformes ; un tir à statut TBD/Hold affiche ce statut à la place. | — |
| TIR-08 | P2 | simulateur | Retoucher le même lancement rejoue la séquence entière ([le doigt se lève](../explorer/lancements.md#le-doigt-se-lève)). | Tir affiché. | 1. Rouvrir le panneau, onglet Lancements (le tir s'efface).<br>2. Retoucher la même ligne. | La séquence se rejoue : recul, voyage (court), plongée, ascension. | — |
| TIR-09 | P3 | réseau coupé | Hors ligne, la séquence marche à l'identique sur les trois tirs de repli ([annulation et interruption](../explorer/lancements.md#annulation-et-interruption)). | Hors ligne, app fraîche. | 1. Sélectionner « Prochaine mission orbitale ». | Séquence complète sur Cap Canaveral. | — |

Non vérifiable à la main :

- L'enchaînement interne des horloges (0,95 s de voyage, mise à feu à 1,6 s) — seul l'ordre perçu se vérifie.
