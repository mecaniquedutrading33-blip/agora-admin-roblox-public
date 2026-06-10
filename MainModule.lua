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

		return

	end

	local IS_PREMIUM = true  -- Licence check
	-- isFounder and getPlayerRole are global

	local AC_ENABLED = SETTINGS and SETTINGS.AntiCheatEnabled
	if AC_ENABLED == nil then AC_ENABLED = true end  -- défaut = actif

	local scriptRef = loaderScript or script

	local commandRegistry = commandsObj

	local Players             = game:GetService("Players")

	local ReplicatedStorage   = game:GetService("ReplicatedStorage")

	local DataStoreService    = game:GetService("DataStoreService")

	local Lighting            = game:GetService("Lighting")

	local HttpService         = game:GetService("HttpService")

	local MarketplaceService  = game:GetService("MarketplaceService")

	local InsertService       = game:GetService("InsertService")

	local PolicyService       = game:GetService("PolicyService")

	local StarterGui          = game:GetService("StarterGui")

	local BanStore       = DataStoreService:GetDataStore("AgoraAdmin_Bans_Final")

	local BanIndexStore  = DataStoreService:GetDataStore("AgoraAdmin_Index_Final")

	local PermsStore     = DataStoreService:GetDataStore("AgoraAdmin_Perms_Final")

	local SettingsStore  = DataStoreService:GetDataStore("AgoraAdmin_Global_Final")

	local RanksStore     = DataStoreService:GetDataStore("AgoraAdmin_Ranks_Final")

	local SuspectStore   = DataStoreService:GetDataStore("AgoraAdmin_Suspects")

	local ThemeStore     = DataStoreService:GetDataStore("AgoraAdmin_Theme")

	local remotes = ReplicatedStorage:FindFirstChild("SystemRemotes")

	if not remotes then

		remotes = Instance.new("Folder")

		remotes.Name = "SystemRemotes"

		remotes.Parent = ReplicatedStorage

	end

	local function getRemote(name, class)

		local r = remotes:FindFirstChild(name)

		if r and r.ClassName ~= class then

			r:Destroy()

			r = nil

		end

		if not r then

			r = Instance.new(class)

			r.Name = name

			r.Parent = remotes

		end

		return r

	end

	-- ════════════════════════════════════════════════════════════════════════

	-- API PUBLIQUE pour les jeux clients (preserver les mecaniques natives)

	-- ════════════════════════════════════════════════════════════════════════

	-- Les scripts serveur du jeu client peuvent fire ces BindableEvents pour

	-- empecher l'AC de bloquer leurs teleports/portails/lifts/jump pads:

	--

	--   local API = game:GetService("ServerScriptService"):WaitForChild("AgoraACServerAPI")

	--   API.WhitelistPlayer:Fire(player, "teleport", 2)  -- whitelist 2s

	--   -- types valides: "fly" / "noclip" / "speed" / "teleport"

	--   -- duration en secondes (si nil = whitelist permanent jusqu'a Unwhitelist)

	--   API.UnwhitelistPlayer:Fire(player, "teleport")   -- retirer manuellement

	--

	-- Auto-whitelists deja gerees par l'AC (rien a faire cote jeu):

	--   - Post-respawn: 2s sur tous types

	--   - Touched sur Part nommee teleport/portal/warp/spawn/pad/checkpoint/lift/elevator/door: 1s

	--   - Touched sur Part avec Attribute AgoraSafeTeleport=true: 1s

	--   - TP > 200 studs (probablement portail map-to-map): 1.5s sans strike

	--   - Seated/Climbing/Swimming/Ragdoll: skip detections

	--   - MoveDirection.Magnitude < 0.05 (conveyor): skip speed check

	-- ════════════════════════════════════════════════════════════════════════

	local ServerScriptService = game:GetService("ServerScriptService")

	local acServerAPI = ServerScriptService:FindFirstChild("AgoraACServerAPI")

	if not acServerAPI then

		acServerAPI = Instance.new("Folder")

		acServerAPI.Name = "AgoraACServerAPI"

		acServerAPI.Parent = ServerScriptService

	end

	local acWhitelistBindable = acServerAPI:FindFirstChild("WhitelistPlayer")

	if not acWhitelistBindable then

		acWhitelistBindable = Instance.new("BindableEvent")

		acWhitelistBindable.Name = "WhitelistPlayer"

		acWhitelistBindable.Parent = acServerAPI

	end

	local acUnwhitelistBindable = acServerAPI:FindFirstChild("UnwhitelistPlayer")

	if not acUnwhitelistBindable then

		acUnwhitelistBindable = Instance.new("BindableEvent")

		acUnwhitelistBindable.Name = "UnwhitelistPlayer"

		acUnwhitelistBindable.Parent = acServerAPI

	end

	local flyEvent        = getRemote("FlyEvent",       "RemoteEvent")

	local notifEvent      = getRemote("NotifEvent",      "RemoteEvent")

	local announceEvent   = getRemote("AnnounceEvent",   "RemoteEvent")

	local refreshEvent    = getRemote("RefreshEvent",    "RemoteEvent")

	local settingsEvent   = getRemote("SettingsEvent",   "RemoteEvent")

	local feedbackEvent   = getRemote("FeedbackEvent",   "RemoteEvent")

	local warnEvent       = getRemote("WarnEvent",       "RemoteEvent")

	local noclipEvent     = getRemote("NoclipEvent",     "RemoteEvent")

	local getBansFunc     = getRemote("GetBansFunc",     "RemoteFunction")

	local unbanEvent      = getRemote("UnbanEvent",      "RemoteEvent")

	local getCmdsFunc     = getRemote("GetCmdsFunc",     "RemoteFunction")

	local updateCmdEvent  = getRemote("UpdateCmdEvent",  "RemoteEvent")

	local logsEvent       = getRemote("LogsEvent",       "RemoteEvent")

	local bubbleChatEvent = getRemote("BubbleChatEvent", "RemoteEvent")

	local cmdBarEvent     = getRemote("CmdBarEvent",     "RemoteEvent")

	local forceChatEvent  = getRemote("ForceChatEvent",  "RemoteEvent")

	local getRanksFunc    = getRemote("GetRanksFunc",    "RemoteFunction")

	local revokeEvent     = getRemote("RevokeRoleEvent", "RemoteEvent")

	local emotePanelEvent = getRemote("EmotePanelEvent", "RemoteEvent")

	local getEmotesFunc   = getRemote("GetEmotesFunc",   "RemoteFunction")

	local playEmoteEvent  = getRemote("PlayEmoteEvent",  "RemoteEvent")

	-- Nouveaux remotes pour Anti-Cheat + Mod Menu + Tickets

	local acAlertEvent     = getRemote("ACAlertEvent",     "RemoteEvent")

	local ticketSubmitEvent= getRemote("TicketSubmitEvent", "RemoteEvent")

	local ticketAlertEvent = getRemote("TicketAlertEvent", "RemoteEvent")

	local ticketListFunc   = getRemote("TicketListFunc",   "RemoteFunction")

	local ticketClaimEvent = getRemote("TicketClaimEvent", "RemoteEvent")

	local modCamEvent      = getRemote("ModCamEvent",      "RemoteEvent")

	local modTPEvent       = getRemote("ModTPEvent",       "RemoteEvent")

	local suspectAddEvent  = getRemote("SuspectAddEvent",  "RemoteEvent")

	local suspectRemEvent  = getRemote("SuspectRemEvent",  "RemoteEvent")

	local suspectListFunc  = getRemote("SuspectListFunc",  "RemoteFunction")

	local themePrefFunc    = getRemote("ThemePrefFunc",    "RemoteFunction")

	-- [AC CLIENT] Remote pour reception alertes camera depuis client (FREECAM, VIEW_OTHER)

	local clientACReport   = getRemote("ClientACReport",   "RemoteEvent")

	-- [AC HEARTBEAT] Remote pour state continu fly/noclip depuis client (evite que la

	-- whitelist serveur expire pendant que le joueur utilise encore une commande admin

	-- comme ;fly. Le client envoie {fly=bool, noclip=bool} toutes les 2s. Le serveur

	-- maintient la whitelist tant que l'etat est ON, et l'enleve si stale > 5s.

	local clientStateReport = getRemote("ClientStateReport", "RemoteEvent")

	-- [BACKROOM] Remote pour le bouton SORTIR client-side. Le serveur fire OPEN/CLOSE,

	-- le LS affiche/cache le bouton. Le LS fire le serveur quand le joueur clique → exit.

	-- Note: _backroomSessions est local et declare PLUS BAS (~ligne 561). On ne peut pas

	-- le referencer via closure ici (resolu comme global = nil). On delegue a

	-- _G._AgoraUnbackroom qui fait son propre check (no-op si pas de session active).

	local backroomGuiEvent = getRemote("BackroomGuiEvent", "RemoteEvent")

	backroomGuiEvent.OnServerEvent:Connect(function(plr)

		if not plr or not plr:IsA("Player") then return end

		if _G._AgoraUnbackroom then

			pcall(function() _G._AgoraUnbackroom(plr) end)

		end

	end)

	-- [AC GLOBAL TOGGLE] Switch ON/OFF global de l'anti-cheat (Fondateur uniquement).

	-- Quand desactive: TOUS les checks AC sont skip. Notif globale a chaque toggle.

	-- Default au boot: ON (pas de persistance, le serveur reset au restart).

	local acGloballyDisabled = false
	-- Restaurer etat persiste
	task.spawn(function()
		local _ok, _saved = pcall(function() return SettingsStore:GetAsync("AgoraAC_Disabled") end)
		if _ok and _saved == true then
			acGloballyDisabled = true
			print("[Agora AC] Etat restaure: DESACTIVE (DataStore)")
		end
	end)

	_G._AgoraACGlobalDisabled = function() return acGloballyDisabled end

	local acToggleEvent = getRemote("AcToggleEvent", "RemoteEvent")

	acToggleEvent.OnServerEvent:Connect(function(plr, payload)

		if not plr or not plr:IsA("Player") then return end

		local plrRole = _G.Agora_getPlayerRole(plr)

		local lvl = rolesHierarchy[plrRole] or 99

		local isOwner = (game.CreatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId)

		print(string.format("[Agora AC] Toggle reçu de %s (role=%s lvl=%d owner=%s payload=%s)",

			plr.Name, tostring(plrRole), lvl, tostring(isOwner), tostring(payload and payload.disabled)))

		local newState = (type(payload) == "table" and payload.disabled == true) or false

		if newState == acGloballyDisabled then

			print("[Agora AC] Toggle: deja dans cet etat ("..tostring(newState)..")")

			-- Re-fire client pour sync UI quand meme (au cas ou le client est desync)

			pcall(function() acToggleEvent:FireClient(plr, {disabled = acGloballyDisabled}) end)

			return

		end

		acGloballyDisabled = newState
		AC_ENABLED = not acGloballyDisabled  -- Sync avec setting global
		pcall(function() SettingsStore:SetAsync("AgoraAC_Disabled", acGloballyDisabled) end)
		print("[Agora AC] Toggle APPLIQUE: acGloballyDisabled = "..tostring(acGloballyDisabled))

		-- Notif globale visible par tous (announceEvent = top notif + warnEvent = banner

		-- plein ecran, double pour garantir que tous voient — avant: que announceEvent

		-- et certains joueurs ne le voyaient pas si leur GUI etait dans un etat bizarre)

		local _msg = acGloballyDisabled

			and ("🛡️ Anti-cheat DESACTIVE par "..plr.Name)

			or  ("✅ Anti-cheat REACTIVE par "..plr.Name)

		print("[Agora AC]", _msg)

		pcall(function()

			if announceEvent then

				if acGloballyDisabled then

					announceEvent:FireAllClients("ANTICHEAT", "🛡️", "Anti-cheat DESACTIVE par "..plr.Name..".")

				else

					announceEvent:FireAllClients("ANTICHEAT", "✅", "Anti-cheat REACTIVE par "..plr.Name..".")

				end

			end

		end)

		-- Fallback warnEvent: banner plein ecran chez tous

		pcall(function()

			if warnEvent then

				for _, _p in ipairs(Players:GetPlayers()) do

					pcall(function() warnEvent:FireClient(_p, _msg) end)

				end

			end

		end)

		-- Sync bouton chez tous les Fondateurs/Gerants (pour que le switch UI matche).

		-- Toujours fire au plr qui a demande (cas: owner du jeu sans role Fondateur match).

		pcall(function() acToggleEvent:FireClient(plr, {disabled = acGloballyDisabled}) end)

		for _, p in ipairs(Players:GetPlayers()) do

			if p ~= plr then

				local pLvl = rolesHierarchy[_G.Agora_getPlayerRole(p)] or 99

				if pLvl <= 2 then

					pcall(function() acToggleEvent:FireClient(p, {disabled = acGloballyDisabled}) end)

				end

			end

		end

	end)

	-- ════════════════════════════════════════════════════════════════════════

	-- [ZOMBIFY] Module : transforme en zombie vert + propagation par toucher

	-- Touché = infecté. Mort ou ;re = guérison. Tous infectés = guérison globale.

	-- ════════════════════════════════════════════════════════════════════════

	local _zombieData = {}  -- [userId] = {origColors={[part]=color}, origMat={[part]=mat}, origSpeed, origJp, animTrack, touchConn, deathConn}

	local _unzombifyPlayer  -- forward decl

	local _zombifyPlayer

	_unzombifyPlayer = function(plr)

		local data = _zombieData[plr.UserId]

		if not data then return end

		_zombieData[plr.UserId] = nil

		plr:SetAttribute("_IsZombie", false)

		local char = plr.Character

		if char then

			for p, c in pairs(data.origColors or {}) do

				if p.Parent then pcall(function() p.Color = c end) end

			end

			for p, m in pairs(data.origMat or {}) do

				if p.Parent then pcall(function() p.Material = m end) end

			end

			local hum = char:FindFirstChildOfClass("Humanoid")

			if hum then

				hum.WalkSpeed = data.origSpeed or 16

				hum.JumpPower = data.origJp or 50

				-- [FIX ZOMBIFY V2] Restaurer l'ORIGINAL HipHeight (R15 default ≈ 2,

				-- R6 default = 0). Forcer 0 enfonce les R15 dans le sol.

				if data.origHipHeight ~= nil then hum.HipHeight = data.origHipHeight end

			end

		end

		pcall(function() if data.touchConn then data.touchConn:Disconnect() end end)

		pcall(function() if data.deathConn then data.deathConn:Disconnect() end end)

		pcall(function() if data.animTrack then data.animTrack:Stop() end end)

		pcall(function() if data.growlSound then data.growlSound:Stop() data.growlSound:Destroy() end end)

	end

	_zombifyPlayer = function(plr)

		if _zombieData[plr.UserId] then return end

		local char = plr.Character

		local hum = char and char:FindFirstChildOfClass("Humanoid")

		local hrp = char and char:FindFirstChild("HumanoidRootPart")

		if not (hum and hrp) then return end

		-- [FIX ZOMBIFY V2] Sauvegarder l'origHipHeight pour le restaurer au unzombify.

		-- R15 default = 2, R6 default = 0. Forcer 0 sur R15 = corps moitie dans le sol.

		local data = {

			origColors = {},

			origMat = {},

			origSpeed = hum.WalkSpeed,

			origJp = hum.JumpPower,

			origHipHeight = hum.HipHeight,

		}

		for _, p in ipairs(char:GetDescendants()) do

			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then

				data.origColors[p] = p.Color

				data.origMat[p] = p.Material

				p.Color = Color3.fromRGB(70, 120, 55)

				p.Material = Enum.Material.Slate

			end

		end

		hum.WalkSpeed = 9

		hum.JumpPower = 22

		-- [FIX ZOMBIFY V2] NE PAS toucher HipHeight - laisser celui de l'avatar.

		-- Avant: hum.HipHeight = 0 → enfonce R15 dans le sol (default R15=2).

		plr:SetAttribute("_IsZombie", true)

		-- [FIX] Animation retiree (cassait le control + camera shift). Ralentir via WalkSpeed.

		-- Sons zombie GRR en boucle (depuis le HRP, audible aux alentours)

		pcall(function()

			local snd = Instance.new("Sound", hrp)

			snd.Name = "ZombieGrowl"

			snd.SoundId = "rbxassetid://5810753638"  -- growl loop classique

			snd.Volume = 1.2

			snd.Looped = true

			snd.RollOffMaxDistance = 60

			snd.RollOffMode = Enum.RollOffMode.InverseTapered

			snd:Play()

			data.growlSound = snd

		end)

		-- Touch contagion

		data.touchConn = hrp.Touched:Connect(function(hit)

			local h = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")

			if h then

				local tPlr = Players:GetPlayerFromCharacter(hit.Parent)

				if tPlr and not _zombieData[tPlr.UserId] then

					_zombifyPlayer(tPlr)

					pcall(function() announceEvent:FireAllClients("ZOMBIE", "🧟", tPlr.Name.." infecté !") end)

				end

			end

		end)

		-- Mort = un-zombify

		data.deathConn = hum.Died:Connect(function()

			_unzombifyPlayer(plr)

		end)

		_zombieData[plr.UserId] = data

		-- Notification d'infection + check global

		local total = #Players:GetPlayers()

		local zombies = 0

		for _ in pairs(_zombieData) do zombies = zombies + 1 end

		pcall(function() announceEvent:FireAllClients("ZOMBIE", "🧟", "Infectés: "..zombies.."/"..total) end)

		if zombies >= total and total > 1 then

			task.delay(3, function()

				for _, p in ipairs(Players:GetPlayers()) do _unzombifyPlayer(p) end

				pcall(function() announceEvent:FireAllClients("ZOMBIE", "✅", "Tous guéris !") end)

			end)

		end

	end

	-- Cleanup quand un joueur quitte

	Players.PlayerRemoving:Connect(function(plr)

		if _zombieData[plr.UserId] then _unzombifyPlayer(plr) end

	end)

	-- Expose pour usage dans le elseif handler + refresh

	_G._AgoraZombify = _zombifyPlayer

	_G._AgoraUnzombify = _unzombifyPlayer

	-- ════════════════════════════════════════════════════════════════════════

	-- [BACKROOM] Module : envoie un joueur dans un labyrinthe horror a -2000 studs

	-- avec un monstre qui le poursuit. Sortie : toucher la sortie rouge, mort,

	-- TTL 180s, ou ;unbackroom <nom>. Cmd Fondateur uniquement.

	--

	-- Pourquoi natif et pas standalone ? Le standalone Backroom.lua dans corrections/

	-- s'appuyait sur Script.Source = clientSrc qui est read-only a runtime en Roblox

	-- live (settable seulement en Studio/plugin). Donc le bouton SORTIR ne s'injectait

	-- jamais. Maintenant tout passe par les remotes Agora deja distribues.

	-- ════════════════════════════════════════════════════════════════════════

	_G._AgoraGetPlayerRole = getPlayerRole

	_G._AgoraRolesHierarchy = rolesHierarchy

	_G._AgoraInjectCmd = function(name, data)

		if commandRegistry and type(name) == "string" and type(data) == "table" then

			commandRegistry[name] = data

		end

	end

	-- ════════════════════════════════════════════════════════════════════════

	-- Forward-declare acSendAlert (defini dans le bloc IS_PREMIUM plus bas)

	local acSendAlert

	-- Handler : kick auto pour FREECAM / VIEW_OTHER chez les non-staff

	local _clientACCooldown = {}

	clientACReport.OnServerEvent:Connect(function(plr, reason, details)

		if not plr or not reason then return end

		local _lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		print(string.format("[Agora AC] ClientReport recu: %s (%s) lvl=%d details=%s",

			plr.Name, tostring(reason), _lvl, tostring(details)))

		if _lvl <= 4 then

			print("[Agora AC] Skip kick: "..plr.Name.." est staff (lvl "..tostring(_lvl).."). Alerte uniquement.")

			task.spawn(function()

				if acSendAlert then acSendAlert(plr, reason.."_STAFF", details or "") end

			end)

			return

		end

		if type(reason) ~= "string" or #reason > 40 then return end

		local kickReasons = {FREECAM=true, VIEW_OTHER=true, CAMERA_DETACHED=true}

		local alertOnlyReasons = {ESP=true, AIMBOT=true}

		if not kickReasons[reason] and not alertOnlyReasons[reason] then return end

		local key = plr.UserId .. "_" .. reason

		local now = os.clock()

		if _clientACCooldown[key] and (now - _clientACCooldown[key]) < 10 then return end

		_clientACCooldown[key] = now

		task.spawn(function()

			if acSendAlert then acSendAlert(plr, reason, details or "") end

		end)

		if kickReasons[reason] then

			warn(string.format("[Agora AC] %s detecte chez %s — KICK", reason, plr.Name))

			task.delay(0.5, function()

				if plr and plr.Parent then

					plr:Kick("\nAgora Admin\n\nComportement camera inhabituel detecte.\nSi c'est une erreur, rejoins le serveur.")

				end

			end)

		end

	end)

	-- Lookup table : nom de commande → animation ID (validés R15)

	local EMOTE_IDS = {

		-- Défaut R15 (garantis stables, fonctionnent pour tous)

		wave      = 507770239,

		dance     = 507771019,

		dance2    = 507776043,

		dance3    = 507777268,

		laugh     = 507770818,

		cheer     = 507770677,

		point     = 507770453,

		-- Catalogue (animation IDs validés, pas catalog IDs)

		salute    = 3360688855,

		shrug     = 3334392772,

		hype      = 3695333486,

		floss     = 5917459365,

		shuffle   = 4349242221,

		toprock   = 3361276673,

		shy       = 3337978742,

		celebrate = 3338097973,

		superhero = 5104344710,

	}

	-- Garder la liste pour GetEmotesFunc (compat)

	local EMOTES = {}

	for name, id in pairs(EMOTE_IDS) do

		table.insert(EMOTES, {Name = name:sub(1,1):upper()..name:sub(2), Id = id})

	end

	table.sort(EMOTES, function(a,b) return a.Name < b.Name end)

	local rolesHierarchy = {}

	local rolesOrder = {}

	local roleColors = {}

	if SETTINGS.CustomRoles then

		local sortedRoles = {}

		for _, v in pairs(SETTINGS.CustomRoles) do table.insert(sortedRoles, v) end

		table.sort(sortedRoles, function(a,b) return a.Level < b.Level end)

		for _, v in ipairs(sortedRoles) do

			rolesHierarchy[v.Name] = v.Level

			table.insert(rolesOrder, v.Name)

			roleColors[v.Name] = v.Color or Color3.new(1,1,1)

		end

		-- [FIX ALIAS RÔLES] Commands.lua utilise "Staffs" et "Joueurs" (pluriel)

		-- mais d'anciennes Settings.lua chez les clients ont "Staff"/"Joueur" (singulier).

		-- Sans cet alias: les commandes Role="Staffs" disparaissent du panel CMDS car

		-- "Staffs" n'est pas dans rolesOrder, et le check serveur reqLvl=99 (rolesHierarchy

		-- nil pour "Staffs") signifie reqLvl effectif a 99, plus aucun blocage par grade.

		-- On enregistre les 2 variantes dans rolesHierarchy + roleColors pour les checks,

		-- ET on normalise commandRegistry[cmd].Role pour matcher EXACTEMENT le nom present

		-- dans rolesOrder (utilise par le filter panel CMDS).

		local _aliases = {

			["Staff"]   = "Staffs",

			["Staffs"]  = "Staff",

			["Joueur"]  = "Joueurs",

			["Joueurs"] = "Joueur",

		}

		for srcName, dstName in pairs(_aliases) do

			if rolesHierarchy[srcName] and not rolesHierarchy[dstName] then

				rolesHierarchy[dstName] = rolesHierarchy[srcName]

				roleColors[dstName] = roleColors[srcName]

			end

		end

		-- Normalise commandRegistry[cmd].Role vers le nom present dans rolesOrder

		-- (= ce qui s'affiche dans l'UI et qu'on filtre pour le panel)

		local _orderSet = {}

		for _, n in ipairs(rolesOrder) do _orderSet[n] = true end

		-- Niveaux par defaut des roles standards (pour remapper les commandes orphelines)

		local _defaultLevels = {

			["Fondateur"]=1, ["Gérant"]=2, ["Staffs"]=3, ["Staff"]=3,

			["Modérateur"]=4, ["Moderateur"]=4, ["VIP"]=5, ["Joueurs"]=6, ["Joueur"]=6

		}

		for cmd, cdata in pairs(commandRegistry) do

			local r = cdata.Role

			if r and not _orderSet[r] then

				-- Le role n'est pas dans rolesOrder → bascule sur l'alias si dispo

				local alt = _aliases[r]

				if alt and _orderSet[alt] then

					cdata.Role = alt

				else

					-- Role introuvable (supprime ou renomme) : remap vers le role existant le plus proche par niveau

					local targetLvl = _defaultLevels[r] or 4

					local bestName, bestDist = nil, math.huge

					for _, roleName in ipairs(rolesOrder) do

						local dist = math.abs((rolesHierarchy[roleName] or 99) - targetLvl)

						if dist < bestDist then bestDist = dist; bestName = roleName end

					end

					if bestName then cdata.Role = bestName end

				end

			end

		end

	else

		rolesHierarchy = {["Fondateur"]=1,["G�rant"]=2,["Staffs"]=3,["Mod�rateur"]=4,["VIP"]=5,["Joueurs"]=6}

		rolesOrder     = {"Fondateur","G�rant","Staffs","Mod�rateur","VIP","Joueurs"}

		roleColors     = {

			["Fondateur"]=Color3.fromRGB(241,196,15), ["G�rant"]=Color3.fromRGB(230,126,34),

			["Staffs"]=Color3.fromRGB(52,152,219),    ["Mod�rateur"]=Color3.fromRGB(46,204,113),

			["VIP"]=Color3.fromRGB(155,89,182),        ["Joueurs"]=Color3.fromRGB(149,165,166)

		}

	end

	local defaultRole = (rolesOrder and rolesOrder[#rolesOrder]) or "Joueurs"

	_G.Agora_isFounder = function(plr)

		if not SETTINGS.Founders then return false end

		local name = type(plr) == "string" and plr or plr.Name

		local userId = type(plr) ~= "string" and plr.UserId or nil

		for _, v in pairs(SETTINGS.Founders) do

			if type(v) == "number" and userId and v == userId then return true end

			if type(v) == "string" and string.lower(v) == string.lower(name) then return true end

		end

	_G.Agora_getPlayerRole = function(plr)

		-- [FIX v8.1.3] Safety: rolesOrder peut être nil pendant l'init rapide
		if not rolesOrder or #rolesOrder == 0 then return "Joueurs" end

		if _G.Agora_isFounder(plr) then return rolesOrder[1] end

		if tempRanks[plr.UserId] and rolesHierarchy[tempRanks[plr.UserId]] then

			return tempRanks[plr.UserId]

		end

	local vipRoleName = SETTINGS.VIP_Role_Name or "VIP"

	local activeJails    = {}

	local activeLoops    = {}

	local commandLogs    = {}

	local feedbackLimits = {}

	local tempRanks      = {}

	-- [FEATURE UNDO] Pile des actions annulables (max 20 par admin)

	local undoStacks     = {}

	local function pushUndo(plr, cmdName, data)

		if not plr then return end

		local uid = plr.UserId

		undoStacks[uid] = undoStacks[uid] or {}

		table.insert(undoStacks[uid], 1, {

			Cmd = cmdName,

			Data = data,

			Time = os.time(),

			AdminName = plr.Name,

		})

		-- Max 20 entrées par admin

		while #undoStacks[uid] > 20 do

			table.remove(undoStacks[uid])

		end

	end

	-- ------------------------------------------------

	-- HELPERS

	-- ------------------------------------------------

		if SETTINGS.FounderNames then

			for _, v in pairs(SETTINGS.FounderNames) do

				if string.lower(v) == string.lower(name) then return true end

			end

		end

		return false

	end

		local attr = plr:GetAttribute("Role")

		if attr and rolesHierarchy[attr] then return attr end

		if plr.Team and rolesHierarchy[plr.Team.Name] then return plr.Team.Name end

		return defaultRole

	end

	local function checkVIPGamepass(plr)

		if _G.Agora_getPlayerRole(plr) ~= defaultRole then return end

		local success, hasPass = pcall(function()

			return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, SETTINGS.VIP_Pass_ID)

		end)

		if success and hasPass and rolesHierarchy[vipRoleName] then

			plr:SetAttribute("Role", vipRoleName)

		end

	end

	local function addToBanIndex(uid, name)

		local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

		list = list or {}

		list[tostring(uid)] = name

		pcall(function() BanIndexStore:SetAsync("MasterList", list) end)

	end

	-- ------------------------------------------------

	-- RÉSOLUTION JOUEUR HORS-LIGNE (par pseudo)

	-- ------------------------------------------------

	local function resolveOfflinePlayer(name)

		local search = name:lower()

		-- D'abord chercher dans RanksStore (match partiel, admins connus)

		local s, rankList = pcall(function() return RanksStore:GetAsync("AllRanks") end)

		if s and rankList then

			for uid, info in pairs(rankList) do

				if info.Name then

					local infoLow = info.Name:lower()

					if (#search >= 2 and infoLow:sub(1, #search) == search) or infoLow == search then

						return {UserId = tonumber(uid), Name = info.Name}

					end

				end

			end

		end

		-- Chercher dans BanIndex (joueurs bannis connus)

		local s2, banList = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

		if s2 and banList then

			for uid, bName in pairs(banList) do

				if type(bName) == "string" then

					local bLow = bName:lower()

					if (#search >= 2 and bLow:sub(1, #search) == search) or bLow == search then

						return {UserId = tonumber(uid), Name = bName}

					end

				end

			end

		end

		-- Sinon essayer Roblox API (nom exact uniquement)

		local ok, userId = pcall(function()

			return Players:GetUserIdFromNameAsync(name)

		end)

		if ok and userId then

			local ok2, realName = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)

			return {UserId = userId, Name = (ok2 and realName) or name}

		end

		return nil

	end

	-- Commandes qui fonctionnent sur un joueur hors-ligne

	local OFFLINE_COMMANDS = {ban=true, pban=true, permrank=true, unban=true}

	local function executeOffline(plr, cmd, target, arg3, rest)

		local myLvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		local cmdData = commandRegistry[cmd]

		if not cmdData then return end

		local reqLvl = rolesHierarchy[cmdData.Role] or 99

		if myLvl > reqLvl then

			notifEvent:FireClient(plr, "Niveau insuffisant.")

			return

		end

		-- Vérifier immunité fondateur

		local targetIsFounder = false

		if SETTINGS.Founders then

			for _, v in pairs(SETTINGS.Founders) do

				if type(v) == "number" and v == target.UserId then targetIsFounder = true break end

			end

		end

		if SETTINGS.FounderNames then

			for _, v in pairs(SETTINGS.FounderNames) do

				if v:lower() == target.Name:lower() then targetIsFounder = true break end

			end

		end

		if targetIsFounder and not _G.Agora_isFounder(plr) then

			notifEvent:FireClient(plr, "Immunité absolue de ce Créateur.")

			return

		end

		if cmd == "ban" then

			local d = tonumber(arg3) or 60

			local exp = os.time() + d*60

			pcall(function() BanStore:SetAsync(tostring(target.UserId), {Type="Temp",Expire=exp,Reason=rest}) end)

			addToBanIndex(target.UserId, target.Name)

			notifEvent:FireClient(plr, target.Name.." banni "..d.."min (hors-ligne).")

			table.insert(commandLogs, 1, {User=plr.Name, Cmd="[OFFLINE] ban "..target.Name.." "..d.."m", Time=os.date("%H:%M:%S")})

			if #commandLogs > 200 then table.remove(commandLogs) end

		elseif cmd == "pban" then

			pcall(function() BanStore:SetAsync(tostring(target.UserId), {Type="Perm",Reason=arg3 or rest}) end)

			addToBanIndex(target.UserId, target.Name)

			notifEvent:FireClient(plr, target.Name.." ban permanent (hors-ligne).")

			table.insert(commandLogs, 1, {User=plr.Name, Cmd="[OFFLINE] pban "..target.Name, Time=os.date("%H:%M:%S")})

			if #commandLogs > 200 then table.remove(commandLogs) end

		elseif cmd == "permrank" then

			local roleToGive = ""

			local reqRole = (arg3 or ""):lower()

			for rName in pairs(rolesHierarchy) do

				if rName:lower() == reqRole then roleToGive = rName break end

			end

			if roleToGive ~= "" then

				task.spawn(function()

					local ok, list = pcall(function() return RanksStore:GetAsync("AllRanks") end)

					list = list or {}

					list[tostring(target.UserId)] = {Name=target.Name, Role=roleToGive}

					pcall(function() RanksStore:SetAsync("AllRanks", list) end)

				end)

				notifEvent:FireClient(plr, target.Name.." → "..roleToGive.." (hors-ligne, effectif au prochain join).")

				table.insert(commandLogs, 1, {User=plr.Name, Cmd="[OFFLINE] permrank "..target.Name.." "..roleToGive, Time=os.date("%H:%M:%S")})

				if #commandLogs > 200 then table.remove(commandLogs) end

			else

				notifEvent:FireClient(plr, "Grade invalide.")

			end

		elseif cmd == "unban" then

			pcall(function() BanStore:RemoveAsync(tostring(target.UserId)) end)

			local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

			if s and list then

				list[tostring(target.UserId)] = nil

				pcall(function() BanIndexStore:SetAsync("MasterList", list) end)

			end

			notifEvent:FireClient(plr, target.Name.." deban (hors-ligne).")

			table.insert(commandLogs, 1, {User=plr.Name, Cmd="[OFFLINE] unban "..target.Name, Time=os.date("%H:%M:%S")})

			if #commandLogs > 200 then table.remove(commandLogs) end

		end

	end

	-- ------------------------------------------------

	-- GUI SETUP — ScreenGui dans le Loader, clone vers StarterGui

	-- ------------------------------------------------

	local StarterGui = game:GetService("StarterGui")

	-- Search StarterGui first (Loader puts ScreenGui there)
	local guiToGive = StarterGui:FindFirstChild("AgoraAdmin")

	-- Fallback: search the Loader scriptRef itself
	if not guiToGive then

		guiToGive = scriptRef:FindFirstChild("AgoraAdmin")

	end

	if not guiToGive then

		for _, child in pairs(scriptRef:GetDescendants()) do

			if child:IsA("ScreenGui") then

				guiToGive = child

				break

			end

		end

	end

	if not guiToGive then

		warn("[Agora Admin] AgoraAdmin introuvable dans le Loader!")

		return

	end

	local existingGui = StarterGui:FindFirstChild("AgoraAdmin")

	if existingGui then existingGui:Destroy() end

	guiToGive:Clone().Parent = StarterGui

	print("[Agora Admin] GUI clonee dans StarterGui.")

	-- ------------------------------------------------

	-- DATASTORES INIT

	-- ------------------------------------------------

	task.spawn(function()

		local s, saved = pcall(function() return PermsStore:GetAsync("Final_Config") end)

		if s and saved then

			for cmd, data in pairs(saved) do

				if commandRegistry[cmd] then

					commandRegistry[cmd].Role   = data.Role

					commandRegistry[cmd].Others = data.Others

				end

			end

		end

		local s2, pref = pcall(function() return SettingsStore:GetAsync("Prefix") end)

		if s2 and pref then SETTINGS.Prefix = pref end

	end)

	-- ------------------------------------------------

	-- REMOTES

	-- ------------------------------------------------

	getCmdsFunc.OnServerInvoke = function(plr)

		local hasWebhook = (SETTINGS.WebhookURL and SETTINGS.WebhookURL ~= "" and SETTINGS.WebhookURL ~= "TON_WEBHOOK_ICI")

		return commandRegistry, _G.Agora_getPlayerRole(plr), hasWebhook, rolesHierarchy, rolesOrder, roleColors

	end

	updateCmdEvent.OnServerEvent:Connect(function(plr, cmd, nRole, nOthers)

		if rolesHierarchy[_G.Agora_getPlayerRole(plr)] ~= 1 then return end

		if commandRegistry[cmd] then

			commandRegistry[cmd].Role   = nRole

			commandRegistry[cmd].Others = nOthers

			pcall(function() PermsStore:SetAsync("Final_Config", commandRegistry) end)

			refreshEvent:FireAllClients(commandRegistry)

		end

	end)

	feedbackEvent.OnServerEvent:Connect(function(plr, msg)

		if not SETTINGS.WebhookURL or SETTINGS.WebhookURL == "TON_WEBHOOK_ICI" or SETTINGS.WebhookURL == "" or #msg < 5 then return end

		local today = os.date("%Y-%m-%d")

		if not feedbackLimits[plr.UserId] or feedbackLimits[plr.UserId].Date ~= today then

			feedbackLimits[plr.UserId] = {Date=today, Count=0}

		end

		if feedbackLimits[plr.UserId].Count >= 10 then

			notifEvent:FireClient(plr, "Limite atteinte : 10 feedbacks max/jour.")

			return

		end

		feedbackLimits[plr.UserId].Count = feedbackLimits[plr.UserId].Count + 1

		local data = {["embeds"]={{

			["title"]="FEEDBACK AGORA",

			["description"]="```"..msg.."```",

			["color"]=16753920,

			["fields"]={

				{["name"]="Joueur", ["value"]=plr.Name.." ("..plr.UserId..")"},

				{["name"]="Grade",  ["value"]=_G.Agora_getPlayerRole(plr)},

				{["name"]="Uses",   ["value"]=feedbackLimits[plr.UserId].Count.."/10"}

			}

		}}}

		pcall(function() HttpService:PostAsync(SETTINGS.WebhookURL, HttpService:JSONEncode(data)) end)

	end)

	settingsEvent.OnServerEvent:Connect(function(plr, act, val)

		if rolesHierarchy[_G.Agora_getPlayerRole(plr)] ~= 1 then return end

		if act == "SetPrefix" then

			SETTINGS.Prefix = val

			pcall(function() SettingsStore:SetAsync("Prefix", val) end)

			settingsEvent:FireAllClients("UpdatePrefix", val)

		end

	end)

	getBansFunc.OnServerInvoke = function(plr)

		if (rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99) > 4 then return {} end

		local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

		if not s or list == nil then return {} end

		local full = {}

		for id, name in pairs(list) do

			local s2, d = pcall(function() return BanStore:GetAsync(id) end)

			if s2 and d then

				table.insert(full, {UserId=id, Name=name, Type=d.Type, Reason=d.Reason, Expire=d.Expire})

			end

		end

		return full

	end

	unbanEvent.OnServerEvent:Connect(function(plr, uid)

		if (rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99) > 4 then return end

		pcall(function() BanStore:RemoveAsync(tostring(uid)) end)

		local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

		if s and list then

			list[tostring(uid)] = nil

			pcall(function() BanIndexStore:SetAsync("MasterList", list) end)

		end

	end)

	getEmotesFunc.OnServerInvoke = function()

		return EMOTES

	end

	-- [FIX] Validation : emoteId doit être numérique ET dans EMOTE_IDS (whitelist)

	-- + permission VIP minimum (sinon n'importe qui peut spammer animations custom)

	playEmoteEvent.OnServerEvent:Connect(function(plr, emoteId)

		emoteId = tonumber(emoteId)

		if not emoteId then return end

		-- Whitelist : seuls les IDs définis dans EMOTE_IDS sont acceptés

		local validId = false

		for _, id in pairs(EMOTE_IDS) do

			if id == emoteId then validId = true break end

		end

		if not validId then return end

		-- Permission VIP+ (level 5 ou moins)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 5 then return end

		local char = plr.Character

		local hum  = char and char:FindFirstChildOfClass("Humanoid")

		if not hum then return end

		local anim = Instance.new("Animation")

		anim.AnimationId = "rbxassetid://" .. tostring(emoteId)

		local animator = hum:FindFirstChildOfClass("Animator")

		local track = animator and animator:LoadAnimation(anim) or hum:LoadAnimation(anim)

		track:Play()

	end)

	getRanksFunc.OnServerInvoke = function(plr)

		local myLvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if myLvl > 5 then return {} end

		local data = {}

		for _, v in ipairs(Players:GetPlayers()) do

			local tRole = _G.Agora_getPlayerRole(v)

			local tLvl  = rolesHierarchy[tRole] or 99

			local isTmp = tempRanks[v.UserId] ~= nil

			local ageStr = nil

			if myLvl <= 4 then

				if tLvl == 1 and myLvl > 1 then

					ageStr = "Masqu�"

				else

					local ok, pol = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(v) end)

					if ok and pol then

						ageStr = pol.AreAdsAllowed and "13+" or "< 13"

					else

						ageStr = "?"

					end

				end

			end

			table.insert(data, {

				UserId    = v.UserId,

				Name      = v.Name,

				Role      = tRole,

				Age       = ageStr,

				CanRevoke = (myLvl == 1 and tLvl > 1),

				Online    = true,

				IsTempRank = isTmp,

			})

		end

		if myLvl <= 5 then

			local ok, rankList = pcall(function() return RanksStore:GetAsync("AllRanks") end)

			if ok and rankList then

				local onlineIds = {}

				for _, v in ipairs(Players:GetPlayers()) do onlineIds[v.UserId] = true end

				for uid, info in pairs(rankList) do

					local numId = tonumber(uid)

					if not onlineIds[numId] then

						table.insert(data, {

							UserId     = numId,

							Name       = info.Name,

							Role       = info.Role,

							Age        = nil,

							CanRevoke  = (myLvl == 1 and (rolesHierarchy[info.Role] or 99) > 1),

							Online     = false,

							IsTempRank = false,

						})

					end

				end

			end

		end

		return data

	end

	revokeEvent.OnServerEvent:Connect(function(plr, targetId)

		-- [FIX REVOKE FEEDBACK] Avant: silent return si pas Fondateur, Pascal ne savait

		-- pas si l'event arrivait. Maintenant notif explicite + accepte tous les Fondateurs

		-- (hardcoded OU permranked) en passant par getPlayerRole.

		local _myRole = _G.Agora_getPlayerRole(plr)

		local _myLvl = rolesHierarchy[_myRole] or 99

		if _myLvl ~= 1 then

			pcall(function() notifEvent:FireClient(plr, "Revoke refuse: tu n'es pas Fondateur (role detecte: "..tostring(_myRole)..")") end)

			return

		end

		local targetPlr = Players:GetPlayerByUserId(targetId)

		if targetPlr and _G.Agora_isFounder(targetPlr) then

			notifEvent:FireClient(plr, "Impossible de r�voquer un Cr�ateur absolu.")

			return

		end

		if tempRanks[targetId] then tempRanks[targetId] = nil end

		local AdminRankEvent = ReplicatedStorage:FindFirstChild("AdminChangeRank")

		if AdminRankEvent then

			AdminRankEvent:Fire(targetId, defaultRole)

		end

		-- [FIX REVOKE COMPLET] Toujours faire les actions ci-dessous, meme si AdminRankEvent

		-- existe. Avant: si AdminRankEvent existait on skip le SetAttribute → l'attribute

		-- gardait l'ancien Role, le joueur conservait ses access commandes.

		if targetPlr then

			targetPlr:SetAttribute("Role", defaultRole)

			-- Aussi clear la Team si elle correspond a un role (ex: ;team Bob Fondateur l'a

			-- mis dans une Team "Fondateur" → getPlayerRole renvoie "Fondateur" via plr.Team.Name)

			pcall(function()

				if targetPlr.Team and rolesHierarchy[targetPlr.Team.Name] and targetPlr.Team.Name ~= defaultRole then

					targetPlr.Team = nil

				end

			end)

			-- Force le client a refresh son cmdRegistry/myRole pour que les commandes

			-- bloquees disparaissent visuellement immediatement

			pcall(function() refreshEvent:FireClient(targetPlr, commandRegistry) end)

			-- Notif au revoque

			pcall(function() notifEvent:FireClient(targetPlr, "Ton grade a ete revoque. Tu es de nouveau Joueur.") end)

		end

		task.spawn(function()

			local ok, list = pcall(function() return RanksStore:GetAsync("AllRanks") end)

			list = list or {}

			local key = tostring(targetId)

			if list[key] then

				-- [FIX REVOKE] Avant: list[key].Role = defaultRole → entry restait dans

				-- la liste avec Role=Joueurs, et le client filtre via _isDefault check.

				-- Si pour une raison quelconque le filter ne s'applique pas, le joueur

				-- restait visible. Maintenant: SUPPRESSION complete de l'entry → garanti

				-- de ne plus apparaitre dans Ranks et ne plus etre traite comme rank actif.

				list[key] = nil

				pcall(function() RanksStore:SetAsync("AllRanks", list) end)

			end

		end)

		notifEvent:FireClient(plr, "Grade r�voqu� avec succ�s.")

	end)

	-- ------------------------------------------------

	-- ANTI-CHEAT WHITELIST (référence, remplie après chargement AC)

	-- ------------------------------------------------

	local acWhitelistFn   = function() end

	local acUnwhitelistFn = function() end

	local function acApplyWhitelist(cmd, targets, plr)

		-- Pour TP : c'est le CALLER qui se teleporte, pas la cible

		if (cmd == "tp") and plr then

			acWhitelistFn(plr, "teleport", true)

			acWhitelistFn(plr, "speed", true)

			-- Track le moment du dernier ;tp pour pas que le delay d'un ancien ;tp

			-- ecrase la whitelist d'un nouveau ;tp tape entretemps.

			plr:SetAttribute("_LastTpAt", tick())

			task.delay(10, function()

				if plr and plr.Parent then

					-- Si un ;tp plus recent a ete fait, ne pas unwhitelist

					local last = plr:GetAttribute("_LastTpAt") or 0

					if tick() - last >= 9.5 then

						acUnwhitelistFn(plr, "teleport")

						acUnwhitelistFn(plr, "speed")

					end

				end

			end)

		end

		for _, t in pairs(targets) do

			if cmd == "fly" then

				-- Fly admin: whitelist UNIQUEMENT fly. Le noclip / speed cheats restent

				-- detectes (le speed check skip auto en l'air, donc pas de faux positif).

				acWhitelistFn(t, "fly", true)

			elseif cmd == "unfly" then

				acUnwhitelistFn(t, "fly")

			elseif cmd == "noclip" then

				-- Noclip admin: whitelist UNIQUEMENT noclip. Le fly cheat reste detecte

				-- meme si le perso flotte un peu pendant le noclip admin (skip transitions).

				acWhitelistFn(t, "noclip", true)

			elseif cmd == "clip" then

				acUnwhitelistFn(t, "noclip")

			elseif cmd == "speed" or cmd == "ws" then

				acWhitelistFn(t, "speed", true)

				task.delay(5, function() acUnwhitelistFn(t, "speed") end)

			elseif cmd == "bring" or cmd == "bringall" then

				acWhitelistFn(t, "teleport", true)

				acWhitelistFn(t, "speed", true)

				task.delay(5, function()

					acUnwhitelistFn(t, "teleport")

					acUnwhitelistFn(t, "speed")

				end)

			elseif cmd == "god" or cmd == "godall" then

				acWhitelistFn(t, "speed", true)

			elseif cmd == "fling" or cmd == "slap" or cmd == "freecandy" or cmd == "zap" then

				acWhitelistFn(t, "speed", true)

				acWhitelistFn(t, "fly", true)

				task.delay(8, function()

					acUnwhitelistFn(t, "speed")

					-- Ne PAS unwhitelist fly/noclip si le client utilise encore activement

					-- la commande (heartbeat le signale). Evite que ;fly admin actif soit

					-- ecrase 8s apres un ;slap/;fling. Helper expose dans bloc heartbeat.

					if not (_G._AgoraClientStateActive and _G._AgoraClientStateActive(t, "fly")) then

						acUnwhitelistFn(t, "fly")

					end

				end)

			elseif cmd == "freeze" or cmd == "freezeall" then

				acWhitelistFn(t, "noclip", true) -- freeze = HRP anchored, sinon AC détecte ANCHOR HACK

			elseif cmd == "thaw" or cmd == "thawall" then

				acUnwhitelistFn(t, "noclip")

			elseif cmd == "invisible" then

				acWhitelistFn(t, "noclip", true)

			elseif cmd == "visible" then

				acUnwhitelistFn(t, "noclip")

			-- Jail : teleporte la cible dans une cage

			elseif cmd == "jail" then

				acWhitelistFn(t, "teleport", true)

				acWhitelistFn(t, "noclip", true)

				task.delay(5, function()

					acUnwhitelistFn(t, "teleport")

					-- Preserve noclip si le client l'utilise activement (cf. heartbeat)

					if not (_G._AgoraClientStateActive and _G._AgoraClientStateActive(t, "noclip")) then

						acUnwhitelistFn(t, "noclip")

					end

				end)

			-- Unjail : libere la cible

			elseif cmd == "unjail" then

				acWhitelistFn(t, "teleport", true)

				acWhitelistFn(t, "speed", true)

				task.delay(4, function()

					acUnwhitelistFn(t, "teleport")

					acUnwhitelistFn(t, "speed")

				end)

			-- Punt/kick physique : lance le joueur

			elseif cmd == "punt" or cmd == "kick" then

				acWhitelistFn(t, "speed", true)

				acWhitelistFn(t, "fly", true)

				task.delay(6, function()

					acUnwhitelistFn(t, "speed")

					-- Preserve fly si le client l'utilise activement (cf. heartbeat)

					if not (_G._AgoraClientStateActive and _G._AgoraClientStateActive(t, "fly")) then

						acUnwhitelistFn(t, "fly")

					end

				end)

			end

		end

	end

	-- ------------------------------------------------

	-- EXECUTE

	-- ------------------------------------------------

	local function execute(plr, cmd, targets, arg3, rest)

		-- Token OK anti-cheat : whitelist AVANT exécution

		acApplyWhitelist(cmd, targets, plr)

		if cmd == "shutdown" then

			for _, v in pairs(Players:GetPlayers()) do v:Kick("\nSERVEUR FERM� PAR LE FONDATEUR") end

			return

		elseif cmd == "time" then

			Lighting.ClockTime = tonumber(arg3) or 12

			return

		elseif cmd == "fog" then

			Lighting.FogEnd = tonumber(arg3) or 100000

			return

		elseif cmd == "music" then

			for _, v in pairs(workspace:GetChildren()) do if v.Name == "AdminMusic" then v:Destroy() end end

			local s = Instance.new("Sound", workspace)

			s.Name="AdminMusic" s.SoundId="rbxassetid://"..tostring(arg3) s.Volume=1 s.Looped=true s:Play()

			return

		elseif cmd == "stopmusic" then

			for _, v in pairs(workspace:GetChildren()) do if v.Name == "AdminMusic" then v:Destroy() end end

			return

		elseif cmd == "clear" or cmd == "clr" then

			for _, v in pairs(workspace:GetChildren()) do

				if v:IsA("Tool") or v:IsA("HopperBin") or v.Name == "AdminMusic"

					or string.match(v.Name, "^Jail_") or v.Name == "AdminRocket" or v.Name == "AdminZap" then

					v:Destroy()

				end

			end

			activeJails = {}

			notifEvent:FireClient(plr, "Serveur nettoyé.")

			return

		-- [TEAM] Créer une équipe (no-target)

		elseif cmd == "newteam" then

			local Teams = game:GetService("Teams")

			local teamName = arg3 or ""

			if teamName == "" then notifEvent:FireClient(plr, "Usage: ;newteam <nom> <r,g,b>") return end

			for _, tm in pairs(Teams:GetTeams()) do

				if tm.Name:lower() == teamName:lower() then

					notifEvent:FireClient(plr, "Équipe déjà existante.")

					return

				end

			end

			local r, g, b = 128, 128, 128

			if rest and rest ~= "" then

				local parts = string.split(rest, ",")

				r = tonumber(parts[1]) or r

				g = tonumber(parts[2]) or g

				b = tonumber(parts[3]) or b

			end

			local newTeam = Instance.new("Team")

			newTeam.Name = teamName

			newTeam.TeamColor = BrickColor.new(Color3.fromRGB(r, g, b))

			newTeam.AutoAssignable = false

			newTeam.Parent = Teams

			notifEvent:FireClient(plr, "Équipe '"..teamName.."' créée.")

			return

		-- [TEAM] Supprimer une équipe (no-target)

		elseif cmd == "removeteam" then

			local Teams = game:GetService("Teams")

			local teamName = arg3 or ""

			if teamName == "" then notifEvent:FireClient(plr, "Usage: ;removeteam <nom>") return end

			for _, tm in pairs(Teams:GetTeams()) do

				if tm.Name:lower() == teamName:lower() then

					for _, pp in pairs(Players:GetPlayers()) do

						if pp.Team == tm then pp.Team = nil end

					end

					tm:Destroy()

					notifEvent:FireClient(plr, "Équipe '"..tm.Name.."' supprimée.")

					return

				end

			end

			notifEvent:FireClient(plr, "Équipe '"..teamName.."' introuvable.")

			return

		end

		local myLvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if cmd == "kickall" then

			for _, v in pairs(Players:GetPlayers()) do

				local tLvl = rolesHierarchy[_G.Agora_getPlayerRole(v)] or 99

				if tLvl > myLvl then

					v:Kick("\nKICK ALL\nRaison: "..(arg3 or rest or "Aucune"))

				end

			end

			return

		end

		for _, t in pairs(targets) do

			-- [FIX STABILITÉ] Vérifier que le joueur cible n'a pas quitté entre-temps

			if not t or t.Parent ~= Players then continue end

			local tLvl = rolesHierarchy[_G.Agora_getPlayerRole(t)] or 99

			if plr ~= t then

				if _G.Agora_isFounder(t) and not _G.Agora_isFounder(plr) then

					-- [FIX PROTECTION CREATEUR] Avant: TOUTES les cmds bloquees → la fondatrice

					-- permrank ne pouvait rien faire (pas meme freecandy/fly/wave) sur les

					-- Fondateurs hardcoded. Maintenant: seulement les cmds DESTRUCTIVES sont

					-- protegees (ban/pban/kick/permrank/temprank). Les cmds fun ou de gameplay

					-- (freecandy, fly, wave, etc.) passent — la fondatrice a recu son rang

					-- volontairement par Pascal, donc elle peut interagir normalement.

					local _protectedCmds = {

						["ban"]=true, ["pban"]=true, ["kick"]=true,

						["permrank"]=true, ["temprank"]=true, ["unban"]=true,

						["jail"]=true, ["loopkill"]=true, ["loopfling"]=true,

					}

					if _protectedCmds[cmd] then

						notifEvent:FireClient(plr, "Action protegee : ce Createur original ne peut etre rank/ban/kick que par un autre Createur original (Settings.lua).")

						continue

					end

					-- Sinon: laisser passer (cmds fun/gameplay)

				end

				if myLvl == 1 and tLvl == 1 then

					local blocked = {["ban"]=true,["pban"]=true,["kick"]=true}

					if blocked[cmd] then

						notifEvent:FireClient(plr, "Action interdite entre Fondateurs.")

						continue

					end

				else

					if tLvl < myLvl then

						notifEvent:FireClient(plr, "Immunit� : Grade sup�rieur.")

						continue

					end

					if tLvl == myLvl and myLvl > 1 then

						notifEvent:FireClient(plr, "Immunit� : m�me grade.")

						continue

					end

				end

				if commandRegistry[cmd] and not commandRegistry[cmd].Others and myLvl > 1 then

					notifEvent:FireClient(plr, "Commande self uniquement.")

					continue

				end

			end

			-- Commandes qui n'ont pas besoin du character (avant le check root/hum)

			if cmd == "unban" then

				pcall(function() BanStore:RemoveAsync(tostring(t.UserId)) end)

				local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

				if s and list then

					list[tostring(t.UserId)] = nil

					pcall(function() BanIndexStore:SetAsync("MasterList", list) end)

				end

				notifEvent:FireClient(plr, t.Name.." deban avec succes.")

				continue

			end

			local char = t.Character

			local hum  = char and char:FindFirstChildOfClass("Humanoid")

			local root = char and char:FindFirstChild("HumanoidRootPart")

			if not root or not hum then continue end

			if cmd == "tp" then

				-- [FIX TP] Avant: ne supportait QUE ;tp <playerA> <playerB> (2 targets).

				-- Maintenant aussi ;tp <player> (1 target) -> le caller TP sur player.

				if targets[2] and targets[2].Character then

					char:PivotTo(targets[2].Character:GetPivot() * CFrame.new(0,0,3))

				elseif plr and plr ~= t and plr.Character then

					local _pHrp = plr.Character:FindFirstChild("HumanoidRootPart")

					if _pHrp then

						plr.Character:PivotTo(t.Character:GetPivot() * CFrame.new(0,0,3))

						-- Whitelist supplementaire pour le TP du caller (la cmd ;tp avait

						-- deja whitelist au depart mais juste pour scenario 2-targets)

						pcall(function() acWhitelistFn(plr, "teleport", true) end)

					end

				end

			elseif cmd == "bring" or cmd == "bringall" then

				local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

				if myRoot then root.CFrame = myRoot.CFrame * CFrame.new(0,0,-3) end

			elseif cmd == "kick" then

				t:Kick("\nKick par "..plr.Name.."\nRaison: "..(arg3 or rest or "Aucune"))

			elseif cmd == "kill" then

				char:BreakJoints()

			elseif cmd == "respawn" then

				t:LoadCharacter()

			elseif cmd == "loopkill" then

				activeLoops[t.UserId.."_kill"] = true

				task.spawn(function()

					while activeLoops[t.UserId.."_kill"] do

						if t.Character then t.Character:BreakJoints() end

						task.wait(0.5)

					end

				end)

			elseif cmd == "unloopkill" then

				activeLoops[t.UserId.."_kill"] = nil

			elseif cmd == "loopfling" then

				activeLoops[t.UserId.."_fling"] = true

				task.spawn(function()

					while activeLoops[t.UserId.."_fling"] do

						if t.Character and t.Character:FindFirstChild("HumanoidRootPart") then

							local r = t.Character.HumanoidRootPart

							r.AssemblyLinearVelocity  = Vector3.new(math.random(-5000,5000), math.random(5000,10000), math.random(-5000,5000))

							r.AssemblyAngularVelocity = Vector3.new(100,100,100)

						end

						task.wait(0.1)

					end

				end)

			elseif cmd == "unloopfling" then

				activeLoops[t.UserId.."_fling"] = nil

			elseif cmd == "slap" then

				hum.Health = hum.Health - 10

				local bv = Instance.new("BodyVelocity", root) bv:SetAttribute("AgoraAdmin", true)

				bv.MaxForce = Vector3.new(1e5,1e5,1e5)

				bv.Velocity = Vector3.new(math.random(-50,50),50,math.random(-50,50))

				task.delay(0.2, function() bv:Destroy() end)

			elseif cmd == "fling" then

				local bv = Instance.new("BodyVelocity", root) bv:SetAttribute("AgoraAdmin", true)

				bv.MaxForce = Vector3.new(1e9,1e9,1e9)

				bv.Velocity = Vector3.new(math.random(-5e3,5e3),1e4,math.random(-5e3,5e3))

				local bav = Instance.new("BodyAngularVelocity", root) bav:SetAttribute("AgoraAdmin", true)

				bav.AngularVelocity = Vector3.new(100,100,100)

				task.delay(1, function() bv:Destroy() bav:Destroy() end)

			elseif cmd == "explode" then

				local ex = Instance.new("Explosion", workspace)

				ex.Position = root.Position ex.BlastRadius=12 ex.BlastPressure=500000

				ex.DestroyJointRadiusPercent=0 ex.ExplosionType=Enum.ExplosionType.NoCraters

				if char then char:BreakJoints() end

			elseif cmd == "freecandy" then

				-- 🍦 FREE CANDY VAN v2: arrive→ralenti→s'arrête→embarque→décolle vite.

				-- Camion blanc style ice cream truck (sans gyrophares police).

				local lookDir = root.CFrame.LookVector

				-- Spawn: 90 studs derrière la cible, AU SOL via raycast

				local approxStart = root.Position - lookDir * 90 + Vector3.new(0, 10, 0)

				local rayP = RaycastParams.new()

				rayP.FilterType = Enum.RaycastFilterType.Exclude

				rayP.FilterDescendantsInstances = {char, t.Character}

				local groundRay = workspace:Raycast(approxStart, Vector3.new(0, -200, 0), rayP)

				local groundY = groundRay and groundRay.Position.Y or (root.Position.Y - 3)

				local startPos = Vector3.new(approxStart.X, groundY + 4, approxStart.Z)

				local toTarget = (root.Position - startPos)

				local rollDir = Vector3.new(toTarget.X, 0, toTarget.Z).Unit

				-- Conteneur Model pour tout le camion (cleanup unique)

				local model = Instance.new("Model")

				model.Name = "AgoraFreeCandy"

				model.Parent = workspace

				-- Châssis (caisse blanche)

				local truck = Instance.new("Part")

				truck.Name = "Body"

				truck.Size = Vector3.new(8, 6, 16)

				truck.Anchored = false

				truck.CanCollide = true

				truck.Color = Color3.fromRGB(252, 252, 250)

				truck.Material = Enum.Material.SmoothPlastic

				truck.CFrame = CFrame.lookAt(startPos, startPos + rollDir)

				truck.Parent = model

				model.PrimaryPart = truck

				-- Toit incliné (pour casser le bloc)

				local roof = Instance.new("Part")

				roof.Name = "Roof"

				roof.Size = Vector3.new(8.2, 0.5, 16.2)

				roof.Color = Color3.fromRGB(220, 30, 40)  -- bande rouge classique ice cream truck

				roof.Material = Enum.Material.SmoothPlastic

				roof.CanCollide = false

				roof.CFrame = truck.CFrame * CFrame.new(0, 3.2, 0)

				roof.Parent = model

				do local w = Instance.new("WeldConstraint", roof) w.Part0 = truck w.Part1 = roof end

				-- Cabine avant (plus basse, plus courte)

				local cabin = Instance.new("Part")

				cabin.Name = "Cabin"

				cabin.Size = Vector3.new(7, 4, 5)

				cabin.Color = Color3.fromRGB(252, 252, 250)

				cabin.Material = Enum.Material.SmoothPlastic

				cabin.CanCollide = false

				cabin.CFrame = truck.CFrame * CFrame.new(0, -1, -10.5)

				cabin.Parent = model

				do local w = Instance.new("WeldConstraint", cabin) w.Part0 = truck w.Part1 = cabin end

				-- Pare-brise (vitre teintée)

				local windshield = Instance.new("Part")

				windshield.Name = "Windshield"

				windshield.Size = Vector3.new(6.2, 2.2, 0.2)

				windshield.Color = Color3.fromRGB(40, 60, 80)

				windshield.Material = Enum.Material.Glass

				windshield.Transparency = 0.35

				windshield.Reflectance = 0.4

				windshield.CanCollide = false

				windshield.CFrame = cabin.CFrame * CFrame.new(0, 0.6, -2.5)

				windshield.Parent = model

				do local w = Instance.new("WeldConstraint", windshield) w.Part0 = cabin w.Part1 = windshield end

				-- Vitres latérales (avec rideaux marrons style camion glacier)

				for _, sx in ipairs({-3.55, 3.55}) do

					local sideWin = Instance.new("Part")

					sideWin.Size = Vector3.new(0.2, 2, 6)

					sideWin.Color = Color3.fromRGB(60, 80, 110)

					sideWin.Material = Enum.Material.Glass

					sideWin.Transparency = 0.45

					sideWin.CanCollide = false

					sideWin.CFrame = truck.CFrame * CFrame.new(sx, 1.5, -1)

					sideWin.Parent = model

					local w = Instance.new("WeldConstraint", sideWin) w.Part0 = truck w.Part1 = sideWin

				end

				-- Pare-chocs noir avant

				local bumper = Instance.new("Part")

				bumper.Size = Vector3.new(7.5, 1, 0.5)

				bumper.Color = Color3.fromRGB(25, 25, 25)

				bumper.Material = Enum.Material.Metal

				bumper.CanCollide = false

				bumper.CFrame = cabin.CFrame * CFrame.new(0, -1.6, -2.7)

				bumper.Parent = model

				do local w = Instance.new("WeldConstraint", bumper) w.Part0 = cabin w.Part1 = bumper end

				-- Calandre (grille)

				local grille = Instance.new("Part")

				grille.Size = Vector3.new(5, 1.6, 0.2)

				grille.Color = Color3.fromRGB(15, 15, 15)

				grille.Material = Enum.Material.DiamondPlate

				grille.CanCollide = false

				grille.CFrame = cabin.CFrame * CFrame.new(0, -0.5, -2.6)

				grille.Parent = model

				do local w = Instance.new("WeldConstraint", grille) w.Part0 = cabin w.Part1 = grille end

				-- Texte "FREE CANDY" sur les côtés (rouge sur fond blanc, style sticker)

				for _, face in ipairs({Enum.NormalId.Left, Enum.NormalId.Right}) do

					local sg = Instance.new("SurfaceGui", truck)

					sg.Face = face

					sg.LightInfluence = 0

					sg.AlwaysOnTop = false

					sg.PixelsPerStud = 35

					local bg = Instance.new("Frame", sg)

					bg.Size = UDim2.new(1, 0, 1, 0)

					bg.BackgroundColor3 = Color3.fromRGB(252, 252, 250)

					bg.BorderSizePixel = 0

					local lab = Instance.new("TextLabel", bg)

					lab.Size = UDim2.new(1, 0, 0.7, 0)

					lab.Position = UDim2.new(0, 0, 0.15, 0)

					lab.BackgroundTransparency = 1

					lab.Text = "🍦 FREE CANDY 🍭"

					lab.TextColor3 = Color3.fromRGB(220, 30, 40)

					lab.Font = Enum.Font.LuckiestGuy

					lab.TextScaled = true

					lab.TextStrokeTransparency = 0.7

				end

				-- Texte arrière (porte)

				do

					local sg = Instance.new("SurfaceGui", truck)

					sg.Face = Enum.NormalId.Back

					sg.LightInfluence = 0

					sg.PixelsPerStud = 35

					local bg = Instance.new("Frame", sg)

					bg.Size = UDim2.new(1, 0, 1, 0)

					bg.BackgroundColor3 = Color3.fromRGB(252, 252, 250)

					bg.BorderSizePixel = 0

					local lab = Instance.new("TextLabel", bg)

					lab.Size = UDim2.new(1, 0, 1, 0)

					lab.BackgroundTransparency = 1

					lab.Text = "🍬"

					lab.TextScaled = true

				end

				-- Roues avec jantes (CanCollide false pour pas glitcher la physique)

				local wheelData = {

					Vector3.new(4.2, -3, 5.5), Vector3.new(-4.2, -3, 5.5),

					Vector3.new(4.2, -3, -5.5), Vector3.new(-4.2, -3, -5.5),

				}

				for _, off in ipairs(wheelData) do

					local wheel = Instance.new("Part")

					wheel.Shape = Enum.PartType.Cylinder

					wheel.Size = Vector3.new(1.2, 2.8, 2.8)

					wheel.Color = Color3.fromRGB(20, 20, 20)

					wheel.Material = Enum.Material.SmoothPlastic

					wheel.CanCollide = false

					wheel.CFrame = truck.CFrame * CFrame.new(off)

					wheel.Parent = model

					local w = Instance.new("WeldConstraint", wheel) w.Part0 = truck w.Part1 = wheel

					-- Jante chrome

					local rim = Instance.new("Part")

					rim.Shape = Enum.PartType.Cylinder

					rim.Size = Vector3.new(0.3, 1.6, 1.6)

					rim.Color = Color3.fromRGB(180, 180, 185)

					rim.Material = Enum.Material.Metal

					rim.Reflectance = 0.5

					rim.CanCollide = false

					rim.CFrame = wheel.CFrame * CFrame.new(0, 0, 0)

					rim.Parent = model

					local w2 = Instance.new("WeldConstraint", rim) w2.Part0 = wheel w2.Part1 = rim

				end

				-- Phares avant (jaune blanc + spot)

				for _, off in ipairs({Vector3.new(2.8, -0.8, -13.2), Vector3.new(-2.8, -0.8, -13.2)}) do

					local light = Instance.new("Part")

					light.Size = Vector3.new(1.4, 1.4, 0.3)

					light.Shape = Enum.PartType.Cylinder

					light.Color = Color3.fromRGB(255, 250, 220)

					light.Material = Enum.Material.Neon

					light.CanCollide = false

					light.CFrame = truck.CFrame * CFrame.new(off) * CFrame.Angles(0, math.rad(90), 0)

					light.Parent = model

					local w = Instance.new("WeldConstraint", light) w.Part0 = truck w.Part1 = light

					local sl = Instance.new("SpotLight", light)

					sl.Brightness = 6 sl.Range = 50 sl.Angle = 80

					sl.Color = Color3.fromRGB(255, 245, 200)

					sl.Face = Enum.NormalId.Right

				end

				-- Topper "ICE CREAM" sur le toit (boîte avec icône cornet) — pas un gyrophare

				local topper = Instance.new("Part")

				topper.Size = Vector3.new(3.5, 1.8, 4)

				topper.Color = Color3.fromRGB(255, 245, 180)

				topper.Material = Enum.Material.Neon

				topper.Transparency = 0.15

				topper.CanCollide = false

				topper.CFrame = truck.CFrame * CFrame.new(0, 4.4, 1)

				topper.Parent = model

				do local w = Instance.new("WeldConstraint", topper) w.Part0 = truck w.Part1 = topper end

				for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do

					local sg = Instance.new("SurfaceGui", topper)

					sg.Face = face

					sg.LightInfluence = 0

					local lab = Instance.new("TextLabel", sg)

					lab.Size = UDim2.new(1, 0, 1, 0)

					lab.BackgroundTransparency = 1

					lab.Text = "🍦"

					lab.TextScaled = true

					lab.Font = Enum.Font.LuckiestGuy

				end

				-- Lumière douce vers le bas depuis le topper (pas clignotante, pas police)

				local topL = Instance.new("PointLight", topper)

				topL.Brightness = 2 topL.Range = 12 topL.Color = Color3.fromRGB(255, 240, 180)

				-- Lumière intérieure jaune chaude

				local interior = Instance.new("PointLight", truck)

				interior.Brightness = 4 interior.Range = 15

				interior.Color = Color3.fromRGB(255, 220, 120)

				-- Échappement à l'arrière (ParticleEmitter pour fumée)

				local exhaust = Instance.new("Part")

				exhaust.Size = Vector3.new(0.6, 0.6, 0.6)

				exhaust.Transparency = 1

				exhaust.CanCollide = false

				exhaust.CFrame = truck.CFrame * CFrame.new(2.5, -2.5, 8.5)

				exhaust.Parent = model

				do local w = Instance.new("WeldConstraint", exhaust) w.Part0 = truck w.Part1 = exhaust end

				local smoke = Instance.new("ParticleEmitter", exhaust)

				smoke.Texture = "rbxassetid://242102147"

				smoke.Lifetime = NumberRange.new(0.6, 1.4)

				smoke.Rate = 25

				smoke.Speed = NumberRange.new(2, 5)

				smoke.SpreadAngle = Vector2.new(15, 15)

				smoke.Size = NumberSequence.new({

					NumberSequenceKeypoint.new(0, 0.5),

					NumberSequenceKeypoint.new(1, 3),

				})

				smoke.Transparency = NumberSequence.new({

					NumberSequenceKeypoint.new(0, 0.4),

					NumberSequenceKeypoint.new(1, 1),

				})

				smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120))

				smoke.LightEmission = 0

				smoke.LockedToPart = false

				-- [CREEPY KIDNAPPING] Jingle Ice Cream Truck (Pop Goes the Weasel) avec

				-- effets sonores qui se distordent progressivement (reverb + EQ) pour passer

				-- de "joyeux camion glacée" a "stalker horror" sans changer de son.

				local jingle = Instance.new("Sound", truck)

				jingle.SoundId = "rbxassetid://9112854440"

				jingle.Looped = true

				jingle.Volume = 4

				jingle.RollOffMaxDistance = 280

				jingle.RollOffMode = Enum.RollOffMode.InverseTapered

				-- ReverbSoundEffect: la creep echoey grotte, exposed comme jingle._creepReverb

				local jReverb = Instance.new("ReverbSoundEffect", jingle)

				jReverb.Name = "CreepReverb"

				jReverb.Density = 1

				jReverb.Diffusion = 1

				jReverb.DecayTime = 0  -- on monte ce parametre quand on veut creepy

				jReverb.WetLevel = 0

				jReverb.DryLevel = 0

				-- EqualizerSoundEffect: low pass = bouffe les aigus = trash etrange

				local jEq = Instance.new("EqualizerSoundEffect", jingle)

				jEq.Name = "CreepEq"

				jEq.HighGain = 0

				jEq.MidGain = 0

				jEq.LowGain = 0

				-- DistortionSoundEffect: kick le creepy au max au moment du kidnapping

				local jDist = Instance.new("DistortionSoundEffect", jingle)

				jDist.Name = "CreepDist"

				jDist.Level = 0

				pcall(function() jingle:Play() end)

				-- Klaxon (declenche a l'arrivee) — plus fort, lourd

				local horn = Instance.new("Sound", truck)

				horn.SoundId = "rbxassetid://9118902208"

				horn.Volume = 5

				horn.RollOffMaxDistance = 220

				horn.PlaybackSpeed = 0.9  -- legerement plus grave = plus menacant

				-- Son freinage — plus fort

				local brake = Instance.new("Sound", truck)

				brake.SoundId = "rbxassetid://2814365274"

				brake.Volume = 4

				brake.RollOffMaxDistance = 160

				-- Son demarrage en trombe (squeal de pneus) — plus fort

				local screech = Instance.new("Sound", truck)

				screech.SoundId = "rbxassetid://5256888266"

				screech.Volume = 4.5

				screech.RollOffMaxDistance = 220

				-- Riff demoniaque pour la phase de kidnapping (rire / atmosphere)

				local creep = Instance.new("Sound", truck)

				creep.SoundId = "rbxassetid://5810753638"  -- growl deep (deja utilise zombie)

				creep.Volume = 3.5

				creep.PlaybackSpeed = 0.6

				creep.RollOffMaxDistance = 200

				creep.Looped = true

				-- BodyGyro: garde l'orientation du camion

				local bg = Instance.new("BodyGyro", truck)

				bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)

				bg.P = 10000

				bg.D = 500

				bg.CFrame = truck.CFrame

				-- BodyVelocity: roule vers la cible

				local bv = Instance.new("BodyVelocity", truck)

				bv:SetAttribute("AgoraAdmin", true)

				bv.MaxForce = Vector3.new(1e9, 0, 1e9)  -- Y libre = gravité

				bv.Velocity = rollDir * 38  -- vitesse approche

				-- ─── PHASE 1 (0→1.4s) approche jingle innocent ───

				-- Pitch normal 1.0, pas de creepy — encore le camion glacée mignon

				-- ─── PHASE 2 (1.4→2.0s) freinage + premier degrade pitch (subtil) ───

				task.delay(1.4, function()

					if not truck.Parent then return end

					pcall(function() brake:Play() end)

					-- Le jingle commence a degrader: pitch 1.0 → 0.85 + low gain monte (sourd)

					pcall(function()

						jingle.PlaybackSpeed = 0.85

						jEq.LowGain = 4

						jEq.HighGain = -2

					end)

					-- Deceleration en 0.6s : 38 → 0

					local steps = 12

					for i = 1, steps do

						if not truck.Parent then return end

						bv.Velocity = rollDir * (38 * (1 - i/steps))

						task.wait(0.05)

					end

					if not truck.Parent then return end

					bv.Velocity = Vector3.new(0, 0, 0)

				end)

				-- ─── PHASE 3 (2.0→3.0s) arret + klaxon + jingle sinistre ───

				task.delay(2.05, function()

					if not truck.Parent then return end

					pcall(function() horn:Play() end)

					-- Pitch 0.65 + reverb echoey + low gain max = "le camion s'arrete c'est pas normal"

					pcall(function()

						jingle.PlaybackSpeed = 0.65

						jEq.LowGain = 8

						jEq.HighGain = -6

						jReverb.DecayTime = 1.5  -- echo de cave

						jReverb.WetLevel = -3

					end)

					-- Notif effrayante au joueur cible

					if notifEvent and t and t.Parent then

						pcall(function() notifEvent:FireClient(t, "🍬 Veux-tu un bonbon...?") end)

					end

				end)

				-- ─── PHASE 4 (3.0s) EMBARQUEMENT — full creep mode ───

				task.delay(3.0, function()

					if not truck.Parent then return end

					if not t or not t.Parent then return end  -- joueur a quitte

					local tChar = t.Character

					local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

					local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

					if tRoot and tHum then

						tHum.PlatformStand = true

						-- TP dans la cabine arriere du camion

						tRoot.CFrame = truck.CFrame * CFrame.new(0, 0.5, 4)

						local kidnapWeld = Instance.new("WeldConstraint", tRoot)

						kidnapWeld.Name = "AgoraKidnap"

						kidnapWeld.Part0 = tRoot

						kidnapWeld.Part1 = truck

					end

					-- Jingle horror max: pitch 0.4, reverb cave, distortion legere, growl en boucle

					pcall(function()

						jingle.PlaybackSpeed = 0.4

						jingle.Volume = 5

						jEq.LowGain = 12

						jEq.HighGain = -10

						jReverb.DecayTime = 3

						jReverb.WetLevel = 0

						jDist.Level = 0.3

					end)

					pcall(function() creep:Play() end)

				end)

				-- ─── PHASE 5 (3.4s) DECOLLAGE rapide — pitch encore plus bas + screech ───

				task.delay(3.4, function()

					if not truck.Parent then return end

					pcall(function() screech:Play() end)

					-- Pitch 0.3 = quasi inaudible, demoniaque

					pcall(function()

						jingle.PlaybackSpeed = 0.3

						jDist.Level = 0.5

					end)

					-- Echappement crache (rate ↑)

					smoke.Rate = 80

					smoke.Speed = NumberRange.new(8, 14)

					-- Acceleration brutale

					bv.Velocity = rollDir * 50

					task.wait(0.15) if not truck.Parent then return end

					bv.Velocity = rollDir * 90

					task.wait(0.2) if not truck.Parent then return end

					bv.Velocity = rollDir * 130  -- 130 studs/s = vroum

				end)

				-- ─── PHASE 6 (8.0s) le joueur meurt + camion despawn discret ───

				task.delay(8.0, function()

					if t and t.Character then pcall(function() t.Character:BreakJoints() end) end

					if model.Parent then

						-- Petite explosion visuelle (sans dégât physique aux alentours)

						local ex = Instance.new("Explosion", workspace)

						ex.Position = truck.Position

						ex.BlastRadius = 6

						ex.BlastPressure = 0

						ex.DestroyJointRadiusPercent = 0

						ex.ExplosionType = Enum.ExplosionType.NoCraters

						model:Destroy()

					end

				end)

				-- Safety net : auto-cleanup après 15s même si une étape plante

				task.delay(15, function()

					if model.Parent then model:Destroy() end

				end)

			elseif cmd == "zap" then

				local startPos=root.Position+Vector3.new(0,500,0)

				local zapDist=(startPos-root.Position).Magnitude

				local zapPart=Instance.new("Part")

				zapPart.Name="AdminZap" zapPart.Size=Vector3.new(2,zapDist,2)

				zapPart.CFrame=CFrame.lookAt(startPos,root.Position)*CFrame.new(0,0,-zapDist/2)*CFrame.Angles(math.pi/2,0,0)

				zapPart.Anchored=true zapPart.CanCollide=false zapPart.Material=Enum.Material.Neon

				zapPart.Color=Color3.fromRGB(100,200,255) zapPart.Parent=workspace

				local snd=Instance.new("Sound",root) snd.SoundId="rbxassetid://147722227" snd.Volume=2 snd:Play()

				local ex=Instance.new("Explosion",workspace)

				ex.Position=root.Position ex.BlastRadius=8 ex.BlastPressure=500000

				ex.DestroyJointRadiusPercent=0 ex.ExplosionType=Enum.ExplosionType.NoCraters

				if char then char:BreakJoints() end

				task.delay(0.2, function() if zapPart then zapPart:Destroy() end end)

				task.delay(2,   function() if snd then snd:Destroy() end end)

			elseif cmd == "fire" then

				Instance.new("Fire", root)

			elseif cmd == "unfire" then

				for _, v in pairs(root:GetChildren()) do if v:IsA("Fire") then v:Destroy() end end

			elseif cmd == "freeze" or cmd == "freezeall" then

				root.Anchored = true

			elseif cmd == "thaw" or cmd == "thawall" then

				root.Anchored = false

			elseif cmd == "speed" or cmd == "ws" then

				hum.WalkSpeed = tonumber(arg3) or 16

			elseif cmd == "jump" or cmd == "jp" then

				hum.JumpPower = tonumber(arg3) or 50

			elseif cmd == "size" then

				-- [FIX SIZE] Limites par rôle (VIP=5, Mod=10, Staff = Staff + 50, min 0.5 pour pas crêpe)

				local scale = tonumber(arg3) or 1

				local callerLvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

				local maxSize, minSize

				if callerLvl <= 3 then        -- Staffs et au-dessus

					maxSize, minSize = 50, 0.3

				elseif callerLvl == 4 then    -- Modérateur

					maxSize, minSize = 10, 0.5

				else                           -- VIP / Joueurs

					maxSize, minSize = 5, 0.5

				end

				scale = math.clamp(scale, minSize, maxSize)

				-- Marquer le joueur comme redimensionné (l'AC ignore le scale check)

				t:SetAttribute("_AdminScaled", true)

				local hs=hum:FindFirstChild("HeadScale")        if hs  then hs.Value=scale  end

				local bds=hum:FindFirstChild("BodyDepthScale")  if bds then bds.Value=scale end

				local bws=hum:FindFirstChild("BodyWidthScale")  if bws then bws.Value=scale end

				local bhs=hum:FindFirstChild("BodyHeightScale") if bhs then bhs.Value=scale end

				notifEvent:FireClient(plr, t.Name.." → taille "..tostring(scale).."x (max "..maxSize..").")

			elseif cmd == "heal" or cmd == "healall" then

				hum.Health = hum.MaxHealth

			elseif cmd == "refresh" or cmd == "reset" or cmd == "re" then

				-- [ZOMBIFY] ;re guérit l'infection (au cas ou)

				if _G._AgoraUnzombify then pcall(function() _G._AgoraUnzombify(t) end) end

				local oPos = root.CFrame

				t:LoadCharacter()

				task.wait(0.2)

				if t.Character and t.Character:FindFirstChild("HumanoidRootPart") then

					t.Character.HumanoidRootPart.CFrame = oPos

				end

			elseif cmd == "god" or cmd == "godall" then

				t:SetAttribute("GodMode", true)

				hum.MaxHealth=1e9 hum.Health=1e9

			elseif cmd == "ungod" or cmd == "ungodall" then

				t:SetAttribute("GodMode", false)

				hum.MaxHealth=100 hum.Health=100

			elseif cmd == "blind" then

				notifEvent:FireClient(t, "BLIND", true)

			elseif cmd == "unblind" then

				notifEvent:FireClient(t, "BLIND", false)

			elseif cmd == "warn" then

				warnEvent:FireClient(t, (arg3 and arg3.." "..(rest or "")) or "AVERTISSEMENT")

			elseif cmd == "mute" then

				t:SetAttribute("Muted", true)

			elseif cmd == "unmute" then

				t:SetAttribute("Muted", false)

			elseif cmd == "btools" then

				local backpack = t:FindFirstChild("Backpack")

				if not backpack then return end

				-- Cherche dans le script, puis dans ServerStorage

				local myBtools = scriptRef:FindFirstChild("Btools")

					or game:GetService("ServerStorage"):FindFirstChild("Btools")

					or ReplicatedStorage:FindFirstChild("Btools")

				if myBtools then

					if myBtools:IsA("Tool") then

						myBtools:Clone().Parent = backpack

					else

						for _, v in pairs(myBtools:GetChildren()) do

							if v:IsA("Tool") then v:Clone().Parent = backpack end

						end

					end

					notifEvent:FireClient(plr, "BTools donnes a "..t.Name..".")

				else

					-- Fallback : Roblox Basic Build Tools via InsertService

					task.spawn(function()

						local ok, model = pcall(function()

							return InsertService:LoadAsset(142785488)

						end)

						if ok and model then

							for _, v in pairs(model:GetDescendants()) do

								if v:IsA("Tool") then v:Clone().Parent = backpack end

							end

							model:Destroy()

							notifEvent:FireClient(plr, "BTools charges pour "..t.Name..".")

						else

							notifEvent:FireClient(plr, "BTools introuvable. Place un dossier Btools dans ServerStorage.")

						end

					end)

				end

			elseif cmd == "noob" then

				for _, v in pairs(char:GetChildren()) do

					if v:IsA("CharacterAppearance") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then v:Destroy() end

				end

				local yellow = Color3.fromRGB(255,255,0)

				local blue = Color3.fromRGB(0,0,255)

				if char:FindFirstChild("Head") then char.Head.Color = yellow end

				-- R6

				if char:FindFirstChild("Torso") then char.Torso.Color = blue end

				-- R15

				if char:FindFirstChild("UpperTorso") then char.UpperTorso.Color = blue end

				if char:FindFirstChild("LowerTorso") then char.LowerTorso.Color = blue end

				if char:FindFirstChild("LeftUpperArm") then char.LeftUpperArm.Color = yellow end

				if char:FindFirstChild("RightUpperArm") then char.RightUpperArm.Color = yellow end

				if char:FindFirstChild("LeftUpperLeg") then char.LeftUpperLeg.Color = Color3.fromRGB(13,105,172) end

				if char:FindFirstChild("RightUpperLeg") then char.RightUpperLeg.Color = Color3.fromRGB(13,105,172) end

			elseif cmd == "ban" then

				local d = tonumber(arg3) or 60

				local exp = os.time() + d*60

				-- [FIX STABILITÉ] pcall pour éviter crash sur throttle DataStore

				local banOk = pcall(function()

					BanStore:SetAsync(tostring(t.UserId), {Type="Temp",Expire=exp,Reason=rest})

				end)

				if banOk then

					addToBanIndex(t.UserId, t.Name)

					pushUndo(plr, "ban", {userId=t.UserId, name=t.Name})

					t:Kick("\nBan Temp ("..d.."m)\nRaison: "..(rest or ""))

				else

					notifEvent:FireClient(plr, "Erreur DataStore — réessaye dans 10s.")

				end

			elseif cmd == "pban" then

				-- [FIX STABILITÉ] pcall pour éviter crash sur throttle DataStore

				local pbanOk = pcall(function()

					BanStore:SetAsync(tostring(t.UserId), {Type="Perm",Reason=arg3 or rest})

				end)

				if pbanOk then

					addToBanIndex(t.UserId, t.Name)

					pushUndo(plr, "pban", {userId=t.UserId, name=t.Name})

					t:Kick("\nBan Permanent\nRaison: "..(arg3 or rest or ""))

				else

					notifEvent:FireClient(plr, "Erreur DataStore — réessaye dans 10s.")

				end

			elseif cmd == "unban" then

				pcall(function() BanStore:RemoveAsync(tostring(t.UserId)) end)

				local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

				if s and list then

					list[tostring(t.UserId)] = nil

					pcall(function() BanIndexStore:SetAsync("MasterList", list) end)

				end

				notifEvent:FireClient(plr, t.Name.." deban avec succes.")

			elseif cmd == "fly" then

				-- [FIX FLY TOGGLE E] Set attribute persistant — la cible peut maintenant

				-- toggle E off/on autant qu'elle veut sans que l'AC kick. Seul ;unfly retire.

				t:SetAttribute("_FlyAllowed", true)

				flyEvent:FireClient(t, "OpenPanel", true)

				flyEvent:FireClient(t, "Toggle", true)

			elseif cmd == "unfly" then

				t:SetAttribute("_FlyAllowed", false)

				flyEvent:FireClient(t, "OpenPanel", false)

				flyEvent:FireClient(t, "Toggle", false)

			elseif cmd == "noclip" then

				t:SetAttribute("_NoclipAllowed", true)

				noclipEvent:FireClient(t, "OpenPanel", true)

				noclipEvent:FireClient(t, "Toggle", true)

			elseif cmd == "clip" or cmd == "unnoclip" then

				t:SetAttribute("_NoclipAllowed", false)

				noclipEvent:FireClient(t, "OpenPanel", false)

				noclipEvent:FireClient(t, "Toggle", false)

			elseif cmd == "invisible" then

				-- [FIX INVISIBLE] Sauve transparency originale + cache GUIs (BillboardGui/SurfaceGui = bannières/titres)

				for _, v in pairs(char:GetDescendants()) do

					if v:IsA("BasePart") then

						if v:GetAttribute("_INVT") == nil then v:SetAttribute("_INVT", v.Transparency) end

						v.Transparency = 1

					elseif v:IsA("Decal") or v:IsA("Texture") then

						if v:GetAttribute("_INVT") == nil then v:SetAttribute("_INVT", v.Transparency) end

						v.Transparency = 1

					elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

						if v:GetAttribute("_INVE") == nil then v:SetAttribute("_INVE", v.Enabled) end

						v.Enabled = false

					elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") or v:IsA("Trail") then

						if v:GetAttribute("_INVE") == nil then v:SetAttribute("_INVE", v.Enabled) end

						v.Enabled = false

					end

				end

				if hum then

					if hum:GetAttribute("_INVDDT") == nil then

						hum:SetAttribute("_INVDDT", hum.DisplayDistanceType.Name)

					end

					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

				end

			elseif cmd == "visible" or cmd == "uninvisible" then

				-- [FIX INVISIBLE] Restaure transparency + ré-active GUIs depuis attributs sauvegardés

				for _, v in pairs(char:GetDescendants()) do

					if v:IsA("BasePart") then

						local saved = v:GetAttribute("_INVT")

						if saved ~= nil then

							v.Transparency = saved

							v:SetAttribute("_INVT", nil)

						elseif v.Name ~= "HumanoidRootPart" then

							v.Transparency = 0

						end

					elseif v:IsA("Decal") or v:IsA("Texture") then

						local saved = v:GetAttribute("_INVT")

						v.Transparency = (saved ~= nil) and saved or 0

						v:SetAttribute("_INVT", nil)

					elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

						local saved = v:GetAttribute("_INVE")

						v.Enabled = (saved == nil) or saved

						v:SetAttribute("_INVE", nil)

					elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Beam") or v:IsA("Trail") then

						local saved = v:GetAttribute("_INVE")

						v.Enabled = (saved == nil) or saved

						v:SetAttribute("_INVE", nil)

					end

				end

				if hum then

					local saved = hum:GetAttribute("_INVDDT")

					hum.DisplayDistanceType = saved and Enum.HumanoidDisplayDistanceType[saved] or Enum.HumanoidDisplayDistanceType.Viewer

					hum:SetAttribute("_INVDDT", nil)

				end

			elseif cmd == "nv" or cmd == "nightvision" or cmd == "esp" then

				local pg = t:FindFirstChild("PlayerGui")

				if pg then

					local old = pg:FindFirstChild("AgoraESP") if old then old:Destroy() end

					local espF = Instance.new("Folder",pg) espF.Name="AgoraESP"

					for _, p in pairs(Players:GetPlayers()) do

						if p ~= t and p.Character then

							local hl=Instance.new("Highlight",espF) hl.Adornee=p.Character

							hl.FillColor=Color3.new(1,0,0) hl.FillTransparency=0.5

							hl.OutlineColor=Color3.new(1,1,1) hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop

						end

					end

				end

			elseif cmd == "unnv" or cmd == "unnightvision" or cmd == "unesp" then

				local pg = t:FindFirstChild("PlayerGui")

				if pg then local f=pg:FindFirstChild("AgoraESP") if f then f:Destroy() end end

			elseif cmd == "char" then

				local id = nil

				pcall(function() id = Players:GetUserIdFromNameAsync(arg3) end)

				if id then pcall(function() hum:ApplyDescription(Players:GetHumanoidDescriptionFromUserId(id)) end) end

			elseif cmd == "jail" then

				if activeJails and activeJails[t.UserId] then activeJails[t.UserId].Model:Destroy() end

				local cf = root.CFrame

				local jail = Instance.new("Model", workspace)

				jail.Name = "Jail_"..t.Name

				local parts = {

					{s=Vector3.new(10,1,10), p=cf*CFrame.new(0,-4.5,0),  c=Color3.new(0.1,0.1,0.1), m=Enum.Material.SmoothPlastic, t=0},

					{s=Vector3.new(10,1,10), p=cf*CFrame.new(0,4.5,0),   c=Color3.new(0.1,0.1,0.1), m=Enum.Material.SmoothPlastic, t=0},

					{s=Vector3.new(1,8,10),  p=cf*CFrame.new(4.5,0,0),   c=Color3.new(1,1,1), m=Enum.Material.Glass, t=0.5},

					{s=Vector3.new(1,8,10),  p=cf*CFrame.new(-4.5,0,0),  c=Color3.new(1,1,1), m=Enum.Material.Glass, t=0.5},

					{s=Vector3.new(8,8,1),   p=cf*CFrame.new(0,0,4.5),   c=Color3.new(1,1,1), m=Enum.Material.Glass, t=0.5},

					{s=Vector3.new(8,8,1),   p=cf*CFrame.new(0,0,-4.5),  c=Color3.new(1,1,1), m=Enum.Material.Glass, t=0.5},

				}

				for _, info in pairs(parts) do

					local p=Instance.new("Part",jail)

					p.Size=info.s p.CFrame=info.p p.Anchored=true p.Locked=true

					p.Transparency=info.t p.Material=info.m p.Color=info.c

				end

				activeJails = activeJails or {}; activeJails[t.UserId] = {Model=jail, CFrame=cf}

				root.CFrame = cf

			elseif cmd == "unjail" then

				if activeJails and activeJails[t.UserId] then

					if activeJails and activeJails[t.UserId] then activeJails[t.UserId].Model:Destroy() end

					if activeJails then activeJails[t.UserId] = nil end

				end

			elseif cmd == "permrank" then

				local roleToGive = ""

				local reqRole = (arg3 or ""):lower()

				for rName in pairs(rolesHierarchy) do

					if rName:lower() == reqRole then roleToGive = rName break end

				end

				if roleToGive ~= "" then

					t:SetAttribute("Role", roleToGive)

					task.spawn(function()

						local ok, list = pcall(function() return RanksStore:GetAsync("AllRanks") end)

						list = list or {}

						list[tostring(t.UserId)] = {Name=t.Name, Role=roleToGive}

						pcall(function() RanksStore:SetAsync("AllRanks", list) end)

					end)

					local AdminRankEvent = ReplicatedStorage:FindFirstChild("AdminChangeRank")

					if AdminRankEvent then AdminRankEvent:Fire(t.UserId, roleToGive) end

					notifEvent:FireClient(plr, "Grade de "..t.Name.." ? "..roleToGive)

				else

					notifEvent:FireClient(plr, "Grade invalide.")

				end

			elseif cmd == "temprank" then

				local roleToGive = ""

				local reqRole = (arg3 or ""):lower()

				for rName in pairs(rolesHierarchy) do

					if rName:lower() == reqRole then roleToGive = rName break end

				end

				if roleToGive ~= "" then

					tempRanks[t.UserId] = roleToGive

					notifEvent:FireClient(plr, "TempRank de "..t.Name.." ? "..roleToGive.." (session)")

					notifEvent:FireClient(t, "Grade temporaire : "..roleToGive)

				else

					notifEvent:FireClient(plr, "Grade invalide.")

				end

			elseif cmd == "logs" then

				logsEvent:FireClient(t, commandLogs)

			elseif cmd == "bubblechat" then

				bubbleChatEvent:FireClient(t, "OpenPanel", true)

			elseif cmd == "cmdbar2" then

				cmdBarEvent:FireClient(t, "OpenPanel", true)

			elseif string.sub(cmd,1,5) == "title" then

				local head = char:FindFirstChild("Head")

				if head then

					local old = head:FindFirstChild("AgoraTitle") if old then old:Destroy() end

					local text = (arg3 or "")

					if rest and rest ~= "" then text = text.." "..rest end

					if text ~= "" then

						local color = Color3.new(1,1,1)

						if     cmd=="titleb" then color=Color3.fromRGB(52,152,219)

						elseif cmd=="titler" then color=Color3.fromRGB(231,76,60)

						elseif cmd=="titleg" then color=Color3.fromRGB(46,204,113)

						elseif cmd=="titley" then color=Color3.fromRGB(241,196,15) end

						local bb=Instance.new("BillboardGui",head)

						bb.Name="AgoraTitle" bb.Size=UDim2.new(0,200,0,50)

						bb.StudsOffset=Vector3.new(0,2.5,0) bb.AlwaysOnTop=true

						local txt=Instance.new("TextLabel",bb)

						txt.Size=UDim2.new(1,0,1,0) txt.BackgroundTransparency=1

						txt.Text=text txt.TextColor3=color

						txt.Font=Enum.Font.GothamBlack txt.TextSize=20 txt.TextStrokeTransparency=0.3

					end

				end

			elseif cmd == "untitle" then

				local head = char:FindFirstChild("Head")

				if head then local old=head:FindFirstChild("AgoraTitle") if old then old:Destroy() end end

			elseif cmd == "sword" then

				local s, m = pcall(function() return InsertService:LoadAsset(11452821) end)

				if s and m then

					for _, v in pairs(m:GetChildren()) do

						if v:IsA("Tool") then v:Clone().Parent = t:FindFirstChild("Backpack") end

					end

					m:Destroy()

				end

			elseif cmd == "gear" then

				local gearId = tonumber(arg3)

				if gearId then

					local s, m = pcall(function() return InsertService:LoadAsset(gearId) end)

					if s and m then

						for _, v in pairs(m:GetChildren()) do

							if v:IsA("Tool") then v:Clone().Parent = t:FindFirstChild("Backpack") end

						end

						m:Destroy()

					else

						notifEvent:FireClient(plr, "ID invalide ou priv�.")

					end

				else

					notifEvent:FireClient(plr, "Sp�cifiez un ID.")

				end

			elseif cmd == "spin" then

				local old = root:FindFirstChild("AgoraSpin") if old then old:Destroy() end

				local bav = Instance.new("BodyAngularVelocity", root) bav:SetAttribute("AgoraAdmin", true)

				bav.Name="AgoraSpin" bav.MaxTorque=Vector3.new(0,math.huge,0)

				bav.AngularVelocity=Vector3.new(0, tonumber(arg3) or 20, 0)

			elseif cmd == "unspin" then

				local old = root:FindFirstChild("AgoraSpin") if old then old:Destroy() end

			elseif cmd == "sit" then

				hum.Sit = true

			elseif cmd == "unsit" then

				hum.Sit = false

			elseif cmd == "jumppower" then

				hum.UseJumpPower = true

				hum.JumpPower = tonumber(arg3) or 50

			elseif cmd == "maxhealth" then

				hum.MaxHealth = tonumber(arg3) or 100

				hum.Health = hum.MaxHealth

			elseif cmd == "health" then

				hum.Health = tonumber(arg3) or 100

			elseif cmd == "ff" then

				local existing = char:FindFirstChild("AgoraFF")

				if existing then existing:Destroy() end

				local f = Instance.new("ForceField", char)

				f.Name = "AgoraFF" f.Visible = true

			elseif cmd == "unff" then

				local f = char:FindFirstChild("AgoraFF") if f then f:Destroy() end

			elseif cmd == "smoke" then

				local s = Instance.new("Smoke", root) s.Name = "AgoraSmoke"

			elseif cmd == "unsmoke" then

				local s = root:FindFirstChild("AgoraSmoke") if s then s:Destroy() end

			elseif cmd == "sparkles" then

				local s = Instance.new("Sparkles", root) s.Name = "AgoraSparkles"

			elseif cmd == "unsparkles" then

				local s = root:FindFirstChild("AgoraSparkles") if s then s:Destroy() end

			elseif cmd == "hat" then

				local id = tonumber(arg3)

				if id then

					local ok, acc = pcall(function() return InsertService:LoadAsset(id) end)

					if ok and acc then

						for _, v in pairs(acc:GetChildren()) do

							if v:IsA("Accessory") then v:Clone().Parent = char end

						end

						acc:Destroy()

					end

				end

			elseif cmd == "unhat" then

				for _, v in pairs(char:GetChildren()) do

					if v:IsA("Accessory") then v:Destroy() end

				end

			elseif cmd == "animation" or cmd == "anim" then

				local id = tonumber(arg3)

				if id then

					local anim = Instance.new("Animation")

					anim.AnimationId = "rbxassetid://"..id

					local animator = hum:FindFirstChildOfClass("Animator")

					local track = animator and animator:LoadAnimation(anim) or hum:LoadAnimation(anim)

					track:Play()

				end

			elseif cmd == "trip" then

				hum.Sit = true

				task.wait(0.1)

				hum.Sit = false

			elseif cmd == "platform" then

				hum.PlatformStand = true

			elseif cmd == "unplatform" then

				hum.PlatformStand = false

			elseif cmd == "gravity" then

				workspace.Gravity = tonumber(arg3) or 196.2

			elseif cmd == "ungravity" then

				workspace.Gravity = 196.2

			elseif cmd == "ambient" then

				local r = tonumber(arg3) or 128

				local g = tonumber(rest and rest:split(" ")[1]) or 128

				local b = tonumber(rest and rest:split(" ")[2]) or 128

				Lighting.Ambient = Color3.fromRGB(r,g,b)

			-- [TEAM] Assigner un joueur à une équipe (par target)

			elseif cmd == "team" then

				local Teams = game:GetService("Teams")

				local teamName = arg3 or ""

				if rest and rest ~= "" then teamName = teamName.." "..rest end

				teamName = teamName:gsub("^%s+",""):gsub("%s+$","")

				if teamName == "" then

					notifEvent:FireClient(plr, "Usage: ;team <joueur> <équipe>")

				else

					local found = nil

					for _, tm in pairs(Teams:GetTeams()) do

						if tm.Name:lower() == teamName:lower() then found = tm break end

					end

					if found then

						t.Team = found

						notifEvent:FireClient(plr, t.Name.." → équipe "..found.Name..".")

					else

						notifEvent:FireClient(plr, "Équipe '"..teamName.."' introuvable.")

					end

				end

			-- [CONTROL] Le caller prend le contrôle physique du target (Staffs+)

			elseif cmd == "control" then

				local mychar = plr.Character

				local myroot = mychar and mychar:FindFirstChild("HumanoidRootPart")

				if not myroot then

					notifEvent:FireClient(plr, "Ton character n'est pas prêt.")

				elseif plr == t then

					notifEvent:FireClient(plr, "Tu ne peux pas te contrôler toi-même.")

				else

					-- Sauvegarder position d'origine du caller

					plr:SetAttribute("_CtrlOrigX", myroot.CFrame.X)

					plr:SetAttribute("_CtrlOrigY", myroot.CFrame.Y)

					plr:SetAttribute("_CtrlOrigZ", myroot.CFrame.Z)

					plr:SetAttribute("_CtrlTargetId", t.UserId)

					-- Cacher le caller

					for _, v in pairs(mychar:GetDescendants()) do

						if v:IsA("BasePart") then

							v:SetAttribute("_CtrlT", v.Transparency)

							v:SetAttribute("_CtrlC", v.CanCollide)

							v.Transparency = 1

							v.CanCollide = false

						elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

							v:SetAttribute("_CtrlE", v.Enabled)

							v.Enabled = false

						end

					end

					myroot.Anchored = true

					myroot.CFrame = root.CFrame * CFrame.new(0, 0, -3)

					-- Whitelist AC totale pour le target

					if acWhitelistFn then

						acWhitelistFn(t, "fly", true)

						acWhitelistFn(t, "noclip", true)

						acWhitelistFn(t, "speed", true)

						acWhitelistFn(t, "teleport", true)

					end

					-- NetworkOwnership : le caller pilote le HRP du target

					pcall(function() root:SetNetworkOwner(plr) end)

					notifEvent:FireClient(t, plr.Name.." te contrôle.")

					notifEvent:FireClient(plr, "Tu contrôles "..t.Name..". Tape ;uncontrol pour relâcher.")

				end

			-- [CONTROL] Relâcher le contrôle (self-only — t = plr)

			elseif cmd == "uncontrol" then

				if plr == t then

					local mychar = plr.Character

					local myroot = mychar and mychar:FindFirstChild("HumanoidRootPart")

					if mychar and myroot then

						-- Restaurer transparency / collision / GUIs

						for _, v in pairs(mychar:GetDescendants()) do

							if v:IsA("BasePart") then

								local sT = v:GetAttribute("_CtrlT")

								if sT ~= nil then v.Transparency = sT v:SetAttribute("_CtrlT", nil) end

								local sC = v:GetAttribute("_CtrlC")

								if sC ~= nil then v.CanCollide = sC v:SetAttribute("_CtrlC", nil) end

							elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

								local sE = v:GetAttribute("_CtrlE")

								if sE ~= nil then v.Enabled = sE v:SetAttribute("_CtrlE", nil) end

							end

						end

						myroot.Anchored = false

						local ox = plr:GetAttribute("_CtrlOrigX")

						local oy = plr:GetAttribute("_CtrlOrigY")

						local oz = plr:GetAttribute("_CtrlOrigZ")

						if ox and oy and oz then

							myroot.CFrame = CFrame.new(ox, oy, oz)

						end

						plr:SetAttribute("_CtrlOrigX", nil)

						plr:SetAttribute("_CtrlOrigY", nil)

						plr:SetAttribute("_CtrlOrigZ", nil)

						-- Reset NetworkOwnership du target précédent

						local tid = plr:GetAttribute("_CtrlTargetId")

						if tid then

							local target = Players:GetPlayerByUserId(tid)

							if target and target.Character then

								local thrp = target.Character:FindFirstChild("HumanoidRootPart")

								if thrp then

									pcall(function() thrp:SetNetworkOwner(target) end)

								end

								if acUnwhitelistFn then

									acUnwhitelistFn(target, "fly")

									acUnwhitelistFn(target, "noclip")

									acUnwhitelistFn(target, "speed")

									acUnwhitelistFn(target, "teleport")

								end

								notifEvent:FireClient(target, "Tu n'es plus contrôlé.")

							end

							plr:SetAttribute("_CtrlTargetId", nil)

						end

						notifEvent:FireClient(plr, "Contrôle relâché.")

					end

				end

				-- HD ADMIN LIKE : effets rigolos

				elseif cmd == "paint" then

					local colorMap = {

						rouge=Color3.fromRGB(255,40,40), bleu=Color3.fromRGB(40,80,255),

						vert=Color3.fromRGB(40,200,80), jaune=Color3.fromRGB(255,220,40),

						rose=Color3.fromRGB(255,100,180), violet=Color3.fromRGB(180,60,220),

						orange=Color3.fromRGB(255,140,40), noir=Color3.fromRGB(20,20,20),

						blanc=Color3.fromRGB(245,245,245), ["or"]=Color3.fromRGB(255,200,40),

						argent=Color3.fromRGB(200,200,210), cyan=Color3.fromRGB(40,220,220),

					}

					local clr

					if arg3 then

						local low = tostring(arg3):lower()

						if colorMap[low] then

							clr = colorMap[low]

						else

							local r,g,b = tostring(arg3):match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")

							if r then clr = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end

						end

					end

					if not clr then clr = Color3.fromRGB(math.random(50,255), math.random(50,255), math.random(50,255)) end

					if char then

						for _, p in ipairs(char:GetDescendants()) do

							if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then

								if not p:GetAttribute("_PaintOrig") then

									p:SetAttribute("_PaintOrig", p.Color:ToHex())

								end

								p.Color = clr

							end

						end

					end

				elseif cmd == "unpaint" then

					if char then

						for _, p in ipairs(char:GetDescendants()) do

							if p:IsA("BasePart") then

								local orig = p:GetAttribute("_PaintOrig")

								if orig then

									pcall(function() p.Color = Color3.fromHex(orig) end)

									p:SetAttribute("_PaintOrig", nil)

								end

							end

						end

					end

				elseif cmd == "aura" then

					if not char or not root then return end

					local old = root:FindFirstChild("AgoraAura")

					if old then old:Destroy() end

					local clrMap = {

						rouge=Color3.fromRGB(255,30,30), bleu=Color3.fromRGB(30,80,255),

						vert=Color3.fromRGB(30,255,80), jaune=Color3.fromRGB(255,230,30),

						rose=Color3.fromRGB(255,80,200), violet=Color3.fromRGB(180,30,255),

						["or"]=Color3.fromRGB(255,200,30), blanc=Color3.fromRGB(255,255,255),

					}

					local clr = (arg3 and clrMap[tostring(arg3):lower()]) or Color3.fromRGB(255, 200, 30)

					local att = Instance.new("Attachment", root)

					att.Name = "AgoraAura"

					local pe = Instance.new("ParticleEmitter", att)

					pe.Texture = "rbxassetid://243660364"

					pe.Color = ColorSequence.new(clr)

					pe.Lifetime = NumberRange.new(0.6, 1.2)

					pe.Rate = 60

					pe.Speed = NumberRange.new(2, 4)

					pe.SpreadAngle = Vector2.new(360, 360)

					pe.Size = NumberSequence.new({

						NumberSequenceKeypoint.new(0, 1.2),

						NumberSequenceKeypoint.new(1, 0.2),

					})

					pe.Transparency = NumberSequence.new({

						NumberSequenceKeypoint.new(0, 0.2),

						NumberSequenceKeypoint.new(1, 1),

					})

					pe.LightEmission = 0.5

				elseif cmd == "unaura" then

					if root then

						local a = root:FindFirstChild("AgoraAura")

						if a then a:Destroy() end

					end

				elseif cmd == "disco" then

					if not root then return end

					local old = root:FindFirstChild("AgoraDisco")

					if old then old:Destroy() end

					local discoFolder = Instance.new("Folder", root)

					discoFolder.Name = "AgoraDisco"

					local ball = Instance.new("Part", discoFolder)

					ball.Shape = Enum.PartType.Ball

					ball.Size = Vector3.new(2, 2, 2)

					ball.Material = Enum.Material.Neon

					ball.CanCollide = false

					ball.Massless = true

					ball.Color = Color3.fromRGB(255, 255, 255)

					ball.Reflectance = 0.5

					ball.CFrame = root.CFrame * CFrame.new(0, 8, 0)

					local weld = Instance.new("Weld", ball)

					weld.Part0 = root weld.Part1 = ball

					weld.C0 = CFrame.new(0, 8, 0)

					local pl = Instance.new("PointLight", ball)

					pl.Brightness = 5 pl.Range = 25

					task.spawn(function()

						while ball.Parent do

							local c = Color3.fromHSV(math.random(), 1, 1)

							ball.Color = c

							pl.Color = c

							task.wait(0.25)

						end

					end)

				elseif cmd == "undisco" then

					if root then

						local d = root:FindFirstChild("AgoraDisco")

						if d then d:Destroy() end

					end

				elseif cmd == "hh" or cmd == "hipheight" then

					if hum then

						local val = tonumber(arg3) or 5

						hum.HipHeight = math.clamp(val, 0, 50)

					end

				elseif cmd == "tools" then

					local src = game:GetService("ServerStorage"):FindFirstChild("Tools")

					if not src then src = Lighting:FindFirstChild("Tools") end

					if not src then

						pcall(function() notifEvent:FireClient(plr, "Aucun dossier Tools dans ServerStorage.") end)

						return

					end

					local backpack = t and t:FindFirstChildOfClass("Backpack")

					if not backpack then return end

					local count = 0

					for _, tool in ipairs(src:GetChildren()) do

						if tool:IsA("Tool") then

							pcall(function() tool:Clone().Parent = backpack end)

							count = count + 1

						end

					end

					pcall(function() notifEvent:FireClient(plr, count.." outils donnes a "..t.Name..".") end)

				elseif cmd == "respawnall" then

					for _, pp in ipairs(Players:GetPlayers()) do

						pcall(function() pp:LoadCharacter() end)

					end

				elseif cmd == "nuke" then

					if not root then return end

					local pos = root.Position

					local flash = Instance.new("Part")

					flash.Shape = Enum.PartType.Ball

					flash.Size = Vector3.new(8, 8, 8)

					flash.Position = pos

					flash.Anchored = true flash.CanCollide = false

					flash.Material = Enum.Material.Neon

					flash.Color = Color3.fromRGB(255, 255, 200)

					flash.Transparency = 0.1

					flash.Parent = workspace

					local TS = game:GetService("TweenService")

					TS:Create(flash, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {

						Size = Vector3.new(160, 160, 160),

						Transparency = 1,

					}):Play()

					task.delay(2, function() flash:Destroy() end)

					local mush = Instance.new("Part")

					mush.Size = Vector3.new(3,3,3) mush.Position = pos + Vector3.new(0, 30, 0)

					mush.Anchored = true mush.CanCollide = false mush.Transparency = 1

					mush.Parent = workspace

					local pe = Instance.new("ParticleEmitter", mush)

					pe.Texture = "rbxassetid://242102147"

					pe.Lifetime = NumberRange.new(2, 4)

					pe.Rate = 200 pe.Speed = NumberRange.new(15, 30)

					pe.SpreadAngle = Vector2.new(180, 180)

					pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 25)})

					pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))

					task.delay(4, function() mush:Destroy() end)

					for _, pp in ipairs(Players:GetPlayers()) do

						local pc = pp.Character

						local pr = pc and pc:FindFirstChild("HumanoidRootPart")

						if pr and (pr.Position - pos).Magnitude <= 80 then

							pcall(function() pc:BreakJoints() end)

						end

					end

					local sound = Instance.new("Sound", workspace)

					sound.SoundId = "rbxassetid://168513088"

					sound.Volume = 4

					sound:Play()

					game.Debris:AddItem(sound, 6)

				elseif cmd == "spook" then

					if not t then return end

					pcall(function() warnEvent:FireClient(t, "BOO !") end)

					local s = Instance.new("Sound", workspace)

					s.SoundId = "rbxassetid://138081509"

					s.Volume = 3

					if root then s.Parent = root end

					pcall(function() s:Play() end)

					game.Debris:AddItem(s, 4)

				elseif cmd == "emotes" then

					pcall(function() emotePanelEvent:FireClient(plr, "OPEN") end)

				elseif cmd == "zombify" then

					if t and t.Parent and _G._AgoraZombify then

						pcall(function() _G._AgoraZombify(t) end)

					end

				elseif cmd == "unzombify" then

					if t and t.Parent and _G._AgoraUnzombify then

						pcall(function() _G._AgoraUnzombify(t) end)

					end

				elseif cmd == "backroom" then

					if t and t.Parent and _G._AgoraBackroomEnter then

						pcall(function() _G._AgoraBackroomEnter(plr, t) end)

						pcall(function() notifEvent:FireClient(plr, "🚪 "..t.Name.." envoye dans le Backroom.") end)

					end

				elseif cmd == "unbackroom" then

					if t and t.Parent and _G._AgoraBackroomExit then

						pcall(function() _G._AgoraBackroomExit(t) end)

						pcall(function() notifEvent:FireClient(plr, "🚪 "..t.Name.." sorti du Backroom.") end)

					end

			elseif EMOTE_IDS[cmd] then

				-- VIP (level 5) = soi-même seulement, Modérateur+ (level 4-) = sur les autres

				if plr ~= t and myLvl > 4 then

					notifEvent:FireClient(plr, "Grade Modérateur requis pour les émotes sur les autres.")

				else

					local anim = Instance.new("Animation")

					anim.AnimationId = "rbxassetid://" .. tostring(EMOTE_IDS[cmd])

					local animator = hum:FindFirstChildOfClass("Animator")

					local track = animator and animator:LoadAnimation(anim) or hum:LoadAnimation(anim)

					track:Play()

				end

			end

		end

	end

	-- ------------------------------------------------

	-- PLAYER HANDLING

	-- ------------------------------------------------

	local function handlePlayer(p)

		task.spawn(function()

			local s, d = pcall(function() return BanStore:GetAsync(tostring(p.UserId)) end)

			if s and d and (d.Type == "Perm" or (d.Expire and d.Expire > os.time())) then

				p:Kick("\nBanni.\nRaison: "..(d.Reason or "N/A"))

				return

			end

		end)

		task.spawn(function() checkVIPGamepass(p) end)

		task.spawn(function()

			local ok, list = pcall(function() return RanksStore:GetAsync("AllRanks") end)

			if ok and list then

				local entry = list[tostring(p.UserId)]

				if entry and rolesHierarchy[entry.Role] then

					p:SetAttribute("Role", entry.Role)

				end

			end

		end)

		-- Donne le GUI directement dans PlayerGui (en plus de StarterGui)

		local pg = p:WaitForChild("PlayerGui", 10)

		if pg and not pg:FindFirstChild("AgoraAdmin") then

			guiToGive:Clone().Parent = pg

		end

		p.CharacterAdded:Connect(function(char)

			-- [FIX SIZE] Reset _AdminScaled au respawn (sinon bypass AC permanent)

			p:SetAttribute("_AdminScaled", nil)

			-- [AC GRACE POST-RESPAWN] Whitelist 2s sur tous types pour eviter les faux positifs

			-- quand un script serveur du jeu client TP/lift/move le character au spawn.

			if acWhitelistFn then

				acWhitelistFn(p, "fly", true)

				acWhitelistFn(p, "noclip", true)

				acWhitelistFn(p, "speed", true)

				acWhitelistFn(p, "teleport", true)

				task.delay(2.0, function()

					if acUnwhitelistFn then

						-- [FIX FLY RESPAWN] Respect des attributes persistants : si l'admin

						-- avait ;fly actif (mort/reset), on ne unwhitelist PAS pour eviter

						-- que l'AC le kick au moment ou il re-toggle son fly.

						if not p:GetAttribute("_FlyAllowed") then acUnwhitelistFn(p, "fly") end

						if not p:GetAttribute("_NoclipAllowed") then acUnwhitelistFn(p, "noclip") end

						acUnwhitelistFn(p, "speed")

						acUnwhitelistFn(p, "teleport")

					end

				end)

			end

			-- [FIX FLY RESPAWN V3] Si _FlyAllowed/_NoclipAllowed persistent (admin avait

			-- ;fly actif avant la mort/;re), on RE-FIRE le toggle au client pour qu'il

			-- recree les forces (BodyVelocity etc.) sur le NOUVEAU character.

			-- Avant: 1 seul retry a 0.8s qui pouvait rater si le ScreenGui n'etait pas

			-- encore charge cote client (LS pas pret = FireClient ignore).

			-- Maintenant: 3 retries (0.8s, 2.5s, 5s) pour couvrir mort/respawn lent.

			for _, _delay in ipairs({0.8, 2.5, 5}) do

				task.delay(_delay, function()

					if not p.Parent then return end

					if p:GetAttribute("_FlyAllowed") and flyEvent then

						pcall(function()

							flyEvent:FireClient(p, "OpenPanel", true)

							flyEvent:FireClient(p, "Toggle", true)

						end)

					end

					if p:GetAttribute("_NoclipAllowed") and noclipEvent then

						pcall(function()

							noclipEvent:FireClient(p, "OpenPanel", true)

							noclipEvent:FireClient(p, "Toggle", true)

						end)

					end

				end)

			end

			-- [AC TELEPORTER/ASCENSEUR NATIF V2] Detection continue via raycast vers le bas.

			-- Avant: timer 3s qui expirait si l'ascenseur prenait plus longtemps -> Pascal

			-- bloquait au mileu d'un trajet d'ascenseur. Maintenant: boucle persistante

			-- qui maintient la whitelist tant qu'on detecte un pad sous le perso.

			task.spawn(function()

				local hrp = char:WaitForChild("HumanoidRootPart", 5)

				local hum = char:WaitForChild("Humanoid", 5)

				if not hrp or not acWhitelistFn then return end

				local function _isPadName(n)

					if not n then return false end

					local nm = string.lower(n)

					-- Liste TRÈS étendue pour catch les noms custom des jeux clients

					return nm:find("teleport") or nm:find("portal") or nm:find("warp")

						or nm:find("checkpoint") or nm:find("lift") or nm:find("elevator")

						or nm:find("pad") or nm:find("spawn") or nm:find("ascenseur")

						or nm:find("escalator") or nm:find("escalier") or nm:find("monte")

						or nm:find("descen") or nm:find("etage") or nm:find("floor")

						or nm:find("plate") or nm:find("platform") or nm:find("button")

						or nm:find("btn") or nm:find("car") or nm:find("vehicle")

						or nm:find("train") or nm:find("boat") or nm:find("ship")

						or nm:find("door") or nm:find("porte") or nm:find("trapdoor")

						or nm:find("conveyor") or nm:find("belt") or nm:find("tapis")

						or nm:find("ride") or nm:find("seat") or nm:find("siege")

				end

				-- [DETECTION AUTO PLATEFORME] Tracker velocity Y prolongée → si le

				-- perso monte/descend > 0.7s sans avoir jumpé, c'est une plateforme

				-- (ascenseur, tapis roulant, véhicule). On whitelist temporairement.

				local _platformLift = 0  -- temps cumule de mouvement Y prolonge

				local _lastVelY = 0

				task.spawn(function()

					while char.Parent and hrp.Parent do

						task.wait(0.15)

						local vY = hrp.AssemblyLinearVelocity.Y

						local hState = hum and hum:GetState()

						-- Si on monte (vY > 8) sans être en saut/chute actif, suspect plateforme

						local isPlatform = math.abs(vY) > 8

							and hState ~= Enum.HumanoidStateType.Jumping

							and hState ~= Enum.HumanoidStateType.Freefall

							and hState ~= Enum.HumanoidStateType.FallingDown

						if isPlatform then

							_platformLift = _platformLift + 0.15

							if _platformLift > 0.7 then

								-- Ascenseur/plateforme confirmé → whitelist 4s

								acWhitelistFn(p, "fly", true)

								acWhitelistFn(p, "speed", true)

								acWhitelistFn(p, "teleport", true)

								task.delay(4.0, function()

									if p.Parent and acUnwhitelistFn then

										if not p:GetAttribute("_FlyAllowed") then acUnwhitelistFn(p, "fly") end

										if not p:GetAttribute("_NoclipAllowed") then acUnwhitelistFn(p, "noclip") end

									end

								end)

							end

						else

							_platformLift = math.max(0, _platformLift - 0.1)

						end

					end

				end)

				local _loopRunning = false

				local function _startProtectionLoop()

					if _loopRunning then return end

					_loopRunning = true

					task.spawn(function()

						local lastOnPadAt = tick()

						while _loopRunning and char.Parent and hrp.Parent do

							local rayParams = RaycastParams.new()

							rayParams.FilterType = Enum.RaycastFilterType.Exclude

							local filter = {char}

							for _, p2 in pairs(Players:GetPlayers()) do

								if p2.Character and p2 ~= p then table.insert(filter, p2.Character) end

							end

							rayParams.FilterDescendantsInstances = filter

							local pos = hrp.Position

							-- 5 raycasts (centre + 4 coins) pour catch les petits pads

							local hits = {

								workspace:Raycast(pos, Vector3.new(0, -12, 0), rayParams),

								workspace:Raycast(pos + Vector3.new(2, 0, 0), Vector3.new(0, -12, 0), rayParams),

								workspace:Raycast(pos + Vector3.new(-2, 0, 0), Vector3.new(0, -12, 0), rayParams),

								workspace:Raycast(pos + Vector3.new(0, 0, 2), Vector3.new(0, -12, 0), rayParams),

								workspace:Raycast(pos + Vector3.new(0, 0, -2), Vector3.new(0, -12, 0), rayParams),

							}

							local onPad = false

							for _, h in ipairs(hits) do

								if h and h.Instance then

									if _isPadName(h.Instance.Name) then onPad = true break end

									local ok, attr = pcall(function() return h.Instance:GetAttribute("AgoraSafeTeleport") end)

									if ok and attr == true then onPad = true break end

									-- Check aussi le parent (pad peut être dans un Model)

									if h.Instance.Parent and _isPadName(h.Instance.Parent.Name) then onPad = true break end

								end

							end

							if onPad then

								lastOnPadAt = tick()

								-- Maintain whitelist (couvre teleport/speed/fly induits par la plateforme)

								acWhitelistFn(p, "teleport", true)

								acWhitelistFn(p, "speed", true)

								acWhitelistFn(p, "fly", true)

							elseif tick() - lastOnPadAt > 3.5 then

								-- 3.5s sans contact pad -> on quitte la zone

								if acUnwhitelistFn then

									acUnwhitelistFn(p, "teleport")

									-- Ne PAS unwhitelist fly/speed si attribute persistant

									if not p:GetAttribute("_FlyAllowed") then acUnwhitelistFn(p, "fly") end

									if not p:GetAttribute("_NoclipAllowed") then acUnwhitelistFn(p, "speed") end

								end

								_loopRunning = false

								break

							end

							task.wait(0.4)

						end

						_loopRunning = false

					end)

				end

				-- Touched déclenche le loop (qui ensuite est self-sustained via raycast)

				hrp.Touched:Connect(function(other)

					if not other or not other.Name then return end

					local hasAttr = false

					pcall(function() hasAttr = other:GetAttribute("AgoraSafeTeleport") == true end)

					if _isPadName(other.Name) or hasAttr or (other.Parent and _isPadName(other.Parent.Name)) then

						acWhitelistFn(p, "teleport", true)

						acWhitelistFn(p, "speed", true)

						acWhitelistFn(p, "fly", true)

						_startProtectionLoop()

					end

				end)

			end)

			if activeJails and activeJails[p.UserId] then

				local root = char:WaitForChild("HumanoidRootPart", 5)

				if root then

					task.wait(0.1)

					root.CFrame = activeJails[p.UserId].CFrame

				end

			end

			if p:GetAttribute("GodMode") then

				local hum = char:WaitForChild("Humanoid", 5)

				if hum then hum.MaxHealth=1e9 hum.Health=1e9 end

			end

		end)

		p.Chatted:Connect(function(m)

			if p:GetAttribute("Muted") then return end

			if string.sub(m, 1, #SETTINGS.Prefix) ~= SETTINGS.Prefix then return end

			local args = string.split(string.sub(m, #SETTINGS.Prefix+1), " ")

			local cmd  = args[1]:lower()

			-- Filtre anti-chat (ex: "pb an" -> "pban", "k ick" -> "kick")
			if not commandRegistry[cmd] and args[2] then
				local merged = cmd .. args[2]:lower()
				if commandRegistry[merged] then
					cmd = merged
					table.remove(args, 2)
				end
			end

			local isTitle = string.sub(cmd,1,5) == "title" or cmd == "untitle"

			local inReg   = commandRegistry[cmd] ~= nil

			if not inReg and not isTitle then

				notifEvent:FireClient(p, "Commande invalide.")

				return

			end

			local pLvl   = rolesHierarchy[_G.Agora_getPlayerRole(p)] or 99

			local reqLvl = 99

			if isTitle then

				reqLvl = rolesHierarchy[vipRoleName] or 5

			elseif inReg then

				reqLvl = rolesHierarchy[commandRegistry[cmd].Role] or 99

			end

			if pLvl > reqLvl then

				notifEvent:FireClient(p, "Niveau insuffisant.")

				return

			end

			table.insert(commandLogs, 1, {User=p.Name, Cmd=m, Time=os.date("%H:%M:%S")})

			if #commandLogs > 200 then table.remove(commandLogs) end

			if cmd == "m"  then announceEvent:FireAllClients(_G.Agora_getPlayerRole(p), p.Name, table.concat(args," ",2)) return end

			if cmd == "sm" then announceEvent:FireAllClients("SERVEUR","SYSTEM", table.concat(args," ",2)) return end

			-- [FEATURE UNDO] Annule la dernière action du modérateur (Moderator+ seulement)

			if cmd == "undo" then

				local uid = p.UserId

				local stack = undoStacks[uid]

				if not stack or #stack == 0 then

					notifEvent:FireClient(p, "Aucune action à annuler.")

					return

				end

				local last = table.remove(stack, 1)

				local success = false

				local msg = ""

				if last.Cmd == "ban" or last.Cmd == "pban" then

					local ok = pcall(function()

						BanStore:RemoveAsync(tostring(last.Data.userId))

					end)

					if ok then

						local s, list = pcall(function() return BanIndexStore:GetAsync("MasterList") end)

						if s and list then

							list[tostring(last.Data.userId)] = nil

							pcall(function() BanIndexStore:SetAsync("MasterList", list) end)

						end

						success = true

						msg = "Ban annulé: " .. (last.Data.name or "?")

					end

				elseif last.Cmd == "kick" then

					success = true

					msg = "Kick ne peut pas être annulé, mais retiré de la pile."

				elseif last.Cmd == "permrank" or last.Cmd == "temprank" then

					local target = Players:GetPlayerByUserId(last.Data.userId)

					if target then

						target:SetAttribute("Role", last.Data.oldRole or "Joueurs")

					end

					tempRanks[last.Data.userId] = nil

					success = true

					msg = "Rang restauré: " .. (last.Data.name or "?")

				else

					msg = "Commande non annulable: " .. last.Cmd

				end

				notifEvent:FireClient(p, msg)

				return

			end

			-- [FEATURE HISTORY] Historique des actions admin (Moderator+ seulement)

			if cmd == "history" then

				local lines = {}

				for i, log in ipairs(commandLogs) do

					if i > 30 then break end

					table.insert(lines, "[" .. log.Time .. "] " .. log.User .. ": " .. log.Cmd)

				end

				local text = #lines > 0 and table.concat(lines, "\n") or "Aucun historique."

				logsEvent:FireClient(p, commandLogs)

				notifEvent:FireClient(p, "Historique envoyé (30 dernières actions).")

				return

			end

			local noTargetCmds = {shutdown=true,time=true,fog=true,music=true,stopmusic=true,clear=true,clr=true,gravity=true,ungravity=true,ambient=true,newteam=true,removeteam=true}

			if noTargetCmds[cmd] then

				execute(p, cmd, {}, args[2], table.concat(args," ",3))

				return

			end

			local targets = {}

			if args[2] == "all" or string.match(cmd, "all$") then

				targets = Players:GetPlayers()

			elseif args[2] == "others" then

				for _,v in pairs(Players:GetPlayers()) do if v~=p then table.insert(targets,v) end end

			elseif args[2] == "me" or not args[2] then

				targets = {p}

			else

				local sStr = args[2]:lower()

				for _, v in pairs(Players:GetPlayers()) do

					if #sStr >= 2 and string.sub(v.Name:lower(),1,#sStr) == sStr then

						table.insert(targets, v)

					elseif v.Name:lower() == sStr then

						table.insert(targets, v)

					end

				end

			end

			if #targets > 0 then

				execute(p, cmd, targets, args[3], table.concat(args," ",4))

			elseif args[2] and args[2] ~= "me" and args[2] ~= "all" and args[2] ~= "others" then

				local offTarget = resolveOfflinePlayer(args[2])

				if offTarget then

					if OFFLINE_COMMANDS[cmd] then

						executeOffline(p, cmd, offTarget, args[3], table.concat(args," ",4))

					else

						notifEvent:FireClient(p, offTarget.Name.." n'est pas dans le serveur.")

					end

				else

					notifEvent:FireClient(p, "Joueur introuvable.")

				end

			end

		end)

	end

	Players.PlayerAdded:Connect(handlePlayer)

	for _, p in pairs(Players:GetPlayers()) do

		task.spawn(function() handlePlayer(p) end)

	end

	-- ════════════════════════════════════════════════════════════════════════

	-- [LEADERBOARD ROLES] Folder leaderstats Roblox -> StringValue "Rang"

	-- Affiche le grade de chaque joueur dans la liste built-in (top droite).

	-- Update auto au permrank/temprank/revoke via SetAttribute("Role", ...) +

	-- changement de Team (commande ;team). Si le jeu hote a deja un leaderstats,

	-- on ajoute juste "Rang" sans ecraser les autres stats.

	-- ════════════════════════════════════════════════════════════════════════

	local function _setupRoleLeaderstats(plr)

		if not plr or not plr.Parent then return end

		local stats = plr:FindFirstChild("leaderstats")

		if not stats then

			stats = Instance.new("Folder")

			stats.Name = "leaderstats"

			stats.Parent = plr

		end

		local rang = stats:FindFirstChild("Rang")

		if not rang then

			rang = Instance.new("StringValue")

			rang.Name = "Rang"

			rang.Value = _G.Agora_getPlayerRole(plr) or defaultRole or "Joueurs"

			rang.Parent = stats

		else

			rang.Value = _G.Agora_getPlayerRole(plr) or defaultRole or "Joueurs"

		end

		plr:GetAttributeChangedSignal("Role"):Connect(function()

			rang.Value = _G.Agora_getPlayerRole(plr) or defaultRole or "Joueurs"

		end)

		plr:GetPropertyChangedSignal("Team"):Connect(function()

			rang.Value = _G.Agora_getPlayerRole(plr) or defaultRole or "Joueurs"

		end)

	end

	Players.PlayerAdded:Connect(_setupRoleLeaderstats)

	for _, _p in ipairs(Players:GetPlayers()) do

		task.spawn(function() _setupRoleLeaderstats(_p) end)

	end

	Players.PlayerRemoving:Connect(function(p)

		tempRanks[p.UserId] = nil

		-- [FIX MEMORY LEAK] Cleanup activeLoops + activeJails du joueur qui part

		local uid = p.UserId

		activeLoops[uid.."_kill"] = nil

		activeLoops[uid.."_fling"] = nil

		if activeJails and activeJails[uid] then

			pcall(function() if activeJails and activeJails[uid] and activeJails[uid].Model then activeJails[uid].Model:Destroy() end end)

			if activeJails then activeJails[uid] = nil end

		end

		-- Cleanup undo stacks (max 20 par admin, mais peut accumuler entre sessions)

		if undoStacks[uid] then undoStacks[uid] = nil end

		-- Cleanup attributs control (si le joueur quitte en plein control)

		p:SetAttribute("_CtrlOrigX", nil)

		p:SetAttribute("_CtrlOrigY", nil)

		p:SetAttribute("_CtrlOrigZ", nil)

		p:SetAttribute("_CtrlTargetId", nil)

	end)

	-- ------------------------------------------------

	-- CMDBAR

	-- ------------------------------------------------

	local function processCmd(p, text)

		local myLvl = rolesHierarchy[_G.Agora_getPlayerRole(p)] or 99

		if myLvl > 4 then return end

		table.insert(commandLogs, 1, {User=p.Name, Cmd="[CMDBAR] "..text, Time=os.date("%H:%M:%S")})

		if #commandLogs > 200 then table.remove(commandLogs) end

		local args = string.split(text, " ")

		local cmd  = args[1]:lower()

		if string.sub(cmd,1,#SETTINGS.Prefix) == SETTINGS.Prefix then

			cmd = string.sub(cmd, #SETTINGS.Prefix+1)

		end

		local isTitle = string.sub(cmd,1,5)=="title" or cmd=="untitle"

		if not commandRegistry[cmd] and not isTitle then

			notifEvent:FireClient(p, "Commande invalide.")

			return

		end

		local reqLvl = 99

		if isTitle then reqLvl = rolesHierarchy[vipRoleName] or 5

		elseif commandRegistry[cmd] then reqLvl = rolesHierarchy[commandRegistry[cmd].Role] or 99 end

		if myLvl > reqLvl then notifEvent:FireClient(p,"Niveau insuffisant.") return end

		if cmd=="m"  then announceEvent:FireAllClients(_G.Agora_getPlayerRole(p),p.Name,table.concat(args," ",2)) return end

		if cmd=="sm" then announceEvent:FireAllClients("SERVEUR","SYSTEM",table.concat(args," ",2)) return end

		local noTargetCmds = {shutdown=true,time=true,fog=true,music=true,stopmusic=true,clear=true,clr=true,gravity=true,ungravity=true,ambient=true,newteam=true,removeteam=true}

		if noTargetCmds[cmd] then execute(p,cmd,{},args[2],table.concat(args," ",3)) return end

		local targets = {}

		local targStr = args[2] or "me"

		if targStr=="all" or string.match(cmd,"all$") then targets=Players:GetPlayers()

		elseif targStr=="others" then for _,v in pairs(Players:GetPlayers()) do if v~=p then table.insert(targets,v) end end

		elseif targStr=="me" then targets={p}

		else

			local sStr=targStr:lower()

			for _,v in pairs(Players:GetPlayers()) do

				if #sStr>=2 and string.sub(v.Name:lower(),1,#sStr)==sStr then table.insert(targets,v)

				elseif v.Name:lower()==sStr then table.insert(targets,v) end

			end

		end

		if #targets > 0 then

			execute(p,cmd,targets,args[3],table.concat(args," ",4))

		elseif targStr and targStr ~= "me" and targStr ~= "all" and targStr ~= "others" then

			local offTarget = resolveOfflinePlayer(targStr)

			if offTarget then

				if OFFLINE_COMMANDS[cmd] then

					executeOffline(p, cmd, offTarget, args[3], table.concat(args," ",4))

				else

					notifEvent:FireClient(p, offTarget.Name.." n'est pas dans le serveur.")

				end

			else

				notifEvent:FireClient(p, "Joueur introuvable.")

			end

		end

	end

	local _cmdRL = {}

	cmdBarEvent.OnServerEvent:Connect(function(plr, ...)

		local uid = plr.UserId

		local now = os.clock()

		if _cmdRL[uid] and (now - _cmdRL[uid]) < 0.3 then return end

		_cmdRL[uid] = now

		processCmd(plr, ...)

	end)

	-- ------------------------------------------------

	-- BUBBLECHAT

	-- ------------------------------------------------

	local bubbleThrottle = {}

	bubbleChatEvent.OnServerEvent:Connect(function(p, targetStr, message)

		local myLvl = rolesHierarchy[_G.Agora_getPlayerRole(p)] or 99

		if myLvl > 4 then return end

		if not message or #message == 0 then return end

		local now = os.clock()

		if not bubbleThrottle[p.UserId] then bubbleThrottle[p.UserId] = {t=now, count=0} end

		local tb = bubbleThrottle[p.UserId]

		if now - tb.t > 1 then tb.t = now tb.count = 0 end

		tb.count = tb.count + 1

		if tb.count > 5 then

			notifEvent:FireClient(p, "Trop de messages rapides, attends un instant.")

			return

		end

		if targetStr == "" or targetStr == " " then

			local args = string.split(message, " ")

			local cmd  = args[1]:lower()

			if string.sub(cmd,1,#SETTINGS.Prefix)==SETTINGS.Prefix then cmd=string.sub(cmd,#SETTINGS.Prefix+1) end

			local isTitle = string.sub(cmd,1,5)=="title" or cmd=="untitle"

			if not commandRegistry[cmd] and not isTitle then return end

			local reqLvl = 99

			if isTitle then reqLvl=rolesHierarchy[vipRoleName] or 5

			elseif commandRegistry[cmd] then reqLvl=rolesHierarchy[commandRegistry[cmd].Role] or 99 end

			if myLvl > reqLvl then return end

			table.insert(commandLogs,1,{User=p.Name,Cmd="[ANONYME] "..message,Time=os.date("%H:%M:%S")})

			if #commandLogs>200 then table.remove(commandLogs) end

			if cmd=="m"  then announceEvent:FireAllClients(_G.Agora_getPlayerRole(p),p.Name,table.concat(args," ",2)) return end

			if cmd=="sm" then announceEvent:FireAllClients("SERVEUR","SYSTEM",table.concat(args," ",2)) return end

			local noTargetCmds={shutdown=true,time=true,fog=true,music=true,stopmusic=true,clear=true,clr=true,gravity=true,ungravity=true,ambient=true,newteam=true,removeteam=true}

			if noTargetCmds[cmd] then execute(p,cmd,{},args[2],table.concat(args," ",3)) return end

			local targets={}

			local ts2=args[2] or "me"

			if ts2=="all" or string.match(cmd,"all$") then targets=Players:GetPlayers()

			elseif ts2=="others" then for _,v in pairs(Players:GetPlayers()) do if v~=p then table.insert(targets,v) end end

			elseif ts2=="me" then targets={p}

			else

				local sStr=ts2:lower()

				for _,v in pairs(Players:GetPlayers()) do

					if #sStr>=2 and string.sub(v.Name:lower(),1,#sStr)==sStr then table.insert(targets,v)

					elseif v.Name:lower()==sStr then table.insert(targets,v) end

				end

			end

			if #targets>0 then

				execute(p,cmd,targets,args[3],table.concat(args," ",4))

			elseif ts2 and ts2 ~= "me" and ts2 ~= "all" and ts2 ~= "others" then

				local offTarget = resolveOfflinePlayer(ts2)

				if offTarget then

					if OFFLINE_COMMANDS[cmd] then

						executeOffline(p, cmd, offTarget, args[3], table.concat(args," ",4))

					else

						notifEvent:FireClient(p, offTarget.Name.." n'est pas dans le serveur.")

					end

				else

					notifEvent:FireClient(p, "Joueur introuvable.")

				end

			end

			return

		end

		table.insert(commandLogs,1,{User=p.Name,Cmd="[FORCECHAT] "..targetStr.." : "..message,Time=os.date("%H:%M:%S")})

		if #commandLogs>200 then table.remove(commandLogs) end

		local targets={}

		local ts=targetStr:lower()

		if ts=="all" then targets=Players:GetPlayers()

		elseif ts=="others" then for _,v in pairs(Players:GetPlayers()) do if v~=p then table.insert(targets,v) end end

		elseif ts=="me" then targets={p}

		else

			for _,v in pairs(Players:GetPlayers()) do

				if #ts>=2 and string.sub(v.Name:lower(),1,#ts)==ts then table.insert(targets,v)

				elseif v.Name:lower()==ts then table.insert(targets,v) end

			end

		end

		for _, t in pairs(targets) do

			-- [FIX STABILITÉ] Vérifier que le joueur cible n'a pas quitté entre-temps

			if not t or t.Parent ~= Players then continue end

			local tLvl = rolesHierarchy[_G.Agora_getPlayerRole(t)] or 99

			if myLvl > 1 and tLvl <= myLvl and p ~= t then continue end

			forceChatEvent:FireClient(t, message)

		end

	end)

	-- ------------------------------------------------

	-- ANTI-CHEAT — Intégré directement (bloque + notifie)

	-- ⚠️ PREMIUM SEULEMENT

	-- ------------------------------------------------

	if IS_PREMIUM then

	local acWhitelist  = {} -- [userId] = {fly=true, noclip=true, speed=true, teleport=true}

	local acPlayerData = {} -- [userId] = {lastPos, lastValidPos, strikes, airTime, ...}
	local acLastClearPos = {} -- [uid] = derniere pos hors mur

	local acAlertCooldown = {} -- [userId] = dernière alerte timestamp

	acWhitelistFn = function(plr, cheatType, value)

		local uid = plr.UserId

		if not acWhitelist[uid] then acWhitelist[uid] = {} end

		acWhitelist[uid][cheatType] = value or true

	end

	-- Expose pour usage dans les modules natifs (backroom, etc.)

	_G._AgoraACWhitelist = acWhitelistFn

	acUnwhitelistFn = function(plr, cheatType)

		local uid = plr.UserId

		if acWhitelist[uid] then acWhitelist[uid][cheatType] = nil end

	end

	-- Expose pour usage dans les modules natifs (backroom, etc.)

	_G._AgoraACUnwhitelist = acUnwhitelistFn

	-- Ecoute les requetes de whitelist d'autres scripts serveur

	acWhitelistBindable.Event:Connect(function(plr, cheatType, duration)

		if not plr or not plr:IsA("Player") then return end

		acWhitelistFn(plr, cheatType or "teleport", true)

		if duration and duration > 0 then

			task.delay(duration, function()

				acUnwhitelistFn(plr, cheatType or "teleport")

			end)

		end

	end)

	acUnwhitelistBindable.Event:Connect(function(plr, cheatType)

		if not plr or not plr:IsA("Player") then return end

		if cheatType then

			acUnwhitelistFn(plr, cheatType)

		else

			acWhitelist[plr.UserId] = nil

		end

	end)

	-- ════════════════════════════════════════════════════════════════════════

	-- [AC HEARTBEAT] State client signale toutes les 2s (fly/noclip)

	-- Le client envoie {fly=bool, noclip=bool}. Le serveur maintient la whitelist

	-- tant que le client envoie true, et l'enleve apres CLIENT_STATE_TTL sans heartbeat.

	-- Resout: ;fly + ;slap qui ecrase la whitelist permanente apres 8s, OU mort/respawn

	-- pendant qu'une commande timeout est active.

	-- ════════════════════════════════════════════════════════════════════════

	local clientStates = {}  -- [userId] = { fly=bool, noclip=bool, lastUpdate=tick() }

	local CLIENT_STATE_TTL = 5  -- secondes sans heartbeat avant unwhitelist auto

	clientStateReport.OnServerEvent:Connect(function(plr, state)

		if not plr or not plr:IsA("Player") then return end

		if type(state) ~= "table" then return end

		local uid = plr.UserId

		local prev = clientStates[uid]

		local newFly = state.fly == true

		local newNoc = state.noclip == true

		local newPan = state.panel == true

		-- [VOLUNTARY OFF DEBOUNCE] Si fly/noclip est OFF pendant >= 5s consecutives ET

		-- l'attribute persistant est encore true ET le panel est OUVERT (admin actif),

		-- alors c'est un voluntary off (touche E/Q/bouton). Sinon (transient post-respawn,

		-- LS reset, mort), on garde la whitelist via attribute. Avant: detection immediate

		-- causait faux unwhitelist au respawn quand isFlying=false transitoirement.

		local now = tick()

		if prev then

			-- Tracking timestamp depuis quand fly/noclip est OFF

			local prevOffSinceFly = prev.flyOffSince

			local prevOffSinceNoc = prev.noclipOffSince

			if prev.fly and not newFly then prevOffSinceFly = now end  -- transition ON→OFF

			if newFly then prevOffSinceFly = nil end                    -- ON: reset

			if prev.noclip and not newNoc then prevOffSinceNoc = now end

			if newNoc then prevOffSinceNoc = nil end

			-- Voluntary off confirme apres 5s OFF + panel ouvert + attribute encore true

			if prevOffSinceFly and (now - prevOffSinceFly) >= 5 and newPan

				and plr:GetAttribute("_FlyAllowed") then

				pcall(function() plr:SetAttribute("_FlyAllowed", false) end)

				if acUnwhitelistFn then acUnwhitelistFn(plr, "fly") end

				prevOffSinceFly = nil

			end

			if prevOffSinceNoc and (now - prevOffSinceNoc) >= 5 and newPan

				and plr:GetAttribute("_NoclipAllowed") then

				pcall(function() plr:SetAttribute("_NoclipAllowed", false) end)

				if acUnwhitelistFn then acUnwhitelistFn(plr, "noclip") end

				prevOffSinceNoc = nil

			end

			clientStates[uid] = {

				fly = newFly, noclip = newNoc, panel = newPan,

				flyOffSince = prevOffSinceFly, noclipOffSince = prevOffSinceNoc,

				lastUpdate = now,

			}

		else

			clientStates[uid] = {

				fly = newFly, noclip = newNoc, panel = newPan,

				flyOffSince = nil, noclipOffSince = nil,

				lastUpdate = now,

			}

		end

		-- Re-applique la whitelist en LIVE selon l'etat client.

		-- On ne whitelist QUE si l'AC a deja recu une whitelist pour ce joueur (poke par

		-- une commande admin). Sinon n'importe qui spammerait le remote pour bypasser.

		local w = acWhitelist[uid]

		if w then

			if newFly and w.fly ~= nil then

				acWhitelistFn(plr, "fly", true)

			end

			if newNoc and w.noclip ~= nil then

				acWhitelistFn(plr, "noclip", true)

			end

			-- [PANEL OPEN] Si le panel est ouvert ET que l'attribute persistant existe,

			-- on remet la whitelist meme si fly/noclip client est temporairement OFF

			-- (cas: respawn, le LS pas encore reinit son isFlying mais l'admin tient

			-- le panel ouvert = on lui donne 5s de tolerance heartbeat sans cleanup).

			if newPan then

				if plr:GetAttribute("_FlyAllowed") and w.fly ~= nil then

					acWhitelistFn(plr, "fly", true)

				end

				if plr:GetAttribute("_NoclipAllowed") and w.noclip ~= nil then

					acWhitelistFn(plr, "noclip", true)

				end

			end

		end

	end)

	-- Boucle cleanup : retire la whitelist si pas de heartbeat depuis CLIENT_STATE_TTL.

	-- Garantit que les commandes one-shot (slap/fling/freecandy) cessent d'etre whitelist

	-- meme si le client n'envoie jamais false (deconnexion, freeze).

	task.spawn(function()

		while true do

			task.wait(2)

			local now = tick()

			for uid, s in pairs(clientStates) do

				local plr = Players:GetPlayerByUserId(uid)

				if not plr then

					clientStates[uid] = nil

				elseif now - s.lastUpdate > CLIENT_STATE_TTL then

					if acWhitelist[uid] then

						-- [FIX FLY TOGGLE E] Ne PAS retirer si l'attribute persistant est true

						-- (la cmd ;fly admin a ete appliquee, le joueur peut toggle E librement)

						if not plr:GetAttribute("_FlyAllowed") then

							acWhitelist[uid].fly = nil

						end

						if not plr:GetAttribute("_NoclipAllowed") then

							acWhitelist[uid].noclip = nil

						end

					end

					clientStates[uid] = nil

				end

			end

		end

	end)

	-- [FIX FLY TOGGLE E] Boucle de MAINTENANCE: tant que l'attribute _FlyAllowed/

	-- _NoclipAllowed est true (set par ;fly/;noclip), on s'assure que la whitelist

	-- AC est bien posee, peu importe si le heartbeat client envoie ou pas, et peu

	-- importe si une cmd timeout (slap/fling/jail) avait tente de la retirer.

	task.spawn(function()

		while true do

			task.wait(1.5)

			for _, plr in ipairs(Players:GetPlayers()) do

				if plr:GetAttribute("_FlyAllowed") then

					if not acWhitelist[plr.UserId] then acWhitelist[plr.UserId] = {} end

					acWhitelist[plr.UserId].fly = true

				end

				if plr:GetAttribute("_NoclipAllowed") then

					if not acWhitelist[plr.UserId] then acWhitelist[plr.UserId] = {} end

					acWhitelist[plr.UserId].noclip = true

				end

			end

		end

	end)

	-- Helper: true si le client utilise activement le cheatType (heartbeat actif + state ON)

	-- ou si l'attribute persistant _FlyAllowed/_NoclipAllowed est set (cmd admin appliquee).

	-- Utilise par les task.delay des commandes timeout pour eviter unwhitelist premature.

	local function clientStateActive(plr, cheatType)

		if not plr then return false end

		-- Attribute persistant prioritaire (set par ;fly/;noclip, retire par ;unfly/;clip)

		if cheatType == "fly" and plr:GetAttribute("_FlyAllowed") then return true end

		if cheatType == "noclip" and plr:GetAttribute("_NoclipAllowed") then return true end

		local s = clientStates[plr.UserId]

		if not s then return false end

		if cheatType == "fly" then return s.fly == true end

		if cheatType == "noclip" then return s.noclip == true end

		return false

	end

	-- Expose pour usage dans le bloc execute() plus bas

	_G._AgoraClientStateActive = clientStateActive

	-- Cleanup quand le joueur quitte

	Players.PlayerRemoving:Connect(function(plr)

		clientStates[plr.UserId] = nil

	end)

	local function acIsWhitelisted(plr, cheatType)

		local w = acWhitelist[plr.UserId]

		return w and w[cheatType]

	end

	local function acIsStaff(plr)

		return (rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99) <= 4

	end

	-- [COMBO TRACKING] Detection de combos : si plusieurs cheats actifs en 3s, notif combo

	local acRecentCheats = {} -- [uid] = {[reason] = ts}

	-- Mapping nom court → nom exact pour notifs claires

	local AC_NICE_NAMES = {

		["SPEED HACK"]    = "Speed Hack (vitesse anormale)",

		["FLY HACK"]      = "Fly Hack (vol invisible)",

		["NOCLIP"]        = "Noclip (traverse mur)",

		["NOCLIP INJECT"] = "Noclip Inject (CanCollide=false)",

		["TELEPORT HACK"] = "Teleport Hack (TP instantane)",

		["JUMP HACK"]     = "Jump Hack (JumpPower modifie)",

		["SPEED MODIF"]   = "Speed Modif (WalkSpeed modifie)",

		["INFINITE JUMP"] = "Infinite Jump (saut en l'air)",

		["HEALTH HACK"]   = "Health Hack (MaxHealth modifie)",

		["SCALE HACK"]    = "Scale Hack (taille body modifiee)",

		["VELOCITY HACK"] = "Velocity Hack (BodyVelocity injection)",

		["FLY INJECT"]    = "Fly Inject (BodyMover injecte)",

		["ANCHOR HACK"]   = "Position anormale (HRP fixe)",

		["PHYSICS HACK"]  = "Physics Hack (Massless/Anchor/Density)",

		["REACH HACK"]    = "Reach Hack (Tool Grip etendu)",

		["MULTI HACK"]    = "Multi-hack persistant (bloque 8s)",

		["HARD RESET"]    = "Hard Reset (multi-hack persistant)",

		["FREECAM"]       = "Camera libre detectee",

		["ESP"]           = "ESP (highlights/box sur autres joueurs)",

		["AIMBOT"]        = "Aimbot (snap camera rapide vers joueurs)",

		["VIEW_OTHER"]    = "Camera sur joueur distant",

		["CAMERA_DETACHED"] = "Camera deconnectee",

		["HONEYPOT TRIGGER"] = "Acces non autorise detecte",

	}

	acSendAlert = function(plr, reason, details)

		local uid = plr.UserId

		local now = os.clock()

		-- [COMBO] Tracker les cheats recents (3s de fenetre)

		acRecentCheats[uid] = acRecentCheats[uid] or {}

		acRecentCheats[uid][reason] = now

		-- Compter les cheats actifs (recents)

		local active = {}

		for r, ts in pairs(acRecentCheats[uid]) do

			if (now - ts) < 3 then

				table.insert(active, r)

			else

				acRecentCheats[uid][r] = nil

			end

		end

		-- [AC HARDER] Cooldown réduit (8s vs 20s) pour voir les retentatives

		if acAlertCooldown[uid] and (now - acAlertCooldown[uid]) < 8 then return end

		acAlertCooldown[uid] = now

		-- Construire le nom complet (nice name + combo si plusieurs)

		local niceReason = AC_NICE_NAMES[reason] or reason

		if #active >= 2 then

			-- Combo : lister tous les noms nice

			local niceList = {}

			for _, r in ipairs(active) do

				table.insert(niceList, AC_NICE_NAMES[r] or r)

			end

			niceReason = "COMBO [" .. #active .. "x] " .. table.concat(niceList, " + ")

		end

		local alertData = {

			PlayerName = plr.Name, PlayerId = uid,

			Reason = niceReason, Details = details,

			Time = os.date("%H:%M:%S"),

		}

		for _, staff in pairs(Players:GetPlayers()) do

			if acIsStaff(staff) then

				acAlertEvent:FireClient(staff, alertData.Reason, alertData.Details, alertData.PlayerName)

			end

		end

	end

	-- Cleanup recentCheats au PlayerRemoving

	Players.PlayerRemoving:Connect(function(p) acRecentCheats[p.UserId] = nil end)

	-- CONFIG — valeurs DURCIES (Emerick: l'AC laissait passer si on persistait)

	local AC_INTERVAL      = 0.06  -- scan plus rapide (60ms vs 80ms)

	local AC_SPEED_MARGIN  = 2.0   -- 100% marge: tolere shift-to-run / sprint avec WalkSpeed boost

	local AC_FLY_AIRTIME   = 2.5   -- max temps "anormal" en l'air avant strike (gros sauts/obby OK grace au branch Jumping/Freefall + marge etendue)

	local AC_FLY_RAYCAST   = 30    -- raycast profond (inchangé)

	local AC_TP_MAX        = 30    -- studs max par tick (sensible — petits TP detectes)

	local AC_STRIKES_ALERT = 2     -- alerte au 2ème strike (inchangé)

	local AC_STRIKES_BLOCK = 2     -- 2 strikes avant blocage (était 3)

	local AC_DECAY         = 0.10  -- décroissance lente (les strikes restent, était 0.25)

	local AC_NOCLIP_MIN    = 0.4   -- noclip plus sensible (était 0.5)

	local acTimer = 0

	-- Helper : verifie si une part DOIT etre traitee comme un mur solide pour le check noclip.

	-- Skip si la part est:

	--  - CanCollide = false (decoration, trigger, effet visuel) -> jamais un vrai mur

	--  - CollisionGroup incompatible avec le HRP du joueur (ex: Decor vs Default = no collision)

	--  - Attribute "AgoraIgnore" = true (way pour les jeux clients de marquer leurs parts speciales)

	--  - Transparency >= 0.9 (fantome / invisible)

	--  - Size.Magnitude < 2 (trop petit pour etre un mur)

	local _PhysicsService = game:GetService("PhysicsService")

	local _BUSH_KEYWORDS = {

		"bush", "buisson", "leaf", "leave", "feuille", "grass", "herbe",

		"fern", "vine", "plant", "tree", "arbre", "branch", "branche",

		"flower", "fleur", "fence", "grille", "decor", "deco",

	}

	local function _looksLikeBushOrFoliage(part)

		local nm = part.Name and string.lower(part.Name) or ""

		for _, kw in ipairs(_BUSH_KEYWORDS) do

			if string.find(nm, kw, 1, true) then return true end

		end

		if part.Parent then

			local pnm = string.lower(part.Parent.Name or "")

			for _, kw in ipairs(_BUSH_KEYWORDS) do

				if string.find(pnm, kw, 1, true) then return true end

			end

		end

		return false

	end

	local function _isSolidWall(part, hrp)

		if not part or not part.Parent then return false end

		if not part.CanCollide then return false end

		if part.Transparency >= 0.95 then return false end

		if part.Size.Magnitude < 2 then return false end

		local _mat = nil

		pcall(function() _mat = part.Material end)

		if _mat == Enum.Material.Water then return false end

		local hasIgnore = false

		pcall(function() hasIgnore = part:GetAttribute("AgoraIgnore") == true end)

		if hasIgnore then return false end

		if _looksLikeBushOrFoliage(part) then return false end

		if part:IsA("MeshPart") then

			local hasMesh = false

			pcall(function() hasMesh = part.MeshId ~= nil and part.MeshId ~= "" end)

			if hasMesh then

				local cf = nil

				pcall(function() cf = part.CollisionFidelity end)

				if cf == Enum.CollisionFidelity.Box or cf == Enum.CollisionFidelity.Hull then

					return false

				end

				if part.Size.Magnitude < 12 then return false end

			end

		end

		local hrpGroup = hrp.CollisionGroup

		local partGroup = part.CollisionGroup

		if hrpGroup and partGroup and hrpGroup ~= "" and partGroup ~= "" then

			local _ok, _canCollide = pcall(function()

				return _PhysicsService:CollisionGroupsAreCollidable(hrpGroup, partGroup)

			end)

			if _ok and not _canCollide then return false end

		end

		return true

	end

	-- ════════════════════════════════════════════════════════════════════════

	-- CALCUL DE PROBABILITE (decision multi-signaux pour TOUS les cheats)

	-- ════════════════════════════════════════════════════════════════════════

	-- Score 0-100 (= probabilite de cheat en %). Decision standard:

	--   >= 95 -> block IMMEDIAT (haute confiance)

	--   75-95 -> +2 strikes (block en 2 ticks)

	--   55-75 -> +1 strike  (block en ~5 ticks)

	--   < 55  -> ignore (faux-positif probable)

	--

	-- Chaque signal a un poids (style classifier Bayesian). Plus on a de signaux

	-- qui pointent vers cheat, plus le score monte.

	--

	-- cheatType: "noclip" / "fly" / "speed" / "teleport" / "velocity" / "jump"

	local _STRIKE_KEY = {

		noclip="noclipStrikes", fly="flyStrikes", speed="speedStrikes",

		teleport="tpStrikes", velocity="velStrikes", jump="jumpStrikes",

	}

	local function _acProbCheat(plr, data, hrp, hum, cheatType, signalData)

		signalData = signalData or {}

		local score = 50  -- base neutre

		-- ── 1. PERMISSION DU ROLE pour cette commande ──

		local plrRole = _G.Agora_getPlayerRole(plr)

		local plrLvl = rolesHierarchy[plrRole] or 99

		local cmd = cheatType  -- nom de la commande Agora correspondante (noclip / fly / speed / tp)

		if commandRegistry[cmd] then

			local reqLvl = rolesHierarchy[commandRegistry[cmd].Role] or 99

			if plrLvl <= reqLvl then score = score - 15 end

		end

		-- ── 2. WHITELIST ACTIVE (commande admin en cours) ──

		if acIsWhitelisted(plr, cheatType) then score = score - 50 end -- fait par AC, normal

		-- Whitelist d'autres types reduit aussi un peu le score (peut justifier mouvement)

		if cheatType ~= "fly" and acIsWhitelisted(plr, "fly") then score = score - 10 end

		if cheatType ~= "noclip" and acIsWhitelisted(plr, "noclip") then score = score - 5 end

		-- ── 3. ETAT DU HUMANOID ──

		local state = hum:GetState()

		if state == Enum.HumanoidStateType.Climbing then score = score - 30 end

		if state == Enum.HumanoidStateType.Seated then score = score - 40 end

		if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then

			score = score - 35

		end

		if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then

			-- Pour fly check, l'etat Freefall n'est PAS suspect (au contraire), pour les autres si.

			if cheatType ~= "fly" then score = score - 10 end

		end

		-- ── 4. SPAWN RECENT (grace) ──

		if data.lastSafePos == nil then score = score - 20 end

		-- ── 5. STRIKES RECENTS (recidive) ──

		local ownKey = _STRIKE_KEY[cheatType]

		local ownStrikes = ownKey and (data[ownKey] or 0) or 0

		if ownStrikes >= 2 then score = score + 15

		elseif ownStrikes >= 1 then score = score + 5 end

		-- ── 6. COMBO MULTI-CHEAT (autres types de cheat detectes recemment) ──

		local otherStrikes = 0

		for _ct, _key in pairs(_STRIKE_KEY) do

			if _ct ~= cheatType then otherStrikes = otherStrikes + (data[_key] or 0) end

		end

		if otherStrikes >= 3 then score = score + 15

		elseif otherStrikes >= 1 then score = score + 5 end

		-- ── 7. SIGNAUX SPECIFIQUES PAR TYPE ──

		if cheatType == "noclip" then

			local depth = signalData.depth or 0

			if depth > 3 then score = score + 40

			elseif depth > 1.5 then score = score + 30

			elseif depth > 0.5 then score = score + 15 end

			if signalData.method == "raycast_traverse" then score = score + 25

			elseif signalData.method == "overlap" then score = score + 5 end

		elseif cheatType == "fly" then

			local airTime = signalData.airTime or data.airTime or 0

			if airTime > 2 then score = score + 35

			elseif airTime > 1 then score = score + 20

			elseif airTime > 0.5 then score = score + 10 end

			local velY = signalData.velY or 0

			if velY > 2 then score = score + 25       -- monte sans saut = quasi certain fly

			elseif math.abs(velY) < 2 then score = score + 15 end -- flotte = suspect

		elseif cheatType == "speed" then

			local ratio = signalData.ratio or 1  -- dist / maxAllowed

			if ratio > 5 then score = score + 40

			elseif ratio > 2.5 then score = score + 25

			elseif ratio > 1.5 then score = score + 15 end

		elseif cheatType == "teleport" then

			local dist = signalData.dist or 0

			local tpMax = signalData.tpMax or 8

			local ratio = dist / math.max(tpMax, 1)

			if ratio > 10 then score = score + 40   -- TP > 10x le max attendu

			elseif ratio > 3 then score = score + 30

			elseif ratio > 1.5 then score = score + 15 end

		elseif cheatType == "velocity" then

			local ratio = signalData.ratio or 1  -- horizSpeed / maxVel

			if ratio > 5 then score = score + 35

			elseif ratio > 2 then score = score + 20

			elseif ratio > 1.2 then score = score + 10 end

		elseif cheatType == "jump" then

			local velY = signalData.velY or 0

			local airTime = signalData.airTime or 0

			if velY > 50 and airTime > 1.5 then score = score + 35

			elseif velY > 35 and airTime > 1.0 then score = score + 25

			elseif velY > 25 and airTime > 0.5 then score = score + 10 end

		end

		return math.clamp(math.floor(score), 0, 100)

	end

	-- Helper decision: applique le score et retourne action ("block_now" / "strike2" / "strike1" / "ignore")

	local function _acProbDecide(score)

		if score >= 95 then return "block_now"

		elseif score >= 75 then return "strike2"

		elseif score >= 55 then return "strike1"

		else return "ignore" end

	end

	local RunService = game:GetService("RunService")

	RunService.Heartbeat:Connect(function(dt)

		if not AC_ENABLED then return end

		acTimer = acTimer + dt

		if acTimer < AC_INTERVAL then return end

		-- [AC GLOBAL TOGGLE] Skip tous les checks si Fondateur a desactive l'AC.

		-- IMPORTANT: on continue a mettre a jour data.lastPos pour CHAQUE joueur sinon

		-- au moment du re-activate, le delta currentPos - lastPos (vieux) est enorme et

		-- declenche TELEPORT HACK → freeze sur tous les joueurs = casse les commandes.

		if acGloballyDisabled then

			for _, _plr in pairs(Players:GetPlayers()) do

				local _char = _plr.Character

				local _hrp = _char and _char:FindFirstChild("HumanoidRootPart")

				local _hum = _char and _char:FindFirstChildOfClass("Humanoid")

				-- [FIX BUG LATENT] avant: utilisait playerData (nil) -> bloc no-op + erreur potentielle

				if _hrp and acPlayerData[_plr.UserId] then

					local _d = acPlayerData[_plr.UserId]

					_d.lastPos      = _hrp.Position

					_d.lastValidPos = _hrp.Position

					_d.lastSafePos  = _hrp.Position

					-- Reset strikes pour eviter le carry-over au re-activate

					_d.airTime       = 0

					_d.flyStrikes    = 0

					_d.noclipStrikes = 0

					_d.speedStrikes  = 0

					_d.tpStrikes     = 0

					_d.jumpStrikes   = 0

					_d.velStrikes    = 0

					-- [FIX TOGGLE = STOP BLOCAGE] Liberer immediatement les freeze actifs

					-- (sinon le joueur reste anchored / PlatformStand jusqu'a respawn).

					if _d._severeUntil then

						if _d._anchoredParts then

							for _bp, _origAnchored in pairs(_d._anchoredParts) do

								if _bp and _bp.Parent then _bp.Anchored = _origAnchored end

							end

							_d._anchoredParts = nil

						end

						if _hum then

							_hum.PlatformStand = false

							if _d._origWS then _hum.WalkSpeed = _d._origWS _d._origWS = nil end

							if _d._origJP then _hum.JumpPower = _d._origJP _d._origJP = nil end

						end

						pcall(function() _hrp:SetNetworkOwnershipAuto() end)

						_d._severeUntil = nil

						_d._severeFrozenPos = nil

						_d._severeFrozenRot = nil

					end

				end

			end

			acTimer = 0

			return

		end

		local elapsed = acTimer

		acTimer = 0

		for _, plr in pairs(Players:GetPlayers()) do

			local _safeMode = false

			pcall(function()

				if plr.Character then

					_safeMode = plr.Character:GetAttribute("AgoraSafeMode") == true

						or plr:GetAttribute("AgoraSafeMode") == true

				end

			end)

			if _safeMode then

				local _ch = plr.Character

				local _hrp2 = _ch and _ch:FindFirstChild("HumanoidRootPart")

				if _hrp2 and acPlayerData[plr.UserId] then

					acPlayerData[plr.UserId].lastPos = _hrp2.Position

					acPlayerData[plr.UserId].lastValidPos = _hrp2.Position

					acPlayerData[plr.UserId].lastSafePos = _hrp2.Position

					acPlayerData[plr.UserId].airTime = 0

					acPlayerData[plr.UserId].flyStrikes = 0

					acPlayerData[plr.UserId].noclipStrikes = 0

					acPlayerData[plr.UserId].speedStrikes = 0

					acPlayerData[plr.UserId].tpStrikes = 0

					acPlayerData[plr.UserId].jumpStrikes = 0

				end

				continue

			end

			local isStaffMember = false

			if isStaffMember then

				local char2 = plr.Character

				if char2 then

					local hrp2 = char2:FindFirstChild("HumanoidRootPart")

					if hrp2 and acPlayerData[plr.UserId] then

						acPlayerData[plr.UserId].lastPos = hrp2.Position

						acPlayerData[plr.UserId].lastValidPos = hrp2.Position

					end

				end

				-- Ne pas bloquer le staff, mais continuer le scan (whitelist gère les exemptions)

				-- continue  ← retiré : le staff est maintenant scanné

			end

			-- Si le joueur est whitelisté pour une action admin (fly, modcam, etc.)

			-- on skip TOUT le scan AC pour éviter les faux positifs

			local w = acWhitelist[plr.UserId]

			if w and (w.fly or w.speed or w.noclip) then

				-- Garder lastPos à jour pour quand la whitelist expire

				local char2 = plr.Character

				if char2 then

					local hrp2 = char2:FindFirstChild("HumanoidRootPart")

					if hrp2 and acPlayerData[plr.UserId] then

						acPlayerData[plr.UserId].lastPos = hrp2.Position

						acPlayerData[plr.UserId].lastValidPos = hrp2.Position

					end

				end

				continue

			end

			local char = plr.Character

			if not char then continue end

			local hrp = char:FindFirstChild("HumanoidRootPart")

			local hum = char:FindFirstChildOfClass("Humanoid")

			if not hrp or not hum or hum.Health <= 0 then continue end

			local uid = plr.UserId

			if not acPlayerData[uid] then

				acPlayerData[uid] = {

					lastPos = hrp.Position, lastValidPos = hrp.Position, lastSafePos = hrp.Position,

					speedStrikes = 0, flyStrikes = 0, noclipStrikes = 0, tpStrikes = 0,

					airTime = 0, lastJumpPower = hum.JumpPower, lastWalkSpeed = hum.WalkSpeed,

					lastMaxHealth = hum.MaxHealth,

				}

				continue

			end

			local data = acPlayerData[uid]

			local currentPos = hrp.Position

			local state = hum:GetState()

			local isFalling = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown)

			local isRagdoll = (state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics)

			local isSwimming = (state == Enum.HumanoidStateType.Swimming)

			local isSeated = (state == Enum.HumanoidStateType.Seated)

			local isClimbing = (state == Enum.HumanoidStateType.Climbing)

			local moveInput = (hum.MoveDirection or Vector3.zero).Magnitude

			-- ══ SEVERE BLOCK : refresh / release ══

			-- Blocage IN-PLACE (pas de TP loin, pas de LoadCharacter) pour preserver

			-- les teleporteurs natifs du jeu et autres mecaniques legitimes des clients.

			if data._severeUntil then

				if os.clock() >= data._severeUntil then

					-- Liberation complete: tout restaurer

					-- Restaurer Anchored sur tous les body parts (qu'on avait tous Anchore)

					if data._anchoredParts then

						for _bp, _origAnchored in pairs(data._anchoredParts) do

							if _bp and _bp.Parent then _bp.Anchored = _origAnchored end

						end

						data._anchoredParts = nil

					end

					hum.PlatformStand = false

					if data._origWS then hum.WalkSpeed = data._origWS data._origWS = nil end

					if data._origJP then hum.JumpPower = data._origJP data._origJP = nil end

					pcall(function() hrp:SetNetworkOwnershipAuto() end)

					data._severeUntil = nil

					local _frozenPos = data._severeFrozenPos

					data._severeFrozenPos = nil

					data._severeFrozenRot = nil

					data.speedStrikes = 0

					data.flyStrikes = 0

					data.noclipStrikes = 0

					data.tpStrikes = 0

					data.velStrikes = 0

					data.jumpStrikes = 0

					data.airTime = 0

					data.lastPos = _frozenPos or currentPos

					data.lastValidPos = _frozenPos or currentPos

					data.lastSafePos = _frozenPos or currentPos

				else

					-- Encore en blocage. La boucle Heartbeat dediee force CFrame chaque frame.

					-- Ici on update juste lastPos pour que la detection au prochain scan calcule

					-- les deltas par rapport a la position figee, pas une fausse pos client.

					data.lastPos = data._severeFrozenPos or currentPos

					continue

				end

			end

			-- Helper local : RETOUR a la position d'AVANT le cheat + freeze TOTAL.

			-- Anchor TOUS les body parts (pas que HRP) + PlatformStand + force CFrame chaque frame.

			-- Bloque le moindre mouvement, meme en spammant les touches.

			local function _acSevereBlock(durationSec)

				-- Position d'avant le cheat (lastSafePos = derniere pos sans aucun strike).

				data._severeFrozenPos = data.lastSafePos or data.lastValidPos or hrp.Position

				data._severeFrozenRot = hrp.CFrame - hrp.CFrame.Position

				-- IMPORTANT ordre: SetNetworkOwner(nil) AVANT Anchored=true sinon Roblox throw.

				pcall(function() hrp:SetNetworkOwner(nil) end)

				-- Anchor TOUS les body parts (Solara peut bouger les parts non-HRP)

				data._anchoredParts = data._anchoredParts or {}

				for _, _bp in ipairs(char:GetDescendants()) do

					if _bp:IsA("BasePart") then

						-- Memoriser l'etat original pour restore au release

						if data._anchoredParts[_bp] == nil then

							data._anchoredParts[_bp] = _bp.Anchored

						end

						_bp.Anchored = true

						_bp.AssemblyLinearVelocity = Vector3.zero

						_bp.AssemblyAngularVelocity = Vector3.zero

					end

					-- Detruire les BodyMovers de Solara/Delta (fly via BodyVelocity etc.)

					if _bp:IsA("BodyVelocity") or _bp:IsA("BodyForce") or _bp:IsA("BodyGyro")

						or _bp:IsA("BodyAngularVelocity") or _bp:IsA("BodyPosition") or _bp:IsA("BodyThrust")

						or _bp:IsA("AlignPosition") or _bp:IsA("AlignOrientation")

						or _bp:IsA("LinearVelocity") or _bp:IsA("AngularVelocity")

						or _bp:IsA("VectorForce") or _bp:IsA("Torque") then

						_bp:Destroy()

					end

				end

				-- Bloquer les inputs de mouvement (touches direction) du Humanoid

				data._origWS = data._origWS or hum.WalkSpeed

				data._origJP = data._origJP or hum.JumpPower

				hum.WalkSpeed = 0

				hum.JumpPower = 0

				hum.PlatformStand = true

				pcall(function() hum:Move(Vector3.zero, false) end)

				pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)

				-- Force la position TOUT DE SUITE

				hrp.CFrame = CFrame.new(data._severeFrozenPos) * data._severeFrozenRot

				data._severeUntil = math.max(data._severeUntil or 0, os.clock() + (durationSec or 2.5))

			end

			-- ══ SPEED CHECK (inclut freefall pour détecter fly+speed) ══

			-- IMPORTANT: les whitelists sont independantes. Skip total UNIQUEMENT si whitelist

			-- speed explicite. Pour fly whitelist, on TOLERE plus mais on continue de surveiller

			-- (un user avec ;fly + cheat speed serait sinon non-detecte).

			if not acIsWhitelisted(plr, "speed") and not isRagdoll and not isSeated and not isClimbing and moveInput > 0.05 and (data.airTime or 0) < 0.2 then

				local flatCur  = Vector3.new(currentPos.X, 0, currentPos.Z)

				local flatLast = Vector3.new(data.lastPos.X, 0, data.lastPos.Z)

				local dist = (flatCur - flatLast).Magnitude

				local maxAllowed = hum.WalkSpeed * elapsed * AC_SPEED_MARGIN

				-- En freefall normal, on tolère un peu plus (gravité + inertie)

				if isFalling then maxAllowed = maxAllowed * 1.5 end

				-- En fly admin legitime, on tolere 5x plus (vol rapide acceptable)

				-- mais on continue de detecter une vitesse anormale au-dela

				if acIsWhitelisted(plr, "fly") then maxAllowed = maxAllowed * 5 end

				if not isSwimming and dist > maxAllowed then

					-- [SCORE PROBABILISTE] On combine signaux. Ratio dist/maxAllowed:

					--   < 1.5 (sprint normal) -> +0  -> ignore

					--   1.5-2.5 (suspect)      -> +15 -> +1 strike

					--   2.5-5 (clair)          -> +25 -> +2 strikes

					--   > 5 (delirant)         -> +40 -> bloc

					local _ratio = dist / math.max(maxAllowed, 0.01)

					local _prob = _acProbCheat(plr, data, hrp, hum, "speed", { ratio = _ratio })

					if _prob >= 95 then

						data.speedStrikes = (data.speedStrikes or 0) + AC_STRIKES_BLOCK

						if not isStaffMember then _acSevereBlock(2.0) end

						acSendAlert(plr, "SPEED HACK",

							string.format("%.0f studs/%.1fs ratio=%.1fx score=%d%%", dist, elapsed, _ratio, _prob))

					elseif _prob >= 75 then

						data.speedStrikes = (data.speedStrikes or 0) + 2

						if not isStaffMember and data.speedStrikes >= AC_STRIKES_BLOCK then

							_acSevereBlock(2.0)

							acSendAlert(plr, "SPEED HACK",

								string.format("%.0f studs/%.1fs ratio=%.1fx strikes=%d score=%d%%", dist, elapsed, _ratio, data.speedStrikes, _prob))

						end

					elseif _prob >= 55 then

						data.speedStrikes = (data.speedStrikes or 0) + 1

						if not isStaffMember and data.speedStrikes >= AC_STRIKES_BLOCK then

							_acSevereBlock(2.0)

						end

					end

					-- < 55: ignore (sprint normal, lag, ou skill)

				else

					data.speedStrikes = math.max(0, (data.speedStrikes or 0) - AC_DECAY)

					if dist < maxAllowed then data.lastValidPos = currentPos end

				end

			else

				data.speedStrikes = 0

				data.lastValidPos = currentPos

			end

			-- ══ FLY CHECK ══

			-- [ANTI-FAUX-POSITIFS] Skip si:

			--   - seated/climbing/swimming

			--   - spawn recent (<8s) -> evite faux-positif quand 2 joueurs spawn empiles

			--     OU quand un script jeu client TP/lift/pose le perso au load.

			if not data._spawnTime then data._spawnTime = os.clock() end

			local _justSpawned = (os.clock() - data._spawnTime) < 8

			if not acIsWhitelisted(plr, "fly") and not isSeated and not isClimbing and not isSwimming and not _justSpawned then

				local rayParams = RaycastParams.new()

				rayParams.FilterType = Enum.RaycastFilterType.Exclude

				-- [FIX SAUT SUR TETE JOUEUR] On exclut SEULEMENT le character analyse, pas

				-- les autres joueurs. Avant: tous les chars exclus -> raycast traversait la

				-- tete d'un joueur sous toi et trouvait le sol loin -> faux fly hack.

				-- Maintenant le raycast s'arrete sur le char d'un autre joueur = grounded.

				local filter = {char}

				rayParams.FilterDescendantsInstances = filter

				local result = workspace:Raycast(hrp.Position, Vector3.new(0, -AC_FLY_RAYCAST, 0), rayParams)

				-- Aussi check sur les côtés (pentes)

				local resultL = workspace:Raycast(hrp.Position + Vector3.new(2,0,0), Vector3.new(0,-AC_FLY_RAYCAST,0), rayParams)

				local resultR = workspace:Raycast(hrp.Position + Vector3.new(-2,0,0), Vector3.new(0,-AC_FLY_RAYCAST,0), rayParams)

				-- [DETECTE FLY LENT] On considere "grounded" UNIQUEMENT si le sol est PROCHE

				-- (<= 5 studs sous le HRP) ET que l'humanoid est en etat sol-compatible.

				-- Avant: raycast hit dans 30 studs = grounded -> fly lent a 5+ studs passait.

				local _isGrounded = false

				local _closestGroundDist = math.huge

				for _, _ray in ipairs({result, resultL, resultR}) do

					if _ray then

						local _d = (hrp.Position - _ray.Position).Magnitude

						if _d < _closestGroundDist then _closestGroundDist = _d end

					end

				end

				-- [FIX SAUT SUR OBJETS / TETE JOUEUR] Threshold elargi (8→12) pour les

				-- sauts sur petits objets, obby, ou tete d'un autre joueur (~5 studs).

				-- La transition Jumping->Landed est rapide; avant on ratait des frames

				-- "between" sans state Landed → faux positif.

				local _groundedThreshold = math.max(12, (hum.HipHeight or 2) + hrp.Size.Y/2 + 6)

				if _closestGroundDist <= _groundedThreshold

					or state == Enum.HumanoidStateType.Running

					or state == Enum.HumanoidStateType.RunningNoPhysics

					or state == Enum.HumanoidStateType.Landed

					or state == Enum.HumanoidStateType.Seated

					or state == Enum.HumanoidStateType.Climbing then

					_isGrounded = true

				end

				if _isGrounded then

					data.airTime = 0

				else

					-- [DETECTION FLY AMELIOREE] On regarde le SIGNE de velY, pas que l'absolu.

					local velY = hrp.AssemblyLinearVelocity.Y

					local absVY = math.abs(velY)

					-- [FIX SAUT HAUT / OBBY] Si Roblox nous dit explicitement que c'est un

					-- saut legitime (Jumping) ou une chute libre (Freefall), on DECREMENT

					-- au lieu de pénaliser. Ces states sont positionnes par le moteur, pas

					-- par le client → un fly hack ne peut pas les forger sans casser autre.

					if state == Enum.HumanoidStateType.Jumping

						or state == Enum.HumanoidStateType.Freefall

						or state == Enum.HumanoidStateType.FallingDown then

						-- Saut/chute legitime: decrement (couvre apex de saut + chutes longues)

						-- [FIX SAUTS INFINIS] memorise le timestamp du dernier state legitime

						-- pour donner une grace dans les transitions Jumping->RunningNoPhysics->Jumping

						-- (sauts en chaine, jump pads, obby = pas de faux positif)

						data._lastJumpStateAt = os.clock()

						data.airTime = math.max(0, (data.airTime or 0) - elapsed * 0.5)

					elseif velY > 1 and state ~= Enum.HumanoidStateType.Jumping then

						-- Monte dans le vide SANS etre en saut legitime = fly quasi-certain

						-- Accumule TRES vite (1.5x temps reel -> trigger en ~0.5s)

						-- [FIX SAUTS INFINIS] grace 0.8s apres un Jumping/Freefall recent

						-- (apex de saut, transitions de state moteur) = decrement au lieu d'accumule

						if os.clock() - (data._lastJumpStateAt or 0) < 0.8 then

							data.airTime = math.max(0, (data.airTime or 0) - elapsed * 0.5)

						else

							data.airTime = (data.airTime or 0) + elapsed * 1.5

						end

					elseif absVY < 6 then

						-- Flottement (velY entre -6 et +1) sans state Jumping/Freefall = suspect

						-- [FIX SAUTS INFINIS] meme grace ici (apex = velY ~ 0)

						if os.clock() - (data._lastJumpStateAt or 0) < 0.8 then

							data.airTime = math.max(0, (data.airTime or 0) - elapsed * 0.3)

						else

							data.airTime = (data.airTime or 0) + elapsed

						end

					elseif velY > -10 then

						-- Chute lente (entre -10 et -6) sans state Freefall = on tombe pas vraiment

						data.airTime = (data.airTime or 0) + elapsed * 0.5

					else

						-- Vraie chute libre (velY <= -10) = on tombe, RESET airTime

						-- (la chute peut durer longtemps depuis une grande hauteur, pas de strike)

						data.airTime = math.max(0, (data.airTime or 0) - elapsed)

					end

				end

				if (data.airTime or 0) > AC_FLY_AIRTIME then

					data.flyStrikes = (data.flyStrikes or 0) + 1

					if data.flyStrikes >= AC_STRIKES_BLOCK then

						-- [BLOCAGE IN-PLACE] Plus de TP au sol. Freeze sur place 2.5s.

						if not isStaffMember then

							_acSevereBlock(2.5)

						end

						data.airTime = 0

					end

					if data.flyStrikes >= AC_STRIKES_ALERT then

						acSendAlert(plr, "FLY HACK",

							string.format("En l'air %.1fs, velocity Y: %.1f", data.airTime or 0, hrp.AssemblyLinearVelocity.Y))

						data.flyStrikes = AC_STRIKES_ALERT

					end

				else

					data.flyStrikes = math.max(0, (data.flyStrikes or 0) - 0.15)

				end

			else

				data.airTime = 0

				data.flyStrikes = 0

			end

			-- ══ NOCLIP CHECK (raycast + overlap — double detection) ══

			-- IMPORTANT: les whitelists sont independantes par type. Si l'user a ;fly,

			-- on whitelist UNIQUEMENT fly et speed. Le noclip CONTINUE d'etre surveille

			-- pour empecher le combo "commande fly admin + cheat noclip".

			-- Skip uniquement si whitelist explicite NOCLIP (commande ;noclip admin).

			-- Le raycast est skip en fly admin (faux positif quand le fly frole un mur),

			-- mais l'overlap reste actif (detecte si le HRP est DANS un mur epais).

			local _flyWhitelistedNC = acIsWhitelisted(plr, "fly")

			if not acIsWhitelisted(plr, "noclip") and not isRagdoll and not isSeated and not isClimbing and not isSwimming then

				local noclipDetected = false

				local _strongDetect = false  -- methode 1 raycast confirmee = vraie traversee, bloc immediat

				local _signalDepth = 0       -- profondeur d'enfoncement (studs), pour scoring

				local _signalMethod = nil    -- "raycast_traverse" ou "overlap"

				local hitName = "?"

				-- Filtre commun (exclure tous les characters)

				local ncFilter = {char}

				for _, p2 in pairs(Players:GetPlayers()) do

					if p2.Character then table.insert(ncFilter, p2.Character) end

				end

				-- METHODE 1 : Raycast (detecte le passage a travers un mur).

				-- ACTIF MEME EN FLY ADMIN: si le perso traverse vraiment un mur, c'est noclip

				-- meme avec ;fly. On ajoute un check "vraie traversee": le rayon doit hit un

				-- mur ET la position courante doit etre de l'AUTRE cote du mur (pas juste froler).

				if data.lastPos then

					local dir = currentPos - data.lastPos

					if dir.Magnitude > AC_NOCLIP_MIN then

						local rayParams = RaycastParams.new()

						rayParams.FilterType = Enum.RaycastFilterType.Exclude

						rayParams.FilterDescendantsInstances = ncFilter

						local offsets = {Vector3.new(0,0,0), Vector3.new(0,2,0), Vector3.new(0,-1.5,0)}

						for _, off in ipairs(offsets) do

							local result = workspace:Raycast(data.lastPos + off, dir, rayParams)

							if result and _isSolidWall(result.Instance, hrp) then

								-- [ANTI-FAUX-POSITIF ESCALIERS/BORDURES] Ignorer les parts dont

								-- le sommet est <= hauteur des hanches +0.5 (le perso peut marcher dessus)

								-- ou dont la hauteur (Size.Y) est < 4 (trop petit pour etre un mur).

								local _partTop = result.Instance.Position.Y + (result.Instance.Size.Y / 2)

								local _hrpBottom = hrp.Position.Y - hrp.Size.Y / 2

								local _isFloorOrStep = _partTop <= (_hrpBottom + 3.0) or result.Instance.Size.Y < 4

								if not _isFloorOrStep then

									-- [ANTI-FAUX-POSITIF FROLER] Verifier que c'est une VRAIE

									-- traversee : lastPos et currentPos doivent etre de cotes

									-- OPPOSES du plan de la part touchee. Et currentPos doit

									-- etre enfonce d'au moins 0.5 stud de l'autre cote.

									local _n = result.Normal

									local _hitPos = result.Position

									local _sideAfter = (currentPos - _hitPos):Dot(_n)

									local _sideBefore = (data.lastPos - _hitPos):Dot(_n)

									-- sideBefore > 0 = on etait du cote de la normale (exterieur).

									-- sideAfter < -0.5 = on est de l'autre cote, enfonce de plus de 0.5 stud.

									if _sideBefore > 0 and _sideAfter < -0.5 then

										noclipDetected = true

										_strongDetect = true  -- vraie traversee confirmee = bloc immediat

										_signalDepth = math.abs(_sideAfter)

										_signalMethod = "raycast_traverse"

										hitName = result.Instance.Name

										break

									end

								end

							end

						end

					end

				end

				-- METHODE 2 : Overlap (detecte si le joueur est DANS un mur)

				if not noclipDetected then

					local overlapParams = OverlapParams.new()

					overlapParams.FilterType = Enum.RaycastFilterType.Exclude

					overlapParams.FilterDescendantsInstances = ncFilter

					local _miniBox = Vector3.new(1.0, 1.0, 0.5)

					local ok, parts = pcall(function()

						return workspace:GetPartBoundsInBox(hrp.CFrame, _miniBox, overlapParams)

					end)

					if ok and parts then

						for _, part in pairs(parts) do

							if _isSolidWall(part, hrp) then

								-- [ANTI-FAUX-POSITIF ESCALIERS/BORDURES] Ignorer parts a hauteur de

								-- hanche ou plus bas (escaliers/bordures que le perso peut grimper).

								local _partTop = part.Position.Y + (part.Size.Y / 2)

								local _hrpBottom = hrp.Position.Y - hrp.Size.Y / 2

								local _isFloorOrStep = _partTop <= (_hrpBottom + 3.0) or part.Size.Y < 4

								if not _isFloorOrStep then

									noclipDetected = true

									_signalMethod = _signalMethod or "overlap"

									_signalDepth = math.max(_signalDepth, 0.7)  -- mini-box overlap = enfonce ~0.7 stud min

									hitName = part.Name

									break

								end

							end

						end

					end

				end

				if noclipDetected then

					-- [SCORE PROBABILISTE] Combine signaux (depth, methode, role, etat,

					-- strikes recents, fly admin, combo) -> score 0-100. Decision:

					--   >= 95 -> bloc IMMEDIAT (haute confiance)

					--   75-95 -> +2 strikes (faut 2 ticks pour bloc)

					--   55-75 -> +1 strike (faut 4-5 ticks)

					--   < 55  -> ignore (faux positif probable)

					-- [FIX BUG VIP-FLY-NOCLIP] Avant: appel oubliait l'arg "noclip" (5e param),

					-- passait {depth,method} comme cheatType. Score restait a ~40 (< 55 = ignore)

					-- => VIP avec ;fly pouvait traverser les murs librement. Maintenant l'appel

					-- est correct et le scoring noclip-specifique s'applique vraiment.

					local _prob = _acProbCheat(plr, data, hrp, hum, "noclip", {

						depth = _signalDepth,

						method = _signalMethod or "overlap",

					})

					-- [VIP FLY != NOCLIP] Si le joueur est en ;fly admin ET que c'est un raycast_traverse

					-- (vraie traversee, pas overlap minor), on RAJOUTE +25 au score pour compenser

					-- le -10 fly-whitelist du scoring de base. Le ;fly autorise voler pas traverser.

					if _strongDetect and _flyWhitelistedNC then

						_prob = math.min(100, _prob + 25)

					end

					if _prob >= 95 then

						-- Quasi certain: bloc immediat

						data.noclipStrikes = (data.noclipStrikes or 0) + AC_STRIKES_BLOCK

						if not isStaffMember then _acSevereBlock(2.5) end

					elseif _prob >= 75 then

						data.noclipStrikes = (data.noclipStrikes or 0) + 2

						if not isStaffMember and data.noclipStrikes >= AC_STRIKES_BLOCK then

							_acSevereBlock(2.5)

						end

					elseif _prob >= 55 then

						data.noclipStrikes = (data.noclipStrikes or 0) + 1

						if not isStaffMember and data.noclipStrikes >= AC_STRIKES_BLOCK then

							_acSevereBlock(2.5)

						end

					else

						-- < 55 = faux-positif probable, on ignore (mais ne reset pas non plus)

						-- Le decay s'occupera de baisser noclipStrikes naturellement.

					end

					if data.noclipStrikes >= AC_STRIKES_ALERT then

						acSendAlert(plr, "NOCLIP",

							string.format("Traverse '%s' — score=%d%% depth=%.1f via %s", hitName, _prob, _signalDepth, _signalMethod or "?"))

						data.noclipStrikes = AC_STRIKES_ALERT

					end

				else

					data.noclipStrikes = math.max(0, (data.noclipStrikes or 0) - AC_DECAY)

				end

			else

				data.noclipStrikes = 0

			end

			-- ══ TELEPORT CHECK ══

			local _hasBodyMover = false

			pcall(function()

				for _, c in ipairs(hrp:GetChildren()) do

					if c:IsA("BodyVelocity") or c:IsA("BodyPosition") or c:IsA("BodyGyro")

						or c:IsA("BodyAngularVelocity") or c:IsA("AlignPosition")

						or c:IsA("AlignOrientation") or c:IsA("LinearVelocity")

						or c:IsA("VectorForce") or c:IsA("AngularVelocity")

						or c:IsA("Torque") or c:IsA("RodConstraint")

						or c:IsA("RopeConstraint") or c:IsA("SpringConstraint") then

						local agora = false

						pcall(function() agora = c:GetAttribute("AgoraAdmin") == true end)

						if not agora then _hasBodyMover = true break end

					end

				end

			end)

			if not acIsWhitelisted(plr, "teleport") and not isRagdoll and not isSeated and not isClimbing and not isSwimming and not _justSpawned and not _hasBodyMover then

				-- [TELEPORT = teleportation HORIZONTALE seule] Le Y peut etre grand sans cheat

				-- (chute libre de haut, saut, gravite). On ne check que la distance XZ qui

				-- represente vraiment un mouvement teleporte (chute = mouvement vertical naturel).

				local _dxz = Vector3.new(currentPos.X - data.lastPos.X, 0, currentPos.Z - data.lastPos.Z)

				local dist = _dxz.Magnitude

				local _baseSpeed = math.max(hum.WalkSpeed, 16)

				local tpMax = math.max(_baseSpeed * elapsed * 8, 8)

				if acIsWhitelisted(plr, "fly") then tpMax = tpMax * 4 end

				-- En chute libre / freefall, tolerer encore plus (saut en avant + gravite)

				if isFalling then tpMax = tpMax * 2 end

				-- [PRESERVE PORTAILS NATIFS] TP > 50 studs = tres probable script serveur

				-- (portail, teleporter custom, lift). Auto-whitelist 1.5s, pas de strike.

				-- SAUF si l'utilisateur avait deja des strikes (sinon un exploit pourrait abuser).

				if dist > 50 and (data.tpStrikes or 0) == 0 and (data.flyStrikes or 0) == 0

					and (data.noclipStrikes or 0) == 0 and (data.velStrikes or 0) == 0 then

					acWhitelistFn(plr, "teleport", true)

					acWhitelistFn(plr, "speed", true)

					task.delay(1.5, function()

						acUnwhitelistFn(plr, "teleport")

						acUnwhitelistFn(plr, "speed")

					end)

					data.lastPos = currentPos

					data.lastValidPos = currentPos

					data.lastSafePos = currentPos

				elseif dist > tpMax then

					-- [SCORE PROBABILISTE] On combine signaux pour decider.

					local _prob = _acProbCheat(plr, data, hrp, hum, "teleport", {

						dist = dist, tpMax = tpMax,

					})

					if _prob >= 95 then

						-- Quasi certain TP hack: bloc immediat

						data.tpStrikes = (data.tpStrikes or 0) + AC_STRIKES_BLOCK

						if not isStaffMember then _acSevereBlock(3.0) end

						acSendAlert(plr, "TELEPORT HACK",

							string.format("%.0f studs (%.0fx) score=%d%%", dist, dist/tpMax, _prob))

					elseif _prob >= 75 then

						data.tpStrikes = (data.tpStrikes or 0) + 2

						if not isStaffMember and data.tpStrikes >= AC_STRIKES_BLOCK then

							_acSevereBlock(3.0)

							acSendAlert(plr, "TELEPORT HACK",

								string.format("%.0f studs strikes=%d score=%d%%", dist, data.tpStrikes, _prob))

						end

					elseif _prob >= 55 then

						data.tpStrikes = (data.tpStrikes or 0) + 1

						if not isStaffMember and data.tpStrikes >= AC_STRIKES_BLOCK then

							_acSevereBlock(3.0)

						end

					end

					-- < 55 = ignore (probablement portail / lift / lag)

				else

					data.tpStrikes = math.max(0, (data.tpStrikes or 0) - AC_DECAY)

				end

			else

				data.tpStrikes = 0

			end

			-- ══ JUMP POWER + INFINITE JUMP CHECK ══

			if not acIsWhitelisted(plr, "speed") and not acIsWhitelisted(plr, "fly") then

				-- JumpPower modifié

				if hum.JumpPower > 80 and data.lastJumpPower <= 80 then

					hum.JumpPower = 50

					acSendAlert(plr, "JUMP HACK", string.format("JumpPower: %.0f (reset a 50)", hum.JumpPower))

				end

				-- WalkSpeed anormalement élevé

				if hum.WalkSpeed > 50 then

					local allowed = data.lastWalkSpeed or 16

					if hum.WalkSpeed > allowed * 2 and allowed <= 50 then

						hum.WalkSpeed = allowed

						acSendAlert(plr, "SPEED MODIF", string.format("WalkSpeed: %.0f (reset a %.0f)", hum.WalkSpeed, allowed))

					end

				end

				-- [INFINITE JUMP V2] Detection PAR TRANSITION STATE: si Jumping survient

				-- alors que l'etat precedent etait NON-grounded (Freefall/Jumping/FallingDown)

				-- = saut sans avoir touche le sol = infinite jump quasi-certain.

				-- Marche meme si le hack utilise des velY faibles (~20).

				if state == Enum.HumanoidStateType.Jumping

					and data.lastAcState ~= Enum.HumanoidStateType.Jumping

					and data.lastAcState ~= Enum.HumanoidStateType.Landed

					and data.lastAcState ~= Enum.HumanoidStateType.Running

					and data.lastAcState ~= Enum.HumanoidStateType.RunningNoPhysics

					and data.lastAcState ~= Enum.HumanoidStateType.Climbing

					and data.lastAcState ~= Enum.HumanoidStateType.Seated

					and data.lastAcState ~= nil

					and not isStaffMember

					and not acIsWhitelisted(plr, "fly") then

					data.jumpStrikes = (data.jumpStrikes or 0) + 2  -- gros strike (transition tres suspect)

					if data.jumpStrikes >= 3 then

						hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)

						acSendAlert(plr, "INFINITE JUMP", "Saut consecutif sans landing (state: "..tostring(data.lastAcState)..")")

						data.jumpStrikes = 4

					end

				end

				-- Reset jumpStrikes quand on touche vraiment le sol

				if state == Enum.HumanoidStateType.Landed

					or state == Enum.HumanoidStateType.Running

					or state == Enum.HumanoidStateType.RunningNoPhysics then

					data.jumpStrikes = math.max(0, (data.jumpStrikes or 0) - 0.5)

				end

				-- Track le state precedent pour la prochaine iteration

				data.lastAcState = state

				-- Saut infini (legacy): détecter jump pendant freefall

				if isFalling then

					local velY = hrp.AssemblyLinearVelocity.Y

					-- Si le joueur monte PENDANT qu'il est en freefall = saut infini

					-- [FIX FAUX POSITIF] Seuils plus stricts pour eviter de bloquer les sauts normaux

					-- velY > 35 (au lieu 20) ET airTime > 1.0 (au lieu 0.5) ET 2 strikes (au lieu 1)

					if velY > 35 and (data.airTime or 0) > 1.0 then

						data.jumpStrikes = (data.jumpStrikes or 0) + 1

						if data.jumpStrikes >= 2 then

							-- [SIMPLE COMME FLY] juste velocity Y = 0 (chute naturelle par gravité)

							hrp.AssemblyLinearVelocity = Vector3.new(

								hrp.AssemblyLinearVelocity.X, 0,

								hrp.AssemblyLinearVelocity.Z)

							acSendAlert(plr, "INFINITE JUMP",

								string.format("Jump en l'air (Y vel: %.0f, airTime: %.1fs)", velY, data.airTime or 0))

							data.jumpStrikes = 3

						end

					else

						data.jumpStrikes = math.max(0, (data.jumpStrikes or 0) - 0.1)

					end

				else

					data.jumpStrikes = 0

				end

			else

				data.jumpStrikes = 0

			end

			data.lastJumpPower = hum.JumpPower

			data.lastWalkSpeed = hum.WalkSpeed

			-- ══ HEALTH CHECK ══

			if not acIsWhitelisted(plr, "god") and not plr:GetAttribute("GodMode") then

				if hum.MaxHealth > 200 and data.lastMaxHealth <= 200 then

					hum.MaxHealth = 100

					hum.Health = 100

					acSendAlert(plr, "HEALTH HACK", string.format("MaxHealth: %.0f (reset à 100)", data.lastMaxHealth))

				end

			end

			data.lastMaxHealth = hum.MaxHealth

			-- ══ SCALE CHECK ══

			-- [FIX SIZE] Skip si la commande size a été appliquée par un admin

			if not plr:GetAttribute("_AdminScaled") then

				local headScale = hum:FindFirstChild("HeadScale")

				local bodyHeight = hum:FindFirstChild("BodyHeightScale")

				if headScale and headScale.Value > 3 and not acIsWhitelisted(plr, "speed") then

					headScale.Value = 1

					acSendAlert(plr, "SCALE HACK", "HeadScale trop grand")

				end

				if bodyHeight and bodyHeight.Value > 3 and not acIsWhitelisted(plr, "speed") then

					bodyHeight.Value = 1

					acSendAlert(plr, "SCALE HACK", "BodyHeight trop grand")

				end

			end

			-- ══ VELOCITY CHECK (détecte les fly scripts qui utilisent BodyVelocity) ══

			-- [ANTI-FAUX-POSITIFS] Skip si seated/climbing/ragdoll (vehicule pousse, echelle, ragdoll fling)

			if not acIsWhitelisted(plr, "fly") and not acIsWhitelisted(plr, "speed") then

				local vel = hrp.AssemblyLinearVelocity

				local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

				-- [SEUIL DYNAMIQUE] Pas de plancher fixe. Detection sur anomalie pure.

				local maxVel = hum.WalkSpeed * 2

				-- Velocity horizontale impossible sans fly/fling

				if horizSpeed > maxVel and not isRagdoll and not isSeated and not isClimbing then

					data.velStrikes = (data.velStrikes or 0) + 1

					if data.velStrikes >= AC_STRIKES_BLOCK then

						-- [BLOCAGE IN-PLACE] Plus de TP au lastSafePos. Freeze sur place 2s.

						if not isStaffMember then _acSevereBlock(2.0) end

					end

					if data.velStrikes >= AC_STRIKES_ALERT then

						acSendAlert(plr, "VELOCITY HACK",

							string.format("Vitesse: %.0f studs/s (max: %.0f)", horizSpeed, maxVel))

						data.velStrikes = AC_STRIKES_ALERT

					end

				else

					data.velStrikes = math.max(0, (data.velStrikes or 0) - AC_DECAY)

				end

			else

				data.velStrikes = 0

			end

			-- ══ PHYSICS OBJECTS CHECK — toujours actif même whitelist ══

			for _, obj in pairs(char:GetDescendants()) do

				if (obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or obj:IsA("BodyPosition")

					or obj:IsA("LinearVelocity") or obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")

					or obj:IsA("VectorForce") or obj:IsA("LineForce"))

					and not obj:GetAttribute("AgoraAdmin") then

					obj:Destroy()

					acSendAlert(plr, "FLY INJECT",

						string.format("'%s' supprimé de '%s'", obj.ClassName, obj.Parent and obj.Parent.Name or "?"))

				end

			end

			-- ══ HUMANOID STATE CHECK (toujours actif) ══

			if hrp.Anchored and not acIsWhitelisted(plr, "noclip") and not data._severeUntil then

				hrp.Anchored = false

				acSendAlert(plr, "ANCHOR HACK", "HumanoidRootPart était ancré")

			end

			-- ══ PHYSICS HACK CHECK (Delta / Synapse / Krnl / etc.) ══

			-- Ces hacks bypass la velocity/noclip detection en modifiant les proprietes physiques

			-- des body parts. On reset systematiquement ce qui est anormal.

			-- IMPORTANT: skip pendant _severeUntil (le bloc peut Anchorer HRP exprès).

			if not data._severeUntil and not acIsWhitelisted(plr, "noclip") and not acIsWhitelisted(plr, "fly") then

				local _physHack = nil

				for _, _bp in ipairs(char:GetDescendants()) do

					if _bp:IsA("BasePart") and _bp ~= hrp then

						-- 1. Anchor hack sur autres body parts (Delta technique)

						if _bp.Anchored then

							_bp.Anchored = false

							_physHack = _physHack or ("Anchor sur " .. _bp.Name)

						end

						-- 2. Massless hack (active = body part flotte / pas de gravite)

						if _bp.Massless then

							_bp.Massless = false

							_physHack = _physHack or ("Massless sur " .. _bp.Name)

						end

						-- 3. CustomPhysicalProperties anormale (Density < 0.05 = quasi flotte)

						if _bp.CustomPhysicalProperties then

							local cpp = _bp.CustomPhysicalProperties

							if cpp.Density < 0.05 or cpp.Density > 200 then

								_bp.CustomPhysicalProperties = nil  -- restore default

								_physHack = _physHack or ("Density anormale sur " .. _bp.Name)

							end

						end

					end

				end

				-- 4. Humanoid HipHeight anormale (defaut R15: 2, R6: 0). >5 = exploit fly-like

				if hum.HipHeight and (hum.HipHeight > 5 or hum.HipHeight < -1) then

					hum.HipHeight = (hum.RigType == Enum.HumanoidRigType.R15) and 2.0 or 0.0

					_physHack = _physHack or ("HipHeight: " .. tostring(hum.HipHeight))

				end

				if _physHack then

					acSendAlert(plr, "PHYSICS HACK", _physHack .. " — reset")

				end

			end

			-- ══ TOOL REACH HACK CHECK (Delta technique pour augmenter la portee des tools) ══

			-- Detecte les Tool dont le Grip a ete deplace anormalement loin (reach hack typique).

			if not acIsWhitelisted(plr, "noclip") then

				for _, _tool in ipairs(char:GetChildren()) do

					if _tool:IsA("Tool") then

						-- Grip modifie : si la position du grip est > 8 studs du HRP origin, suspect

						local gpos = _tool.Grip.Position

						if gpos.Magnitude > 8 then

							_tool.Grip = CFrame.new()  -- reset au default (CFrame.new())

							acSendAlert(plr, "REACH HACK", "Tool '" .. _tool.Name .. "' Grip anormal — reset")

						end

					end

				end

			end

			-- ══ COLLISION CHECK (noclip exploit = body parts critiques en CanCollide false) ══

			-- [FIX FAUX POSITIF] Ne check QUE les body parts critiques R6/R15 + skip pendant

			-- les etats transitoires (Jumping/Freefall/FallingDown) ou Roblox set CanCollide=false

			-- temporairement, et requiert PERSISTANCE de 1.5s avant de strike.

			if not acIsWhitelisted(plr, "noclip") and not acIsWhitelisted(plr, "fly")

				and not isFalling

				and state ~= Enum.HumanoidStateType.Jumping

				and state ~= Enum.HumanoidStateType.Landed

				and state ~= Enum.HumanoidStateType.Ragdoll

				and state ~= Enum.HumanoidStateType.Physics then

				local CRITICAL_PARTS = {

					-- R6

					Torso=true, ["Left Arm"]=true, ["Right Arm"]=true,

					["Left Leg"]=true, ["Right Leg"]=true,

					-- R15

					UpperTorso=true, LowerTorso=true,

					LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,

					RightUpperArm=true, RightLowerArm=true, RightHand=true,

					LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,

					RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,

				}

				local noCollideCount = 0

				local criticalParts = {}

				for _, part in pairs(char:GetChildren()) do

					if part:IsA("BasePart") and CRITICAL_PARTS[part.Name] then

						table.insert(criticalParts, part)

						if not part.CanCollide then noCollideCount = noCollideCount + 1 end

					end

				end

				-- Persistance : on detecte la condition "TOUTES CanCollide=false" mais on

				-- ne strike qu'apres 1.5s consecutif (= 25 ticks a 60ms). Roblox lui-meme

				-- toggle CanCollide pendant les transitions, ne pas faux-positiver.

				if #criticalParts >= 4 and noCollideCount == #criticalParts then

					data._collideAccum = (data._collideAccum or 0) + elapsed

					if data._collideAccum >= 1.5 then

						-- Vraie injection persistante. Force CanCollide=true et alerte.

						for _, part in ipairs(criticalParts) do

							part.CanCollide = true

						end

						acSendAlert(plr, "NOCLIP INJECT",

							string.format("Body parts CanCollide=false depuis %.1fs (forcé true)", data._collideAccum))

						data._collideAccum = 0

					end

				else

					-- Au moins une part collide -> reset compteur (pas d'injection)

					data._collideAccum = 0

				end

			else

				-- Skip pendant les etats transitoires : reset le compteur sinon ca s'accumule

				if data then data._collideAccum = 0 end

			end

			-- [AC HARDER] Mettre à jour lastSafePos UNIQUEMENT quand tout est safe ET au sol

			local _allClean = (data.speedStrikes or 0) == 0

				and (data.flyStrikes or 0) == 0

				and (data.noclipStrikes or 0) == 0

				and (data.tpStrikes or 0) == 0

				and (data.velStrikes or 0) == 0

				and (data.jumpStrikes or 0) == 0

				and (data.airTime or 0) < 0.3

			if _allClean then

				data.lastSafePos = currentPos

			end

			-- [BLOCAGE PROLONGE] Persistance multi-hack -> freeze in-place 8s (plus de LoadCharacter).

			-- LoadCharacter respawnait le joueur ce qui peut casser des mecaniques de jeu (inventaire,

			-- quetes, position de checkpoint, etc.). Maintenant on bloque sur place 8s.

			local totalStrikes = (data.speedStrikes or 0)

				+ (data.flyStrikes or 0)

				+ (data.noclipStrikes or 0)

				+ (data.tpStrikes or 0)

				+ (data.velStrikes or 0)

				+ (data.jumpStrikes or 0)

			if totalStrikes >= 6 and not isStaffMember then

				if not data.lastHardReset or (os.clock() - data.lastHardReset) > 15 then

					data.lastHardReset = os.clock()

					acSendAlert(plr, "MULTI HACK", "Persistance multi-hack — bloque 8s sur place")

					_acSevereBlock(8.0)

					-- Note: les strikes seront reset automatiquement quand _severeUntil expire

					-- (dans le bloc SEVERE BLOCK release au debut du tick suivant).

				end

			end

			-- Sauvegarder position

			data.lastPos = currentPos

		end

	end)

	-- ════════════════════════════════════════════════════════════════════════

	-- SEVERE BLOCK — REFRESH CHAQUE FRAME (Anchored + PlatformStand + force CFrame)

	-- ════════════════════════════════════════════════════════════════════════

	-- Tourne a CHAQUE Heartbeat (pas seulement toutes les 60ms du scan AC).

	-- Garantit que le joueur en _severeUntil ne fait AUCUNE distance, meme en

	-- spammant les touches direction:

	--   1. SetNetworkOwner(nil) - le client ne controle plus la physique

	--   2. Anchored=true - aucune physics step ne s'applique au HRP

	--   3. PlatformStand=true - bloque tous les inputs de mouvement Humanoid

	--   4. WalkSpeed=0 + JumpPower=0 - bloque toute commande Move

	--   5. Move(zero, false) - annule toute commande Move en cours

	--   6. CFrame force - meme si tout est bypass, on reset la position

	--   7. velocity = 0 - reset au cas ou

	RunService.Heartbeat:Connect(function()

		-- [FIX TOGGLE = STOP BLOCAGE] Si AC desactive globalement, ne pas refresh les freeze.

		-- Le scan AC libere deja les anchored/PlatformStand au moment du toggle off.

		if acGloballyDisabled then return end

		local now = os.clock()

		for _, plr in pairs(Players:GetPlayers()) do

			local data = acPlayerData[plr.UserId]

			if not data or not data._severeUntil then continue end

			if now >= data._severeUntil then continue end

			local char = plr.Character

			if not char then continue end

			local hrp = char:FindFirstChild("HumanoidRootPart")

			local hum = char:FindFirstChildOfClass("Humanoid")

			if not hrp or not data._severeFrozenPos then continue end

			-- Re-claim network ownership (anti-Solara qui tente de la reprendre)

			pcall(function() hrp:SetNetworkOwner(nil) end)

			-- Re-Anchorer TOUS les body parts (le client peut tenter de set Anchored=false)

			for _, _bp in ipairs(char:GetDescendants()) do

				if _bp:IsA("BasePart") and not _bp.Anchored then

					_bp.Anchored = true

				end

				-- Re-detruire les BodyMovers que Solara aurait re-poses

				if _bp:IsA("BodyVelocity") or _bp:IsA("BodyForce") or _bp:IsA("BodyGyro")

					or _bp:IsA("BodyAngularVelocity") or _bp:IsA("BodyPosition") or _bp:IsA("BodyThrust")

					or _bp:IsA("AlignPosition") or _bp:IsA("AlignOrientation")

					or _bp:IsA("LinearVelocity") or _bp:IsA("AngularVelocity")

					or _bp:IsA("VectorForce") or _bp:IsA("Torque") then

					_bp:Destroy()

				end

			end

			-- Bloquer les inputs de mouvement (touches direction)

			if hum then

				if hum.WalkSpeed ~= 0 then hum.WalkSpeed = 0 end

				if hum.JumpPower ~= 0 then hum.JumpPower = 0 end

				if not hum.PlatformStand then hum.PlatformStand = true end

				pcall(function() hum:Move(Vector3.zero, false) end)

			end

			-- Force la position d'avant le cheat

			hrp.CFrame = CFrame.new(data._severeFrozenPos) * (data._severeFrozenRot or CFrame.new())

			hrp.AssemblyLinearVelocity = Vector3.zero

			hrp.AssemblyAngularVelocity = Vector3.zero

		end

	end)

	-- Cleanup quand un joueur part

	Players.PlayerRemoving:Connect(function(p)

		acPlayerData[p.UserId] = nil

		acWhitelist[p.UserId] = nil

		acAlertCooldown[p.UserId] = nil

	end)

	-- ════════════════════════════════════════════════════════════════════════

	-- [DESACTIVE - cause du conflit avec la boucle PRINCIPALE noclip 60ms]

	-- La boucle principale (lignes ~6780) fait deja le check + Anchor + paralyze.

	-- Garder UNE seule boucle = pas de conflit. Le code mort ci-dessous est

	-- conserve pour reference (jamais execute grace au if false).

	-- ════════════════════════════════════════════════════════════════════════

	if false then

	-- ════════════════════════════════════════════════════════════════════════

	-- [DEAD CODE] ancienne boucle Heartbeat qui dupliquait le check :

	-- juste CFrame.new(backTo) + velocity = 0. PAS d'Anchor, PAS de SetNetworkOwner,

	-- PAS de paralyze. Le fly marche avec ça, le noclip marchera pareil.

	-- ════════════════════════════════════════════════════════════════════════

	local acNoclipPersist = {} -- [uid] = nb de frames consécutives dans un mur

	local acNoclipLastReset = {} -- [uid] = os.clock()

	local acLastClearPos = {} -- [uid] = derniere pos hors mur

	RunService.Heartbeat:Connect(function()

		for _, plr in pairs(Players:GetPlayers()) do

			if acIsStaff(plr) then continue end

			if acIsWhitelisted(plr, "noclip") then continue end

			local char = plr.Character

			if not char then continue end

			local hrp = char:FindFirstChild("HumanoidRootPart")

			local hum = char:FindFirstChildOfClass("Humanoid")

			if not hrp or not hum or hum.Health <= 0 then continue end

			local state = hum:GetState()

			if state == Enum.HumanoidStateType.Seated then continue end

			if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then continue end

			-- Skip si en saut/chute (états transitoires, faux positifs possibles)

			if state == Enum.HumanoidStateType.Climbing then continue end

			local uid = plr.UserId

			-- Filtre commun

			local ncFilter = {char}

			for _, p2 in pairs(Players:GetPlayers()) do

				if p2.Character then table.insert(ncFilter, p2.Character) end

			end

			local overlapParams = OverlapParams.new()

			overlapParams.FilterType = Enum.RaycastFilterType.Exclude

			overlapParams.FilterDescendantsInstances = ncFilter

			local insideWall = false

			local hitName = "?"

			-- [METHODE 1 RAYCAST DIRECTIONNEL] (méthode fly-like, plus fiable contre Solara)

			-- Raycast depuis acLastClearPos vers position actuelle. Si ça hit un mur, noclip.

			local prevPos = acLastClearPos[uid] or hrp.Position

			local moveVec = hrp.Position - prevPos

			if moveVec.Magnitude > 0.5 then

				local rayParams2 = RaycastParams.new()

				rayParams2.FilterType = Enum.RaycastFilterType.Exclude

				rayParams2.FilterDescendantsInstances = ncFilter

				-- Raycast à 3 hauteurs : centre HRP, haut, bas (couvre marches/sauts)

				local offsets = {Vector3.new(0,0,0), Vector3.new(0,1.5,0), Vector3.new(0,-1.5,0)}

				for _, off in ipairs(offsets) do

					local r = workspace:Raycast(prevPos + off, moveVec, rayParams2)

					if r and r.Instance.CanCollide and r.Instance.Transparency < 0.9

						and r.Instance.Size.Magnitude > 2 then

						-- Vérifier que c'est un VRAI mur (pas une marche d'escalier)

						local partTop = r.Instance.Position.Y + (r.Instance.Size.Y / 2)

						local hrpBottom = hrp.Position.Y - 2

						local isFloorOrStep = partTop <= (hrpBottom + 1.5)

						if not isFloorOrStep then

							insideWall = true

							hitName = r.Instance.Name

							break

						end

					end

				end

			end

			-- [METHODE 2 OVERLAP] (en plus du raycast, pour catch HRP DANS le mur)

			if not insideWall then

				local ok, parts = pcall(function() return workspace:GetPartsInPart(hrp, overlapParams) end)

				if ok and parts then

					for _, part in pairs(parts) do

						if _isSolidWall(part, hrp) then

							local partTop = part.Position.Y + (part.Size.Y / 2)

							local hrpBottom = hrp.Position.Y - 2

							local isFloorOrStep = partTop <= (hrpBottom + 1.5)

							if not isFloorOrStep then

								insideWall = true

								hitName = part.Name

								break

							end

						end

					end

				end

			end

			if insideWall then

				acNoclipPersist[uid] = (acNoclipPersist[uid] or 0) + 1

				local data = acPlayerData[uid]

				-- [BLOC + WARN seulement, PAS de kill] Chaque frame dans le mur :

				-- 1. Anchor PERSISTANT (pas de timer désanchor — désancher quand sort du mur)

				-- 2. TP au sol via raycast vertical

				-- 3. Velocity = 0 + paralyze WS/JP

				-- 4. Détruire les BodyMovers de Solara (BodyVelocity/AlignPosition/etc)

				hrp.Anchored = true

				local rayDown = RaycastParams.new()

				rayDown.FilterType = Enum.RaycastFilterType.Exclude

				rayDown.FilterDescendantsInstances = ncFilter

				local searchFrom = acLastClearPos[uid] or (data and (data.lastSafePos or data.lastValidPos)) or hrp.Position

				local groundRay = workspace:Raycast(searchFrom + Vector3.new(0, 50, 0), Vector3.new(0, -500, 0), rayDown)

				local backTo = groundRay and (groundRay.Position + Vector3.new(0, 4, 0)) or searchFrom

				hrp.CFrame = CFrame.new(backTo)

				hrp.AssemblyLinearVelocity = Vector3.zero

				hrp.AssemblyAngularVelocity = Vector3.zero

				-- Paralyser humanoid + sauvegarder valeurs originales

				if data then

					data._origWS = data._origWS or 16

					data._origJP = data._origJP or 50

				end

				hum.WalkSpeed = 0

				hum.JumpPower = 0

				hum.JumpHeight = 0

				-- Détruire les BodyMovers injectés par Solara (qui peuvent forcer mouvement)

				for _, obj in pairs(char:GetDescendants()) do

					if (obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") or obj:IsA("BodyPosition")

						or obj:IsA("LinearVelocity") or obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")

						or obj:IsA("VectorForce") or obj:IsA("LineForce"))

						and not obj:GetAttribute("AgoraAdmin") then

						obj:Destroy()

					end

				end

				-- Warn au 3e strike (~50ms), pas spam (cooldown 5s)

				if acNoclipPersist[uid] == 3 then

					local now = os.clock()

					if not acNoclipLastReset[uid] or (now - acNoclipLastReset[uid]) > 5 then

						acNoclipLastReset[uid] = now

						acSendAlert(plr, "NOCLIP",

							string.format("Bloque dans '%s' (Anchor + paralyze)", hitName))

					end

				end

			else

				-- Pas dans un mur → libérer + mettre à jour lastClearPos

				if hrp.Anchored then

					hrp.Anchored = false

				end

				-- Restaurer WalkSpeed/JumpPower si paralyse précédemment

				local data = acPlayerData[uid]

				if data and data._origWS then

					hum.WalkSpeed = data._origWS

					hum.JumpPower = data._origJP or 50

					hum.JumpHeight = 7.2

					data._origWS = nil

					data._origJP = nil

				end

				acLastClearPos[uid] = hrp.Position

				-- Décrémenter

				if acNoclipPersist[uid] then

					acNoclipPersist[uid] = math.max(0, acNoclipPersist[uid] - 1)

					if acNoclipPersist[uid] == 0 then acNoclipPersist[uid] = nil end

				end

			end

		end

	end)

	-- Cleanup acNoclipPersist quand joueur part

	Players.PlayerRemoving:Connect(function(p)

		acNoclipPersist[p.UserId] = nil

		acNoclipLastReset[p.UserId] = nil

		acLastClearPos[p.UserId] = nil

	end)

	end -- fin if false (boucle Heartbeat noclip dupliquee desactivee)

	-- Reset au respawn + [FIX STABILITÉ] Whitelist 3s après respawn pour éviter faux positifs

	local acRespawnConnections = {}

	local function acResetOnSpawn(plr)

		-- Évite les doubles connexions si la fonction est appelée plusieurs fois pour le même joueur

		if acRespawnConnections[plr.UserId] then return end

		local conn = plr.CharacterAdded:Connect(function(char)

			local uid = plr.UserId

			if acPlayerData[uid] then

				acPlayerData[uid].lastPos = nil

				acPlayerData[uid].lastValidPos = nil

				acPlayerData[uid].airTime = 0

				acPlayerData[uid]._spawnTime = os.clock()

				acPlayerData[uid].speedStrikes = 0

				acPlayerData[uid].flyStrikes = 0

				acPlayerData[uid].noclipStrikes = 0

				acPlayerData[uid].tpStrikes = 0

				acPlayerData[uid].velStrikes = 0

			end

			-- [FIX TP RETOUR] Initialiser lastClearPos à la position de spawn pour qu'au 1er noclip

			-- on tp le joueur à un endroit valide (pas hrp.Position = pos actuelle dans le mur)

			task.spawn(function()

				local spawnHrp = char:WaitForChild("HumanoidRootPart", 5)

				if spawnHrp then

					acLastClearPos[uid] = spawnHrp.Position

					if acPlayerData[uid] then

						acPlayerData[uid].lastSafePos = spawnHrp.Position

						acPlayerData[uid].lastValidPos = spawnHrp.Position

					end

				end

			end)

			-- [FIX ANTI-CHEAT] Whitelist temporaire 3s après respawn (évite fausses détections

			-- TP/speed). PRESERVE les whitelists PERMANENTES (ex: ;fly admin actif): on ne

			-- reset que les types qu'on a ajoute pendant ce respawn, pas ceux qui etaient deja la.

			acWhitelist[uid] = acWhitelist[uid] or {}

			-- [FIX SEAT] Whitelist teleport+noclip 2s a chaque fois que le joueur s'assoit
			task.spawn(function()
				local _hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
				if not _hum then return end
				_hum.Seated:Connect(function(active)
					if not active then return end
					local _seatAdded = {}
					acWhitelist[uid] = acWhitelist[uid] or {}
					for _, _t in ipairs({"teleport", "noclip"}) do
						if not acWhitelist[uid][_t] then
							_seatAdded[_t] = true
							acWhitelist[uid][_t] = true
						end
					end
					task.delay(2, function()
						if acWhitelist[uid] then
							for _t in pairs(_seatAdded) do
								acWhitelist[uid][_t] = nil
							end
						end
					end)
				end)
			end)

			-- Memoriser l'etat AVANT pour ne pas ecraser les whitelists permanentes

			local _addedBySpawn = {}

			for _, _t in ipairs({"speed", "fly", "noclip"}) do

				if not acWhitelist[uid][_t] then

					_addedBySpawn[_t] = true

					acWhitelist[uid][_t] = true

				end

			end

			task.delay(3, function()

				if acWhitelist[uid] then

					-- Reset UNIQUEMENT les types qu'on a ajoute (preserve les permanentes)

					for _t, _ in pairs(_addedBySpawn) do

						acWhitelist[uid][_t] = nil

					end

				end

			end)

		end)

		acRespawnConnections[plr.UserId] = conn

	end

	-- Cleanup quand le joueur part

	Players.PlayerRemoving:Connect(function(plr)

		local conn = acRespawnConnections[plr.UserId]

		if conn then

			conn:Disconnect()

			acRespawnConnections[plr.UserId] = nil

		end

	end)

	Players.PlayerAdded:Connect(acResetOnSpawn)

	for _, p in pairs(Players:GetPlayers()) do acResetOnSpawn(p) end

	print("[Agora Admin] Anti-Cheat intégré et actif.")

	-- ------------------------------------------------

	-- TICKETS — Système serveur

	-- ------------------------------------------------

	local activeTickets = {}

	local ticketId = 0

	ticketSubmitEvent.OnServerEvent:Connect(function(plr, data)

		if type(data) ~= "table" then return end

		if not data.Description or #data.Description < 5 then return end

		if #data.Description > 500 then data.Description = string.sub(data.Description, 1, 500) end

		ticketId = ticketId + 1

		local ticket = {

			Id         = ticketId,

			ReporterId = plr.UserId,

			Reporter   = plr.Name,

			TargetName = data.Target or "",

			Category   = data.Category or "Autre",

			Description= data.Description,

			Time       = os.date("%H:%M:%S"),

			Claimed    = false,

			ClaimedBy  = nil,

		}

		table.insert(activeTickets, 1, ticket) -- plus récent en premier

		if #activeTickets > 50 then table.remove(activeTickets) end

		-- Notifier le reporter

		notifEvent:FireClient(plr, "Ticket #"..ticketId.." envoyé aux modérateurs.")

		-- Notifier tous les modérateurs+ avec alerte visuelle

		for _, staff in pairs(Players:GetPlayers()) do

			local lvl = rolesHierarchy[_G.Agora_getPlayerRole(staff)] or 99

			if lvl <= 4 then

				ticketAlertEvent:FireClient(staff, {

					Reporter = plr.Name,

					Category = data.Category,

					Target = data.Target or "",

					Description = string.sub(data.Description, 1, 80),

				})

			end

		end

	end)

	ticketListFunc.OnServerInvoke = function(plr)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return {} end -- Modérateur+ seulement

		local list = {}

		for _, t in ipairs(activeTickets) do

			if not t.Claimed then

				table.insert(list, t)

			end

		end

		return list

	end

	ticketClaimEvent.OnServerEvent:Connect(function(plr, tId)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return end

		for _, t in ipairs(activeTickets) do

			if t.Id == tId and not t.Claimed then

				t.Claimed = true

				t.ClaimedBy = plr.Name

				notifEvent:FireClient(plr, "Ticket #"..tId.." pris en charge.")

				-- Notifier le reporter

				local reporter = Players:GetPlayerByUserId(t.ReporterId)

				if reporter then

					notifEvent:FireClient(reporter, "Un modérateur traite votre ticket #"..tId..".")

				end

				break

			end

		end

	end)

	-- ------------------------------------------------

	-- MOD CAM — Invisible + whitelist serveur

	-- ------------------------------------------------

	modCamEvent.OnServerEvent:Connect(function(plr, action, camPosition)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return end

		local char = plr.Character

		if not char then return end

		local hrp = char:FindFirstChild("HumanoidRootPart")

		local hum = char:FindFirstChildOfClass("Humanoid")

		if not hrp then return end

		if action == "Enter" then

			-- Whitelist anti-cheat COMPLÈTE

			acWhitelistFn(plr, "fly", true)

			acWhitelistFn(plr, "noclip", true)

			acWhitelistFn(plr, "speed", true)

			acWhitelistFn(plr, "teleport", true)

			-- Reset AC data

			local uid = plr.UserId

			if acPlayerData[uid] then

				acPlayerData[uid].speedStrikes = 0

				acPlayerData[uid].flyStrikes = 0

				acPlayerData[uid].tpStrikes = 0

				acPlayerData[uid].velStrikes = 0

				acPlayerData[uid].airTime = 0

				acPlayerData[uid].noclipStrikes = 0

			end

			-- Sauvegarder la position avant

			plr:SetAttribute("ModCamOriginX", hrp.CFrame.X)

			plr:SetAttribute("ModCamOriginY", hrp.CFrame.Y)

			plr:SetAttribute("ModCamOriginZ", hrp.CFrame.Z)

			-- Rendre TOUT invisible : parts, decals, BillboardGui, nametags

			for _, v in pairs(char:GetDescendants()) do

				if v:IsA("BasePart") then

					v:SetAttribute("_MCT", v.Transparency)

					v:SetAttribute("_MCC", v.CanCollide)

					v.Transparency = 1

					v.CanCollide = false

				elseif v:IsA("Decal") or v:IsA("Texture") then

					v:SetAttribute("_MCT", v.Transparency)

					v.Transparency = 1

				elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

					v:SetAttribute("_MCE", v.Enabled)

					v.Enabled = false

				elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then

					v:SetAttribute("_MCE", v.Enabled)

					v.Enabled = false

				end

			end

			-- Cacher le nametag Roblox

			if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

			-- [FIX] NE PAS téléporter sous la map — juste invisible + ancrer sur place

			-- (Avant: tp à Y=-500 faisait que la caméra apparaissait sous la map ailleurs)

			hrp.Anchored = true

			-- hrp.CFrame INCHANGÉ (le character reste exactement là où il était)

			if hum then hum.PlatformStand = true end

		elseif action == "Exit" then

			-- D'abord téléporter le corps à la position de la caméra

			if camPosition and typeof(camPosition) == "Vector3" then

				hrp.CFrame = CFrame.new(camPosition + Vector3.new(0, -3, 0))

			else

				local ox = plr:GetAttribute("ModCamOriginX") or 0

				local oy = plr:GetAttribute("ModCamOriginY") or 10

				local oz = plr:GetAttribute("ModCamOriginZ") or 0

				hrp.CFrame = CFrame.new(ox, oy, oz)

			end

			-- Désancrer AVANT de rendre visible

			hrp.Anchored = false

			hrp.AssemblyLinearVelocity = Vector3.zero

			hrp.AssemblyAngularVelocity = Vector3.zero

			if hum then

				hum.PlatformStand = false

				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

			end

			-- Rendre TOUT visible (fallback robuste si attributs perdus)

			for _, v in pairs(char:GetDescendants()) do

				if v:IsA("BasePart") then

					local savedT = v:GetAttribute("_MCT")

					if savedT ~= nil then

						v.Transparency = savedT

					elseif v.Name == "HumanoidRootPart" then

						v.Transparency = 1

					else

						v.Transparency = 0

					end

					local savedC = v:GetAttribute("_MCC")

					if savedC ~= nil then

						v.CanCollide = savedC

					else

						v.CanCollide = (v.Name ~= "HumanoidRootPart")

					end

					v:SetAttribute("_MCT", nil)

					v:SetAttribute("_MCC", nil)

				elseif v:IsA("Decal") or v:IsA("Texture") then

					local savedT = v:GetAttribute("_MCT")

					v.Transparency = (savedT ~= nil) and savedT or 0

					v:SetAttribute("_MCT", nil)

				elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

					local savedE = v:GetAttribute("_MCE")

					v.Enabled = (savedE ~= nil) and savedE or true

					v:SetAttribute("_MCE", nil)

				elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then

					local savedE = v:GetAttribute("_MCE")

					v.Enabled = (savedE ~= nil) and savedE or true

					v:SetAttribute("_MCE", nil)

				end

			end

			-- Whitelist TP temporaire puis retirer tout

			acWhitelistFn(plr, "teleport", true)

			task.delay(3, function()

				acUnwhitelistFn(plr, "fly")

				acUnwhitelistFn(plr, "noclip")

				acUnwhitelistFn(plr, "speed")

				acUnwhitelistFn(plr, "teleport")

			end)

			-- Confirmer au client

			modCamEvent:FireClient(plr, "Restored")

		elseif action == "ModFly" then

			-- Vol invisible : whitelist AC + invisible MAIS reste en jeu (pas sous la map)

			acWhitelistFn(plr, "fly", true)

			acWhitelistFn(plr, "noclip", true)

			acWhitelistFn(plr, "speed", true)

			acWhitelistFn(plr, "teleport", true)

			-- Reset les données AC pour éviter faux positifs (position stale)

			local uid = plr.UserId

			if acPlayerData[uid] then

				acPlayerData[uid].lastPos = hrp.Position

				acPlayerData[uid].lastValidPos = hrp.Position

				acPlayerData[uid].speedStrikes = 0

				acPlayerData[uid].flyStrikes = 0

				acPlayerData[uid].tpStrikes = 0

				acPlayerData[uid].velStrikes = 0

				acPlayerData[uid].airTime = 0

				acPlayerData[uid].noclipStrikes = 0

				acPlayerData[uid].jumpStrikes = 0

			end

			for _, v in pairs(char:GetDescendants()) do

				if v:IsA("BasePart") then

					v:SetAttribute("_MFT", v.Transparency)

					v:SetAttribute("_MFC", v.CanCollide)

					v.Transparency = 1

					v.CanCollide = false

				elseif v:IsA("Decal") or v:IsA("Texture") then

					v:SetAttribute("_MFT", v.Transparency)

					v.Transparency = 1

				elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

					v:SetAttribute("_MFE", v.Enabled)

					v.Enabled = false

				elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then

					v:SetAttribute("_MFE", v.Enabled)

					v.Enabled = false

				end

			end

			if hum then

				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

			end

			modCamEvent:FireClient(plr, "FlyStarted")

		elseif action == "ModFlyExit" then

			local uid = plr.UserId

			-- Reset AC data

			if acPlayerData[uid] then

				acPlayerData[uid].lastPos = hrp.Position

				acPlayerData[uid].lastValidPos = hrp.Position

				acPlayerData[uid].speedStrikes = 0

				acPlayerData[uid].flyStrikes = 0

				acPlayerData[uid].tpStrikes = 0

				acPlayerData[uid].velStrikes = 0

				acPlayerData[uid].airTime = 0

				acPlayerData[uid].noclipStrikes = 0

			end

			-- Restaurer la visibilité côté serveur (pour les autres joueurs)

			-- Le client restaure sa propre vue via flySavedParts (pas de LoadCharacter)

			if hum then

				hum.PlatformStand = false

				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

			end

			for _, v in pairs(char:GetDescendants()) do

				if v:IsA("BasePart") then

					local savedT = v:GetAttribute("_MFT")

					local savedC = v:GetAttribute("_MFC")

					v.Transparency = (savedT ~= nil) and savedT or 0

					v.CanCollide   = (savedC ~= nil) and savedC or (v.Name ~= "HumanoidRootPart")

				elseif v:IsA("Decal") or v:IsA("Texture") then

					local savedT = v:GetAttribute("_MFT")

					v.Transparency = (savedT ~= nil) and savedT or 0

				elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then

					local savedE = v:GetAttribute("_MFE")

					v.Enabled = (savedE == nil) or savedE

				elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then

					local savedE = v:GetAttribute("_MFE")

					v.Enabled = (savedE == nil) or savedE

				end

			end

			-- Retirer whitelist après délai (stabilisation)

			task.delay(2, function()

				acUnwhitelistFn(plr, "fly")

				acUnwhitelistFn(plr, "noclip")

				acUnwhitelistFn(plr, "speed")

				acUnwhitelistFn(plr, "teleport")

			end)

			modCamEvent:FireClient(plr, "FlyEnded")

		elseif action == "ZoneStaff" or action == "ZoneStaffTarget" then

			-- Téléporter le mod + un joueur cible sur la part "zone staff"

			local zonePart = workspace:FindFirstChild("zone staff", true)

			if not zonePart then

				notifEvent:FireClient(plr, "Part 'zone staff' introuvable dans le jeu.")

				return

			end

			-- [FIX] CFrame.new(position) = orientation neutre (face Z+), évite d'arriver tourné

			local dest = CFrame.new(zonePart.Position + Vector3.new(0, 5, 0))

			-- Sauvegarder position du mod AVANT le TP

			if not plr:GetAttribute("_ZoneOrigX") then

				plr:SetAttribute("_ZoneOrigX", hrp.CFrame.X)

				plr:SetAttribute("_ZoneOrigY", hrp.CFrame.Y)

				plr:SetAttribute("_ZoneOrigZ", hrp.CFrame.Z)

			end

			-- TP le mod (skip si ZoneStaffTarget — TP uniquement la cible)

			if action == "ZoneStaff" then

				acWhitelistFn(plr, "teleport", true)

				acWhitelistFn(plr, "speed", true)

				hrp.CFrame = dest

				-- [FIX] Reset Sit/PlatformStand + ChangeState pour arriver droit

				if hum then

					hum.Sit = false

					hum.PlatformStand = false

					hum:ChangeState(Enum.HumanoidStateType.GettingUp)

				end

				task.delay(5, function()

					acUnwhitelistFn(plr, "teleport")

					acUnwhitelistFn(plr, "speed")

				end)

				-- Notifier le client pour afficher le bouton retour

				modCamEvent:FireClient(plr, "ZoneStaffEntered")

			end

			-- (envoi ZoneStaffEntered fait dans le bloc if au-dessus)

			-- TP la cible si fournie — sauvegarder sa position d'origine

			if camPosition and typeof(camPosition) == "number" then

				local targetPlr = Players:GetPlayerByUserId(camPosition)

				if targetPlr and targetPlr.Character then

					local tHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")

					if tHrp then

						-- Sauvegarder position d'origine SEULEMENT si pas deja en zone (evite l'ecrasement)

						if not targetPlr:GetAttribute("_ZoneOrigX") then

							targetPlr:SetAttribute("_ZoneOrigX", tHrp.CFrame.X)

							targetPlr:SetAttribute("_ZoneOrigY", tHrp.CFrame.Y)

							targetPlr:SetAttribute("_ZoneOrigZ", tHrp.CFrame.Z)

						end

						acWhitelistFn(targetPlr, "teleport", true)

						acWhitelistFn(targetPlr, "speed", true)

						tHrp.CFrame = dest * CFrame.new(4, 0, 0)

						-- [FIX] Reset Sit/PlatformStand cible pour qu'elle arrive droite

						local tHum = targetPlr.Character:FindFirstChildOfClass("Humanoid")

						if tHum then

							tHum.Sit = false

							tHum.PlatformStand = false

							tHum:ChangeState(Enum.HumanoidStateType.GettingUp)

						end

						-- Notifier la cible qu'elle a été convoquée

						notifEvent:FireClient(targetPlr, plr.Name.." t'a convoqué en zone staff.")

						task.delay(5, function()

							acUnwhitelistFn(targetPlr, "teleport")

							acUnwhitelistFn(targetPlr, "speed")

						end)

					end

				end

			end

		elseif action == "ZoneStaffReturn" then

			-- Remettre un joueur à sa position d'origine (avant zone staff)

			if camPosition and typeof(camPosition) == "number" then

				local targetPlr = Players:GetPlayerByUserId(camPosition)

				if targetPlr and targetPlr.Character then

					local tHrp = targetPlr.Character:FindFirstChild("HumanoidRootPart")

					if tHrp then

						local ox = targetPlr:GetAttribute("_ZoneOrigX")

						local oy = targetPlr:GetAttribute("_ZoneOrigY")

						local oz = targetPlr:GetAttribute("_ZoneOrigZ")

						if ox and oy and oz then

							acWhitelistFn(targetPlr, "teleport", true)

							acWhitelistFn(targetPlr, "speed", true)

							tHrp.CFrame = CFrame.new(ox, oy, oz)

							task.delay(5, function()

								acUnwhitelistFn(targetPlr, "teleport")

								acUnwhitelistFn(targetPlr, "speed")

							end)

							-- Nettoyer les attributs

							targetPlr:SetAttribute("_ZoneOrigX", nil)

							targetPlr:SetAttribute("_ZoneOrigY", nil)

							targetPlr:SetAttribute("_ZoneOrigZ", nil)

							notifEvent:FireClient(plr, targetPlr.Name.." remis a sa position.")

						else

							notifEvent:FireClient(plr, "Pas de position sauvegardee pour ce joueur.")

						end

					end

				end

			end

			notifEvent:FireClient(plr, "Teleporte en zone staff.")

		elseif action == "ZoneStaffReturnSelf" then

			-- Le mod veut revenir à sa position d'avant la zone staff

			local ox = plr:GetAttribute("_ZoneOrigX")

			local oy = plr:GetAttribute("_ZoneOrigY")

			local oz = plr:GetAttribute("_ZoneOrigZ")

			if ox and oy and oz then

				acWhitelistFn(plr, "teleport", true)

				acWhitelistFn(plr, "speed", true)

				hrp.CFrame = CFrame.new(ox, oy, oz)

				task.delay(5, function()

					acUnwhitelistFn(plr, "teleport")

					acUnwhitelistFn(plr, "speed")

				end)

				plr:SetAttribute("_ZoneOrigX", nil)

				plr:SetAttribute("_ZoneOrigY", nil)

				plr:SetAttribute("_ZoneOrigZ", nil)

				modCamEvent:FireClient(plr, "ZoneStaffLeft")

			else

				notifEvent:FireClient(plr, "Pas de position sauvegardee.")

			end

		end

	end)

	-- ------------------------------------------------

	-- MOD TP — Whitelist AC pour les TP du panel mod

	-- ------------------------------------------------

	modTPEvent.OnServerEvent:Connect(function(plr)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return end

		acWhitelistFn(plr, "teleport", true)

		acWhitelistFn(plr, "speed", true)

		task.delay(3, function()

			acUnwhitelistFn(plr, "teleport")

			acUnwhitelistFn(plr, "speed")

		end)

	end)

	-- ------------------------------------------------

	-- LISTE SUSPECTS — DataStore persistant

	-- ------------------------------------------------

	suspectAddEvent.OnServerEvent:Connect(function(plr, targetId, targetName, reason)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return end

		if not targetId or not targetName then return end

		task.spawn(function()

			local ok, list = pcall(function() return SuspectStore:GetAsync("SuspectList") end)

			list = list or {}

			list[tostring(targetId)] = {

				Name = targetName,

				Reason = reason or "",

				AddedBy = plr.Name,

				Date = os.date("%Y-%m-%d %H:%M"),

			}

			pcall(function() SuspectStore:SetAsync("SuspectList", list) end)

			notifEvent:FireClient(plr, targetName.." ajouté aux suspects.")

		end)

	end)

	suspectRemEvent.OnServerEvent:Connect(function(plr, targetId)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return end

		if not targetId then return end

		task.spawn(function()

			local ok, list = pcall(function() return SuspectStore:GetAsync("SuspectList") end)

			list = list or {}

			local name = list[tostring(targetId)] and list[tostring(targetId)].Name or "?"

			list[tostring(targetId)] = nil

			pcall(function() SuspectStore:SetAsync("SuspectList", list) end)

			notifEvent:FireClient(plr, name.." retiré des suspects.")

		end)

	end)

	-- ══ THEME PREFERENCE ══

	themePrefFunc.OnServerInvoke = function(plr, action, value)

		local uid = tostring(plr.UserId)

		if action == "save" and (type(value) == "number" or type(value) == "string") then

			-- [FIX] Cap string à 50 chars pour éviter abus DataStore quota

			if type(value) == "string" and #value > 50 then value = value:sub(1, 50) end

			pcall(function() ThemeStore:SetAsync(uid, value) end)

			return true

		elseif action == "load" then

			local ok, v = pcall(function() return ThemeStore:GetAsync(uid) end)

			return (ok and v) or nil

		end

		return nil

	end

	suspectListFunc.OnServerInvoke = function(plr)

		local lvl = rolesHierarchy[_G.Agora_getPlayerRole(plr)] or 99

		if lvl > 4 then return {} end

		local ok, list = pcall(function() return SuspectStore:GetAsync("SuspectList") end)

		return (ok and list) or {}

	end

	print("[Agora Admin] Premium actif: AC + Tickets + ModCam + Suspects")

	end -- fin if IS_PREMIUM

	-- Remote pour que le ModMenu sache si premium est actif

	local premiumCheckFunc = getRemote("PremiumCheckFunc", "RemoteFunction")

	premiumCheckFunc.OnServerInvoke = function()

		return IS_PREMIUM

	end

	-- ════════════════════════════════════════════════════════════════════════

	-- [CONFIG JSON DYNAMIQUE] Fetch client_config.json depuis GitHub via Supabase.

	-- Permet de modifier le comportement du LocalScript SANS le re-publier.

	-- Workflow: modifier client_config.json sur GitHub, push, restart serveur Roblox.

	-- ════════════════════════════════════════════════════════════════════════

	local clientConfig = {} -- defaut vide si fetch échoue

	task.spawn(function()

		local PROXY_URL = "https://kpsshbmgejbeeyreqqit.supabase.co/functions/v1/agora-proxy"

		local ok, raw = pcall(function()

			return HttpService:GetAsync(PROXY_URL .. "?file=client_config.json")

		end)

		if ok and raw then

			-- Strip metadata prefix éventuel (proxy peut prepend) → trouver "{"

			local jsonStart = raw:find("{")

			if jsonStart then raw = raw:sub(jsonStart) end

			local okParse, parsed = pcall(function() return HttpService:JSONDecode(raw) end)

			if okParse and type(parsed) == "table" then

				clientConfig = parsed

				print("[Agora Admin] client_config.json charge (version: " .. tostring(parsed.version or "?") .. ")")

			else

				warn("[Agora Admin] client_config.json invalide: " .. tostring(parsed))

			end

		else

			print("[Agora Admin] client_config.json indisponible (NetFail) — utilisation des valeurs par défaut")

		end

	end)

	-- RemoteFunction pour que le client recupere le config au join

	local clientConfigFunc = getRemote("ClientConfigFunc", "RemoteFunction")

	clientConfigFunc.OnServerInvoke = function(plr)

		return clientConfig

	end

	-- ════════════════════════════════════════════════════════════════════════

	-- [HONEYPOTS] Remotes leurres avec noms tentants pour exploiteurs.

	-- Un joueur normal ne touche JAMAIS ces remotes (ils ne sont referencés

	-- nulle part dans le code client). Tout invoke = exploiteur qui scanne

	-- les remotes et essaie de les abuser. Kick instantané.

	-- ════════════════════════════════════════════════════════════════════════

	local HONEYPOT_NAMES = {

		"AdminBypass",

		"GiveAdmin",

		"GiveOwner",

		"GodModeEnable",

		"BypassAntiCheat",

		"UnlockAllItems",

		"FreeMoney",

		"GiveAllMoney",

		"AdminPanelOpen",

		"DevConsoleAccess",

		"SuperJumpEnable",

		"WallhackToggle",

		"NoclipMaster",

		"FlyMaster",

		"InfiniteHealth",

		"GetServerKey",

		"PromoteToOwner",

		"BypassBan",

	}

	local honeypotKicks = {} -- anti-spam : 1 kick par joueur

	local function honeypotKick(plr, remoteName)

		if not plr or not plr.Parent then return end

		if honeypotKicks[plr.UserId] then return end

		honeypotKicks[plr.UserId] = true

		-- [PAS DE KICK AUTO] Juste alerter les staff dans le panel AC LOGS

		pcall(function()

			if acSendAlert then

				acSendAlert(plr, "HONEYPOT TRIGGER",

					"Acces non autorise: remote '" .. remoteName .. "' (no kick auto)")

			end

		end)

		warn(string.format("[Agora AC] HONEYPOT '%s' touched by %s (UserId: %d) — alerte staff",

			remoteName, plr.Name, plr.UserId))

	end

	for _, hpName in ipairs(HONEYPOT_NAMES) do

		-- Creer un mix de RemoteEvent et RemoteFunction (les exploits scan les 2)

		local kind = (math.random() > 0.5) and "RemoteEvent" or "RemoteFunction"

		local hp = getRemote(hpName, kind)

		if kind == "RemoteEvent" then

			hp.OnServerEvent:Connect(function(plr, ...) honeypotKick(plr, hpName) end)

		else

			hp.OnServerInvoke = function(plr, ...) honeypotKick(plr, hpName) return nil end

		end

	end

	Players.PlayerRemoving:Connect(function(p)

		honeypotKicks[p.UserId] = nil

	end)

	print("[Agora AC] " .. #HONEYPOT_NAMES .. " honeypots actifs.")

end
