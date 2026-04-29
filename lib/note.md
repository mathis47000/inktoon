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

1. SearchScreen avec une source v
2. WebtoonDetailScreen v
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

Voici toutes les commandes pour ton projet :

## 🦀 **Rust**

### Tester le code Rust seul

```bash
cd rust

# Tester toutes les fonctions
cargo test

# Tester avec affichage des println!
cargo test -- --nocapture

# Tester une fonction spécifique
cargo test test_search_webtoons -- --nocapture
cargo test test_get_webtoon_episodes -- --nocapture
cargo test test_get_chapter_pages -- --nocapture

# Build
cargo build --release

# Nettoyer
cargo clean
```

### Générer les bindings Flutter

```bash
# Depuis la racine du projet (pas dans rust/)
flutter_rust_bridge_codegen generate \
  --rust-input rust/src/lib.rs \
  --dart-output lib/src/rust/api/simple.dart
```

---

## 📱 **Flutter/Dart**

### Lancer l'app

```bash
# Android
flutter run

# Android en release
flutter run --release

# Choisir un device spécifique
flutter devices  # Liste les appareils
flutter run -d <device_id>

# Hot reload dans le terminal
# Appuie sur 'r' pour reload
# Appuie sur 'R' pour restart
```

### Nettoyer et rebuild

```bash
# Nettoyer Flutter
flutter clean

# Nettoyer Rust
cd rust && cargo clean && cd ..

# Récupérer les dépendances
flutter pub get

# Rebuild complet
flutter clean && flutter pub get && flutter run
```

### Debug

```bash
# Voir les logs en temps réel
flutter logs

# Analyser le code
flutter analyze

# Formater le code
flutter format lib/
```

---

## 🔄 **Workflow complet de développement**

### 1. Modifier le code Rust

```bash
cd rust

# Éditer src/lib.rs
nano src/lib.rs  # ou VS Code

# Tester
cargo test -- --nocapture
```

### 2. Régénérer les bindings

```bash
# Revenir à la racine
cd ..

# Générer
flutter_rust_bridge_codegen generate \
  --rust-input rust/src/lib.rs \
  --dart-output lib/src/rust/api/simple.dart
```

### 3. Lancer Flutter

```bash
flutter run
```

---

## 🚀 **Commandes rapides (aliases)**

Ajoute ça dans ton `~/.bashrc` ou `~/.zshrc` :

```bash
# Aliases Inktoon
alias ink-test='cd rust && cargo test -- --nocapture && cd ..'
alias ink-gen='flutter_rust_bridge_codegen generate --rust-input rust/src/lib.rs --dart-output lib/src/rust/api/simple.dart'
alias ink-run='flutter run'
alias ink-clean='flutter clean && cd rust && cargo clean && cd ..'
alias ink-rebuild='flutter clean && flutter pub get && ink-gen && flutter run'
```

Puis tu peux faire :

```bash
ink-test      # Tester Rust
ink-gen       # Générer bindings
ink-run       # Lancer l'app
ink-rebuild   # Rebuild complet
```

---

## 🐛 **Debug Android via ADB**

```bash
# Voir les logs Android
adb logcat | grep flutter

# Voir les fichiers créés
adb shell
cd /data/data/com.example.inktoon/app_flutter
ls -la

# Copier un fichier vers PC
adb pull /data/data/com.example.inktoon/app_flutter/webtoons/library.json ./

# Installer l'APK
flutter build apk
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📦 **Build Release**

### Android APK

```bash
# Build APK
flutter build apk --release

# APK sera dans:
# build/app/outputs/flutter-apk/app-release.apk

# Installer sur device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (pour Play Store)

```bash
flutter build appbundle --release
# Fichier : build/app/outputs/bundle/release/app-release.aab
```

---

## 🔧 **Troubleshooting**

### Problème de compilation Rust

```bash
cd rust
cargo clean
cargo build --release
cd ..
flutter clean
flutter run
```

### Bindings pas à jour

```bash
# Supprimer et régénérer
rm -rf lib/src/rust/
flutter_rust_bridge_codegen generate \
  --rust-input rust/src/lib.rs \
  --dart-output lib/src/rust/api/simple.dart
```

### Cache Flutter corrompu

```bash
flutter clean
flutter pub cache repair
flutter pub get
flutter run
```

### Erreur OpenSSL (Android)

```bash
# Vérifier Cargo.toml
# Doit avoir : features = ["blocking", "rustls-tls"], default-features = false
cd rust
cargo clean
cd ..
flutter clean
flutter run
```

---

## 📋 **Checklist avant commit**

```bash
# 1. Tester Rust
cd rust && cargo test && cd ..

# 2. Formater Rust
cd rust && cargo fmt && cd ..

# 3. Analyser Flutter
flutter analyze

# 4. Formater Flutter
flutter format lib/

# 5. Vérifier que ça compile
flutter build apk --debug
```

---

## 🎯 **Commande la plus utilisée**

```bash
# Après modification Rust :
cd rust && cargo test -- --nocapture && cd .. && \
flutter_rust_bridge_codegen generate \
  --rust-input rust/src/lib.rs \
  --dart-output lib/src/rust/api/simple.dart && \
flutter run
```

Ou avec l'alias :

```bash
ink-test && ink-gen && ink-run
```

---

Besoin de plus de détails sur une commande spécifique ? 🚀
