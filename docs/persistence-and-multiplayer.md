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

## Format v1

```lua
SurvivorMemory = {
    schemaVersion = 1,
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
        },
    },
    debug = {},
}
```

Seuls nombres, chaînes, booléens et tables sont stockés. Les migrations passent
par `MemoryStore.migrate`; une version future doit ajouter une étape v1→v2 puis
incrémenter `SCHEMA_VERSION`. Une version inconnue est rejetée par `migrate`;
`forModData` enregistre `SurvivorMemoryRecovery` puis repart sur un store v1
vide afin de ne pas bloquer le chargement du personnage.

## Extension Item Memory

Le découplage des identités et du store permet d'ajouter plus tard une table
`itemObservations` contenant `itemType`, `itemDisplayName`, `quantityObserved`,
`containerIdentity`, `buildingIdentity` et `observedAt`. Elle devra être remplie
uniquement au moment où le container est affiché localement. Une observation
restera volontairement obsolète jusqu'à une nouvelle inspection; aucun scan à
distance ne sera introduit.
