# Mémoire des livres et médias récupérés

## Contrat

Un livre, magazine, carte, CD ou VHS est retenu dès qu'il entre dans
l'inventaire du personnage ou un sac qu'il porte. Le mod pose un petit signet
bleu sur les autres exemplaires reconnus dans l'interface d'inventaire et de
loot. Cela signifie **déjà récupéré**, pas **déjà lu** : le témoin de lecture
vanilla reste indépendant. Le signet aide à éviter de rapporter des doublons.

Les titres sont enregistrés par personnage dans `player modData`, format v11.
Une clé versionnée décrit le type complet et, selon le cas, le titre, l'ID de
carte ou l'ID du média. Une nouvelle prise du même titre ne multiplie pas les
entrées. La première heure in-game de collecte est conservée. Le nom affiché
de l'objet et son instance Java ne sont pas persistés.

## Sources d'observation B42

Le chemin `ISInventoryTransferAction.transferItem`/`perform` est enveloppé
pour observer une prise **réellement terminée** vers l'inventaire personnel ou
un sac porté. Une lecture unique de l'inventaire actuellement porté à
l'initialisation permet de reconnaître les objets déjà sur le personnage
quand le mod est activé. Aucun contenant de base, bâtiment ou monde n'est
parcouru. Une réactivation de l'option reprend seulement les observations
locales. Aucun événement distant ne modifie la mémoire.

La clé utilise `InventoryItem:getFullType`, `getMediaData():getId`,
`MapItem:getMapID` et les données de titre disponibles sur les objets de
littérature B42. Un livre de compétence ou une recette à type distinct peut
être reconnu par ce type. Un exemplaire générique dont le titre/ID fiable
manque n'est pas marqué : un faux doublon serait pire qu'une absence de
signet. Les objets moddés suivent les mêmes règles lorsque leurs métadonnées
sont suffisantes.

## Limites et validation

Le mod ne reconstitue pas rétroactivement la bibliothèque déjà déposée dans
une base avant son activation. Il ne prétend pas qu'un exemplaire est toujours
possédé : le signet reflète le fait de l'avoir **déjà ramassé**, même si le
personnage l'a ensuite laissé ailleurs. La mémoire est personnelle en solo
et en MP ; elle n'est pas partagée entre personnages.

Les tests déterministes couvrent identités, doublons, migration v10→v11,
données corrompues, isolement des personnages, transferts simulés, scan porté
et repère UI.

Le 24 septembre 2026, `make smoke` a passé les deux variantes B42 : NeatUI et
fallback vanilla, création puis reload réel (`SMOKE MATRIX PASS variants=2`).
Chaque variante a réellement transféré `Base.BookCarpentry1` depuis un
conteneur vers l'inventaire, reconnu le second exemplaire comme déjà récupéré
et conservé la clé du titre dans le `player modData` après rechargement.
La capture de diagnostic du loot est conservée dans `tests/results/screenshots/` ;
elle contient l'UI debug du smoke et n'est pas un visuel Workshop.
