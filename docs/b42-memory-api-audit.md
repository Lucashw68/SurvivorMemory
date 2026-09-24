# Audit des APIs mémoire — Project Zomboid B42

Audit statique de l'installation locale le 29 août 2026: version annoncée dans
`console.txt` **42.20.4** (`b0bbce05d5`), Steam build ID `24909800`, SHA-256 du
JAR commençant par `80e405a4bfc42f6072e75b37`. Les conclusions ci-dessous
portent sur cette build, pas sur B41.

Les traductions du MVP utilisent également le format B42 JSON natif
`Translate/<langue>/IG_UI.json`, et non les tables `*_EN.txt` historiques.

### Lua/Kahlua — présence d'entrées

Le smoke B42 du 23 septembre 2026 a montré que le global Lua standard `next`
n'est pas disponible (`Object tried to call nil` dans le test de présence du
badge carte). Utiliser `pairs` avec retour dès la première entrée pour tester
une table non vide. Le test simulé du badge désactive explicitement `next`
pour ne pas masquer cette différence avec l'interpréteur Lua des tests locaux.

## Buildings et rooms

`IsoGridSquare` expose `getBuilding()`, `getBuildingDef()`, `getRoom()` et
`getRoomDef()`. `IsoBuilding` expose `getDef()` et un `int getID()`. Cet ID est
un compteur de l'instance streamée (`idCount`) et n'est donc pas retenu.

`BuildingDef` expose les bounds `getX/Y/X2/Y2`, `getMinLevel/MaxLevel`, les
rooms, `long getID()`, `getIDString()` et `calculateMetaID(cellX, cellY)`. Le
bytecode de `calculateMetaID` encode niveau et coordonnées locales à une
meta-cell; c'est déterministe dans cette build, mais aucune API ne garantit que
`id` ou sa stratégie d'affectation survivra à une évolution de map/mod. Le MVP
utilise donc sa propre clé géométrique versionnée:

`b1:x:y:x2:y2:minLevel:maxLevel`

Les IDs natifs ne sont conservés qu'en diagnostic. Une modification de map qui
change les bounds crée volontairement une nouvelle identité; fusion/séparation
de bâtiments n'est pas migrable sans heuristique et est documentée comme
risque.

`RoomDef` expose bounds, niveau, nom, `id`, `metaId` et `calculateMetaID`.
L'identité de room utilise bâtiment + bounds + niveau + nom avec encodage de
longueur. Deux rooms superposées, de même nom et mêmes bounds seraient une
collision; aucun cas vanilla n'a été établi, mais le risque est explicite.

Le nombre total `BuildingDef:getRoomsNumber()` est accessible. Il n'est jamais
lu par le runtime: l'afficher dévoilerait la topologie d'étages non explorés.
L'UI dit donc seulement « Rooms explored: N ».

## Détection d'entrée

`Events.OnSeeNewRoom` existe, mais correspond à la vision/découverte moteur et
non à l'entrée physique exigée. `Events.OnPlayerUpdate` reçoit le joueur local.
Le runtime mémorise sa dernière case et retourne immédiatement tant que x/y/z
n'a pas changé. Sur changement de case seulement, il compare les clés de
bâtiment et room:

- extérieur → intérieur: `ENTER_BUILDING`, création ou nouvelle visite;
- intérieur → extérieur/autre bâtiment: `EXIT_BUILDING`;
- nouvelle room courante: découverte unique.

Le coût par update est trois lectures de coordonnées et trois comparaisons; les
appels Java de bâtiment/room et les écritures n'arrivent qu'au changement de
case. `lastVisited` et `visitCount` changent uniquement à l'entrée.
Au premier update après chargement, un bâtiment déjà mémorisé reprend la session
sans incrémenter le compteur; un personnage neuf apparaissant à l'intérieur
crée en revanche sa première observation.

## Containers

`ItemContainer` expose `getParent()`, `getSourceGrid()`, `getType()`,
`getContainingItem()`, `isVehiclePart()` et l'état `isExplored()`. `IsoObject`
expose `getObjectIndex()`, `getSpriteName()`, `getContainerCount()` et
`getContainerByIndex()`.

`OnContainerUpdate` signifie modification/rafraîchissement et est déclenché par
de nombreuses opérations sans inspection. Il n'est pas un signal fiable
d'ouverture. B42 sélectionne réellement un container via
`ISInventoryPage:selectContainer` ou `setNewContainer`; les containers proches
sont matérialisés via `addContainerButton`. Le mod enveloppe ces trois méthodes:

- apparition dans le loot UI → container connu;
- sélection/affichage dans le loot UI → container inspecté.

Le filtre MVP rejette véhicules et containers dans un item, exige un
`IsoObject` parent et exige que la source appartienne au bâtiment. Un container
posé par le joueur peut encore satisfaire ce filtre: le distinguer d'un meuble
natif n'a pas d'API publique fiable dans la build auditée.

La clé est `c1:x:y:z:objectIndex:containerIndex:spriteName:type`. Déplacer le
meuble crée une nouvelle observation; le détruire laisse un souvenir obsolète;
un nouvel objet peut rétrograder la complétion. L'ordre des objets d'une case
est sauvegardé en pratique mais n'est pas contractuellement stable: c'est le
principal risque d'identité container MVP.

### Respawn du loot (B42.20.4)

L'inspection bytecode de `zombie.LootRespawn` confirme que le traitement ne
s'exécute pas sur un client MP. Il vérifie périodiquement les chunks chargés et
ne traite que `TownZone`, `TownZones` et `TrailerPark`, selon
`HoursForLootRespawn`, `SeenHoursPreventLootRespawn`, le seuil maximal d'items,
les constructions et, côté serveur, les safehouses.

Un contenant doit être `explored` et `hasBeenLooted`. Lorsque
`ItemPickerJava.fillContainer` ajoute effectivement au moins un objet,
`LootRespawn` appelle `setHasBeenLooted(false)`. Le paquet MP
`AddInventoryItemToContainer` transmet les nouveaux objets mais pas ce booléen.
La confirmation de Survivor Memory est donc locale en solo et prend la forme
d'une requête serveur ciblée en MP, uniquement lors de la sélection dans le
loot UI d'un contenant connu et précédemment pillé. Le serveur valide les
coordonnées, l'identité, le bâtiment et la proximité avant de lire le drapeau.
Aucun événement Lua public dédié au respawn et aucun scan de bâtiment ne sont
utilisés.

## Temps et persistence

`GameTime:getWorldAgeHours()` fournit un double in-game déterministe. Les valeurs
brutes stockées sont des heures depuis le début du monde; les libellés humains
sont calculés à l'affichage.

La mémoire est placée dans `IsoPlayer:getModData().SurvivorMemory`. Elle suit le
fichier personnage en solo et reste propre au personnage. En client MP,
`IsoGameCharacter:transmitModData()` est appelé après une mutation. Ce chemin
évite `ModData.getOrCreate`, qui est global à la save/au serveur et partagerait
implicitement les souvenirs.

Les tables Lua sérialisables sont supportées; références Java, fonctions et
metatables ne sont jamais persistées. Le format courant a `schemaVersion = 11`
et une fonction de migration centrale. La v2 ajoute la désignation personnelle;
la v3 ajoute le souvenir émotionnel optionnel.

## World Map

B42 expose `UIWorldMap`, `WorldMapMarkers:addGridSquareMarker` et les APIs
`getSymbolsAPIv2()` avec ajout de texte/texture, couleurs, échelles et position.
Cependant:

- les markers sont transitoires et sans tooltip public;
- les symbols sont des annotations du `MapItem`, sauvegardées/partageables et
  éditables par l'utilisateur;
- aucune couche de mod nommée avec cycle de vie/tooltip propre n'a été trouvée;
- écrire un symbole par bâtiment risquerait de polluer les annotations du
  joueur et leur synchronisation MP.

Décision MVP+1: overlay de rendu `ISWorldMap` validé en B42.20.4. Il projette
uniquement les centres des mémoires du personnage, sans appeler l'API markers
ou symbols et sans modifier les annotations persistantes. Un cache indexé par
la révision du store évite de reconstruire la liste à chaque frame.

Les marqueurs `HOME` et `OUTPOST` utilisent leurs textures propres et des
facteurs de rendu respectifs de 130 % et 165 %. Le clic droit effectue son
hit-test uniquement sur les mémoires déjà affichées et propose `HOME`,
`OUTPOST` ou `NONE`; il ne crée aucun symbole vanilla. La capture réelle de
référence se trouve dans
`research/screenshots/localization-preflight/survivor-memory-world-map-fr.png`.

## Performance et instrumentation

L'audit complémentaire des couches de rendu B42 et des liaisons de sous-sols
est détaillé dans [map-and-basement-memory.md](map-and-basement-memory.md).

Il n'existe aucun scan mondial, scan de bâtiment complet ou scan périodique de
containers. Le suivi du respawn ajoute une écriture unique lorsqu'un contenant
éligible devient armé et, en MP, une requête ciblée lorsqu'il est réinspecté.
Les compteurs persistés sous `debug` sont `buildingEntries`,
`buildingExits`, `roomsDiscovered`, `containersObserved` et
`containersInspected` et `modDataWrites`. Le panneau debug montre aussi la
session, les clés observées, les timestamps bruts, la version et la taille
logique estimée du store.
