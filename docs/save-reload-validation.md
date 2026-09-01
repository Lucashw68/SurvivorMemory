# Validation save / reload

1. `make smoke` demande à PzModTools un cycle par backend UI.
2. Le driver crée les observations et appelle `save(true)`.
3. Le harness découvre la save produite et rappelle le driver en étape reload.
4. Un nouveau processus B42 sélectionne cette save et contrôle le player
   modData après `OnGameStart`.

Attendu: schéma v5, un bâtiment, deux visites, deux rooms, deux containers
inspectés, timestamps ordonnés, statut `PARTIALLY_SEARCHED` et désignation
`HOME`. Le souvenir émotionnel et le timestamp de sa réaction doivent également
être présents. Les souvenirs agrégés des vrais générateurs intérieur et
extérieur, leurs coordonnées et `observedAt`, doivent également survivre.
Une unique observation véhicule, avec son identité stable et sa dernière
position connue, doit également survivre.

Exécution du 1er septembre 2026 sur B42.20.4: **PASS** avec NeatUI puis avec le
fallback vanilla, dans un second processus pour chaque variante. Le personnage
sauvegardé était vivant et les invariants ci-dessus ont été lus
dans l'`IsoPlayer` réellement désérialisé. Preuve brute:
`tests/results/reload-console.txt`.

Une session déjà active au reload est `resumed`, pas comptée comme nouvelle
entrée. Les données v1 migrent via v2 avec `placeDesignation = NONE`; v3 ajoute
la mémoire émotionnelle, v4 `importantMemories` et v5 `vehicleMemories`. Les données partielles sont
assainies et une entrée irréparable est
retirée. Un schéma futur non supporté crée `SurvivorMemoryRecovery` puis repart
sur un store vide au lieu de planter.
