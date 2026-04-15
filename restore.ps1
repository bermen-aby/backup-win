[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# === 0. CHARGEMENT CONFIGURATION ===
$ScriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$MAX_SIZE_GB = 50 # Valeur défaut
$ConfigFile = "$ScriptPath\config.json"
if (Test-Path $ConfigFile) {
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($Config.MaxBackupSizeGB) { $MAX_SIZE_GB = $Config.MaxBackupSizeGB }
        Write-Host "Configuration chargée (Limite : $MAX_SIZE_GB Go)" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Erreur lecture config.json, utilisation valeur défaut ($MAX_SIZE_GB Go)."
    }
}

# === 1. CHOIX DU DOSSIER SOURCE ===
$SourceRoot = $ScriptPath
Write-Host "Dossier actuel : $SourceRoot" -ForegroundColor Gray
$choice = Read-Host "Utiliser ce dossier comme source ? (O/N)"
if ($choice -eq "N") {
    Write-Host "Source actuelle : $SourceRoot" -ForegroundColor Gray
    $changeSrc = Read-Host "Voulez-vous sélectionner un autre dossier de sauvegarde à restaurer ? (O/N)"
    
    if ($changeSrc -eq "O") {
        Add-Type -AssemblyName System.Windows.Forms
        $colordialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $colordialog.Description = "Sélectionnez le dossier contenant les sauvegardes"
        $colordialog.ShowNewFolderButton = $false
        
        if ($colordialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $SourceRoot = $colordialog.SelectedPath
        }
        else {
            $SourceRoot = Read-Host "Aucune sélection. Entrez le chemin complet manuellement"
        }
    }
    else {
        $SourceRoot = Read-Host "Entrez le chemin complet du dossier de sauvegarde"
    }
}

if (-not (Test-Path $SourceRoot)) { Write-Error "Dossier introuvable."; pause; exit }

# === 2. ANALYSE ET TAILLE ===
$MAX_SIZE_BYTES = $MAX_SIZE_GB * 1GB
Write-Host "`nAnalyse du contenu... (Patientez)" -ForegroundColor Gray

$allFiles = Get-ChildItem -Path $SourceRoot -Recurse -File -Exclude "Restore.ps1", "*.bat"
[long]$totalSize = 0
foreach ($f in $allFiles) { $totalSize += $f.Length }
$sizeGB = [Math]::Round($totalSize / 1GB, 2)

if ($totalSize -gt $MAX_SIZE_BYTES) {
    Write-Host "ERREUR : Backup trop lourd ($sizeGB Go)." -ForegroundColor Red; pause; exit
}

# Détection utilisateur
$explorer = Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -First 1
$loggedUser = $explorer.UserName.Split("\")[-1]
$realUserProfile = "C:\Users\$loggedUser"

Write-Host "`nPrêt à restaurer $sizeGB Go pour $loggedUser." -ForegroundColor Cyan
Write-Host "Appuyez sur [ENTRÉE] pour démarrer..." -ForegroundColor Green
$null = Read-Host

# === 3. RESTAURATION FICHIERS ===
$totalFiles = $allFiles.Count
$idx = 0

foreach ($file in $allFiles) {
    if ($file.FullName -like "*\Browsers\*") { continue } # On traite les navigateurs après
    $idx++
    $percent = [int](($idx / $totalFiles) * 100)
    $visualBar = "#" * [int]($percent * 0.4) + "." * (40 - [int]($percent * 0.4))
    Write-Host "`r  Restauration : [$visualBar] $percent% ($idx/$totalFiles)" -NoNewline -ForegroundColor Green

    $targetDir = $file.DirectoryName.Replace($SourceRoot, $realUserProfile)
    robocopy $file.DirectoryName $targetDir $file.Name /R:1 /W:1 /NP /NFL /NDL /NJH /NJS > $null
}

# === 4. RESTAURATION NAVIGATEURS ===
Write-Host "`n`n>>> Restauration des favoris et mots de passe..." -ForegroundColor Yellow
$browserSrc = "$SourceRoot\Browsers"

function Restore-Chromium {
    param($Name, $Path)
    if (Test-Path "$browserSrc\$Name") {
        foreach ($p in (Get-ChildItem "$browserSrc\$Name" -Directory)) {
            $target = "$Path\$($p.Name)"
            if (-not (Test-Path $target)) { New-Item -Path $target -ItemType Directory -Force | Out-Null }
            robocopy "$($p.FullName)" "$target" "Bookmarks" "Login Data" /R:1 /W:1 /NP /NFL /NDL /NJH /NJS > $null
        }
    }
}

Restore-Chromium -Name "Chrome" -Path "$realUserProfile\AppData\Local\Google\Chrome\User Data"
Restore-Chromium -Name "Brave"  -Path "$realUserProfile\AppData\Local\BraveSoftware\Brave-Browser\User Data"
Restore-Chromium -Name "Edge"   -Path "$realUserProfile\AppData\Local\Microsoft\Edge\User Data"

# Firefox
# Nouvelle logique : Restauration complète ou rien
$ffBackup = "$browserSrc\Firefox"
if (Test-Path $ffBackup) {
    Write-Host "Restauration du profil complet Firefox..." -ForegroundColor Yellow
    $ffLocal = "$realUserProfile\AppData\Roaming\Mozilla\Firefox"
    
    # On écrase proprement pour éviter les conflits de profils
    if (Test-Path $ffLocal) {
        Remove-Item $ffLocal -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $ffLocal -ItemType Directory -Force | Out-Null
    
    robocopy "$ffBackup" "$ffLocal" /E /R:1 /W:1 /NP /NFL /NDL /NJH /NJS > $null
}

# === 5. RESTAURATION FOND D'ÉCRAN ===
$wallpaperSrc = "$SourceRoot\Wallpaper"
if (Test-Path $wallpaperSrc) {
    Write-Host "`n>>> Restauration du fond d'écran..." -ForegroundColor Yellow
    $wallpaperFile = Get-ChildItem "$wallpaperSrc\current_wallpaper.*" | Select-Object -First 1
    $settingsFile = "$wallpaperSrc\wallpaper_settings.json"

    if ($wallpaperFile -and (Test-Path $settingsFile)) {
        $destPath = "$realUserProfile\AppData\Local\Microsoft\Windows\Themes\RestoredWallpaper$($wallpaperFile.Extension)"
        if (-not (Test-Path (Split-Path $destPath))) { New-Item -ItemType Directory -Path (Split-Path $destPath) -Force | Out-Null }
        Copy-Item $wallpaperFile.FullName -Destination $destPath -Force

        $settings = Get-Content $settingsFile | ConvertFrom-Json
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value $settings.WallpaperStyle
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value $settings.TileWallpaper
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $destPath

        # Forcer le rafraîchissement immédiat via l'API Windows
        $code = @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        [Wallpaper]::SystemParametersInfo(20, 0, $destPath, 3) | Out-Null
    }
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "RESTAURATION TERMINÉE."
Write-Host "===============================================" -ForegroundColor Green
pause