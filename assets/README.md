# Assets Survivor Memory

Ce dossier contient les sources canoniques des assets maintenus par le mod.
Les copies placées dans la structure B42 ou Workshop sont des miroirs de
déploiement imposés par Project Zomboid.

## Organisation

- `branding/poster.png` : artwork canonique du mod et de la preview Workshop ;
- `branding/icon.png` : icône canonique du mod ;
- `runtime/` : textures réellement chargées par le Lua Survivor Memory ;
- `workshop/description/` : dérivés de présentation centrés sur des canevas
  transparents, destinés exclusivement au BBCode Workshop ;
- `workshop/screenshots/` : destination des captures réelles anglaises préparées
  pour la page Workshop. Le dossier peut rester vide tant qu’une nouvelle
  capture conforme n’a pas été validée.

## Miroirs obligatoires

`make validate` vérifie byte-for-byte les correspondances suivantes :

- `branding/poster.png` → `poster.png`, `42/poster.png`,
  `workshop/preview.png` ;
- `branding/icon.png` → `icon.png`, `42/icon.png` ;
- `runtime/*.png` → `42/media/ui/SurvivorMemory/*.png`.

Les miroirs restent présents dans le dépôt parce que PZ B42 et son éditeur
Workshop attendent ces chemins exacts. `assets/` n'entre jamais dans le payload
runtime.
