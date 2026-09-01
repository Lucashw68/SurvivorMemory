# Smoke test bâtiment B42

L'unique hook public `make smoke` utilise le harness save-cycle de PzModTools
0.4.0 dans deux caches isolés : avec NeatUI, puis avec Survivor Memory seul.
Chaque variante enchaîne création, sauvegarde et reload. Le scan du fixture est confiné au test; le runtime de
production ne scanne jamais un bâtiment.

Exécution Vehicle Memory du 1er septembre 2026, build 42.20.4: **PASS**.

- fixture vanilla: 16 rooms et 50 containers;
- mémoire créée sur la vraie transition extérieur → intérieur;
- 2 rooms traversées et 2 containers inspectés, sans doublon;
- sortie, avance de 6 heures par l'horloge in-game, puis retour;
- `firstVisited` inchangé, `lastVisited` 2.014486 → 8.025776;
- `visitCount` 1 puis 2, une seule fois;
- statut final `PARTIALLY_SEARCHED`: d'autres containers montrés par l'UI de
  loot étaient connus mais non inspectés;
- capture NeatUI et sauvegarde vanilla `save(true)` réussies.
- indicateur HUD visible et type `HOUSE` observé sans scan;
- World Map ouverte avec overlay, toggle NeatUI et capture réussis.

Les deux variantes ont réussi le protocole complet : backend `neat=true`
lorsque NeatUI est activé et backend `neat=false` lorsqu'il est absent de la
liste du monde. Dans les deux cas, moodle, panneau et bouton de carte étaient
présents et fonctionnels. La seconde variante utilise la vraie fenêtre
`ISCollapsableWindow` et les contrôles B42 vanilla, pas une reproduction du
thème NeatUI.

Depuis la version 1.6.0, le démarrage vérifie également que la section native
`PZAPI.ModOptions` de Survivor Memory est enregistrée et que les valeurs par
défaut critiques (Building Memory activé et taille de marqueur à 100 %) sont
effectivement chargées dans B42.

Régression du 31 août 2026 : **PASS** sur les deux variantes. Le scénario rend
volontairement obsolètes le statut et la couleur mis en cache par l'indicateur,
puis vérifie leur resynchronisation pendant l'update UI avant d'ouvrir la World
Map (`indicator_status_refreshes_without_map` et
`indicator_color_refreshes_without_map`). Les cycles save/reload réussissent
ensuite sans modification des données persistées.

La même exécution couvre Places That Matter : désignation `HOME`, chargement
réel des textures HOME et OUTPOST, sélection des deux chemins de marqueur,
masquage du moodle pour un `OUTPOST` `SEARCHED`, réapparition pour un `HOME`
`PARTIALLY_SEARCHED`, puis conservation de `HOME` après save/reload. Le fixture
observe explicitement un contenant supplémentaire sans l'inspecter afin que
l'état partiel soit déterministe quels que soient les boutons de loot déjà
présentés par B42.

Elle couvre également Emotional Memory : le scénario prépare un souvenir
émotionnel personnel, revient réellement dans le bâtiment, vérifie qu'une seule
réaction ajoute du panic et du stress vanilla, puis contrôle après reload les
timestamps `observedAt` et `lastReactionAt`. Le seuil de détection est couvert
par les tests déterministes; cette exécution ne prétend pas avoir reproduit un
combat naturel assez sévère pour le déclencher.

Things Worth Remembering est couvert avec deux vrais `IsoGenerator` créés dans
le fixture isolé : un dans le bâtiment et un dehors, ainsi qu'un `IsoObject`
utilisant le vrai sprite B42 `location_shop_fossoil_01_12`. Classification,
observation visible, agrégation, ligne « vu pour la dernière fois », cache des
marqueurs extérieurs et persistance après reload sont vérifiés avec NeatUI et
vanilla. Les poêles disposent de tests déterministes de classification mais pas
encore de fixture réel dans ce smoke.

Vehicle Memory est couvert par un vrai `Base.CarNormal` créé dans le fixture.
Les deux variantes ont résolu un SQL ID et un mechanical ID B42, déclenché les
handlers d'entrée et de sortie, conservé une seule mémoire, alimenté le cache du
marqueur World Map et retrouvé exactement une entrée après reload. La capture
World Map montre le glyph véhicule orange à côté des autres souvenirs. Le smoke
ne conduit pas le véhicule et confirme ainsi que le runtime ne dépend d'aucun
échantillonnage de trajet.

Preuves actuelles : `tests/results/building-console.txt`,
`tests/results/building-vanilla-ui-console.txt` et
`research/screenshots/localization-preflight/survivor-memory-panel-fr-debug.png`.

Avant une future publication Steam, refaire manuellement: bâtiment sans room standard,
meuble détruit/déplacé, meuble player-built, entrée/sortie rapide et téléport.
Les deux derniers cas sont aussi couverts par les tests déterministes.
