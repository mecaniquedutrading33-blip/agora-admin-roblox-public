-- Agora Universelle Hub - Loader
-- Coller dans exécuteur ou LocalScript dans StarterPlayerScripts
-- Auto-update: le script est fetch depuis Supabase proxy à chaque exécution

local SUPABASE_URL = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua&nocache=" .. tostring(tick())

-- Multi-fallback HTTP (game:HttpGet, HttpService, request/syn.request)
local function httpGet(url)
	-- 1) game:HttpGet (Solara, etc.)
	local ok, r = pcall(function() return game:HttpGet(url) end)
	if ok and r and r ~= "" then return r end
	-- 2) HttpService:GetAsync
	ok, r = pcall(function() return game:GetService("HttpService"):GetAsync(url) end)
	if ok and r and r ~= "" then return r end
	-- 3) request / syn.request (Synapse, Fluxus, etc.)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		ok, r = pcall(function() return req({Url=url, Method="GET"}).Body end)
		if ok and r and r ~= "" then return r end
	end
	return nil
end

print("[AGORA UNIVERSALLE] Téléchargement du script...")

local code = httpGet(SUPABASE_URL)

if not code or code == "" then
	warn("[AGORA UNIVERSALLE] ERREUR: Impossible de télécharger le script.")
	warn("[AGORA UNIVERSALLE] URL: " .. SUPABASE_URL)
	return
end

print("[AGORA UNIVERSALLE] Script téléchargé (" .. #code .. " bytes)")

local fn, err = loadstring(code)
if not fn then
	warn("[AGORA UNIVERSALLE] ERREUR de compilation: " .. tostring(err))
	return
end

print("[AGORA UNIVERSALLE] Compilation OK, exécution...")
local ok, runErr = pcall(fn)
if not ok then
	warn("[AGORA UNIVERSALLE] ERREUR d'exécution: " .. tostring(runErr))
else
	print("[AGORA UNIVERSALLE] Script chargé avec succès!")
end