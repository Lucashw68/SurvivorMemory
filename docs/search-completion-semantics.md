# Sémantique de complétion de fouille

## Stratégies étudiées

1. Scanner tous les containers du `BuildingDef` ou de `IsoBuilding`. Rejeté:
   révèle les pièces et meubles jamais observés, dépend du streaming et coûte
   davantage.
2. Considérer le premier container ouvert comme maison fouillée. Rejeté:
   simple mais arbitraire et trompeur.
3. Compter les containers de chaque room entrée. Rejeté pour le MVP: entrer sur
   une case d'une grande pièce ne signifie pas avoir vu chaque recoin.
4. Utiliser uniquement ce que le loot UI B42 a rendu observable. Retenu: la
   connaissance coïncide avec l'information effectivement présentée au joueur.

## Règle MVP

- **VISITED**: le personnage est entré dans le bâtiment et aucun container
  pertinent n'a été inspecté.
- **PARTIALLY_SEARCHED**: au moins un container connu a été inspecté, mais au
  moins un autre container connu ne l'a pas été.
- **SEARCHED**: il existe au moins un container connu et chacun des containers
  actuellement connus a été inspecté.

« Connu » ne signifie pas « présent quelque part dans le bâtiment ». Cela
signifie que B42 l'a présenté comme container de loot accessible au personnage.
« Inspecté » signifie que son contenu est devenu le container sélectionné dans
le panneau de loot.

SEARCHED est donc une conclusion de mémoire, pas une vérité omnisciente. Si le
personnage découvre plus tard un nouveau placard, le statut redevient
PARTIALLY_SEARCHED jusqu'à inspection. Un container détruit ou déplacé n'efface
pas rétroactivement le souvenir; cette obsolescence est conforme à la vision du
mod.

Un bâtiment sans container reste VISITED. Le MVP ne prétend pas qu'il est
« fouillé » sur la seule base de ses rooms. L'UI utilisateur affiche seulement
le nombre inspecté; le nombre connu reste en debug pour ne jamais être pris
pour le total du bâtiment.

Le smoke B42 réel confirme cette règle: après deux inspections, d'autres
containers présentés par l'UI de loot restaient connus et le statut est resté
`PARTIALLY_SEARCHED`. La règle n'a pas été assouplie pour produire un joli
`SEARCHED`.
