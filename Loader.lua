-- Agora Local Loader v23 — 100% Roblox Studio, no HTTP, no loadstring
local s = script.Parent

local st = s:FindFirstChild("Settings")
if not st then
	warn("[AGORA] Settings introuvable")
	return
end
local ok, SETTINGS = pcall(require, st)
if not ok then
	warn("[AGORA] Erreur Settings : " .. tostring(SETTINGS))
	return
end
print("[AGORA] Settings charge")

local cmdMod = s:FindFirstChild("Commands")
if not cmdMod then
	warn("[AGORA] Commands introuvable")
	return
end
local ok2, commandsObj = pcall(require, cmdMod)
if not ok2 then
	warn("[AGORA] Erreur Commands : " .. tostring(commandsObj))
	return
end

local cmdCount = 0
for _ in pairs(commandsObj) do cmdCount += 1 end
print("[AGORA] Commands charge — " .. cmdCount .. " commandes")

local mm = s:FindFirstChild("MainModule")
if not mm then
	warn("[AGORA] MainModule introuvable")
	return
end
local ok3, mainFactory = pcall(require, mm)
if not ok3 then
	warn("[AGORA] Erreur MainModule : " .. tostring(mainFactory))
	return
end
print("[AGORA] MainModule factory charge")

print("[AGORA] Lancement MainModule(SETTINGS, Commands, script)...")
local ok4, err = pcall(mainFactory, SETTINGS, commandsObj, script)
if not ok4 then
	warn("[AGORA] MainModule a crash : " .. tostring(err))
	return
end

print("[AGORA] SYSTEM READY — tout est local.")