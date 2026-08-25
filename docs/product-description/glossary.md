# Glossaire

Le vocabulaire employé dans ces documents. Quand un document utilise un de ces mots, il veut dire exactement ceci.

## La scène

**La scène.** La vue 3D qui occupe tout l'écran : le Soleil au centre, les huit planètes sur leurs orbites, et selon la sélection, des lunes, des sondes, des satellites et une trajectoire de lancement. Tout ce qui n'est pas la scène (dock, cartouche, timeline, panneau Explorer, étiquettes) est posé par-dessus.

**La cible.** Le point de l'espace que la caméra regarde et autour duquel elle orbite. Sans sélection, c'est le Soleil (le centre). Avec une sélection, c'est l'astre sélectionné, qui reste verrouillé dans le cadre même quand le temps défile. La caméra rejoint une nouvelle cible par un mouvement amorti, jamais par un saut.

**La distance de caméra.** L'éloignement de la caméra à sa cible, entre 1,4 et 560 unités de scène. La vue d'ensemble est à 230. Chaque type de sélection impose sa distance d'arrivée : 42 pour une planète, 14 pour une lune, 34 pour une sonde (puis cadrée sur sa trajectoire), 9 pour la Terre vue de l'onglet Satellites, 12 pour un lancement.

**L'échelle compressée.** Les distances de la scène ne sont pas proportionnelles aux distances réelles : elles sont compressées logarithmiquement, pour que Mercure et Neptune tiennent dans le même cadre. La *direction* de chaque astre est exacte ; sa distance apparente ne l'est pas. Même principe autour de la Terre : surface < orbite basse < orbite moyenne < Lune, dans cet ordre, mais pas à l'échelle.

## Les objets

**Astre.** Terme générique pour tout ce qui est sélectionnable dans la scène : planète, lune, sonde ou satellite. Un lancement n'est pas un astre : le sélectionner sélectionne la Terre.

**Planète.** Un des huit corps de Mercure à Neptune, toujours visibles, chacun sur son ellipse képlérienne inclinée. La Terre porte en plus le globe daté (temps sidéral, inclinaison de 23,44°), le point de géolocalisation et les trajectoires de lancement.

**Lune.** Un des 22 satellites naturels du jeu de données, attaché à sa planète. Les lunes d'une planète n'apparaissent que quand cette planète ou l'une de ses lunes est sélectionnée.

**Sonde.** Une des 26 missions spatiales (Voyager 1, JUICE, Juno…), représentée par un octaèdre lumineux à taille d'écran constante. Une sonde a une *période de validité* (par exemple 1977–2030) ; hors de cette période, elle n'existe pas dans la scène.

**Satellite.** Un engin en orbite terrestre suivi par éléments TLE : trois maquettes individuelles (ISS, Hubble, Tiangong) et deux *constellations* (GPS, Starlink) affichées en nuage de points, sans maquette. Un satellite n'apparaît jamais avant son année de lancement, lue dans son TLE.

**Lancement.** Une entrée de la liste des prochains tirs (API Launch Library, dix au plus, ou trois lancements de repli embarqués). Un lancement a un pas de tir réel (latitude/longitude), une date, un statut et un compte à rebours.

**Trace.** La traînée lumineuse laissée par un astre quand le temps défile vite : un arc de sa trajectoire récente, qui s'estompe quand le temps ralentit. La sonde sélectionnée a une trace permanente : la portion de trajectoire déjà parcourue (limitée à sa dernière révolution si elle est en orbite).

## Sélection et état

**Sélection.** L'astre courant, ou rien. Il n'y a qu'une sélection à la fois. Sélectionner remplace ; taper le vide désélectionne tout (astre et lancement) et rend la vue d'ensemble. La sélection pilote le titre du cartouche, la distance de caméra, la visibilité des lunes, de la trace et de l'étiquette.

**Lancement sélectionné.** État distinct de la sélection d'astre : le lancement courant dans l'onglet Lancements. Sélectionner un lancement sélectionne aussi la Terre (comme astre) et déclenche la *séquence de tir*. Changer d'onglet ou fermer le panneau Explorer désélectionne le lancement mais laisse la Terre sélectionnée.

**Vue d'ensemble.** L'état sans sélection : caméra sur le Soleil à distance 230, cartouche titré « Système solaire — Explorer les orbites », pas de lunes ni de sondes visibles (sauf bascules « afficher »).

**Séquence de tir.** L'animation jouée à la sélection d'un lancement : recul de la caméra, transition de date vers la date du tir, plongée sur le pas de tir, puis ascension du tracé lumineux en 3,4 secondes. La trajectoire reste ensuite affichée tant que le lancement est sélectionné.

## L'interface

**Le dock.** La barre en bas de l'écran : bouton Explorer à gauche, cartouche au centre, bouton d'échelle à droite. Quand le cartouche se déplie, les deux boutons s'estompent et deviennent intouchables.

**Le cartouche.** La feuille dépliable du dock. Repliée (58 pt), elle affiche le titre et le sous-titre de la sélection. Dépliée (mi-hauteur d'écran), elle ajoute le texte explicatif, avec ses *liens de date*. On la déplie au chevron, à la poignée, ou en la tirant ; le contenu 3D se recadre en même temps vers la moitié haute de l'écran.

**Lien de date.** Dans le texte du cartouche, toute date reconnue (« 14 janvier 2005 », « janvier 1986 », « 1977 ») est un lien : le toucher lance une transition de date vers ce jour.

**Le panneau Explorer.** Le panneau à trois onglets (Sondes, Satellites, Lancements) ouvert par le bouton de gauche du dock. Un seul panneau, un seul onglet actif. Sélectionner une sonde ou un satellite le ferme ; sélectionner un lancement le laisse ouvert.

**La poignée.** La pastille blanche datée, sur le bord droit de l'écran, qui commande la timeline. Sa position verticale représente la date courante dans la fenêtre de temps visible. Au repos après un recadrage, elle se place à 62 % de la hauteur.

**Le bouton « Aujourd'hui ».** Le bouton flottant à droite qui ramène la date à maintenant. Il n'apparaît que si la date simulée s'écarte de plus de 30 jours d'aujourd'hui, que la poignée est à plus de 9 points de pourcentage du centre, et qu'aucune transition de date n'est en cours.

**Le menu d'échelle.** Le menu ouvert par le bouton de droite du dock : Heure, Jour, Mois, Année. Il fixe le *pas* de la timeline : la fenêtre de temps que représente la hauteur de la course de la poignée (4,2 jours, 100 jours, 3 044 jours, 36 525 jours).

**Étiquette.** Le badge nommé qui suit à l'écran la sonde ou le satellite individuel sélectionné. Les planètes n'ont pas d'étiquette.

## Le temps

**La date simulée.** La date et l'heure que la scène représente, distincte de l'heure réelle. Tout en dépend : positions des planètes, lunes, sondes, satellites, rotation du globe, textes du cartouche. Elle est affichée dans la poignée (format selon le pas : heure, jour ou mois).

**Le pas.** L'échelle de temps choisie au menu d'échelle. Il détermine la fenêtre de la timeline, la vitesse maximale d'élan, et le format de la date affichée.

**Transition de date.** Le déplacement animé de la date simulée vers une date cible, en 0,95 seconde, avec accélération et décélération. Déclenchée par la sélection d'une sonde hors période, d'un lancement, d'un lien de date, du bouton « Aujourd'hui », ou de la bascule début/fin d'une sonde. Toucher la poignée pendant la transition l'arrête net.

**L'élan.** L'inertie de la timeline : lâchée en mouvement, la date continue de défiler en décélérant. L'élan est plafonné proportionnellement au pas choisi.

**Le défilement au bord.** Quand la poignée est tirée tout en haut ou tout en bas de sa course (2,5 % du bord), la fenêtre de temps se met à défiler continûment dans cette direction jusqu'à ce que le doigt s'écarte du bord ou se lève.

**Fenêtre SGP4.** Les positions des satellites ne sont fiables que dans une fenêtre de ±45 jours autour de l'époque de leurs éléments TLE. Au-delà, la propagation est gelée au bord de la fenêtre : orbites justes, positions non synchronisées, maquettes estompées, et le panneau Satellites affiche « Positions indicatives ».

## Les gestes

**Geste à un doigt.** Le glissement à un doigt sur la scène : il fait orbiter la caméra autour de la cible (azimut et élévation), avec élan au lever du doigt.

**Geste composé.** La manipulation à deux doigts : orientation (glissement, précision réduite à 72 %), zoom (pincement) et roulis (torsion), disponibles simultanément dans un même mouvement continu. Le geste composé s'arrête avec les doigts : il n'a jamais d'élan.

**Roulis.** La rotation de l'image autour de l'axe de visée, commandée par la torsion à deux doigts. Manipulation directe, sans inertie ; remis à zéro au retour à la vue d'ensemble.

**Zoom.** Le pincement. Sur une sonde sélectionnée, il ne change pas la distance de caméra mais l'ampleur du cadrage de sa trajectoire (de 0,3× à 3×) ; partout ailleurs, il change la distance de caméra (1,4 à 560).

**Rayon de saisie.** La zone tactile d'un astre, plus large que son dessin : au moins 22 points d'écran, davantage pour les gros corps. En cas de chevauchement, la priorité est : lune, puis sonde ou satellite, puis planète ; à priorité égale, le plus proche du doigt.

## Événements qui terminent ou interrompent un geste

**Terminer.** Le doigt (ou les doigts) se lève : le geste s'achève normalement. Pour le geste à un doigt, l'élan démarre ; pour le geste composé et la torsion, tout s'arrête net ; pour la poignée, l'élan de timeline démarre.

**Interrompre.** Le système retire le toucher à l'app (appel entrant, centre de contrôle, geste système de bord d'écran) : le geste s'arrête là où il en est, sans élan. Rien n'est annulé rétroactivement — la caméra ou la date restent où le geste les a laissées.

**Prendre la main.** Un deuxième doigt se pose pendant un geste à un doigt : le geste à un doigt est annulé immédiatement (sans élan) et le geste composé continue seul. L'inverse n'existe pas : lever un doigt d'un geste composé ne rend pas la main au geste à un doigt en cours.

**Recadrer.** Une visée de caméra programmée (sélection depuis une liste, séquence de tir) : azimut et élévation rejoignent une valeur calculée par amortissement. Commencer n'importe quel geste d'orientation abandonne la visée en cours — le doigt gagne toujours.

## Réseau et replis

**Repli.** La donnée embarquée utilisée quand le réseau ne répond pas : textures procédurales (au lieu des cartes téléchargées), TLE du 23 août 2026 (au lieu de Celestrak), trois lancements illustratifs (au lieu de Launch Library). L'app est utilisable entièrement hors ligne sur ses replis ; rien ne signale le repli à l'utilisateur, sauf la note du panneau Satellites.

**Cache.** Les données téléchargées sont conservées sur disque : cartes de textures sans expiration, TLE 12 heures, lancements 1 heure. Une donnée en cache expirée est quand même utilisée si le réseau échoue.
