-- ============================================================
-- Agora Loader v35 — MINIMAL, pas de diagnostic à l'écran
-- Mets ce Script dans ServerScriptService (dossier AgoraAdmin)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local ServerScriptService = game:GetService("ServerScriptService")

-- ──── Cherche dans le dossier du script ET dans StarterGui ────
local dossier = script.Parent

local st  = dossier:FindFirstChild("Settings")
local cm  = dossier:FindFirstChild("Commands")
local mm  = dossier:FindFirstChild("MainModule")
local gui = dossier:FindFirstChild("AgoraAdmin")

-- Fallback: chercher dans tout ServerScriptService
if not (st and cm and mm and gui) then
	for _, obj in ipairs(ServerScriptService:GetDescendants()) do
		if obj.Name == "Settings"  and obj:IsA("ModuleScript") and not st  then st  = obj end
		if obj.Name == "Commands"  and obj:IsA("ModuleScript") and not cm  then cm  = obj end
		if obj.Name == "MainModule"and obj:IsA("ModuleScript") and not mm  then mm  = obj end
		if obj.Name == "AgoraAdmin"and obj:IsA("ScreenGui")   and not gui then gui = obj end
	end
end

-- Fallback: ScreenGui dans StarterGui
if not gui then
	gui = StarterGui:FindFirstChild("AgoraAdmin")
end

-- Vérification
if not (st and cm and mm and gui) then
	warn("[AGORA] Fichiers manquants:")
	warn("  Settings:  " .. (st  and "OK" or "MANQUANT"))
	warn("  Commands:  " .. (cm  and "OK" or "MANQUANT"))
	warn("  MainModule:" .. (mm  and "OK" or "MANQUANT"))
	warn("  ScreenGui: " .. (gui and "OK" or "MANQUANT"))
	return
end

print("[AGORA] Loader v35 — fichiers trouvés")

-- ──── 1) SystemRemotes + 26 remotes ────
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

-- RemoteEvents (23)
mk("FlyEvent","RemoteEvent"); mk("NotifEvent","RemoteEvent"); mk("AnnounceEvent","RemoteEvent")
mk("RefreshEvent","RemoteEvent"); mk("SettingsEvent","RemoteEvent"); mk("FeedbackEvent","RemoteEvent")
mk("WarnEvent","RemoteEvent"); mk("NoclipEvent","RemoteEvent"); mk("UnbanEvent","RemoteEvent")
mk("UpdateCmdEvent","RemoteEvent"); mk("LogsEvent","RemoteEvent"); mk("BubbleChatEvent","RemoteEvent")
mk("CmdBarEvent","RemoteEvent"); mk("ForceChatEvent","RemoteEvent"); mk("RevokeRoleEvent","RemoteEvent")
mk("ACAlertEvent","RemoteEvent"); mk("SuspectAddEvent","RemoteEvent"); mk("SuspectRemEvent","RemoteEvent")
mk("TicketAlertEvent","RemoteEvent"); mk("ClientACReport","RemoteEvent"); mk("ClientStateReport","RemoteEvent")
mk("EmotePanelEvent","RemoteEvent"); mk("AcToggleEvent","RemoteEvent")

-- RemoteFunctions (4)
mk("GetBansFunc","RemoteFunction"); mk("GetCmdsFunc","RemoteFunction")
mk("GetRanksFunc","RemoteFunction"); mk("SuspectListFunc","RemoteFunction")

print("[AGORA] SystemRemotes OK (" .. #sr:GetChildren() .. " remotes)")

-- ──── 2) Charger modules ────
local ok, SETTINGS = pcall(require, st)
if not ok then warn("[AGORA] ERREUR Settings: " .. tostring(SETTINGS)); return end

local ok2, commandsObj = pcall(require, cm)
if not ok2 then warn("[AGORA] ERREUR Commands: " .. tostring(commandsObj)); return end

local ok3, mainFactory = pcall(require, mm)
if not ok3 then warn("[AGORA] ERREUR MainModule require: " .. tostring(mainFactory)); return end

-- ──── 3) Lancer MainModule ────
local ok4, system = pcall(mainFactory, SETTINGS, commandsObj, script)
if not ok4 then warn("[AGORA] ERREUR MainModule(): " .. tostring(system)); return end

_G.AgoraSystem = system
print("[AGORA] MainModule lancé — system OK")

-- ──── 4) ScreenGui dans StarterGui (si pas déjà là) ────
if gui.Parent ~= StarterGui then
	local old = StarterGui:FindFirstChild("AgoraAdmin")
	if old then old:Destroy() end
	local clone = gui:Clone()
	clone.Name = "AgoraAdmin"
	clone.ResetOnSpawn = false
	clone.Parent = StarterGui
	print("[AGORA] ScreenGui → StarterGui")
else
	print("[AGORA] ScreenGui déjà dans StarterGui")
end

print("[AGORA] ✅ SYSTEM READY v35")
