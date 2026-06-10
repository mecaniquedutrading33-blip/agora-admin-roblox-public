-- Agora Local Loader v24 — 100% Roblox Studio, no HTTP
-- Place as Script inside ServerScriptService/AgoraAdmin/
-- siblings: MainModule (ModuleScript), Commands (ModuleScript), Settings (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local s = script.Parent

-- ══════════════════════ SYSTEM REMOTES (client l'attend) ══════════════════════
local SystemRemotes = ReplicatedStorage:FindFirstChild("SystemRemotes")
if not SystemRemotes then
	SystemRemotes = Instance.new("Folder")
	SystemRemotes.Name = "SystemRemotes"
	SystemRemotes.Parent = ReplicatedStorage
end

local GetCmdsFunc = SystemRemotes:FindFirstChild("GetCmdsFunc")
if not GetCmdsFunc then
	GetCmdsFunc = Instance.new("RemoteFunction")
	GetCmdsFunc.Name = "GetCmdsFunc"
	GetCmdsFunc.Parent = SystemRemotes
end

local CmdBarEvent = SystemRemotes:FindFirstChild("CmdBarEvent")
if not CmdBarEvent then
	CmdBarEvent = Instance.new("RemoteEvent")
	CmdBarEvent.Name = "CmdBarEvent"
	CmdBarEvent.Parent = SystemRemotes
end

print("[AGORA] ✅ SystemRemotes créé (GetCmdsFunc + CmdBarEvent)")

-- ══════════════════════ 1) SETTINGS ══════════════════════
local st = s:FindFirstChild("Settings")
if not st then
	warn("[AGORA] ⚠ Settings introuvable")
	return
end
local ok, SETTINGS = pcall(require, st)
if not ok then
	warn("[AGORA] ⚠ Erreur Settings : " .. tostring(SETTINGS))
	return
end
print("[AGORA] ✅ Settings chargé")

-- ══════════════════════ 2) COMMANDS ══════════════════════
local cmdMod = s:FindFirstChild("Commands")
if not cmdMod then
	warn("[AGORA] ⚠ Commands introuvable")
	return
end
local ok2, commandsObj = pcall(require, cmdMod)
if not ok2 then
	warn("[AGORA] ⚠ Erreur Commands : " .. tostring(commandsObj))
	return
end
local cmdCount = 0
for _ in pairs(commandsObj) do cmdCount += 1 end
print("[AGORA] ✅ Commands chargé — " .. cmdCount .. " commandes")

-- ══════════════════════ 3) MAINMODULE ══════════════════════
local mm = s:FindFirstChild("MainModule")
if not mm then
	warn("[AGORA] ⚠ MainModule introuvable")
	return
end
local ok3, mainFactory = pcall(require, mm)
if not ok3 then
	warn("[AGORA] ⚠ Erreur MainModule : " .. tostring(mainFactory))
	return
end
print("[AGORA] ✅ MainModule factory chargée")

-- ══════════════════════ 4) LANCER ══════════════════════
print("[AGORA] 🚀 Lancement MainModule(SETTINGS, commandsObj, script)...")
local ok4, system = pcall(mainFactory, SETTINGS, commandsObj, script)
if not ok4 then
	warn("[AGORA] ❌ MainModule a crashé : " .. tostring(system))
	return
end
print("[AGORA] ✅ MainModule initialisé")

-- ══════════════════════ 5) CONNECTER GetCmdsFunc ══════════════════════
if system and system.GetCommands then
	GetCmdsFunc.OnServerInvoke = function(player)
		return system:GetCommands()
	end
	print("[AGORA] ✅ GetCmdsFunc connecté — retourne les commandes")
else
	warn("[AGORA] ⚠ MainModule ne retourne pas de GetCommands()")
end

print("[AGORA] ✨ SYSTEM READY — tout est local.")
