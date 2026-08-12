-- ============================================================
-- Agora Client Bootstrap v1.0
-- Place ce LocalScript dans StarterPlayerScripts
-- Il charge le client UI (AgoraAdminLS.lua) via le proxy Supabase
-- et l'exécute. Le ScreenGui + AdminLogoBtn sont créés par le Loader serveur.
-- ============================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PROXY_URL = "https://hlxbqtayotwdtspkrlol.supabase.co/functions/v1/agora-universelle?file="

local LocalPlayer = Players.LocalPlayer

-- Attendre que le ScreenGui créé par le Loader serveur existe
local function waitForGui()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	for i = 1, 40 do
		local gui = pg:FindFirstChild("AgoraAdmin")
		if gui and gui:FindFirstChild("AdminLogoBtn") then
			return gui
		end
		task.wait(0.25)
	end
	return nil
end

-- Charger et exécuter le client
local function loadClient()
	local gui = waitForGui()
	if not gui then
		warn("[AGORA] ScreenGui AgoraAdmin introuvable après 10s — vérifie le Loader serveur")
		return
	end

	local url = PROXY_URL .. "AgoraAdminLS.lua&nocache=" .. tick()
	local ok, source = pcall(function() return HttpService:GetAsync(url, true) end)
	if not ok or not source or #source < 1000 then
		warn("[AGORA] Client introuvable via proxy — UI ne s'affichera pas")
		return
	end

	local okLoad, fn = pcall(function() return loadstring(source) end)
	if not okLoad or not fn then
		warn("[AGORA] Erreur loadstring client: " .. tostring(okLoad and "fn nil" or fn))
		return
	end

	local okRun, err = pcall(fn)
	if not okRun then
		warn("[AGORA] Erreur exécution client: " .. tostring(err))
	end
end

task.spawn(loadClient)
