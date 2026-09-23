# Classification des lieux observés

Le titre décrit les usages reconnus des pièces réellement traversées, pas un
nom commercial officiel, ni une séparation garantie entre commerces mitoyens.
Une même mémoire peut afficher « Medical building / Warehouse ». Les labels
restent distincts, triés par identifiant de catégorie pour un ordre stable, et
traduits avec les clés natives existantes dans les sept langues.

## Règles

- Seul `room:getRoomDef():getName()` de la pièce occupée est consulté.
- Les cuisines, salles de bains, salles à manger et placards ne classent pas
  un bâtiment comme maison. Une chambre ou un salon reste un indice résidentiel.
- Les noms reconnus comme `medical`/`pharmacy`, `warehouse`, `office`, etc.
  ajoutent leur catégorie, sans écraser celles déjà découvertes.
- Une pièce inconnue ne donne aucun label ; sans label reconnu : « Building ».
- Aucun appel à `BuildingDef:isResidential()` ou `isShop()`, ni lecture des
  couleurs de la World Map. Aucun inventaire de pièces distantes.
- Home/Outpost, statut de fouille et compteur de visites restent indépendants.
- L'observation est raccordée aux entrées/reprises et découvertes de rooms
  existantes. Pas de nouveau polling. Les labels suivent les changements de
  pièce même si le comptage détaillé des rooms est désactivé ; cela ne réactive
  pas `roomsKnown` ni le suivi de progression des pièces.
- Une découverte ajoute au plus une catégorie et utilise la synchronisation
  personnelle existante. Pas de table globale ou de partage automatique MP.

Les noms de pièces `bedroom`, `livingroom`, `medical`, `office`, `pharmacy` et
`warehouse` sont présents dans le `Distributions.lua` de l'installation B42
locale. La classification reste une heuristique : les maps moddés peuvent
utiliser d'autres noms ; un bureau peut être une annexe d'une clinique et non
un établissement indépendant. Ne pas transformer les labels en prétendus
identifiants de commerces.

## Sauvegardes et rendu

Le format v10 conserve un ensemble `locationKinds`. La migration reconstruit
les labels depuis les clés de pièces déjà enregistrées (`r1`, longueurs
encodées vérifiées, clé du bâtiment correspondante). Elle ignore les identités
malformées, les noms inconnus et les anciennes déductions non justifiées.
Sans historique de room exploitable, le joueur retrouve les labels lors de
ses prochains passages. Aucun souvenir de loot ou de visite n'est supprimé.

Le panneau, le tooltip carte et l'indicateur utilisent le même formateur.
Le tooltip carte renvoie déjà les titres longs à la ligne. Le panneau utilise
le même découpage UTF-8 et adapte sa hauteur au contenu, dans la limite de
l'écran, avec NeatUI comme avec le fallback vanilla.

## Validation

`tests/location_names.lua` couvre la classification progressive, l'ordre,
la déduplication, les pièces ambiguës, migration v9→v10, reload simulé,
données partielles, noms Unicode, fusion de sous-sol, isolation et raccordement
runtime simulé. Les doubles lèvent une erreur si le code consulte les
propriétés globales du bâtiment. La simulation vérifie aussi transmission MP,
notification UI et absence de transmission stationnaire.

Le smoke B42 compare les labels aux deux pièces réellement parcourues dans
le fixture puis contrôle leur persistance au reload. Il ne constitue pas une
validation de tous les bâtiments mixtes vanilla ou moddés, ni un test MP réel.

Exécution du 23 septembre 2026 : `make test` PASS (441 assertions),
`make validate` et `make build` PASS. `make smoke` PASS
(`SMOKE MATRIX PASS variants=2`), quatre cycles création/reload en jeu entre
NeatUI et vanilla. `make install` PASS ; le dossier local est byte-for-byte
identique au package. Les 7 langues possèdent toujours 169 clés. Les tests MP
réels ne faisaient pas partie de ce changement.
