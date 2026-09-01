# Documentation

Les investigations et campagnes qui ne décrivent plus l'état courant peuvent
être conservées localement sous `research/`, un dossier ignoré par Git.

## Architecture et APIs B42

- `b42-memory-api-audit.md` : APIs bâtiment, persistance et World Map ;
- `persistence-and-multiplayer.md` : format v5 et propriété par personnage ;
- `character-memory-semantics.md` : mort, respawn et isolation des souvenirs ;
- `neatui-audit.md` : intégration optionnelle et fallback vanilla.

## Règles métier

- `search-completion-semantics.md` : statuts d'exploration ;
- `location-naming-semantics.md` : noms de lieux non omniscients ;
- `item-memory-contract.md` : contrat des choses remarquables ;
- `roadmap.md` : état livré et suites prudentes.

## Audits des extensions

- `emotional-memory-b42-audit.md` ;
- `things-worth-remembering-b42-audit.md` ;
- `vehicle-memory-b42-audit.md` ;
- `moodle-indicator-audit.md`.

## Validation

- `building-smoke-test.md` ;
- `save-reload-validation.md` ;
- `mp-sanity.md` ;
- `performance-notes.md`.

Les sorties courantes correspondantes sont regroupées sous `tests/results/`.

## Publication

- `workshop-description.md` : BBCode et emplacement des captures ;
- `releases/` : notes de version et checklists de publication maintenues ;
- `localization.md` : langues runtime, validation et limites du workflow Workshop ;
- les captures anglaises prêtes à publier sont centralisées sous
  `assets/workshop/screenshots/` ; les anciennes validations peuvent être
  archivées localement sous `research/screenshots/`.
