# Mort et nouveau personnage

La mémoire appartient au personnage dans
`IsoPlayer:getModData().SurvivorMemory`, jamais au world modData.

- un personnage rechargé retrouve ses souvenirs;
- le personnage B d'une même save reçoit son modData vide;
- les souvenirs du personnage A mort ne sont pas copiés;
- aucune récupération par compte, username ou save n'est implicite.

Le test déterministe construit deux modData indépendants et vérifie cette
isolation. Le protocole réel manuel est: visiter avec A, mourir, créer B puis
vérifier une première visite neuve. Cette opération destructive n'est pas dans
le smoke quotidien.

En MP, `transmitModData()` synchronise le personnage concerné; aucune table
globale ni commande de partage n'existe.
