# Tests

- `test_runner.lua` contient les assertions déterministes ;
- `results/` contient les résultats locaux courants et reste ignoré par Git.

Le smoke bâtiment écrit directement dans `tests/results/`. PzModTools 0.4.1
écrit encore les résultats de `make smoke-mp` dans `test-results/mp-smoke/` à
la racine du mod, sans option de destination. Après une nouvelle campagne MP,
son dossier doit être déplacé vers `tests/results/mp-smoke/` si le résultat
devient la preuve courante, ou vers `research/test-campaigns/mp-smoke/` s'il
devient historique.
