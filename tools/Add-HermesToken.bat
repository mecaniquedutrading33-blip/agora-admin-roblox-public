@echo off
chcp 65001 >nul
echo === Hermes Token Drop ===
echo.

set "ps1Url=https://raw.githubusercontent.com/mecaniquedutrading33-blip/agora-admin-roblox-public/main/tools/Add-HermesToken.ps1"
set "ps1Path=%TEMP%\Add-HermesToken.ps1"

echo Telechargement du script PowerShell...
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%ps1Url%' -OutFile '%ps1Path%' -UseBasicParsing"

if not exist "%ps1Path%" (
    echo ERREUR: impossible de telecharger le script.
    echo Verifie ta connexion internet et reessaie.
    pause
    exit /b 1
)

echo.
echo Lancement du script PowerShell...
powershell -ExecutionPolicy Bypass -File "%ps1Path%"

echo.
echo Appuie sur une touche pour fermer...
pause >nul
