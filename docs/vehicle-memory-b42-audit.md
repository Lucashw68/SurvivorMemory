# Vehicle Memory — audit B42

Audit effectué le 1er septembre 2026 sur l'installation locale B42.20.4. Les
constats ci-dessous proviennent du Lua vanilla et des classes du
`projectzomboid.jar`; les comportements marqués « validé en jeu » ont aussi été
exercés par le smoke Survivor Memory.

Source visuelle approuvée :
`assets/runtime/map-vehicle-marker.png`. Elle sert
uniquement au marqueur runtime Vehicle Memory; poster, icône du mod et preview
Workshop restent inchangés.

## Identité

`BaseVehicle:getSqlId()` expose l'identifiant de la base véhicules. Il est
retenu comme clé persistante principale sous la forme `vehicle:sql:<id>` dès
qu'il est non négatif. `BaseVehicle:getId()` est un identifiant court attribué
au runtime/réseau et n'est pas persisté par Survivor Memory.

Si le SQL ID n'est pas encore disponible, le fallback combine
`getScriptName()` et `getMechanicalID()`. Le `mechanicalID` est sauvegardé par
B42 mais est tiré dans un espace aléatoire limité; une collision reste donc
théoriquement possible. Lorsqu'un SQL ID apparaît après une première
observation, le store promeut le fallback vers la clé SQL sans créer de doublon.

Validé en jeu sur deux fixtures `Base.CarNormal` : SQL ID `1`, mechanical IDs
`42488` et `3082`, puis conservation d'une unique entrée après save/reload.

## Événements observables

- `ISEnterVehicle:perform()` appelle `triggerEvent("OnEnterVehicle",
  character)` après avoir placé le personnage dans le véhicule. À ce moment,
  `character:getVehicle()` fournit le véhicule observé.
- `ISExitVehicle:perform()` appelle `vehicle:exit(character)` avant
  `OnExitVehicle`. Le handler doit donc conserver la référence locale acquise à
  l'entrée. Survivor Memory l'efface immédiatement après l'observation de
  sortie.
- `ISVehicleMenu.onMechanic(playerObj, vehicle)` fournit directement les deux
  objets au moment où le joueur demande réellement la mécanique. Le wrapper
  appelle l'original et ne modifie pas l'action vanilla.
- Après reload alors que le personnage est déjà assis, une observation unique
  `resume` reconstruit la session. Elle ne se répète pas par frame.

Les événements entrée/sortie et la résolution d'identité ont été validés en jeu
avec un vrai `BaseVehicle`. Le chemin mécanique est vérifié contre le Lua B42 et
par validation statique, mais n'a pas encore été cliqué manuellement pendant le
smoke automatisé.

## Données retenues

Une observation contient uniquement identité, script/type, nom affiché,
coordonnées de la case, niveau et heure in-game. Elle ne contient ni carburant,
ni moteur, ni batterie, ni pneus, ni coffre, ni position actuelle distante.

L'entrée, la mécanique et la sortie sont des interactions significatives. La
conduite ne déclenche aucun enregistrement continu : aucune route et aucun
historique de positions ne sont construits.

## World Map

L'overlay dessine l'icône véhicule dédiée
`media/ui/SurvivorMemory/map-vehicle-marker.png` à `x/y/z` mémorisé et un
tooltip avec le nom et « Last seen ». L'icône runtime 64×64 dérive par recadrage
et réduction Lanczos de l'artwork fourni, dont le canal alpha est conservé. Le
rendu ne crée aucun symbole vanilla persistant. Il suit le toggle Survivor Memory et le cache est
invalidé seulement lorsque la révision du store personnel change.

Le marqueur a été rendu dans les smokes NeatUI et vanilla, puis capturé dans
`research/screenshots/localization-preflight/survivor-memory-world-map-fr.png`.

## Absence et oubli

L'oubli automatique n'est pas activé dans cette V1. Une voiture occupe plusieurs
cases, peut être remorquée ou momentanément absente du chunk; conclure à son
absence à partir d'une seule case introduirait des faux positifs. La doctrine
« en cas de doute, ne pas oublier » prévaut. Une future validation devra établir
un test local et visible, borné, sans parcourir la liste globale des véhicules.

## Multijoueur

Le store reste dans le `player ModData`. Le client ne demande jamais au serveur
la position réelle d'un véhicule mémorisé. Deux joueurs peuvent donc conserver
des coordonnées et des dates différentes pour le même véhicule, ce qui est le
comportement voulu.
