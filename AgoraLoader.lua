-- ============================================================
-- Agora Admin Loader v20.0 — Hybride (proxy Supabase Emerick)
-- Crée les 27 remotes attendus par le client + charge
-- Commands/MainModule/AntiCheat via proxy Supabase (code caché)
-- ============================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local HttpService         = game:GetService("HttpService")
local StarterGui          = game:GetService("StarterGui")
local ServerScriptService = game:GetService("ServerScriptService")

-- PROXY URL — Supabase d'Emerick (agora-universelle)
local PROXY_URL = "https://hlxbqtayotwdtspkrlol.supabase.co/functions/v1/agora-universelle?file="

-- ──── 1) Trouver Settings.lua dans le dossier ────
local scriptFolder = script.Parent
local settingsFile = scriptFolder:FindFirstChild("Settings")
if not settingsFile then
	for _, child in ipairs(scriptFolder:GetDescendants()) do
		if child.Name == "Settings" and child:IsA("ModuleScript") then
			settingsFile = child
			break
		end
	end
end
if not settingsFile then
	warn("[AGORA] Settings.lua introuvable dans " .. scriptFolder.Name)
	return
end

local SETTINGS
local ok, err = pcall(function() SETTINGS = require(settingsFile) end)
if not ok then
	warn("[AGORA] Erreur require Settings.lua : " .. tostring(err))
	return
end

-- ──── 2) Créer SystemRemotes + 27 remotes ────
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

-- ──── 3) Charger Commands (proxy, fallback local) ────
local function loadCommands()
	local commandsModule = scriptFolder:FindFirstChild("Commands")
	if commandsModule then
		local okCmd, resCmd = pcall(function() return require(commandsModule) end)
		if okCmd then return resCmd or {} end
	end
	local url = PROXY_URL .. "Commands.lua&nocache=" .. tick()
	local okHttp, source = pcall(function() return HttpService:GetAsync(url, true) end)
	if okHttp and source and #source > 100 then
		local okParse, fn = pcall(function() return loadstring(source) end)
		if okParse and fn then
			local okRun, cmds = pcall(fn)
			if okRun and type(cmds) == "table" then
				return cmds
			end
		end
	end
	warn("[AGORA] Commands introuvable — table vide")
	return {}
end

local Commands = loadCommands()

-- ──── 4) Charger MainModule (proxy, fallback local) ────
local MainModule = nil
local function loadMainModule()
	local module = scriptFolder:FindFirstChild("MainModule")
	if module then
		local mainMod = require(module)
		if type(mainMod) == "function" then
			local ok, result = pcall(function() return mainMod(SETTINGS, Commands, script) end)
			if ok and result then return result end
		elseif type(mainMod) == "table" then
			if mainMod.Init then
				pcall(function() return mainMod.Init(sr, SETTINGS, Commands) end)
			end
			return mainMod
		end
	end
	local url = PROXY_URL .. "MainModule.lua&nocache=" .. tick()
	local ok, source = pcall(function() return HttpService:GetAsync(url, true) end)
	if ok and source and #source > 1000 then
		local ok2, loaderFn = pcall(function() return loadstring(source) end)
		if ok2 and loaderFn then
			local ok3, maybeFunc = pcall(function() return loaderFn() end)
			if ok3 and type(maybeFunc) == "function" then
				local ok4, result = pcall(function() return maybeFunc(SETTINGS, Commands, script) end)
				if ok4 and result then return result end
			elseif ok3 and type(maybeFunc) == "table" then
				return maybeFunc
			end
		end
	end
	warn("[AGORA] MainModule introuvable — serveur minimal actif")
	return {
		Init = function() end,
		GetCommands = function() return Commands end,
		GetRanks = function() return {} end,
		ProcessCommand = function() return nil, "MainModule absent" end,
		HasPermission = function() return false end,
		Version = "minimal"
	}
end

MainModule = loadMainModule()

-- ──── 5) GetCmdsFunc : retourner les 6 valeurs attendues par le client ────
local function buildRolesData()
	local hierarchy, order, colors = {}, {}, {}
	if MainModule and MainModule.GetRanks then
		local ok, ranks = pcall(MainModule.GetRanks)
		if ok and type(ranks) == "table" then
			for _, r in ipairs(ranks) do
				if type(r) == "table" and r.Name then
					hierarchy[r.Name] = r.Level or 6
					table.insert(order, r.Name)
					colors[r.Name] = r.Color
				end
			end
		end
	end
	-- Fallback si vide
	if #order == 0 then
		local def = { {Name="Fondateur",Level=1,Color=Color3.fromRGB(255,215,0)}, {Name="Co-Fondateur",Level=2,Color=Color3.fromRGB(255,140,0)}, {Name="Admin",Level=3,Color=Color3.fromRGB(255,0,0)}, {Name="Modérateur",Level=4,Color=Color3.fromRGB(0,255,140)}, {Name="Premium",Level=5,Color=Color3.fromRGB(0,240,255)}, {Name="Joueurs",Level=6,Color=Color3.fromRGB(200,200,200)} }
		for _, r in ipairs(def) do
			hierarchy[r.Name] = r.Level
			table.insert(order, r.Name)
			colors[r.Name] = r.Color
		end
	end
	return hierarchy, order, colors
end

local GetCmdsFunc = sr:FindFirstChild("GetCmdsFunc")
if GetCmdsFunc then
	GetCmdsFunc.OnServerInvoke = function(player)
		local cmds = Commands
		if MainModule and MainModule.GetCommands then
			local ok, res = pcall(MainModule.GetCommands)
			if ok and type(res) == "table" then cmds = res end
		end
		local role = "Joueurs"
		if _G.Agora_getPlayerRole then
			pcall(function() role = _G.Agora_getPlayerRole(player) or "Joueurs" end)
		end
		local hw = true
		local rH, rO, rC = buildRolesData()
		return cmds, role, hw, rH, rO, rC
	end
end

-- GetRanksFunc
local GetRanksFunc = sr:FindFirstChild("GetRanksFunc")
if GetRanksFunc then
	GetRanksFunc.OnServerInvoke = function()
		if MainModule and MainModule.GetRanks then
			local ok, res = pcall(MainModule.GetRanks)
			if ok then return res end
		end
		return {}
	end
end

-- ──── 6) Créer le ScreenGui + AdminLogoBtn ────
-- NOTE: un Script serveur ne peut PAS écrire le code d'un LocalScript (restriction Roblox).
-- Le client UI est chargé par un petit bootstrap LocalScript dans StarterPlayerScripts
-- (AgoraClientBootstrap) qui fetch le code via le proxy et le loadstring.
local function ensureGuiForPlayer(plr)
	local pg = plr:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("AgoraAdmin")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AgoraAdmin"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 99999
	gui.Parent = pg

	local btn = Instance.new("TextButton")
	btn.Name = "AdminLogoBtn"
	btn.Size = UDim2.new(0, 36, 0, 36)
	btn.Position = UDim2.new(1, -50, 1, -50)
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(18, 8, 32)
	btn.BackgroundTransparency = 0.2
	btn.Text = "A"
	btn.TextColor3 = Color3.fromRGB(0, 240, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 20
	btn.ZIndex = 99999
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 240, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = btn
end

Players.PlayerAdded:Connect(ensureGuiForPlayer)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(function() ensureGuiForPlayer(plr) end)
end

-- ──── 7) SettingsEvent : envoyer SETTINGS aux clients ────
local SettingsEvent = sr:FindFirstChild("SettingsEvent")
if SettingsEvent then
	local function sendSettings(plr)
		pcall(function() SettingsEvent:FireClient(plr, "UpdatePrefix", SETTINGS.Prefix or ";") end)
		pcall(function() SettingsEvent:FireClient(plr, "UpdateConfig", SETTINGS) end)
	end
	Players.PlayerAdded:Connect(sendSettings)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function() sendSettings(plr) end)
	end
end

-- ──── 8) AntiCheat optionnel depuis le proxy ────
local function loadAntiCheat()
	local acModule = scriptFolder:FindFirstChild("AntiCheat")
	if acModule then
		pcall(function() require(acModule) end)
		return
	end
	local url = PROXY_URL .. "AntiCheat.lua&nocache=" .. tick()
	local ok, source = pcall(function() return HttpService:GetAsync(url, true) end)
	if ok and source and #source > 100 then
		local ok2, fn = pcall(function() return loadstring(source) end)
		if ok2 and fn then
			pcall(fn)
		end
	end
end
task.spawn(loadAntiCheat)

print("[AGORA] ✅ SYSTEM READY v20.0 — " .. #sr:GetChildren() .. " remotes, " .. (type(Commands)=="table" and #Commands or 0) .. " commandes")
