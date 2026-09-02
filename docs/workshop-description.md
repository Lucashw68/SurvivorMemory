# Steam Workshop description

Ce document est la maquette éditoriale de la page Workshop. Les deux marqueurs
visuels ne doivent jamais être publiés littéralement : ils indiquent où insérer
le BBCode fourni par Steam après l'upload réel de chaque capture.

Toutes les captures destinées au Workshop doivent respecter cette checklist :

- langue de Project Zomboid réglée sur **English** ;
- aucun overlay de débogage ni panneau développeur ;
- uniquement l’interface finale de production ;
- situation de jeu représentative ;
- échelle d’interface lisible ;
- fonctionnalités importantes plutôt qu’écrans de configuration.

Le smoke dédié force `language=EN` uniquement dans son profil isolé. Il ne
modifie pas les préférences du profil Project Zomboid normal.

- `{{WORLD_MAP_SCREENSHOT}}` → capture anglaise validée
  `assets/workshop/screenshots/survivor-memory-world-map.png` ;
- `{{MEMORY_PANEL_SCREENSHOT}}` → future capture anglaise
  `assets/workshop/screenshots/survivor-memory-panel.png`.

Les anciennes captures françaises et la capture anglaise du panneau contenant
encore la console de smoke ont été archivées sous
`research/screenshots/localization-preflight/`. Elles ne doivent pas être
utilisées sur le Workshop. La carte a été régénérée en anglais ; le panneau
reste à capturer proprement dans une partie normale.

Tant qu'aucune URL Steam n'est disponible et vérifiée, `workshop/workshop.txt`
conserve le même texte sans ces deux marqueurs. Les captures peuvent être
ajoutées manuellement à la galerie de l'item sans entrer dans le payload du mod.

## Final BBCode

```text
[h1]Ever walked into the same house twice?[/h1]
You know the feeling.
You open the same bathroom cabinet. Again.
You check the same kitchen. Again.
And somewhere around the third identical suburban house, you start wondering:
[i]Have I already been here?[/i]
Survivor Memory gives your character something surprisingly useful in the zombie apocalypse: a memory.
[b]Your survivor doesn't know everything.[/b]
[b]They remember what they've seen.[/b]

{{WORLD_MAP_SCREENSHOT}}

[h1]What does it do?[/h1]
Survivor Memory keeps track of the places your character has actually explored. It remembers when they first found a building, when they last returned, which rooms they entered, and which containers they really inspected.
Every remembered building can be [b]Visited[/b], [b]Partially Searched[/b], or [b]Searched[/b] based on your survivor's own observations.

{{MEMORY_PANEL_SCREENSHOT}}

[h2]Remember where you've been[/h2]
See when you first found a place, how many times you have visited it, and how long it has been since you last came back.
A compact status indicator appears while you are inside a remembered building. Click it whenever you need a quick reminder.

[h2]Remember what you've searched[/h2]
Your survivor remembers the rooms they actually entered and the containers that genuinely appeared in the loot interface.
Yes, you already looted that bathroom.

[h2]See your memories on the map[/h2]
The World Map can display a discreet overlay for remembered buildings. Toggle it when you need it, hide it when you do not.
The overlay does not replace or pollute your manual map annotations.

[h2]Places That Matter[/h2]
A remembered building can become your personal [b]Home[/b] or [b]Outpost[/b]. Mark it manually, keep its exploration status, and find it again with its own World Map icon.
Right-click a Survivor Memory marker on the World Map to mark or clear that personal place directly.
Once a Home or Outpost is fully searched, its memory indicator quietly gets out of your way while the place remains remembered.

[h2]Emotional Memory[/h2]
Some places really are harder to forget. An exceptionally severe and sustained encounter can leave a personal memory of that place.
Coming back later may cause one small vanilla panic/stress reaction. It fades with time and safe returns: no trauma points, no sanity system, no new moodle, and no permanent effect.

[h2]Things Worth Remembering[/h2]
Your survivor can remember a few discoveries that are genuinely worth keeping in mind: generators, gas pumps, and antique ovens or wood stoves.
These memories always say [i]last seen here[/i], never [i]still here[/i]. See one in the world or encounter its container normally; Survivor Memory never searches the world for it.

[h2]Vehicle Memory[/h2]
Remember where your survivor last meaningfully encountered a vehicle: when entering it, inspecting its mechanics, or getting out.
Mechanics inspections and readable dashboard information leave broad memories too: an empty, low, partly filled, or apparently full tank; a running engine; or an engine that looked broken, badly damaged, or usable. No suspiciously perfect percentages.
The map marker shows where the vehicle was last seen. It is not live GPS, does not record your route, and does not know if somebody moved the car while you were gone.
Because “where did I leave the car?” is apparently still a problem after civilization ends.

[h2]Memories age — the world does not stand still[/h2]
Visits update when your survivor returns. Emotional memories weaken with time and safe returns until they fade away.
Important objects and vehicles are remembered as [i]last seen[/i]. Those memories can become outdated, but Survivor Memory will never check them remotely behind your character's back.

[h2]No magical knowledge[/h2]
Survivor Memory does not scan the world. It only records information your character has actually discovered.
It does not reveal:
[list]
[*]unexplored rooms;
[*]containers your survivor has never encountered;
[*]remote changes made while your survivor was away;
[*]information your survivor could not reasonably know.
[/list]
If someone moves something while you are gone, your survivor does not magically get a notification from the universe.
And no, the mod will not tell you where every can of beans in Kentucky is.

[h2]Multiplayer[/h2]
Memories belong to each character.
If Player A searches a house, Player B does not magically inherit that memory. Your friends still have to remember things themselves.

[h2]UI & compatibility[/h2]
[list]
[*]Made for Project Zomboid Build 42.
[*]Complete vanilla UI included.
[*]Optional NeatUI integration when NeatUI is active.
[*]No required UI framework.
[*]Character-owned persistence in single-player and multiplayer.
[/list]

[h2]Make it yours[/h2]
Survivor Memory uses Build 42's native [b]Options → Mods[/b] screen. Enable only the memories you want: buildings, meaningful places, emotional memories, important discoveries, vehicles, the status indicator, or the World Map overlay.
Map categories, marker size, memorable object types, reaction strength, the recall key, and the NeatUI preference can also be adjusted.
Turning something off never erases your character's existing memories. They simply wait quietly until you enable it again. Unlike the zombies, they are patient.

[h1]Quick feature list[/h1]
[list]
[*]First visit, last visit, and visit count for remembered buildings.
[*]Rooms actually entered.
[*]Containers actually presented and inspected through the loot UI.
[*]Visited, Partially Searched, and Searched states.
[*]Compact recall panel and contextual status indicator.
[*]Toggleable, non-destructive World Map overlay.
[*]Personal Home and Outpost designations with distinct map markers.
[*]Rare Emotional Memories from exceptionally severe experiences.
[*]Last-seen memories for selected generators, gas pumps, and wood stoves.
[*]Last-seen vehicle positions and broad observed fuel/engine details, with no live tracking.
[*]Native Build 42 mod options for every major feature and map category.
[/list]

[h2]Languages[/h2]
[list]
[*]English
[*]Simplified Chinese
[*]Russian
[*]Spanish
[*]Brazilian Portuguese
[*]French
[*]German
[/list]

[h2]The rule behind everything[/h2]
[b]Could the survivor reasonably remember this?[/b]
If the answer is no, Survivor Memory should not know it either.
```

## Visual placement

1. Intro et tagline.
2. Capture World Map, utilisée tôt comme visuel principal.
3. Section « What does it do? ».
4. Capture du panneau mémoire.
5. Explication des bénéfices, doctrine, MP et compatibilité.
6. Liste concise puis rappel de la règle non omnisciente.

Aucun troisième visuel existant n'apporte actuellement une information assez
différente. Une future capture réelle montrant plusieurs bâtiments avec des
états distincts pourrait compléter la page, mais ne doit pas être fabriquée.
