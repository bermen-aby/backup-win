##[Ps1 To Exe]
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# === 0. CHARGEMENT CONFIGURATION ===
$ScriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$ConfigFile = "$ScriptPath\config.json"

$explorer = Get-Process explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -First 1
$loggedUser = $explorer.UserName.Split("\")[-1]
if (-not $loggedUser) { $loggedUser = $env:USERNAME }
$realUserProfile = "C:\Users\$loggedUser"

function Save-Config { param($ConfigObj) $ConfigObj | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Force }
function Load-Config {
    if (Test-Path $ConfigFile) {
        try { return Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch { return $null }
    }; return $null
}

$DefaultFolders = [ordered]@{
    "Documents"       = @{ Path = "$realUserProfile\Documents"; Enabled = $true }
    "Images"          = @{ Path = "$realUserProfile\Pictures"; Enabled = $true }
    "Videos"          = @{ Path = "$realUserProfile\Videos"; Enabled = $true }
    "Bureau"          = @{ Path = "$realUserProfile\Desktop"; Enabled = $true }
    "Telechargements" = @{ Path = "$realUserProfile\Downloads"; Enabled = $true }
    "Signatures"      = @{ Path = "$realUserProfile\AppData\Roaming\Microsoft\Signatures"; Enabled = $true }
}

$Config = Load-Config
if (-not $Config) {
    $Config = [PSCustomObject]@{
        MaxBackupSizeGB     = 50
        MaxBackupsToKeep    = 5
        PrimaryDestination  = "E:\Sauvegarde Test"
        FallbackDestination = "C:\Sauvegarde_Secours"
        ProcessCheckList    = @("chrome", "firefox", "msedge", "brave", "outlook", "thunderbird")
        SourceFolders       = $DefaultFolders
    }
    Save-Config $Config
}

# Nettoyage des dossiers (migration vers Hashtable propre)
$cleanFolders = [ordered]@{}
foreach ($p in $Config.SourceFolders.PSObject.Properties) {
    if ($p.Name -match "Count|Keys|Values|SyncRoot|IsReadOnly|IsFixedSize|IsSynchronized") { continue }
    if ($p.Value -is [string]) { $cleanFolders[$p.Name] = [PSCustomObject]@{ Path = $p.Value; Enabled = $true } }
    else { $cleanFolders[$p.Name] = $p.Value }
}
if ($cleanFolders.Count -eq 0) { $cleanFolders = $DefaultFolders }
$Config.SourceFolders = $cleanFolders

# === 1. LOGIQUE DE L'INTERFACE ===
$selectedIndex = 0

function Get-MenuItems {
    $items = @()
    $items += @{ Type = "Action"; Key = "Start"; Label = " [ LANCER LA SAUVEGARDE ]"; Color = "Green" }
    $items += @{ Type = "Separator"; Label = "-----------------------------------------------" }
    $items += @{ Type = "Config"; Key = "PrimaryDestination";  Label = "Destination Primaire : "; Value = $Config.PrimaryDestination; ValueColor = "Cyan" }
    $items += @{ Type = "Config"; Key = "FallbackDestination"; Label = "Destination Secours  : "; Value = $Config.FallbackDestination; ValueColor = "Cyan" }
    $items += @{ Type = "Config"; Key = "MaxBackupSizeGB";     Label = "Limite de Taille     : "; Suffix = " Go"; Value = $Config.MaxBackupSizeGB }
    $items += @{ Type = "Config"; Key = "MaxBackupsToKeep";    Label = "Versions à garder    : "; Value = $Config.MaxBackupsToKeep }
    $items += @{ Type = "Separator"; Label = "-----------------------------------------------" }
    $items += @{ Type = "Action"; Key = "AddFolder"; Label = " [+] Ajouter un nouveau dossier"; Color = "Cyan" }
    
    foreach ($key in $Config.SourceFolders.Keys) {
        $folder = $Config.SourceFolders[$key]
        $status = if ($folder.Enabled) { "[X]" } else { "[ ]" }
        $items += @{ Type = "Folder"; Key = $key; Label = " $status $key : $($folder.Path)"; Enabled = $folder.Enabled }
    }
    
    $items += @{ Type = "Separator"; Label = "-----------------------------------------------" }
    $items += @{ Type = "Action"; Key = "Exit";  Label = " [ QUITTER ]"; Color = "Red" }
    return $items
}

while ($true) {
    $menuItems = Get-MenuItems
    if ($selectedIndex -ge $menuItems.Count) { $selectedIndex = $menuItems.Count - 1 }
    
    [Console]::SetCursorPosition(0, 0)
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "         GESTIONNAIRE DE SAUVEGARDE" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        $item = $menuItems[$i]
        $isSel = ($i -eq $selectedIndex)
        $prefix = if ($isSel) { "> " } else { "  " }
        
        if ($item.Type -eq "Separator") {
            Write-Host "  $($item.Label)" -ForegroundColor Gray
            continue
        }
        
        $fg = "White"; $bg = "Black"
        if ($isSel) { $fg = "Black"; $bg = "White" }
        elseif ($item.Color) { $fg = $item.Color }
        elseif ($item.Type -eq "Folder" -and -not $item.Enabled) { $fg = "DarkGray" }
        
        # Affichage spécial avec couleurs mélangées si non sélectionné
        if (-not $isSel -and $item.ValueColor -and $item.Value) {
            Write-Host "$prefix$($item.Label)" -NoNewline -ForegroundColor $fg
            Write-Host "$($item.Value)" -ForegroundColor $item.ValueColor
        } else {
            $lineText = "$prefix$($item.Label)$($item.Value)$($item.Suffix)"
            if ($lineText.Length -gt 47) { $lineText = $lineText.Substring(0, 44) + "..." }
            Write-Host $lineText.PadRight(47) -ForegroundColor $fg -BackgroundColor $bg
        }
    }
    
    Write-Host "`n-----------------------------------------------" -ForegroundColor Gray
    Write-Host " [↑/↓]: Naviguer  [Entrée]: Agir/Basculer  [Q]: Quitter" -ForegroundColor Gray
    
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq "UpArrow") { 
        $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $menuItems.Count - 1 }
        while ($menuItems[$selectedIndex].Type -eq "Separator") { $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $menuItems.Count - 1 } }
    }
    elseif ($key.Key -eq "DownArrow") { 
        $selectedIndex = if ($selectedIndex -lt $menuItems.Count - 1) { $selectedIndex + 1 } else { 0 }
        while ($menuItems[$selectedIndex].Type -eq "Separator") { $selectedIndex = if ($selectedIndex -lt $menuItems.Count - 1) { $selectedIndex + 1 } else { 0 } }
    }
    elseif ($key.Key -eq "Q") { [Console]::CursorVisible = $true; exit }
    elseif ($key.Key -eq "Enter") {
        $selectedItem = $menuItems[$selectedIndex]
        if ($selectedItem.Key -eq "Start") { break }
        if ($selectedItem.Key -eq "Exit") { [Console]::CursorVisible = $true; exit }
        if ($selectedItem.Type -eq "Config") {
            if ($selectedItem.Key -match "Destination") {
                Add-Type -AssemblyName System.Windows.Forms; $fd = New-Object System.Windows.Forms.FolderBrowserDialog
                if ($fd.ShowDialog() -eq "OK") { $Config.$($selectedItem.Key) = $fd.SelectedPath; Save-Config $Config }
            } else {
                [Console]::CursorVisible = $true
                [Console]::SetCursorPosition($selectedItem.Label.Length + 2, $selectedIndex + 3)
                Write-Host "      " -NoNewline -BackgroundColor White
                [Console]::SetCursorPosition($selectedItem.Label.Length + 2, $selectedIndex + 3)
                $val = Read-Host
                if ($val -match "^\d+$") { $Config.$($selectedItem.Key) = [int]$val; Save-Config $Config }
                [Console]::CursorVisible = $false
            }
        }
        elseif ($selectedItem.Key -eq "AddFolder") {
            [Console]::CursorVisible = $true; Clear-Host
            $name = Read-Host "Nom du dossier"; Add-Type -AssemblyName System.Windows.Forms; $fd = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($fd.ShowDialog() -eq "OK") { $Config.SourceFolders[$name] = @{ Path = $fd.SelectedPath; Enabled = $true }; Save-Config $Config }
            [Console]::CursorVisible = $false; Clear-Host
        }
        elseif ($selectedItem.Type -eq "Folder") {
            $Config.SourceFolders[$selectedItem.Key].Enabled = -not $Config.SourceFolders[$selectedItem.Key].Enabled
            Save-Config $Config
        }
    }
}

# === 2. EXECUTION ===
[Console]::CursorVisible = $true; Clear-Host
Write-Host "--- PRÉPARATION DE LA SAUVEGARDE ---" -ForegroundColor Cyan
$folders = [ordered]@{}
foreach ($key in $Config.SourceFolders.Keys) {
    if ($Config.SourceFolders[$key].Enabled) { $folders[$key] = $Config.SourceFolders[$key].Path }
}
Write-Host "Analyse des dossiers..." -ForegroundColor Gray
[long]$totalSize = 0
foreach ($path in $folders.Values) { if (Test-Path $path) { $size = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; if ($size) { $totalSize += $size } } }
$sizeGB = [Math]::Round($totalSize / 1GB, 2)
if ($totalSize -gt ($Config.MaxBackupSizeGB * 1GB)) { Write-Host "ERREUR : Taille ($sizeGB Go) > Limite ($($Config.MaxBackupSizeGB) Go)." -ForegroundColor Red; pause; exit }
$DestRoot = if (Test-Path $Config.PrimaryDestination.Split("\")[0]) { $Config.PrimaryDestination } else { $Config.FallbackDestination }
$dest = "$DestRoot\$((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss'))"
New-Item $dest -ItemType Directory -Force | Out-Null
Write-Host "`n>>> Copie vers $dest..." -ForegroundColor Yellow
foreach ($folderName in $folders.Keys) {
    Write-Host " - $folderName" -ForegroundColor Gray
    robocopy "$($folders[$folderName])" "$dest\$folderName" /E /MT:16 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS /XD Cache Caches .git node_modules /LOG+:"$dest\backup.log"
}
$browserDest = "$dest\Browsers"
function Backup-Chromium { param($Path, $Name) if (Test-Path $Path) { $found = Get-ChildItem $Path -Directory -Filter "Profile*"; if (Test-Path "$Path\Default") { $found += Get-Item "$Path\Default" }; foreach ($p in $found) { robocopy "$($p.FullName)" "$browserDest\$Name\$($p.Name)" "Bookmarks" "Login Data" /R:1 /W:1 /NP /NFL /NDL /NJH /NJS /LOG+:"$dest\backup.log" } } }
Backup-Chromium -Path "$realUserProfile\AppData\Local\Google\Chrome\User Data" -Name "Chrome"
Backup-Chromium -Path "$realUserProfile\AppData\Local\Microsoft\Edge\User Data" -Name "Edge"
Backup-Chromium -Path "$realUserProfile\AppData\Local\BraveSoftware\Brave-Browser\User Data" -Name "Brave"
robocopy "$realUserProfile\AppData\Roaming\Mozilla\Firefox" "$browserDest\Firefox" /E /MT:8 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS /XD Cache Caches /LOG+:"$dest\backup.log"
robocopy "$realUserProfile\AppData\Roaming\Thunderbird" "$browserDest\Thunderbird" /E /MT:8 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS /XD Cache Caches /LOG+:"$dest\backup.log"
if (Test-Path (Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper) { 
    New-Item "$dest\Wallpaper" -ItemType Directory -Force | Out-Null
    Copy-Item (Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper "$dest\Wallpaper\current_wallpaper.jpg" -Force 
    # AJOUT DE LA SAUVEGARDE DES PARAMÈTRES
    Get-ItemProperty 'HKCU:\Control Panel\Desktop' | Select-Object WallpaperStyle, TileWallpaper | ConvertTo-Json | Set-Content "$dest\Wallpaper\wallpaper_settings.json" -Force
}
Copy-Item "$ScriptPath\restore.ps1", "$ScriptPath\restore.bat", "$ScriptPath\config.json" -Destination $dest -Force
Get-ChildItem $DestRoot -Directory | Sort-Object CreationTime -Descending | Select-Object -Skip $Config.MaxBackupsToKeep | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nSAUVEGARDE TERMINÉE !" -ForegroundColor Green
pause