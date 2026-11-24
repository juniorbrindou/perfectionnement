# Illustrations des cartes, une par livre

Chaque carte affiche en haut l'illustration de son livre biblique. Les cartes actuelles couvrent les
20 livres ci-dessous.

**Mode d'emploi.** Colle une demande à la fois dans ChatGPT, dans une nouvelle conversation pour
chaque image. Enregistre l'image obtenue dans `assets/livres/` sous le nom indiqué au-dessus de la
demande. Ce dossier garde les originaux (~4 Mo chacun) : Godot et git l'ignorent.

Ensuite, `pwsh -File tools/livres_images.ps1` en fait des JPG de 1152 × 768 dans
`assets/illustrations/`, ceux que le jeu charge. Leur import Godot doit être en compression
« Lossy » (`compress/mode=1` dans le `.import`), sinon chaque image pèse 1 Mo de plus dans l'APK.

Si une image ne convient pas (texte écrit dedans, cadre, personnage déformé), redemande dans la même
conversation : « Refais-la sans texte ni cadre. »

---

## Ancien Testament

### Genèse → `genese.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : l'arche de Noé posée sur le mont Ararat après le déluge, la colombe revient avec un rameau
d'olivier, un grand arc-en-ciel traverse le ciel qui s'éclaircit, des animaux descendent par paires.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### Exode → `exode.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : Moïse, de dos sur un rocher, lève son bâton ; la mer Rouge s'ouvre en deux immenses murs de
vagues bleues, un chemin de sable sec apparaît au milieu, le peuple d'Israël s'avance au loin.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### Nombres → `nombres.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : le camp d'Israël dans le désert, des tentes à perte de vue, la colonne de nuée lumineuse
au-dessus du tabernacle, Moïse dresse le serpent d'airain sur une perche au premier plan.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### Josué → `josue.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : les murailles de Jéricho s'écroulent dans un nuage de poussière dorée, des prêtres sonnent
du shofar devant l'arche de l'alliance, Josué lève l'épée vers le ciel.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### Juges → `juges.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : Gédéon et ses trois cents hommes sur une colline la nuit, ils brandissent des torches qui
sortent de cruches brisées et sonnent des trompettes, le camp ennemi dans la vallée sous la lune.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée des torches, ciel nocturne bleu profond, profondeur et atmosphère,
personnages bibliques en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune
bordure : l'image remplit tout le format.
```

### Ruth → `ruth.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : Ruth glane des épis dans les champs de blé dorés de Boaz au coucher du soleil, des
moissonneurs au loin, Boaz l'observe avec bienveillance depuis le bord du champ, Bethléem sur la
colline.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel lumineux, profondeur et atmosphère, personnages bibliques en
vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout
le format.
```

### 1 Samuel → `1_samuel.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : le jeune berger David, fronde à la main, fait face au géant Goliath en armure de bronze dans
la vallée d'Éla, les deux armées alignées sur les collines de chaque côté.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### 1 Rois → `1_rois.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : le roi Salomon en habits royaux devant le Temple de Jérusalem tout juste achevé, colonnes de
bronze, or éclatant, une nuée de gloire lumineuse remplit le parvis, le peuple en prière.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### 2 Rois → `2_rois.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : le prophète Élie enlevé au ciel dans un tourbillon par un char de feu tiré par des chevaux
de feu, son manteau tombe vers Élisée qui le regarde depuis la rive du Jourdain.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée et flammes éclatantes, ciel spectaculaire, profondeur et atmosphère,
personnages bibliques en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune
bordure : l'image remplit tout le format.
```

### Esther → `esther.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : la reine Esther, en robe royale, s'avance dans la grande salle du palais de Suse ; le roi
Assuérus, sur son trône, lui tend le sceptre d'or ; colonnes perses, tentures, lumière douce.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, profondeur et atmosphère, personnages bibliques en vêtements
d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout le format.
```

### Daniel → `daniel.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : Daniel, paisible et en prière, dans la fosse aux lions ; les lions sont couchés calmement
autour de lui, un ange lumineux se tient à ses côtés, un rai de lumière tombe d'en haut.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, profondeur et atmosphère, personnages bibliques en vêtements
d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout le format.
```

### Ézéchiel → `ezechiel.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : le prophète Ézéchiel, debout dans une vaste vallée, étend la main ; un souffle de lumière
dorée balaie la vallée et une foule immense se relève, pleine de vie, sous un ciel qui s'ouvre.
Rien d'effrayant : une scène d'espérance et de résurrection.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel lumineux, profondeur et atmosphère, personnages bibliques en
vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout
le format.
```

### Osée → `osee.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : le prophète Osée, à l'aube, ramène tendrement son épouse Gomer par la main à travers les
vignes et les collines d'Israël, symbole de l'amour fidèle de Dieu, un village au loin.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée de l'aube, ciel lumineux, profondeur et atmosphère, personnages
bibliques en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image
remplit tout le format.
```

### Jonas → `jonas.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : sur une mer agitée sous un ciel d'orage qui s'éclaircit, un immense poisson surgit des
vagues, Jonas est déposé sur le rivage ; un bateau de marins au loin, la ville de Ninive à l'horizon.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, mer bleu profond, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

## Nouveau Testament

### Matthieu → `matthieu.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : Jésus enseigne une grande foule assise sur le flanc d'une colline verdoyante au bord du lac
de Galilée (le sermon sur la montagne), fleurs des champs, oiseaux dans le ciel.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel bleu lumineux, profondeur et atmosphère, personnages bibliques
en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit
tout le format.
```

### Marc → `marc.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : Jésus debout dans une barque de pêcheurs, la main levée, calme la tempête sur le lac de
Galilée ; les disciples stupéfaits, les vagues s'apaisent et la lumière perce les nuages.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, profondeur et atmosphère, personnages bibliques en vêtements
d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout le format.
```

### Luc → `luc.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : la nativité à Bethléem, Marie et Joseph près de la crèche où repose l'enfant Jésus, des
bergers arrivent avec leurs moutons, une étoile brillante au-dessus de l'étable, nuit étoilée.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel nocturne bleu profond, profondeur et atmosphère, personnages
bibliques en vêtements d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image
remplit tout le format.
```

### Jean → `jean.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : les noces de Cana, une fête joyeuse dans une cour de maison, Jésus près de grandes jarres
de pierre où l'eau devient du vin, des serviteurs étonnés, guirlandes et lampes.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, profondeur et atmosphère, personnages bibliques en vêtements
d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout le format.
```

### Actes → `actes.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : la Pentecôte, les apôtres et Marie réunis dans une chambre haute de Jérusalem, des langues
de feu se posent sur chacun, un vent puissant fait voler les tentures, lumière éclatante.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, profondeur et atmosphère, personnages bibliques en vêtements
d'époque. Aucun texte, aucune lettre, aucun cadre, aucune bordure : l'image remplit tout le format.
```

### Apocalypse → `apocalypse.png`

```
Illustration peinte pour un jeu de cartes biblique premium, format paysage 1536 × 1024.
Scène : la Jérusalem céleste descend du ciel, une ville d'or translucide aux portes de perles et aux
murailles de pierres précieuses, un fleuve de vie limpide, des arbres de vie, une lumière éclatante.
Style : peinture numérique détaillée façon jeu de cartes à collectionner haut de gamme, couleurs
vives et chaudes, lumière dorée, ciel lumineux, profondeur et atmosphère. Aucun texte, aucune
lettre, aucun cadre, aucune bordure : l'image remplit tout le format.
```
