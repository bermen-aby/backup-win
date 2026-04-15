@echo off
net session >nul 2>&1 || (powershell start -verb runas '%~f0' & exit /b)
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -Command "& {Get-Content 'Backup.ps1' -Raw -Encoding UTF8 | Invoke-Expression}"