# World Map — overlay MVP+1

Implémenté et validé en jeu sur B42.20.4.

Les annotations et symboles persistants vanilla restent rejetés: ils
pollueraient les données du joueur et `map_symbols.bin`. Survivor Memory
enveloppe seulement le rendu de `ISWorldMap` et projette les centres déjà
mémorisés avec `worldToUIX/Y`.

- rouge: bâtiment visité, aucun container inspecté;
- orange: partiellement fouillé;
- vert: tous les containers actuellement connus ont été inspectés;
- survol: type de lieu, statut et dernière visite;
- bouton mémoire NeatUI en bas à gauche: affichage activable/désactivable.

La liste de marqueurs est reconstruite uniquement lorsque la révision du store
change. Le rendu parcourt ce cache, sans scan du monde, BuildingDef ou carte.
Il n'appelle aucune API de symboles, markers ou annotations et n'écrit rien dans
la carte vanilla.

Capture de validation: `docs/images/survivor-memory-world-map.png`.
