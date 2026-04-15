# 📑 Guide d'Utilisation : Système de Sauvegarde & Restauration Automatisé

Ce système professionnel, basé sur PowerShell et Robocopy, permet la sauvegarde et la restauration rapide et sécurisée de vos données personnelles et profils de navigateurs.

---

## 🚀 Démarrage Rapide

**Double-cliquez simplement sur le fichier `.bat` correspondant à votre besoin :**

1.  🟢 **Pour SAUVEGARDER** : Lancez `backup.bat`
2.  🔵 **Pour RESTAURER** : Lancez `restore.bat`

> [!IMPORTANT]
> Utilisez toujours les fichiers **.bat**. N'exécutez pas directement les fichiers `.ps1`, car les `.bat` gèrent automatiquement les droits administrateur et les problèmes d'affichage des accents.

---

## 🆕 Nouveautés (Mise à jour)

*   **Sélection de Dossier Interactive** : Plus besoin de modifier les scripts manuellement !
    *   Lors de la sauvegarde, vous pouvez choisir **n'importe quel dossier ou disque** comme destination via une fenêtre de dialogue.
    *   Lors de la restauration, vous pouvez naviguer pour sélectionner exactement le dossier contenant vos sauvegardes.
*   **Support des Accents** : Les scripts affichent désormais correctement les caractères accentués (`é`, `à`, `ê`) dans la console.
*   **Configuration Centralisée** : Un fichier `config.json` permet de régler les paramètres sans toucher au code.

---

## ⚙️ Fonctionnement Détaillé

### 1. Sauvegarde (`backup.bat`)

Le script effectue les actions suivantes :
1.  **Vérification des Processus** : Détecte si vos navigateurs (Chrome, Firefox, Edge, etc.) ou Outlook sont ouverts et propose de les fermer pour garantir la sauvegarde des fichiers verrouillés (mots de passe, emails).
2.  **Calcul de Taille** : Estime le volume total des données. Si la taille dépasse la limite configurée (50 Go par défaut), la sauvegarde est annulée par sécurité.
3.  **Choix de la Destination** :
    *   Utilise par défaut le chemin défini dans la configuration.
    *   Vous propose de **choisir un autre dossier** via une fenêtre explorateur si vous le souhaitez.
4.  **Copie Robuste** : Utilise *Robocopy* avec une barre de progression visuelle pour copier :
    *   📂- **Documents, Images, Vidéos, Bureau, Téléchargements**.
- **Signatures Outlook**.
- **Navigateurs** (Favoris et mots de passe pour Chrome, Brave, Edge, Firefox).
- **Fond d'écran Windows** (Image et positionnement).
- **Maintenance automatique** (Garde les 5 dernières sauvegardes). les plus anciennes pour n'en garder que les X dernières (5 par défaut).
5.  **Rotation (Nettoyage)** : Supprime automatiquement les sauvegardes les plus anciennes pour n'en garder que les X dernières (5 par défaut).

### 2. Restauration (`restore.bat`)

Le script restaure vos données intelligemment :
1.  **Choix de la Source** :
    *   Détecte automatiquement si le script est lancé depuis un dossier de sauvegarde.
    *   Sinon, vous permet de **parcourir vos disques** pour sélectionner le dossier source.
2.  **Réinjection des Données** : Replace les fichiers exactement là où ils doivent être (`C:\Users\VotreNom\...`).
3.  **Restauration des Navigateurs** :
    *   Réinjecte les favoris et mots de passe.
    *   Pour **Firefox**, restaure le profil complet (extensions, historique, etc.).

---

## 🔧 Configuration (`config.json`)

Vous pouvez personnaliser le comportement du système en modifiant le fichier `config.json` avec le Bloc-notes :

```json
{
    "MaxBackupSizeGB": 50,           // Limite de taille en Go (sécurité)
    "MaxBackupsToKeep": 5,           // Nombre de versions à conserver
    "PrimaryDestination": "E:\\Sauv", // Dossier par défaut (disque externe)
    "FallbackDestination": "C:\\Secours", // Dossier de secours
    "ProcessCheckList": [            // Logiciels à fermer avant sauvegarde
        "chrome", "firefox", "outlook"
    ]
}
```

---

## 📂 Structure Recommandée

Pour une organisation optimale sur votre disque externe :

```text
📁 E:\Mes Sauvegardes\
 ┣ 📁 2024-01-28_14-00-00\     <-- Dossier créé par le script
 ┃  ┣ 📁 Browsers              <-- Données navigateurs
 ┃  ┣ 📁 Documents             <-- Vos fichiers
 ┃  ┣ ...
 ┃  ┣ 📜 Restore.ps1           <-- Copié automatiquement ici
 ┃  ┗ ⚙️ restore.bat           <-- Copié automatiquement ici
```