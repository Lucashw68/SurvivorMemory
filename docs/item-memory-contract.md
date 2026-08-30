# Contrat futur Item Memory (MVP+2)

Documentation uniquement; aucun index ou scan n'est implémenté.

```lua
ItemMemoryObservation = {
    itemType = "Base.PropaneTorch",
    itemDisplayName = "Propane Torch",
    quantityObserved = 1,
    containerIdentity = "c1:...",
    buildingIdentity = "b1:...",
    observedAt = 432.5,
}
```

Une observation ne sera créée que lorsque le contenu est montré au personnage.
Elle pourra devenir obsolète sans mise à jour distante. Aucun index global de
l'état actuel des containers n'est autorisé.
