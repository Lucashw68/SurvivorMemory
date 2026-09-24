# Validation save / reload

1. `make smoke` demande à PzModTools un cycle par backend UI.
2. Le driver crée les observations et appelle `save(true)`.
3. Le harness découvre la save produite et rappelle le driver en étape reload.
4. Un nouveau processus B42 sélectionne cette save et contrôle le player
   modData après `OnGameStart`.

Attendu actuellement : schéma v11, un bâtiment, deux visites, deux rooms, deux containers
inspectés, timestamps ordonnés, statut `PARTIALLY_SEARCHED` et désignation
`HOME`. Le souvenir émotionnel et le timestamp de sa réaction doivent également
être présents. Les souvenirs agrégés des vrais générateurs intérieur et
extérieur, leurs coordonnées et `observedAt`, doivent également survivre.
Une unique observation véhicule, avec son identité stable, sa dernière
position connue et sa désignation personnelle éventuelle, doit également survivre.
La boîte de clous sélectionnée doit conserver son type, sa quantité et sa clé
de texture. Le store séparé du fixture sous-sol (conservé uniquement dans le
`debug` du profil de test) doit garder un alias, un bâtiment canonique, une
visite et les deux snapshots historiques après rechargement réel.
Le titre du livre réellement pris dans l'inventaire doit aussi rester marqué
« déjà récupéré » après rechargement, y compris sur un autre exemplaire.

Exécution historique du 1er septembre 2026 (schéma v6) sur B42.20.4: **PASS** avec NeatUI puis avec le
fallback vanilla, dans un second processus pour chaque variante. Le personnage
sauvegardé était vivant et les invariants ci-dessus ont été lus
dans l'`IsoPlayer` réellement désérialisé. Preuve brute:
`tests/results/reload-console.txt`.

Une session déjà active au reload est `resumed`, pas comptée comme nouvelle
entrée. Les données v1 migrent via v2 avec `placeDesignation = NONE`; v3 ajoute
la mémoire émotionnelle, v4 `importantMemories`, v5 `vehicleMemories`, v6 la
désignation personnelle des véhicules, v7 le respawn vanilla, v8 les objets
sélectionnés et v9 les alias de sous-sols observés. Les données partielles sont
assainies et une entrée irréparable est
retirée. Un schéma futur non supporté crée `SurvivorMemoryRecovery` puis repart
sur un store vide au lieu de planter.

Exécution du 23 septembre 2026 (schéma v9) : **PASS** pour les deux backends,
y compris le souvenir de boîte de clous et le store de sous-sol lié. Le verdict
final du harness est `SMOKE MATRIX PASS variants=2`, code retour 0. Le détail
des contrôles et de leurs limites figure dans
[map-and-basement-memory.md](map-and-basement-memory.md#résultats-exécutés--23-septembre-2026).

Exécution du 23 septembre 2026 (schéma v10) : `make smoke` passe la matrice
complète (`SMOKE MATRIX PASS variants=2`). Création puis rechargement B42
réussis avec NeatUI et vanilla. Le smoke vérifie que seules les catégories
des deux pièces effectivement traversées sont conservées, puis confirme leur
persistance au rechargement. `make test` : 441 assertions lors de la validation
finale ; la même version runtime a ensuite passé la matrice B42 complète.

Exécution du 24 septembre 2026 (schéma v11) : `make smoke` passe à nouveau la
matrice complète avec NeatUI et vanilla (`SMOKE MATRIX PASS variants=2`). Une
prise réelle de livre depuis un conteneur, l'identification d'un second
exemplaire et la sauvegarde/relecture de sa clé personnelle sont vérifiées.
`make test` passe 484 assertions déterministes ; `make validate` et
`make build` passent également.
