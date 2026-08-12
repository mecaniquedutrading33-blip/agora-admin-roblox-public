-- Agora Admin Loader v19.0 - Supabase proxy for hidden server-side code
-- Place ce Script dans ServerScriptService/TON_DOSSIER/
-- Settings.lua + ScreenGui (avec LocalScript DEDANS) restent locaux
-- MainModule + Commands + AntiCheat sont charges via proxy Supabase (code cache)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local isStudio = RunService:IsStudio()

-- PROXY URL - sert les fichiers cotes depuis le repo prive
local PROXY_URL = "https://hlxbqtayotwdtspkrlol.supabase.co/functions/v1/agora-universelle?file="

-- 1) Trouver Settings.lua dans le dossier actuel
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
local ok, err = pcall(function()
	SETTINGS = require(settingsFile)
end)
if not ok then
	warn("[AGORA] Erreur require Settings.lua : " .. tostring(err))
	return
end

-- 2) CREER SystemRemotes
local SystemRemotes = ReplicatedStorage:FindFirstChild("SystemRemotes")
if not SystemRemotes then
	SystemRemotes = Instance.new("Folder")
	SystemRemotes.Name = "SystemRemotes"
	SystemRemotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, class)
	local r = SystemRemotes:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = SystemRemotes
	end
	return r
end

ensureRemote("GetCmdsFunc", "RemoteFunction")
ensureRemote("RefreshEvent", "RemoteEvent")
ensureRemote("NotifEvent", "RemoteEvent")
ensureRemote("FlyEvent", "RemoteEvent")
ensureRemote("SettingsEvent", "RemoteEvent")
ensureRemote("CmdBarEvent", "RemoteEvent")

-- 3) AUTO-CLONE DU SCREENGUI
local originalGui = scriptFolder:FindFirstChild("AgoraAdmin")
if not originalGui or not originalGui:IsA("ScreenGui") then
	for _, child in ipairs(scriptFolder:GetChildren()) do
		if child:IsA("ScreenGui") then originalGui = child; break end
	end
	if not originalGui then
		for _, child in ipairs(scriptFolder:GetDescendants()) do
			if child:IsA("ScreenGui") then originalGui = child; break end
		end
	end
end

if originalGui then
	for _, child in ipairs(StarterGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == originalGui.Name then
			child:Destroy()
		end
	end

	local cloneGui = originalGui:Clone()
	cloneGui.ResetOnSpawn = false
	cloneGui.Parent = StarterGui

	for _, plr in ipairs(Players:GetPlayers()) do
		local pg = plr:FindFirstChild("PlayerGui")
		if pg and not pg:FindFirstChild(cloneGui.Name) then
			local playClone = originalGui:Clone()
			playClone.ResetOnSpawn = false
			playClone.Parent = pg
		end
	end
else
	warn("[AGORA] ScreenGui non trouve dans " .. scriptFolder.Name)
end

-- 4) CHARGER COMMANDS DEPUIS LE PROXY (si pas local)
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
	return {}
end

local Commands = loadCommands()

-- 5) CHARGER MAINMODULE DEPUIS LE PROXY (code serveur cache)
local function loadMainModule()
	local module = scriptFolder:FindFirstChild("MainModule")
	if module then
		local mainMod = require(module)
		if type(mainMod) == "function" then
			local ok, result = pcall(function() return mainMod(SETTINGS, Commands, script) end)
			if ok and result then return result end
		elseif type(mainMod) == "table" then
			if mainMod.Init then
				pcall(function() return mainMod.Init(SystemRemotes, SETTINGS, Commands) end)
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
				local ok4, result = pcall(function()
					return maybeFunc(SETTINGS, Commands, script)
				end)
				if ok4 and result then
					return result
				end
			elseif ok3 and type(maybeFunc) == "table" then
				return maybeFunc
			end
		end
	end

	warn("[AGORA] MainModule introuvable — serveur minimal actif")
	return {
		Init = function() end,
		GetCommands = function() return Commands end,
		ExecCommand = function() return nil, "MainModule absent" end
	}
end

local MainModule = loadMainModule()

-- 6) Setup GetCmdsFunc
local GetCmdsFunc = SystemRemotes:FindFirstChild("GetCmdsFunc")
if GetCmdsFunc then
	GetCmdsFunc.OnServerInvoke = function(player)
		local cmds = Commands
		if MainModule and MainModule.GetCommands then
			local ok, res = pcall(MainModule.GetCommands)
			if ok then cmds = res or Commands end
		end
		return cmds
	end
end

-- 7) SettingsEvent: envoyer SETTINGS aux clients
local SettingsEvent = SystemRemotes:FindFirstChild("SettingsEvent")
if SettingsEvent then
	local function sendSettings(plr)
		pcall(function()
			SettingsEvent:FireClient(plr, "UpdatePrefix", SETTINGS.Prefix or ";")
		end)
		pcall(function()
			SettingsEvent:FireClient(plr, "UpdateConfig", SETTINGS)
		end)
	end
	Players.PlayerAdded:Connect(sendSettings)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function() sendSettings(plr) end)
	end
end

-- 8) AntiCheat optionnel depuis le proxy
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

Players.PlayerAdded:Connect(function(plr) end)