# Carte et liaisons observées de sous-sols

## Présentation sans nouvelle connaissance

`MapPresentation` contient les règles déterministes d'opacité, de taille de
véhicule personnel et de visibilité du point joueur. Le rendu ne lit que les
mémoires et la position du personnage local, jamais la position distante d'un
objet ou véhicule mémorisé. Le rayon natif vaut 300 cases (50–2 000).

Dans le rayon, opacité 100 %. Entre une et deux fois le rayon, décroissance
linéaire jusqu'à 25 % pour les souvenirs ordinaires, 85 % pour les personnels.
Le survol ou la désactivation de l'option donne 100 %. HOME/OUTPOST gardent les
textures approuvées et leurs facteurs 1,30/1,65. La voiture personnelle garde
la texture voiture, facteur 1,25 contre 1,05 pour une voiture ordinaire, avec
un repère doré discret dessiné par l'UI. Aucun nouvel asset n'est nécessaire.

Les deux passes de rendu placent les souvenirs personnels au-dessus des autres.
Le point joueur est redessiné ensuite, avant le tooltip.

## APIs locales B42 inspectées

### Tooltips de carte

`MapTooltip` dessine les tooltips des bâtiments, véhicules et objets
remarquables avec les primitives de la carte : titre Medium clair, désignation
personnelle dorée, séparateurs discrets, détails blancs et dates Small grises.
Les véhicules affichent « Condition » / « État » plutôt qu'un second libellé
générique « Vehicle » / « Véhicule ». L'absence d'une observation de carburant
ou d'état ne produit aucune information inventée.

Les souvenirs d'objets montrent nom/quantité puis date sur une ligne distincte.
Les icônes font 32 px, les noms longs passent à la ligne (UTF-8, y compris CJK)
et les tooltips restent dans les limites de la carte avec un compteur d'entrées
supplémentaires. Aucun nouveau panneau ni dépendance UI n'est ajouté ; le
chemin de rendu est identique avec NeatUI et vanilla.

Les illustrations de catégories remarquables utilisent des textures B42
statiques : `Item_Generator`, `location_shop_fossoil_01_12` (propriété
`fuelAmount`) et `appliances_cooking_01_16` (conteneur `woodstove`,
`IsoFireplace`). Ces noms proviennent des scripts d'items et de
`media/newtiledefinitions.tiles.txt`. Ce sont des illustrations de catégorie,
pas une promesse de modèle/couleur exact pour un objet moddé. Le tooltip ne
relit jamais l'objet distant. Aucune migration, donnée persistée, observation
ou texture copiée dans les assets du mod n'est nécessaire ; une texture absente
laisse le texte lisible.

Les textures passent par `Texture:splitIcon()`, comme les menus vanilla
`ISBBQMenu` / `ISCampingMenu` et les moveables. Cette variante mise en cache
retire les marges du canvas de tuile sans modifier la texture partagée ; la
silhouette remplit ainsi réellement la case d'icône.

`tests/map_tooltip.lua` couvre la hiérarchie, les sauts de ligne Unicode, les
limites de la carte, l'overflow, les icônes bâtiment/extérieur et les données
véhicule inconnues. Le smoke vérifie la résolution réelle des trois textures.
La capture `survivor-memory-tooltip-cards-<backend>.png` utilise la mémoire du
véhicule de test et une fiche de présentation `WOOD_STOVE` non persistée ; elle
ne constitue pas un test de détection d'un poêle dans le monde.

### Ordre de rendu et liaison de sous-sol

Le bytecode local de `UIWorldMap.renderLocalPlayers` dessine un rectangle rouge
de 6×6 pour les joueurs locaux vivants si l'option `Players` est active et si
`WorldMapRenderer.getDisplayZoomF() < 20`. Au-delà, le modèle joueur prend sa
place. En véhicule, le point utilise ses coordonnées. Cette méthode Java est
privée et s'exécute avant l'overlay Lua ; le mod reproduit seulement le point,
avec les mêmes conditions. `UIWorldMapV1.getZoomF()` délègue au zoom affiché
(vérifié dans le bytecode) : il faut cette API Lua, pas accéder au renderer
Java, dont la méthode publique n'est pas pour autant exposée à Lua. Cet accès
direct a échoué lors du premier smoke et a été remplacé. `worldToUIX/Y`,
`getBoolean` et `getNumActivePlayers` complètent le rendu sans écriture dans
les symboles vanilla.

`BasementsV1` permet d'enregistrer des définitions mais ne donne pas de relation
publique fiable bâtiment-parent. `Basements` possède des méthodes privées de
fusion et de recherche du bâtiment : elles ne sont pas invoquées. Les cases
occupées fournissent `getBuilding`, `getX/Y/Z`, `HasStairs`, `HasStairsBelow`.

## Liaison et compatibilité des sauvegardes

`BuildingLinks` n'associe deux clés techniques différentes que si les deux
observations consécutives sont des cases effectivement occupées : différence
d'étage de 1, un étage négatif, distance horizontale Manhattan au plus 2,
preuve d'escalier sur une des cases, sans déplacement en véhicule.

La clé du volume supérieur devient la clé logique. Les bounds restent ceux de
l'identité technique ; aucune découverte de pièce/contenant n'en est déduite.
Un alias est sauvegardé dans le ModData personnel v9. Les pièces du sous-sol
sont re-cléées avec la clé logique pour ne pas être recomptées. Les contenants,
objets sélectionnés et ressources observées suivent la même mémoire.

Les deux historiques pré-fusion sont conservés dans `linkedBuildingHistory`,
notamment pour les conflits d'anciennes désignations. La désignation de surface
prévaut si présente ; sinon celle du sous-sol est reprise. Premier passage :
minimum des dates ; dernier passage : maximum ; compteur historique : maximum
des compteurs, jamais leur somme (les anciens allers-retours d'escalier ont pu
être comptés deux fois). Il est impossible de reconstruire un nombre exact de
sessions historiques sans journal. Les nouvelles traversées liées ne créent
plus de visite. Le statut est recalculé sur l'union des observations connues.

Les alias sont aussi appliqués aux observations locales de conteneurs/items,
aux ressources et à la vérification ciblée du respawn côté serveur. Pas de
table globale, pas de partage entre personnages, pas de nouveau protocole MP.

## Limites intentionnelles

- Pas de fusion par proximité seule, bounds superposés ou contenu chargé.
- Les accès extérieurs sans bâtiment de surface identifié ne sont pas rattachés
  à la maison la plus proche. Les tunnels horizontaux restent indépendants.
- Un accès moddé/téléporteur sans preuve de traversée d'escalier n'est pas lié.
- Les anciennes mémoires attendent une traversée observée pour être liées.
- Une modification des bâtiments par une map mod peut changer les identités
  techniques ; ce travail ne prétend pas résoudre arbitrairement cette migration.

## Validation

`tests/map_building_links.lua` couvre opacité, priorité personnelle, règles du
point joueur, exclusions de passage, fusion des données, archives, save/reload
simulé, cycles d'alias corrompus et absence de double visite. Le raccordement
runtime est également testé avec des doubles Lua ; ce n'est pas un test en jeu.

Le scénario B42 isolé `make smoke` exerce le vrai tooltip d'objet et le point
joueur, puis recherche des cases d'escalier dans la zone vanilla de sous-sol
à 7121,8329, avec fréquence de sous-sols réglée à Always dans le profil de test
uniquement. Il déplace le personnage sur ces cases réelles via le debug,
vérifie la mémoire et le compteur, restaure la mémoire principale du test et
sauvegarde. Ce scénario n'équivaut pas à un parcours manuel de tous les modèles
d'escaliers ou maps moddés.

### Résultats exécutés — 23 septembre 2026

- `make test` : PASS, 340 assertions déterministes (incluant les raccordements
  simulés), sept langues complètes de 167 clés.
- `make validate` et `make build` : PASS ; package runtime identique au dossier
  `42/`, nouveaux modules et sept traductions inclus.
- `make smoke` final : `SMOKE MATRIX PASS variants=2`, code retour 0. Création
  puis rechargement réel B42 avec NeatUI et avec le fallback vanilla.
- Deux identités réellement distinctes dans le fixture :
  `b1:7117:8327:7129:8340:0:1` et `b1:7124:8329:7128:8336:-1:-1`.
  Descente/remontée par déplacement debug sur les cases d'escalier : une seule
  mémoire, une visite. Après reload : un alias, une mémoire canonique et deux
  snapshots conservés (vérifiés sur le ModData désérialisé via l'agent de test).
- L'icône de boîte de clous et le repère du véhicule personnel sont visibles
  dans les captures de tooltip NeatUI/vanilla, inspectées visuellement. Le
  rendu du point rouge utilise bien l'API Lua publique ; son ordre au-dessus
  des marqueurs est aussi couvert par le test simulé du renderer.
- Opacité distante et rayon : tests déterministes et simulés du rendu ;
  réglages enregistrés dans B42. Une appréciation visuelle sur une carte très
  chargée reste une QA manuelle, pas une validation prétendue par ce fixture.
- Aucun nouveau test MP réel pour ce lot. Isolation par personnage et
  transmission sont couvertes par les tests simulés, pas par un serveur dédié.

Preuves locales ignorées par Git : `tests/results/building-console.txt`,
`building-vanilla-ui-console.txt`, `reload-console.txt`,
`reload-vanilla-ui-console.txt` et `screenshots/survivor-memory-item-tooltip-*.png`.
Le premier essai avec l'accès direct au renderer Java a échoué ; le cycle
final a été relancé après correction et après ajout d'un test de régression.

### Lisibilité des tooltips — 23 septembre 2026

- `make test` : PASS, 374 assertions ; sept langues complètes de 169 clés,
  placeholders et encodage validés.
- `make validate` et `make build` : PASS.
- `make smoke` après les derniers ajustements : `SMOKE MATRIX PASS variants=2`,
  code retour 0 ; création/rechargement B42 avec NeatUI et fallback vanilla.
- Les trois textures natives de ressources sont résolues en jeu. Les captures
  `tests/results/screenshots/survivor-memory-tooltip-cards-*.png` ont été
  inspectées visuellement : titre, informations séparées, date et icône de
  poêle. Le poêle de cette capture est un fixture de présentation uniquement,
  pas une preuve de détection d'un poêle dans le monde ni un souvenir persisté.
- `make install` : PASS ; copie locale identique au build. Aucun changement
  d'observation, de persistance ou de protocole MP pour ce lot de présentation.
  Aucun test MP supplémentaire exécuté.
