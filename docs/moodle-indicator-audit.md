# Audit de l'indicateur « moodle » — B42.20.4

## Conclusion

Survivor Memory utilise un moodle autonome placé dans le prochain emplacement
visuel de la pile vanilla. Le bouton emploie NeatUI lorsque ce framework est
activé et son équivalent vanilla sinon. Il ne modifie aucune donnée privée du
jeu et n'ajoute pas Moodle Framework comme dépendance.

## Pourquoi ce n'est pas un `MoodleType` vanilla

L'inspection de `projectzomboid.jar` montre que `MoodleType.register(String)`
et le registre `Registries.MOODLE_TYPE` sont extensibles. L'extension s'arrête
cependant là :

- `Moodle.Update()` calcule uniquement les types vanilla codés en dur ;
- le niveau est privé et ne possède pas de setter public ;
- `MoodleTextureSet` associe explicitement les textures aux types vanilla ;
- `MoodlesUI`, classe `final`, ne fournit aucune méthode publique d'ajout de
  moodle ou de texture.

Une injection réelle demanderait donc de modifier des maps/champs privés ou de
remplacer l'UI vanilla. Cette solution serait fragile lors des mises à jour.

## Alternative écartée : Moodle Framework

Le framework fournit sa propre pile Lua et rend possible l'apparence d'un
moodle personnalisé. Il ajouterait toutefois une deuxième dépendance UI, des
interactions avec les remplacements de moodles et une surface de risque MP.
Survivor Memory reste autonome vis-à-vis de ce framework.

## Intégration retenue

- composant `NI_SquareButton` NeatUI avec rendu spécialisé ;
- fond et contour visuels vanilla chargés selon la taille configurée (32 à
  128 pixels, y compris le mode lié à la taille de police) ;
- icône mémoire propre à Survivor Memory ;
- rouge pour `VISITED`, orange pour `PARTIALLY_SEARCHED`, vert pour `SEARCHED` ;
- placement après les moodles vanilla actuellement visibles ;
- tooltip localisé : lieu mémorisé, statut, visites et dernière visite ;
- clic ouvrant le panneau NeatUI ;
- disparition à la sortie du bâtiment.

Le comptage des moodles visibles sert uniquement au placement. Il est limité à
quatre vérifications par seconde et ne consulte ni bâtiment, ni room, ni
container. Aucune information de jeu supplémentaire n'est persistée ou révélée.
