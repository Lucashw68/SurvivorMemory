# Things Worth Remembering — audit B42

Audit effectué le 31 août 2026 sur Project Zomboid `42.20.4` installé
localement. Les constats vérifiés sont séparés des catégories encore ambiguës.

## Représentations vérifiées

### Generator

Un générateur posé est une instance de `zombie.iso.objects.IsoGenerator`.
`getSquare()` fournit son lieu chargé. L'observation automatique exige en plus
que cette case soit actuellement `isCanSee(playerNum)`. Le smoke B42 crée un
vrai `IsoGenerator`, le fait entrer dans le champ de vision, puis vérifie sa
mémoire et sa persistance après reload.

### Gas Pump

Les sprites vanilla des pompes Fossoil et Gas2Go possèdent la propriété
`fuelAmount = 20000` dans `media/newtiledefinitions.tiles.txt`. La classe
`IsoObject` expose aussi `getPipedFuelAmount()`, utilisé par les actions vanilla
de ravitaillement. Survivor Memory classe une pompe par la présence de la
propriété de sprite `fuelAmount`, sans lire ni mémoriser sa quantité actuelle.

Cette classification est validée statiquement et déterministiquement. Un
fixture réel de pompe n'a pas encore été ajouté au smoke.

### Antique Oven / Wood Stove

Les antiques ovens vanilla ont `container = woodstove` et `IsoType =
IsoFireplace`. Le type de conteneur `woodstove` est donc le signal stable retenu.
L'observation arrive quand l'objet devient réellement visible ou quand son
conteneur est effectivement présenté par l'interface de loot.

### Well

Les tile definitions contiennent plusieurs objets et sources naturelles avec
des volumes d'eau très élevés ou illimités, sans propriété sémantique unique
permettant de distinguer sûrement un puits. Une heuristique basée uniquement sur
`waterAmount` confondrait puits, plans d'eau et autres sources.

Le puits est donc **différé** tant qu'un objet ou sprite B42 précis n'a pas été
inspecté en jeu. Il n'est pas deviné dans la V1.

## Événements d'observation

- `LoadGridsquare` enregistre uniquement les candidats remarquables des cases
  chargées dans un cache client transitoire. `OnObjectAdded` y ajoute les objets
  posés ou déplacés après le chargement; `OnObjectAboutToBeRemoved` les retire.
- Après un changement de case, de direction ou de candidats, une passe différée
  et bornée teste uniquement ce petit cache. L'objet doit à la fois satisfaire
  `isCanSee(playerNum)` et avoir son centre projeté dans le viewport du joueur ;
  une case visible mais située hors écran ne suffit pas.
- `OnSeeNewRoom` programme la même vérification lorsqu'une nouvelle ligne de vue
  apparaît sans déplacement du personnage.
- Seule une transition non-visible → visible crée ou actualise un souvenir.
- Les hooks de loot déjà présents signalent le parent d'un conteneur réellement
  présenté; ils permettent aussi de reconnaître un `woodstove` légitimement vu.
- Le menu contextuel ne déclenche aucune observation et ne dépend d'aucun code
  de Things Worth Remembering.
- Aucun bâtiment, rayon spatial ou monde global n'est parcouru.

Ces signaux prouvent que le personnage a eu l'objet sous les yeux. `isCouldSee`
n'est volontairement pas suffisant pour l'observation automatique, et
`isCanSee` seul ne suffit plus lorsqu'une case se trouve hors du viewport. Ces
signaux ne prouvent pas que l'objet existe encore après son départ.

## Agrégation et persistance

Le format v4 conserve une table personnelle `importantMemories` :

- une entrée par catégorie et bâtiment;
- une entrée par catégorie et zone extérieure déterministe de 10×10 cases;
- catégorie, coordonnées représentatives et date in-game de dernière
  observation;
- aucun carburant, contenu, état distant ou inventaire.

Une réobservation actualise « last seen ». Plusieurs objets identiques du même
lieu restent agrégés sans quantité technique trompeuse.

## Absence et oubli

La suppression automatique n'est pas activée dans cette première V1. Avec une
observation agrégée, l'absence d'un objet sur une case ne prouve pas l'absence
de tous les objets semblables du lieu. Conformément à « en cas de doute, ne pas
oublier », le souvenir reste possiblement obsolète jusqu'à une future règle
d'absence légitime validée en jeu.
