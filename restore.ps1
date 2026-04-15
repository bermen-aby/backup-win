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

function Load-Config {
    if (Test-Path $ConfigFile) {
        try { return Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch { return $null }
    }; return $null
}

$Config = Load-Config
if (-not $Config) { $Config = @{ PrimaryDestination = "E:\Sauvegarde Test"; FallbackDestination = "C:\Sauvegarde_Secours" } }

# Détection automatique de la source (dernière sauvegarde)
$DestRoot = if (Test-Path $Config.PrimaryDestination.Split("\")[0]) { $Config.PrimaryDestination } else { $Config.FallbackDestination }
$SourceRoot = $ScriptPath

# Si on n'est pas déjà dans un dossier de backup, on cherche le plus récent
if (-not (Test-Path "$SourceRoot\Browsers") -and -not (Test-Path "$SourceRoot\Documents")) {
    if (Test-Path $DestRoot) {
        $last = Get-ChildItem $DestRoot -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($last) { $SourceRoot = $last.FullName }
    }
}

# === 1. LOGIQUE DE L'INTERFACE RESTORE ===
$selectedIndex = 0
$restoreOptions = [ordered]@{
    "Files"     = @{ Label = "Documents et Fichiers"; Enabled = $true; Found = $false }
    "Browsers"  = @{ Label = "Profils Navigateurs (Chrome, Firefox...)"; Enabled = $true; Found = $false }
    "Wallpaper" = @{ Label = "Fond d'écran et Personnalisation"; Enabled = $true; Found = $false }
}

function Update-FoundItems {
    $restoreOptions.Files.Found = (Get-ChildItem $SourceRoot -Directory | Where-Object { $_.Name -notin @("Browsers", "Wallpaper") }).Count -gt 0
    $restoreOptions.Browsers.Found = Test-Path "$SourceRoot\Browsers"
    $restoreOptions.Wallpaper.Found = Test-Path "$SourceRoot\Wallpaper"
}

function Get-MenuItems {
    $items = @()
    $items += @{ Type = "Action"; Key = "Start"; Label = " [ LANCER LA RESTAURATION ]"; Color = "Green" }
    $items += @{ Type = "Separator"; Label = "-----------------------------------------------" }
    $items += @{ Type = "Config"; Key = "Source"; Label = "Dossier Source : "; Value = $SourceRoot; ValueColor = "Cyan" }
    $items += @{ Type = "Separator"; Label = "-----------------------------------------------" }
    $items += @{ Type = "Header"; Label = "[ ÉLÉMENTS À RESTAURER ]" }
    
    foreach ($key in $restoreOptions.Keys) {
        $opt = $restoreOptions[$key]
        if ($opt.Found) {
            $status = if ($opt.Enabled) { "[X]" } else { "[ ]" }
            $items += @{ Type = "Toggle"; Key = $key; Label = " $status $($opt.Label)"; Enabled = $opt.Enabled }
        } else {
            $items += @{ Type = "Info"; Label = " [ ] $($opt.Label) (Non trouvé)"; Color = "DarkGray" }
        }
    }
    
    $items += @{ Type = "Separator"; Label = "-----------------------------------------------" }
    $items += @{ Type = "Action"; Key = "Exit"; Label = " [ QUITTER ]"; Color = "Red" }
    return $items
}

while ($true) {
    Update-FoundItems
    $menuItems = Get-MenuItems
    if ($selectedIndex -ge $menuItems.Count) { $selectedIndex = $menuItems.Count - 1 }
    
    [Console]::SetCursorPosition(0, 0)
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "        GESTIONNAIRE DE RESTAURATION" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        $item = $menuItems[$i]
        $isSel = ($i -eq $selectedIndex)
        $prefix = if ($isSel) { "> " } else { "  " }
        
        if ($item.Type -eq "Separator" -or $item.Type -eq "Header") {
            Write-Host "  $($item.Label)" -ForegroundColor Gray
            continue
        }
        
        $fg = "White"; $bg = "Black"
        if ($isSel) { $fg = "Black"; $bg = "White" }
        elseif ($item.Color) { $fg = $item.Color }
        elseif ($item.Type -eq "Info") { $fg = "DarkGray" }
        
        if (-not $isSel -and $item.ValueColor) {
            Write-Host "$prefix$($item.Label)" -NoNewline -ForegroundColor $fg
            Write-Host "$($item.Value)" -ForegroundColor $item.ValueColor
        } else {
            $lineText = "$prefix$($item.Label)$($item.Value)"
            if ($lineText.Length -gt 47) { $lineText = $lineText.Substring(0, 44) + "..." }
            Write-Host $lineText.PadRight(47) -ForegroundColor $fg -BackgroundColor $bg
        }
    }
    
    Write-Host "`n-----------------------------------------------" -ForegroundColor Gray
    Write-Host " [↑/↓]: Naviguer  [Entrée]: Agir/Basculer  [Q]: Quitter" -ForegroundColor Gray
    
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq "UpArrow") { 
        $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $menuItems.Count - 1 }
        while ($menuItems[$selectedIndex].Type -in @("Separator", "Header", "Info")) { $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $menuItems.Count - 1 } }
    }
    elseif ($key.Key -eq "DownArrow") { 
        $selectedIndex = if ($selectedIndex -lt $menuItems.Count - 1) { $selectedIndex + 1 } else { 0 }
        while ($menuItems[$selectedIndex].Type -in @("Separator", "Header", "Info")) { $selectedIndex = if ($selectedIndex -lt $menuItems.Count - 1) { $selectedIndex + 1 } else { 0 } }
    }
    elseif ($key.Key -eq "Q") { [Console]::CursorVisible = $true; exit }
    elseif ($key.Key -eq "Enter") {
        $selectedItem = $menuItems[$selectedIndex]
        if ($selectedItem.Key -eq "Start") { break }
        if ($selectedItem.Key -eq "Exit") { [Console]::CursorVisible = $true; exit }
        if ($selectedItem.Key -eq "Source") {
            Add-Type -AssemblyName System.Windows.Forms; $fd = New-Object System.Windows.Forms.FolderBrowserDialog
            $fd.Description = "Sélectionnez le dossier de sauvegarde à restaurer"
            if ($fd.ShowDialog() -eq "OK") { $SourceRoot = $fd.SelectedPath }
        }
        elseif ($selectedItem.Type -eq "Toggle") {
            $restoreOptions[$selectedItem.Key].Enabled = -not $restoreOptions[$selectedItem.Key].Enabled
        }
    }
}

# === 2. EXECUTION DE LA RESTAURATION ===
[Console]::CursorVisible = $true; Clear-Host
Write-Host "--- DÉMARRAGE DE LA RESTAURATION ---" -ForegroundColor Cyan
Write-Host "Source : $SourceRoot" -ForegroundColor Gray

# Fichiers
if ($restoreOptions.Files.Enabled -and $restoreOptions.Files.Found) {
    Write-Host "`nRestaurations des dossiers personnels..." -ForegroundColor Yellow
    Get-ChildItem $SourceRoot -Directory | Where-Object { $_.Name -notin @("Browsers", "Wallpaper") } | foreach {
        Write-Host " - $($_.Name)" -ForegroundColor Gray
        robocopy "$($_.FullName)" "$realUserProfile\$($_.Name)" /E /MT:16 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS
    }
}

# Navigateurs
if ($restoreOptions.Browsers.Enabled -and $restoreOptions.Browsers.Found) {
    Write-Host "`nRestaurations des navigateurs..." -ForegroundColor Yellow
    $bSrc = "$SourceRoot\Browsers"
    
    # Chrome/Edge/Brave (Favoris/Pass)
    function Restore-Chromium {
        param($Name, $Path)
        if (Test-Path "$bSrc\$Name") {
            Write-Host " - $Name" -ForegroundColor Gray
            Get-ChildItem "$bSrc\$Name" -Directory | foreach {
                robocopy "$($_.FullName)" "$Path\$($_.Name)" "Bookmarks" "Login Data" /R:1 /W:1 /NP /NFL /NDL /NJH /NJS
            }
        }
    }
    Restore-Chromium "Chrome" "$realUserProfile\AppData\Local\Google\Chrome\User Data"
    Restore-Chromium "Edge"   "$realUserProfile\AppData\Local\Microsoft\Edge\User Data"
    Restore-Chromium "Brave"  "$realUserProfile\AppData\Local\BraveSoftware\Brave-Browser\User Data"
    
    # Firefox & Thunderbird (Complets)
    if (Test-Path "$bSrc\Firefox") { Write-Host " - Firefox"; robocopy "$bSrc\Firefox" "$realUserProfile\AppData\Roaming\Mozilla\Firefox" /E /MT:8 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS }
    if (Test-Path "$bSrc\Thunderbird") { Write-Host " - Thunderbird"; robocopy "$bSrc\Thunderbird" "$realUserProfile\AppData\Roaming\Thunderbird" /E /MT:8 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS }
}

# Wallpaper
if ($restoreOptions.Wallpaper.Enabled -and $restoreOptions.Wallpaper.Found) {
    Write-Host "`nRestauration du fond d'écran..." -ForegroundColor Yellow
    $wpFile = Get-ChildItem "$SourceRoot\Wallpaper\current_wallpaper.*" | Select-Object -First 1
    if ($wpFile) {
        $destWp = "$realUserProfile\AppData\Local\Microsoft\Windows\Themes\RestoredWallpaper$($wpFile.Extension)"
        if (-not (Test-Path (Split-Path $destWp))) { New-Item (Split-Path $destWp) -ItemType Directory -Force | Out-Null }
        Copy-Item $wpFile.FullName $destWp -Force
        
        if (Test-Path "$SourceRoot\Wallpaper\wallpaper_settings.json") {
            $set = Get-Content "$SourceRoot\Wallpaper\wallpaper_settings.json" | ConvertFrom-Json
            Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value $set.WallpaperStyle
            Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value $set.TileWallpaper
        }
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $destWp
        
        $code = 'using System.Runtime.InteropServices; public class Wp { [DllImport("user32.dll")] public static extern int SystemParametersInfo(int u, int p, string v, int f); }'
        Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
        [Wp]::SystemParametersInfo(20, 0, $destWp, 3) | Out-Null
    }
}

Write-Host "`nRESTAURATION TERMINÉE !" -ForegroundColor Green
pause