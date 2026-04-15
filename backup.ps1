##[Ps1 To Exe]
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# === 0. CHARGEMENT CONFIGURATION ===
$ScriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$ConfigFile = "$ScriptPath\config.json"
if (Test-Path $ConfigFile) {
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Host "Configuration chargée depuis config.json" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Erreur lecture config.json, utilisation des valeurs par défaut."
    }
}

# Valeurs par défaut (si config absente)
if (-not $Config) {
    $Config = @{
        MaxBackupSizeGB     = 50
        MaxBackupsToKeep    = 5
        PrimaryDestination  = "E:\Sauvegarde Test"
        FallbackDestination = "C:\Sauvegarde_Secours"
        ProcessCheckList    = @("chrome", "firefox", "msedge", "brave", "outlook")
    }
}

$MAX_SIZE_GB = $Config.MaxBackupSizeGB
$MAX_SIZE_BYTES = $MAX_SIZE_GB * 1GB

# Détection de l'utilisateur réel
$explorer = Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -First 1
$loggedUser = $explorer.UserName.Split("\")[-1]
if (-not $loggedUser) { $loggedUser = $env:USERNAME }
$realUserProfile = "C:\Users\$loggedUser"

$folders = @{
    "Documents"       = "$realUserProfile\Documents"
    "Images"          = "$realUserProfile\Pictures"
    "Videos"          = "$realUserProfile\Videos"
    "Bureau"          = "$realUserProfile\Desktop"
    "Telechargements" = "$realUserProfile\Downloads"
    "Signatures"      = "$realUserProfile\AppData\Roaming\Microsoft\Signatures"
}

# Fonction pour vérifier les processus bloquants
function Test-BlockingProcess {
    param($ProcessNames)
    $running = Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue
    if ($running) {
        Add-Type -AssemblyName System.Windows.Forms
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Les applications suivantes sont ouvertes et bloquent la sauvegarde :`n`n" + ($running.ProcessName -join ", ") + "`n`nVoulez-vous les fermer automatiquement ?",
            "Processus bloquants détectés",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -eq 'Yes') {
            Stop-Process -Name $ProcessNames -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        else {
            Write-Host "ATTENTION : Si ces applications restent ouvertes, les mots de passe ne seront pas copiés." -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    }
}

# Vérification avant analyse (depuis la config)
Test-BlockingProcess -ProcessNames $Config.ProcessCheckList

# === 2. ANALYSE ET TAILLE ===
Write-Host "--- ANALYSE DU SYSTÈME POUR $loggedUser ---" -ForegroundColor Yellow
Write-Host "Calcul de la taille totale... (Patientez)" -ForegroundColor Gray

$allFiles = @()
[long]$totalSize = 0
foreach ($f in $folders.Keys) {
    if (Test-Path $folders[$f]) {
        $files = Get-ChildItem -Path $folders[$f] -Recurse -File -ErrorAction SilentlyContinue
        $allFiles += $files
        foreach ($file in $files) { $totalSize += $file.Length }
    }
}

$sizeGB = [Math]::Round($totalSize / 1GB, 2)
if ($totalSize -gt $MAX_SIZE_BYTES) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("ALERTE : Taille ($sizeGB Go) > Limite ($MAX_SIZE_GB Go).`nSauvegarde annulée.", "Limite Dépassée", 0, 48)
    exit
}

# === 3. CONFIRMATION ===
Write-Host "`nVolume détecté : $sizeGB Go / $MAX_SIZE_GB Go" -ForegroundColor Cyan
Write-Host "Appuyez sur [ENTRÉE] pour démarrer la sauvegarde..." -ForegroundColor Green
$null = Read-Host

# Choix Destination via Config
# Choix Destination via Config
$DefaultDest = if (Test-Path $Config.PrimaryDestination.Split("\")[0]) { $Config.PrimaryDestination } else { $Config.FallbackDestination }

Write-Host "Destination par défaut : $DefaultDest" -ForegroundColor Gray
$changeDest = Read-Host "Voulez-vous modifier le dossier de sauvegarde ? (O/N)"

if ($changeDest -eq "O") {
    Add-Type -AssemblyName System.Windows.Forms
    $colordialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $colordialog.Description = "Sélectionnez le dossier de sauvegarde"
    $colordialog.ShowNewFolderButton = $true
    if ($colordialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $DestinationRoot = $colordialog.SelectedPath
    }
    else {
        Write-Warning "Aucun dossier sélectionné. Utilisation de la destination par défaut."
        $DestinationRoot = $DefaultDest
    }
}
else {
    $DestinationRoot = $DefaultDest
}
$timeStamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$dest = "$DestinationRoot\$timeStamp"

# === 4. COPIE AVEC BARRE PRÉCISE ===
$totalFilesCount = $allFiles.Count
$currentFileIdx = 0

foreach ($file in $allFiles) {
    $currentFileIdx++
    $percent = [int](($currentFileIdx / $totalFilesCount) * 100)
    $visualBar = "#" * [int]($percent * 0.4) + "." * (40 - [int]($percent * 0.4))
    Write-Host "`r  Sauvegarde : [$visualBar] $percent% ($currentFileIdx/$totalFilesCount)" -NoNewline -ForegroundColor Cyan

    $relativePath = $file.DirectoryName.Replace($realUserProfile, "").TrimStart('\')
    $targetDir = Join-Path $dest $relativePath
    robocopy $file.DirectoryName $targetDir $file.Name /R:1 /W:1 /NP /NFL /NDL /NJH /NJS > $null
}

# === 5. NAVIGATEURS (FAVORIS ET PASS) ===
Write-Host "`n`n>>> Sauvegarde des navigateurs..." -ForegroundColor Yellow
$browserDest = "$dest\Browsers"

function Backup-Chromium {
    param($Path, $Name)
    if (Test-Path $Path) {
        $Profiles = Get-ChildItem $Path -Directory -Filter "Default*"
        $Profiles += Get-ChildItem $Path -Directory -Filter "Profile*"
        foreach ($p in $Profiles) {
            $t = "$browserDest\$Name\$($p.Name)"
            robocopy "$($p.FullName)" "$t" "Bookmarks" "Login Data" /R:1 /W:1 /NP /NFL /NDL /NJH /NJS > $null
        }
    }
}

Backup-Chromium -Path "$realUserProfile\AppData\Local\Google\Chrome\User Data" -Name "Chrome"
Backup-Chromium -Path "$realUserProfile\AppData\Local\BraveSoftware\Brave-Browser\User Data" -Name "Brave"
Backup-Chromium -Path "$realUserProfile\AppData\Local\Microsoft\Edge\User Data" -Name "Edge"

# Firefox
$ffPath = "$realUserProfile\AppData\Roaming\Mozilla\Firefox"
if (Test-Path $ffPath) {
    Write-Host "Sauvegarde complète du profil Firefox..." -ForegroundColor Yellow
    # On copie tout le dossier Firefox (Profiles + profiles.ini) pour une restauration parfaite
    # On exclut juste les caches pour gagner de la place
    $ffDest = "$browserDest\Firefox"
    robocopy "$ffPath" "$ffDest" /E /XD "Cache" "Caches" "OfflineCache" "startupCache" /R:1 /W:1 /NP /NFL /NDL /NJH /NJS > $null
}

# === 6. FOND D'ÉCRAN ===
Write-Host "`n>>> Sauvegarde du fond d'écran..." -ForegroundColor Yellow
$wallpaperDest = "$dest\Wallpaper"
if (-not (Test-Path $wallpaperDest)) { New-Item -ItemType Directory -Path $wallpaperDest -Force | Out-Null }

$wallpaperPath = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop').Wallpaper
if (Test-Path $wallpaperPath) {
    $wallpaperExt = [System.IO.Path]::GetExtension($wallpaperPath)
    Copy-Item $wallpaperPath -Destination "$wallpaperDest\current_wallpaper$wallpaperExt" -Force
    
    $wallpaperSettings = @{
        WallpaperStyle = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop').WallpaperStyle
        TileWallpaper  = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop').TileWallpaper
    }
    $wallpaperSettings | ConvertTo-Json | Set-Content -Path "$wallpaperDest\wallpaper_settings.json"
}

# === 7. NETTOYAGE (ROTATION) ===
Write-Host "`n`n>>> Maintenance (Rotation des backups)..." -ForegroundColor Magenta
$toKeep = $Config.MaxBackupsToKeep
$backups = Get-ChildItem -Path $DestinationRoot -Directory | Sort-Object CreationTime -Descending

if ($backups.Count -gt $toKeep) {
    $toDelete = $backups | Select-Object -Skip $toKeep
    foreach ($old in $toDelete) {
        Write-Host "Suppression ancienne sauvegarde : $($old.Name)" -ForegroundColor DarkGray
        Remove-Item $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n===============================================" -ForegroundColor Green
Write-Host "SAUVEGARDE TERMINÉE DANS : $dest"
Write-Host "===============================================" -ForegroundColor Green
pause