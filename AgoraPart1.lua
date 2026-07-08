-- Agora Hub [UNIVERSELLE] - Panel Roblox universel
-- LocalScript dans StarterPlayerScripts ou exécuteur

SETTINGS = {
	SpiderSpeed = 16,
	SpiderHoverDistance = 2.6,
	SpiderNetworkCompensation = 0.8,
	SpiderJumpPower = 60,
	SpiderJumpCooldown = 0.5,
	SpiderTransitionSpeed = 15
}

-- SAFEGUARD EXECUTEUR: certains loadstring ne passent pas 'game' en global
-- On recupere game via getfenv, shared, ou le premier argument de loadstring
local _game = nil
if game then _game = game end
if not _game then
	local ok, envGame = pcall(function() return getfenv().game end)
	if ok and envGame then _game = envGame end
end
if not _game then
	local ok, sharedGame = pcall(function() return shared and shared.game end)
	if ok and sharedGame then _game = sharedGame end
end
if not _game then
	local ok, argGame = pcall(function() return nil end)
	if ok and argGame and typeof(argGame) == "Instance" and argGame:IsA("DataModel") then _game = argGame end
end
if not _game then
	for i = 0, 10 do
		local ok, env = pcall(function() return getfenv(i) end)
		if ok and env then
			local ok2, g = pcall(function() return env.game end)
			if ok2 and g then _game = g; break end
		end
	end
end
if not _game then
	-- Dernier recours: chercher dans les globals
	for k, v in pairs(getfenv()) do
		if typeof(v) == "Instance" and pcall(function() return v:IsA("DataModel") end) then
			_game = v; break
		end
	end
end
if not _game then
	warn("[AGORA] game est nil - executeur incompatible")
	return
end
game = _game

-- WRAP PANEL IN LOCAL FUNCTION to avoid Solara 200-register chunk limit


-- === COORDINATOR ===
_G._buildPanel = function()
if not game then
	warn("[AGORA] game est nil — exécuteur incompatible ou loadstring mal formé")
	return
end

-- === LOADING SCREEN ===
Players = game:GetService("Players")
RunService = game:GetService("RunService")
UserInputService = game:GetService("UserInputService")
TextChatService = game:GetService("TextChatService")
Workspace = game:GetService("Workspace")
Lighting = game:GetService("Lighting")
ReplicatedStorage = game:GetService("ReplicatedStorage")
TweenService = game:GetService("TweenService")
HttpService = game:GetService("HttpService")
SoundService = game:GetService("SoundService")

-- Create loading screen
loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "AgoraLoading"
loadingGui.ResetOnSpawn = false
loadingGui.Parent = (game:GetService("CoreGui")) or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

loadingBg = Instance.new("Frame")
loadingBg.Size = UDim2.new(1, 0, 1, 0)
loadingBg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
loadingBg.BackgroundTransparency = 0
loadingBg.BorderSizePixel = 0
loadingBg.Parent = loadingGui

loadingLogo = Instance.new("TextLabel")
loadingLogo.Size = UDim2.new(0, 300, 0, 60)
loadingLogo.Position = UDim2.new(0.5, -150, 0.4, -30)
loadingLogo.BackgroundTransparency = 1
loadingLogo.Text = "AGORA"
loadingLogo.Font = Enum.Font.GothamBold
loadingLogo.TextSize = 48
loadingLogo.TextColor3 = Color3.fromRGB(60, 180, 255)
loadingLogo.TextXAlignment = Enum.TextXAlignment.Center
loadingLogo.Parent = loadingBg

loadingSub = Instance.new("TextLabel")
loadingSub.Size = UDim2.new(0, 300, 0, 30)
loadingSub.Position = UDim2.new(0.5, -150, 0.4, 35)
loadingSub.BackgroundTransparency = 1
loadingSub.Text = "UNIVERSELLE HUB"
loadingSub.Font = Enum.Font.Gotham
loadingSub.TextSize = 18
loadingSub.TextColor3 = Color3.fromRGB(120, 120, 140)
loadingSub.TextXAlignment = Enum.TextXAlignment.Center
loadingSub.Parent = loadingBg

loadingBarBg = Instance.new("Frame")
loadingBarBg.Size = UDim2.new(0, 250, 0, 6)
loadingBarBg.Position = UDim2.new(0.5, -125, 0.5, -3)
loadingBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
loadingBarBg.BorderSizePixel = 0
barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 3)
barCorner.Parent = loadingBarBg
loadingBarBg.Parent = loadingBg

loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.new(0, 0, 1, 0)
loadingBar.BackgroundColor3 = Color3.fromRGB(60, 180, 255)
loadingBar.BorderSizePixel = 0
barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 3)
barFillCorner.Parent = loadingBar
loadingBar.Parent = loadingBarBg

loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(0, 300, 0, 20)
loadingText.Position = UDim2.new(0.5, -150, 0.5, 15)
loadingText.BackgroundTransparency = 1
loadingText.Text = "Chargement..."
loadingText.Font = Enum.Font.Gotham
loadingText.TextSize = 13
loadingText.TextColor3 = Color3.fromRGB(100, 100, 120)
loadingText.TextXAlignment = Enum.TextXAlignment.Center
loadingText.Parent = loadingBg

-- Loading dots animation
dots = Instance.new("TextLabel")
dots.Size = UDim2.new(0, 300, 0, 20)
dots.Position = UDim2.new(0.5, -150, 0.5, 35)
dots.BackgroundTransparency = 1
dots.Text = ""
dots.Font = Enum.Font.Gotham
dots.TextSize = 20
dots.TextColor3 = Color3.fromRGB(60, 180, 255)
dots.TextXAlignment = Enum.TextXAlignment.Center
dots.Parent = loadingBg

-- Animate dots
task.spawn(function()
	local dotFrames = {"", ".", "..", "...", "....", "....."}
	local i = 0
	while loadingGui and loadingGui.Parent do
		i = i % #dotFrames + 1
		dots.Text = dotFrames[i]
		task.wait(0.3)
	end
end)

-- Helper: update loading bar
local function updateLoad(progress, msg)
	if loadingBar and loadingBar.Parent then
		loadingBar:TweenSize(UDim2.new(progress, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
	end
	if loadingText then
		loadingText.Text = msg or "Chargement..."
	end
	-- Petit wait pour étaler la charge
	task.wait(0.05)
end

updateLoad(0.02, "Initialisation...")
task.wait(0.1)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

-- Helper multi-fallback pour vérifier si un joueur peut chatter (client-only, pas d'accès serveur)
_G._resolveCanChat = function(target, callback)
	task.spawn(function()
		local result, src = nil, "non vérifiable"
		local uid = (typeof(target) == "Instance" and target:IsA("Player") and target.UserId) or tonumber(target)

		-- 1) VRAIE réponse serveur : RemoteFunction CanUsersChatAsync
		if uid and LocalPlayer then
			local rf = ReplicatedStorage:FindFirstChild("AgoraCanChatRF")
			if rf and rf:IsA("RemoteFunction") then
				local ok, r = pcall(function() return rf:InvokeServer(uid) end)
				if ok and r ~= nil then
					result, src = r, "CanTalkWithMe"
				end
			end
		end

		-- 2) API client native (moins fiable, indique juste "a le chat activé")
		if result == nil and uid then
			local ok, r = pcall(function() return TextChatService:CanUserChatAsync(uid) end)
			if ok then result, src = r, "ChatEnabled" end
		end

		-- 3) Propriétés legacy
		if result == nil and typeof(target) == "Instance" and target:IsA("Player") then
			local ok, r = pcall(function() return target.CanChat end)
			if ok then result, src = r, "Player.CanChat" end
		end
		if result == nil and typeof(target) == "Instance" and target:IsA("Player") and LocalPlayer then
			local ok, r = pcall(function() return target:CanChatWith(LocalPlayer.UserId) end)
			if ok then result, src = r, "CanChatWith" end
		end
		if result == nil and typeof(target) == "Instance" and target:IsA("Player") then
			local ok, r = pcall(function()
				local chans = TextChatService:FindFirstChild("TextChannels")
				if not chans then return nil end
				local general = chans:FindFirstChild("RBXGeneral")
				if not general then return nil end
				for _, sp in ipairs(general:GetChildren()) do
					if sp:IsA("TextSource") and tostring(sp.UserId) == tostring(target.UserId) then
						return true
					end
				end
				return false
			end)
			if ok then result, src = r, "TextChannels" end
		end
		-- 5) On a VU le joueur parler dans le chat public → il peut nous parler
		if result == nil and uid and _G._chatSeenPlayers[uid] then
			local since = tick() - _G._chatSeenPlayers[uid]
			if since <= 600 then
				result, src = true, "Vu parler"
			else
				_G._chatSeenPlayers[uid] = nil
			end
		end
		pcall(function() callback(result, src) end)
	end)
end

-- Client-only chat detection: remember players whose public messages we actually saw
_G._chatSeenPlayers = {}
task.spawn(function()
	local ok, svc = pcall(function() return game:GetService("TextChatService") end)
	if not ok or not svc then return end
	local ok2 = pcall(function()
		svc.MessageReceived:Connect(function(msg)
			if not (msg and msg.TextSource and msg.TextSource.UserId) then return end
			local uid = tonumber(msg.TextSource.UserId)
			if uid then
				_G._chatSeenPlayers[uid] = tick()
			end
		end)
	end)
	if not ok2 then
		-- Legacy chat fallback
		pcall(function()
			local default = game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents", 3)
			if default then
				local ev = default:FindFirstChild("OnMessageDoneFiltering")
				if ev then
					ev.OnClientEvent:Connect(function(data)
						local uid = tonumber(data and data.SpeakerUserId)
						if uid then _G._chatSeenPlayers[uid] = tick() end
					end)
				end
			end
		end)
	end
end)

-- Wrapper de son multi-exécuteur (Solara, etc.) - pcall silencieux
local function playSound(id, vol)
	if not id then return end
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume = vol or 0.4
		s.Parent = SoundService
		if s.IsLoaded then
			s:Play()
		else
			s.Loaded:Connect(function()
				s:Play()
			end)
		end
		local len = (s.TimeLength and s.TimeLength > 0) and s.TimeLength or 3
		task.delay(len + 0.2, function()
			pcall(function() s:Destroy() end)
		end)
	end)
end

-- Helper HTTP multi-executeur (essaie TOUTES les methodes possibles)
local function httpGet(url)
	-- 1) game:HttpGet (Solara, Xeno, etc.) - le plus commun
	local ok, r = pcall(function() return game:HttpGet(url) end)
	if ok and r and r ~= "" then return r end
	-- 2) game:HttpGet avec no-cache
	ok, r = pcall(function() return game:HttpGet(url, true) end)
	if ok and r and r ~= "" then return r end
	-- 3) HttpService:RequestAsync (marche sur certains executeurs qui bloquent GetAsync)
	ok, r = pcall(function()
		local resp = HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = {["Content-Type"] = "application/json"}
		})
		if resp and resp.Success and resp.Body then return resp.Body end
	end)
	if ok and r and r ~= "" then return r end
	-- 4) HttpService:GetAsync (Studio-like)
	ok, r = pcall(function() return HttpService:GetAsync(url) end)
	if ok and r and r ~= "" then return r end
	-- 5) HttpService:GetAsync avec no-cache
	ok, r = pcall(function() return HttpService:GetAsync(url, true) end)
	if ok and r and r ~= "" then return r end
	-- 6) request / syn.request (Synapse, Fluxus, Wave, etc.)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		ok, r = pcall(function() return req({Url=url, Method="GET"}).Body end)
		if ok and r and r ~= "" then return r end
	end
	-- 7) request avec headers
	if req then
		ok, r = pcall(function() return req({
			Url = url,
			Method = "GET",
			Headers = {["User-Agent"] = "Roblox/WinInet", ["Accept"] = "*/*"}
		}).Body end)
		if ok and r and r ~= "" then return r end
	end
	-- 8) HttpPost avec GET simule (certains executeurs acceptent)
	ok, r = pcall(function() return game:HttpPost(url, "", true, "application/json") end)
	if ok and r and r ~= "" then return r end
	return nil
end

local function httpPost(url, body)
	-- 1) game:HttpPostJSON / HttpGet avec body
	local ok, r = pcall(function() return game:HttpGet(url, true, body) end)
	if ok and r and r ~= "" then return r end
	-- 2) HttpService:PostAsync
	ok, r = pcall(function() return HttpService:PostAsync(url, body) end)
	if ok and r and r ~= "" then return r end
	-- 3) request POST
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		ok, r = pcall(function() return req({Url=url, Method="POST", Body=body, Headers={["Content-Type"]="application/json"}}).Body end)
		if ok and r and r ~= "" then return r end
	end
	return nil
end

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Mémoire client : sauvegarde persistante entre réouvertures du panel
if not _G.PanelMemory then
	_G.PanelMemory = { dontAskRestore = false, lastEchoPlayerName = nil }
end
local panelMemory = _G.PanelMemory

local character, humanoid, rootPart
local function updateCharacter()
	character = LocalPlayer.Character
	if character then
		humanoid = character:FindFirstChildOfClass("Humanoid")
		rootPart = character:FindFirstChild("HumanoidRootPart")
	else
		humanoid, rootPart = nil, nil
	end
end

updateCharacter()
LocalPlayer.CharacterAdded:Connect(function(char)
	char:WaitForChild("HumanoidRootPart")
	char:WaitForChild("Humanoid")
	task.wait(0.2)
	updateCharacter()
	if flyState and flyState.flying then
		stopFly()
	end
	if noclipState and noclipState.enabled then
		noclipState.enabled = false
		if refreshNoClipSwitch then refreshNoClipSwitch() end
	end
	if espState.enabled or globalESPEnabled then
		refreshESP()
	end
end)

local function getDeviceType()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	elseif UserInputService.GamepadEnabled then
		return "Console"
	else
		return "PC"
	end
end

local function createCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function createStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(60, 60, 60)
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function tween(obj, props, duration)
	if not obj or not obj.Parent then return end
	pcall(function()
		TweenService:Create(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MilanEmerickPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Backdrop retiré : il recouvrait tout l'écran en noir semi-transparent.

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 460, 0, 520)
mainFrame.Position = UDim2.new(0.5, -230, 0.5, -260)
mainFrame.Visible = false  -- Sera révélé après l'intro
-- S'assure que le panel reste visible et ne se fait pas pousser par le chat au démarrage
task.delay(0, function()
	local function clampFrame()
		local abs = mainFrame.AbsoluteSize
		local scr = screenGui.AbsoluteSize
		local x = math.clamp(mainFrame.AbsolutePosition.X, 0, math.max(0, scr.X - abs.X))
		local y = math.clamp(mainFrame.AbsolutePosition.Y, 0, math.max(0, scr.Y - abs.Y))
		mainFrame.Position = UDim2.new(0, x, 0, y)
	end
	clampFrame()
	task.wait(0.1)
	clampFrame()
end)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.BackgroundTransparency = 0.35
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 1
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(120, 120, 150), 1.2)

-- ===== INTRO CINÉMA : "Agora Hub" puis TAMPON "UNIVERSELLE" BOUM =====
-- Backdrop full screen noir pour masquer le panel pendant l'intro
;(function()
	local _mainFrame = mainFrame
	local _screenGui = screenGui
	local _LocalPlayer = LocalPlayer
	local _TweenService = TweenService
	local _tween = tween
	local _createCorner = createCorner

	local bootGui = Instance.new("ScreenGui")
	bootGui.Name = "MilanEmerickIntro"
	bootGui.ResetOnSpawn = false
	bootGui.DisplayOrder = 99999
	bootGui.IgnoreGuiInset = true
	bootGui.Parent = _LocalPlayer:WaitForChild("PlayerGui")

	-- Backdrop noir full screen
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 100
	backdrop.Parent = bootGui

	-- Vignette dorée subtile en arrière-plan
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.new(1.4, 0, 1.4, 0)
	vignette.Position = UDim2.new(-0.2, 0, -0.2, 0)
	vignette.BackgroundTransparency = 1
	vignette.Image = "rbxassetid://9638773891"
	vignette.ImageColor3 = Color3.fromRGB(120, 90, 30)
	vignette.ImageTransparency = 0.6
	vignette.ZIndex = 101
	vignette.Parent = bootGui

	-- Titre "Agora Hub" - apparaît avec un fade in
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.9, 0, 0, 50)
	title.Position = UDim2.new(0.05, 0, 0.45, -10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = "Agora Hub"
	title.TextSize = 38
	title.TextColor3 = Color3.fromRGB(220, 220, 240)
	title.TextTransparency = 1
	title.TextStrokeTransparency = 0.5
	title.TextStrokeColor3 = Color3.fromRGB(40, 40, 50)
	title.ZIndex = 102
	title.Parent = bootGui

	-- Sous-titre fin "by Milan & Emerick" en gris clair
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.9, 0, 0, 20)
	subtitle.Position = UDim2.new(0.05, 0, 0.45, 36)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "by Milan & Emerick"
	subtitle.TextSize = 13
	subtitle.TextColor3 = Color3.fromRGB(150, 150, 170)
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 102
	subtitle.Parent = bootGui

	-- Tag "UNIVERSELLE" - cachée au début, scale 0
	local uniTag = Instance.new("TextLabel")
	uniTag.Name = "UniTag"
	uniTag.Size = UDim2.new(1.1, 0, 0, 130)
	uniTag.Position = UDim2.new(-0.05, 0, 0.4, 0)
	uniTag.AnchorPoint = Vector2.new(0, 0)
	uniTag.BackgroundTransparency = 1
	uniTag.Rotation = -8
	uniTag.Font = Enum.Font.GothamBlack
	uniTag.Text = "UNIVERSELLE"
	uniTag.TextScaled = false
	uniTag.TextSize = 110
	uniTag.TextColor3 = Color3.fromRGB(255, 220, 120)
	uniTag.TextStrokeTransparency = 0.2
	uniTag.TextStrokeColor3 = Color3.fromRGB(120, 80, 0)
	uniTag.TextTransparency = 1
	uniTag.ZIndex = 103
	uniTag.Parent = bootGui

	-- 3 traits noirs "stamp borders" autour du tag pour effet tampon
	local stampTop = Instance.new("Frame")
	stampTop.Name = "StampTop"
	stampTop.Size = UDim2.new(0.8, 0, 0, 2)
	stampTop.Position = UDim2.new(0.1, 0, 0.41, 0)
	stampTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stampTop.BorderSizePixel = 0
	stampTop.BackgroundTransparency = 1
	stampTop.ZIndex = 103
	stampTop.Parent = bootGui

	local stampBot = Instance.new("Frame")
	stampBot.Name = "StampBot"
	stampBot.Size = UDim2.new(0.8, 0, 0, 2)
	stampBot.Position = UDim2.new(0.1, 0, 0.68, 0)
	stampBot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stampBot.BorderSizePixel = 0
	stampBot.BackgroundTransparency = 1
	stampBot.ZIndex = 103
	stampBot.Parent = bootGui

	-- BOOM FLASH blanc court (effet impact)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 110
	flash.Parent = bootGui

	-- === SÉQUENCE CINÉMA ===
	task.spawn(function()
		local ok, err = pcall(function()
			-- Étape 1 : fade in du backdrop depuis noir + whoosh grave
			playSound(9114850423, 0.5)
			backdrop.BackgroundTransparency = 0

			-- Étape 2 : titre "Agora Hub" fade in (0.5s) + ding doux
			task.wait(0.3)
			_tween(title, {TextTransparency = 0}, 0.5)
			_tween(subtitle, {TextTransparency = 0}, 0.5)
			playSound(6042053626, 0.25)

			-- Étape 3 : pause 1s pour lire le titre
			task.wait(1.0)

			-- Étape 4 : BOUM - flash blanc brutal + tag scale 0→1.3→1 + boom impact fort
			flash.BackgroundTransparency = 0
			uniTag.TextTransparency = 0
			stampTop.BackgroundTransparency = 0
			stampBot.BackgroundTransparency = 0

			-- Scale : commence à 0, monte à 1.3 puis 1 (impact élastique)
			uniTag.Size = UDim2.new(0, 0, 0, 0)
			uniTag.Position = UDim2.new(0.5, 0, 0.5, 0)
			uniTag.AnchorPoint = Vector2.new(0.5, 0.5)
			uniTag.Rotation = 4  -- rotation d'entrée (corrigée à -8 à la fin)
			playSound(4590662766, 0.85)  -- boom impact
			_tween(uniTag, {Size = UDim2.new(1.2, 0, 0, 140), Rotation = -10}, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			_tween(flash, {BackgroundTransparency = 1}, 0.25)
			task.wait(0.12)
			-- Stabilise à la taille finale avec la bonne rotation
			_tween(uniTag, {Size = UDim2.new(1.1, 0, 0, 130), Rotation = -8}, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			-- Étape 5 : le tag reste affiché 1.2s
			task.wait(1.2)

			-- Étape 6 : fade out de tout
			_tween(title, {TextTransparency = 1}, 0.3)
			_tween(subtitle, {TextTransparency = 1}, 0.3)
			_tween(uniTag, {TextTransparency = 1, Rotation = -12}, 0.4)
			_tween(stampTop, {BackgroundTransparency = 1}, 0.3)
			_tween(stampBot, {BackgroundTransparency = 1}, 0.3)
			_tween(vignette, {ImageTransparency = 1}, 0.3)
			task.wait(0.3)
			_tween(backdrop, {BackgroundTransparency = 1}, 0.4)
			task.wait(0.5)
		end)

		if not ok then
			warn("[MILAN] Intro crash: " .. tostring(err))
		end

		-- Cleanup + révélation du panel
		pcall(function() if bootGui and bootGui.Parent then bootGui:Destroy() end end)
		pcall(function()
			_mainFrame.Visible = true
		end)
	end)
end)()


local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
topBar.BackgroundTransparency = 0.45
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
topBar.ZIndex = 2
createCorner(topBar, 14)
createStroke(topBar, Color3.fromRGB(80, 80, 100), 0.8)

-- Logo à gauche du titre + badge "UNIVERSELLE" penché (mini) à droite du titre
;(function()
	local _topBar = topBar
	local _createCorner = createCorner
	local _createStroke = createStroke

	local titleLogo = Instance.new("ImageLabel")
	titleLogo.Name = "TitleLogo"
	titleLogo.Size = UDim2.new(0, 22, 0, 22)
	titleLogo.Position = UDim2.new(0, 8, 0.5, 0)
	titleLogo.AnchorPoint = Vector2.new(0, 0.5)
	titleLogo.BackgroundTransparency = 1
	titleLogo.Image = "rbxassetid://73314612607499"
	titleLogo.Parent = _topBar

	-- Badge "UNIVERSELLE" petit et penché, à droite du titre
	local uniBadge = Instance.new("TextLabel")
	uniBadge.Name = "UniBadge"
	uniBadge.Size = UDim2.new(0, 90, 0, 18)
	uniBadge.Position = UDim2.new(0, 134, 0.5, 0)
	uniBadge.AnchorPoint = Vector2.new(0, 0.5)
	uniBadge.BackgroundColor3 = Color3.fromRGB(60, 30, 110)
	uniBadge.BackgroundTransparency = 0.15
	uniBadge.BorderSizePixel = 0
	uniBadge.Font = Enum.Font.GothamBlack
	uniBadge.Text = "UNIVERSELLE"
	uniBadge.TextSize = 9
	uniBadge.TextColor3 = Color3.fromRGB(220, 180, 255)
	uniBadge.Rotation = -8
	uniBadge.ZIndex = 5
	uniBadge.Parent = _topBar
	_createCorner(uniBadge, 4)
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(150, 100, 220)
	badgeStroke.Thickness = 1
	badgeStroke.Parent = uniBadge
end)()

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -110, 1, 0)
titleLabel.Position = UDim2.new(0, 36, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Agora Hub"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local function addGlow(frame)
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.Size = UDim2.new(1, 60, 1, 60)
	glow.Position = UDim2.new(0, -30, 0, -30)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://9638773891"
	glow.ImageColor3 = Color3.fromRGB(80, 120, 255)
	glow.ImageTransparency = 0.85
	glow.ZIndex = -1
	glow.Parent = frame
	return glow
end

local mainGlow = addGlow(mainFrame)

task.spawn(function()
	while mainGlow and mainGlow.Parent do
		for i = 0.82, 0.92, 0.003 do
			mainGlow.ImageTransparency = i
			task.wait(0.03)
		end
		for i = 0.92, 0.82, -0.003 do
			mainGlow.ImageTransparency = i
			task.wait(0.03)
		end
	end
end)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar
createCorner(closeBtn, 8)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -68, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
minimizeBtn.Text = "—"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 18
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
minimizeBtn.AutoButtonColor = false
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = topBar
createCorner(minimizeBtn, 8)

local function makeIcon(btn, txt)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 1, 0)
	l.BackgroundTransparency = 1
	l.Text = txt
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = btn
end

makeIcon(closeBtn, "×")

local function createButton(parent, text, yPos, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 34)
	btn.Position = UDim2.new(0, 10, 0, yPos)
	btn.BackgroundColor3 = color or Color3.fromRGB(45, 75, 160)
	btn.Text = text
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = parent
	createCorner(btn, 8)
	btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = color and color:Lerp(Color3.new(1,1,1), 0.15) or Color3.fromRGB(60, 95, 200)}, 0.1) end)
	btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = color or Color3.fromRGB(45, 75, 160)}, 0.1) end)
	btn.MouseButton1Click:Connect(function()
		playSound(6042053626, 0.22)
		if callback then callback() end
	end)
	return btn
end

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 34)
tabBar.Position = UDim2.new(0, 10, 0, 44)
tabBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame
createCorner(tabBar, 10)

local tabHolder = Instance.new("Frame")
tabHolder.Size = UDim2.new(1, -8, 1, -8)
tabHolder.Position = UDim2.new(0, 4, 0, 4)
tabHolder.BackgroundTransparency = 1
tabHolder.Parent = tabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabHolder

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -122)
contentFrame.Position = UDim2.new(0, 10, 0, 82)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local pages = {}
local tabButtons = {}
local activeTab = "Joueurs"

local function switchTab(name)
	activeTab = name
	for n, page in pairs(pages) do
		page.Visible = (n == name)
		if n == name then
			tween(page, {BackgroundTransparency = 1}, 0)
		end
	end
	for n, btn in pairs(tabButtons) do
		local active = (n == name)
		tween(btn, {BackgroundColor3 = active and Color3.fromRGB(55, 90, 180) or Color3.fromRGB(40, 40, 50)}, 0.15)
		btn.TextColor3 = active and Color3.new(1, 1, 1) or Color3.fromRGB(160, 160, 160)
	end
end

local function createTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.115, -2, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		btn.Text = name
		btn.Font = Enum.Font.GothamSemibold
		btn.TextScaled = true
		btn.TextColor3 = Color3.fromRGB(160, 160, 160)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
	btn.Parent = tabHolder
	createCorner(btn, 6)
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
	btn.MouseEnter:Connect(function() if activeTab ~= name then tween(btn, {BackgroundColor3 = Color3.fromRGB(50, 50, 65)}, 0.1) end end)
	btn.MouseLeave:Connect(function() if activeTab ~= name then tween(btn, {BackgroundColor3 = Color3.fromRGB(40, 40, 50)}, 0.1) end end)
	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = contentFrame
	pages[name] = page
	tabButtons[name] = btn
	return page
end

-- ============= Home TAB — IIFE pour 0 top-level local =============
;(function()
	local homePage = createTab("Home")
	
	-- Fond sombre
	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = homePage
	createCorner(bgFrame, 10)
	
	-- Logo / Titre centre
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.new(0, 10, 0, 15)
	title.BackgroundTransparency = 1
	title.Text = "AGORA"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(130, 150, 255)
	title.Parent = bgFrame
	
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -20, 0, 20)
	subtitle.Position = UDim2.new(0, 10, 0, 48)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Universelle Hub"
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 16
	subtitle.TextColor3 = Color3.fromRGB(100, 100, 130)
	subtitle.Parent = bgFrame
	
	-- Separateur
	local sep1 = Instance.new("Frame")
	sep1.Size = UDim2.new(0.8, 0, 0, 1)
	sep1.Position = UDim2.new(0.1, 0, 0, 76)
	sep1.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	sep1.BorderSizePixel = 0
	sep1.Parent = bgFrame
	
	-- Version
	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(1, -20, 0, 18)
	versionLabel.Position = UDim2.new(0, 10, 0, 82)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v39.16"
	versionLabel.Font = Enum.Font.GothamSemibold
	versionLabel.TextSize = 12
	versionLabel.TextColor3 = Color3.fromRGB(100, 220, 120)
	versionLabel.TextXAlignment = Enum.TextXAlignment.Center
	versionLabel.Parent = bgFrame
	
	-- Changelog box
	local changelogBox = Instance.new("Frame")
	changelogBox.Size = UDim2.new(1, -30, 0, 125)
	changelogBox.Position = UDim2.new(0, 15, 0, 105)
	changelogBox.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	changelogBox.BorderSizePixel = 0
	changelogBox.Parent = bgFrame
	createCorner(changelogBox, 8)
	
	local changelogTitle = Instance.new("TextLabel")
	changelogTitle.Size = UDim2.new(1, -10, 0, 20)
	changelogTitle.Position = UDim2.new(0, 8, 0, 6)
	changelogTitle.BackgroundTransparency = 1
	changelogTitle.Text = "Nouveautes"
	changelogTitle.Font = Enum.Font.GothamBold
	changelogTitle.TextSize = 13
	changelogTitle.TextColor3 = Color3.fromRGB(140, 160, 255)
	changelogTitle.TextXAlignment = Enum.TextXAlignment.Left
	changelogTitle.Parent = changelogBox
	
	local changelogScroll = Instance.new("ScrollingFrame")
	changelogScroll.Size = UDim2.new(1, -10, 1, -30)
	changelogScroll.Position = UDim2.new(0, 5, 0, 28)
	changelogScroll.BackgroundTransparency = 1
	changelogScroll.BorderSizePixel = 0
	changelogScroll.ScrollBarThickness = 3
	changelogScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 80)
	changelogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	changelogScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	changelogScroll.Parent = changelogBox
	
	local changelogLayout = Instance.new("UIListLayout")
	changelogLayout.SortOrder = Enum.SortOrder.LayoutOrder
	changelogLayout.Padding = UDim.new(0, 3)
	changelogLayout.Parent = changelogScroll
	
	local changelogEntries = {
		"v38.97 — Tri remotes + traduction langue",
		"+ Remotes interceptes tries en haut de la liste automatiquement",
		"+ Auto-refresh de la liste remotes toutes les 5s",
		"+ Detection amelioree (StarterGui, tous les joueurs, dedup)",
		"+ Traduction des onglets et labels dans 14 langues",
		"+ Changement de langue fonctionne maintenant",
	}
	
	for i, entry in ipairs(changelogEntries) do
		local line = Instance.new("TextLabel")
		line.Size = UDim2.new(1, 0, 0, 16)
		line.BackgroundTransparency = 1
		line.Text = entry
		line.Font = (i == 1) and Enum.Font.GothamSemibold or Enum.Font.Gotham
		line.TextSize = (i == 1) and 12 or 11
		line.TextColor3 = (i == 1) and Color3.fromRGB(100, 220, 120) or Color3.fromRGB(150, 150, 165)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.LayoutOrder = i
		line.Parent = changelogScroll
	end
	
	-- Bouton Discord (copier le lien)
	local discordBtn = Instance.new("TextButton")
	discordBtn.Size = UDim2.new(0.7, 0, 0, 32)
	discordBtn.Position = UDim2.new(0.15, 0, 0, 238)
	discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	discordBtn.Text = "Rejoindre le Discord"
	discordBtn.Font = Enum.Font.GothamBold
	discordBtn.TextSize = 14
	discordBtn.TextColor3 = Color3.new(1, 1, 1)
	discordBtn.BorderSizePixel = 0
	discordBtn.AutoButtonColor = true
	discordBtn.Parent = bgFrame
	createCorner(discordBtn, 8)
	
	local copyLabel = Instance.new("TextLabel")
	copyLabel.Size = UDim2.new(1, 0, 0, 16)
	copyLabel.Position = UDim2.new(0, 0, 1, 3)
	copyLabel.BackgroundTransparency = 1
	copyLabel.Text = ""
	copyLabel.Font = Enum.Font.Gotham
	copyLabel.TextSize = 10
	copyLabel.TextColor3 = Color3.fromRGB(100, 220, 120)
	copyLabel.Parent = bgFrame
	
	discordBtn.MouseButton1Click:Connect(function()
		pcall(function()
			local link = "https://discord.gg/fVw2rzAMb"
			local ok = pcall(function() setclipboard(link) end)
			if ok then
				copyLabel.Text = "Lien copie dans le presse-papiers!"
			else
				ok = pcall(function() toclipboard(link) end)
				if ok then
					copyLabel.Text = "Lien copie dans le presse-papiers!"
				else
					copyLabel.Text = "Lien: " .. link
				end
			end
			playSound(6042053626, 0.3)
		end)
		task.delay(5, function()
			pcall(function() copyLabel.Text = "" end)
		end)
	end)
	discordBtn.MouseEnter:Connect(function() tween(discordBtn, {BackgroundColor3 = Color3.fromRGB(100, 115, 255)}, 0.15) end)
	discordBtn.MouseLeave:Connect(function() tween(discordBtn, {BackgroundColor3 = Color3.fromRGB(88, 101, 242)}, 0.15) end)
	
	-- === SELECTEUR DE LANGUE ===
	local languages = {
		{code = "FR", flag = "🇫🇷", name = "Français"},
		{code = "EN", flag = "🇬🇧", name = "English"},
		{code = "ES", flag = "🇪🇸", name = "Español"},
		{code = "DE", flag = "🇩🇪", name = "Deutsch"},
		{code = "IT", flag = "🇮🇹", name = "Italiano"},
		{code = "PT", flag = "🇵🇹", name = "Português"},
		{code = "RU", flag = "🇷🇺", name = "Русский"},
		{code = "JP", flag = "🇯🇵", name = "日本語"},
		{code = "ZH", flag = "🇨🇳", name = "中文"},
		{code = "KR", flag = "🇰🇷", name = "한국어"},
		{code = "AR", flag = "🇸🇦", name = "العربية"},
		{code = "NL", flag = "🇳🇱", name = "Nederlands"},
		{code = "PL", flag = "🇵🇱", name = "Polski"},
		{code = "TR", flag = "🇹🇷", name = "Türkçe"},
	}

	local function loadLang()
		local saved = nil
		pcall(function()
			saved = readfile("agora_lang.txt")
		end)
		if saved and saved ~= "" then
			return saved
		end
		return _G._agoraLang or "FR"
	end

	local function saveLang(code)
		_G._agoraLang = code
		pcall(function()
			writefile("agora_lang.txt", code)
		end)
	end

	local selectedLang = loadLang()
	_G._agoraLang = selectedLang

	-- Bouton Langue avec menu popup
	local langBtn = Instance.new("TextButton")
	langBtn.Size = UDim2.new(0.7, 0, 0, 34)
	langBtn.Position = UDim2.new(0.15, 0, 0, 275)
	langBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	langBtn.Text = "🌍 Langue"
	langBtn.Font = Enum.Font.GothamSemibold
	langBtn.TextSize = 14
	langBtn.TextColor3 = Color3.fromRGB(200, 210, 255)
	langBtn.BorderSizePixel = 0
	langBtn.AutoButtonColor = true
	langBtn.Parent = bgFrame
	createCorner(langBtn, 8)

	local langMenu = Instance.new("Frame")
	langMenu.Size = UDim2.new(0, 200, 0, 280)
	langMenu.Position = UDim2.new(0.5, -100, 0.5, -140)
	langMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	langMenu.BorderSizePixel = 0
	langMenu.Visible = false
	langMenu.ZIndex = 100
	langMenu.Parent = bgFrame
	createCorner(langMenu, 10)

	local langMenuTitle = Instance.new("TextLabel")
	langMenuTitle.Size = UDim2.new(1, -10, 0, 24)
	langMenuTitle.Position = UDim2.new(0, 10, 0, 8)
	langMenuTitle.BackgroundTransparency = 1
	langMenuTitle.Text = "Choisir la langue"
	langMenuTitle.Font = Enum.Font.GothamBold
	langMenuTitle.TextSize = 14
	langMenuTitle.TextColor3 = Color3.fromRGB(140, 160, 255)
	langMenuTitle.TextXAlignment = Enum.TextXAlignment.Center
	langMenuTitle.ZIndex = 101
	langMenuTitle.Parent = langMenu

	local langMenuScroll = Instance.new("ScrollingFrame")
	langMenuScroll.Size = UDim2.new(1, -10, 1, -40)
	langMenuScroll.Position = UDim2.new(0, 5, 0, 34)
	langMenuScroll.BackgroundTransparency = 1
	langMenuScroll.BorderSizePixel = 0
	langMenuScroll.ScrollBarThickness = 3
	langMenuScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	langMenuScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	langMenuScroll.ZIndex = 101
	langMenuScroll.Parent = langMenu

	local langMenuLayout = Instance.new("UIListLayout")
	langMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	langMenuLayout.Padding = UDim.new(0, 4)
	langMenuLayout.Parent = langMenuScroll

	-- Find current language name for display
	local currentLangName = "Français"
	for _, l in ipairs(languages) do
		if l.code == selectedLang then currentLangName = l.name break end
	end
	langBtn.Text = "🌍 " .. currentLangName

	for _, lang in ipairs(languages) do
		local lBtn = Instance.new("TextButton")
		lBtn.Size = UDim2.new(1, 0, 0, 30)
		lBtn.BackgroundColor3 = (lang.code == selectedLang) and Color3.fromRGB(55, 90, 180) or Color3.fromRGB(30, 30, 40)
		lBtn.Text = lang.flag .. "  " .. lang.name
		lBtn.Font = Enum.Font.Gotham
		lBtn.TextSize = 12
		lBtn.TextColor3 = Color3.new(1, 1, 1)
		lBtn.BorderSizePixel = 0
		lBtn.LayoutOrder = _
		lBtn.ZIndex = 101
		lBtn.Parent = langMenuScroll
		createCorner(lBtn, 6)

		lBtn.MouseButton1Click:Connect(function()
			selectedLang = lang.code
			saveLang(lang.code)
			langBtn.Text = "🌍 " .. lang.name
			if _G._agoraApplyLang then _G._agoraApplyLang(lang.code) end
			-- Update highlight
			for _, child in ipairs(langMenuScroll:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
				end
			end
			lBtn.BackgroundColor3 = Color3.fromRGB(55, 90, 180)
			playSound(6042053626, 0.2)
			task.wait(0.15)
			langMenu.Visible = false
		end)
	end

	-- Close button for lang menu
	local langCloseBtn = Instance.new("TextButton")
	langCloseBtn.Size = UDim2.new(0, 24, 0, 24)
	langCloseBtn.Position = UDim2.new(1, -28, 0, 4)
	langCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	langCloseBtn.Text = "✕"
	langCloseBtn.Font = Enum.Font.GothamBold
	langCloseBtn.TextSize = 12
	langCloseBtn.TextColor3 = Color3.new(1, 1, 1)
	langCloseBtn.BorderSizePixel = 0
	langCloseBtn.ZIndex = 102
	langCloseBtn.Parent = langMenu
	createCorner(langCloseBtn, 6)
	langCloseBtn.MouseButton1Click:Connect(function()
		langMenu.Visible = false
	end)

	langBtn.MouseButton1Click:Connect(function()
		langMenu.Visible = not langMenu.Visible
		playSound(6042053626, 0.2)
	end)

	-- === TRANSLATION SYSTEM ===
	local translations = {
		FR = { Home="Home", Joueurs="Joueurs", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", discord="Rejoindre le Discord", langue="Langue", nouveautes="Nouveautes", utilisateurs="Lancements", enLigne="En ligne", credits="Agora Universelle" },
		EN = { Home="Home", Joueurs="Players", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", discord="Join Discord", langue="Language", nouveautes="What's New", utilisateurs="Launches", enLigne="Online", credits="Agora Universelle" },
		ES = { Home="Inicio", Joueurs="Jugadores", Move="Mover", Extra="Extra", Remotes="Remotes", Registry="Registro", Local="Local", Protections="Proteccion", discord="Unirse a Discord", langue="Idioma", nouveautes="Novedades", utilisateurs="Lanzamientos", enLigne="En linea", credits="Agora Universelle" },
		DE = { Home="Start", Joueurs="Spieler", Move="Bewegen", Extra="Extra", Remotes="Remotes", Registry="Register", Local="Lokal", Protections="Schutz", discord="Discord beitreten", langue="Sprache", nouveautes="Neuigkeiten", utilisateurs="Starts", enLigne="Online", credits="Agora Universelle" },
		IT = { Home="Home", Joueurs="Giocatori", Move="Muovi", Extra="Extra", Remotes="Remotes", Registry="Registro", Local="Locale", Protections="Protezione", discord="Unisciti a Discord", langue="Lingua", nouveautes="Novita", utilisateurs="Avvii", enLigne="Online", credits="Agora Universelle" },
		PT = { Home="Inicio", Joueurs="Jogadores", Move="Mover", Extra="Extra", Remotes="Remotes", Registry="Registro", Local="Local", Protections="Protecao", discord="Entrar no Discord", langue="Idioma", nouveautes="Novidades", usuarios="Usuarios", enLigne="Online", credits="Agora Universelle" },
		RU = { Home="Главная", Joueurs="Игроки", Move="Движение", Extra="Доп", Remotes="Ремоуты", Registry="Реестр", Local="Локал", Protections="Защита", discord="Присоединиться к Discord", langue="Язык", nouveautes="Новое", utilisateurs="Запуски", enLigne="Онлайн", credits="Agora Universelle" },
		JP = { Home="ホーム", Joueurs="プレイヤー", Move="移動", Extra="エクストラ", Remotes="リモート", Registry="レジストリ", Local="ローカル", Protections="保護", discord="Discordに参加", langue="言語", nouveautes="新着", utilisateurs="起動", enLigne="オンライン", credits="Agora Universelle" },
		ZH = { Home="首页", Joueurs="玩家", Move="移动", Extra="额外", Remotes="远程", Registry="注册", Local="本地", Protections="保护", discord="加入Discord", langue="语言", nouveautes="新功能", utilisateurs="启动", enLigne="在线", credits="Agora Universelle" },
		KR = { Home="홈", Joueurs="플레이어", Move="이동", Extra="추가", Remotes="리모트", Registry="레지스트리", Local="로컬", Protections="보호", discord="Discord 가입", langue="언어", nouveautes="새소식", utilisateurs="실행", enLigne="온라인", credits="Agora Universelle" },
		AR = { Home="الرئيسية", Joueurs="اللاعبون", Move="تحريك", Extra="إضافي", Remotes="ريموت", Registry="السجل", Local="محلي", Protections="حماية", discord="انضم إلى Discord", langue="اللغة", nouveautes="جديد", utilisateurs="إطلاق", enLigne="متصل", credits="Agora Universelle" },
		NL = { Home="Home", Joueurs="Spelers", Move="Bewegen", Extra="Extra", Remotes="Remotes", Registry="Register", Local="Lokaal", Protections="Bescherming", discord="Join Discord", langue="Taal", nouveautes="Nieuws", utilisateurs="Starts", enLigne="Online", credits="Agora Universelle" },
		PL = { Home="Home", Joueurs="Gracze", Move="Ruch", Extra="Extra", Remotes="Remotes", Registry="Rejestr", Local="Lokal", Protections="Ochrona", discord="Dolacz do Discord", langue="Jezyk", nouveautes="Nowosci", utilisateurs="Uruchomienia", enLigne="Online", credits="Agora Universelle" },
		TR = { Home="Ana Sayfa", Joueurs="Oyuncular", Move="Hareket", Extra="Ekstra", Remotes="Remoteler", Registry="Kayit", Local="Yerel", Protections="Koruma", discord="Discord'a Katil", langue="Dil", nouveautes="Yenilikler", utilisateurs="Baslatma", enLigne="Cevrimici", credits="Agora Universelle" },
	}

	local function applyLanguage(langCode)
		local t = translations[langCode] or translations.FR
		pcall(function()
			-- Translate tab buttons
			for name, btn in pairs(tabButtons) do
				if t[name] and btn then btn.Text = t[name] end
			end
			-- Translate Home elements
			if t.discord and discordBtn then discordBtn.Text = t.discord end
			if t.langue and langBtn then langBtn.Text = "🌍 " .. (t.langue or "Langue") end
			if t.nouveautes and changelogTitle then changelogTitle.Text = t.nouveautes end
			if t.utilisateurs and totalLabel then totalLabel.Text = (t.utilisateurs or "Lancements") .. ": " .. tostring((_G._agoraStats and _G._agoraStats.totalLaunches) or 0) end
			if t.enLigne and onlineLabel then onlineLabel.Text = (t.enLigne or "En ligne") .. ": " .. tostring((_G._agoraStats and _G._agoraStats.onlineUsers) or 0) end
			if t.credits and credits then credits.Text = t.credits end
		end)
	end

	-- Apply language on load
	applyLanguage(selectedLang)

	-- Re-apply when language changes

	-- Since the lang menu buttons are created in a loop, we expose applyLanguage via _G
	_G._agoraApplyLang = applyLanguage

	-- === COMPTEURS LIVE (lancements + utilisateurs en ligne) ===
	_G._agoraStats = { totalLaunches = 0, onlineUsers = 0 }

	local statsBox = Instance.new("Frame")
	statsBox.Size = UDim2.new(1, -30, 0, 50)
	statsBox.Position = UDim2.new(0, 15, 0, 340)
	statsBox.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	statsBox.BorderSizePixel = 0
	statsBox.Parent = bgFrame
	createCorner(statsBox, 8)

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statsLayout.Padding = UDim.new(0.05, 0)
	statsLayout.Parent = statsBox

	local totalLabel = Instance.new("TextLabel")
	totalLabel.Size = UDim2.new(0, 160, 0, 36)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Font = Enum.Font.GothamSemibold
	totalLabel.TextSize = 13
	totalLabel.TextColor3 = Color3.fromRGB(160, 180, 255)
	totalLabel.Text = "Lancements: 0"
	totalLabel.Parent = statsBox

	local onlineLabel = Instance.new("TextLabel")
	onlineLabel.Size = UDim2.new(0, 160, 0, 36)
	onlineLabel.BackgroundTransparency = 1
	onlineLabel.Font = Enum.Font.GothamSemibold
	onlineLabel.TextSize = 13
	onlineLabel.TextColor3 = Color3.fromRGB(100, 220, 120)
	onlineLabel.Text = "En ligne: 0"
	onlineLabel.Parent = statsBox

	-- Tracker: envoyer le lancement + refresh les stats (1 seul appel HTTP)
	task.spawn(function()
		local function updateStats()
			task.spawn(function()
				local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?action=launch&user=" .. HttpService:UrlEncode(LocalPlayer.Name) .. "&uid=" .. tostring(LocalPlayer.UserId)
				local resp = httpGet(url)
				if resp and resp ~= "" then
					local parsed = nil
					pcall(function() parsed = HttpService:JSONDecode(resp) end)
					if parsed then
						_G._agoraStats.totalLaunches = tonumber(parsed.total_launches) or 0
						_G._agoraStats.onlineUsers = tonumber(parsed.online_users) or 0
						totalLabel.Text = "Lancements: " .. tostring(_G._agoraStats.totalLaunches)
						onlineLabel.Text = "En ligne: " .. tostring(_G._agoraStats.onlineUsers)
					end
				end
			end)
		end

		-- Send launch tracking (inc + get stats in one call)
		updateStats()

		-- Refresh stats every 60 seconds (less HTTP calls = less lag)
		while homePage and homePage.Parent do
			task.wait(60)
			updateStats()
		end
	end)

	-- Credits
	local credits = Instance.new("TextLabel")
	credits.Size = UDim2.new(1, -20, 0, 16)
	credits.Position = UDim2.new(0, 10, 0, 400)
	credits.BackgroundTransparency = 1
	credits.Text = "Agora Universelle"
	credits.Font = Enum.Font.Gotham
	credits.TextSize = 10
	credits.TextColor3 = Color3.fromRGB(80, 80, 100)
	credits.Parent = bgFrame
end)()

local playersPage = createTab("Joueurs")
local movePage = createTab("Move")
local extraPage = createTab("Extra")
local remotesPage = createTab("Remotes")
local registryPage = createTab("Registry")
local localPage = createTab("Local")
local protectionsPage = createTab("Protections")

-- ============= REGISTRY SEARCH + AUTOCOMPLETE =============
-- WRAP dans local function + appel pour isoler les locals
local function _initRegistrySearch()
	local registrySearchBox = Instance.new("TextBox")
	registrySearchBox.Size = UDim2.new(1, -10, 0, 28)
	registrySearchBox.Position = UDim2.new(0, 5, 0, 5)
	registrySearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	registrySearchBox.BackgroundTransparency = 0.2
	registrySearchBox.TextColor3 = Color3.fromRGB(230, 230, 230)
	registrySearchBox.PlaceholderText = "Rechercher un pseudo Roblox..."
	registrySearchBox.Text = ""
	registrySearchBox.Font = Enum.Font.Gotham
	registrySearchBox.TextSize = 12
	registrySearchBox.TextXAlignment = Enum.TextXAlignment.Center
	registrySearchBox.ClearTextOnFocus = false
	registrySearchBox.Parent = registryPage
	createCorner(registrySearchBox, 8)
	createStroke(registrySearchBox, Color3.fromRGB(80, 80, 100), 1)

	-- Bouton X pour effacer la saisie (à droite de la searchBox)
	local registryClearBtn = Instance.new("TextButton")
	registryClearBtn.Size = UDim2.new(0, 22, 0, 22)
	registryClearBtn.Position = UDim2.new(1, -28, 0, 8)
	registryClearBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	registryClearBtn.Text = "X"
	registryClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	registryClearBtn.Font = Enum.Font.GothamBold
	registryClearBtn.TextSize = 11
	registryClearBtn.BorderSizePixel = 0
	registryClearBtn.Visible = false -- caché quand la searchBox est vide
	registryClearBtn.ZIndex = registrySearchBox.ZIndex + 1
	registryClearBtn.AutoButtonColor = true
	registryClearBtn.Parent = registryPage
	createCorner(registryClearBtn, 11) -- rond
	registryClearBtn.MouseButton1Click:Connect(function()
		registrySearchBox.Text = ""
		registryClearBtn.Visible = false
		suggestionsFrame.Visible = false
	end)
	-- Afficher/cacher le X selon le contenu
	registrySearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		registryClearBtn.Visible = (registrySearchBox.Text ~= "")
	end)

	-- Frame pour les 3 suggestions (sous la search box)
	local suggestionsFrame = Instance.new("Frame")
	suggestionsFrame.Size = UDim2.new(1, -10, 0, 0) -- hauteur auto
	suggestionsFrame.AutomaticSize = Enum.AutomaticSize.Y
	suggestionsFrame.Position = UDim2.new(0, 5, 0, 38)
	suggestionsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	suggestionsFrame.BorderSizePixel = 0
	suggestionsFrame.Visible = false -- caché par défaut
	suggestionsFrame.Parent = registryPage
	createCorner(suggestionsFrame, 6)
	createStroke(suggestionsFrame, Color3.fromRGB(70, 70, 100), 1)

	local suggestionsLayout = Instance.new("UIListLayout")
	suggestionsLayout.Padding = UDim.new(0, 2)
	suggestionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	suggestionsLayout.Parent = suggestionsFrame

	local suggestionsPadding = Instance.new("UIPadding")
	suggestionsPadding.PaddingTop = UDim.new(0, 4)
	suggestionsPadding.PaddingBottom = UDim.new(0, 4)
	suggestionsPadding.PaddingLeft = UDim.new(0, 4)
	suggestionsPadding.PaddingRight = UDim.new(0, 4)
	suggestionsPadding.Parent = suggestionsFrame

	-- Liste de pseudos Roblox populaires (pour aider la recherche fuzzy)
	local popularNames = {
		"Builderman", "Roblox", "Stickmasterluke", "Shedletsky", "Telamon",
		"Gigaplex", "FaZe_Sway", "DenisDaily", "KreekCraft", "Flamingo",
		"Peppa Pig", "Pinky", "Tanqr", "The Bacon Hair", "Alex Banzi",
		"Benjamin", "Bloxy News", "Brittany", "Caleb", "Chip",
		"Connor", "Daisy", "Dakota", "Emma", "Ethan",
		"Faith", "Gabriel", "Grace", "Henry", "Ian",
		"Isaac", "Jack", "Jacob", "James", "Jasmine",
		"Jennifer", "Jessica", "John", "Joshua", "Julia",
		"Karen", "Kate", "Kevin", "Kyle", "Laura",
		"Liam", "Lily", "Logan", "Lucas", "Lucy",
		"Mason", "Megan", "Mia", "Nathan", "Noah",
		"Olivia", "Owen", "Patrick", "Rachel", "Riley",
		"Samuel", "Sara", "Savannah", "Sean", "Sophie",
		"Stephen", "Taylor", "Thomas", "Tyler", "Victoria",
		"William", "Zoe", "Xx_Shadow_xX", "Dark_Mage", "ProGamer123",
		-- Pseudos spécifiques (connus / populaires)
		"Vzlom_Emk", "MilanAC", "Eme_Giroux", "RobloxDev", "TestAccount",
	}

	-- Helper : calcule un score de match entre query et name
	-- Retourne nil si pas de match, sinon un score (plus haut = meilleur)
	local function fuzzyScore(query, name)
		if not query or query == "" then return nil end
		query = string.lower(query)
		name = string.lower(name)

		-- Préfixe exact = meilleur score
		if string.sub(name, 1, #query) == query then
			return 1000 - #name -- plus court = mieux
		end

		-- Sous-string match = bon score
		local sPos = string.find(name, query, 1, true)
		if sPos then
			return 500 - sPos
		end

		-- Match flou : tous les caractères de query présents dans name dans l'ordre
		local qi = 1
		local lastPos = 0
		local matches = 0
		for i = 1, #name do
			if qi > #query then break end
			if string.sub(name, i, i) == string.sub(query, qi, qi) then
				matches = matches + 1
				qi = qi + 1
				lastPos = i
			end
		end
		if matches == #query then
			return 100 - lastPos -- sous-séquence trouve, mais plus loin dans le nom
		end

		return nil -- pas de match
	end

	-- Met à jour la liste de suggestions en fonction de queryText
	local function updateSuggestions(queryText)
		-- Nettoyer les anciennes suggestions
		for _, child in ipairs(suggestionsFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		if not queryText or queryText == "" or #queryText < 1 then
			suggestionsFrame.Visible = false
			return
		end

		-- Collecter tous les candidats (connectés + populaires)
		local candidates = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			table.insert(candidates, plr.Name)
		end
		for _, name in ipairs(popularNames) do
			table.insert(candidates, name)
		end

		-- Calculer les scores et trier
		local scored = {}
		for _, name in ipairs(candidates) do
			local score = fuzzyScore(queryText, name)
			if score then
				table.insert(scored, {name = name, score = score})
			end
		end
		table.sort(scored, function(a, b) return a.score > b.score end)

		-- Prendre top 3
		local top3 = {}
		for i = 1, math.min(3, #scored) do
			table.insert(top3, scored[i].name)
		end

		if #top3 == 0 then
			suggestionsFrame.Visible = false
			return
		end

		-- Créer les 3 boutons de suggestion
		-- Pour les connectés : "NomComplet (ID: 12345678)"
		-- Pour les hardcodés : "NomComplet" (pas d'ID connu)
		for i, name in ipairs(top3) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 22)
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			btn.BorderSizePixel = 0
			btn.Text = "  " .. i .. ". " .. name
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 11
			btn.TextColor3 = Color3.fromRGB(220, 220, 240)
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.LayoutOrder = i
			btn.Parent = suggestionsFrame
			createCorner(btn, 4)

			-- Cliquer = remplir la search box
			btn.MouseButton1Click:Connect(function()
				registrySearchBox.Text = name
				registrySearchBox:CaptureFocus()
				updateSuggestions(name)
			end)

			-- Hover effects
			btn.MouseEnter:Connect(function()
				btn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
			end)
			btn.MouseLeave:Connect(function()
				btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			end)
		end

		-- Label d'aide : ID du joueur quand on tape un nom connu
		local helpLabel = Instance.new("TextLabel")
		helpLabel.Name = "HelpLabel"
		helpLabel.Size = UDim2.new(1, -10, 0, 16)
		helpLabel.Position = UDim2.new(0, 5, 0, 0)
		helpLabel.BackgroundTransparency = 1
		helpLabel.Text = ""
		helpLabel.Font = Enum.Font.Gotham
		helpLabel.TextSize = 9
		helpLabel.TextColor3 = Color3.fromRGB(120, 180, 140)
		helpLabel.TextXAlignment = Enum.TextXAlignment.Left
		helpLabel.LayoutOrder = 100
		helpLabel.Parent = suggestionsFrame

		suggestionsFrame.Visible = true
	end

	-- Listener sur changement de texte
	registrySearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		updateSuggestions(registrySearchBox.Text)
	end)

	-- Enter = lancer la recherche Roblox officielle (relie à runRegistrySearch)
	registrySearchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			pcall(function() runRegistrySearch(registrySearchBox.Text) end)
		end
		task.delay(3, function()
			if not registrySearchBox:IsFocused() then
				suggestionsFrame.Visible = false
			end
		end)
	end)

	-- Cliquer sur le frame parent (registryPage) en dehors de la search box
	-- cache les suggestions (pour pas qu'elles restent flottantes)
end
_initRegistrySearch()


	-- Call section builders
	_G.AgoraBuild_REGISTRY_SCROLL()
	_G.AgoraBuild_JOUEURS()
	_G.AgoraBuild_ESP()
	_G.AgoraBuild_ANIMATIONS()
	_G.AgoraBuild_MOVE()
	_G.AgoraBuild_AUTO_CLICKER()
	_G.AgoraBuild_EXTRA()
	_G.AgoraBuild_AIMBOT()
	_G.AgoraBuild_PROTECTIONS()
	_G.AgoraBuild_REGISTRE_DES_COMPTES_ROBLOX()
	_G.AgoraBuild_CHAT_COMMANDS()
	_G.AgoraBuild_CREDITS()
end


-- Remove loading screen
pcall(function() if loadingGui then loadingGui:Destroy() end end)
