# Steam Workshop description

`workshop/workshop.txt` est la metadata canonique transmise à l'éditeur B42.
Le bloc ci-dessous contient la même description sans les préfixes
`description=` et peut être copié directement dans Steam Workshop.

Les visuels utilisent des dérivés Workshop centrés des sources canoniques :

- mémoire : `assets/workshop/description/memory-hero.png` (640×190) ;
- Home : `assets/workshop/description/home.png` (640×120) ;
- Outpost : `assets/workshop/description/outpost.png` (640×120) ;
- Vehicle Memory : `assets/workshop/description/vehicle.png` (640×140) ;
- capture carte :
  `assets/workshop/screenshots/survivor-memory-world-map.png`.

Les URLs ciblent la branche publique `main` de
`Lucashw68/SurvivorMemory`. Elles ne deviennent accessibles que lorsque le
commit qui contient ces fichiers a été intégré à `main` et que le dépôt est
public. Vérifier les cinq URLs dans un navigateur avant de mettre la description
Steam à jour.

La capture carte est réelle, en anglais, sans interface de debug. Aucune capture
propre du panneau n'est actuellement suivie ; aucune image de test n'est donc
présentée comme capture de production.

Toute future capture Workshop doit respecter cette checklist :

- langue de Project Zomboid réglée sur **English** ;
- aucun overlay de débogage ni panneau développeur ;
- uniquement l'interface finale de production ;
- situation de jeu représentative ;
- échelle d'interface lisible ;
- fonctionnalités importantes plutôt qu'écrans de configuration.

## Final BBCode

```text
[h1]Ever walked into the same house twice?[/h1]
You know the feeling.
You open the same bathroom cabinet. Again.
You check the same kitchen. Again.
And somewhere around the third identical suburban house, you start wondering:
[i]Have I already been here?[/i]
Survivor Memory gives your character something surprisingly useful in the zombie apocalypse:
[img]https://raw.githubusercontent.com/Lucashw68/SurvivorMemory/main/assets/workshop/description/memory-hero.png[/img]
[h2]A memory.[/h2]
[b]Your survivor doesn't know everything.
They remember what they've seen.[/b]
[i] [/i]
[hr][/hr]
[h1]REMEMBER WHERE YOU'VE BEEN[/h1]
See when you first found a place, how often you have visited it, and how long it has been since you last came back.
Your survivor remembers the rooms they actually entered and the containers that genuinely appeared in the loot interface. Each building moves naturally from [b]Visited[/b] to [b]Partially Searched[/b] or [b]Searched[/b] as those memories grow.
A compact status indicator tells you where that memory stands. Click it whenever you need the full reminder.
[i]Yes, you already looted that bathroom.[/i]
[i] [/i]
[hr][/hr]
[h1]YOUR MEMORIES, ON THE MAP[/h1]
[img]https://raw.githubusercontent.com/Lucashw68/SurvivorMemory/main/assets/workshop/screenshots/survivor-memory-world-map.png[/img]
The World Map can display a discreet overlay for remembered buildings. Toggle it when you need it, hide it when you do not.
It is calculated from your survivor's memories and does not replace or pollute your manual map annotations.
[i] [/i]
[hr][/hr]
[h1]PLACES THAT MATTER[/h1]
Some remembered buildings become more than another dot on the map. Mark one manually as your personal [b]Home[/b] or [b]Outpost[/b] while keeping its real exploration status.
[b]HOME[/b]
[img]https://raw.githubusercontent.com/Lucashw68/SurvivorMemory/main/assets/workshop/description/home.png[/img]
The place your survivor calls home.
[b]OUTPOST[/b]
[img]https://raw.githubusercontent.com/Lucashw68/SurvivorMemory/main/assets/workshop/description/outpost.png[/img]
A useful foothold away from home.
Both receive their own World Map icon. Right-click a Survivor Memory marker to mark or clear the designation. Once a Home or Outpost is fully searched, the contextual memory indicator can quietly disappear without forgetting the place.
[i] [/i]
[hr][/hr]
[h1]EMOTIONAL MEMORY[/h1]
Some places really are harder to forget. An exceptionally severe and sustained encounter can leave a personal emotional memory of that location.
Coming back later may cause one small vanilla panic/stress reaction. The memory weakens with time and safe returns: no trauma points, no sanity system, no new moodle, and no permanent effect.
[i] [/i]
[hr][/hr]
[h1]THINGS WORTH REMEMBERING[/h1]
Your survivor can remember a few discoveries genuinely worth keeping in mind: generators, gas pumps, and antique ovens or wood stoves.
These memories always mean [i]last seen here[/i], never [i]still here[/i]. They are formed when the object is actually seen; Survivor Memory never searches the world remotely to check whether it stayed there.
No, this is not an index of every hammer, nail, or suspiciously precious can of beans.
[i] [/i]
[hr][/hr]
[h1]VEHICLE MEMORY[/h1]
[img]https://raw.githubusercontent.com/Lucashw68/SurvivorMemory/main/assets/workshop/description/vehicle.png[/img]
Remember where your survivor last meaningfully encountered a vehicle: when entering it, inspecting its mechanics, or getting out.
Legitimate dashboard and mechanics observations can also leave broad memories of fuel and overall condition, without storing suspiciously perfect percentages.
The marker is the vehicle's [i]last known position[/i]. There is no live GPS, no route tracking, and no magical update if somebody moves the car while you are gone.
[i]Because "where did I leave the car?" is apparently still a problem after civilization ends.[/i]
[i] [/i]
[hr][/hr]
[h1]MEMORIES AGE[/h1]
Visits update when your survivor returns. Emotional memories weaken with time and safe returns until they fade away.
Important objects and vehicles remain last-seen observations. The world may change while your survivor is away, and their memory may become outdated without pretending otherwise.
[i] [/i]
[hr][/hr]
[h1]NO MAGICAL KNOWLEDGE[/h1]
[b]It only records information your character has actually discovered.[/b]
Survivor Memory does not reveal:
[list]
[*]unexplored rooms;
[*]unseen containers;
[*]remote changes made while your survivor was away;
[*]information your survivor could not reasonably know.
[/list]
If someone moves something while you are gone, your survivor does not magically get a notification from the universe.
And no, the mod will not tell you where every can of beans in Kentucky is.
[i] [/i]
[hr][/hr]
[h1]MULTIPLAYER[/h1]
Memories belong to each character.
If Player A searches a house, Player B does not magically inherit that memory. Your friends still have to remember things themselves.
[i] [/i]
[hr][/hr]
[h1]FEATURES[/h1]
[list]
[*]First visit, last visit, and visit count for remembered buildings.
[*]Rooms entered and containers actually inspected.
[*]Visited, Partially Searched, and Searched states.
[*]Compact recall panel and contextual status indicator.
[*]Toggleable, non-destructive World Map overlay.
[*]Personal Home and Outpost designations.
[*]Rare, fading Emotional Memories from severe experiences.
[*]Last-seen memories for selected important objects and vehicles.
[*]Broad observed vehicle fuel and condition details, with no live tracking.
[*]Native Build 42 options for every major feature and map category.
[/list]
[h2]OPTIONS[/h2]
Survivor Memory uses Build 42's native [b]Options → Mods[/b] screen. Enable only the memories and map categories you want, choose the marker size, adjust emotional reactions, configure the recall shortcut, and select your preferred UI.
Turning something off never erases your character's existing memories. They simply wait quietly until you enable it again. Unlike the zombies, they are patient.
[h2]UI & COMPATIBILITY[/h2]
[list]
[*]Made for Project Zomboid Build 42.
[*]Complete vanilla UI included.
[*]Optional NeatUI integration when NeatUI is active.
[*]No required UI framework.
[*]Character-owned persistence in single-player and multiplayer.
[*]Configurable shortcut, marker filters, and marker size.
[/list]
[h2]LANGUAGES[/h2]
[list]
[*]English
[*]Simplified Chinese
[*]Russian
[*]Spanish
[*]Brazilian Portuguese
[*]French
[*]German
[/list]
[i] [/i]
[hr][/hr]
[h1]THE RULE BEHIND EVERYTHING[/h1]
[h2]Could the survivor reasonably remember this?[/h2]
If the answer is no, Survivor Memory should not know it either.
Workshop ID: 3793080806
Mod ID: SurvivorMemory
```

## Visual placement

1. Accroche, icône mémoire et manifeste court.
2. Mémoire des bâtiments.
3. Capture réelle de la World Map.
4. Home et Outpost avec leurs icônes distinctes.
5. Emotional Memory et Things Worth Remembering.
6. Vehicle Memory introduit par son icône.
7. Vieillissement, doctrine non omnisciente et multijoueur.
8. Récapitulatif, compatibilité, langues et règle finale.
