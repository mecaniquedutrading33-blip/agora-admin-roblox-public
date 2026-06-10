return function(SETTINGS, commandsObj, loaderScript)

	-- [FIX v8.1.2] Placeholders _G pour éviter nil pendant l'init
	_G.Agora_getPlayerRole = function() return "Joueurs" end
	_G.Agora_isFounder     = function() return false end
	_G.Agora_isOwner       = function() return false end
	_G.Agora_isAdmin       = function() return false end
	_G.Agora_isMod         = function() return false end
	_G.Agora_isPremium     = function() return false end

	if not commandsObj then
		warn("[Agora Admin] Commands non recu!")
		return { GetCommands = function() return {} end }
	end

	local IS_PREMIUM = true  -- Licence check
	-- isFounder and getPlayerRole are global

	-- ──── FONCTIONS AUXILIAIRES ────
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterGui = game:GetService("StarterGui")
	local ServerStorage = game:GetService("ServerStorage")
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local TextService = game:GetService("TextService")
	local Lighting = game:GetService("Lighting")

	local function cloneTable(t)
		if type(t) ~= "table" then return t end
		local copy = {}
		for k, v in pairs(t) do copy[k] = cloneTable(v) end
		return copy
	end

	local function safeSet(obj, prop, val)
		pcall(function() obj[prop] = val end)
	end

	local function safeGet(obj, prop)
		local ok, v = pcall(function() return obj[prop] end)
		return ok and v or nil
	end

	-- ──── RÔLES ET HIÉRARCHIE ────
	local RANKS = SETTINGS["Rangs"] or SETTINGS.Rangs or {
		["Fondateur"]    = { Level = 6, Color = Color3.fromRGB(170, 0, 255) },
		["Co-Fondateur"]= { Level = 5, Color = Color3.fromRGB(148, 0, 211) },
		["Admin"]        = { Level = 4, Color = Color3.fromRGB(255, 0, 0) },
		["Modérateur"]   = { Level = 3, Color = Color3.fromRGB(0, 170, 255) },
		["Premium"]      = { Level = 2, Color = Color3.fromRGB(255, 215, 0) },
		["Joueurs"]      = { Level = 1, Color = Color3.fromRGB(200, 200, 200) },
	}

	local rolesHierarchy = {}
	for name, info in pairs(RANKS) do
		rolesHierarchy[name] = info.Level
	end

	-- ───_g FUNCTIONS ────
	_G.Agora_getPlayerRole = function(plr)
		if not plr then return "Joueurs" end
		local uid = tostring(plr.UserId)
		local dataStore = SETTINGS["DataStore"] or SETTINGS.DataStore
		if dataStore then
			local ok, rank = pcall(function() return dataStore:GetAsync("Rank_" .. uid) end)
			if ok and rank and RANKS[rank] then return rank end
		end
		-- Fallback: check team or attribute
		local attr = plr:GetAttribute("AgoraRank")
		if attr and RANKS[attr] then return attr end
		return "Joueurs"
	end

	_G.Agora_isFounder = function(plr)
		return _G.Agora_getPlayerRole(plr) == "Fondateur"
	end

	_G.Agora_isOwner = function(plr)
		local r = _G.Agora_getPlayerRole(plr)
		return r == "Fondateur" or r == "Co-Fondateur"
	end

	_G.Agora_isAdmin = function(plr)
		local r = _G.Agora_getPlayerRole(plr)
		return r == "Fondateur" or r == "Co-Fondateur" or r == "Admin"
	end

	_G.Agora_isMod = function(plr)
		local r = _G.Agora_getPlayerRole(plr)
		return r == "Modérateur" or r == "Admin" or r == "Co-Fondateur" or r == "Fondateur"
	end

	_G.Agora_isPremium = function(plr)
		return _G.Agora_getPlayerRole(plr) == "Premium" or _G.Agora_isMod(plr)
	end

	-- ──── SYSTEM REMOTES ────
	local SystemRemotes = ReplicatedStorage:FindFirstChild("SystemRemotes")
	if not SystemRemotes then
		SystemRemotes = Instance.new("Folder")
		SystemRemotes.Name = "SystemRemotes"
		SystemRemotes.Parent = ReplicatedStorage
	end

	local function getRemote(name, kind)
		local existing = SystemRemotes:FindFirstChild(name)
		if existing then return existing end
		local r = Instance.new(kind or "RemoteEvent")
		r.Name = name
		r.Parent = SystemRemotes
		return r
	end

	-- ──── CRÉER TOUTES LES REMOTES (même si déjà créées par Loader) ────
	local flyEvent         = getRemote("FlyEvent", "RemoteEvent")
	local notifEvent       = getRemote("NotifEvent", "RemoteEvent")
	local announceEvent    = getRemote("AnnounceEvent", "RemoteEvent")
	local refreshEvent     = getRemote("RefreshEvent", "RemoteEvent")
	local settingsEvent    = getRemote("SettingsEvent", "RemoteEvent")
	local feedbackEvent    = getRemote("FeedbackEvent", "RemoteEvent")
	local warnEvent        = getRemote("WarnEvent", "RemoteEvent")
	local noclipEvent      = getRemote("NoclipEvent", "RemoteEvent")
	local unbanEvent       = getRemote("UnbanEvent", "RemoteEvent")
	local updateCmdEvent   = getRemote("UpdateCmdEvent", "RemoteEvent")
	local logsEvent        = getRemote("LogsEvent", "RemoteEvent")
	local bubbleChatEvent  = getRemote("BubbleChatEvent", "RemoteEvent")
	local cmdBarEvent      = getRemote("CmdBarEvent", "RemoteEvent")
	local forceChatEvent   = getRemote("ForceChatEvent", "RemoteEvent")
	local revokeRoleEvent  = getRemote("RevokeRoleEvent", "RemoteEvent")
	local acAlertEvent     = getRemote("ACAlertEvent", "RemoteEvent")
	local suspectAddEvent  = getRemote("SuspectAddEvent", "RemoteEvent")
	local suspectRemEvent  = getRemote("SuspectRemEvent", "RemoteEvent")
	local ticketAlertEvent = getRemote("TicketAlertEvent", "RemoteEvent")
	local clientACReport   = getRemote("ClientACReport", "RemoteEvent")
	local clientStateReport= getRemote("ClientStateReport", "RemoteEvent")
	local emotePanelEvent  = getRemote("EmotePanelEvent", "RemoteEvent")
	local acToggleEvent    = getRemote("AcToggleEvent", "RemoteEvent")

	local getBansFunc      = getRemote("GetBansFunc", "RemoteFunction")
	local getCmdsFunc      = getRemote("GetCmdsFunc", "RemoteFunction")
	local getRanksFunc     = getRemote("GetRanksFunc", "RemoteFunction")
	local suspectListFunc  = getRemote("SuspectListFunc", "RemoteFunction")

	print("[Agora] SystemRemotes OK (" .. #SystemRemotes:GetChildren() .. " remotes)")

	-- ──── BAN INDEX (DataStore) ────
	local BanIndexStore = nil
	if SETTINGS["DataStore"] or SETTINGS.DataStore then
		BanIndexStore = SETTINGS["DataStore"] or SETTINGS.DataStore
	else
		local ok, ds = pcall(function() return game:GetService("DataStoreService"):GetDataStore("AgoraBanIndex") end)
		if ok then BanIndexStore = ds end
	end

	local function loadBanIndex()
		if not BanIndexStore then return {} end
		local ok, data = pcall(function() return BanIndexStore:GetAsync("MasterList") end)
		return (ok and data) or {}
	end

	local function saveBanIndex(list)
		if not BanIndexStore then return end
		pcall(function() BanIndexStore:SetAsync("MasterList", list) end)
	end

	-- ──── SUSPECTS (Anti-cheat) ────
	local suspects = {}
	local acLogs = {}
	local acEnabled = SETTINGS["AntiCheat"] or SETTINGS.AntiCheat or true

	local function acSendAlert(plr, reason, detail)
		if not acEnabled then return end
		table.insert(acLogs, {
			Time = os.time(),
			Player = plr and plr.Name or "N/A",
			UserId = plr and plr.UserId or 0,
			Reason = reason,
			Detail = detail or ""
		})
		if #acLogs > 500 then table.remove(acLogs, 1) end
		local data = HttpService:JSONEncode(acLogs)
		pcall(function() acAlertEvent:FireAllClients("AC_ALERT", data) end)
	end

	-- ──── COMMAND PROCESSOR ────
	local commandList = commandsObj or {}
	local commandAliases = {}

	for cmdName, cmdData in pairs(commandList) do
		if cmdData.Aliases then
			for _, alias in ipairs(cmdData.Aliases) do
				commandAliases[alias:lower()] = cmdName
			end
		end
	end

	local function findCommand(input)
		local low = input:lower()
		if commandList[low] then return low, commandList[low] end
		if commandAliases[low] then return commandAliases[low], commandList[commandAliases[low]] end
		return nil, nil
	end

	local function hasPermission(plr, cmdData)
		if not cmdData or not cmdData.Permission then return true end
		local role = _G.Agora_getPlayerRole(plr)
		local reqLevel = cmdData.Permission
		local playerLevel = rolesHierarchy[role] or 0
		if type(reqLevel) == "number" then
			return playerLevel >= reqLevel
		elseif type(reqLevel) == "string" then
			return role == reqLevel or playerLevel >= (rolesHierarchy[reqLevel] or 99)
		end
		return false
	end

	local function processCommand(plr, rawCmd)
		local args = {}
		for arg in rawCmd:gmatch("%S+") do table.insert(args, arg) end
		local cmdName = args[1] and args[1]:lower()
		if not cmdName then return false, "Commande vide" end
		table.remove(args, 1)

		local realName, cmdData = findCommand(cmdName)
		if not cmdData then return false, "Commande inconnue: " .. cmdName end
		if not hasPermission(plr, cmdData) then return false, "Permission refusée" end

		local ok, result = pcall(function()
			if cmdData.Server then
				return cmdData.Server(plr, args)
			else
				return true, "Commande serveur non définie"
			end
		end)
		return ok, result
	end

	-- ──── CONNECTER REMOTES ────
	getCmdsFunc.OnServerInvoke = function(plr)
		local list = {}
		for name, data in pairs(commandList) do
			if hasPermission(plr, data) then
				table.insert(list, {
					Name = name,
					Desc = data.Description or data.Desc or "",
					Category = data.Category or "Général",
					Aliases = data.Aliases or {}
				})
			end
		end
		return list
	end

	getBansFunc.OnServerInvoke = function(plr)
		if (rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99) > 4 then return {} end
		return loadBanIndex()
	end

	getRanksFunc.OnServerInvoke = function(plr)
		local myLvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99
		if myLvl > 5 then return {} end
		local data = {}
		for name, info in pairs(RANKS) do
			table.insert(data, { Name = name, Level = info.Level, Color = info.Color })
		end
		return data
	end

	suspectListFunc.OnServerInvoke = function(plr)
		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99
		if lvl > 4 then return {} end
		return suspects
	end

	-- ──── CONNEXION CHAT (CmdBarEvent) ────
	cmdBarEvent.OnServerEvent:Connect(function(plr, msg)
		if not msg or type(msg) ~= "string" then return end
		if msg:sub(1,1) ~= SETTINGS["Prefix"] or SETTINGS.Prefix or "/" then return end
		local cmd = msg:sub(2)
		local ok, result = processCommand(plr, cmd)
		if not ok then
			pcall(function() feedbackEvent:FireClient(plr, "ERROR", result) end)
		end
	end)

	-- ──── ANTI-CHEAT BASIQUE ────
	if acEnabled then
		RunService.Heartbeat:Connect(function()
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						-- Speed check
						local walkSpeed = hum.WalkSpeed or 16
						if walkSpeed > 100 and not _G.Agora_isAdmin(plr) then
							acSendAlert(plr, "SPEED_HACK", "WalkSpeed: " .. walkSpeed)
						end
					end
				end
			end
		end)
	end

	-- ──── CLONE ScreenGui → StarterGui (pour joueurs existants + futurs) ────
	local function setupGUIForPlayer(plr)
		local pg = plr:WaitForChild("PlayerGui")
		local existing = pg:FindFirstChild("AgoraAdmin")
		if existing then existing:Destroy() end

		local guiToGive = nil
		if loaderScript and loaderScript.Parent then
			guiToGive = loaderScript.Parent:FindFirstChild("AgoraAdmin")
		end
		-- Fallback: chercher dans StarterGui
		if not guiToGive then
			guiToGive = StarterGui:FindFirstChild("AgoraAdmin")
		end
		-- Fallback: chercher n'importe où
		if not guiToGive then
			for _, obj in ipairs(StarterGui:GetChildren()) do
				if obj:IsA("ScreenGui") and obj.Name:find("Agora") then
					guiToGive = obj
					break
				end
			end
		end

		if guiToGive then
			local clone = guiToGive:Clone()
			clone.Name = "AgoraAdmin"
			clone.ResetOnSpawn = false
			clone.Parent = pg
			print("[Agora] GUI cloné pour " .. plr.Name)
		else
			warn("[Agora] ScreenGui 'AgoraAdmin' introuvable!")
		end
	end

	Players.PlayerAdded:Connect(setupGUIForPlayer)
	for _, plr in ipairs(Players:GetPlayers()) do
		spawn(function() setupGUIForPlayer(plr) end)
	end

	print("[Agora Admin] MainModule chargé — " .. #SystemRemotes:GetChildren() .. " remotes, " .. (commandList and #commandList or 0) .. " commandes")

	-- ═══════════════════════════════════════════════════════════
	-- RETOUR EXPLICIT POUR LE LOADER (GetCommands + metadata)
	-- ═══════════════════════════════════════════════════════════
	return {
		GetCommands = function()
			local list = {}
			for name, data in pairs(commandList) do
				if type(data) == "table" then
					table.insert(list, {
						Name = name,
						Desc = data.Description or data.Desc or "",
						Category = data.Category or "Général",
						Aliases = data.Aliases or {},
						Permission = data.Permission or 1
					})
				end
			end
			return list
		end,
		GetRanks = function()
			local data = {}
			for name, info in pairs(RANKS) do
				table.insert(data, { Name = name, Level = info.Level, Color = info.Color })
			end
			return data
		end,
		ProcessCommand = processCommand,
		HasPermission = hasPermission,
		Version = "8.1.3"
	}
end