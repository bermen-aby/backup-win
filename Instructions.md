# 📑 Guide d'Utilisation : Système de Sauvegarde & Restauration Automatisé

Ce système professionnel permet la sauvegarde, la gestion et la restauration ultra-rapide de vos données personnelles et profils d'applications.

---

## 🚀 Démarrage Rapide

1.  🟢 **SAUVEGARDER** : Lancez `backup.bat`.
2.  🔵 **RESTAURER** : Lancez `restore.bat` (soit à la racine, soit dans un dossier de sauvegarde).
3.  ⚙️ **GÉRER** : Lancez `manage.bat` pour voir, calculer la taille ou supprimer vos archives.

---

## 📂 Ce qui est sauvegardé

Le script cible intelligemment les données les plus importantes pour une migration ou une sauvegarde complète :

### 1. Dossiers Personnels
*   📁 **Documents**, **Images**, **Vidéos**, **Bureau**, **Téléchargements**.

### 2. Messagerie & Bureautique
*   📧 **Thunderbird** : Sauvegarde complète du profil (emails, comptes, carnets d'adresses).
*   ✉️ **Outlook** : Sauvegarde des **Signatures** (les fichiers `.pst` ne sont pas inclus par défaut car souvent trop lourds, utilisez l'export Outlook pour les mails).

### 3. Navigateurs Web
*   🌐 **Chrome, Edge, Brave** : Sauvegarde des **Favoris** (Bookmarks) et des **Mots de passe** (Login Data).
*   🦊 **Firefox** : Sauvegarde **complète du profil** (extensions, historique, thèmes, mots de passe).

### 4. Personnalisation Windows
*   🖼️ **Fond d'écran** : L'image actuelle et ses réglages de positionnement sont conservés et réappliqués.

---

## ⚙️ Configuration (`config.json`)

Vous pouvez personnaliser le comportement du système en modifiant le fichier `config.json` avec le Bloc-notes. Voici la signification de chaque réglage :

```json
{
    "MaxBackupSizeGB": 50,           // Limite de sécurité en Go. Si vos données dépassent ce seuil, le backup s'arrête.
    "MaxBackupsToKeep": 5,           // Nombre de versions à garder sur votre disque. La plus ancienne est supprimée à la 6ème.
    "PrimaryDestination": "E:\\Sauv", // Votre disque dur externe ou clé USB (utilisez des doubles antislashs \\).
    "FallbackDestination": "C:\\Secours", // Dossier utilisé si votre disque externe n'est pas branché.
    "ProcessCheckList": [            // Liste des logiciels que le script proposera de fermer (pour déverrouiller les fichiers).
        "chrome", "firefox", "msedge", "brave", "outlook", "thunderbird"
    ]
}
```

---

## 🔵 Comment Restaurer ?

### Restauration Totale
Lancez `restore.bat`. Le script détectera l'utilisateur actuel et replacera chaque fichier exactement à sa place d'origine (`C:\Users\VotreNom\...`).

### Restauration Sélective (Manuelle)
Chaque sauvegarde étant un dossier standard, vous pouvez simplement l'ouvrir et copier-coller manuellement un fichier spécifique si vous n'avez pas besoin de tout restaurer.

---

## ✨ Points Forts Techniques

*   🚀 **Multi-threading** : Copie 16 fichiers à la fois pour une vitesse maximale.
*   🛡️ **Auto-vérification** : Teste l'espace disque libre avant de commencer.
*   📝 **Journalisation** : Un fichier `backup.log` est généré pour chaque opération.
*   📦 **Autonomie** : Chaque dossier de sauvegarde contient son propre outil de restauration.

---

## 🛠️ Dépannage

*   **Erreur d'espace** : Si le message "Espace insuffisant" apparaît, utilisez `manage.bat` pour supprimer de vieilles sauvegardes.
*   **Fichiers verrouillés** : Si certains fichiers ne se copient pas, fermez les applications mentionnées dans la console avant de valider.
*   **Accents** : Si vous voyez des caractères bizarres, lancez bien les fichiers `.bat` et non les `.ps1`.
