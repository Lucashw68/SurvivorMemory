# Contrat — Things Worth Remembering

La V1 sélective est implémentée sans devenir l'ancien projet d'index générique
« Item Memory ». Il n'existe toujours aucun inventaire global ni scan distant.

## Candidats V1

- Generator ;
- Gas Pump ;
- Antique Oven / Wood Stove.

`Well` reste candidat différé : l'audit B42 n'a pas trouvé de propriété
sémantique assez sûre pour le distinguer des autres sources d'eau illimitées.

Le loot ordinaire n'est pas mémorisé automatiquement. Une sélection manuelle
est désormais possible selon le contrat ci-dessous. Les inventaires complets
automatiquement indexés et la recherche globale restent hors périmètre.

## Invariant

Une observation signifie toujours « last seen here », jamais « is currently
here ». Elle est créée ou confirmée uniquement quand le personnage peut
légitimement observer la ressource.

```text
OBSERVED
→ REMEMBERED
→ AGE
→ RE-OBSERVED
    → CONFIRM
    → UPDATE
    → FORGET
```

Si une ressource est constatée absente lors d'un retour réel, une notification
contextuelle unique peut précéder la suppression du souvenir. En cas de doute,
le souvenir est conservé. Aucun changement distant ou invisible ne le met à
jour.

## Contrat runtime v4

Le modèle commun exprime :

- la catégorie remarquable observée ;
- un nom affichable ;
- le lieu de l'observation ;
- la date in-game de dernière observation ;
- une agrégation par catégorie et lieu, sans quantité lorsque celle-ci serait
  trompeuse.

L'oubli automatique reste différé : l'absence d'un représentant ne suffit pas à
prouver l'absence de toute une catégorie agrégée. Voir l'[audit
B42](things-worth-remembering-b42-audit.md) et la
[`roadmap.md`](roadmap.md#things-worth-remembering).

## Souvenirs d'objets sélectionnés — format v8

L'action « Remember selected items here » du menu d'inventaire B42 mémorise
uniquement les objets sélectionnés dans le conteneur de bâtiment affiché dans
le panneau de loot. Le bâtiment doit déjà être connu, le personnage à proximité
et au même niveau. Les inventaires personnels, véhicules, sacs imbriqués et
objets au sol ne sont pas couverts. Les contrôles sont refaits au clic effectif.

Chaque bâtiment conserve `itemMemories`, indexé par identité du conteneur + type
d'objet. Une observation contient `itemType`, `displayName`, `containerKey`,
`quantityObserved`, `textureName` et `observedAt`. La quantité correspond à la
sélection, pas au contenu total du conteneur. Répéter la sélection remplace
l'observation de ce type dans ce conteneur. Un autre conteneur garde un souvenir
distinct. Aucun identifiant d'instance d'item ni référence Java n'est conservé.

Le tooltip carte affiche l'icône observée et « last seen ». Il montre jusqu'à
six observations récentes selon la hauteur disponible, puis le nombre restant.
Un sous-menu au clic droit permet d'oublier chaque observation, même après
déplacement ou destruction du meuble. L'absence d'une texture n'empêche pas
l'affichage du texte. La texture provient du jeu/mod de l'objet, sans copie
d'asset dans Survivor Memory.

Un petit badge bleu « + » en bas à droite du marqueur signale la présence de
souvenirs d'objets à consulter dans le tooltip. Il conserve l'icône du bâtiment,
y compris Home/Outpost, et suit son atténuation à distance. Il couvre les objets
sélectionnés et les ressources importantes selon leurs options actives ; ce
n'est ni une quantité ni une garantie de présence actuelle. L'oubli du dernier
objet retire le badge s'il ne reste aucune ressource importante mémorisée.
L'index des ressources est recalculé seulement lors d'une révision de mémoire,
sans interrogation du monde ni modification des données sauvegardées.

L'option native dépend de Building Memory; désactivation et réactivation
conservent les souvenirs existants. Le stockage utilise exclusivement le
ModData du personnage et son mécanisme de synchronisation existant. Aucune
inspection distante, recherche globale, mise à jour automatique ni changement
du statut de fouille ne résulte d'une sélection d'objet.

### API B42 inspectées

Le Lua local `ISInventoryPaneContextMenu.createMenu` déclenche
`OnFillInventoryObjectContextMenu(player, context, items)`.
`ISInventoryPane.getActualItems` normalise la sélection et déduplique les
éléments de piles (y compris le doublon servant d'en-tête). L'inventaire vanilla
dessine `InventoryItem:getTex()`; `Texture:getName()` fournit la clé stockable
résolue ensuite par `getTexture`. L'overlay utilise `drawTextureScaledAspect`
avec une case de 32 px, quelle que soit l'intégration NeatUI. Le nom et la
quantité forment la ligne principale ; la date d'observation est une ligne
secondaire. Les noms longs sont renvoyés à la ligne sans couper les caractères
UTF-8. La hauteur du tooltip est bornée à la carte, avec un compte d'entrées
supplémentaires lorsque tout ne tient pas.

### Validation

Le test déterministe couvre migration v7→v8→v9, Unicode, quantité sélectionnée,
répétition sans doublon, conteneurs distincts, oubli individuel et données
corrompues. Le test simulé du raccordement runtime vérifie le refus pour un
bâtiment inconnu, un loot fermé/replié, un objet déplacé après ouverture du menu,
un autre étage et un conteneur distant. Il contrôle aussi le nombre de
transmissions du ModData et la conservation des données si l'option est coupée.

Le scénario `make smoke` ajoute une vraie `Base.NailsBox` à un conteneur du
bâtiment de test, sélectionne ce conteneur dans l'UI vanilla de loot et invoque
l'action du menu. Il vérifie l'observation, la résolution de la texture et la
non-duplication. Une capture montre le vrai tooltip de production dans la
World Map; le scénario force uniquement sa position pour la capture.
Les captures sont conservées dans `tests/results/screenshots/` (ignoré par Git),
sous les noms `survivor-memory-item-tooltip-neatui.png` et
`survivor-memory-item-tooltip-vanilla.png`. Le cycle save/reload vérifie ensuite
le type et la texture mémorisés. Une session MP à deux joueurs n'est pas couverte
par ce smoke solo; le raccordement MP est testé de manière simulée.

Validation du 23 septembre 2026 : `make test` PASS (340 assertions au total,
dont les contrôles simulés), `make validate` PASS (7 langues, 167 clés chacune),
`make build` PASS. `make smoke` termine avec `SMOKE MATRIX PASS variants=2` :
création et rechargement B42 avec NeatUI et vanilla réussis. Les deux captures
du tooltip ont été inspectées visuellement. Le scénario épingle explicitement
le panneau de loot pour éviter son repli automatique avant la sélection.

### Badge d'objets sur la carte — 23 septembre 2026

`make test` : PASS, 393 assertions au total ; `make validate`, `make build`
et `make install` : PASS, sept langues de 169 clés. Le test simulé vérifie les
marqueurs ordinaires/Home/Outpost, les options, l'oubli, l'invalidation du cache,
l'atténuation et plusieurs tailles de marqueurs. Aucun changement de format
persisté ou de protocole réseau.

Le premier smoke a échoué sur l'absence du global `next` dans Kahlua, puis a
atteint son timeout. Après correction et ajout de la régression simulée,
le scénario de création NeatUI a réussi, badge compris ; sa capture a été
inspectée. Le cycle complet a ensuite été interrompu par SIGTERM (code 143)
pendant le reload : ce rechargement n'est pas déclaré validé pour ce lot.
Le scénario ciblé `sh tools/run_building_smoke.sh create
/tmp/SurvivorMemory-Smoke-Vanilla vanilla` a ensuite terminé avec
`SMOKE RESULT status=PASS` et code 0 ; badge vérifié, capture vanilla inspectée.
Les deux captures `survivor-memory-item-tooltip-*.png` sont dans les résultats
locaux ignorés. Aucun nouveau test MP exécuté.
