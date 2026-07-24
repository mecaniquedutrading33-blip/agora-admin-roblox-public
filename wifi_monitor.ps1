# wifi_monitor.ps1 — Surveillance WiFi temps reel
# Affiche les evenements WiFi en boucle: connexions, deconnexions, signal, appareils
# Pas de spam = seulement les CHANGEMENTS sont affiches
# Ctrl+C pour arreter

$ErrorActionPreference = "SilentlyContinue"

# Couleurs hacker
$bgColor = "Black"
$textColor = "Green"
$warnColor = "Yellow"
$errColor = "Red"
$infoColor = "Cyan"
$dimColor = "DarkGray"

# Etat precedent pour deduplication
$script:lastSSID = ""
$script:lastBSSID = ""
$script:lastSignal = -1
$script:lastAuth = ""
$script:lastState = ""
$script:lastIP = ""
$script:knownDevices = @{}
$script:lastChannel = -1
$script:lastRX = -1
$script:lastTX = -1
$script:lastDnsCount = -1
$script:seenEvents = @{}
$script:startTime = Get-Date

function Get-WiFiState {
    $output = netsh wlan show interfaces 2>&1
    $state = @{
        SSID = ""
        BSSID = ""
        State = ""
        Signal = ""
        Auth = ""
        Channel = ""
        RX = ""
        TX = ""
        Radio = ""
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
        elseif ($line -match "Radio\s*:\s*(.+)|Radio\s*State\s*:\s*(.+)") { $state.Radio = ($matches[1].Trim(), $matches[2].Trim() | Where-Object { $_ } | Select-Object -First 1) }
    }
    return $state
}

function Get-ConnectedDevices {
    # ARP table = appareils connectes au reseau
    $arp = arp -a 2>&1
    $devices = @{}
    foreach ($line in $arp) {
        if ($line -match "^\s*([\d\.]+)\s+([a-fA-F0-9\-]+)\s+(\w+)") {
            $ip = $matches[1]
            $mac = $matches[2]
            $type = $matches[3]
            if ($ip -ne "224.0.0.22" -and $ip -notmatch "^169\.254" -and $mac -ne "ff-ff-ff-ff-ff-ff" -and $type -ne "statique") {
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
    try {
        $dns = Get-DnsClientCache -EA Stop
        return $dns.Count
    } catch { return -1 }
}

function Write-Event {
    param([string]$type, [string]$message, [string]$color = "Green")
    $ts = Get-Date -Format "HH:mm:ss"
    $typeTag = switch ($type) {
        "CONNECT" { "[+]" }
        "DISCONNECT" { "[-]" }
        "SIGNAL" { "[~]" }
        "CHANGE" { "[!]" }
        "DEVICE" { "[D]" }
        "INFO" { "[i]" }
        "WARN" { "[?]" }
        default { "[*]" }
    }
    Write-Host "[$ts] $typeTag $message" -ForegroundColor $color
}

function Write-Header {
    Clear-Host
    Write-Host "============================================" -ForegroundColor $infoColor
    Write-Host "  WIFI MONITOR - SURVEILLANCE TEMPS REEL" -ForegroundColor $textColor
    Write-Host "  PC: $env:COMPUTERNAME | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor $dimColor
    Write-Host "  Ctrl+C pour arreter" -ForegroundColor $warnColor
    Write-Host "============================================" -ForegroundColor $infoColor
    Write-Host ""
}

# === EN-TETE ===
Write-Header
Write-Event "INFO" "Demarrage de la surveillance WiFi..." $infoColor
Write-Host ""

# Scan initial
$initState = Get-WiFiState
$initDevices = Get-ConnectedDevices
$initIP = Get-CurrentIP

if ($initState.SSID) {
    Write-Event "INFO" "WiFi connecte: $($initState.SSID) | Signal: $($initState.Signal)% | Canal: $($initState.Channel)" $textColor
    $script:lastSSID = $initState.SSID
    $script:lastBSSID = $initState.BSSID
    $script:lastSignal = [int]$initState.Signal
    $script:lastChannel = [int]$initState.Channel
    $script:lastAuth = $initState.Auth
    $script:lastState = $initState.State
} else {
    Write-Event "WARN" "WiFi non connecte ou en cours de connexion" $warnColor
    $script:lastState = $initState.State
}

if ($initIP) {
    Write-Event "INFO" "IP locale: $initIP" $dimColor
    $script:lastIP = $initIP
}

if ($initDevices.Count -gt 0) {
    Write-Event "INFO" "$($initDevices.Count) appareil(s) sur le reseau:" $textColor
    foreach ($mac in $initDevices.Keys) {
        Write-Host "       $mac -> $($initDevices[$mac])" -ForegroundColor $dimColor
        $script:knownDevices[$mac] = $initDevices[$mac]
    }
} else {
    Write-Event "INFO" "Aucun appareil detecte (ARP vide)" $dimColor
}

Write-Host ""
Write-Event "INFO" "En surveillance... (Ctrl+C pour arreter)" $infoColor
Write-Host ""

# === BOUCLE PRINCIPALE ===
$loopCount = 0
$pollInterval = 3  # secondes entre chaque scan

try {
    while ($true) {
        Start-Sleep -Seconds $pollInterval
        $loopCount++
        
        # Rafraichir l'en-tete toutes les 30 iterations (~90s)
        if ($loopCount % 30 -eq 0) {
            Write-Host ""
            Write-Host "--- [ $(Get-Date -Format 'HH:mm:ss') ] En cours... Ctrl+C pour arreter ---" -ForegroundColor $dimColor
        }
        
        # 1. Etat WiFi
        $state = Get-WiFiState
        
        # Changement de SSID (connexion a un autre reseau)
        if ($state.SSID -and $state.SSID -ne $script:lastSSID) {
            if ($script:lastSSID -eq "") {
                Write-Event "CONNECT" "WiFi connecte: $($state.SSID) (BSSID: $($state.BSSID))" $textColor
            } else {
                Write-Event "CHANGE" "Changement de reseau: $($script:lastSSID) -> $($state.SSID)" $warnColor
            }
            $script:lastSSID = $state.SSID
            $script:lastBSSID = $state.BSSID
            $script:lastSignal = [int]$state.Signal
            $script:lastChannel = [int]$state.Channel
            $script:lastAuth = $state.Auth
        }
        
        # Deconnexion WiFi
        if (-not $state.SSID -and $script:lastSSID) {
            Write-Event "DISCONNECT" "WiFi deconnecte (etait: $($script:lastSSID))" $errColor
            $script:lastSSID = ""
            $script:lastBSSID = ""
            $script:lastSignal = -1
        }
        
        # Changement de BSSID (roaming entre points d'acces)
        if ($state.BSSID -and $state.BSSID -ne $script:lastBSSID -and $state.SSID -eq $script:lastSSID -and $script:lastBSSID) {
            Write-Event "CHANGE" "Roaming: BSSID change ($($script:lastBSSID) -> $($state.BSSID)) meme SSID $($state.SSID)" $warnColor
            $script:lastBSSID = $state.BSSID
        }
        
        # Changement de signal (seuil de 10% pour eviter le spam)
        if ($state.Signal) {
            $sigVal = [int]$state.Signal
            if ($script:lastSignal -ge 0 -and [Math]::Abs($sigVal - $script:lastSignal) -ge 10) {
                $arrow = if ($sigVal -gt $script:lastSignal) { "haut" } else { "bas" }
                Write-Event "SIGNAL" "Signal: $($script:lastSignal)% -> $sigVal% ($arrow) sur $($state.SSID)" $warnColor
                $script:lastSignal = $sigVal
            } elseif ($script:lastSignal -lt 0 -and $sigVal -ge 0) {
                $script:lastSignal = $sigVal
            }
        }
        
        # Changement de canal
        if ($state.Channel) {
            $chVal = [int]$state.Channel
            if ($script:lastChannel -ge 0 -and $chVal -ne $script:lastChannel) {
                Write-Event "CHANGE" "Canal change: $($script:lastChannel) -> $chVal" $warnColor
            }
            $script:lastChannel = $chVal
        }
        
        # Changement d'etat (connecte -> deconnecte -> etc)
        if ($state.State -and $state.State -ne $script:lastState) {
            Write-Event "CHANGE" "Etat WiFi: $($script:lastState) -> $($state.State)" $warnColor
            $script:lastState = $state.State
        }
        
        # 2. Appareils connectes (ARP)
        $devices = Get-ConnectedDevices
        
        # Nouveaux appareils
        foreach ($mac in $devices.Keys) {
            if (-not $script:knownDevices.ContainsKey($mac)) {
                Write-Event "DEVICE" "Nouvel appareil: $mac -> $($devices[$mac])" $textColor
                $script:knownDevices[$mac] = $devices[$mac]
            }
        }
        
        # Appareils disparus
        foreach ($mac in @($script:knownDevices.Keys)) {
            if (-not $devices.ContainsKey($mac)) {
                Write-Event "DEVICE" "Appareil parti: $mac (etait $($script:knownDevices[$mac]))" $errColor
                $script:knownDevices.Remove($mac)
            }
        }
        
        # Changement d'IP d'un appareil existant
        foreach ($mac in $devices.Keys) {
            if ($script:knownDevices.ContainsKey($mac) -and $script:knownDevices[$mac] -ne $devices[$mac]) {
                Write-Event "DEVICE" "IP change: $mac $($script:knownDevices[$mac]) -> $($devices[$mac])" $warnColor
                $script:knownDevices[$mac] = $devices[$mac]
            }
        }
        
        # 3. Changement d'IP locale
        $currentIP = Get-CurrentIP
        if ($currentIP -and $currentIP -ne $script:lastIP) {
            Write-Event "CHANGE" "IP locale change: $($script:lastIP) -> $currentIP" $warnColor
            $script:lastIP = $currentIP
        } elseif (-not $currentIP -and $script:lastIP) {
            Write-Event "DISCONNECT" "IP locale perdue (etait $($script:lastIP))" $errColor
            $script:lastIP = ""
        }
        
        # 4. Cache DNS (nouveaux domaines resolus = nouvelle activite)
        $dnsCount = Get-DnsCacheCount
        if ($dnsCount -ge 0 -and $dnsCount -ne $script:lastDnsCount) {
            if ($script:lastDnsCount -ge 0) {
                $diff = $dnsCount - $script:lastDnsCount
                if ($diff -gt 5) {
                    Write-Event "INFO" "Activite DNS: +$diff entrees (total: $dnsCount)" $dimColor
                }
            }
            $script:lastDnsCount = $dnsCount
        }
        
        # 5. Nouvelles connexions TCP (vers IP externes)
        try {
            $conns = Get-NetTCPConnection -State Established -EA Stop
            $externalConns = $conns | Where-Object { $_.RemoteAddress -notmatch "^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" } | Select-Object -First 5
            foreach ($c in $externalConns) {
                $procName = try { (Get-Process -Id $c.OwningProcess -EA Stop).Name } catch { "?" }
                $eventKey = "$($c.RemoteAddress):$($c.RemotePort)"
                if (-not $script:seenEvents.ContainsKey($eventKey)) {
                    Write-Event "CONNECT" "Connexion sortante: $eventKey [$procName]" $dimColor
                    $script:seenEvents[$eventKey] = Get-Date
                    # Garder seulement les 50 dernieres pour ne pas exploser la memoire
                    if ($script:seenEvents.Count -gt 50) {
                        $script:seenEvents = $script:seenEvents.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 30 | ForEach-Object { $_.Key = $_.Value } | Out-Null
                    }
                }
            }
        } catch {}
    }
} catch {
    if ($_.Exception.Message -match "Ctrl\+C|Interrupted|PipelineStopped") {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor $infoColor
        Write-Host "  ARRET - Surveillance terminee" -ForegroundColor $textColor
        Write-Host "  Duree: $((Get-Date) - $script:startTime | ForEach-Object { '{0}min {1}s' -f $_.TotalMinutes.ToString('0'), $_.Seconds })" -ForegroundColor $dimColor
        Write-Host "  Appareils vus: $($script:knownDevices.Count)" -ForegroundColor $dimColor
        Write-Host "========================================" -ForegroundColor $infoColor
    } else {
        Write-Event "WARN" "Erreur: $($_.Exception.Message)" $errColor
    }
}