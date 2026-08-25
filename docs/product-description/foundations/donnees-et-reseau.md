# Données et réseau

## Résumé

Ce document possède les trois flux de données distantes de l'app — les éléments orbitaux des satellites (TLE), la liste des prochains lancements, les textures des corps — avec leurs caches, leurs replis embarqués et ce que l'utilisateur voit dans chaque état. Règle générale : **l'app ne montre jamais d'erreur réseau, jamais d'indicateur de chargement bloquant, et fonctionne entièrement hors ligne sur ses replis.** Le seul texte qui change selon l'état du réseau est la note du panneau Satellites.

## Les trois flux

| Flux | Source | Cache disque | Repli embarqué |
| --- | --- | --- | --- |
| TLE satellites | Celestrak (par groupe ou numéro de catalogue) | 12 heures | TLE du 23 août 2026 |
| Prochains lancements | Launch Library (thespacedevs), 10 au plus | 1 heure | 3 lancements illustratifs |
| Textures | CDN jsdelivr (cartes planétaires, Lune, Soleil, anneaux) | Sans expiration | Textures procédurales dessinées localement |

Un cache expiré n'est pas jeté : si le réseau échoue au rafraîchissement, la copie locale périmée est réutilisée telle quelle. L'ordre de préférence est toujours : cache frais, puis réseau, puis cache périmé, puis repli embarqué.

## Les TLE et la fenêtre SGP4

Au lancement de l'app, chaque jeu de satellites (ISS, Hubble, Tiangong, GPS, Starlink) charge ses éléments orbitaux : cache s'il a moins de 12 heures, sinon Celestrak, sinon cache périmé, sinon repli. Starlink est tronqué à 600 satellites, GPS à 40. Pendant le chargement, le panneau Satellites affiche « Chargement des éléments orbitaux… » ; les maquettes n'apparaissent qu'une fois les éléments disponibles — quelques dixièmes de seconde sur les replis, le temps du réseau sinon.

Les positions calculées ne valent que près de l'époque des éléments : c'est la **fenêtre SGP4**, ±45 jours autour de l'époque moyenne des TLE chargés. Tant que la date simulée est dans la fenêtre, le panneau affiche « Propagation SGP4 · TLE du {date} ». Au-delà :

- les positions sont **gelées au bord de la fenêtre** — les satellites cessent de tourner quand on scrubbe plus loin, leurs orbites restent justes mais leur position sur l'orbite n'est plus synchronisée avec la date ;
- les maquettes et nuages sont **estompés** (à un peu moins de moitié) ;
- la note devient « Positions indicatives · loin du TLE du {date} ».

Avec les TLE de repli (époque figée au 23 août 2026), la fenêtre est donc figée elle aussi : hors ligne, l'app montre des satellites exacts fin août 2026 et indicatifs partout ailleurs.

> Note technique : l'année de lancement de chaque satellite est lue dans le désignateur international de son TLE ; c'est elle qui fait qu'un satellite « n'existe pas » avant son lancement (voir [Scène et objets](scene-et-objets.md)), indépendamment de la fenêtre SGP4.

## Les lancements

La liste des prochains tirs vient de Launch Library : les dix prochains, avec nom de mission, lanceur, site, coordonnées réelles du pas de tir, date-heure et statut. Cache une heure ; si l'API ne répond pas et que le cache est vide, trois lancements illustratifs embarqués prennent le relais (« Prochaine mission orbitale » à Cap Canaveral, etc.), avec des dates relatives au lancement de l'app — ils sont plausibles mais fictifs, et rien ne le signale dans la liste elle-même. La mention permanente sous la liste, « Fenêtres indicatives · trajectoire non télémétrique », est le seul garde-fou.

La liste est chargée une fois par lancement de l'app ; elle ne se rafraîchit pas en cours de session. Le compte à rebours, lui, se recalcule toutes les minutes sur l'heure réelle.

## Les textures

Chaque corps texturé démarre avec une texture procédurale dessinée localement — reconnaissable, mais schématique — puis la vraie carte se substitue, silencieusement, dès qu'elle est disponible (cache, puis téléchargement en tâche de fond). Ni indicateur, ni transition : la planète change simplement d'habillage, en général dans les premières secondes. Hors ligne sans cache, les textures procédurales restent pour toute la session. Une fois téléchargée, une carte est en cache pour toujours : les sessions suivantes n'ont plus ce délai.

## Variantes

Sans objet : ce document ne décrit pas une interaction. L'état du réseau n'est pas une variante que l'utilisateur choisit ; ses effets sont décrits ci-dessus et référencés par la ligne « Le réseau manque » de chaque tableau d'interruption.

## Annulation et interruption

Ce que la liste standard signifie pour les données :

- **Taper le vide / un deuxième doigt / une transition de date** : aucun effet sur les flux. Une transition de date peut faire sortir de la fenêtre SGP4, ce qui est un effet du temps, pas du réseau.
- **Le système annule le toucher** : aucun effet.
- **L'app passe en arrière-plan** : les téléchargements en cours continuent ou reprennent selon le système ; aucun état visible ne s'y perd. Au retour d'une longue absence, les caches ont pu expirer — ils ne se rafraîchissent qu'au prochain lancement de l'app, pas au retour au premier plan.
- **La cible disparaît** : sans objet ici.
- **Le réseau manque** : c'est le sujet du document — cache, puis repli, silencieusement.
- **L'appareil pivote** : aucun effet.

## Questions ouvertes et vérification

- « Quelques dixièmes de seconde » pour l'apparition des satellites sur repli est une estimation, pas une mesure.
- Le non-rafraîchissement des lancements et des TLE au retour au premier plan (seulement au lancement de l'app) est lu dans le code ; l'effet pour un utilisateur qui garde l'app ouverte des jours — compte à rebours juste mais liste périmée — vaut peut-être un ticket de triage.
- Les trois lancements de repli ont des dates relatives (« +18 h après le lancement de l'app ») : deux sessions à des heures différentes montrent des heures de tir différentes pour la « même » mission. Défaut probable à trancher (repli assumé vs. incohérence visible).
- Celestrak peut répondre « data has not updated » au lieu de TLE ; le code garde alors la copie locale. Non observé en conditions réelles.
- La troncature de Starlink à 600 membres se fait en octets sur le flux téléchargé ; le dernier TLE du lot peut être coupé et ignoré. Sans effet visible probable, non vérifié.

Vérifié contre le dossier natif au commit `bb3744e`.
