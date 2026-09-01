# Emotional Memory — audit B42

Audit local effectué sur Project Zomboid B42.20.4. Les conclusions ci-dessous
sont limitées aux classes et Lua de cette version.

## Signaux vérifiés

- `Stats:get(CharacterStat.PANIC)` : échelle 0–100, également utilisée par le
  foraging vanilla avec une division par 100.
- `Stats:get(CharacterStat.STRESS)` : échelle normalisée, modifiable avec
  `Stats:add` sans remplacer le système vanilla.
- `Stats:get(CharacterStat.PAIN)` : échelle 0–100.
- `BodyDamage:getHealth()` et `getNumPartsBleeding()` : santé globale et
  blessures observables du personnage.
- `Stats:getNumVeryCloseZombies()`, `getNumChasingZombies()` et
  `IsoPlayer:isTargetedByZombie()` : compteurs déjà calculés par B42. Le mod ne
  parcourt donc ni cellule, ni liste globale de zombies.

## Détection retenue

Un candidat grave exige simultanément : panique ≥ 80, danger réel (ciblé, deux
zombies très proches ou quatre poursuivants) et vulnérabilité (santé ≤ 55,
douleur ≥ 50 ou saignement). Cette combinaison doit persister 15 secondes.
Trois secondes calmes remettent la fenêtre volatile à zéro.

L'échantillonnage est borné à une fois par seconde dans le bâtiment courant. Il
lit seulement des scalaires déjà calculés par le jeu. Il n'effectue aucun scan
du monde et ne sérialise rien tant que le seuil complet n'est pas atteint.

## Réaction et vieillissement

Une réentrée ultérieure peut ajouter une fois une petite quantité aux stats
vanilla PANIC et STRESS. Le cooldown est de 24 heures in-game. L'effet diminue
par tranches d'âge jusqu'à disparaître après 90 jours. Trois retours réellement
calmes font oublier la mémoire. Aucun score, trauma level, nouveau moodle ou
effet continu n'est exposé.

## Autorité et MP

Le client du personnage local observe ses propres stats, écrit son player
ModData et utilise la synchronisation déjà existante. Aucun état émotionnel
global ou partagé n'est créé.
