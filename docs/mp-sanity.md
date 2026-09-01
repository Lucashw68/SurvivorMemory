# Sanity multijoueur

## Invariants vérifiés

- store exclusivement dans le `player modData`;
- aucun world modData ou registre partagé;
- callbacks résolus par joueur local et `playerNum`;
- `transmitModData()` seulement après mutation;
- aucune commande de partage;
- test déterministe: deux modData ne partagent aucun bâtiment, désignation,
  souvenir émotionnel, ressource remarquable ou souvenir véhicule.

## Protocole deux clients

Sur serveur B42 isolé, A et B rejoignent la même save. A entre dans X, ouvre un
container, désigne le bâtiment `OUTPOST`, possède un souvenir émotionnel et une
observation remarquable et une observation véhicule; B reste dehors. Vérifier
que seul A possède ces données.

Exécution Vehicle Memory du 1er septembre 2026 sur B42.20.4 avec PzModTools
0.4.0 : **PASS**.

- serveur dédié prêt et arrêté proprement;
- deux clients simultanés connectés sous deux identités distinctes;
- A : bâtiment, room, container, `designation=OUTPOST`, `emotional=true`,
  `important=1` et `vehicles=1` présents;
- B : mémoire étrangère absente, `buildings=0`, `important=0` et `vehicles=0`;
- aucun processus orphelin ni kill forcé.

Preuve brute :
`tests/results/mp-smoke/20260831T222744Z-1312050/summary.json`.

La persistance après reconnexion n'a pas été rejouée dans cette exécution
ciblée; elle reste couverte par les validations MP antérieures du mod et par le
cycle save/reload réel pour le format v5.
