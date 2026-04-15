@echo off
:: Passage en UTF8 pour les accents
chcp 65001 > nul
:: Lancement de PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage_backups.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Une erreur est survenue lors de l'exécution du script.
    pause
)
exit