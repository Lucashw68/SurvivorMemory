# Performance

`OnPlayerUpdate` retourne immédiatement si la case n'a pas changé. Aucun monde,
BuildingDef ou ensemble de containers n'est scanné par frame. Les mutations
arrivent seulement sur transition de case/bâtiment/room ou callback loot UI.

Smoke réel, un bâtiment: 1 284 callbacks joueur, 6 transitions traitées, 2
entrées, 1 sortie, 2 rooms, 2 inspections, 10 écritures/synchronisations et
1 157 octets logiques estimés.

Estimation synthétique (10 rooms, 15 containers connus, 10 inspectés chacun):

| Bâtiments | Taille logique |
|---:|---:|
| 100 | 190 180 octets (~186 Kio) |
| 500 | 961 029 octets (~939 Kio) |
| 1 000 | 1 949 029 octets (~1,86 Mio) |

L'estimateur mesure les tables Lua, pas le blob exact B42. La croissance est
linéaire. Le panneau debug expose les compteurs et la taille courante. La carte
met en cache la liste des mémoires selon `root.revision`; elle ne relit pas les
tables bâtiment complètes à chaque frame et ne scanne jamais le monde.

Le moodle autonome ne scanne aucune donnée de mémoire. Son positionnement
compte au maximum les 26 moodles vanilla quatre fois par seconde (104 lectures
de niveaux par seconde lorsqu'il est visible). Son tooltip est rafraîchi une
fois par seconde afin que la date relative reste correcte.
