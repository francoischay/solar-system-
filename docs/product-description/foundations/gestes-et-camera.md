# Gestes et caméra

## Résumé

Ce document possède le modèle d'entrée de la scène : quels gestes existent, qui prend la main sur qui, quelles constantes règlent la sensibilité, les bornes et les amortissements de la caméra. Les documents de geste ([orbite libre](../camera/orbite-libre.md), [geste composé](../camera/geste-compose.md), [toucher un astre](../selection/toucher-un-astre.md)) racontent l'expérience ; celui-ci fixe les nombres et les règles qu'ils partagent.

## Les gestes de la scène

Cinq reconnaisseurs sont posés sur la scène, et seulement sur elle — le dock, le cartouche, la poignée de timeline et le panneau Explorer ont leurs propres gestes SwiftUI, décrits dans leurs documents.

| Geste | Doigts | Effet |
| --- | --- | --- |
| Glissement | 1 | Oriente la caméra (azimut, élévation), avec élan |
| Glissement | 2 | Oriente la caméra, précision réduite à 72 %, sans élan |
| Pincement | 2 | Zoom (distance de caméra), ou ampleur du cadrage sur une sonde |
| Torsion | 2 | Roulis, manipulation directe sans élan |
| Tap | 1 | Sélection d'un astre, ou désélection dans le vide |

## L'arbitrage : qui prend la main sur qui

- **Tous les gestes de scène se reconnaissent simultanément entre eux, sauf le tap.** À deux doigts, on peut orienter, zoomer et rouler dans un même mouvement continu : c'est le *geste composé*. Le tap, lui, ne se combine avec rien : il ne déclenche que si aucun autre geste n'est en cours.
- **Le glissement à un doigt ne s'engage jamais pendant une manipulation à deux doigts.** Si les deux doigts sont déjà posés, un mouvement d'un seul d'entre eux ne compte pas comme glissement à un doigt.
- **Un deuxième doigt posé pendant un glissement à un doigt l'annule immédiatement**, sans élan, et le geste composé continue seul. C'est *prendre la main* (voir le glossaire). L'inverse n'existe pas : lever un doigt du geste composé ne rend pas la main au glissement à un doigt — il faut tout lever et recommencer.

> Note technique : UIKit n'annule pas de lui-même un glissement limité à un doigt quand un deuxième doigt se pose ; il continuerait de suivre le premier doigt et cumulerait sa rotation, puis son élan, avec le geste composé. L'app force l'annulation. C'est pour la même raison que le geste composé n'a jamais d'élan : les vitesses de plusieurs reconnaisseurs ne doivent jamais s'additionner.

## Le rig de caméra

La caméra orbite autour d'une *cible* (voir le glossaire) décrite par quatre nombres : azimut, élévation, roulis, distance.

- **Azimut** : libre, sans borne, sensibilité 0,007 radian par point de glissement (0,005 par point à deux doigts, soit 72 %).
- **Élévation** : bornée à ±(π/2 − 0,025) radians — la caméra s'arrête à 0,025 radian de la verticale et l'image ne bascule jamais. Sensibilité 0,005 radian par point (0,0036 à deux doigts).
- **Roulis** : libre, commandé par la torsion uniquement, remis à zéro au retour à la vue d'ensemble (tap dans le vide). Aucune inertie.
- **Distance** : bornée à [1,4 ; 560] unités de scène. La vue d'ensemble est à 230. Le pincement la règle ; chaque sélection impose sa distance d'arrivée (voir [Scène et objets](scene-et-objets.md)).

## Élan et amortissements

- **Élan du glissement à un doigt** : au lever du doigt, la vitesse du geste devient vitesse de rotation, plafonnée à ±1,8 rad/s en azimut et ±1,35 rad/s en élévation, puis décroît en exp(−5,2·t) — il en reste ~7 % après une demi-seconde. L'élan ne démarre que si aucun autre geste d'orientation n'est actif au moment du lever. Arrivé à la butée d'élévation, la composante verticale de l'élan s'annule.
- **Visées programmées** : quand l'app oriente elle-même la caméra (sélection depuis une liste, séquence de tir), azimut, élévation et roulis rejoignent leur but par un amortissement critique de temps caractéristique 0,48 s — vite au début, doux à l'arrivée, sans dépassement. La visée est déclarée atteinte (et abandonnée) quand l'écart et la vitesse deviennent négligeables.
- **Distance** : amortie vers son but en 0,5 s, en continu — un changement de but en cours de route conserve la vitesse acquise.
- **Cible** : amortie en 0,42 s vers l'astre suivi (0,58 s vers le centre quand il n'y a plus de sélection). Quand l'astre suivi se déplace parce que le temps défile, la caméra reçoit exactement le même déplacement : l'astre reste verrouillé dans le cadre pendant le défilement, l'amortissement ne sert qu'aux changements de cible.

**Le doigt gagne toujours** : commencer n'importe quel geste d'orientation (un ou deux doigts) abandonne la visée d'orientation en cours, là où elle en est. L'animation de distance, elle, n'est pas abandonnée — on peut orbiter pendant que la caméra plonge. Le pincement, en revanche, reprend la main sur la distance dès qu'il commence.

## Le zoom et son exception

Le pincement écarte-pour-approcher classique : la distance de caméra est divisée par le facteur d'écartement, bornée à [1,4 ; 560], mesurée depuis la distance au début du pincement (pas de dérive cumulative).

**Exception** : quand une sonde est sélectionnée, la distance de caméra est calculée automatiquement pour cadrer sa trajectoire parcourue. Le pincement ne règle alors plus la distance mais l'*ampleur* de ce cadrage, entre 0,3× (serré sur la sonde) et 3× (large). Changer de sonde remet l'ampleur à 1.

## Le recadrage vertical du cartouche

Quand le [cartouche](../selection/cartouche.md) se déplie, la scène ne se contente pas d'être recouverte : la caméra vise progressivement *sous* sa cible, d'une demi-hauteur de champ au maximum, pour que l'astre sélectionné remonte au centre de la moitié haute de l'écran. Pendant le drag du cartouche, ce décalage suit le doigt en direct ; au snap, il s'amortit. Il disparaît avec la sélection.

## Variantes

Les variantes du squelette (sélection courante, panneau ouvert, cartouche déplié, échelle de temps) n'ont aucun effet sur l'arbitrage des gestes ni sur les constantes ci-dessus, à deux exceptions près, décrites dans leurs documents : la sélection d'une sonde change ce que règle le pincement, et le cartouche déplié décale la visée.

## Annulation et interruption

Les définitions valent pour tous les documents de geste :

- **Taper le vide** : n'est possible qu'au repos (le tap ne se reconnaît pas pendant un geste). Désélectionne tout, remet le roulis à zéro, renvoie la caméra au centre à distance 230.
- **Un deuxième doigt se pose** : annule le glissement à un doigt sans élan ; le geste composé prend la main.
- **Une transition de date démarre** : ne peut venir que d'un bouton ou d'une liste, donc jamais pendant un geste de scène. Elle ne touche pas à la caméra (sauf si la même action programme aussi une visée, comme la sélection d'un lancement).
- **Le système annule le toucher** (appel, centre de contrôle, geste de bord) : le geste en cours s'arrête là où il en est, sans élan. Rien n'est annulé rétroactivement.
- **L'app passe en arrière-plan** : même effet ; au retour, la caméra est là où le geste l'a laissée.
- **La cible disparaît** : la caméra reste sur la dernière position connue ; ce que devient la sélection appartient à [Scène et objets](scene-et-objets.md).
- **Le réseau manque** : aucun effet, tous les gestes sont locaux.
- **L'appareil pivote** : les gestes en cours continuent dans le nouveau repère ; les bornes et sensibilités sont indépendantes de l'orientation.

## Questions ouvertes et vérification

- Le seuil d'engagement des glissements (~10 pt) et du tap est celui d'UIKit, non redéfini par l'app ; valeurs non mesurées.
- Le plafonnement de l'élan (±1,8 / ±1,35 rad/s) est écrit dans le code ; l'impression subjective (« on ne peut pas lancer la scène à une vitesse folle ») n'a pas été confirmée sur appareil.
- Le comportement du pincement quand la sélection change *pendant* le pincement (possible seulement si une transition de date fait apparaître ou disparaître une sonde) n'est pas couvert par le code de façon explicite ; non observé.
- Des traces de débogage (`print`) subsistent dans les gestes ; sans effet utilisateur.

Vérifié contre le dossier natif au commit `ddd8314`.
