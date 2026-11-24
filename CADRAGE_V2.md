# Cadrage de la version 2 — Integrated Photogrammetry Assistant

## Statut et objectif

Ce document guide la conception et le développement de la v2. Il intègre les 30 décisions fonctionnelles et ergonomiques initiales ainsi que les 10 décisions complémentaires relatives au Viewer et à la mise à l'échelle, validées le 24 novembre 2026.

Il intègre également deux axes complémentaires validés le 24 novembre 2026 : la production de documentation scientifique 2D et l'interopérabilité des formats 3D.

## Principes confirmés

- La v2 requiert **macOS 15.2 ou ultérieur**. La recette de compatibilité comprend un essai sur macOS 15.2. Le README de la v2 devra annoncer ce minimum.
- Conserver toutes les fonctionnalités de la version actuelle, y compris celles propres aux ossements, sauf suppression ou réorganisation explicitement validée. Réaliser un inventaire de l'existant avant toute transformation et vérifier l'absence de régression.
- Supprimer entièrement le Viewer externe et intégrer les fonctions de visualisation, de mesure, de calibration manuelle et d'orientation dans le Viewer propre à IPA.
- Employer un vocabulaire générique pour le matériel archéologique dans l'interface commune.
- Concevoir le parcours autour d'un seul objet à la fois, pour des scans ponctuels, sans imposer une organisation en projets ni une structure stricte de dossiers.
- Proposer un parcours de référence étape par étape, tout en laissant l'utilisateur naviguer librement entre les étapes disponibles.
- Regrouper tous les outils spécifiques et facultatifs des sections File Management et Dataset Preparation dans une section Tools indépendante.
- Supprimer le logo en bas à gauche de l'interface.

## Navigation, interface et sessions

- Adopter une interface macOS native et minimaliste.
- Placer la navigation principale dans une barre horizontale supérieure.
- Laisser les étapes librement accessibles dès que leurs prérequis sont satisfaits. Griser les étapes indisponibles faute de données.
- Exiger une validation manuelle pour le passage à l'étape suivante, sauf après une reconstruction réussie : le modèle est alors ouvert automatiquement dans le Viewer.
- Utiliser une session de travail temporaire, sans sauvegarde ni restauration de session après la fermeture d'IPA. Les fichiers explicitement enregistrés restent disponibles sur le disque.
- Distinguer les préférences persistantes de la session temporaire : les derniers seuils d'analyse des photos et les derniers paramètres de reconstruction sont mémorisés.

## Parcours principal

1. Import des photos.
2. Revue et sélection des photos.
3. Paramétrage et reconstruction photogrammétrique.
4. Visualisation 3D (Viewer), avec mise à l'échelle manuelle et orientation intégrées.
5. Mise à l'échelle automatique (alternative facultative à la calibration manuelle du Viewer).

### 1. Import des photos

- Permettre l'import par glisser-déposer ou sélection d'un dossier.
- Utiliser les fichiers originaux à leur emplacement, sans les déplacer ni les copier dans un dossier de travail obligatoire.
- Permettre l'ajout de photos à tout moment de la session, y compris après une première reconstruction.

### 2. Revue et sélection des photos

- Présenter les photos dans une grille de miniatures permettant leur sélection et leur désélection manuelles.
- Afficher en permanence le nombre de photos sélectionnées par rapport au nombre total de photos importées.
- Détecter automatiquement trois types de défauts : flou, saturation des hautes lumières et saturation des basses lumières. Aucun autre critère de qualité n'est demandé pour la v2.
- Lancer automatiquement l'analyse en arrière-plan à l'importation des photos et permettre de la relancer manuellement après modification des seuils.
- Proposer un curseur de tolérance indépendant pour chacun des trois critères.
- Signaler les défauts détectés par des indicateurs directement sur les miniatures.
- Proposer une désélection automatique configurable des photos problématiques. L'utilisateur conserve la possibilité de modifier la sélection manuellement.
- Mémoriser les derniers seuils utilisés entre les sessions.

### 3. Reconstruction photogrammétrique

- Conserver toutes les options actuellement présentes dans le module Photogrammetry et les afficher sans les masquer dans une section avancée.
- Initialiser les paramètres avec les dernières valeurs utilisées.
- Reconstruire le modèle à partir des seules photos sélectionnées.
- Laisser l'utilisateur choisir manuellement l'emplacement d'enregistrement des modèles générés.
- Afficher la progression, le statut et un journal technique détaillé pendant la reconstruction.
- Ouvrir automatiquement le modèle dans le Viewer après une reconstruction réussie.

### 4. Visualisation 3D (Viewer)

- Utiliser exclusivement le Viewer intégré à IPA, sans recours à un Viewer externe.
- Permettre la navigation et l'inspection 3D, les mesures de distances, la mise à l'échelle manuelle et la modification de l'orientation du modèle.
- Proposer quatre modes de visualisation : texture, surface unie, maillage filaire et texture avec maillage filaire.
- Permettre d'ouvrir directement un modèle 3D externe sans importer de photos ni lancer de reconstruction.
- Afficher explicitement le statut de calibration du modèle.
- Proposer un mode d'édition dédié à la mise à l'échelle manuelle au sein du Viewer, sans interface OBJ Scaling séparée.
- Permettre de modifier l'orientation réelle du modèle par rotation libre interactive ou par rotation précise autour des axes X, Y et Z, indépendamment de la navigation de la caméra.
- Lors de l'enregistrement des modifications d'échelle ou d'orientation, demander si l'utilisateur souhaite remplacer le fichier existant ou créer une nouvelle version.

### 5. Mise à l'échelle

- Proposer deux méthodes alternatives : la calibration manuelle intégrée au Viewer et la calibration automatique (Auto Scale). Elles ne constituent pas deux opérations successives obligatoires.
- En mode de calibration manuelle, sélectionner deux points sur la surface du modèle 3D et saisir la distance réelle correspondante en centimètres.
- Accepter une seule distance de référence ou plusieurs distances ; dans ce dernier cas, appliquer la moyenne des facteurs d'échelle individuels.
- Appliquer immédiatement la calibration manuelle au modèle dans le Viewer, avec possibilité d'annuler la modification avant son enregistrement.
- Autoriser la recalibration manuelle d'un modèle déjà calibré automatiquement, après avertissement explicite.
- Pour la méthode automatique, afficher le facteur calculé et demander confirmation avant son application.
- Utiliser exclusivement le centimètre (cm) pour les mesures et les dimensions réelles saisies ou affichées.
- Lors de l'enregistrement, demander si l'utilisateur souhaite créer une nouvelle version ou remplacer le modèle existant.
- Après une calibration, actualiser automatiquement le modèle affiché dans le Viewer et son statut de calibration.
- Ne pas générer de rapport ni conserver de trace persistante spécifique à la mise à l'échelle.

## Production de documentation scientifique 2D

- Permettre de produire des documents scientifiques bidimensionnels à partir du modèle 3D chargé dans le Viewer, qu'il ait été reconstruit dans IPA ou importé.
- Proposer la génération de vues orthographiques, de planches multivues, de coupes et profils, ainsi que de silhouettes.
- Permettre d'ajouter une échelle graphique exprimée en centimètres lorsque le modèle est calibré. Ne pas présenter de dimensions réelles pour un modèle non calibré.
- Permettre l'export des documents produits pour leur utilisation dans des publications scientifiques, sans modifier le modèle 3D source.
- Rendre ces opérations facultatives, sans imposer d'étape supplémentaire dans le parcours principal.

## Interopérabilité des formats 3D

- Développer une couche commune d'importation, de conversion et d'exportation des modèles 3D, indépendante du moteur de reconstruction.
- Prendre en charge les formats suivants, en fonction de leurs caractéristiques et usages :

| Format | Usage privilégié |
| --- | --- |
| OBJ | Échange de modèles texturés |
| GLB / glTF | Diffusion web |
| PLY | Analyses géométriques |
| STL | Impression 3D |
| USDZ | Réalité augmentée |
| 3MF | Fabrication additive |

- Préserver la géométrie, les textures, les matériaux, l'échelle et l'orientation lors des conversions, dans les limites des capacités de chaque format.
- Vérifier les conversions et signaler explicitement les informations susceptibles d'être perdues ou altérées, notamment les textures et les unités. Respecter la convention de mesure en centimètres dans l'interface, en tenant compte des conventions propres aux formats de fichiers.
- Permettre l'enregistrement des modèles convertis à un emplacement choisi par l'utilisateur, sans modification implicite des fichiers sources.

## Section Tools

- Présenter tous les outils existants de File Management et Dataset Preparation dans une liste unique, sans subdivision imposée par ces anciennes catégories.
- Conserver les fonctionnalités spécialisées pour les ossements et la préparation des jeux de données.
- Rendre les outils accessibles indépendamment du parcours principal, même en l'absence de photos importées ou de modèle chargé.
- Lorsque des fichiers pertinents sont disponibles dans la session en cours, les proposer automatiquement aux outils concernés. L'utilisateur peut modifier cette sélection.
- Ajouter un outil spécifique et facultatif de génération et d'impression de repères QR code compatibles avec la mise à l'échelle automatique (Auto Scale). Permettre de produire des planches imprimables respectant les dimensions physiques attendues par l'algorithme de calibration, avec des consignes d'impression à taille réelle (100 %, sans ajustement automatique). Cet outil doit être accessible indépendamment du parcours principal, notamment avant l'acquisition des photos.

## Vérification du développement

- Inventorier les fonctionnalités existantes avant la refonte et vérifier leur maintien, sous réserve des changements explicitement validés dans ce document.
- Tester le parcours complet ainsi que l'accès indépendant au Viewer et aux outils complémentaires.
- Vérifier la compatibilité des repères QR code imprimés avec Auto Scale et l'exactitude de leurs dimensions physiques après impression à taille réelle.
- Vérifier que le Viewer fonctionne sans application externe, que la calibration manuelle accepte une ou plusieurs références, que l'annulation et la recalibration fonctionnent, et que les deux modes d'orientation et les deux options d'enregistrement sont opérationnels.
- Vérifier la production et l'export des documents scientifiques 2D, notamment l'exactitude des échelles graphiques sur les modèles calibrés.
- Tester l'importation, la conversion et l'exportation des formats 3D pris en charge, la conservation des attributs compatibles et les avertissements en cas de perte d'information.
- Vérifier la distinction entre les données temporaires de session, les préférences persistantes et les fichiers enregistrés par l'utilisateur.
- Vérifier la compatibilité sur macOS 15.2 et la mise à jour du README.

