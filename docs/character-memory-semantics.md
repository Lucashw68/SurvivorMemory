# Mort et nouveau personnage

La mémoire appartient au personnage dans
`IsoPlayer:getModData().SurvivorMemory`, jamais au world modData.

- un personnage rechargé retrouve ses souvenirs;
- le personnage B d'une même save reçoit son modData vide;
- les souvenirs du personnage A mort ne sont pas copiés;
- les désignations `HOME` et `OUTPOST` du personnage A ne sont pas copiées;
- les souvenirs émotionnels du personnage A ne sont pas copiés;
- les ressources remarquables mémorisées par A ne sont pas copiées;
- aucune récupération par compte, username ou save n'est implicite.

Le test déterministe construit deux modData indépendants et vérifie cette
isolation. Le protocole réel manuel est: visiter avec A, mourir, créer B puis
vérifier une première visite neuve. Cette opération destructive n'est pas dans
le smoke quotidien.

En MP, `transmitModData()` synchronise le personnage concerné, y compris ses
désignations et observations remarquables personnelles; aucune table globale ni commande de partage
n'existe.
