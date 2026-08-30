# Survivor Memory

> Your character doesn't know everything. They remember what they've seen.

Survivor Memory is an autonomous Project Zomboid Build 42 mod. NeatUI Framework
is used automatically when it is activated, with a complete vanilla UI fallback
when it is not. Its MVP stores,
per character, only buildings entered, rooms entered, and building containers
actually exposed through the loot UI.

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

`make smoke` utilise le harness PzModTools 0.2.0 et valide, pour NeatUI puis
vanilla, un cycle complet bâtiment → save → reload.

Inside a remembered building, use the world context-menu action “Recall this
building" to open the compact panel. It never opens automatically. No
world scan or remote container scan is performed.

While inside, a colored standalone memory moodle occupies the next visual slot
in the vanilla moodle stack and opens the panel when clicked. It follows the
vanilla moodle-size option without patching private game state. The World Map
renders a non-persistent overlay for remembered buildings; its memory button
toggles the overlay.
