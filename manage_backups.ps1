##[Ps1 To Exe]
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# === 0. CHARGEMENT CONFIGURATION ===
$ScriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$ConfigFile = "$ScriptPath\config.json"

function Load-Config {
    if (Test-Path $ConfigFile) {
        try { return Get-Content $ConfigFile -Raw | ConvertFrom-Json } catch { return $null }
    }; return $null
}

$Config = Load-Config
if (-not $Config) { $Config = @{ PrimaryDestination = "E:\Sauvegarde Test"; FallbackDestination = "C:\Sauvegarde_Secours" } }
$DestRoot = if (Test-Path $Config.PrimaryDestination.Split("\")[0]) { $Config.PrimaryDestination } else { $Config.FallbackDestination }

# === 1. FONCTIONS DE GESTION ===
$backupsList = @() # Liste d'objets : { Name, Path, Size, Selected }

function Get-FolderSize {
    param($Path)
    $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $size) { return "0 Mo" }
    if ($size -gt 1GB) { return "$([Math]::Round($size/1GB, 2)) Go" }
    return "$([Math]::Round($size/1MB, 0)) Mo"
}

function Refresh-Backups {
    Write-Host "`n  Analyse des dossiers en cours... " -ForegroundColor Gray -NoNewline
    $global:backupsList = @()
    if (Test-Path $DestRoot) {
        $folders = Get-ChildItem -Path $DestRoot -Directory | Sort-Object CreationTime -Descending
        foreach ($f in $folders) {
            $global:backupsList += [PSCustomObject]@{
                Name     = $f.Name
                Path     = $f.FullName
                Size     = Get-FolderSize $f.FullName
                Selected = $false
            }
        }
    }
}

# === 2. LOGIQUE DE L'INTERFACE BIOS ===
$selectedIndex = 0

function Draw-Menu {
    [Console]::SetCursorPosition(0, 0)
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "         GESTIONNAIRE DES ARCHIVES" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Dossier : $DestRoot" -ForegroundColor Gray
    Write-Host "-----------------------------------------------" -ForegroundColor Gray
    
    if ($backupsList.Count -eq 0) {
        Write-Host "  (Aucune sauvegarde trouvée)" -ForegroundColor Yellow
        for ($i=0; $i -lt 10; $i++) { Write-Host "                                               " }
    } else {
        for ($i = 0; $i -lt $backupsList.Count; $i++) {
            $b = $backupsList[$i]
            $isSel = ($i -eq $selectedIndex)
            $prefix = if ($isSel) { "> " } else { "  " }
            $status = if ($b.Selected) { "[X]" } else { "[ ]" }
            
            $fg = "White"; $bg = "Black"
            if ($isSel) { $fg = "Black"; $bg = "White" }
            elseif ($b.Selected) { $fg = "Cyan" }
            
            $line = "$prefix$status $($b.Name)".PadRight(35) + "($($b.Size))"
            Write-Host $line.PadRight(47).Substring(0,47) -ForegroundColor $fg -BackgroundColor $bg
        }
    }
    
    Write-Host "`n-----------------------------------------------" -ForegroundColor Gray
    Write-Host " [↑/↓]: Naviguer    [ENTRÉE]: Sélectionner" -ForegroundColor Gray
    Write-Host " [S]: Supprimer     [O]: Ouvrir dossier" -ForegroundColor Gray
    Write-Host " [R]: Actualiser    [Q]: Quitter" -ForegroundColor Gray
}

# Initialisation
Refresh-Backups

while ($true) {
    Draw-Menu
    
    $key = [Console]::ReadKey($true)
    
    if ($key.Key -eq "UpArrow") { 
        $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $backupsList.Count - 1 }
    }
    elseif ($key.Key -eq "DownArrow") { 
        $selectedIndex = if ($selectedIndex -lt $backupsList.Count - 1) { $selectedIndex + 1 } else { 0 }
    }
    elseif ($key.Key -eq "Q") { [Console]::CursorVisible = $true; exit }
    elseif ($key.Key -eq "R") { Clear-Host; Refresh-Backups; Clear-Host }
    elseif ($key.Key -eq "Enter") {
        if ($backupsList.Count -gt 0) {
            $backupsList[$selectedIndex].Selected = -not $backupsList[$selectedIndex].Selected
        }
    }
    elseif ($key.Key -eq "O") {
        if ($backupsList.Count -gt 0) {
            explorer $backupsList[$selectedIndex].Path
        } else {
            explorer $DestRoot
        }
    }
    elseif ($key.Key -eq "S") {
        $toDelete = $backupsList | Where-Object { $_.Selected }
        if ($toDelete.Count -gt 0) {
            [Console]::CursorVisible = $true
            Write-Host "`n"
            $confirm = Read-Host "Supprimer $($toDelete.Count) sauvegarde(s) ? (O/N)"
            if ($confirm -eq "O") {
                foreach ($b in $toDelete) {
                    Write-Host "Suppression de : $($b.Name)..." -ForegroundColor Gray
                    Remove-Item $b.Path -Recurse -Force -ErrorAction SilentlyContinue
                }
                Refresh-Backups
                Clear-Host
            }
            [Console]::CursorVisible = $false
        }
    }
}