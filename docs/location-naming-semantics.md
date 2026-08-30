# Sémantique des noms de lieux

Le jeu ne fournit pas un nom public, stable et humain pour chaque BuildingDef.
Survivor Memory n'affiche donc pas des identifiants techniques de zone comme
s'il s'agissait d'une enseigne connue.

Le type mémorisé est déduit au moment où le personnage entre:

- classification évidente du bâtiment observé (`isResidential`, `isShop`);
- nom interne de la room réellement traversée, avec une liste fermée de types:
  maison, garage, bureau, entrepôt, usine, épicerie, restaurant, bar, bâtiment
  médical, police, pompiers, école, église, banque ou hôtel.

Une observation plus spécifique peut améliorer « Maison » en « Poste de
police », mais une room générique ne dégrade jamais un type spécifique. Les
rooms non traversées ne sont pas consultées. Sans preuve suffisante, l'UI garde
simplement « Bâtiment ».
