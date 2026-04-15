##[Ps1 To Exe]
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# 0. CONFIG
if ($PSScriptRoot) { $ScriptDir = $PSScriptRoot } else { $ScriptDir = $PWD.Path }
$ConfigFile = Join-Path $ScriptDir "config.json"

if (Test-Path $ConfigFile) {
    $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
} else {
    $Config = @{ PrimaryDestination = "E:\Sauvegarde Test"; FallbackDestination = "C:\Sauvegarde_Secours" }
}

$DestRoot = $Config.FallbackDestination
if ($Config.PrimaryDestination) {
    $parts = $Config.PrimaryDestination.Split("\")
    if ($parts.Count -gt 0) {
        $RootDrive = $parts[0]
        if (Test-Path $RootDrive) {
            $DestRoot = $Config.PrimaryDestination
        }
    }
}

# 1. DATA
$global:backupsList = @()
$global:idx = 0

function Get-FSize($p) {
    try {
        $files = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue
        if (-not $files) { return "0 Mo" }
        $s = ($files | Measure-Object -Property Length -Sum).Sum
        if ($s -gt 1GB) { 
            $res = [Math]::Round($s/1GB, 2)
            return "$res Go" 
        }
        $res = [Math]::Round($s/1MB, 0)
        return "$res Mo"
    } catch { return "Error" }
}

function Get-BackupUser($p) {
    # 1. Tentative via user.txt
    $userFile = Join-Path $p "user.txt"
    if (Test-Path $userFile) {
        return (Get-Content $userFile -Raw).Trim()
    }
    
    # 2. Tentative via backup.log (Robocopy contient souvent le chemin source avec l'utilisateur)
    $logFile = Join-Path $p "backup.log"
    if (Test-Path $logFile) {
        $log = Get-Content $logFile -TotalCount 50 -ErrorAction SilentlyContinue
        foreach ($line in $log) {
            if ($line -match "C:\\Users\\([^\\]+)") {
                return $Matches[1]
            }
        }
    }
    
    return "Inconnu"
}

function Refresh {
    $global:backupsList = @()
    if (Test-Path $DestRoot) {
        $folders = Get-ChildItem -Path $DestRoot -Directory | Sort-Object CreationTime -Descending
        foreach ($f in $folders) {
            $user = Get-BackupUser $f.FullName
            
            $item = [PSCustomObject]@{
                Name = $f.Name
                User = $user
                Path = $f.FullName
                Size = "..."
                Sel  = $false
            }
            $global:backupsList += $item
        }
    }
}

# 2. UI
function Draw {
    [Console]::SetCursorPosition(0, 0)
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "         GESTIONNAIRE DES ARCHIVES" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Dossier : $DestRoot" -ForegroundColor Gray
    Write-Host "-----------------------------------------------" -ForegroundColor Gray
    
    if ($global:backupsList.Count -eq 0) {
        Write-Host "  (Aucune sauvegarde trouvee)" -ForegroundColor Yellow
        for($k=0;$k -lt 10;$k++){ Write-Host "                                               " }
    } else {
        for ($i = 0; $i -lt $global:backupsList.Count; $i++) {
            $b = $global:backupsList[$i]
            $isSel = ($i -eq $global:idx)
            
            if ($isSel) { $pfx = "> " } else { $pfx = "  " }
            if ($b.Sel) { $chk = "[X]" } else { $chk = "[ ]" }
            
            $fg = "White"; $bg = "Black"
            if ($isSel) { 
                $fg = "Black"
                $bg = "White" 
            } elseif ($b.Sel) { 
                $fg = "Cyan" 
            }
            
            $txtUser = "($($b.User))"
            $lineTxt = "$pfx$chk $($b.Name) $txtUser".PadRight(35) + "($($b.Size))"
            
            if ($lineTxt.Length -gt 47) { $lineTxt = $lineTxt.Substring(0,47) }
            Write-Host $lineTxt.PadRight(47) -ForegroundColor $fg -BackgroundColor $bg
        }
        for($j=$global:backupsList.Count;$j -lt 10;$j++){ Write-Host "                                               " }
    }
    
    Write-Host "`n-----------------------------------------------" -ForegroundColor Gray
    Write-Host " [Haut/Bas]: Naviguer    [ENTREE]: Cocher" -ForegroundColor Gray
    Write-Host " [S]: Supprimer          [O]: Ouvrir" -ForegroundColor Gray
    Write-Host " [R]: Actualiser         [Q]: Quitter" -ForegroundColor Gray
}

# START
Refresh
foreach ($b in $global:backupsList) { $b.Size = Get-FSize $b.Path }
Clear-Host

while ($true) {
    Draw
    $k = [Console]::ReadKey($true).Key
    
    if ($k -eq "UpArrow") { 
        if($global:backupsList.Count -gt 0){ 
            if($global:idx -gt 0){ $global:idx-- } else { $global:idx = $global:backupsList.Count-1 } 
        } 
    }
    if ($k -eq "DownArrow") { 
        if($global:backupsList.Count -gt 0){ 
            if($global:idx -lt $global:backupsList.Count-1){ $global:idx++ } else { $global:idx = 0 } 
        } 
    }
    if ($k -eq "Q") { 
        [Console]::CursorVisible = $true
        break 
    }
    if ($k -eq "R") { 
        Clear-Host
        Refresh
        foreach($b in $global:backupsList){ $b.Size = Get-FSize $b.Path }
        Clear-Host 
    }
    if ($k -eq "Enter") { 
        if($global:backupsList.Count -gt 0){ 
            $global:backupsList[$global:idx].Sel = -not $global:backupsList[$global:idx].Sel 
        } 
    }
    if ($k -eq "O") { 
        if($global:backupsList.Count -gt 0){ 
            $p = $global:backupsList[$global:idx].Path
            explorer $p 
        } 
    }
    if ($k -eq "S") {
        $delItems = $global:backupsList | Where-Object { $_.Sel }
        if ($delItems) {
            $count = ($delItems | Measure-Object).Count
            if ($count -gt 0) {
                [Console]::CursorVisible = $true
                Write-Host "`n"
                $ans = Read-Host "Supprimer $count sauvegarde(s) ? (O/N)"
                if ($ans -eq "O") {
                    foreach($d in $delItems){ 
                        Remove-Item $d.Path -Recurse -Force -ErrorAction SilentlyContinue 
                    }
                    Refresh
                    foreach($b in $global:backupsList){ $b.Size = Get-FSize $b.Path }
                    Clear-Host
                }
                [Console]::CursorVisible = $false
            }
        }
    }
}
exit
