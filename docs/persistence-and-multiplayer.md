# Persistence, versioning et multijoueur

## Propriété de la mémoire

La mémoire appartient au **personnage** via son `player modData`. Deux
personnages de la même save ne partagent rien automatiquement. Après mort et
création d'un nouveau personnage, la mémoire repart vide; un personnage rechargé
retrouve ses observations.

En MP, le client local observe et met à jour sa mémoire, puis transmet le
`modData` du personnage. Il n'existe ni table globale de connaissances, ni
commande de partage. Un durcissement serveur (validation/rate limiting de
commandes dédiées) pourra être ajouté si le mod devient compétitif, mais le MVP
n'accorde aucun avantage à distance. Seuls les souvenirs d'objets explicitement
sélectionnés sont transmis avec le ModData de leur propriétaire.

## Format v10

```lua
SurvivorMemory = {
    schemaVersion = 10,
    buildingAliases = { [observedBasementKey] = observedSurfaceKey },
    linkedBuildingHistory = { [originalKey] = originalBuildingSnapshot },
    buildings = {
        [buildingKey] = {
            buildingKey = "b1:...",
            firstVisited = 24.0,
            lastVisited = 99.5,
            visitCount = 2,
            roomsKnown = { [roomKey] = observedWorldAgeHours },
            locationKinds = { MEDICAL = true, WAREHOUSE = true },
            containersKnown = { [containerKey] = observedWorldAgeHours },
            containersInspected = { [containerKey] = lastInspectedWorldAgeHours },
            itemMemories = {
                [itemMemoryKey] = {
                    itemType = "Base.NailsBox", displayName = "Box of Nails",
                    containerKey = "c1:...", quantityObserved = 1,
                    textureName = "Item_NailsBox", observedAt = 99.5,
                },
            },
            lootRespawnArmed = { [containerKey] = lastLootedWorldAgeHours },
            searchCompletedAt = 99.5,
            status = "PARTIALLY_SEARCHED",
            centerX = 105,
            centerY = 206,
            identityVersion = 1,
            nativeIdObserved = "...",
            placeDesignation = "HOME", -- NONE, HOME ou OUTPOST
            emotionalMemory = {
                observedAt = 240.0,
                lastReactionAt = 264.0,
                safeReturns = 0,
            },
        },
    },
    importantMemories = {
        ["important:v1:GENERATOR:building:b1:..."] = {
            kind = "GENERATOR",
            placeKey = "building:b1:...",
            buildingKey = "b1:...",
            x = 105, y = 206, z = 0,
            observedAt = 120.0,
        },
    },
    vehicleMemories = {
        ["vehicle:sql:81"] = {
            vehicleKey = "vehicle:sql:81",
            identityKind = "SQL",
            sqlId = 81,
            mechanicalId = 12004,
            scriptName = "Base.CarNormal",
            displayName = "Chevalier Dart",
            x = 350, y = 451, z = 0,
            observedAt = 525.0,
            personal = true,
        },
    },
    debug = {},
}
```

Seuls nombres, chaînes, booléens et tables sont stockés. Les migrations passent
par `MemoryStore.migrate`. La migration v1→v2 ajoute implicitement la
désignation personnelle `NONE`; elle ne modifie ni les observations ni le
statut d'exploration. La migration v2→v3 accepte le champ émotionnel optionnel;
une entrée absente reste absente et une entrée corrompue est supprimée. La
migration v3→v4 ajoute `importantMemories`; une observation invalide est
supprimée sans affecter les bâtiments. La migration v4→v5 ajoute
`vehicleMemories`; une entrée incomplète ou ambiguë est écartée. Une
valeur v5 migre vers v6, qui ajoute la désignation personnelle optionnelle des
véhicules; son absence équivaut à `false`. Une valeur v6 migre vers v7, qui
ajoute le suivi minimal du respawn vanilla. Les
anciens bâtiments `SEARCHED` récupèrent un `searchCompletedAt` déterministe à
partir de leur inspection la plus récente, mais aucun conteneur n'est supposé
avoir été pillé rétroactivement. La migration v7→v8 ajoute `itemMemories` vide
aux bâtiments existants, sans inventer d'observations ni modifier les visites.
La migration v8→v9 initialise `buildingAliases` et `linkedBuildingHistory` sans
lier de bâtiments arbitrairement. Une liaison est créée uniquement après une
traversée locale admissible. Voir [regroupement des sous-sols](map-and-basement-memory.md).
La migration v9→v10 reconstruit `locationKinds` à partir des noms encodés dans
les clés `r1` de `roomsKnown`, sans charger ni rechercher de pièces dans le monde.
L'ancien `locationKind` est conservé comme donnée historique, mais n'est plus
utilisé pour l'affichage : il pouvait être déduit de pièces non explorées.
Sans preuve reconnue, le titre devient « Building ». Les visites, observations,
désignations et identités ne changent pas. Une table v10 manquante est réparée
depuis ces mêmes pièces mémorisées ; une table valide reste l'ensemble des
types découverts. Les alias de sous-sol fusionnent aussi cet ensemble.
Voir [classification des lieux](location-naming-semantics.md).
Une version inconnue est rejetée par `migrate`;
`forModData` enregistre `SurvivorMemoryRecovery` puis repart sur un store v10
vide afin de ne pas bloquer le chargement du personnage.

`lootRespawnArmed` ne stocke ni contenu ni quantité. Il indique seulement qu'un
conteneur naturel connu, situé dans une zone vanilla éligible, a réellement été
pillé par ce personnage. En MP, la confirmation `hasBeenLooted: true → false`
est demandée au serveur uniquement lorsque ce même conteneur apparaît à nouveau
dans l'interface de loot et que le personnage se trouve à proximité.

`placeDesignation` est manuel, personnel au personnage et limité à `NONE`,
`HOME` ou `OUTPOST`. Une valeur absente ou corrompue est ramenée à `NONE`.
`emotionalMemory` reste optionnel et ne contient ni score affiché, ni état
mondial, ni référence Java.

`importantMemories` contient uniquement catégorie, lieu, coordonnées
représentatives et date in-game de dernière observation. Il ne contient aucun
état actuel distant, quantité de carburant ou contenu de container.

`vehicleMemories` conserve la dernière observation significative, jamais la
position courante distante. Le SQL ID B42 est préféré; le couple script +
mechanical ID sert uniquement de fallback et est promu sans doublon lorsqu'un
SQL ID devient disponible.
Le booléen `personal` est une désignation manuelle propre au personnage. Il ne
change ni l'icône, ni les règles d'observation, ni la position mémorisée.

## Extensions futures

Les futures extensions restent soumises à la doctrine non omnisciente. Elles ne
doivent jamais reconstruire une connaissance distante actuelle à partir de
l'état du moteur.
