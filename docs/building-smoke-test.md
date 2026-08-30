# Smoke test bâtiment B42

L'unique hook public `make smoke` utilise le harness save-cycle de PzModTools
0.2.0 dans deux caches isolés : avec NeatUI, puis avec Survivor Memory seul.
Chaque variante enchaîne création, sauvegarde et reload. Aucune carte ou logique
véhicules n'est chargée. Le scan du fixture est confiné au test; le runtime de
production ne scanne jamais un bâtiment.

Exécution du 29 août 2026, build 42.20.4: **PASS**.

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

Preuve: `test-results/building-smoke-console.txt` et
`docs/images/survivor-memory-panel.png`.

Avant publication Steam, refaire manuellement: bâtiment sans room standard,
meuble détruit/déplacé, meuble player-built, entrée/sortie rapide et téléport.
Les deux derniers cas sont aussi couverts par les tests déterministes.
