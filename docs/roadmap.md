# Roadmap

## Fondation livrée

Survivor Memory mémorise par personnage les bâtiments visités, les premières et
dernières visites, les pièces réellement traversées et les contenants réellement
présentés ou inspectés. Le panneau, l'indicateur de statut, l'overlay World Map,
la persistance et le multijoueur sont livrés. NeatUI reste optionnel avec un
fallback vanilla complet.

## Doctrine de design

Survivor Memory doit rester :

- important ;
- observed ;
- personal ;
- possibly outdated ;
- never omniscient.

> Survivor Memory remembers what the survivor has actually experienced, not
> what the game engine currently knows.

Toute proposition doit répondre positivement à ces deux questions :

1. Could the survivor reasonably remember this?
2. Does this still feel like Project Zomboid rather than a separate RPG system?

Une donnée distante actuelle n'est jamais substituée à une observation passée.
Une mémoire peut donc être exacte, vieillissante ou obsolète. Le mod ne doit pas
la corriger à l'insu du personnage.

## Maintenance du produit actuel

- **Livré le 1er septembre 2026 (1.6.0) :** options natives B42 sous
  `Options → Mods`. Chaque module peut être désactivé personnellement sans
  effacer ses souvenirs; filtres de carte, taille des marqueurs, indicateur,
  intensité des réactions, types d'objets, raccourci et préférence NeatUI sont
  configurables. Aucun nouveau panneau de configuration propriétaire.
- **Livré le 1er septembre 2026 (1.5.0) :** Vehicle Memory V1. Les interactions
  significatives entrée, mécanique et sortie mémorisent identité, nom, dernière
  position observée et date in-game. La World Map affiche un glyph de dernière
  position connue; aucun GPS, trajet, télémétrie ou polling de conduite n'est
  introduit. Persistance personnelle v5 et save/reload B42 validés avec NeatUI
  et vanilla.
- **Livré le 31 août 2026 (1.4.0) :** Things Worth Remembering V1 pour les
  générateurs, pompes à essence et poêles à bois réellement observés, avec
  agrégation par lieu, date « last seen », panneau, tooltip/carte et persistance
  personnelle v4. Le puits reste différé faute d'identité B42 non ambiguë.
- **Livré le 31 août 2026 (1.3.0) :** Emotional Memory V1, limitée aux dangers
  exceptionnellement sévères et soutenus, avec réaction panic/stress vanilla
  ponctuelle, vieillissement, habituation et isolation personnelle validée en MP.
- **Livré le 31 août 2026 (1.2.3) :** facteur du marqueur OUTPOST porté à 1,65
  pour compenser sa silhouette plus détaillée; HOME reste à 1,30 et la
  disquette standard à 1,00.
- **Livré le 31 août 2026 (1.2.2) :** clic droit sur un marqueur Survivor
  Memory dans la World Map pour définir directement `HOME`, `OUTPOST` ou
  `NONE`. L'action cible uniquement la mémoire personnelle déjà affichée et ne
  crée aucune annotation vanilla.
- **Livré le 31 août 2026 (1.2.1) :** les marqueurs HOME et OUTPOST utilisent
  un facteur de rendu 1,30 pour compenser leur marge transparente et retrouver
  une emprise visuelle comparable à la disquette standard. Les PNG approuvés et
  la taille du marqueur mémoire restent inchangés.
- **Livré le 31 août 2026 :** correction du rafraîchissement différé du moodle
  lorsqu'une mémoire de bâtiment change de statut. Le chemin événementiel reste
  prioritaire et l'indicateur resynchronise défensivement son statut, sa couleur
  et son tooltip dès la frame UI suivante si sa mémoire partagée a changé sans
  notification. Le smoke B42 NeatUI et vanilla confirme la mise à jour avant
  toute ouverture de la World Map.
- Les filtres d'affichage avancés de l'overlay World Map restent optionnels.

## Places That Matter

**État : V1 implémentée dans Survivor Memory 1.2.0.**

### Intent

Permettre au personnage de donner une importance personnelle à certains lieux
déjà connus. Cette désignation décrit ce que le lieu représente pour le
survivant ; elle ne mesure ni sa sécurité ni son niveau d'exploration.

### Player experience

Depuis la mémoire d'un bâtiment visité, le joueur peut choisir une désignation :

- `HOME` ;
- `OUTPOST` ;
- `NONE`.

Un `HOME` ou un `OUTPOST` peut indépendamment être `VISITED`,
`PARTIALLY_SEARCHED` ou `SEARCHED`. La World Map lui donne une icône propre,
distincte du marqueur mémoire standard. Une courte note personnelle pourra être
évaluée plus tard, sans transformer cette feature en journal complet.

### Rules

- La désignation est entièrement manuelle.
- Elle appartient au personnage et n'est jamais héritée automatiquement.
- Elle n'accorde aucun bonus RPG, niveau ou automatisation de base.
- `NONE` retire la désignation sans supprimer la mémoire du bâtiment.
- Pour un bâtiment normal, le moodle reste visible dans les trois états.
- Pour `HOME` ou `OUTPOST`, le moodle est visible en `VISITED` et
  `PARTIALLY_SEARCHED`, puis masqué en `SEARCHED`.
- Le statut d'exploration reste conservé lorsque le moodle est masqué.

### Constraints

La désignation ne doit déclencher aucun scan, ne doit pas prouver qu'un lieu est
sûr et ne doit pas devenir un système de territoire, de spawn ou de safehouse.
Les icônes de carte ne doivent pas altérer les annotations manuelles vanilla.

### Multiplayer semantics

La désignation reste dans la mémoire du personnage. Deux personnages peuvent
donner des sens différents au même bâtiment. Aucun partage implicite entre
joueurs, personnages ou factions.

### Décisions techniques validées

- L'action manuelle est placée dans le menu contextuel du bâtiment : `HOME`,
  `OUTPOST` ou `NONE`.
- Le format de persistance v2 ajoute `placeDesignation`; la migration v1→v2
  choisit `NONE` sans altérer la mémoire existante.
- L'overlay calculé à la volée remplace visuellement le marqueur standard par
  une icône HOME ou OUTPOST, sans écrire dans les annotations vanilla.
- Le moodle conserve la couleur du statut d'exploration. Il est masqué seulement
  pour un HOME/OUTPOST `SEARCHED`, puis réapparaît si le statut redevient
  incomplet.
- Les désignations restent dans le player ModData et suivent exactement
  l'isolation par personnage existante.

### Implementation phases

1. **Livré :** modèle versionné et règles métier déterministes.
2. **Livré :** action manuelle et présentation dans le panneau mémoire.
3. **Livré :** règle du moodle et tests de transition.
4. **Livré et validé B42/MP :** icônes `HOME` / `OUTPOST` dans l'overlay World Map.
5. **Future optionnelle :** évaluation séparée d'une courte note personnelle.

## Emotional Memory

**État : V1 implémentée dans Survivor Memory 1.3.0.**

### Intent

Permettre au survivant d'associer exceptionnellement un lieu à une expérience
très éprouvante, sans créer un système psychologique parallèle. La mémoire doit
rester rare, compréhensible par le joueur et fidèle aux réactions vanilla.

### Player experience

Une combinaison grave et durable de danger peut laisser une mémoire du lieu.
Lors d'un retour ultérieur, elle provoque au plus une réaction ponctuelle et
modérée de panic ou de stress, puis les systèmes vanilla reprennent entièrement
la main. L'effet vieillit et des retours sans danger habituent progressivement
le personnage. Un nouvel événement grave peut le renforcer.

### Rules

- Un instant isolé de panique ne suffit jamais.
- La création exige un seuil élevé combinant plusieurs signaux observables :
  panique très élevée, durée, danger réel, blessures, santé très basse, douleur
  ou forte présence zombie.
- Aucun score émotionnel n'est affiché au joueur.
- Le retour ne produit qu'une réaction ponctuelle, jamais un effet permanent
  tant que le personnage reste dans le bâtiment.
- L'impact diminue avec le temps et avec les retours ultérieurs sans danger.
- Un événement grave plus récent peut actualiser ou renforcer la mémoire.
- La V1 n'ajoute ni souvenir positif ni buff associé à `HOME`.

### Constraints

Sont explicitement exclus : trauma points, sanity, PTSD system, trauma level,
nouveau moodle, compétence psychologique et sous-système RPG. Seuls panic et
stress vanilla peuvent être sollicités. Le comportement vanilla ne doit pas être
neutralisé ou continuellement forcé.

### Multiplayer semantics

La mémoire émotionnelle est strictement personnelle. L'expérience d'un joueur
n'est jamais copiée vers un autre joueur, même lorsqu'ils se trouvent dans le
même lieu ou vivent le même combat.

### Décisions techniques validées

- Le détecteur lit au plus une fois par seconde les statistiques vanilla déjà
  calculées : panic, stress, douleur, santé, saignements et compteurs zombies
  proches/en poursuite. Il ne parcourt aucun zombie ni aucune zone du monde.
- Un souvenir exige 15 secondes continues avec panic très élevée, danger réel
  et vulnérabilité sérieuse. Un signal faible ou isolé réinitialise la fenêtre.
- Le format personnel v3 conserve seulement `observedAt`, `lastReactionAt` et
  `safeReturns`; aucun score émotionnel ou état distant n'est enregistré.
- Le retour peut ajouter une seule petite impulsion de panic/stress vanilla,
  avec 24 heures de cooldown. Elle décroît avec l'âge et l'habituation.
- Trois retours suffisamment longs et sans danger effacent naturellement le
  souvenir. Un nouvel événement grave le réactualise.
- L'audit d'API et les limites vérifiées sont détaillés dans
  `docs/emotional-memory-b42-audit.md`.

### Implementation phases

1. **Livré :** audit B42 et doctrine sans système psychologique parallèle.
2. **Livré :** détecteur déterministe d'événement exceptionnel et debug séparé.
3. **Livré :** persistance personnelle v3, vieillissement et habituation.
4. **Livré et validé en B42 :** réaction ponctuelle via panic/stress vanilla,
   affichage contextuel et cycle save/reload NeatUI/vanilla.
5. **À poursuivre :** équilibrage manuel dans plusieurs combats réels. Le seuil
   logique est couvert déterministiquement, mais son déclenchement naturel sous
   combat sévère doit encore être observé et ajusté sans l'assouplir arbitrairement.

## Things Worth Remembering

**État : V1 initiale implémentée dans Survivor Memory 1.4.0.**

### Intent

Mémoriser uniquement des découvertes assez remarquables pour qu'un survivant
puisse raisonnablement retenir où il les a vues. La V1 doit rester très
sélective.

### Player experience

Le panneau d'un lieu peut rappeler qu'un générateur, un puits, une pompe à
essence ou un antique oven / wood stove y a été vu, avec l'âge de cette dernière
observation. La formulation est toujours « last seen here », jamais « is
currently here ».

Cycle général :

```text
OBSERVED
→ REMEMBERED
→ AGE
→ RE-OBSERVED
    → CONFIRM
    → UPDATE
    → FORGET
```

Si le personnage revient et peut légitimement constater que la ressource n'est
plus là, une information contextuelle peut être montrée une seule fois, puis le
souvenir utile est supprimé. En cas de doute, le mod n'oublie pas.

### Rules

- Candidats V1 : `Generator`, `Well`, `Gas Pump`, `Antique Oven / Wood Stove`.
- Aucun loot ordinaire n'est indexé : notamment nails, canned food et hammer.
- Aucun inventaire complet de bâtiment et aucun moteur de recherche global.
- Une réobservation confirme ou actualise le lieu et la date.
- Une absence ne supprime la mémoire que si le personnage peut réellement la
  constater.
- « No longer observed here » ne devient pas une entrée persistante.
- Plusieurs éléments identiques dans un même lieu sont agrégés lorsque cela
  produit une mémoire plus utile et crédible qu'une identité technique par item.

### Constraints

Aucun container distant n'est relu, aucun contenu jamais ouvert n'est inspecté
et aucun changement invisible ne met à jour la mémoire. La World Map ne reçoit
pas automatiquement une icône différente pour chaque ressource ; privilégier le
panneau, le tooltip ou un indicateur discret de souvenirs importants.

### Multiplayer semantics

Les observations appartiennent au personnage. Deux joueurs peuvent se souvenir
de ressources différentes dans le même bâtiment et à des dates différentes.
Aucun index partagé ou état mondial de « ressources connues ».

### Décisions techniques validées

- `IsoGenerator`, la propriété de sprite `fuelAmount` et le conteneur
  `woodstove` fournissent des classifications sélectives en B42.
- Une transition réelle vers visible (`isCanSee`) ou la présentation du parent
  dans le loot UI déclenche l'observation. Le menu contextuel ne participe plus
  au tracking.
- Le format v4 agrège par catégorie et bâtiment, ou par zone extérieure de
  10×10 cases. Il stocke une position représentative et `observedAt`.
- Le panneau et le tooltip du bâtiment affichent « last seen ». Une ressource
  extérieure utilise la disquette standard sur l'overlay, jamais une icône par
  type de ressource.
- Le puits n'est pas reconnu par une heuristique d'eau illimitée : les données
  B42 inspectées ne le distinguent pas sûrement des autres sources naturelles.
- L'oubli automatique reste désactivé tant qu'une absence agrégée ne peut pas
  être établie sans faux positif. Une mémoire possiblement obsolète est plus
  honnête qu'une suppression omnisciente.

### Implementation phases

1. **Livré :** audit B42 et contrat commun d'observation remarquable.
2. **Livré et validé en B42 :** générateur réel, vieillissement et réobservation.
3. **Livré statiquement :** pompes à essence et poêles à bois via signaux B42
   sélectifs; fixtures réels supplémentaires encore souhaitables.
4. **Livré :** panneau, tooltip bâtiment et marqueur mémoire extérieur discret.
5. **Future prudente :** identifier les puits sans ambiguïté et concevoir
   l'oubli après absence légitimement constatée.

## Vehicle Memory

**État : V1 implémentée dans Survivor Memory 1.5.0.**

### Intent

Remember where you last saw a vehicle, not where the vehicle is. La mémoire
conserve une dernière observation ; elle ne devient jamais un GPS.

### Player experience

Après une interaction significative, le personnage peut retrouver sur la World
Map la dernière position où il se souvient du véhicule. Le tooltip affiche son
nom et « Last seen X ago ». Le marqueur reste explicitement une observation
possiblement obsolète. L'oubli après constat d'absence est différé jusqu'à
disposer d'un test B42 local et visible sans faux positif.

### Rules

- Déclencheurs V1 livrés : entrer dans un véhicule, demander l'inspection de sa
  mécanique et quitter un véhicule.
- Données minimales : identité stable, nom/type, dernière position observée et
  date de dernière observation.
- La sortie du véhicule est un point de mise à jour important.
- Aucune position enregistrée en continu pendant la conduite.
- Aucun historique de trajet ou de positions.
- Pas de fuel, moteur, batterie, pneus, coffre ou télémétrie exacts en V1.
- Le marqueur indique la dernière position connue, jamais la position distante
  actuelle.

### Constraints

Le mod ne doit jamais interroger un véhicule distant pour corriger la mémoire.
La disparition ne pourra être actée que lors d'un retour permettant une
observation légitime; faute de détection suffisamment sûre, la V1 conserve le
souvenir. Les identifiants et événements Build 41 ne sont pas présumés valides
pour B42.

### Multiplayer semantics

Deux joueurs peuvent conserver des souvenirs différents du même véhicule. Le
serveur ne synchronise jamais automatiquement sa position réelle dans les
mémoires personnelles.

### Technical findings and remaining unknowns

- Le SQL ID B42 est la clé principale; script + mechanical ID est un fallback
  promu sans doublon. Save/reload réel validé.
- `OnEnterVehicle`, `OnExitVehicle` et `ISVehicleMenu.onMechanic` sont les
  points d'observation retenus; le clic mécanique reste à valider manuellement.
- Définir une constatation d'absence raisonnable sans scan de zone étendu.
- Déterminer le comportement des véhicules remorqués, démontés ou remplacés.
- Valider le rendu et la densité des marqueurs sur la World Map.

### Implementation phases

1. **Livré :** audit B42 de l'identité et des événements véhicule.
2. **Livré :** modèle personnel v5 et tests déterministes.
3. **Livré et validé en jeu :** observation entrée/sortie et save/reload.
4. **Livré et validé en jeu :** marqueur de dernière position connue et tooltip.
5. **À suivre prudemment :** oubli après absence localement constatée, cas
   remorque/destruction et validation manuelle du clic mécanique.

## Future / Deferred

### Shared Memories

Le partage explicite de souvenirs reste au parking lot. Il ne fait pas partie du
chantier actuel et ne possède volontairement pas encore de design détaillé.

Notebooks/cartes, oubli configurable et autres extensions restent également à
évaluer après les quatre axes principaux.
