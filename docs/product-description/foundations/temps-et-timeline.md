# Temps et timeline

## Résumé

Ce document possède le temps simulé : comment la date est représentée, ce qui la fait bouger, à quelle vitesse, et ce qui l'affiche. Les interactions elles-mêmes (glisser la poignée, choisir un pas, revenir à aujourd'hui) sont racontées dans [timeline/glissement.md](../timeline/glissement.md) et [timeline/echelle-et-aujourdhui.md](../timeline/echelle-et-aujourdhui.md) ; les nombres et les règles sont ici.

## La date simulée

Toute la scène représente un instant unique : la *date simulée*. Les positions des planètes, des lunes, des sondes et des satellites, la rotation du globe terrestre, la visibilité des engins, les textes contextuels — tout en découle. L'app démarre à maintenant, et la date reste continue : elle ne saute jamais, elle glisse (au doigt) ou s'anime (transition).

> Note technique : la date est comptée en jours décimaux depuis J2000 (le 1ᵉʳ janvier 2000 à 12:00 UTC). Toutes les conversions calendaire passent par UTC ; l'affichage est en français.

Ce qui peut faire bouger la date, et rien d'autre :

1. le glissement de la poignée (suivi direct du doigt) ;
2. l'élan qui suit ce glissement ;
3. le défilement au bord, pendant le glissement ;
4. une transition de date (bouton « Aujourd'hui », lien de date du cartouche, sélection d'une sonde hors période, bascule début/fin d'une sonde, sélection d'un lancement).

Le temps ne s'écoule jamais tout seul : sans action de l'utilisateur, la scène est figée à la date courante (l'heure réelle qui passe ne la déplace pas).

## La fenêtre, la poignée et le pas

La timeline est verticale, sur le bord droit de l'écran. Elle représente une *fenêtre* de temps : un intervalle centré sur une date, dont la hauteur de course de la poignée est l'étendue. La position de la poignée dans sa course est la position de la date courante dans la fenêtre — en haut, le passé de la fenêtre ; en bas, son futur.

Le *pas* choisi au menu d'échelle fixe l'étendue de la fenêtre :

| Pas | Étendue de la fenêtre |
| --- | --- |
| Heure | 4,2 jours |
| Jour | 100 jours |
| Mois | 3 044 jours (~8,3 ans) |
| Année | 36 525 jours (100 ans) |

Le pas par défaut au lancement est **Jour**.

Deux positions de poignée sont notables :

- **62 %** : la position de repos. Toute transition de date y dépose la poignée (la fenêtre est recalculée autour de la date cible pour ça). Changer de pas l'y replace aussi, sans changer la date.
- **le centre (50 %)** : la référence du bouton « Aujourd'hui », qui ne s'affiche que si la poignée en est éloignée de plus de 9 points de pourcentage.

## Les vitesses

- **Glissement** : suivi direct — la date affichée est exactement celle que la position du doigt désigne dans la fenêtre. Déplacer la poignée de toute sa course traverse toute la fenêtre.
- **Élan** : au lever du doigt, la vitesse de glissement devient vitesse de défilement, plafonnée à un quart de la fenêtre par seconde (pas/4000 en jours par milliseconde), puis décroît en exp(−0,0045·ms) — moitié moins vite toutes les ~150 ms. Un élan trop faible (moins de 0,003 jour/ms) est ignoré : la date s'arrête net. Pendant l'élan, la fenêtre défile avec la date : la poignée ne bouge pas, c'est le temps qui coule dessous.
- **Défilement au bord** : quand le doigt tire la poignée sous 2,5 % d'une extrémité de sa course, la fenêtre défile continûment dans cette direction, d'un demi-pour-cent de fenêtre par pas de 45 ms, tant que le doigt reste au bord. L'élan est inhibé au bord.
- **Transition de date** : 0,95 seconde, accélération puis décélération (cubique entrée-sortie), quelle que soit la distance à parcourir — aller à demain ou à 1977 prend le même temps. La fenêtre, la poignée et la date voyagent ensemble. Toucher la poignée pendant la transition l'arrête net à la date atteinte.

Une transition de date annule l'élan et le défilement au bord ; un glissement annule la transition ; les trois ne se cumulent jamais.

## L'affichage de la date

La poignée affiche la date courante, formatée selon le pas :

| Pas | Format | Exemple |
| --- | --- | --- |
| Heure | jour, mois, heure:minute | « 25 août 14:30 » |
| Jour, Mois | jour, mois, année | « 25 août 2026 » |
| Année | mois, année | « août 2026 » |

Pendant qu'on la tire, la poignée grossit légèrement, s'écarte du bord vers la gauche et son ombre s'accentue ; elle reprend sa place au lever du doigt.

## Les traces de défilement

Quand le temps défile vite (glissement ample, élan, transition), chaque planète — et les lunes visibles — laisse une *trace* : un arc de sa trajectoire récente, orienté dans le sens du défilement, d'autant plus long et opaque que le temps va vite. À l'arrêt, les traces s'estompent en une demi-seconde environ.

> Note technique : l'intensité des traces suit une « énergie » qui monte avec la vitesse de défilement et décroît en exp(−2,2·t) ; la longueur d'arc est plafonnée à 9 % de la période orbitale de chaque planète. La sonde sélectionnée a une trace d'une autre nature — sa trajectoire parcourue — décrite dans [explorer/sondes.md](../explorer/sondes.md).

## Ce qui dépend de la date, au-delà des positions

- **Visibilité des sondes** : une sonde n'existe que pendant sa période de validité — voir [Scène et objets](scene-et-objets.md).
- **Visibilité des satellites** : un satellite n'apparaît jamais avant son année de lancement ; hors de la fenêtre SGP4 (±45 jours autour de l'époque des TLE), les positions sont gelées au bord de la fenêtre et les maquettes estompées — voir [Données et réseau](donnees-et-reseau.md).
- **Le bouton « Aujourd'hui »** : visible seulement si la date s'écarte de plus de 30 jours d'aujourd'hui *et* que la poignée est à plus de 9 points de pourcentage du centre *et* qu'aucune transition n'est en cours.
- **Le compte à rebours des lancements** : calculé sur l'heure réelle, pas sur la date simulée — voir [explorer/lancements.md](../explorer/lancements.md).

## Annulation et interruption

Ce que chaque événement de la liste standard fait au temps :

- **Taper le vide** : ne touche pas à la date. La désélection n'a aucun effet temporel.
- **Un deuxième doigt se pose** : les gestes de scène ne touchent pas au temps ; un deuxième doigt sur la *poignée* est ignoré (le glissement de poignée est à un doigt).
- **Une transition de date démarre** : annule l'élan et le défilement au bord, prend la main sur la date.
- **Le système annule le toucher** : le glissement de poignée s'arrête là où il en est ; l'élan éventuel démarre selon la dernière vitesse connue.
- **L'app passe en arrière-plan** : la date simulée est conservée telle quelle ; une transition ou un élan en cours se retrouvent, au retour, terminés ou poursuivis selon le temps réel écoulé (les animations courent sur l'horloge réelle).
- **La cible disparaît** : sans effet sur le temps — c'est le temps qui fait disparaître des cibles, jamais l'inverse.
- **Le réseau manque** : aucun effet ; le temps est entièrement local.
- **L'appareil pivote** : la course de la poignée change de longueur avec l'écran ; la date et sa position relative sont conservées.

## Questions ouvertes et vérification

- Le comportement exact d'une transition ou d'un élan interrompu par un passage en arrière-plan (poursuite sur l'horloge réelle) est déduit du code, pas observé.
- La durée ressentie de l'estompage des traces (« une demi-seconde environ ») est calculée, pas chronométrée.
- Au pas Heure (fenêtre de 4,2 jours), le format n'affiche pas l'année : à cheval sur un changement d'année, la date affichée peut être ambiguë. À vérifier à la main ; possible choix assumé.
- Le défilement au bord n'a pas de butée : on peut défiler indéfiniment vers le passé ou le futur, y compris vers des dates où les éphémérides n'ont plus de sens physique (les orbites restent calculées). Comportement assumé par le code, à confirmer comme choix produit.

Vérifié contre le dossier natif au commit `bb3744e`.
