-- ============================================================
-- Agora Loader v36 — Tout en LOCAL, pas de diagnostic à l'écran
-- Mets ce Script dans ServerScriptService (dossier AgoraAdmin)
-- ============================================================

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local StarterGui          = game:GetService("StarterGui")
local ServerScriptService = game:GetService("ServerScriptService")
local Players             = game:GetService("Players")

-- ──── Découverte automatique (partout dans SSS) ────
local st, cm, mm, gui

for _, obj in ipairs(ServerScriptService:GetDescendants()) do
	if obj.Name == "Settings"  and obj:IsA("ModuleScript") and not st  then st  = obj end
	if obj.Name == "Commands"  and obj:IsA("ModuleScript") and not cm  then cm  = obj end
	if obj.Name == "MainModule"and obj:IsA("ModuleScript") and not mm  then mm  = obj end
	if obj.Name == "AgoraAdmin"and obj:IsA("ScreenGui")   and not gui then gui = obj end
end

-- Fallback : ScreenGui peut être dans StarterGui (Emerick le place là parfois)
if not gui then
	gui = StarterGui:FindFirstChild("AgoraAdmin")
end

if not (st and cm and mm and gui) then
	warn("[AGORA] Fichiers manquants:")
	warn("  Settings:  "  .. (st  and "OK" or "MANQUANT"))
	warn("  Commands:  "  .. (cm  and "OK" or "MANQUANT"))
	warn("  MainModule:"  .. (mm  and "OK" or "MANQUANT"))
	warn("  ScreenGui: "  .. (gui and "OK" or "MANQUANT"))
	return
end

print("[AGORA] Loader v36 — fichiers trouvés")

-- ──── 1) SystemRemotes + 27 remotes ────
local sr = ReplicatedStorage:FindFirstChild("SystemRemotes")
if not sr then
	sr = Instance.new("Folder")
	sr.Name = "SystemRemotes"
	sr.Parent = ReplicatedStorage
end

local function mk(n, t)
	if not sr:FindFirstChild(n) then
		local r = Instance.new(t)
		r.Name = n
		r.Parent = sr
	end
end

-- 23 RemoteEvents
mk("FlyEvent","RemoteEvent"); mk("NotifEvent","RemoteEvent"); mk("AnnounceEvent","RemoteEvent")
mk("RefreshEvent","RemoteEvent"); mk("SettingsEvent","RemoteEvent"); mk("FeedbackEvent","RemoteEvent")
mk("WarnEvent","RemoteEvent"); mk("NoclipEvent","RemoteEvent"); mk("UnbanEvent","RemoteEvent")
mk("UpdateCmdEvent","RemoteEvent"); mk("LogsEvent","RemoteEvent"); mk("BubbleChatEvent","RemoteEvent")
mk("CmdBarEvent","RemoteEvent"); mk("ForceChatEvent","RemoteEvent"); mk("RevokeRoleEvent","RemoteEvent")
mk("ACAlertEvent","RemoteEvent"); mk("SuspectAddEvent","RemoteEvent"); mk("SuspectRemEvent","RemoteEvent")
mk("TicketAlertEvent","RemoteEvent"); mk("ClientACReport","RemoteEvent"); mk("ClientStateReport","RemoteEvent")
mk("EmotePanelEvent","RemoteEvent"); mk("AcToggleEvent","RemoteEvent")

-- 4 RemoteFunctions
mk("GetBansFunc","RemoteFunction"); mk("GetCmdsFunc","RemoteFunction")
mk("GetRanksFunc","RemoteFunction"); mk("SuspectListFunc","RemoteFunction")

print("[AGORA] SystemRemotes OK (" .. #sr:GetChildren() .. " remotes)")

-- ──── 2) Charger Settings ────
local ok, SETTINGS = pcall(require, st)
if not ok then warn("[AGORA] ERREUR Settings: " .. tostring(SETTINGS)); return end

-- ──── 3) Charger Commands ────
local ok2, commandsObj = pcall(require, cm)
if not ok2 then warn("[AGORA] ERREUR Commands: " .. tostring(commandsObj)); return end
if type(commandsObj) ~= "table" then
	commandsObj = {}
	warn("[AGORA] Commands retourné " .. type(commandsObj) .. ", table vide utilisée")
end

-- ──── 4) Charger MainModule ────
local ok3, mainFactory = pcall(require, mm)
if not ok3 then warn("[AGORA] ERREUR MainModule require: " .. tostring(mainFactory)); return end

-- ──── 5) Lancer MainModule avec arguments corrects ────
local ok4, system = pcall(mainFactory, SETTINGS, commandsObj, script)
if not ok4 then warn("[AGORA] ERREUR MainModule(): " .. tostring(system)); return end

-- Vérifier que MainModule a retourné GetCommands
if type(system) ~= "table" or not system.GetCommands then
	warn("[AGORA] MainModule ne retourne pas GetCommands — vérifie que MainModule se termine par 'return {...}'")
	return
end

_G.AgoraSystem = system
print("[AGORA] MainModule lancé — system OK")

-- ──── 6) Clone UI → StarterGui (pour que LocalScript tourne) ────
if gui.Parent ~= StarterGui then
	local old = StarterGui:FindFirstChild("AgoraAdmin")
	if old then old:Destroy() end
	local clone = gui:Clone()
	clone.Name = "AgoraAdmin"
	clone.ResetOnSpawn = false
	clone.Parent = StarterGui
	print("[AGORA] ScreenGui → StarterGui (clone OK)")
else
	print("[AGORA] ScreenGui déjà dans StarterGui")
end

-- ──── 7) GUI pour joueurs déjà connectés ────
if system.setupGUIForPlayer then
	for _, plr in ipairs(Players:GetPlayers()) do
		pcall(function() system.setupGUIForPlayer(plr) end)
	end
end

print("[AGORA] ✅ SYSTEM READY v36")
