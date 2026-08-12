-- ============================================================
-- Agora Client LocalScript v1.0
-- Place ce LocalScript DANS le ScreenGui 'AgoraAdmin' (dossier Agora)
-- Crée le bouton AdminLogoBtn (style Roblox noir, A + A inversé)
-- PUIS charge le client UI (AgoraAdminLS.lua) via le proxy Supabase.
-- ============================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local PROXY_URL = "https://hlxbqtayotwdtspkrlol.supabase.co/functions/v1/agora-universelle?file="

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ──── Créer le bouton AdminLogoBtn (style Roblox noir) ────
local function ensureButton()
	local gui = script.Parent
	if not gui or not gui:IsA("ScreenGui") then
		warn("[AGORA] LocalScript pas dans un ScreenGui — bouton non créé")
		return nil
	end

	local existing = gui:FindFirstChild("AdminLogoBtn")
	if existing then existing:Destroy() end

	local btn = Instance.new("TextButton")
	btn.Name = "AdminLogoBtn"
	btn.Size = UDim2.new(0, 36, 0, 36)
	btn.Position = UDim2.new(0, 8, 0, 8)   -- haut-gauche, à côté des boutons Roblox
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)   -- fond noir
	btn.BackgroundTransparency = 0
	btn.Text = "A"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)   -- A blanc
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 20
	btn.ZIndex = 99999
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = btn

	return btn
end

-- ──── Charger et exécuter le client ────
local function loadClient()
	ensureButton()

	local url = PROXY_URL .. "AgoraAdminLS.lua&nocache=" .. tick()
	-- PAS de 2e arg (true) à GetAsync — le proxy renvoie du Lua brut, pas du JSON.
	local ok, source = pcall(function() return HttpService:GetAsync(url) end)
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
