# Sanity multijoueur

## Invariants vérifiés

- store exclusivement dans le `player modData`;
- aucun world modData ou registre partagé;
- callbacks résolus par joueur local et `playerNum`;
- `transmitModData()` seulement après mutation;
- aucune commande de partage;
- test déterministe: deux modData ne partagent aucun bâtiment.

## Protocole deux clients

Sur serveur B42 isolé, A et B rejoignent la même save. A entre dans X et ouvre
un container; B reste dehors. Vérifier que seul A possède le buildingKey.
Reconnecter A et contrôler son store, puis B et l'absence de X.

Ce protocole à deux processus clients n'a pas été exécuté par le harness SP de
ce jalon. Il reste un gate avant publication; aucune réussite MP réelle ne doit
être déduite du seul test déterministe.
