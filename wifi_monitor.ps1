# wifi_monitor.ps1 — Surveillance WiFi temps reel v3
# Affichage CONTINU: tableau de bord qui se rafraichit a chaque cycle
# Montre l'etat actuel + evenements recents en bas
# Ctrl+C pour arreter
# SAUVEGARDER ce fichier et le lancer: powershell -ExecutionPolicy Bypass -File wifi_monitor.ps1

$ErrorActionPreference = "SilentlyContinue"

# === ETAT ===
$script:startTime = Get-Date
$script:eventLog = [System.Collections.ArrayList]@()
$script:maxLogLines = 12
$script:knownDevices = @{}
$script:seenConnections = @{}
$script:lastSSID = ""
$script:lastBSSID = ""
$script:lastSignal = -1
$script:lastChannel = -1
$script:lastState = ""
$script:lastIP = ""
$script:eventCount = 0

function Get-WiFiState {
    $output = netsh wlan show interfaces 2>&1
    $state = [ordered]@{ SSID=""; BSSID=""; State=""; Signal=""; Auth=""; Channel=""; RX=""; TX="" }
    foreach ($line in $output) {
        if ($line -match "SSID\s*:\s*(.+)") { $state.SSID = $matches[1].Trim() }
        elseif ($line -match "BSSID\s*:\s*(.+)") { $state.BSSID = $matches[1].Trim() }
        elseif ($line -match "Etat\s*:\s*(.+)|State\s*:\s*(.+)") { $state.State = ($matches[1].Trim(),$matches[2].Trim() | Where-Object {$_} | Select-Object -First 1) }
        elseif ($line -match "Signal\s*:\s*(\d+)") { $state.Signal = $matches[1].Trim() }
        elseif ($line -match "Authentification\s*:\s*(.+)|Authentication\s*:\s*(.+)") { $state.Auth = ($matches[1].Trim(),$matches[2].Trim() | Where-Object {$_} | Select-Object -First 1) }
        elseif ($line -match "Canal\s*:\s*(\d+)|Channel\s*:\s*(\d+)") { $state.Channel = ($matches[1].Trim(),$matches[2].Trim() | Where-Object {$_} | Select-Object -First 1) }
        elseif ($line -match "Reception\s*:\s*(.+)|Receive\s*:\s*(.+)") { $state.RX = ($matches[1].Trim(),$matches[2].Trim() | Where-Object {$_} | Select-Object -First 1) }
        elseif ($line -match "Transmission\s*:\s*(.+)|Transmit\s*:\s*(.+)") { $state.TX = ($matches[1].Trim(),$matches[2].Trim() | Where-Object {$_} | Select-Object -First 1) }
    }
    return $state
}

function Get-ConnectedDevices {
    $devices = @{}
    $arp = arp -a 2>&1
    foreach ($line in $arp) {
        if ($line -match "^\s*([\d\.]+)\s+([a-fA-F0-9\-]+)\s+(\w+)") {
            $ip=$matches[1]; $mac=$matches[2]
            if ($ip -ne "224.0.0.22" -and $ip -notmatch "^169\.254" -and $mac -ne "ff-ff-ff-ff-ff-ff") { $devices[$mac]=$ip }
        }
    }
    return $devices
}

function Get-CurrentIP {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -EA Stop | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object -First 1
        return $ip.IPAddress
    } catch { return "--" }
}

function Get-SignalBars {
    param([int]$signal)
    $bars = [math]::Floor($signal / 20)
    if ($bars -gt 5) { $bars = 5 }
    $filled = [string]::new([char]9608, $bars)
    $empty = [string]::new([char]9617, (5 - $bars))
    return "$filled$empty"
}

function Log-Event {
    param([string]$type, [string]$message)
    $script:eventCount++
    $ts = Get-Date -Format "HH:mm:ss"
    $tag = switch ($type) {
        "CONNECT"    { "+ CONNEXION  " }
        "DISCONNECT" { "- DECONNEXION" }
        "SIGNAL"     { "~ SIGNAL     " }
        "CHANGE"     { "! CHANGEMENT " }
        "DEVICE"     { "D APPAREIL   " }
        "INFO"       { "i INFO       " }
        default      { "* EVENEMENT  " }
    }
    $line = "[$ts] [$tag] $message"
    $script:eventLog.Insert(0, $line) | Out-Null
    if ($script:eventLog.Count -gt $script:maxLogLines) {
        $script:eventLog.RemoveAt($script:eventLog.Count - 1) | Out-Null
    }
}

function Get-ExternalConns {
    try {
        $conns = Get-NetTCPConnection -State Established -EA Stop
        $ext = $conns | Where-Object { $_.RemoteAddress -notmatch "^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" } | Select-Object -First 8
        $result = @()
        foreach ($c in $ext) {
            $proc = try { (Get-Process -Id $c.OwningProcess -EA Stop).Name } catch { "?" }
            $key = "$($c.RemoteAddress):$($c.RemotePort)"
            if (-not $script:seenConnections.ContainsKey($key)) {
                Log-Event "CONNECT" "Connexion sortante: $key [$proc]"
                $script:seenConnections[$key] = Get-Date
                if ($script:seenConnections.Count -gt 50) {
                    $sorted = $script:seenConnections.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 30
                    $script:seenConnections = @{}
                    foreach ($e in $sorted) { $script:seenConnections[$e.Key] = $e.Value }
                }
            }
            $result += "$($c.RemoteAddress):$($c.RemotePort) [$proc]"
        }
        return $result
    } catch { return @() }
}

# === BOUCLE PRINCIPALE ===
$pollInterval = 2

try {
    while ($true) {
        $now = Get-Date
        $elapsed = $now - $script:startTime
        $elapsedStr = "{0}h {1}m {2}s" -f [int]$elapsed.TotalHours, $elapsed.Minutes, $elapsed.Seconds

        # Recuperer les donnees
        $wifi = Get-WiFiState
        $devices = Get-ConnectedDevices
        $myIP = Get-CurrentIP
        $extConns = Get-ExternalConns

        # Detecter les changements
        if ($wifi.SSID -and $wifi.SSID -ne $script:lastSSID) {
            if ($script:lastSSID -eq "") { Log-Event "CONNECT" "WiFi connecte: $($wifi.SSID)" }
            else { Log-Event "CHANGE" "Reseau change: $($script:lastSSID) -> $($wifi.SSID)" }
            $script:lastSSID = $wifi.SSID; $script:lastBSSID = $wifi.BSSID; $script:lastSignal = [int]$wifi.Signal; $script:lastChannel = [int]$wifi.Channel; $script:lastState = $wifi.State
        }
        if (-not $wifi.SSID -and $script:lastSSID) {
            Log-Event "DISCONNECT" "WiFi deconnecte (etait: $($script:lastSSID))"
            $script:lastSSID = ""; $script:lastBSSID = ""; $script:lastSignal = -1
        }
        if ($wifi.BSSID -and $wifi.BSSID -ne $script:lastBSSID -and $wifi.SSID -eq $script:lastSSID -and $script:lastBSSID) {
            Log-Event "CHANGE" "Roaming BSSID change (meme reseau)"
            $script:lastBSSID = $wifi.BSSID
        }
        if ($wifi.Signal) {
            $sig = [int]$wifi.Signal
            if ($script:lastSignal -ge 0 -and [Math]::Abs($sig - $script:lastSignal) -ge 10) {
                $dir = if ($sig -gt $script:lastSignal) { "hausse" } else { "baisse" }
                Log-Event "SIGNAL" "Signal: $($script:lastSignal)% -> $sig% ($dir)"
            }
            $script:lastSignal = $sig
        }
        if ($wifi.Channel) {
            $ch = [int]$wifi.Channel
            if ($script:lastChannel -ge 0 -and $ch -ne $script:lastChannel) { Log-Event "CHANGE" "Canal: $($script:lastChannel) -> $ch" }
            $script:lastChannel = $ch
        }
        if ($wifi.State -and $wifi.State -ne $script:lastState) {
            Log-Event "CHANGE" "Etat: $($script:lastState) -> $($wifi.State)"
            $script:lastState = $wifi.State
        }
        foreach ($mac in $devices.Keys) {
            if (-not $script:knownDevices.ContainsKey($mac)) {
                Log-Event "DEVICE" "Nouvel appareil: $mac -> $($devices[$mac])"
                $script:knownDevices[$mac] = $devices[$mac]
            }
        }
        foreach ($mac in @($script:knownDevices.Keys)) {
            if (-not $devices.ContainsKey($mac)) {
                Log-Event "DEVICE" "Appareil parti: $mac"
                $script:knownDevices.Remove($mac)
            }
        }
        foreach ($mac in $devices.Keys) {
            if ($script:knownDevices.ContainsKey($mac) -and $script:knownDevices[$mac] -ne $devices[$mac]) {
                Log-Event "DEVICE" "IP change: $mac $($script:knownDevices[$mac]) -> $($devices[$mac])"
                $script:knownDevices[$mac] = $devices[$mac]
            }
        }
        if ($myIP -ne "--" -and $myIP -ne $script:lastIP) {
            if ($script:lastIP) { Log-Event "CHANGE" "IP locale: $($script:lastIP) -> $myIP" }
            $script:lastIP = $myIP
        }

        # === AFFICHAGE ===
        Clear-Host

        # En-tete
        Write-Host ""
        Write-Host "  +----------------------------------------------+" -ForegroundColor Cyan
        Write-Host "  |" -ForegroundColor Cyan -NoNewline
        Write-Host "         WIFI MONITOR - TEMPS REEL v3           " -ForegroundColor Green -NoNewline
        Write-Host "|" -ForegroundColor Cyan
        Write-Host "  +----------------------------------------------+" -ForegroundColor Cyan
        Write-Host "  |" -ForegroundColor Cyan -NoNewline
        Write-Host "  PC: $env:COMPUTERNAME  |  $elapsedStr" -ForegroundColor DarkGray -NoNewline
        $padLen = 46 - ("  PC: $env:COMPUTERNAME  |  $elapsedStr").Length
        if ($padLen -gt 0) { Write-Host (" " * $padLen) -NoNewline } else { Write-Host "" -NoNewline }
        Write-Host "|" -ForegroundColor Cyan
        Write-Host "  |" -ForegroundColor Cyan -NoNewline
        Write-Host "  Events: $($script:eventCount)  |  Ctrl+C pour arreter" -ForegroundColor Yellow -NoNewline
        $padLen2 = 46 - ("  Events: $($script:eventCount)  |  Ctrl+C pour arreter").Length
        if ($padLen2 -gt 0) { Write-Host (" " * $padLen2) -NoNewline }
        Write-Host "|" -ForegroundColor Cyan
        Write-Host "  +----------------------------------------------+" -ForegroundColor Cyan
        Write-Host ""

        # Section WiFi
        Write-Host "  +--- WIFI ---+" -ForegroundColor Cyan
        if ($wifi.SSID) {
            $sigBars = Get-SignalBars ([int]$wifi.Signal)
            $sigColor = if ([int]$wifi.Signal -ge 70) { "Green" } elseif ([int]$wifi.Signal -ge 40) { "Yellow" } else { "Red" }
            Write-Host "  | SSID    : $($wifi.SSID)" -ForegroundColor White
            Write-Host "  | BSSID   : $($wifi.BSSID)" -ForegroundColor DarkGray
            Write-Host "  | Signal  : $sigBars  $($wifi.Signal)%" -ForegroundColor $sigColor
            Write-Host "  | Canal   : $($wifi.Channel)" -ForegroundColor DarkGray
            Write-Host "  | Auth    : $($wifi.Auth)" -ForegroundColor DarkGray
            Write-Host "  | Etat    : $($wifi.State)" -ForegroundColor DarkGray
            Write-Host "  | RX/TX   : $($wifi.RX) / $($wifi.TX)" -ForegroundColor DarkGray
            Write-Host "  | IP      : $myIP" -ForegroundColor DarkGray
        } else {
            Write-Host "  | WiFi non connecte" -ForegroundColor Red
            Write-Host "  | Etat    : $($wifi.State)" -ForegroundColor DarkGray
        }
        Write-Host "  +-----------+" -ForegroundColor Cyan
        Write-Host ""

        # Section appareils
        $devCount = $devices.Count
        Write-Host "  +--- APPAREILS RESEAU ($devCount) ---+" -ForegroundColor Cyan
        if ($devCount -gt 0) {
            foreach ($mac in $devices.Keys) {
                $isNew = -not $script:knownDevices.ContainsKey($mac)
                $color = if ($isNew) { "Green" } else { "DarkGray" }
                $tag = if ($isNew) { " NOUVEAU" } else { "" }
                Write-Host "  | $mac -> $($devices[$mac])$tag" -ForegroundColor $color
            }
        } else {
            Write-Host "  | (aucun appareil detecte)" -ForegroundColor DarkGray
        }
        Write-Host "  +------------------------------+" -ForegroundColor Cyan
        Write-Host ""

        # Section connexions sortantes
        $connCount = $extConns.Count
        Write-Host "  +--- CONNEXIONS SORTANTES ($connCount) ---+" -ForegroundColor Cyan
        if ($connCount -gt 0) {
            foreach ($c in $extConns) {
                Write-Host "  | $c" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  | (aucune connexion externe)" -ForegroundColor DarkGray
        }
        Write-Host "  +-----------------------------------+" -ForegroundColor Cyan
        Write-Host ""

        # Section evenements recents
        Write-Host "  +--- EVENEMENTS RECENTS ---+" -ForegroundColor Cyan
        if ($script:eventLog.Count -gt 0) {
            foreach ($entry in $script:eventLog) {
                $color = if ($entry -match "\+ CONNEXION|D APPAREIL.*Nouvel") { "Green" }
                         elseif ($entry -match "- DECONNEXION|D APPAREIL.*parti") { "Red" }
                         elseif ($entry -match "! CHANGEMENT|~ SIGNAL") { "Yellow" }
                         else { "DarkGray" }
                Write-Host "  | $entry" -ForegroundColor $color
            }
        } else {
            Write-Host "  | (en attente d'evenements...)" -ForegroundColor DarkGray
        }
        Write-Host "  +--------------------------+" -ForegroundColor Cyan
        Write-Host ""

        Start-Sleep -Seconds $pollInterval
    }
} catch {
    Clear-Host
    Write-Host ""
    $elapsed = [math]::Round(((Get-Date) - $script:startTime).TotalMinutes, 1)
    Write-Host "  +==============================================+" -ForegroundColor Cyan
    Write-Host "  |" -ForegroundColor Cyan -NoNewline
    Write-Host "         SURVEILLANCE TERMINEE                  " -ForegroundColor Green -NoNewline
    Write-Host "|" -ForegroundColor Cyan
    Write-Host "  +==============================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Duree       : $elapsed minutes" -ForegroundColor DarkGray
    Write-Host "  Evenements  : $($script:eventCount)" -ForegroundColor DarkGray
    Write-Host "  Appareils   : $($script:knownDevices.Count) vus" -ForegroundColor DarkGray
    Write-Host "  Connexions  : $($script:seenConnections.Count) IP externes" -ForegroundColor DarkGray
    Write-Host ""
}