# wifi_monitor.ps1 — Surveillance WiFi temps reel v2
# Affiche les evenements WiFi en boucle: connexions, deconnexions, signal, appareils
# Pas de spam = seulement les CHANGEMENTS sont affiches
# Ctrl+C pour arreter
# SAUVEGARDER ce fichier et le lancer: powershell -ExecutionPolicy Bypass -File wifi_monitor.ps1

$ErrorActionPreference = "SilentlyContinue"

# === COULEURS ===
$cTitle = "Cyan"
$cText = "Green"
$cWarn = "Yellow"
$cErr = "Red"
$cInfo = "Cyan"
$cDim = "DarkGray"
$cBright = "White"

# === ETAT PRECEDENT ===
$script:lastSSID = ""
$script:lastBSSID = ""
$script:lastSignal = -1
$script:lastAuth = ""
$script:lastState = ""
$script:lastIP = ""
$script:knownDevices = @{}
$script:lastChannel = -1
$script:lastDnsCount = -1
$script:seenEvents = @{}
$script:startTime = Get-Date
$script:eventCount = 0

# === FONCTIONS ===

function Get-WiFiState {
    $output = netsh wlan show interfaces 2>&1
    $state = [ordered]@{
        SSID = ""; BSSID = ""; State = ""; Signal = ""; Auth = ""; Channel = ""; RX = ""; TX = ""; Radio = ""
    }
    foreach ($line in $output) {
        if ($line -match "SSID\s*:\s*(.+)") { $state.SSID = $matches[1].Trim() }
        elseif ($line -match "BSSID\s*:\s*(.+)") { $state.BSSID = $matches[1].Trim() }
        elseif ($line -match "Etat\s*:\s*(.+)|State\s*:\s*(.+)") { $state.State = ($matches[1].Trim(), $matches[2].Trim() | Where-Object { $_ } | Select-Object -First 1) }
        elseif ($line -match "Signal\s*:\s*(\d+)") { $state.Signal = $matches[1].Trim() }
        elseif ($line -match "Authentification\s*:\s*(.+)|Authentication\s*:\s*(.+)") { $state.Auth = ($matches[1].Trim(), $matches[2].Trim() | Where-Object { $_ } | Select-Object -First 1) }
        elseif ($line -match "Canal\s*:\s*(\d+)|Channel\s*:\s*(\d+)") { $state.Channel = ($matches[1].Trim(), $matches[2].Trim() | Where-Object { $_ } | Select-Object -First 1) }
        elseif ($line -match "Reception\s*:\s*(.+)|Receive\s*:\s*(.+)") { $state.RX = ($matches[1].Trim(), $matches[2].Trim() | Where-Object { $_ } | Select-Object -First 1) }
        elseif ($line -match "Transmission\s*:\s*(.+)|Transmit\s*:\s*(.+)") { $state.TX = ($matches[1].Trim(), $matches[2].Trim() | Where-Object { $_ } | Select-Object -First 1) }
    }
    return $state
}

function Get-ConnectedDevices {
    $devices = @{}
    $arp = arp -a 2>&1
    foreach ($line in $arp) {
        if ($line -match "^\s*([\d\.]+)\s+([a-fA-F0-9\-]+)\s+(\w+)") {
            $ip = $matches[1]; $mac = $matches[2]; $type = $matches[3]
            if ($ip -ne "224.0.0.22" -and $ip -notmatch "^169\.254" -and $mac -ne "ff-ff-ff-ff-ff-ff") {
                $devices[$mac] = $ip
            }
        }
    }
    return $devices
}

function Get-CurrentIP {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -EA Stop | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object -First 1
        return $ip.IPAddress
    } catch { return "" }
}

function Get-DnsCacheCount {
    try { return (Get-DnsClientCache -EA Stop).Count } catch { return -1 }
}

function Print-Event {
    param([string]$type, [string]$message, [string]$color = "Green")
    $script:eventCount++
    $ts = Get-Date -Format "HH:mm:ss"
    $tag = switch ($type) {
        "CONNECT"    { "  [+] CONNEXION  " }
        "DISCONNECT" { "  [-] DECONNEXION" }
        "SIGNAL"     { "  [~] SIGNAL     " }
        "CHANGE"     { "  [!] CHANGEMENT " }
        "DEVICE"     { "  [D] APPAREIL   " }
        "INFO"       { "  [i] INFO       " }
        "WARN"       { "  [?] ATTENTION  " }
        default      { "  [*] EVENEMENT  " }
    }
    Write-Host "[$ts] " -ForegroundColor $cDim -NoNewline
    Write-Host $tag -ForegroundColor $color -NoNewline
    Write-Host " $message" -ForegroundColor $cBright
}

function Print-Box {
    param([string]$text, [string]$color = "Cyan")
    $len = $text.Length
    $bar = "+" + ("-" * ($len + 2)) + "+"
    Write-Host $bar -ForegroundColor $color
    Write-Host "| $text |" -ForegroundColor $color
    Write-Host $bar -ForegroundColor $color
}

function Print-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor $cTitle
    Write-Host "  |" -ForegroundColor $cTitle -NoNewline
    Write-Host "        WIFI MONITOR - TEMPS REEL v2       " -ForegroundColor $cText -NoNewline
    Write-Host "|" -ForegroundColor $cTitle
    Write-Host "  +------------------------------------------+" -ForegroundColor $cTitle
    Write-Host "  |" -ForegroundColor $cTitle -NoNewline
    Write-Host "  PC: $env:COMPUTERNAME                    " -ForegroundColor $cDim -NoNewline
    Write-Host "|" -ForegroundColor $cTitle
    Write-Host "  |" -ForegroundColor $cTitle -NoNewline
    Write-Host "  Debut: $($script:startTime.ToString('HH:mm:ss'))           " -ForegroundColor $cDim -NoNewline
    Write-Host "|" -ForegroundColor $cTitle
    Write-Host "  |" -ForegroundColor $cTitle -NoNewline
    Write-Host "  Ctrl+C pour arreter                     " -ForegroundColor $cWarn -NoNewline
    Write-Host "|" -ForegroundColor $cTitle
    Write-Host "  +------------------------------------------+" -ForegroundColor $cTitle
    Write-Host ""
}

# === DEMARRAGE ===
Print-Header
Print-Event "INFO" "Initialisation de la surveillance WiFi..." $cInfo

# Scan initial
$initState = Get-WiFiState
$initDevices = Get-ConnectedDevices
$initIP = Get-CurrentIP

Write-Host ""
if ($initState.SSID) {
    Print-Box "RESEAU: $($initState.SSID) | Signal: $($initState.Signal)% | Canal: $($initState.Channel)" $cText
    Write-Host ""
    Write-Host "  BSSID     : $($initState.BSSID)" -ForegroundColor $cDim
    Write-Host "  Auth      : $($initState.Auth)" -ForegroundColor $cDim
    Write-Host "  Etat      : $($initState.State)" -ForegroundColor $cDim
    Write-Host "  Reception : $($initState.RX)" -ForegroundColor $cDim
    Write-Host "  Envoi     : $($initState.TX)" -ForegroundColor $cDim
    if ($initIP) { Write-Host "  IP locale : $initIP" -ForegroundColor $cDim }
    Write-Host ""
    $script:lastSSID = $initState.SSID
    $script:lastBSSID = $initState.BSSID
    $script:lastSignal = [int]$initState.Signal
    $script:lastChannel = [int]$initState.Channel
    $script:lastAuth = $initState.Auth
    $script:lastState = $initState.State
    $script:lastIP = $initIP
} else {
    Write-Host "  WiFi non connecte ou en cours de connexion..." -ForegroundColor $cWarn
    $script:lastState = $initState.State
}

if ($initDevices.Count -gt 0) {
    Write-Host ""
    Write-Host "  +-- APPAREILS SUR LE RESEAU ($($initDevices.Count)) --+" -ForegroundColor $cInfo
    foreach ($mac in $initDevices.Keys) {
        Write-Host "  | $mac -> $($initDevices[$mac])" -ForegroundColor $cDim
        $script:knownDevices[$mac] = $initDevices[$mac]
    }
    Write-Host "  +-----------------------------+" -ForegroundColor $cInfo
}

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor $cDim
Write-Host "  En surveillance... (Ctrl+C pour arreter)" -ForegroundColor $cInfo
Write-Host "  ==========================================" -ForegroundColor $cDim
Write-Host ""

# === BOUCLE PRINCIPALE ===
$loopCount = 0
$pollInterval = 3

try {
    while ($true) {
        Start-Sleep -Seconds $pollInterval
        $loopCount++

        # Heartbeat discret toutes les 30 iterations
        if ($loopCount % 30 -eq 0) {
            $elapsed = [math]::Round(((Get-Date) - $script:startTime).TotalMinutes, 1)
            Write-Host "  --- [$([math]::Round($elapsed,1))min] En cours... Events: $($script:eventCount) Appareils: $($script:knownDevices.Count) ---" -ForegroundColor $cDim
        }

        # 1. Etat WiFi
        $state = Get-WiFiState

        if ($state.SSID -and $state.SSID -ne $script:lastSSID) {
            if ($script:lastSSID -eq "") {
                Print-Event "CONNECT" "WiFi connecte: $($state.SSID) (BSSID: $($state.BSSID))" $cText
            } else {
                Print-Event "CHANGE" "Changement de reseau: $($script:lastSSID) -> $($state.SSID)" $cWarn
            }
            $script:lastSSID = $state.SSID
            $script:lastBSSID = $state.BSSID
            $script:lastSignal = [int]$state.Signal
            $script:lastChannel = [int]$state.Channel
            $script:lastAuth = $state.Auth
        }

        if (-not $state.SSID -and $script:lastSSID) {
            Print-Event "DISCONNECT" "WiFi deconnecte (etait: $($script:lastSSID))" $cErr
            $script:lastSSID = ""
            $script:lastBSSID = ""
            $script:lastSignal = -1
        }

        if ($state.BSSID -and $state.BSSID -ne $script:lastBSSID -and $state.SSID -eq $script:lastSSID -and $script:lastBSSID) {
            Print-Event "CHANGE" "Roaming entre points d'acces (BSSID change) meme reseau $($state.SSID)" $cWarn
            $script:lastBSSID = $state.BSSID
        }

        if ($state.Signal) {
            $sigVal = [int]$state.Signal
            if ($script:lastSignal -ge 0 -and [Math]::Abs($sigVal - $script:lastSignal) -ge 10) {
                $arrow = if ($sigVal -gt $script:lastSignal) { "en hausse" } else { "en baisse" }
                Print-Event "SIGNAL" "Signal: $($script:lastSignal)% -> $sigVal% ($arrow)" $cWarn
                $script:lastSignal = $sigVal
            } elseif ($script:lastSignal -lt 0 -and $sigVal -ge 0) {
                $script:lastSignal = $sigVal
            }
        }

        if ($state.Channel) {
            $chVal = [int]$state.Channel
            if ($script:lastChannel -ge 0 -and $chVal -ne $script:lastChannel) {
                Print-Event "CHANGE" "Canal WiFi change: $($script:lastChannel) -> $chVal" $cWarn
            }
            $script:lastChannel = $chVal
        }

        if ($state.State -and $state.State -ne $script:lastState) {
            Print-Event "CHANGE" "Etat connexion: $($script:lastState) -> $($state.State)" $cWarn
            $script:lastState = $state.State
        }

        # 2. Appareils connectes
        $devices = Get-ConnectedDevices

        foreach ($mac in $devices.Keys) {
            if (-not $script:knownDevices.ContainsKey($mac)) {
                Print-Event "DEVICE" "Nouvel appareil connecte: $mac -> $($devices[$mac])" $cText
                $script:knownDevices[$mac] = $devices[$mac]
            }
        }

        foreach ($mac in @($script:knownDevices.Keys)) {
            if (-not $devices.ContainsKey($mac)) {
                Print-Event "DEVICE" "Appareil deconnecte: $mac (etait $($script:knownDevices[$mac]))" $cErr
                $script:knownDevices.Remove($mac)
            }
        }

        foreach ($mac in $devices.Keys) {
            if ($script:knownDevices.ContainsKey($mac) -and $script:knownDevices[$mac] -ne $devices[$mac]) {
                Print-Event "DEVICE" "IP change pour $mac : $($script:knownDevices[$mac]) -> $($devices[$mac])" $cWarn
                $script:knownDevices[$mac] = $devices[$mac]
            }
        }

        # 3. IP locale
        $currentIP = Get-CurrentIP
        if ($currentIP -and $currentIP -ne $script:lastIP) {
            Print-Event "CHANGE" "IP locale change: $($script:lastIP) -> $currentIP" $cWarn
            $script:lastIP = $currentIP
        } elseif (-not $currentIP -and $script:lastIP) {
            Print-Event "DISCONNECT" "IP locale perdue (etait $($script:lastIP))" $cErr
            $script:lastIP = ""
        }

        # 4. DNS
        $dnsCount = Get-DnsCacheCount
        if ($dnsCount -ge 0 -and $dnsCount -ne $script:lastDnsCount) {
            if ($script:lastDnsCount -ge 0) {
                $diff = $dnsCount - $script:lastDnsCount
                if ($diff -gt 5) {
                    Print-Event "INFO" "Activite DNS: +$diff nouvelles entrees (total cache: $dnsCount)" $cDim
                }
            }
            $script:lastDnsCount = $dnsCount
        }

        # 5. Connexions TCP sortantes
        try {
            $conns = Get-NetTCPConnection -State Established -EA Stop
            $externalConns = $conns | Where-Object { $_.RemoteAddress -notmatch "^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" } | Select-Object -First 5
            foreach ($c in $externalConns) {
                $procName = try { (Get-Process -Id $c.OwningProcess -EA Stop).Name } catch { "?" }
                $eventKey = "$($c.RemoteAddress):$($c.RemotePort)"
                if (-not $script:seenEvents.ContainsKey($eventKey)) {
                    Print-Event "CONNECT" "Connexion sortante: $eventKey [$procName]" $cDim
                    $script:seenEvents[$eventKey] = Get-Date
                    if ($script:seenEvents.Count -gt 50) {
                        $sorted = $script:seenEvents.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 30
                        $script:seenEvents = @{}
                        foreach ($e in $sorted) { $script:seenEvents[$e.Key] = $e.Value }
                    }
                }
            }
        } catch {}
    }
} catch {
    Write-Host ""
    Write-Host ""
    $elapsed = [math]::Round(((Get-Date) - $script:startTime).TotalMinutes, 1)
    Write-Host "  +==========================================+" -ForegroundColor $cTitle
    Write-Host "  |" -ForegroundColor $cTitle -NoNewline
    Write-Host "        SURVEILLANCE TERMINEE              " -ForegroundColor $cText -NoNewline
    Write-Host "|" -ForegroundColor $cTitle
    Write-Host "  +==========================================+" -ForegroundColor $cTitle
    Write-Host ""
    Write-Host "  Duree       : $elapsed minutes" -ForegroundColor $cDim
    Write-Host "  Evenements  : $($script:eventCount)" -ForegroundColor $cDim
    Write-Host "  Appareils   : $($script:knownDevices.Count) sur le reseau" -ForegroundColor $cDim
    Write-Host "  Connexions  : $($script:seenEvents.Count) IP externes vues" -ForegroundColor $cDim
    Write-Host ""
}