# Survivor Memory

> Your character doesn't know everything. They remember what they've seen.

Ever returned to the same house and wondered whether you had already searched
it? Survivor Memory gives each Project Zomboid Build 42 character a persistent
memory of the places they have actually explored: buildings entered, rooms
visited, containers encountered, and the passage of time between visits.
Visited buildings can also be marked manually as a personal Home or Outpost.
These designations remain independent from exploration progress and use their
own non-persistent World Map overlay markers.

Exceptionally severe experiences can make a place hard to forget. Emotional
Memory requires sustained panic, real zombie danger, and serious vulnerability;
returning later may cause one small vanilla panic/stress reaction. It adds no
trauma score, sanity system, new moodle, or continuous effect.

Things Worth Remembering records only a few genuinely notable discoveries:
generators, gas pumps, and antique ovens / wood stoves. The wording is always
“last seen here”; the mod never claims that the object is still there. Wells
remain deferred until Build 42 exposes an identity that cannot be confused with
other unlimited water sources. A remarkable object is remembered automatically
when it becomes genuinely visible; no context-menu action is required.

Vehicle Memory remembers where the character last meaningfully encountered a
vehicle: when entering it, inspecting its mechanics, or leaving it. The World
Map marker is a last-seen position, never live tracking; driving does not record
a route or continuously update the memory.

The mod never scans the world for hidden knowledge. Memories are personal and
may become outdated, just like the survivor who formed them. NeatUI Framework
is used automatically when active, while a complete vanilla UI fallback keeps
it optional.

## Options

Build 42 exposes Survivor Memory under `Options → Mods`. Every major module can
be enabled independently: Building Memory, Places That Matter, Emotional
Memory, Things Worth Remembering, Vehicle Memory, the status indicator, and
the World Map overlay. Map categories, marker size, emotional reaction
strength, memorable object types, the recall key, and NeatUI preference can
also be configured.

Options are personal to the local Project Zomboid profile. Disabling a module
never deletes existing character memories; it only stops new observations and
hides that module until it is enabled again.

## Languages

Survivor Memory supports English, Simplified Chinese, Russian, Spanish,
Brazilian Portuguese, French, and German. Project Zomboid automatically uses
the matching translation when the selected game language is supported; there
is no separate mod-language setting.

## Repository layout

- `42/` contient exclusivement le runtime B42 et ses miroirs de déploiement ;
- `assets/` contient les sources canoniques de tous les visuels du mod ;
- `docs/` contient les décisions permanentes et les protocoles de validation ;
- `research/` peut conserver localement d'anciens plans et campagnes ; il est ignoré par Git ;
- `tests/` contient les tests déterministes et leurs résultats locaux courants ;
- `tools/` contient uniquement les helpers spécifiques à Survivor Memory ;
- `workshop/` contient les metadata et la preview requises par l'éditeur PZ.

Voir [`assets/README.md`](assets/README.md) pour la correspondance entre sources
canoniques et chemins imposés par B42.

## Development

```sh
make info
make test
make validate
make build
make package
make install
make install-dry-run
make dev
make logs
make logs-errors
make smoke
make version
```

`make smoke` utilise le harness PzModTools 0.4.1 et valide, pour NeatUI puis
vanilla, un cycle complet bâtiment → save → reload.

Inside a remembered building, use the world context-menu action “Recall this
building” to open the compact panel. It never opens automatically. No
world scan or remote container scan is performed.

The same context menu offers “Mark this place” with Home, Outpost, and None.
The choice belongs to the current character. A fully searched Home or Outpost
hides the contextual moodle while retaining its memory and map designation.
The same choices are available by right-clicking a Survivor Memory marker on
the World Map, including when the character is not currently inside that place.

While inside, a colored standalone memory moodle occupies the next visual slot
in the vanilla moodle stack and opens the panel when clicked. It follows the
vanilla moodle-size option without patching private game state. The World Map
renders a non-persistent overlay for remembered buildings; its memory button
toggles the overlay.
