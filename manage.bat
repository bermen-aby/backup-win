@echo off
:: Passage en UTF8 pour les accents
chcp 65001 > nul
:: Lancement de PowerShell en masquant la console au maximum
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage_backups.ps1"
exit