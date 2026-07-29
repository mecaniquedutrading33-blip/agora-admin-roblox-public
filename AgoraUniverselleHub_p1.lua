-- Agora Hub [UNIVERSELLE] - Panel Roblox universel
-- LocalScript dans StarterPlayerScripts ou executeur

_G.SETTINGS = {
	SpiderSpeed = 16,
	SpiderHoverDistance = 2.6,
	SpiderNetworkCompensation = 0.8,
	SpiderJumpPower = 60,
	SpiderJumpCooldown = 0.5,
	SpiderTransitionSpeed = 15
}

-- SAFEGUARD EXECUTEUR: certains loadstring ne passent pas 'game' en global
-- On recupere game via getfenv, shared, ou le premier argument de loadstring
_G._game = nil
if game then _game = game end
if not _game then
	_G.ok, envGame = pcall(function() return getfenv().game end)
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

-- === LOADING SCREEN ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

-- Create loading screen
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "AgoraLoading"
loadingGui.ResetOnSpawn = false
loadingGui.Parent = (game:GetService("CoreGui")) or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local loadingBg = Instance.new("Frame")
loadingBg.Size = UDim2.new(1, 0, 1, 0)
loadingBg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
loadingBg.BackgroundTransparency = 1
loadingBg.BorderSizePixel = 0
loadingBg.Parent = loadingGui

local loadingLogo = Instance.new("TextLabel")
loadingLogo.Size = UDim2.new(0, 300, 0, 60)
loadingLogo.Position = UDim2.new(0.5, -150, 0.4, -30)
loadingLogo.BackgroundTransparency = 1
loadingLogo.Text = "AGORA"
loadingLogo.Font = Enum.Font.GothamBold
loadingLogo.TextSize = 48
loadingLogo.TextColor3 = Color3.fromRGB(60, 180, 255)
loadingLogo.TextTransparency = 1
loadingLogo.TextXAlignment = Enum.TextXAlignment.Center
loadingLogo.Parent = loadingBg

local loadingSub = Instance.new("TextLabel")
loadingSub.Size = UDim2.new(0, 300, 0, 30)
loadingSub.Position = UDim2.new(0.5, -150, 0.4, 35)
loadingSub.BackgroundTransparency = 1
loadingSub.Text = "UNIVERSELLE HUB"
loadingSub.Font = Enum.Font.Gotham
loadingSub.TextSize = 18
loadingSub.TextColor3 = Color3.fromRGB(120, 120, 140)
loadingSub.TextTransparency = 1
loadingSub.TextXAlignment = Enum.TextXAlignment.Center
loadingSub.Parent = loadingBg

local loadingBarBg = Instance.new("Frame")
loadingBarBg.Size = UDim2.new(0, 250, 0, 6)
loadingBarBg.Position = UDim2.new(0.5, -125, 0.5, -3)
loadingBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
loadingBarBg.BackgroundTransparency = 1
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 3)
barCorner.Parent = loadingBarBg
loadingBarBg.Parent = loadingBg

local loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.new(0, 0, 1, 0)
loadingBar.BackgroundColor3 = Color3.fromRGB(60, 180, 255)
loadingBar.BackgroundTransparency = 1
loadingBar.BorderSizePixel = 0
local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 3)
barFillCorner.Parent = loadingBar
loadingBar.Parent = loadingBarBg

local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(0, 300, 0, 20)
loadingText.Position = UDim2.new(0.5, -150, 0.5, 15)
loadingText.BackgroundTransparency = 1
loadingText.Text = "Chargement..."
loadingText.Font = Enum.Font.Gotham
loadingText.TextSize = 13
loadingText.TextColor3 = Color3.fromRGB(100, 100, 120)
loadingText.TextTransparency = 1
loadingText.TextXAlignment = Enum.TextXAlignment.Center
loadingText.Parent = loadingBg

-- Loading dots animation
local dots = Instance.new("TextLabel")
dots.Size = UDim2.new(0, 300, 0, 20)
dots.Text = ""
dots.Font = Enum.Font.Gotham
dots.TextSize = 20
dots.TextColor3 = Color3.fromRGB(60, 180, 255)
dots.TextTransparency = 1
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
_G.updateLoad = updateLoad
	if loadingText then
		loadingText.Text = msg or "Chargement..."
	end
	-- Petit wait pour etaler la charge
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

-- Helper multi-fallback pour verifier si un joueur peut chatter (client-only, pas d'acces serveur)
local function _resolveCanChat(target, callback)
	task.spawn(function()
		local result, src = nil, "non verifiable"
		local uid = (typeof(target) == "Instance" and target:IsA("Player") and target.UserId) or tonumber(target)

		-- 1) VRAIE reponse serveur : RemoteFunction CanUsersChatAsync
		if uid and LocalPlayer then
			local rf = ReplicatedStorage:FindFirstChild("AgoraCanChatRF")
			if rf and rf:IsA("RemoteFunction") then
				local ok, r = pcall(function() return rf:InvokeServer(uid) end)
				if ok and r ~= nil then
					result, src = r, "CanTalkWithMe"
				end
			end
		end

		-- 2) API client native (moins fiable, indique juste "a le chat active")
		if result == nil and uid then
			local ok, r = pcall(function() return TextChatService:CanUserChatAsync(uid) end)
			if ok then result, src = r, "ChatEnabled" end
		end

		-- 3) Proprietes legacy
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
		-- 5) On a VU le joueur parler dans le chat public -> il peut nous parler
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
_G._resolveCanChat = _resolveCanChat

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

-- Wrapper de son multi-executeur (Solara, etc.) - pcall silencieux
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
_G.playSound = playSound
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
_G.httpGet = httpGet

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
_G.httpPost = httpPost
	return nil
end

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Memoire client : sauvegarde persistante entre reouvertures du panel
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
_G.updateCharacter = updateCharacter
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
_G.getDeviceType = getDeviceType
end

local function createCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end
_G.createCorner = createCorner

local function createStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(60, 60, 60)
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end
_G.createStroke = createStroke

local function tween(obj, props, duration)
	if not obj or not obj.Parent then return end
	pcall(function()
		TweenService:Create(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end)
end
_G.tween = tween

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MilanEmerickPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Backdrop retire : il recouvrait tout l'ecran en noir semi-transparent.

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 460, 0, 520)
mainFrame.Position = UDim2.new(0.5, -230, 0.5, -260)
mainFrame.Visible = false  -- Sera revele apres l'intro
-- S'assure que le panel reste visible et ne se fait pas pousser par le chat au demarrage
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
mainFrame.BackgroundTransparency = 1  -- Cache le panel pendant l'intro (evite flash gris)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 1
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(120, 120, 150), 1.2)

-- ===== INTRO CINEMA : "Agora Hub" puis TAMPON "UNIVERSELLE" BOUM =====
-- Backdrop full screen noir pour masquer le panel pendant l'intro
_=(function()
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

	-- Vignette doree subtile en arriere-plan
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

	-- Titre "Agora Hub" - apparait avec un fade in
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

	-- Tag "UNIVERSELLE" - cachee au debut, scale 0
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

	-- === SEQUENCE CINEMA ===
	task.spawn(function()
		local ok, err = pcall(function()
			-- Etape 1 : fade in du backdrop depuis noir + whoosh grave
			playSound(4590662766, 0.5)
			backdrop.BackgroundTransparency = 0

			-- Etape 2 : titre "Agora Hub" fade in (0.5s) + ding doux
			task.wait(0.15)
			_tween(title, {TextTransparency = 0}, 0.3)
			_tween(subtitle, {TextTransparency = 0}, 0.3)
			playSound(6042053626, 0.2)

			-- Etape 3 : pause courte pour lire le titre
			task.wait(0.4)

			-- Etape 4 : BOUM - flash blanc brutal + tag scale 0->1.3->1 + boom impact fort
			flash.BackgroundTransparency = 0
			uniTag.TextTransparency = 0
			stampTop.BackgroundTransparency = 0
			stampBot.BackgroundTransparency = 0

			-- Scale : commence a 0, monte a 1.3 puis 1 (impact elastique)
			uniTag.Size = UDim2.new(0, 0, 0, 0)
			uniTag.Position = UDim2.new(0.5, 0, 0.5, 0)
			uniTag.AnchorPoint = Vector2.new(0.5, 0.5)
			uniTag.Rotation = 4  -- rotation d'entree (corrigee a -8 a la fin)
			playSound(4590662766, 0.85)  -- boom impact
			_tween(uniTag, {Size = UDim2.new(1.2, 0, 0, 140), Rotation = -10}, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			_tween(flash, {BackgroundTransparency = 1}, 0.25)
			task.wait(0.12)
			-- Stabilise a la taille finale avec la bonne rotation
			_tween(uniTag, {Size = UDim2.new(1.1, 0, 0, 130), Rotation = -8}, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			-- Etape 5 : le tag reste affiche brievement
			task.wait(0.5)

			-- Etape 6 : fade out de tout
			_tween(title, {TextTransparency = 1}, 0.3)
			_tween(subtitle, {TextTransparency = 1}, 0.3)
			_tween(uniTag, {TextTransparency = 1, Rotation = -12}, 0.4)
			_tween(stampTop, {BackgroundTransparency = 1}, 0.3)
			_tween(stampBot, {BackgroundTransparency = 1}, 0.3)
			_tween(vignette, {ImageTransparency = 1}, 0.2)
			task.wait(0.15)
			_tween(backdrop, {BackgroundTransparency = 1}, 0.25)
			task.wait(0.2)
		end)

		if not ok then
			warn("[MILAN] Intro crash: " .. tostring(err))
		end

		-- Cleanup + revelation du panel
		pcall(function() if bootGui and bootGui.Parent then bootGui:Destroy() end end)
		pcall(function()
			_mainFrame.Visible = true
			_mainFrame.BackgroundTransparency = 0.35
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

-- Logo a gauche du titre + badge "UNIVERSELLE" penche (mini) a droite du titre
_=(function()
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

	-- Badge "UNIVERSELLE" petit et penche, a droite du titre
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
_G.addGlow = addGlow

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
minimizeBtn.Text = "-"
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
_G.makeIcon = makeIcon

makeIcon(closeBtn, "?")

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
_G.createButton = createButton

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
_G.switchTab = switchTab
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
_G.createTab = createTab

-- ============= Home TAB - IIFE pour 0 top-level local =============
_=(function()
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
	versionLabel.Text = "v39.42"
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
		"v39.42 -- Server Authority bypass: fly adaptatif (Anchored+CFrame quand SA actif), noclip SA, fix diverses",
		"v39.41 - Fly: perso s'incline haut/bas selon ou on regarde (pitch camera + mouvement)",
		"v39.37 - Fix noclip: personnage stale apres respawn, HRP collision restore, 41 animations",
		"v39.36 - 41 animations: danses, gymnastique, fun, emotes classiques + 10 custom CFrame",
		"v39.35 - Emotes: 10 mouvements custom (roulade buche, epilepsie, etc), X circulaire, stop visible",
		"v39.34 - Emotes deplace vers Extra, X circulaire, stop toujours visible",
		"v39.33 - Server Authority: detection + bouton desactiver dans Extra",
		"v39.32 - Emotes refait: 36 animations folles, 100% visibles par tous",
		"  Categories: Danses, Combat (boxe/kick), Acrobaties (backflip), Fun",
		"  Plus rien en local - tout en animations Roblox (replication auto)",
		"v39.31 - Ajout systeme emotes (fenetre draggable + 16 emotes)",
		"  Emotes: saluer, danser, rire, rouler par terre, rebondir, etc.",
		"  Fenetre draggable avec bouton X + bouton stop emote",
		"v39.30 - FIX compteurs live (lancements + en ligne)",
		"  Edge Function: action=launch retourne maintenant total_launches + online_users",
		"  Table agora_hub_launches creee dans Supabase",
		"  Fix: _G.httpGet deplace hors de la fonction (etait inside)",
	"v39.21 - FIX CRITIQUE: safety net p1 + joinOrIndi local + buildRegistrySection export",
		"  p1: 8 _G exports misplaced INSIDE functions (createSwitch, createSlider, startFly, stopFly, computePathTo, reparentChildrenToLocalScroll, _initRegistrySearch, jumpState bridge)",
		"  p2: local joinOrIndi (nil dans sandbox loadstring)",
		"  p2: _G.buildRegistrySection deplace hors de joinOrIndi (bug misplaced)",
		"  p2: error logging sur runtime crash",
		"v39.19 - RESTAURATION header bar (topBar 38px)",
		"  Le commit precedent avait mis topBar a 0px -> header invisible",
		"  Restaure: topBar 38px + tabBar Y=44 + logo + titre + boutons",
		"v39.18 - FIX Part 2: 18 fonctions utilitaires restaurees",
		"  createSwitch/createButton/createCorner/tween/etc nil dans Solara",
	"- Barre grise supprimee, onglets repositionnes",
		"v38.97 - Tri remotes + traduction langue",
		"+ Remotes interceptes tries en haut de la liste",
		"+ Auto-refresh remotes toutes les 5s",
		"+ Traduction 14 langues",
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
		{code = "FR", flag = "??", name = "Francais"},
		{code = "EN", flag = "??", name = "English"},
		{code = "ES", flag = "??", name = "Espa?ol"},
		{code = "DE", flag = "??", name = "Deutsch"},
		{code = "IT", flag = "??", name = "Italiano"},
		{code = "PT", flag = "??", name = "Portugues"},
		{code = "RU", flag = "??", name = "???????"},
		{code = "JP", flag = "??", name = "???"},
		{code = "ZH", flag = "??", name = "??"},
		{code = "KR", flag = "??", name = "???"},
		{code = "AR", flag = "??", name = "???????"},
		{code = "NL", flag = "??", name = "Nederlands"},
		{code = "PL", flag = "??", name = "Polski"},
		{code = "TR", flag = "??", name = "Turkce"},
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
	langBtn.Text = "? Langue"
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
	local currentLangName = "Francais"
	for _, l in ipairs(languages) do
		if l.code == selectedLang then currentLangName = l.name break end
	end
	langBtn.Text = "? " .. currentLangName

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
			langBtn.Text = "? " .. lang.name
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
	langCloseBtn.Text = "?"
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
		RU = { Home="???????", Joueurs="??????", Move="????????", Extra="???", Remotes="???????", Registry="??????", Local="?????", Protections="??????", discord="?????????????? ? Discord", langue="????", nouveautes="?????", utilisateurs="???????", enLigne="??????", credits="Agora Universelle" },
		JP = { Home="???", Joueurs="?????", Move="??", Extra="?????", Remotes="????", Registry="?????", Local="????", Protections="??", discord="Discord???", langue="??", nouveautes="??", utilisateurs="??", enLigne="?????", credits="Agora Universelle" },
		ZH = { Home="??", Joueurs="??", Move="??", Extra="??", Remotes="??", Registry="??", Local="??", Protections="??", discord="??Discord", langue="??", nouveautes="???", utilisateurs="??", enLigne="??", credits="Agora Universelle" },
		KR = { Home="?", Joueurs="????", Move="??", Extra="??", Remotes="???", Registry="?????", Local="??", Protections="??", discord="Discord ??", langue="??", nouveautes="???", utilisateurs="??", enLigne="???", credits="Agora Universelle" },
		AR = { Home="????????", Joueurs="????????", Move="?????", Extra="?????", Remotes="?????", Registry="?????", Local="????", Protections="?????", discord="???? ??? Discord", langue="?????", nouveautes="????", utilisateurs="?????", enLigne="????", credits="Agora Universelle" },
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
			if t.langue and langBtn then langBtn.Text = "? " .. (t.langue or "Langue") end
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

	-- Bouton X pour effacer la saisie (a droite de la searchBox)
	local registryClearBtn = Instance.new("TextButton")
	registryClearBtn.Size = UDim2.new(0, 22, 0, 22)
	registryClearBtn.Position = UDim2.new(1, -28, 0, 8)
	registryClearBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	registryClearBtn.Text = "X"
	registryClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	registryClearBtn.Font = Enum.Font.GothamBold
	registryClearBtn.TextSize = 11
	registryClearBtn.BorderSizePixel = 0
	registryClearBtn.Visible = false -- cache quand la searchBox est vide
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
	suggestionsFrame.Visible = false -- cache par defaut
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
		-- Pseudos specifiques (connus / populaires)
		"Vzlom_Emk", "MilanAC", "Eme_Giroux", "RobloxDev", "TestAccount",
	}

	-- Helper : calcule un score de match entre query et name
	-- Retourne nil si pas de match, sinon un score (plus haut = meilleur)
	local function fuzzyScore(query, name)
		if not query or query == "" then return nil end
		query = string.lower(query)
		name = string.lower(name)

		-- Prefixe exact = meilleur score
		if string.sub(name, 1, #query) == query then
			return 1000 - #name -- plus court = mieux
		end

		-- Sous-string match = bon score
		local sPos = string.find(name, query, 1, true)
		if sPos then
			return 500 - sPos
		end

		-- Match flou : tous les caracteres de query presents dans name dans l'ordre
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
			return 100 - lastPos -- sous-sequence trouve, mais plus loin dans le nom
		end

		return nil -- pas de match
	end

	-- Met a jour la liste de suggestions en fonction de queryText
	local function updateSuggestions(queryText)
		-- Nettoyer les anciennes suggestions
		for _, child in ipairs(suggestionsFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		if not queryText or queryText == "" or #queryText < 1 then
			suggestionsFrame.Visible = false
			return
		end

		-- Collecter tous les candidats (connectes + populaires)
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

		-- Creer les 3 boutons de suggestion
		-- Pour les connectes : "NomComplet (ID: 12345678)"
		-- Pour les hardcodes : "NomComplet" (pas d'ID connu)
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

	-- Enter = lancer la recherche Roblox officielle (relie a runRegistrySearch)
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

_G._initRegistrySearch = _initRegistrySearch
_initRegistrySearch()

-- ============= REGISTRY SCROLL =============
-- registryScroll commence juste apres la search box + un peu de gap pour les suggestions
local registryScroll = Instance.new("ScrollingFrame")
registryScroll.Size = UDim2.new(1, 0, 1, -40) -- 40px = search box (33) + gap (7)
registryScroll.Position = UDim2.new(0, 0, 0, 40)
registryScroll.BackgroundTransparency = 1
registryScroll.ScrollBarThickness = 4
registryScroll.BorderSizePixel = 0
registryScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
registryScroll.CanvasSize = UDim2.new(0, 0, 0, 2000)
registryScroll.Parent = registryPage
createCorner(registryScroll, 4)

local registryLayout = Instance.new("UIListLayout")
registryLayout.Padding = UDim.new(0, 6)
registryLayout.SortOrder = Enum.SortOrder.LayoutOrder
registryLayout.Parent = registryScroll

local registryPadding = Instance.new("UIPadding")
registryPadding.PaddingTop = UDim.new(0, 4)
registryPadding.PaddingBottom = UDim.new(0, 4)
registryPadding.PaddingLeft = UDim.new(0, 6)
registryPadding.PaddingRight = UDim.new(0, 6)
registryPadding.Parent = registryScroll

local localScroll = Instance.new("ScrollingFrame")
localScroll.Size = UDim2.new(1, 0, 1, 0)
localScroll.BackgroundTransparency = 1
localScroll.ScrollBarThickness = 4
localScroll.BorderSizePixel = 0
localScroll.CanvasSize = UDim2.new(0, 0, 0, 900)
localScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
localScroll.Parent = localPage

local localLayout = Instance.new("UIListLayout")
localLayout.Padding = UDim.new(0, 6)
localLayout.SortOrder = Enum.SortOrder.LayoutOrder
localLayout.Parent = localScroll

local protectionsScroll = Instance.new("ScrollingFrame")
protectionsScroll.Name = "ProtectionsScroll"
protectionsScroll.Size = UDim2.new(1, 0, 1, 0)
protectionsScroll.Position = UDim2.new(0, 0, 0, 0)
protectionsScroll.BackgroundTransparency = 1
protectionsScroll.ScrollBarThickness = 4
protectionsScroll.BorderSizePixel = 0
protectionsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
protectionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
protectionsScroll.Parent = protectionsPage

local protectionsLayout = Instance.new("UIListLayout")
protectionsLayout.Padding = UDim.new(0, 6)
protectionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
protectionsLayout.Parent = protectionsScroll

-- FIX: CanvasSize handler manquant + force remeasure apres 1er render
protectionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	protectionsScroll.CanvasSize = UDim2.new(0, 0, 0, protectionsLayout.AbsoluteContentSize.Y + 10)
end)
task.defer(function()
	protectionsScroll.CanvasSize = UDim2.new(0, 0, 0, protectionsLayout.AbsoluteContentSize.Y + 10)
end)

local function reparentChildrenToLocalScroll()
	for _, child in ipairs(localPage:GetChildren()) do
		if child ~= localScroll then
			child.Parent = localScroll
			if child:IsA("GuiObject") and child.LayoutOrder == 0 then
				child.LayoutOrder = (#localScroll:GetChildren() - 1)
			end
		end
	end
end

_G.reparentChildrenToLocalScroll = reparentChildrenToLocalScroll

local dragging, dragStart, startPos

topBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		local absSize = mainFrame.AbsoluteSize
		local newX = math.clamp(startPos.X.Offset + delta.X, 0, screenGui.AbsoluteSize.X - absSize.X)
		local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, screenGui.AbsoluteSize.Y - absSize.Y)
		mainFrame.Position = UDim2.new(0, newX, 0, newY)
	end
end)

-- Drag manuel du mini panel autoclick (clickControl) - declenche par controlHeader
local ccInputConn = UserInputService.InputChanged:Connect(function(input)
	if ccDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - ccDragStart
		local absSize = clickControl.AbsoluteSize
		local newX = math.clamp(ccStartPos.X.Offset + delta.X, 0, screenGui.AbsoluteSize.X - absSize.X)
		local newY = math.clamp(ccStartPos.Y.Offset + delta.Y, 0, screenGui.AbsoluteSize.Y - absSize.Y)
		clickControl.Position = UDim2.new(0, newX, 0, newY)
	end
end)

local minimized = false
_=(function()
	local _createCorner = createCorner
	local _tween = tween
	local _contentFrame = contentFrame
	local _tabBar = tabBar
	local _mainFrame = mainFrame
	local _minimizeBtn = minimizeBtn
	local _topBar = topBar
	local _closeBtn = closeBtn

	local btn = Instance.new("ImageButton")
	btn.Name = "RestoreBtn"
	btn.Size = UDim2.new(0, 56, 0, 56)
	btn.Position = UDim2.new(0, 12, 0.5, -28)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
	btn.Image = "rbxassetid://73314612607499"
	btn.ScaleType = Enum.ScaleType.Fit
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Visible = false
	btn.ZIndex = 9999
	btn.Parent = screenGui
	_createCorner(btn, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 80, 220)
	stroke.Thickness = 2
	stroke.Parent = btn

	-- Long-press 2s sur le bouton = destroy all (escape hatch)
		-- lpStartTime = -1 quand on vient de finir un long-press (sentinel)
		local longPressProgress = nil
		local lpStartTime = 0

		local function destroyAllPanel()
			if longPressProgress and longPressProgress.Parent then
				longPressProgress:Destroy()
			end
			pcall(shutdownPanel)
			btn.Visible = false
			for _, gui in ipairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
				if gui.Name == "MilanEmerickPanel" or gui.Name == "AgoraAdminUniverselle" then
					pcall(function() gui:Destroy() end)
				end
			end
			pcall(function()
				if game.CoreGui:FindFirstChild("MilanEmerickPanel") then
					game.CoreGui.MilanEmerickPanel:Destroy()
				end
			end)
			print("[Agora Universelle] Panel detruit.")
		end

		local function startLongPress()
			lpStartTime = tick()
			if not longPressProgress or not longPressProgress.Parent then
				longPressProgress = Instance.new("Frame")
				longPressProgress.Size = UDim2.new(1.4, 0, 1.4, 0)
				longPressProgress.Position = UDim2.new(0.5, 0, 0.5, 0)
				longPressProgress.AnchorPoint = Vector2.new(0.5, 0.5)
				longPressProgress.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
				longPressProgress.BackgroundTransparency = 0.6
				longPressProgress.BorderSizePixel = 0
				longPressProgress.ZIndex = btn.ZIndex - 1
				longPressProgress.Parent = btn
				_createCorner(longPressProgress, 1)
			end
			longPressProgress.Visible = true
			longPressProgress.Size = UDim2.new(1, 0, 1, 0)
			longPressProgress.BackgroundTransparency = 1
			_tween(longPressProgress, {Size = UDim2.new(1.4, 0, 1.4, 0), BackgroundTransparency = 0.6}, 2)
		end
		local function endLongPress()
			local longPressed = lpStartTime > 0 and (tick() - lpStartTime) >= 2
			lpStartTime = longPressed and -1 or 0
			if longPressed then
				destroyAllPanel()
			end
			if longPressProgress and longPressProgress.Parent then
				_tween(longPressProgress, {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1}, 0.2)
			end
		end

		btn.MouseButton1Down:Connect(startLongPress)
		btn.MouseLeave:Connect(endLongPress)
		btn.MouseButton1Up:Connect(endLongPress)

		-- Clic court = restaurer le panel (seulement si pas un long-press)
		btn.MouseButton1Click:Connect(function()
			if lpStartTime == -1 then
				lpStartTime = 0
				return
			end
			minimized = false
			_contentFrame.Visible = true
			_tabBar.Visible = true
			_topBar.Visible = true
			_minimizeBtn.Visible = true
			_closeBtn.Visible = true
			_tween(_mainFrame, {Size = UDim2.new(0, 460, 0, 520), BackgroundTransparency = 0.35}, 0.25)
			btn.Visible = false
		end)

	btn.MouseEnter:Connect(function()
		_tween(btn, {Size = UDim2.new(0, 62, 0, 62)}, 0.15)
	end)
	btn.MouseLeave:Connect(function()
		_tween(btn, {Size = UDim2.new(0, 56, 0, 56)}, 0.15)
	end)

	_minimizeBtn.MouseButton1Click:Connect(function()
		minimized = true
		_contentFrame.Visible = false
		_tabBar.Visible = false
		_topBar.Visible = false
		_minimizeBtn.Visible = false
		_closeBtn.Visible = false
		_tween(_mainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.25)
		btn.Visible = true
	end)
end)()

closeBtn.MouseButton1Click:Connect(function()
	local confirm = Instance.new("Frame")
	confirm.Size = UDim2.new(0, 260, 0, 140)
	confirm.Position = UDim2.new(0.5, -130, 0.5, -70)
	confirm.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	confirm.BorderSizePixel = 0
	confirm.ZIndex = 200
	confirm.Parent = screenGui
	createCorner(confirm, 12)
	createStroke(confirm, Color3.fromRGB(80, 80, 100), 1)

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1, -20, 0, 50)
	msg.Position = UDim2.new(0, 10, 0, 15)
	msg.BackgroundTransparency = 1
	msg.Text = "Fermer le panel ?"
	msg.Font = Enum.Font.GothamSemibold
	msg.TextSize = 16
	msg.TextColor3 = Color3.new(1, 1, 1)
	msg.ZIndex = 201
	msg.Parent = confirm

	local yes = createButton(confirm, "Oui", 75, Color3.fromRGB(200, 60, 60), function()
		confirm:Destroy()
		pcall(shutdownPanel)
		-- ===== ANIM FERMETURE "implosion" : panel se contracte vers le centre + flash + glitch =====
		-- Phase 1 : flash blanc
		local flash = Instance.new("Frame")
		flash.Size = UDim2.new(1, 0, 1, 0)
		flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.ZIndex = 999
		flash.Parent = screenGui
		tween(flash, {BackgroundTransparency = 0.4}, 0.1)
		task.wait(0.1)
		tween(flash, {BackgroundTransparency = 1}, 0.3)
		task.delay(0.4, function() if flash and flash.Parent then flash:Destroy() end end)

		-- Phase 2 : glitch horizontal bars
		for i = 1, 6 do
			local gb = Instance.new("Frame")
			gb.Size = UDim2.new(1, 0, 0, math.random(2, 8))
			gb.Position = UDim2.new(0, 0, math.random() * 0.95, 0)
			gb.BackgroundColor3 = Color3.fromRGB(math.random(100, 255), math.random(100, 255), math.random(100, 255))
			gb.BackgroundTransparency = 0.4
			gb.BorderSizePixel = 0
			gb.ZIndex = 990
			gb.Parent = screenGui
			task.spawn(function()
				task.wait(i * 0.05)
				tween(gb, {BackgroundTransparency = 1, Position = UDim2.new(0, math.random(-20, 20), gb.Position.Y.Scale, 0)}, 0.2)
				task.delay(0.3, function() if gb and gb.Parent then gb:Destroy() end end)
			end)
		end

		-- Phase 3 : panel se contracte (scale vers 0 + rotation + fade)
		mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		local oldPos = mainFrame.Position
		mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		tween(mainFrame, {
			Size = UDim2.new(0, 0, 0, 0),
			Rotation = 12,
			BackgroundTransparency = 1,
		}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		-- Text goodbye au milieu
		local goodbye = Instance.new("TextLabel")
		goodbye.Size = UDim2.new(1, 0, 0, 40)
		goodbye.Position = UDim2.new(0, 0, 0.5, -20)
		goodbye.BackgroundTransparency = 1
		goodbye.Text = "Au revoir " .. LocalPlayer.DisplayName .. " revenez vite... 3:)"
		goodbye.Font = Enum.Font.GothamBold
		goodbye.TextSize = 22
		goodbye.TextColor3 = Color3.fromRGB(120, 255, 180)
		goodbye.TextStrokeTransparency = 0.3
		goodbye.TextTransparency = 1
		goodbye.ZIndex = 1000
		goodbye.Parent = screenGui
		task.wait(0.2)
		tween(goodbye, {TextTransparency = 0}, 0.3)
		task.wait(1.2)
		tween(goodbye, {TextTransparency = 1}, 0.5)
		task.wait(0.6)
		screenGui.Enabled = false
		if goodbye and goodbye.Parent then goodbye:Destroy() end
	end)
	yes.Size = UDim2.new(0.45, -10, 0, 34)
	yes.Position = UDim2.new(0.05, 5, 0, 75)
	yes.ZIndex = 201

	local no = createButton(confirm, "Non", 75, Color3.fromRGB(60, 160, 90), function()
		confirm:Destroy()
	end)
	no.Size = UDim2.new(0.45, -10, 0, 34)
	no.Position = UDim2.new(0.55, -5, 0, 75)
	no.ZIndex = 201

	confirm:TweenPosition(UDim2.new(0.5, -130, 0.5, -70), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.25, true)
end)

-- == SHUTDOWN ALL FEATURES ==
local function shutdownPanel()
	if flyState and flyState.flying then stopFly() end
	if noclipState and noclipState.enabled then
		noclipState.enabled = false
		if noclipSwitch then noclipSwitch.set(false) end
		local char = LocalPlayer.Character
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
			end
		end
	end
	if globalESPSwitch and globalESPSwitch.get and globalESPSwitch.get() then
		globalESPSwitch.set(false)
	end
	if espState then
		espState.enabled = false
		clearESP()
	end
	globalESPEnabled = false
	if autoClickState then
		autoClickState.toolActive = false
		if stopAutoClickEngine then stopAutoClickEngine() end
		removeFakeTool()
		if clickControl then clickControl.Visible = false end
	end
	if fullbrightSwitch and fullbrightSwitch.get and fullbrightSwitch.get() then fullbrightSwitch.set(false) end
	if zeroGSwitch and zeroGSwitch.get and zeroGSwitch.get() then zeroGSwitch.set(false) end
	if hitboxSwitch and hitboxSwitch.get and hitboxSwitch.get() then hitboxSwitch.set(false) end
	if clickTPSwitch and clickTPSwitch.get and clickTPSwitch.get() then clickTPSwitch.set(false) end
	if antiTPSwitch and antiTPSwitch.get and antiTPSwitch.get() then antiTPSwitch.set(false) end
	if antiFlingSwitch and antiFlingSwitch.get and antiFlingSwitch.get() then antiFlingSwitch.set(false) end
	if antiSeatSwitch and antiSeatSwitch.get and antiSeatSwitch.get() then antiSeatSwitch.set(false) end
	if antiFallSwitch and antiFallSwitch.get and antiFallSwitch.get() then antiFallSwitch.set(false) end
	if antiKillSwitch and antiKillSwitch.get and antiKillSwitch.get() then antiKillSwitch.set(false) end
	if antiAFKSwitch and antiAFKSwitch.get and antiAFKSwitch.get() then antiAFKSwitch.set(false) end
	if gotoWalkSwitch and gotoWalkSwitch.get and gotoWalkSwitch.get() then gotoWalkSwitch.set(false) end
	if infiniteJumpSwitch and infiniteJumpSwitch.get and infiniteJumpSwitch.get() then infiniteJumpSwitch.set(false) end
	if platformState and platformState.enabled then
		platformState.enabled = false
		if platformState.part then
			platformState.part:Destroy()
			platformState.part = nil
		end
	end
	-- Aimbot shutdown
	_G._agoraAimbotEnabled = false
	-- Restore Lighting if fullbright was on
	pcall(function()
		Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end)
	-- Destroy the panel GUI itself
	pcall(function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
	pcall(function()
		for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
			if g:IsA("ScreenGui") and (g.Name:match("Agora") or g.Name:match("Milan")) then
				g:Destroy()
			end
		end
	end)
	_G._agoraShutdownDone = true
end

_G.shutdownPanel = shutdownPanel

local function createSwitch(parent, labelText, yPos, callback, defaultOn)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 36)
	container.Position = UDim2.new(0, 10, 0, yPos)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	container.BorderSizePixel = 0
	container.Parent = parent
	createCorner(container, 8)
	createStroke(container, Color3.fromRGB(45, 45, 55), 1)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -70, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(210, 210, 210)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container
	label.ZIndex = 4

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 48, 0, 24)
	track.Position = UDim2.new(1, -60, 0.5, -12)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	track.BorderSizePixel = 0
	track.Parent = container
	track.ZIndex = 5
	createCorner(track, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 20, 0, 20)
	knob.Position = UDim2.new(0, 2, 0.5, -10)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
	knob.ZIndex = 6
	createCorner(knob, 10)

	local state = defaultOn or false
	local function update(animate)
		local dur = animate and 0.15 or 0
		tween(track, {BackgroundColor3 = state and Color3.fromRGB(60, 190, 120) or Color3.fromRGB(60, 60, 70)}, dur)
		tween(knob, {Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, dur)
	end
	update(false)

	local function toggle()
		state = not state
		update(true)
		callback(state)
	end

	-- Zone de clic invisible par-dessus tout le switch
	local hitbox = Instance.new("TextButton")
	hitbox.Name = "SwitchHitbox"
	hitbox.Size = UDim2.new(1, 0, 1, 0)
	hitbox.BackgroundTransparency = 1
	hitbox.Text = ""
	hitbox.Parent = container
	hitbox.ZIndex = 10

	-- Pass-through : les enfants (label, track) doivent etre cliquables si le hitbox ne les recouvre pas,
	-- MAIS le container opaque empiete sur le texte des lignes voisines. On force le hitbox a s'arreter a la taille du switch.
	container.ClipsDescendants = true

	hitbox.MouseButton1Click:Connect(toggle)

	return {
		set = function(v)
			state = v
			update(true)
			callback(v)
		end,
		get = function() return state end
	}
end

_G.createSwitch = createSwitch

updateLoad(0.08, "Modules joueurs...")
task.wait(0.05)
-- ============= JOUEURS =============
local playerCards = {}
local playerSearchQuery = "" -- query actuelle (vide = pas de filtre)

-- searchBox de Joueurs = FILTRE LOCAL de la liste des joueurs connectes
-- (la recherche officielle par username Roblox reste dans Registry)
local playerSearchBox = Instance.new("TextBox")
playerSearchBox.Size = UDim2.new(1, -10, 0, 26)
playerSearchBox.Position = UDim2.new(0, 5, 0, 8)
playerSearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
playerSearchBox.BackgroundTransparency = 0.4 -- plus discret que la search box Registry
playerSearchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
playerSearchBox.PlaceholderText = "? Filtrer la liste des joueurs..."
playerSearchBox.Text = ""
playerSearchBox.Font = Enum.Font.Gotham
playerSearchBox.TextSize = 11
playerSearchBox.TextXAlignment = Enum.TextXAlignment.Left
playerSearchBox.ClearTextOnFocus = false
playerSearchBox.Parent = playersPage
createCorner(playerSearchBox, 6)
createStroke(playerSearchBox, Color3.fromRGB(60, 60, 80), 1)

-- Bouton X pour effacer le filtre Joueurs
local playerClearBtn = Instance.new("TextButton")
playerClearBtn.Size = UDim2.new(0, 20, 0, 20)
playerClearBtn.Position = UDim2.new(1, -25, 0, 11)
playerClearBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
playerClearBtn.Text = "X"
playerClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
playerClearBtn.Font = Enum.Font.GothamBold
playerClearBtn.TextSize = 10
playerClearBtn.BorderSizePixel = 0
playerClearBtn.Visible = false
playerClearBtn.ZIndex = playerSearchBox.ZIndex + 1
playerClearBtn.AutoButtonColor = true
playerClearBtn.Parent = playersPage
createCorner(playerClearBtn, 10)
playerClearBtn.MouseButton1Click:Connect(function()
	playerSearchBox.Text = ""
	playerClearBtn.Visible = false
end)

local psbPad = Instance.new("UIPadding")
psbPad.PaddingLeft = UDim.new(0, 8)
psbPad.Parent = playerSearchBox

-- playersScroll commence sous la searchBox de Joueurs
local playersScroll = Instance.new("ScrollingFrame")
playersScroll.Size = UDim2.new(1, -10, 1, -48)
playersScroll.Position = UDim2.new(0, 5, 0, 40)
playersScroll.BackgroundTransparency = 1
playersScroll.ScrollBarThickness = 4
playersScroll.BorderSizePixel = 0
playersScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playersScroll.Parent = playersPage

-- Stats serveur deplacees vers l'onglet Extra (card "Stats serveur")
-- playersScroll prend maintenant toute la place disponible sous la searchBox
local playersLayout = Instance.new("UIListLayout")
playersLayout.Padding = UDim.new(0, 6)
playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
playersLayout.Parent = playersScroll

playersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end)
task.defer(function()
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end)

-- === CARTE "* MOI" (LocalPlayer) - auto-creee, toujours en haut ===
;(function(_createCorner, _createStroke)
	local myCard = Instance.new("Frame")
	myCard.Name = "MyCard"
	myCard.Size = UDim2.new(1, -8, 0, 0)
	myCard.AutomaticSize = Enum.AutomaticSize.Y
	myCard.BackgroundColor3 = Color3.fromRGB(45, 30, 70)
	myCard.BorderSizePixel = 0
	myCard.LayoutOrder = -100 -- toujours en premier
	myCard.Parent = playersScroll
	_createCorner(myCard, 8)
	_createStroke(myCard, Color3.fromRGB(180, 130, 255), 1.5)

	-- Titre "* TOI - @pseudo"
	local myTitle = Instance.new("TextLabel")
	myTitle.Size = UDim2.new(1, -16, 0, 22)
	myTitle.Position = UDim2.new(0, 8, 0, 6)
	myTitle.BackgroundTransparency = 1
	myTitle.Font = Enum.Font.GothamBlack
	myTitle.TextSize = 14
	myTitle.TextColor3 = Color3.fromRGB(220, 180, 255)
	myTitle.TextXAlignment = Enum.TextXAlignment.Left
	myTitle.Parent = myCard

	-- Contenu (lignes natives Roblox)
	local myContent = Instance.new("TextLabel")
	myContent.Name = "MyContent"
	myContent.Size = UDim2.new(1, -16, 0, 0)
	myContent.Position = UDim2.new(0, 8, 0, 30)
	myContent.AutomaticSize = Enum.AutomaticSize.Y
	myContent.BackgroundTransparency = 1
	myContent.Font = Enum.Font.Gotham
	myContent.TextSize = 11
	myContent.TextColor3 = Color3.fromRGB(210, 210, 230)
	myContent.TextXAlignment = Enum.TextXAlignment.Left
	myContent.TextYAlignment = Enum.TextYAlignment.Top
	myContent.TextWrapped = true
	myContent.Parent = myCard

	-- Update function (IIFE pour isoler les locals)
	local function updateMyCard()
		pcall(function()
			local _lp = LocalPlayer
			local myName = _lp.Name or "?"
			local myDisp = _lp.DisplayName or "?"
			local myUid = tostring(_lp.UserId or "?")
			local myAgeDays = _lp.AccountAge or 0
			local myYears = math.floor(myAgeDays / 365)
			local myRem = myAgeDays - (myYears * 365)
			local myMt = tostring(_lp.MembershipType or "None"):gsub("Enum.MembershipType.", "")
			local myPing = "?"
			pcall(function() myPing = tostring(math.floor((_lp.GetNetworkPing and _lp:GetNetworkPing() or 0) * 1000)) .. " ms" end)
			local myTeam = (_lp.Team and _lp.Team.Name) or "Aucune"
			local myChar = _lp.Character
			local myHp = "?"
			local myPos = "?"
			pcall(function()
				if myChar then
					local h = myChar:FindFirstChildOfClass("Humanoid")
					if h then myHp = tostring(math.floor(h.Health)) .. "/" .. tostring(math.floor(h.MaxHealth)) end
					local hrp = myChar:FindFirstChild("HumanoidRootPart")
					if hrp then
						local p = hrp.Position
						myPos = string.format("(%.0f, %.0f, %.0f)", p.X, p.Y, p.Z)
					end
				end
			end)
			local myGame = tostring(game.GameId or "?")
			local myPlace = tostring(game.PlaceId or "?")

			myTitle.Text = "* TOI - @" .. myName .. " (" .. myDisp .. ")"
			myContent.Text = table.concat({
				"UserId      : " .. myUid,
				"Compte      : " .. myYears .. " an(s) " .. myRem .. "j (" .. myAgeDays .. " jours)",
				"Membership  : " .. myMt,
				"Team        : " .. myTeam,
				"Ping        : " .. myPing,
				"HP          : " .. myHp,
				"Position    : " .. myPos,
				"GameId      : " .. myGame .. " / PlaceId " .. myPlace,
			}, "\n")
		end)
	end
	updateMyCard()
	-- Update chaque seconde
	task.spawn(function()
		while true do
			task.wait(1)
			updateMyCard()
		end
	end)
end)(createCorner, createStroke)

-- Listener filtre de la searchBox de Joueurs
playerSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = playerSearchBox.Text:lower():gsub("%s+", "")
	playerClearBtn.Visible = (playerSearchBox.Text ~= "")
	for plr, card in pairs(playerCards) do
		local n = plr.Name:lower()
		local d = plr.DisplayName:lower()
		local match = (q == "") or (n:find(q, 1, true) ~= nil) or (d:find(q, 1, true) ~= nil)
		card.Visible = match
	end
end)

local echoStatusLabel = Instance.new("TextLabel")
echoStatusLabel.Size = UDim2.new(1, -20, 0, 18)
echoStatusLabel.Position = UDim2.new(0, 10, 1, -26)
echoStatusLabel.BackgroundTransparency = 1
echoStatusLabel.Text = "Echo: aucun"
echoStatusLabel.Font = Enum.Font.Gotham
echoStatusLabel.TextSize = 10
echoStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
echoStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
echoStatusLabel.Parent = mainFrame

local selectedEchoPlayer = nil

-- Pop-up de restauration du dernier joueur Echo
local function showRestorePopup(lastName)
	if panelMemory.dontAskRestore then return end
	if not lastName then return end
	local current = Players:FindFirstChild(lastName)
	if not current then return end

	local popup = Instance.new("Frame")
	popup.Size = UDim2.new(0, 300, 0, 130)
	popup.Position = UDim2.new(0.5, -150, 0.5, -65)
	popup.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	popup.BorderSizePixel = 0
	popup.ZIndex = 500
	popup.Parent = screenGui
	createCorner(popup, 12)
	createStroke(popup, Color3.fromRGB(80, 80, 100), 1)

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1, -20, 0, 44)
	msg.Position = UDim2.new(0, 10, 0, 12)
	msg.BackgroundTransparency = 1
	msg.Text = "Restaurer les parametres pour @" .. lastName .. " ?"
	msg.Font = Enum.Font.GothamSemibold
	msg.TextSize = 14
	msg.TextColor3 = Color3.new(1, 1, 1)
	msg.ZIndex = 501
	msg.Parent = popup

	local restoreBtn = createButton(popup, "Restaurer", 70, Color3.fromRGB(60, 160, 90), function()
		selectedEchoPlayer = current
		echoStatusLabel.Text = "Echo: @" .. current.Name
		echoStatusLabel.TextColor3 = Color3.fromRGB(120, 200, 120)
		popup:Destroy()
	end)
	restoreBtn.Size = UDim2.new(0.32, -8, 0, 30)
	restoreBtn.Position = UDim2.new(0.02, 4, 0, 70)
	restoreBtn.ZIndex = 501

	local neverBtn = createButton(popup, "Ne plus afficher", 70, Color3.fromRGB(120, 120, 120), function()
		panelMemory.dontAskRestore = true
		popup:Destroy()
	end)
	neverBtn.Size = UDim2.new(0.36, -8, 0, 30)
	neverBtn.Position = UDim2.new(0.36, 4, 0, 70)
	neverBtn.ZIndex = 501

	local cancelBtn = createButton(popup, "Annuler", 70, Color3.fromRGB(200, 60, 60), function()
		popup:Destroy()
	end)
	cancelBtn.Size = UDim2.new(0.28, -8, 0, 30)
	cancelBtn.Position = UDim2.new(0.74, -4, 0, 70)
	cancelBtn.ZIndex = 501

	popup:TweenPosition(UDim2.new(0.5, -150, 0.5, -65), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.25, true)
end

local addPlayerCard, removePlayerCard, refreshPlayersList  -- forward-declares
local function createPlayerEntry(plr)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 196)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	card.BorderSizePixel = 0
	card.LayoutOrder = plr.Name:byte(1)
	card.Parent = playersScroll
	createCorner(card, 10)
	createStroke(card, Color3.fromRGB(45, 45, 55), 1)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -80, 0, 18)
	nameLbl.Position = UDim2.new(0, 6, 0, 4)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = card

	-- Badge chat active sur le joueur - a GAUCHE haut, jamais sur les boutons
	local playerChatBadge = Instance.new("TextLabel")
	playerChatBadge.Name = "PlayerChatBadge"
	playerChatBadge.Size = UDim2.new(0, 24, 0, 20)
	playerChatBadge.Position = UDim2.new(0, 6, 0, 4)
	playerChatBadge.BackgroundTransparency = 1
	playerChatBadge.Text = "?"
	playerChatBadge.Font = Enum.Font.GothamBold
	playerChatBadge.TextSize = 14
	playerChatBadge.TextColor3 = Color3.fromRGB(220, 220, 255)
	playerChatBadge.TextXAlignment = Enum.TextXAlignment.Center
	playerChatBadge.Visible = false
	playerChatBadge.Parent = card
	playerChatBadge.ZIndex = 6

	-- Nom decale si badge chat present
	nameLbl.Size = UDim2.new(1, -108, 0, 18)
	nameLbl.Position = UDim2.new(0, 30, 0, 4)

	-- Badge local "mouvement anormal" - a droite, plus haut pour pas toucher les boutons
	local moveBadge = Instance.new("TextLabel")
	moveBadge.Name = "MoveBadge"
	moveBadge.Size = UDim2.new(0, 24, 0, 20)
	moveBadge.Position = UDim2.new(1, -32, 0, 2)
	moveBadge.BackgroundTransparency = 1
	moveBadge.BorderSizePixel = 0
	moveBadge.Text = "?"
	moveBadge.Font = Enum.Font.GothamBold
	moveBadge.TextSize = 15
	moveBadge.TextColor3 = Color3.fromRGB(255, 80, 80)
	moveBadge.TextXAlignment = Enum.TextXAlignment.Center
	moveBadge.Visible = false
	moveBadge.Parent = card
	moveBadge.ZIndex = 6

	-- Label detail du mouvement suspect (rouge, petit)
	local moveDetail = Instance.new("TextLabel")
	moveDetail.Name = "MoveDetail"
	moveDetail.Size = UDim2.new(1, -12, 0, 14)
	moveDetail.Position = UDim2.new(0, 6, 0, 108)
	moveDetail.BackgroundTransparency = 1
	moveDetail.Text = ""
	moveDetail.Font = Enum.Font.Gotham
	moveDetail.TextSize = 9
	moveDetail.TextColor3 = Color3.fromRGB(255, 100, 100)
	moveDetail.TextXAlignment = Enum.TextXAlignment.Left
	moveDetail.TextWrapped = true
	moveDetail.Parent = card

	-- Bloc notes detection de cheat (rouge, sous les infos principales)
	local cheatNotes = Instance.new("TextLabel")
	cheatNotes.Name = "CheatNotes"
	cheatNotes.Size = UDim2.new(1, -12, 0, 34)
	cheatNotes.Position = UDim2.new(0, 6, 0, 140)
	cheatNotes.BackgroundTransparency = 1
	cheatNotes.Text = ""
	cheatNotes.Font = Enum.Font.Gotham
	cheatNotes.TextSize = 9
	cheatNotes.TextColor3 = Color3.fromRGB(255, 120, 120)
	cheatNotes.TextXAlignment = Enum.TextXAlignment.Left
	cheatNotes.TextWrapped = true
	cheatNotes.TextYAlignment = Enum.TextYAlignment.Top
	cheatNotes.Parent = card

	-- Timer de cooldown du badge (evite les flashs a chaque frame)
	local lastMoveFlagAt = 0
	local lastMoveReason = ""
	local MOVE_FLAG_DURATION = 3
	local lastChatCheck = 0
	local lastKnownPos = nil

	local infoLeft = Instance.new("TextLabel")
	infoLeft.Size = UDim2.new(0.55, -6, 0, 14)
	infoLeft.Position = UDim2.new(0, 6, 0, 24)
	infoLeft.BackgroundTransparency = 1
	local days = plr.AccountAge
	local years = math.floor(days / 365)
	local remainingDays = days - (years * 365)
	infoLeft.Text = "ID: " .. plr.UserId .. " | Age: " .. days .. "j (" .. years .. (years <= 1 and " an" or " ans") .. ")"
	infoLeft.Font = Enum.Font.Gotham
	infoLeft.TextSize = 10
	infoLeft.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLeft.TextXAlignment = Enum.TextXAlignment.Left
	infoLeft.Parent = card

	-- === Colonne droite : statut Roblox + jeu actuel + derniere connexion ===
	local statusCol = Instance.new("TextLabel")
	statusCol.Name = "StatusCol"
	statusCol.Size = UDim2.new(0.42, -6, 0, 60)
	statusCol.Position = UDim2.new(0.55, 0, 0, 24)
	statusCol.BackgroundTransparency = 1
	statusCol.Text = "Statut: ?"
	statusCol.Font = Enum.Font.GothamSemibold
	statusCol.TextSize = 10
	statusCol.TextColor3 = Color3.fromRGB(180, 200, 230)
	statusCol.TextXAlignment = Enum.TextXAlignment.Right
	statusCol.TextYAlignment = Enum.TextYAlignment.Top
	statusCol.TextWrapped = true
	statusCol.Parent = card

	local distLbl = Instance.new("TextLabel")
	distLbl.Size = UDim2.new(0.55, -6, 0, 14)
	distLbl.Position = UDim2.new(0, 6, 0, 38)
	distLbl.BackgroundTransparency = 1
	distLbl.Text = "Distance: ?"
	distLbl.Font = Enum.Font.Gotham
	distLbl.TextSize = 10
	distLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	distLbl.TextXAlignment = Enum.TextXAlignment.Left
	distLbl.Parent = card

	local hpLbl = Instance.new("TextLabel")
	hpLbl.Size = UDim2.new(0.55, -6, 0, 14)
	hpLbl.Position = UDim2.new(0, 6, 0, 52)
	hpLbl.BackgroundTransparency = 1
	hpLbl.Text = "HP: ?"
	hpLbl.Font = Enum.Font.Gotham
	hpLbl.TextSize = 10
	hpLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	hpLbl.TextXAlignment = Enum.TextXAlignment.Left
	hpLbl.Parent = card

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Size = UDim2.new(0.55, -6, 0, 14)
	speedLbl.Position = UDim2.new(0, 6, 0, 66)
	speedLbl.BackgroundTransparency = 1
	speedLbl.Text = "Vitesse/Saut: ?"
	speedLbl.Font = Enum.Font.Gotham
	speedLbl.TextSize = 10
	speedLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	speedLbl.TextXAlignment = Enum.TextXAlignment.Left
	speedLbl.Parent = card

	local chatLbl = Instance.new("TextLabel")
	chatLbl.Name = "ChatLabel"
	chatLbl.Size = UDim2.new(0.55, -6, 0, 14)
	chatLbl.Position = UDim2.new(0, 6, 0, 80)
	chatLbl.BackgroundTransparency = 1
	chatLbl.Text = "? can_chat: chargement..."
	chatLbl.Font = Enum.Font.Gotham
	chatLbl.TextSize = 10
	chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	chatLbl.TextXAlignment = Enum.TextXAlignment.Left
	chatLbl.Parent = card

	_G._resolveCanChat(plr, function(canChat, src)
		if chatLbl and chatLbl.Parent then
			if src == "CanTalkWithMe" then
				if canChat == true then
					chatLbl.Text = "? Peut me parler"
					chatLbl.TextColor3 = Color3.fromRGB(120, 220, 140)
				else
					chatLbl.Text = "? Ne peut pas me parler"
					chatLbl.TextColor3 = Color3.fromRGB(220, 120, 120)
				end
			else
				-- Pas de serveur : on montre juste si le joueur a le chat active
				if canChat == true then
					chatLbl.Text = "? Chat active (" .. src .. ")"
					chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
				elseif canChat == false then
					chatLbl.Text = "? Chat desactive (" .. src .. ")"
					chatLbl.TextColor3 = Color3.fromRGB(180, 120, 120)
				else
					chatLbl.Text = "? Chat: non verifiable"
					chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
				end
			end
		end
	end)

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.55, -6, 0, 14)
	statusLbl.Position = UDim2.new(0, 6, 0, 94)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "Statut: ?"
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 10
	statusLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Parent = card

	local tpBtn = Instance.new("TextButton")
	tpBtn.Size = UDim2.new(0, 54, 0, 24)
	tpBtn.Position = UDim2.new(1, -128, 0, 26)
	tpBtn.BackgroundColor3 = Color3.fromRGB(45, 110, 190)
	tpBtn.Text = "TP"
	tpBtn.Font = Enum.Font.GothamSemibold
	tpBtn.TextSize = 11
	tpBtn.TextColor3 = Color3.new(1, 1, 1)
	tpBtn.BorderSizePixel = 0
	tpBtn.Parent = card
	createCorner(tpBtn, 6)

	local specBtn = Instance.new("TextButton")
	specBtn.Size = UDim2.new(0, 68, 0, 24)
	specBtn.Position = UDim2.new(1, -70, 0, 26)
	specBtn.BackgroundColor3 = Color3.fromRGB(190, 120, 50)
	specBtn.Text = "Spectate"
	specBtn.Font = Enum.Font.GothamSemibold
	specBtn.TextSize = 11
	specBtn.TextColor3 = Color3.new(1, 1, 1)
	specBtn.BorderSizePixel = 0
	specBtn.Parent = card
	createCorner(specBtn, 6)

	local echoBtn = Instance.new("TextButton")
	echoBtn.Size = UDim2.new(0, 54, 0, 24)
	echoBtn.Position = UDim2.new(1, -128, 0, 54)
	echoBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 160)
	echoBtn.Text = "Echo"
	echoBtn.Font = Enum.Font.GothamSemibold
	echoBtn.TextSize = 11
	echoBtn.TextColor3 = Color3.new(1, 1, 1)
	echoBtn.BorderSizePixel = 0
	echoBtn.Parent = card
	createCorner(echoBtn, 6)

	local espBtn = Instance.new("TextButton")
	espBtn.Size = UDim2.new(0, 68, 0, 24)
	espBtn.Position = UDim2.new(1, -70, 0, 54)
	espBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
	espBtn.Text = "ESP"
	espBtn.Font = Enum.Font.GothamSemibold
	espBtn.TextSize = 11
	espBtn.TextColor3 = Color3.new(1, 1, 1)
	espBtn.BorderSizePixel = 0
	espBtn.Parent = card
	createCorner(espBtn, 6)

	local invBtn = Instance.new("TextButton")
	invBtn.Size = UDim2.new(0, 54, 0, 24)
	invBtn.Position = UDim2.new(1, -128, 0, 82)
	invBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
	invBtn.Text = "Voir Inv"
	invBtn.Font = Enum.Font.GothamSemibold
	invBtn.TextSize = 11
	invBtn.TextColor3 = Color3.new(1, 1, 1)
	invBtn.BorderSizePixel = 0
	invBtn.Parent = card
	createCorner(invBtn, 6)

	local skinBtn = Instance.new("TextButton")
	skinBtn.Size = UDim2.new(0, 68, 0, 24)
	skinBtn.Position = UDim2.new(1, -70, 0, 82)
	skinBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 160)
	skinBtn.Text = "Copy Skin"
	skinBtn.Font = Enum.Font.GothamSemibold
	skinBtn.TextSize = 11
	skinBtn.TextColor3 = Color3.new(1, 1, 1)
	skinBtn.BorderSizePixel = 0
	skinBtn.Parent = card
	createCorner(skinBtn, 6)

	local spectating = false

	tpBtn.MouseButton1Click:Connect(function()
		updateCharacter()
		if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and rootPart then
			rootPart.CFrame = plr.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
		end
_G.showRestorePopup = showRestorePopup
	end)

	specBtn.MouseButton1Click:Connect(function()
		spectating = not spectating
		if spectating and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
			Camera.CameraSubject = plr.Character:FindFirstChildOfClass("Humanoid")
			specBtn.Text = "Stop"
			specBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
		else
			updateCharacter()
			if humanoid then Camera.CameraSubject = humanoid end
			spectating = false
			specBtn.Text = "Spectate"
			specBtn.BackgroundColor3 = Color3.fromRGB(190, 120, 50)
		end
	end)

	echoBtn.MouseButton1Click:Connect(function()
		if selectedEchoPlayer == plr then
			selectedEchoPlayer = nil
			echoBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 160)
			echoStatusLabel.Text = "Echo: aucun"
			echoStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		else
			selectedEchoPlayer = plr
			panelMemory.lastEchoPlayerName = plr.Name
			echoBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 100)
			echoStatusLabel.Text = "Echo: @" .. plr.Name
			echoStatusLabel.TextColor3 = Color3.fromRGB(120, 200, 120)
		end
	end)

	local tempEspActive = false
	espBtn.MouseButton1Click:Connect(function()
		if tempEspActive then return end
		tempEspActive = true
		espBtn.Text = "5s"
		espBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
		local targetChar = plr.Character
		local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		local targetHead = targetChar and targetChar:FindFirstChild("Head")
		local arrowGui, arrowLbl

		if targetHead then
			local arrowAdorn = Instance.new("BillboardGui")
			arrowAdorn.Name = "TempESPArrow"
			arrowAdorn.AlwaysOnTop = true
			arrowAdorn.Size = UDim2.new(0, 80, 0, 60)
			arrowAdorn.StudsOffset = Vector3.new(0, 4, 0)
			arrowAdorn.Adornee = targetHead
			arrowAdorn.Parent = targetHead
			arrowGui = arrowAdorn

			local arrowText = Instance.new("TextLabel")
			arrowText.Size = UDim2.new(1, 0, 1, 0)
			arrowText.BackgroundTransparency = 1
			arrowText.Text = "?"
			arrowText.Font = Enum.Font.GothamBlack
			arrowText.TextSize = 36
			arrowText.TextColor3 = Color3.fromRGB(0, 255, 120)
			arrowText.TextStrokeTransparency = 0.2
			arrowText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			arrowText.Parent = arrowAdorn
			arrowLbl = arrowText

			task.spawn(function()
				local up = true
				while arrowAdorn and arrowAdorn.Parent do
					arrowAdorn.StudsOffset = Vector3.new(0, up and 4.6 or 3.4, 0)
					up = not up
					task.wait(0.25)
				end
			end)
		end

		if targetHrp and rootPart then
			local camStart = Camera.CFrame
			local targetCF = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
			TweenService:Create(Camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF}):Play()
		end

		togglePlayerESP(plr)

		task.delay(5, function()
			togglePlayerESP(plr)
			if arrowGui then arrowGui:Destroy() end
			local char = plr.Character
			if char then
				for _, v in ipairs(char:GetDescendants()) do
					if v.Name == "TempESPArrow" then v:Destroy() end
				end
			end
			espBtn.Text = "ESP"
			espBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
			tempEspActive = false
		end)
	end)

	local function showInventoryGui()
		-- Fermer toute fenetre d'inventaire deja ouverte pour ce joueur
		local existing = screenGui:FindFirstChild("_InvPanel_" .. plr.Name)
		if existing then existing:Destroy() end

		local win = Instance.new("Frame")
		win.Name = "_InvPanel_" .. plr.Name
		win.Size = UDim2.new(0, 300, 0, 320)
		win.Position = UDim2.new(0.5, -150, 0.5, -160)
		win.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		win.BackgroundTransparency = 0.1
		win.BorderSizePixel = 0
		win.Active = true
		win.Draggable = true
		win.Parent = screenGui
		createCorner(win, 10)
		createStroke(win, Color3.fromRGB(100, 100, 130), 1.2)

		-- Titre + fermeture X
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -40, 0, 30)
		title.Position = UDim2.new(0, 10, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = "Inv de @" .. plr.Name
		title.Font = Enum.Font.GothamBold
		title.TextSize = 13
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = win

		local closeX = Instance.new("TextButton")
		closeX.Size = UDim2.new(0, 26, 0, 26)
		closeX.Position = UDim2.new(1, -32, 0, 4)
		closeX.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		closeX.Text = "?"
		closeX.Font = Enum.Font.GothamBold
		closeX.TextSize = 16
		closeX.TextColor3 = Color3.new(1, 1, 1)
		closeX.BorderSizePixel = 0
		closeX.Parent = win
		createCorner(closeX, 6)
		closeX.MouseButton1Click:Connect(function() win:Destroy() end)

		-- Bouton "Tout voler"
		local stealAll = Instance.new("TextButton")
		stealAll.Size = UDim2.new(1, -20, 0, 28)
		stealAll.Position = UDim2.new(0, 10, 0, 32)
		stealAll.BackgroundColor3 = Color3.fromRGB(180, 90, 50)
		stealAll.Text = "Tout voler"
		stealAll.Font = Enum.Font.GothamBold
		stealAll.TextSize = 12
		stealAll.TextColor3 = Color3.new(1, 1, 1)
		stealAll.BorderSizePixel = 0
		stealAll.Parent = win
		createCorner(stealAll, 6)

		-- Liste scrollable
		local list = Instance.new("ScrollingFrame")
		list.Size = UDim2.new(1, -20, 1, -72)
		list.Position = UDim2.new(0, 10, 0, 66)
		list.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
		list.BackgroundTransparency = 0.3
		list.ScrollBarThickness = 4
		list.BorderSizePixel = 0
		list.CanvasSize = UDim2.new(0, 0, 0, 0)
		list.Parent = win
		createCorner(list, 6)
		createStroke(list, Color3.fromRGB(60, 60, 75), 1)

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		local function collectItems()
			local target = plr.Character
			local items = {}
			if not target then return items end
			for _, item in ipairs(plr.Backpack:GetChildren()) do
				if item:IsA("Tool") then table.insert(items, {Name = item.Name, Tool = item}) end
			end
			if target:FindFirstChildOfClass("Humanoid") then
				for _, item in ipairs(target:GetChildren()) do
					if item:IsA("Tool") then table.insert(items, {Name = "(EQ) " .. item.Name, Tool = item}) end
				end
			end
			return items
		end

		local function refreshList()
			for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
			local items = collectItems()
			if #items == 0 then
				local none = Instance.new("TextLabel")
				none.Size = UDim2.new(1, -10, 0, 28)
				none.BackgroundTransparency = 1
				none.Text = "(inventaire vide)"
				none.Font = Enum.Font.GothamSemibold
				none.TextSize = 12
				none.TextColor3 = Color3.fromRGB(180, 180, 180)
				none.Parent = list
			else
				for idx, item in ipairs(items) do
					local row = Instance.new("Frame")
					row.Size = UDim2.new(1, -8, 0, 28)
					row.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
					row.BorderSizePixel = 0
					row.LayoutOrder = idx
					row.Parent = list
					createCorner(row, 5)

					local nameLbl = Instance.new("TextLabel")
					nameLbl.Size = UDim2.new(1, -76, 1, 0)
					nameLbl.Position = UDim2.new(0, 8, 0, 0)
					nameLbl.BackgroundTransparency = 1
					nameLbl.Text = item.Name
					nameLbl.Font = Enum.Font.GothamSemibold
					nameLbl.TextSize = 11
					nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
					nameLbl.TextXAlignment = Enum.TextXAlignment.Left
					nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
					nameLbl.Parent = row

					local take = Instance.new("TextButton")
					take.Size = UDim2.new(0, 56, 0, 22)
					take.Position = UDim2.new(1, -62, 0.5, -11)
					take.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
					take.Text = "Voler"
					take.Font = Enum.Font.GothamBold
					take.TextSize = 11
					take.TextColor3 = Color3.new(1, 1, 1)
					take.BorderSizePixel = 0
					take.Parent = row
					createCorner(take, 5)
					take.MouseButton1Click:Connect(function()
						local tool = item.Tool
						if not tool or not tool.Parent then return end
						local clone = tool:Clone()
						local myBackpack = LocalPlayer:FindFirstChild("Backpack")
						if not myBackpack then return end
						clone.Parent = myBackpack
						if notify then notify("Item vole: " .. clone.Name, 2) end
						task.wait(0.1)
						refreshList()
					end)
				end
			end
			list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
		end

		stealAll.MouseButton1Click:Connect(function()
			local items = collectItems()
			local stolen = 0
			local myBackpack = LocalPlayer:FindFirstChild("Backpack")
			if not myBackpack then return end
			for _, item in ipairs(items) do
				if item.Tool and item.Tool.Parent then
					item.Tool:Clone().Parent = myBackpack
					stolen = stolen + 1
				end
			end
			if notify then notify("Voles: " .. stolen .. " item(s)", 2) end
			task.wait(0.1)
			refreshList()
		end)

		refreshList()

		-- Auto-refresh toutes les 2s tant que la fenetre est ouverte
		local refreshConn
		refreshConn = task.spawn(function()
			while win and win.Parent do
				task.wait(2)
				if win and win.Parent then refreshList() end
			end
		end)
		win.Destroying:Connect(function()
			if refreshConn then pcall(task.cancel, refreshConn) end
		end)
	end

	invBtn.MouseButton1Click:Connect(showInventoryGui)

	skinBtn.MouseButton1Click:Connect(function()
		local target = plr.Character
		if not target then return end
		updateCharacter()
		if not character then return end
		-- Copie locale des vetements/corps uniquement (local uniquement)
		local copied = 0
		for _, part in ipairs(target:GetDescendants()) do
			if part:IsA("Clothing") or part:IsA("BodyColors") or part:IsA("Accessory") or part:IsA("ShirtGraphic") then
				local clone = part:Clone()
				local name = clone.Name
				if name == "BodyColors" then
					local existing = character:FindFirstChildOfClass("BodyColors")
					if existing then existing:Destroy() end
				end
				for _, existing in ipairs(character:GetDescendants()) do
					if existing:IsA("Accessory") and existing.Name == clone.Name then
						existing:Destroy()
					end
				end
				clone.Parent = character
				copied = copied + 1
			end
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ApplyDescription(hum:GetAppliedDescription())
		end
		local note = Instance.new("TextLabel")
		note.Size = UDim2.new(0, 220, 0, 30)
		note.Position = UDim2.new(0.5, -110, 0, 80)
		note.BackgroundTransparency = 1
		note.Text = copied > 0 and "Skin copie en local (" .. copied .. ")" or "Rien a copier"
		note.Font = Enum.Font.GothamBold
		note.TextSize = 13
		note.TextColor3 = copied > 0 and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(255, 120, 120)
		note.ZIndex = 200
		note.Parent = screenGui
		tween(note, {TextTransparency = 0}, 0.3)
		task.delay(2.5, function()
			tween(note, {TextTransparency = 1}, 0.3)
			task.delay(0.35, function() if note then note:Destroy() end end)
		end)
	end)

	task.spawn(function()
		while card.Parent do
			task.wait(0.6)
			updateCharacter()
			local char = plr.Character
			if char and rootPart then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (hrp.Position - rootPart.Position).Magnitude
					distLbl.Text = "Distance: " .. math.floor(dist) .. " studs"
					distLbl.TextColor3 = dist < 50 and Color3.fromRGB(120, 255, 120) or dist < 200 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(255, 120, 120)
				else
					distLbl.Text = "Distance: N/A"
				end
				local h = char:FindFirstChildOfClass("Humanoid")
				if h then
					hpLbl.Text = "HP: " .. math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth)
					speedLbl.Text = "Vit: " .. math.floor(h.WalkSpeed) .. " | Saut: " .. math.floor(h.JumpPower)

					-- Statut manuel plus fiable que GetState()
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local stateText = "Standing"
					local moveFlag = false
					if h.Health <= 0 then
						stateText = "Dead"
					elseif h.Sit then
						stateText = "Seated"
					elseif h:GetState() == Enum.HumanoidStateType.Jumping then
						stateText = "Jumping"
					elseif h:GetState() == Enum.HumanoidStateType.Freefall then
						stateText = "Falling"
					elseif hrp then
						local vel = hrp.AssemblyLinearVelocity
						local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
						local vSpeed = math.abs(vel.Y)
						local floorY = hrp.Position.Y - 3
						-- Check si le joueur est dans un vehicule / siege
						local inVehicle = h.SeatPart ~= nil
						-- Seuil d'airborne plus fiable : ignore les sauts legit
						-- NE PAS flagger si en vehicule (avion, voiture, bateau)
						local isAirborne = (floorY > 50 and vSpeed > 20) or (vSpeed > 120)
						if inVehicle then isAirborne = false end
						if flatSpeed > 2 then
							stateText = (h.WalkSpeed > 18 or flatSpeed > 18) and "Running" or "Walking"
						end
						if inVehicle then stateText = "In Vehicle" end
						-- Detection de cheat AMELIOREE v39.29 :
						-- 1. Ignore les vehicules (avions, voitures, bateaux)
						-- 2. Seuils plus hauts pour eviter les faux positifs
						-- 3. Detection God Mode + Noclip + Teleportation
						local suspiciousHorizontal = false
						local suspiciousVertical = false
						local suspiciousAirborne = false
						local suspiciousTeleport = false
						local suspiciousGodMode = false
						local suspiciousNoclip = false
						local reason = ""
						if not inVehicle then
							suspiciousHorizontal = (flatSpeed > 80) or (flatSpeed > 50 and flatSpeed > h.WalkSpeed * 3)
							suspiciousVertical = (vSpeed > 150) and not (h:GetState() == Enum.HumanoidStateType.Freefall)
							suspiciousAirborne = isAirborne and (flatSpeed > 40 or vSpeed > 80)
						else
							suspiciousHorizontal = (flatSpeed > 300) -- Vehicule: seulement extreme
						end
						-- God Mode
						if h.Health > h.MaxHealth and h.MaxHealth > 0 then
							suspiciousGodMode = true
							reason = "God Mode " .. math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth)
						end
						-- Teleportation instantanee
						if lastKnownPos and not inVehicle then
							local tpDelta = (hrp.Position - lastKnownPos).Magnitude
							if tpDelta > 300 then
								suspiciousTeleport = true
								if reason == "" then reason = "TP " .. math.floor(tpDelta) .. " studs" end
							end
						end
						lastKnownPos = hrp.Position
						-- Noclip (character dans un mur)
						if not inVehicle and not flyState.flying and not noclipState.enabled then
							pcall(function()
								local params = RaycastParams.new()
									params.FilterType = Enum.RaycastFilterType.Include
									params.FilterDescendantsInstances = {hrp}
									local hit = Workspace:Raycast(hrp.Position, hrp.Size, params)
									if hit and hit.Instance and not hit.Instance:IsDescendantOf(char) then
										suspiciousNoclip = true
										if reason == "" then reason = "Noclip (dans un mur)" end
									end
							end)
						end
						local now = tick()
						if reason == "" then
						if suspiciousHorizontal then
							reason = "Vit. " .. math.floor(flatSpeed) .. " (max " .. math.floor(h.WalkSpeed) .. ")"
						elseif suspiciousVertical then
							reason = "Air " .. math.floor(vSpeed) .. " studs/s"
						elseif suspiciousAirborne then
							reason = "Airborne " .. math.floor(flatSpeed) .. "/s"
						end
						end
						if suspiciousHorizontal or suspiciousVertical or suspiciousAirborne or suspiciousTeleport or suspiciousGodMode or suspiciousNoclip then
							lastMoveFlagAt = now
							lastMoveReason = reason
							moveFlag = true
						elseif now - lastMoveFlagAt < MOVE_FLAG_DURATION then
							moveFlag = true
						end
					end
					statusLbl.Text = "Statut: " .. stateText
					pcall(function()
						if moveFlag then
							moveBadge.Visible = true
							moveDetail.Text = "? " .. lastMoveReason
							-- ajout dans les notes avec heure
							local ts = os.date("%H:%M:%S")
							local line = "[" .. ts .. "] " .. stateText .. " - " .. lastMoveReason
							if not cheatNotes.Text:find(line, 1, true) then
								if #cheatNotes.Text > 0 then
									cheatNotes.Text = line .. "\n" .. cheatNotes.Text
								else
									cheatNotes.Text = line
								end
								if #cheatNotes.Text > 240 then
									cheatNotes.Text = cheatNotes.Text:sub(1, 240) .. "..."
								end
							end
							card.BackgroundColor3 = Color3.fromRGB(38, 25, 25)
							createStroke(card, Color3.fromRGB(160, 70, 70), 1.2)
						else
							moveBadge.Visible = false
							moveDetail.Text = ""
							card.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
							createStroke(card, Color3.fromRGB(45, 45, 55), 1)
						end
						-- badge chat en temps reel
						local now2 = tick()
						if now2 - lastChatCheck > 0.5 then
							lastChatCheck = now2
							local seenChat = plr.UserId and _G._chatSeenPlayers[plr.UserId]
							local sinceChat = seenChat and (now2 - seenChat) or math.huge
							playerChatBadge.Visible = (seenChat and sinceChat <= 600)
						end
					end)
				else
					hpLbl.Text = "HP: mort"
					speedLbl.Text = "Vit: ? | Saut: ?"
					statusLbl.Text = "Statut: ?"
				end
			else
				distLbl.Text = "Distance: N/A"
				hpLbl.Text = "HP: N/A"
				speedLbl.Text = "Vit: N/A | Saut: N/A"
				statusLbl.Text = "Statut: N/A"
			end
		end
	end)

	-- === ENRICHISSEMENT v37.1 : temps de connexion + badge ordre d'arrivee ===
	-- Ligne du bas : "Connecte depuis 12m 34s" + badge "Arrive avant toi" / "Arrive il y a Xs"
	local connTimeLbl = Instance.new("TextLabel")
	connTimeLbl.Size = UDim2.new(0.55, -6, 0, 14)
	connTimeLbl.Position = UDim2.new(0, 6, 0, 116)
	connTimeLbl.BackgroundTransparency = 1
	connTimeLbl.Text = "Connecte: ?"
	connTimeLbl.Font = Enum.Font.Gotham
	connTimeLbl.TextSize = 10
	connTimeLbl.TextColor3 = Color3.fromRGB(160, 200, 240)
	connTimeLbl.TextXAlignment = Enum.TextXAlignment.Left
	connTimeLbl.Parent = card

	local arrivalBadge = Instance.new("TextLabel")
	arrivalBadge.Size = UDim2.new(0.55, -6, 0, 14)
	arrivalBadge.Position = UDim2.new(0, 6, 0, 130)
	arrivalBadge.BackgroundTransparency = 1
	arrivalBadge.Text = ""
	arrivalBadge.Font = Enum.Font.GothamSemibold
	arrivalBadge.TextSize = 10
	arrivalBadge.TextColor3 = Color3.fromRGB(255, 200, 80)
	arrivalBadge.TextXAlignment = Enum.TextXAlignment.Left
	arrivalBadge.Parent = card

	-- Bouton "i" : ouvre un popup detail avec toutes les infos Roblox du joueur
	local infoBtn = Instance.new("TextButton")
	infoBtn.Size = UDim2.new(0, 24, 0, 24)
	infoBtn.Position = UDim2.new(1, -32, 0, 4)
	infoBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	infoBtn.Text = "i"
	infoBtn.Font = Enum.Font.GothamBold
	infoBtn.TextSize = 13
	infoBtn.TextColor3 = Color3.fromRGB(180, 200, 255)
	infoBtn.BorderSizePixel = 0
	infoBtn.AutoButtonColor = false
	infoBtn.Parent = card
	createCorner(infoBtn, 12)

	-- Boucle live : met a jour le timer et le badge toutes les secondes
	-- Timestamp = moment ou le panel a vu ce player pour la 1ere fois
	-- Pour les players deja la au boot, c'est approximatif (= temps depuis l'ouverture du panel)
	local firstSeenTick = tick()
	_JOIN_TIMESTAMPS = _JOIN_TIMESTAMPS or {}
	_JOIN_TIMESTAMPS[plr] = firstSeenTick
	_JOIN_TIMESTAMPS["__panelBoot__"] = _JOIN_TIMESTAMPS["__panelBoot__"] or firstSeenTick
	task.spawn(function()
		while card and card.Parent and plr and plr.Parent do
			pcall(function()
				local now = tick()
				local seen = _JOIN_TIMESTAMPS[plr] or firstSeenTick
				local since = now - seen
				local secs = math.floor(since % 60)
				local mins = math.floor(since / 60) % 60
				local hrs = math.floor(since / 3600)
				if hrs > 0 then
					connTimeLbl.Text = string.format("Connecte: %dh %dm %ds", hrs, mins, secs)
				elseif mins > 0 then
					connTimeLbl.Text = string.format("Connecte: %dm %ds", mins, secs)
				else
					connTimeLbl.Text = string.format("Connecte: %ds", secs)
				end

				-- Badge "arrivee" : compare au 1er player tracke
				local bootRef = _JOIN_TIMESTAMPS["__panelBoot__"] or firstSeenTick
				if seen <= bootRef + 0.5 then
					arrivalBadge.Text = "? La depuis l'ouverture du panel"
					arrivalBadge.TextColor3 = Color3.fromRGB(120, 200, 255)
				else
					local late = math.floor(now - seen)
					arrivalBadge.Text = string.format("? Arrive il y a %ds", late)
					arrivalBadge.TextColor3 = Color3.fromRGB(180, 220, 140)
				end
				end) -- ferme pcall
				task.wait(1)
				end -- ferme while
				end) -- ferme task.spawn

				-- Popup de details complet sur clic "i"
	infoBtn.MouseButton1Click:Connect(function()
		pcall(function()
			local existing = screenGui:FindFirstChild("_InfoPanel_" .. plr.Name)
			if existing then existing:Destroy() return end

			local win = Instance.new("Frame")
			win.Name = "_InfoPanel_" .. plr.Name
			win.Size = UDim2.new(0, 380, 0, 500)
			win.Position = UDim2.new(0.5, -190, 0.5, -250)
			win.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
			win.BackgroundTransparency = 0.05
			win.BorderSizePixel = 0
			win.Active = true
			win.Draggable = true
			win.Parent = screenGui
			createCorner(win, 10)
			createStroke(win, Color3.fromRGB(120, 80, 255), 1.2)

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, -100, 0, 28)
			title.Position = UDim2.new(0, 10, 0, 0)
			title.BackgroundTransparency = 1
			title.Text = "Details : @" .. plr.Name
			title.Font = Enum.Font.GothamBold
			title.TextSize = 14
			title.TextColor3 = Color3.fromRGB(255, 255, 255)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = win

			-- Bouton Copier (a gauche du X)
			local copyBtn = Instance.new("TextButton")
			copyBtn.Size = UDim2.new(0, 60, 0, 22)
			copyBtn.Position = UDim2.new(1, -100, 0, 6)
			copyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
			copyBtn.Text = "? Copier"
			copyBtn.Font = Enum.Font.GothamBold
			copyBtn.TextSize = 11
			copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			copyBtn.BorderSizePixel = 0
			copyBtn.Parent = win
			createCorner(copyBtn, 4)

			local closeX = Instance.new("TextButton")
			closeX.Size = UDim2.new(0, 26, 0, 26)
			closeX.Position = UDim2.new(1, -32, 0, 4)
			closeX.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
			closeX.Text = "X"
			closeX.Font = Enum.Font.GothamBold
			closeX.TextSize = 13
			closeX.TextColor3 = Color3.fromRGB(255, 255, 255)
			closeX.BorderSizePixel = 0
			closeX.Parent = win
			createCorner(closeX, 6)
			closeX.MouseButton1Click:Connect(function() win:Destroy() end)

			-- Contenu scrollable (permet beaucoup plus d'infos que le TextLabel fixe)
			local scrollFrame = Instance.new("ScrollingFrame")
			scrollFrame.Name = "InfoScroll"
			scrollFrame.Size = UDim2.new(1, -20, 1, -40)
			scrollFrame.Position = UDim2.new(0, 10, 0, 32)
			scrollFrame.BackgroundTransparency = 1
			scrollFrame.BorderSizePixel = 0
			scrollFrame.ScrollBarThickness = 6
			scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 255)
			scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1500)
			scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scrollFrame.Parent = win
			createCorner(scrollFrame, 4)

			-- Avatar via Players:GetUserThumbnailAsync (NATIVE Roblox, pas besoin de HttpGet)
			pcall(function()
				local img = Instance.new("ImageLabel")
				img.Name = "AvatarImg"
				img.Size = UDim2.new(0, 72, 0, 72)
				img.Position = UDim2.new(0, 8, 0, 4)
				img.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
				img.BorderSizePixel = 0
				img.Parent = scrollFrame
				createCorner(img, 36)
				local ok, content = pcall(function()
					return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok and content then
					img.Image = content
				else
					img.Image = "rbxassetid://0"
				end
			end)

			local infoText = Instance.new("TextLabel")
			infoText.Name = "InfoText"
			infoText.Size = UDim2.new(1, -100, 0, 1500)
			infoText.Position = UDim2.new(0, 88, 0, 4)
			infoText.BackgroundTransparency = 1
			infoText.TextXAlignment = Enum.TextXAlignment.Left
			infoText.TextYAlignment = Enum.TextYAlignment.Top
			infoText.Font = Enum.Font.Gotham
			infoText.TextSize = 13
			infoText.TextColor3 = Color3.fromRGB(240, 240, 255)
			infoText.TextWrapped = true
			infoText.Parent = scrollFrame

			-- Construction du contenu
			local allLines = {}
			local function setText(lines)
				if type(lines) == "table" then
					allLines = lines
				else
					allLines = {tostring(lines)}
				end
				infoText.Text = table.concat(allLines, "\n")
			end
			-- Bouton Copier : copie tout le texte actuel dans le presse-papier
			copyBtn.MouseButton1Click:Connect(function()
				local txt = table.concat(allLines, "\n")
				pcall(function()
					if setclipboard then
						setclipboard(txt)
					elseif toclipboard then
						toclipboard(txt)
					end
				end)
				copyBtn.Text = "OK Copie"
				copyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
				task.delay(1.5, function()
					if copyBtn and copyBtn.Parent then
						copyBtn.Text = "? Copier"
						copyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
					end
				end)
			end)

			local days = plr.AccountAge
			local years = math.floor(days / 365)
			local rem = days - years * 365
			local myUserId = LocalPlayer and LocalPlayer.UserId or 0
			local isFriend = false
			pcall(function()
				if LocalPlayer and LocalPlayer:IsFriendsWith(plr.UserId) then isFriend = true end
			end)

			setText({
				"Display : " .. plr.DisplayName,
				"Username : @" .. plr.Name,
				"UserId : " .. plr.UserId,
				"Compte : " .. years .. (years <= 1 and " an " or " ans ") .. rem .. "j (" .. days .. " jours)",
				"Team : " .. tostring(plr.Team and plr.Team.Name or "Aucune"),
				"Neutral : " .. tostring(plr.Neutral),
				"PlaceId : " .. tostring(game.PlaceId),
				"JobId : " .. (game.JobId ~= "" and game.JobId or "(meme serveur)"),
				"Ami avec toi : " .. (isFriend and "OUI" or "non"),
				"--- Chargement Roblox API... ---"
			})

			-- Fetch details Roblox (async, pcall, timeout 5s)
			task.spawn(function()
				local extra = {}
				pcall(function()
					local resp = game:HttpGet("https://users.roblox.com/v1/users/" .. plr.UserId, true)
					if resp and resp ~= "" then
						local d = HttpService:JSONDecode(resp)
						if d then
							table.insert(extra, "Cree le : " .. tostring(d.created or "?"))
							table.insert(extra, "Banni : " .. tostring(d.isBanned and "OUI" or "non"))
							if d.description and d.description ~= "" then
								local blurb = d.description:sub(1, 200)
								table.insert(extra, "Bio : " .. blurb .. (d.description:len() > 200 and "..." or ""))
							else
								table.insert(extra, "Bio : (vide)")
							end
						end
					end
				end)
				pcall(function()
					local resp = game:HttpGet("https://friends.roblox.com/v1/users/" .. plr.UserId .. "/friends/count")
					if resp and resp ~= "" then
						local d = HttpService:JSONDecode(resp)
						if d and d.count then
							table.insert(extra, "Amis : " .. tostring(d.count))
						end
					end
				end)
				pcall(function()
					local resp = game:HttpGet("https://users.roblox.com/v1/users/" .. plr.UserId .. "/groups")
					if resp and resp ~= "" then
						local d = HttpService:JSONDecode(resp)
						if d and d.data and #d.data > 0 then
							local n = math.min(3, #d.data)
							for i = 1, n do
								table.insert(extra, "Groupe : " .. (d.data[i].group and d.data[i].group.name or "?"))
							end
						end
					end
				end)
				-- Test rapide des APIs Roblox (peuvent etre bloquees par l'executeur)
				local apiOk = false
				pcall(function()
					if game and game.HttpGet then
						-- Test court : la 1ere API Roblox accessible
						local test = game:HttpGet("https://users.roblox.com/v1/users/" .. plr.UserId)
						if test and test ~= "" then apiOk = true end
					end
				end)
				if not apiOk then
					table.insert(extra, "---")
					table.insert(extra, "! APIs Roblox bloquees par l'executeur")
					table.insert(extra, "(presence, favoris, profil detailles indisponibles)")
				else
					-- Presence actuelle : est-ce qu'il joue EN CE MOMENT a ce jeu precis ?
					pcall(function()
						local resp = game:HttpGet("https://presence.roblox.com/v1/presence/users", true, HttpService:JSONEncode({userIds = {plr.UserId}}))
						if resp and resp ~= "" then
							local d = HttpService:JSONDecode(resp)
							if d and d.userPresences and d.userPresences[1] then
								local p = d.userPresences[1]
								-- userPresenceType: 0=Online, 1=InGame, 2=InStudio, 3=Offline
								-- userPresenceType+1: 1=Online, 2=InGame, 3=InStudio, 4=Offline (selon versions API)
								local t = tonumber(p.userPresenceType) or 0
								-- Detection plus fine du statut
								local status = "Inconnu"
								local statusIcon = "?"
								if t == 3 then
									status = "Hors ligne"
									statusIcon = "?"
								elseif t == 2 then
									status = "Au Studio (developpeur)"
									statusIcon = "?"
								elseif t == 1 then
									-- Il joue a un jeu
									if p.lastLocation and p.lastLocation ~= "" then
										status = "En jeu : " .. tostring(p.lastLocation)
									else
										status = "En jeu"
									end
									statusIcon = "?"
									if p.universeId and tostring(p.universeId) == tostring(game.GameId) then
										status = "? JOUE A CE JEU : " .. tostring(p.lastLocation or "")
										statusIcon = "?"
									end
								elseif t == 0 then
									-- Online : peut etre sur le site web / chat / pas dans un jeu
									if p.lastLocation and p.lastLocation ~= "" then
										-- Last location = dernier JEU ou il a joue
										status = "En ligne (dernier jeu : " .. tostring(p.lastLocation) .. ")"
										statusIcon = "?"
									else
										status = "En ligne (sur le site Roblox, pas dans un jeu)"
										statusIcon = "?"
									end
								end
								table.insert(extra, statusIcon .. " Statut : " .. status)
								if p.lastLocation and p.lastLocation ~= "" then
									table.insert(extra, "  ? Dernier jeu : " .. tostring(p.lastLocation))
								end
								if p.universeId then
									table.insert(extra, "  ? UniverseId : " .. tostring(p.universeId) .. (tostring(p.universeId) == tostring(game.GameId) and " (= CE JEU)" or ""))
								end
								if p.lastOnline then
									-- Parser lastOnline ISO -> delai relatif
									local y, mo, da, h, mi, s = p.lastOnline:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
									if y then
										local epochThen = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(da), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
										local diff = os.time() - epochThen
										if diff < 60 then
											table.insert(extra, "  ? Vu il y a : a l'instant")
										elseif diff < 3600 then
											table.insert(extra, "  ? Vu il y a : " .. math.floor(diff/60) .. " min")
										elseif diff < 86400 then
											table.insert(extra, "  ? Vu il y a : " .. math.floor(diff/3600) .. "h " .. math.floor((diff%3600)/60) .. "min")
										elseif diff < 2592000 then
											table.insert(extra, "  ? Vu il y a : " .. math.floor(diff/86400) .. "j " .. math.floor((diff%86400)/3600) .. "h")
										else
											table.insert(extra, "  ? Vu le : " .. tostring(p.lastOnline))
										end
									else
										table.insert(extra, "  ? Vu la derniere fois : " .. tostring(p.lastOnline))
									end
								end
							end
						end
					end)
					-- Jeux favoris (jusqu'a 5)
					pcall(function()
						local resp = game:HttpGet("https://games.roblox.com/v1/users/" .. plr.UserId .. "/favorite/games?sortOrder=Desc&limit=5")
						if resp and resp ~= "" then
							local d = HttpService:JSONDecode(resp)
							if d and d.data and #d.data > 0 then
								table.insert(extra, "--- Jeux favoris (" .. #d.data .. ") ---")
								for i, g in ipairs(d.data) do
									if i > 5 then break end
									if g.name then
										local favName = g.name:sub(1, 40) .. (g.name:len() > 40 and "..." or "")
										local favNote = ""
										if g.universeId and tostring(g.universeId) == tostring(game.GameId) then
											favNote = " ? (CE JEU)"
										end
										table.insert(extra, "? " .. favName .. favNote)
									end
								end
							end
						end
					end)
					-- Methodes natives Roblox (marchent meme si l'executeur bloque HttpGet)
					table.insert(extra, "---")
					-- Membership (Premium/BC)
					local mt = tostring(plr.MembershipType):gsub("Enum.MembershipType.", "")
					local isPremium = (mt == "Premium" or plr.MembershipType == Enum.MembershipType.Premium)
					table.insert(extra, "? " .. (isPremium and "Premium" or "Non-Premium") .. (mt ~= "None" and mt ~= "Premium" and (" (" .. mt .. ")") or ""))
					-- Network ping (latence)
					pcall(function()
						local ping = plr:GetNetworkPing()
						local pingIcon = "?"
						if ping > 0.2 then pingIcon = "?" elseif ping > 0.4 then pingIcon = "?" end
						table.insert(extra, pingIcon .. " Ping : " .. math.floor(ping * 1000) .. " ms")
					end)
					-- Ami avec moi ?
					if LocalPlayer and plr ~= LocalPlayer then
						pcall(function()
							local isFriend = LocalPlayer:IsFriendsWith(plr.UserId)
							if isFriend then
								table.insert(extra, "? Ami avec toi : OUI")
							end
						end)
					end
					-- Joue a CE JEU (verif locale, pas besoin d'API)
					if plr ~= LocalPlayer then
						local placeId = game.PlaceId
						pcall(function()
							local hasAsset = game:GetService("MarketplaceService"):UserOwnsGamePassAsync(plr.UserId, 0)
						end)
						-- Si le player est dans CE JEU, son GameId = placeId
						if plr.GameId and tostring(plr.GameId) == tostring(placeId) then
							table.insert(extra, "? EST DANS CE JEU MAINTENANT")
						end
					end
					end
					-- Concat avec contenu initial
					local base = {
						"Display : " .. plr.DisplayName,
						"Username : @" .. plr.Name,
						"UserId : " .. plr.UserId,
						"Compte : " .. years .. (years <= 1 and " an " or " ans ") .. rem .. "j (" .. days .. " jours)",
						"Ami avec toi : " .. (isFriend and "OUI" or "non")
					}
					setText(table.concat(base, "\n") .. "\n" .. table.concat(extra, "\n"))
					end)
					end)
					end)

					playerCards[plr] = card
					return card
					end

function addPlayerCard(plr)
	if plr == LocalPlayer then return end
	if playerCards[plr] and playerCards[plr].Parent then return end
	createPlayerEntry(plr)
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

_G.createPlayerEntry = createPlayerEntry
_G.addPlayerCard = addPlayerCard

function removePlayerCard(plr)
	if playerCards[plr] then
		playerCards[plr]:Destroy()
		playerCards[plr] = nil
	end
_G.removePlayerCard = removePlayerCard
	if selectedEchoPlayer == plr then
		selectedEchoPlayer = nil
		echoStatusLabel.Text = "Echo: aucun"
		echoStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	end
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

function refreshPlayersList()
	local existing = {}
	for plr, card in pairs(playerCards) do
		if card and card.Parent then
			existing[plr] = true
		else
			playerCards[plr] = nil
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and not existing[plr] then
			createPlayerEntry(plr)
		end
	end
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

_G.refreshPlayersList = refreshPlayersList

Players.PlayerAdded:Connect(function(plr)
	task.wait(0.3)
	addPlayerCard(plr)
end)
Players.PlayerRemoving:Connect(function(plr)
	task.wait(0.1)
	removePlayerCard(plr)
end)
playersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end)
refreshPlayersList()

-- Pop-up de restauration au demarrage
if panelMemory.lastEchoPlayerName and not panelMemory.dontAskRestore then
	task.delay(1.5, function()
		showRestorePopup(panelMemory.lastEchoPlayerName)
	end)
end

-- searchBox de Joueurs supprimee (doublon avec Registry)
-- Plus de filtre local ici, le filtrage se fait dans Registry
-- Toutes les cartes sont toujours visibles par defaut
for plr, card in pairs(playerCards) do
	if card then
		card.Visible = true
	end
end

-- ECHO CHAT
local function sendEchoMessage(text)
	local channels = TextChatService:FindFirstChild("TextChannels")
	if not channels then return end
	local general = channels:FindFirstChild("RBXGeneral")
	if not general then return end
	pcall(function() general:SendAsync(text) end)
end
_G.sendEchoMessage = sendEchoMessage

TextChatService.MessageReceived:Connect(function(msg)
	if not selectedEchoPlayer then return end
	local src = msg.TextSource
	if not src then return end
	local sender = Players:GetPlayerByUserId(src.UserId)
	if sender ~= selectedEchoPlayer then return end
	task.spawn(sendEchoMessage, msg.Text)
end)


updateLoad(0.15, "ESP...")
task.wait(0.05)

-- BRIDGE: save Part 1 locals for Part 2
_G._P1 = {}
_G._P1.Camera = Camera
_G._P1.HttpService = HttpService
_G._P1.Lighting = Lighting
_G._P1.LocalPlayer = LocalPlayer
_G._P1.Mouse = Mouse
_G._P1.Players = Players
_G._P1.ReplicatedStorage = ReplicatedStorage
_G._P1.RunService = RunService
_G._P1.UserInputService = UserInputService
_G._P1.Workspace = Workspace
_G._P1.character = character
_G._P1.closeBtn = closeBtn
_G._P1.espState = espState
_G._P1.extraPage = extraPage
_G._P1.flyState = flyState
_G._P1.flySwitch = flySwitch
_G._P1.gotoWalkState = gotoWalkState
_G._P1.humanoid = humanoid
_G._P1.loadingGui = loadingGui
_G._P1.localPage = localPage
_G._P1.localScroll = localScroll
_G._P1.localState = localState
_G._P1.mainFrame = mainFrame
_G._P1.noclipState = noclipState
_G._P1.noclipSwitch = noclipSwitch
_G._P1.pages = pages
_G._P1.panelMemory = panelMemory
_G._P1.platformState = platformState
_G._P1.protectionsScroll = protectionsScroll
_G._P1.registryLayout = registryLayout
_G._P1.registryPage = registryPage
_G._P1.registryScroll = registryScroll
_G._P1.remotesPage = remotesPage
_G._P1.rootPart = rootPart
_G._P1.screenGui = screenGui
_G._P1.walkSpeedState = walkSpeedState
_G._P1.zeroGSwitch = zeroGSwitch
_G._P1.jumpState = jumpState
_G._P1.TweenService = TweenService
_G._P1.movePage = movePage
_G._P1.activeTab = activeTab
_G._P1.tabButtons = tabButtons
_G._P1.contentFrame = contentFrame
_G._P1.tabBar = tabBar
_G._P1.topBar = topBar
_G._P1.playersPage = playersPage
_G._P1.homePage = homePage
_G._P1.protectionsPage = protectionsPage
_G._P1.HttpService = HttpService
_G._P1.Mouse = Mouse
_G._P1.ReplicatedStorage = ReplicatedStorage

-- SAFETY NET: reveal panel + switchTab + destroy loading GUI even if Part 2 crashes
-- This runs in p1 so the panel is ALWAYS visible even if p2 fails to load
task.delay(8, function()
	pcall(function()
		if mainFrame and not mainFrame.Visible then
			warn("[AGORA] Safety net: forcing panel visible (p2 may have failed)")
			mainFrame.Visible = true
			mainFrame.BackgroundTransparency = 0.35
		end
	end)
	pcall(function()
		if pages and pages["Home"] and not pages["Home"].Visible then
			switchTab("Home")
		end
	end)
	pcall(function()
		if loadingGui and loadingGui.Parent then
			loadingGui:Destroy()
		end
	end)
end)

-- Destroy loading GUI early (it was never visible anyway, all transparency=1)
pcall(function() if loadingGui and loadingGui.Parent then loadingGui:Destroy() end end)

task.spawn(function()
	local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p2.lua&nocache=" .. tick()
	local ok, code = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and code and #code > 100 then
		local fn, err = loadstring(code)
		if fn then
			local ok2, err2 = pcall(fn)
			if not ok2 then
				warn("[AGORA] Part 2 runtime error: " .. tostring(err2))
			end
		else
			warn("[AGORA] Part 2 load error: " .. tostring(err))
		end
	else
		warn("[AGORA] Part 2 fetch failed")
	end
end)

if _G._agoraAU then return end
_G._agoraAU = true
local CV = "v39.53"
local VURL = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_version.lua&nocache="
local uP, lUC, uD = nil, 0, false
local function cFU()
	if uP or uD then return end
	if tick()-lUC<55 then return end
	lUC=tick()
	task.spawn(function()
		local ok,r=pcall(function() return game:HttpGet(VURL..tostring(tick()),true) end)
		if not ok or not r or #r<5 then return end
		local rv=r:match('return%s+"(v[%d%.]+)"')
		if not rv or rv==CV then return end
		task.spawn(function()
			local sg=Instance.new("ScreenGui")
			sg.Name="AgoraUpd"
			sg.ResetOnSpawn=false
			sg.DisplayOrder=99999
			local ok2,par=pcall(function() return game:GetService("CoreGui") end)
			if not ok2 or not par then par=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
			sg.Parent=par
			local f=Instance.new("Frame")
			f.Size=UDim2.new(0,280,0,120)
			f.Position=UDim2.new(1,-300,1,-140)
			f.BackgroundColor3=Color3.fromRGB(30,30,40)
			f.BorderSizePixel=0
			f.Parent=sg
			local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,10) c.Parent=f
			local s=Instance.new("UIStroke") s.Color=Color3.fromRGB(100,200,255) s.Thickness=2 s.Parent=f
			local t=Instance.new("TextLabel")
			t.Size=UDim2.new(1,0,0,30)
			t.BackgroundTransparency=1
			t.Text="Mise a jour disponible"
			t.TextColor3=Color3.fromRGB(100,200,255)
			t.Font=Enum.Font.GothamBold
			t.TextSize=15
			t.Parent=f
			local d=Instance.new("TextLabel")
			d.Size=UDim2.new(1,-20,0,35)
			d.Position=UDim2.new(0,10,0,32)
			d.BackgroundTransparency=1
			d.Text="Version "..rv.." disponible\nVous avez "..CV
			d.TextColor3=Color3.fromRGB(200,200,210)
			d.Font=Enum.Font.Gotham
			d.TextSize=13
			d.TextWrapped=true
			d.Parent=f
			local yB=Instance.new("TextButton")
			yB.Size=UDim2.new(0,100,0,32)
			yB.Position=UDim2.new(0,15,0,75)
			yB.BackgroundColor3=Color3.fromRGB(80,180,100)
			yB.Text="Oui"
			yB.TextColor3=Color3.fromRGB(255,255,255)
			yB.Font=Enum.Font.GothamBold
			yB.TextSize=14
			yB.Parent=f
			local yC=Instance.new("UICorner") yC.CornerRadius=UDim.new(0,6) yC.Parent=yB
			local nB=Instance.new("TextButton")
			nB.Size=UDim2.new(0,100,0,32)
			nB.Position=UDim2.new(0,130,0,75)
			nB.BackgroundColor3=Color3.fromRGB(60,60,70)
			nB.Text="Plus tard"
			nB.TextColor3=Color3.fromRGB(200,200,210)
			nB.Font=Enum.Font.Gotham
			nB.TextSize=14
			nB.Parent=f
			local nC=Instance.new("UICorner") nC.CornerRadius=UDim.new(0,6) nC.Parent=nB
			uP=sg
			yB.MouseButton1Click:Connect(function()
				if _G._agoraShutdown then _G._agoraShutdown() end
				if shutdownPanel then shutdownPanel() end
				sg:Destroy() uP=nil
				task.spawn(function()
					local aG=Instance.new("ScreenGui")
					aG.Name="AgoraUpdAnim"
					aG.ResetOnSpawn=false
					aG.DisplayOrder=99999
					local ok3,par2=pcall(function() return game:GetService("CoreGui") end)
					if not ok3 or not par2 then par2=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
					aG.Parent=par2
					local aF=Instance.new("Frame")
					aF.Size=UDim2.new(0,320,0,80)
					aF.Position=UDim2.new(0.5,-160,0.5,-40)
					aF.BackgroundColor3=Color3.fromRGB(25,25,35)
					aF.BorderSizePixel=0
					aF.Parent=aG
					local aC2=Instance.new("UICorner") aC2.CornerRadius=UDim.new(0,12) aC2.Parent=aF
					local aS2=Instance.new("UIStroke") aS2.Color=Color3.fromRGB(100,200,255) aS2.Thickness=2 aS2.Parent=aF
					local aL=Instance.new("TextLabel")
					aL.Size=UDim2.new(1,0,1,0)
					aL.BackgroundTransparency=1
					aL.Text="Mise a jour en cours..."
					aL.TextColor3=Color3.fromRGB(100,200,255)
					aL.Font=Enum.Font.GothamBold
					aL.TextSize=16
					aL.Parent=aF
					task.wait(1.5)
					pcall(function()
						for _,g in ipairs(par2:GetChildren()) do
							if g:IsA("ScreenGui") and (g.Name:match("Agora") or g.Name:match("Milan")) then g:Destroy() end
						end
					end)
					aL.Text="Redemarrage..."
					task.wait(0.5)
					local rU="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p1.lua&nocache="..tostring(tick())
					local okR,code=pcall(function() return game:HttpGet(rU,true) end)
					if okR and code and #code>100 then
						aG:Destroy()
						local fn=loadstring(code)
						if fn then pcall(fn) end
					else
						aL.Text="Erreur de chargement"
						task.wait(2) aG:Destroy()
					end
				end)
			end)
			nB.MouseButton1Click:Connect(function()
				sg:Destroy() uP=nil uD=true
				task.delay(300,function() uD=false end)
			end)
		end)
	end)
end
task.delay(10,function()
	while true do pcall(cFU) task.wait(60) end
end)
