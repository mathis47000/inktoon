# Architecture de l'application Inktoon

## 📱 Écrans principaux

### 1. **HomeScreen** (Écran d'accueil)
**Navigation : Accueil**
- Liste des webtoons récemment ajoutés/téléchargés
- Accès rapide aux webtoons favoris
- Barre de recherche rapide
- Statistiques : nombre de webtoons sauvegardés, dernière synchronisation
- Boutons d'action rapide : "Nouveau téléchargement", "Synchroniser"

### 2. **SearchScreen** (Recherche et Sources)
**Navigation : Rechercher**
- **Sélection de la source** (Webtoon.com, Tapas, Lezhin, etc.)
  - Liste déroulante ou tabs pour changer de source
  - Icônes pour chaque plateforme
- **Barre de recherche** avec suggestions
- **Résultats de recherche** :
  - Vignette du webtoon
  - Titre, auteur
  - Note/popularité
  - Statut (En cours, Terminé)
  - Bouton "Voir détails"
- **Filtres** :
  - Genre (Romance, Action, Fantaisie, etc.)
  - Statut (En cours, Terminé)
  - Tri (Popularité, Date, Alphabétique)

### 3. **WebtoonDetailScreen** (Détails du Webtoon)
**Navigation : Depuis la recherche**
- **En-tête** :
  - Image de couverture
  - Titre, auteur
  - Note et nombre de chapitres
  - Description/synopsis
  - Tags/genres
- **Sélection des chapitres** :
  - Liste des chapitres disponibles
  - Sélection multiple (checkboxes)
  - Options : "Tous", "Plage" (ex: 1-50), "Derniers X chapitres"
  - Affichage du statut : disponible, déjà téléchargé
- **Bouton d'action** : "Télécharger sélection"
- **Bouton** : "Ajouter aux favoris"

### 4. **DownloadScreen** (Téléchargements)
**Navigation : Téléchargements**
- **File d'attente active** :
  - Liste des téléchargements en cours
  - Barre de progression par webtoon
  - Chapitres téléchargés / Total
  - Vitesse de téléchargement
  - Boutons : Pause, Annuler
- **Téléchargements terminés** :
  - Liste des webtoons complétés
  - Taille du fichier
  - Format (CBZ/EPUB)
  - Date de téléchargement
  - Actions : Ouvrir, Transférer, Supprimer

### 5. **LibraryScreen** (Bibliothèque)
**Navigation : Bibliothèque**
- **Vue grille/liste** des webtoons sauvegardés
- **Affichage** :
  - Couverture, titre
  - Nombre de chapitres
  - Format (badge CBZ/EPUB)
  - Espace occupé
- **Tri et filtres** :
  - Date d'ajout
  - Nom alphabétique
  - Taille
  - Source d'origine
- **Actions par webtoon** :
  - Prévisualiser
  - Transférer vers liseuse
  - Uploader vers drive
  - Supprimer
  - Mettre à jour (vérifier nouveaux chapitres)

### 6. **TransferScreen** (Transfert et Export)
**Navigation : Transfert**
- **Options de transfert** :
  - 📱 **USB/Cable** :
    - Détection automatique de la liseuse
    - Sélection du dossier de destination
    - Liste des webtoons à transférer
  - ☁️ **Cloud Drive** :
    - Connexion Google Drive / Dropbox / OneDrive
    - Sélection du dossier de destination
    - Synchronisation automatique optionnelle
- **Historique des transferts**
- **Configuration du format d'export** :
  - CBZ ou EPUB
  - Qualité d'image (Original, Compressée)
  - Options de métadonnées

### 7. **SettingsScreen** (Paramètres)
**Navigation : Paramètres**
- **Sources** :
  - Activer/désactiver des sources
  - Configurer les credentials si nécessaire
- **Téléchargement** :
  - Dossier de sauvegarde par défaut
  - Nombre de téléchargements simultanés
  - Limite de bande passante
  - Télécharger via WiFi uniquement
- **Format** :
  - Format par défaut (CBZ/EPUB)
  - Qualité d'image
  - Compression
- **Transfert** :
  - Configuration Drive (OAuth)
  - Dossier par défaut sur liseuse
  - Synchronisation automatique
- **Interface** :
  - Thème (Clair/Sombre)
  - Langue
- **Stockage** :
  - Espace utilisé
  - Cache
  - Nettoyer les fichiers temporaires
- **À propos** :
  - Version
  - Crédits
  - Licences

## 🎨 Fonctionnalités supplémentaires suggérées

### Gestion intelligente
- **Auto-update** : Vérifier automatiquement les nouveaux chapitres des webtoons favoris
- **Planification** : Télécharger automatiquement à des heures définies
- **Notifications** : Alertes pour nouveaux chapitres, fin de téléchargement

### Lecture et prévisualisation
- **Lecteur intégré** : Prévisualiser avant transfert (optionnel)
- **Marque-pages** : Se rappeler où on en est dans la lecture

### Organisation
- **Collections personnalisées** : Organiser par genre, statut, etc.
- **Tags personnalisés** : Ajouter ses propres catégories
- **Notes** : Ajouter des commentaires personnels sur les webtoons

### Optimisation
- **Compression intelligente** : Réduire la taille sans perdre en qualité
- **Format adaptatif** : Suggérer CBZ ou EPUB selon le type de contenu
- **Batch processing** : Télécharger plusieurs webtoons en une fois

### Synchronisation
- **Backup cloud** : Sauvegarder la bibliothèque et les paramètres
- **Multi-device** : Synchroniser entre plusieurs appareils
- **Import/Export** : Partager des listes de webtoons

### Social (optionnel)
- **Historique de lecture** : Suivre sa progression
- **Recommandations** : Basées sur les webtoons aimés
- **Partage** : Partager des webtoons avec d'autres utilisateurs

## 📊 Structure de navigation suggérée

```
Bottom Navigation Bar (5 onglets) :
├── 🏠 Accueil (HomeScreen)
├── 🔍 Rechercher (SearchScreen)
├── 📥 Téléchargements (DownloadScreen)
├── 📚 Bibliothèque (LibraryScreen)
└── ⚙️ Paramètres (SettingsScreen)

TransferScreen accessible depuis :
- Bibliothèque (bouton flottant)
- Menu hamburger
- Actions sur un webtoon spécifique
```

## 🎯 Priorisation du développement

### Phase 1 (MVP)
1. SearchScreen avec une source
2. WebtoonDetailScreen
3. DownloadScreen (basique)
4. LibraryScreen
5. SettingsScreen (basique)

### Phase 2
1. TransferScreen (USB)
2. HomeScreen complet
3. Multi-sources
4. Favoris et collections

### Phase 3
1. TransferScreen (Cloud)
2. Auto-update
3. Notifications
4. Fonctionnalités avancées