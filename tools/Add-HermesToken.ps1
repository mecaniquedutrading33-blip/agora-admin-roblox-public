# Add-HermesToken.ps1
# Envoie un token securise a Hermes via l'Edge Function Supabase
# Historique local : noms de services + projet uniquement, JAMAIS le token.

$ErrorActionPreference = 'Stop'

# --- Configuration du projet Agora (Emerick) ---
$DropKey = 'dropkey_emerick_2026'
$ProjectId = 'hlxbqtayotwdtspkrlol'
$Endpoint = "https://$ProjectId.supabase.co/functions/v1/token-drop"

# --- Historique local ---
$HistoryDir = Join-Path $env:USERPROFILE '.hermes'
$HistoryFile = Join-Path $HistoryDir 'token-history.json'

function Ensure-HistoryFile {
    if (-not (Test-Path $HistoryDir)) {
        New-Item -ItemType Directory -Path $HistoryDir -Force | Out-Null
    }
    if (-not (Test-Path $HistoryFile)) {
        @{ services = @() } | ConvertTo-Json -Depth 3 | Out-File -FilePath $HistoryFile -Encoding utf8
    }
}

function Load-History {
    Ensure-HistoryFile
    $raw = Get-Content -Path $HistoryFile -Raw -Encoding utf8
    return ($raw | ConvertFrom-Json)
}

function Save-History {
    param([object]$Data)
    $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $HistoryFile -Encoding utf8
}

function Show-Menu {
    Clear-Host
    Write-Host '=== Hermes Token Drop ===' -ForegroundColor Cyan
    Write-Host "Projet : $ProjectId" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Historique local (tokens jamais sauves) :' -ForegroundColor Yellow

    $history = Load-History
    $i = 1
    foreach ($svc in $history.services) {
        Write-Host "  $i. $($svc.name)" -ForegroundColor White
        $i++
    }

    Write-Host ''
    Write-Host 'Commandes :' -ForegroundColor Green
    Write-Host '  n = Nouveau service'
    Write-Host '  e = Editer un nom'
    Write-Host '  d = Supprimer un service de l historique'
    Write-Host '  q = Quitter'
    Write-Host ''
}

function Prompt-Choice {
    Show-Menu
    $choice = Read-Host 'Choix'
    return $choice
}

function Send-Token {
    param([string]$ServiceName)

    $secureToken = Read-Host "Token pour [$ServiceName]" -AsSecureString
    if ($secureToken.Length -eq 0) {
        Write-Host 'Token vide. Annulation.' -ForegroundColor Red
        return
    }

    # Convert SecureString -> plain text (local use only, never logged)
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    $body = @{
        service  = $ServiceName.ToUpper()
        token    = $plainToken
        drop_key = $DropKey
    } | ConvertTo-Json -Compress

    $plainToken = $null

    $headers = @{
        'Content-Type' = 'application/json'
    }

    try {
        $response = Invoke-RestMethod -Uri $Endpoint -Method POST -Headers $headers -Body $body -TimeoutSec 30
        Write-Host ''
        Write-Host 'Token envoye avec succes.' -ForegroundColor Green
        Write-Host "Service : $($response.service)"
        Write-Host 'Tu peux reset ton token cote Discord/GitHub maintenant.' -ForegroundColor Yellow
    }
    catch {
        Write-Host ''
        Write-Host 'ERREUR lors de l envoi :' -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

function Add-NewService {
    $name = Read-Host 'Nom du nouveau service (ex: EMERICK_DISCORD_BOT_TOKEN)'
    if (-not $name) {
        Write-Host 'Nom vide. Annulation.' -ForegroundColor Red
        return
    }

    $history = Load-History
    $exists = $history.services | Where-Object { $_.name -eq $name.ToUpper() }
    if ($exists) {
        Write-Host 'Ce service existe deja.' -ForegroundColor Yellow
        return
    }

    Send-Token -ServiceName $name.ToUpper()

    $history.services += @{ name = $name.ToUpper(); created_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }
    Save-History -Data $history
}

function Edit-ServiceName {
    $history = Load-History
    if ($history.services.Count -eq 0) {
        Write-Host 'Historique vide.' -ForegroundColor Yellow
        return
    }

    $num = Read-Host 'Numero du service a renommer'
    $idx = [int]$num - 1
    if ($idx -lt 0 -or $idx -ge $history.services.Count) {
        Write-Host 'Numero invalide.' -ForegroundColor Red
        return
    }

    $oldName = $history.services[$idx].name
    $newName = Read-Host "Nouveau nom pour [$oldName]"
    if (-not $newName) {
        Write-Host 'Nom vide. Annulation.' -ForegroundColor Red
        return
    }

    $history.services[$idx].name = $newName.ToUpper()
    Save-History -Data $history
    Write-Host 'Nom mis a jour.' -ForegroundColor Green
}

function Delete-Service {
    $history = Load-History
    if ($history.services.Count -eq 0) {
        Write-Host 'Historique vide.' -ForegroundColor Yellow
        return
    }

    $num = Read-Host 'Numero du service a supprimer'
    $idx = [int]$num - 1
    if ($idx -lt 0 -or $idx -ge $history.services.Count) {
        Write-Host 'Numero invalide.' -ForegroundColor Red
        return
    }

    $name = $history.services[$idx].name
    $history.services = $history.services | Where-Object { $_.name -ne $name }
    Save-History -Data $history
    Write-Host "[$name] supprime de l historique." -ForegroundColor Green
}

function Select-ExistingService {
    param([string]$RawChoice)
    $history = Load-History
    $idx = [int]$RawChoice - 1
    if ($idx -lt 0 -or $idx -ge $history.services.Count) {
        Write-Host 'Numero invalide.' -ForegroundColor Red
        return
    }

    Send-Token -ServiceName $history.services[$idx].name
}

# --- Boucle principale ---
while ($true) {
    $choice = Prompt-Choice

    switch ($choice.ToLower()) {
        'n' { Add-NewService }
        'e' { Edit-ServiceName }
        'd' { Delete-Service }
        'q' { exit 0 }
        default {
            # Si l utilisateur tape un numero, envoyer un token pour ce service
            if ($choice -match '^\d+$') {
                Select-ExistingService -RawChoice $choice
            }
            else {
                Write-Host 'Choix non reconnu.' -ForegroundColor Red
            }
        }
    }

    Write-Host ''
    Write-Host 'Appuie sur Entree pour continuer...'
    Read-Host
}
