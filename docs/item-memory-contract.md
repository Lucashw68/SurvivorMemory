# Contrat — Things Worth Remembering

La V1 sélective est implémentée sans devenir l'ancien projet d'index générique
« Item Memory ». Il n'existe toujours aucun inventaire global ni scan distant.

## Candidats V1

- Generator ;
- Gas Pump ;
- Antique Oven / Wood Stove.

`Well` reste candidat différé : l'audit B42 n'a pas trouvé de propriété
sémantique assez sûre pour le distinguer des autres sources d'eau illimitées.

Le loot ordinaire, les inventaires complets et la recherche globale d'items sont
hors périmètre.

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
