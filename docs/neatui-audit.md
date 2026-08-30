# Audit NeatUI pour Survivor Memory

Audit effectué le 29 août 2026 avant la refonte de `MemoryPanel`.

## Installation et version

- Workshop ID: `3508537032`.
- Mod ID optionnel: `NeatUI_Framework`.
- Emplacement local: `$HOME/.local/share/Steam/steamapps/workshop/content/108600/3508537032/mods/NeatUI_Framework`.
- Variante retenue: dossier `42/`.
- `modversion=1.0.8`, `versionMin=42.0.2`.
- Le manifeste annonce B42.0.2 à B42.20.2+; l'installation de jeu auditée est
  B42.20.4. Les mods Neat Building et Neat Crafting déclarent cette même
  dépendance et annoncent leur validation B42.20.x.

Survivor Memory ne déclare plus de dépendance dure dans ses `mod.info` et le
framework n'est ni copié ni vendorisé. `UICompat` vérifie s'il est activé : ses
widgets sont utilisés dans ce cas ; sinon une UI vanilla locale assure toutes
les fonctions.

Le fallback n'imite pas le thème NeatUI. Les fenêtres utilisateur et debug
dérivent réellement de `ISCollapsableWindow` et utilisent `Panel_TitleBar`, les
boutons fermer/replier/épingler, le fond, la bordure et le scroll B42 vanilla.
Le smoke test isolé vérifie séparément les backends `NeatUI` et `vanilla`.

## API disponible

NeatUI 1.0.8 est un framework bas niveau, pas un constructeur de fenêtres
complet. Il fournit:

- `NeatTool.NinePatch.draw` et `NeatTool.ThreePatch.drawHorizontal/Vertical`;
- les assets nine-patch `media/ui/NeatUI/DefaultPanel/*`;
- `NI_SquareButton`, bouton carré thémé avec état normal/hover/pressed/active;
- `NIScrollView`, scroll horizontal/vertical fluide avec barres custom;
- `NIVirtualScrollView` et `NIGridVirtualScrollView` pour grandes listes;
- helpers de troncature/rendu numérique;
- compatibilité des helpers de centrage `ISUIElement` entre builds B42.

Il ne fournit pas de label, fenêtre ou tooltip de haut niveau. Les utilisateurs
réels dérivent donc leurs panneaux de `ISPanel`/`ISTableLayout`, puis utilisent
les textures et contrôles NeatUI.

## Usages B42 inspectés

Trois familles installées ont été comparées:

1. **Neat Building**, variante `42/`: panneau `ISTableLayout`, dimensions
   dérivées de `getTextManager():getFontHeight`, `NIScrollView`,
   `NIVirtualScrollView`, `NI_SquareButton`, resize borné à la résolution.
2. **Neat Crafting**, code commun chargé par sa variante B42: panneaux
   `ISPanel`, titres/content via `NinePatchTexture` et assets Neat, scroll views
   horizontales/verticales, 3-patch pour catégories et contrôles.
3. **Modern Status**, variante B42.13: dépendance `NeatUI_Framework`, tailles
   calculées depuis la police et écran, panneaux bornés, scroll custom et
   3-patch pour boutons/champs.

La convention commune est: `new` prépare dimensions/textures, `initialise`
appelle la classe vanilla, `createChildren` instancie les widgets, puis
`addToUIManager`/`setVisible` gèrent l'ouverture. Les panneaux persistants sont
explicitement fermés/retirés; aucune magie de cycle de vie n'est fournie.

## Choix pour Survivor Memory

Le panneau compact utilise:

- `ISPanel` comme conteneur nécessaire au cycle UI PZ;
- les nine-patches NeatUI `MainPanelBG_RoundTop`, `MainTitle_BG`,
  `ContentPanel_BG`, `InnerTitle_BG` pour tout le chrome visible;
- `NI_SquareButton` pour fermer;
- tailles/padding calculés depuis `UIFont.Small` et `UIFont.Medium`;
- position centrée et bornée à l'écran courant;
- tooltip traduit sur le bouton de fermeture.

Il n'utilise pas de scroll: le contenu utilisateur est volontairement borné et
compact. Le panneau debug séparé utilise `NIScrollView`, car les clés et
compteurs peuvent dépasser la hauteur disponible.

## Sizing, thème et scaling

La fenêtre part d'une base compacte de 380 × 300 px mise à l'échelle par la
hauteur de police. Largeur et hauteur sont bornées à 90% de la résolution.
Padding, titres, boutons et interlignes sont tous des multiples de la hauteur de
police, suivant Neat Building/Modern Status. Une résolution ou taille de police
différente entraîne donc un relayout, pas un simple agrandissement bitmap.

Les couleurs sont des teintes appliquées aux textures NeatUI; aucun asset du
framework n'est modifié. Les statuts utilisent uniquement une couleur
d'accentuation, jamais un pourcentage.

## Tooltips et API exactement utilisées

- `NI_SquareButton:new`, `setIconSizeRatio`, propriété `tooltip` héritée;
- `NinePatchTexture.getSharedTexture(...):render(...)` avec les assets NeatUI;
- `NIScrollView:new`, `setScrollDirection`, `setAutoHideScrollbar`,
  `addScrollChild`, `setScrollHeight` dans le panneau debug;
- compatibilité de centrage chargée par la dépendance.

Les chaînes visibles et tooltips viennent exclusivement de `IG_UI.json` EN/FR.
