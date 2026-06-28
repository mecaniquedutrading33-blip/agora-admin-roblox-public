# Add-HermesToken.ps1
# Envoie un token sécurisé à Hermès via l'Edge Function Supabase

$ErrorActionPreference = 'Stop'

$DropKey = 'dropkey_emerick_2026'
$Endpoint = 'https://hlxbqtayotwdtspkrlol.supabase.co/functions/v1/token-drop'

Write-Host '=== Hermès Token Drop ===' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Services acceptés :'
Write-Host '  - EMERICK_DISCORD_BOT_TOKEN'
Write-Host '  - EMERICK_GITHUB_TOKEN'
Write-Host '  - EMERICK_SUPABASE_ACCESS_TOKEN'
Write-Host ''

$service = Read-Host 'Nom du service (ex: EMERICK_DISCORD_BOT_TOKEN)'
if (-not $service) {
    Write-Host 'Service vide. Annulation.' -ForegroundColor Red
    exit 1
}

$secureToken = Read-Host 'Token à envoyer' -AsSecureString
if ($secureToken.Length -eq 0) {
    Write-Host 'Token vide. Annulation.' -ForegroundColor Red
    exit 1
}

# Convert SecureString -> plain text (local use only, never logged)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

$body = @{
    service = $service.ToUpper()
    token   = $plainToken
    drop_key = $DropKey
} | ConvertTo-Json -Compress

$plainToken = $null

$headers = @{
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri $Endpoint -Method POST -Headers $headers -Body $body -TimeoutSec 30
    Write-Host ''
    Write-Host 'Token envoyé avec succès.' -ForegroundColor Green
    Write-Host "Service : $($response.service)"
    Write-Host 'Tu peux reset ton token maintenant côté Discord/GitHub.' -ForegroundColor Yellow
} catch {
    Write-Host ''
    Write-Host 'ERREUR lors de l envoi :' -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ''
Write-Host 'Appuie sur Entrée pour fermer...'
Read-Host
