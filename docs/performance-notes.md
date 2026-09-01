# Performance

`OnPlayerUpdate` retourne immédiatement si la case n'a pas changé. Aucun monde,
BuildingDef ou ensemble de containers n'est scanné par frame. Les mutations
arrivent seulement sur transition de case/bâtiment/room ou callback loot UI.

Smoke réel du 1er septembre 2026, un bâtiment: 1 366 callbacks joueur, 6 transitions
traitées, 2 entrées, 1 sortie, 2 rooms et 2 inspections. Avec les mutations de
désignation, Emotional Memory, deux souvenirs agrégés de générateur et une
mémoire véhicule propres au scénario, la mémoire atteint environ 2,3 Kio
(2 324 octets dans les dernières variantes). Ces
transitions supplémentaires sont ponctuelles et ne créent aucun travail par
frame.

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

`placeDesignation` ajoute une chaîne scalaire par bâtiment; il ne change pas
l'ordre de grandeur linéaire ci-dessus. Le cache de carte est invalidé par la
révision déjà existante et ne reconstruit la liste qu'après une mutation.

Emotional Memory échantillonne au maximum une fois par seconde et uniquement
pendant une visite de bâtiment non encore déclenchée. Chaque échantillon lit
sept scalaires déjà calculés par B42; aucun zombie, square ou bâtiment n'est
parcouru. La persistance et la synchronisation ne se produisent qu'au seuil
complet, lors d'une réaction ou d'une habituation.

Things Worth Remembering ne parcourt jamais le monde. `LoadGridsquare` et
`OnObjectAdded` alimentent un cache client transitoire contenant uniquement les
rares objets remarquables des cases chargées; `OnObjectAboutToBeRemoved` retire
immédiatement ceux qui disparaissent. Après un changement de case, de
direction ou de contenu de ce cache, une passe différée de 250 ms teste ces
seuls candidats avec `isCanSee`; `OnSeeNewRoom` programme également cette passe
quand une ligne de vue s'ouvre sans déplacement. Elle n'écrit que lors d'une
transition vers visible. Les références déchargées sont éliminées pendant ces passes. Le parent
d'un conteneur déjà présenté dans le loot UI reste un second signal légitime.
L'overlay met les observations extérieures dans son cache invalidé par
`root.revision`; il n'effectue aucun scan spatial.

Vehicle Memory écrit uniquement sur entrée, demande de mécanique, sortie ou
reprise unique après reload. Pendant la conduite, aucune position n'est
échantillonnée. La World Map relit la petite liste personnelle uniquement lors
de la reconstruction du cache après changement de `root.revision`.

Le moodle autonome ne scanne aucune donnée de mémoire. Son positionnement
compte au maximum les 26 moodles vanilla quatre fois par seconde (104 lectures
de niveaux par seconde lorsqu'il est visible). Son tooltip est rafraîchi une
fois par seconde afin que la date relative reste correcte. Pendant l'update UI
déjà existant, il compare également le statut et la désignation afin de réparer une
présentation périmée ; cette vérification est constante, n'alloue rien lorsque
le statut est inchangé et ne parcourt ni bâtiments, ni rooms, ni containers.
