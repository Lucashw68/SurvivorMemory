# Options natives B42

Audit effectué le 1er septembre 2026 sur Project Zomboid `42.20.4`.

## API retenue

B42 fournit nativement `PZAPI.ModOptions` dans
`media/lua/client/PZAPI/ModOptions.lua`. Une section enregistrée avec
`PZAPI.ModOptions:create` apparaît dans `Options → Mods`. B42 fournit les cases
à cocher, listes, sliders et raccourcis, puis sauvegarde leurs valeurs dans le
fichier personnel `ModOptions.ini`.

Ce stockage est local au profil Project Zomboid : il n'appartient ni au
personnage, ni à une save, ni au serveur. Cela convient à Survivor Memory car
le choix d'utiliser une mémoire personnelle et son affichage ne modifie pas le
monde partagé. En multijoueur, chaque client conserve ses propres préférences.

Le système `sandbox-options.txt` a également été vérifié. Il sert aux règles de
monde et à l'autorité du serveur. Il n'est pas retenu pour cette V1 afin de ne
pas imposer les préférences d'un hôte à tous les souvenirs personnels.

## Sémantique

- toutes les fonctionnalités restent activées par défaut ;
- désactiver une fonctionnalité arrête ses nouvelles observations et masque sa
  présentation dédiée, sans supprimer les données déjà persistées ;
- réactiver une fonctionnalité reprend le tracking normal ;
- les options d'overlay ne modifient que le rendu de la carte ;
- `Places That Matter` et `Emotional Memory` dépendent de Building Memory ;
- `Things Worth Remembering` et `Vehicle Memory` restent indépendants ;
- le changement de backend NeatUI/vanilla nécessite un redémarrage car les
  classes de fenêtre sont choisies au chargement des Lua client.

Le fichier natif n'est normalement chargé qu'à l'ouverture de l'écran Options.
Survivor Memory enregistre donc ses options puis appelle une fois le loader B42
au démarrage afin que les valeurs sauvegardées s'appliquent avant la création
de l'UI.

## Absence d'effacement

Les options ne changent ni le schéma `MemoryStore`, ni le player ModData. Aucun
bouton de suppression n'est exposé. Les souvenirs désactivés restent simplement
en sommeil et peuvent être retrouvés après réactivation.
