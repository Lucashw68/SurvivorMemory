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
n'accorde aucun avantage à distance et n'envoie aucun contenu d'item.

## Format v5

```lua
SurvivorMemory = {
    schemaVersion = 5,
    buildings = {
        [buildingKey] = {
            buildingKey = "b1:...",
            firstVisited = 24.0,
            lastVisited = 99.5,
            visitCount = 2,
            roomsKnown = { [roomKey] = observedWorldAgeHours },
            containersKnown = { [containerKey] = observedWorldAgeHours },
            containersInspected = { [containerKey] = lastInspectedWorldAgeHours },
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
version inconnue est rejetée par `migrate`; `forModData` enregistre
`SurvivorMemoryRecovery` puis repart sur un store v5
vide afin de ne pas bloquer le chargement du personnage.

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

## Extensions futures

Les futures extensions restent soumises à la doctrine non omnisciente. Elles ne
doivent jamais reconstruire une connaissance distante actuelle à partir de
l'état du moteur.
