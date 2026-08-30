# Validation save / reload

1. `make smoke` demande à PzModTools un cycle par backend UI.
2. Le driver crée les observations et appelle `save(true)`.
3. Le harness découvre la save produite et rappelle le driver en étape reload.
4. Un nouveau processus B42 sélectionne cette save et contrôle le player
   modData après `OnGameStart`.

Attendu: schéma v1, un bâtiment, deux visites, deux rooms, deux containers
inspectés, timestamps ordonnés et statut `PARTIALLY_SEARCHED`.

Exécution du 29 août 2026 sur B42.20.4: **PASS** dans un second processus. Le
personnage sauvegardé était vivant et les sept invariants ci-dessus ont été lus
dans l'`IsoPlayer` réellement désérialisé. Preuve brute:
`test-results/reload-console.txt`.

Une session déjà active au reload est `resumed`, pas comptée comme nouvelle
entrée. Les données v1 partielles sont assainies; une entrée irréparable est
retirée. Un schéma futur non supporté crée `SurvivorMemoryRecovery` puis repart
sur un store vide au lieu de planter.
