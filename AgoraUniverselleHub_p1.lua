-- Agora Hub [UNIVERSELLE] - Panel Roblox universel
-- LocalScript dans StarterPlayerScripts ou executeur
-- v39.42-fix1

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
			local success, canChat = pcall(function()
				return UserInputService:GetPlatform() == Enum.Platform.Windows and UserInputService:GetMouseButtonsPressed()
			end)
			if success then
				result, src = canChat, "UserInputService"
			end
		end

		-- 3) TextChatService (si disponible)
		if result == nil and TextChatService then
			local success, canChat = pcall(function()
				return TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
			end)
			if success then
				result, src = canChat, "TextChatService"
			end
		end

		-- 4) Fallback: assume true if we can't determine
		if result == nil then
			result, src = true, "assumed"
		end

		if callback then
			task.spawn(function()
				callback(result, src)
			end)
		end
	end)
end

-- Fallback for older executors: if shared is not available, try to get game from getfenv(0)
if not _game then
	local ok, g = pcall(function() return getfenv(0).game end)
	if ok and g then _game = g end
end

-- Ensure we have a valid game reference
if not _game then
	warn("[AGORA] Could not obtain game reference after fallbacks")
	return
end

-- Main panel logic wrapped in a function to avoid exceeding 200 local vars limit in a single chunk (Solara)
local function main()
	-- Services
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local HttpService = game:GetService("HttpService")
	local SoundService = game:GetService("SoundService")
	local TextChatService = game:GetService("TextChatService")

	-- Players
	local LocalPlayer = Players.LocalPlayer
	local Mouse = LocalPlayer:GetMouse()
	local Camera = Workspace.CurrentCamera

	-- Settings from _G.SETTINGS (set at top of script)
	local SETTINGS = _G.SETTINGS

	-- Character references (updated on respawn)
	local character, humanoid, rootPart

	-- Shared state between parts
	_G._P1 = {}

	local panelMemory = _G.PanelMemory
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
-- Helper HTTP multi-executeur (essaie game:HttpGet, GetAsync, request/syn.request)
local function httpGet(url)
	-- 1) game:HttpGet (Solara, etc.)
	local ok, r = pcall(function() return game:HttpGet(url) end)
	if ok and r and r ~= "" then return r end
	-- 2) HttpService:GetAsync (Studio-like)
	ok, r = pcall(function() return HttpService:GetAsync(url) end)
	if ok and r and r ~= "" then return r end
	-- 3) request / syn.request (Synapse, Fluxus, etc.)
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		ok, r = pcall(function() return req({Url=url, Method="GET"}).Body end)
		if ok and r and r ~= "" then return r end
	end
	return nil
end

local function httpPost(url, body)
	-- 1) game:HttpPostJSON / HttpGet avec body
	local ok, r = pcall(function() return game:HttpGet(url, true, body) end)
	if ok and r and r ~= "" then return r end
	-- 2) HttpService:PostAsync
	ok, r = pcall(function() return HttpService:PostAsync(url, body) end)
	if ok and r and r ~= "" then return r end
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
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AgoraUniverselleHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10)
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
mainFrame.BackgroundTransparency = 0.35
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 1
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(120, 120, 150), 1.2)

-- ===== INTRO CINEMA : "Agora Hub" puis TAMPON "UNIVERSELLE" BOUM =====
-- Backdrop full screen noir pour masquer le panel pendant l'intro
;(function()
	local _mainFrame = mainFrame
	local _screenGui = screenGui
	local _LocalPlayer = LocalPlayer
	local _TweenService = TweenService
	local _tween = tween
	local _createCorner = createCorner

	local bootGui = Instance.new("ScreenGui")
	bootGui.Name = "AgoraUniverselleIntro"
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

	-- Sous-titre fin "by Agora Admin" en gris clair
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.9, 0, 0, 20)
	subtitle.Position = UDim2.new(0.05, 0, 0.45, 36)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "by Emerick"
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
			playSound(9114850423, 0.5)
			backdrop.BackgroundTransparency = 0

			-- Etape 2 : titre "Agora Hub" fade in (0.5s) + ding doux
			task.wait(0.3)
			_tween(title, {TextTransparency = 0}, 0.5)
			_tween(subtitle, {TextTransparency = 0}, 0.5)
			playSound(6042053626, 0.25)

			-- Etape 3 : pause 1s pour lire le titre
			task.wait(1.0)

			-- Etape 4 : BOUM - flash blanc brutal + tag scale 01.31 + boom impact fort
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

			-- Etape 5 : le tag reste affiche 1.2s
			task.wait(1.2)

			-- Etape 6 : fade out de tout
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
			warn("[AGORA] Intro crash: " .. tostring(err))
		end

		-- Cleanup + revelation du panel
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

-- Logo a gauche du titre + badge "UNIVERSELLE" penche (mini) a droite du titre
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
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar
createCorner(closeBtn, 8)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -68, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
minimizeBtn.Text = ""
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

makeIcon(closeBtn, "")
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
	btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = color and color * 1.15 or Color3.fromRGB(60, 95, 200)}, 0.1) end)
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
	btn.TextSize = 11
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
	local playersPage = createTab("Joueurs")
	local movePage = createTab("Move")
	local extraPage = createTab("Extra")
	local remotesPage = createTab("Remotes")
	local registryPage = createTab("Registry")
	local localPage = createTab("Local")
	local protectionsPage = createTab("Protections")
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
local flyState = { flying = false, speed = 120, gyro = nil, vel = nil, loop = nil, mobileInput = Vector3.zero, mobileUp = false, mobileDown = false, mobileStickId = nil, mobileBase = nil, mobileKnob = nil, mobileBasePos = nil, mobileUiCreated = false }
local noclipState = { enabled = false }
local walkSpeedState = { value = 16 }
local jumpState = { infinite = false }
local platformState = { enabled = false, part = nil, y = 0, offset = 0 }

local function stopFly()
	if not flyState.flying then return end
	flyState.flying = false
	if flyState.loop then flyState.loop:Disconnect() flyState.loop = nil end
	if flyState.gyro then flyState.gyro:Destroy() flyState.gyro = nil end
	if flyState.vel then flyState.vel:Destroy() flyState.vel = nil end
	local noclipState = { enabled = false }
	_G._P1.noclipState = noclipState

	-- ============= WALKSPEED STATE =============
	local walkSpeedState = { value = 16 }
	_G._P1.walkSpeedState = walkSpeedState

	-- ============= JUMP STATE =============
	local jumpState = { infinite = false }
	_G._P1.jumpState = jumpState

	-- ============= PLATFORM STATE =============
	local platformState = { enabled = false, part = nil, y = 0, offset = 0 }
	_G._P1.platformState = platformState

	-- ============= FLY SWITCH (forward declared) =============
	local flySwitch  -- forward-declare (assigned later)
	_G._P1.flySwitch = flySwitch

	-- ============= ESP STATE =============
	local espState = { enabled = false, players = {}, objects = {}, colors = { ally = Color3.fromRGB(0, 255, 0), enemy = Color3.fromRGB(255, 0, 0), neutral = Color3.fromRGB(255, 255, 0) } }
	_G._P1.espState = espState

	-- ============= EXTRA PAGE =============
	local extraPage = nil
	_G._P1.extraPage = extraPage

	-- ============= MOVE PAGE =============
	local movePage = nil
	_G._P1.movePage = movePage

	-- ============= REMOTES PAGE =============
	local remotesPage = nil
	_G._P1.remotesPage = remotesPage

	-- ============= REGISTRY PAGE =============
	local registryPage = nil
	_G._P1.registryPage = registryPage

	-- ============= LOCAL PAGE =============
	local localPage = nil
	_G._P1.localPage = localPage

	-- ============= PROTECTIONS PAGE =============
	local protectionsPage = nil
	_G._P1.protectionsPage = protectionsPage

	-- ============= SETTINGS PAGE =============
	local settingsPage = nil
	_G._P1.settingsPage = settingsPage

	-- ============= ABOUT PAGE =============
	local aboutPage = nil
	_G._P1.aboutPage = aboutPage
	local flySwitch  -- forward-declare (assigned later)
	-- ============= FUNCTIONS =============

	local function stopFly()
		if not flyState.flying then return end
		flyState.flying = false
		if flyState.loop then flyState.loop:Disconnect() flyState.loop = nil end
		if flyState.saMode then
			-- SA mode: unanchor
			if flyState.anchored then
				pcall(function()
					if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
						LocalPlayer.Character.PrimaryPart.Anchored = false
					end
				end)
				flyState.anchored = false
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
			end
		else
			-- NORMAL MODE: destroy body movers
			if flyState.gyro then flyState.gyro:Destroy() flyState.gyro = nil end
			if flyState.vel then flyState.vel:Destroy() flyState.vel = nil end
		end
		flyState.mobileInput = Vector3.zero
		flyState.mobileUpHeld = false
		flyState.mobileDownHeld = false
		if flyState.showMobileUi then flyState.showMobileUi(false) end
		updateCharacter()
	end

	local function startFly()
		if flyState.flying then return end
		if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
		flyState.flying = true
		flyState.saMode = isServerAuthority()
		if flyState.saMode then
			-- SERVER AUTHORITY BYPASS: Anchored + CFrame (BodyVelocity rolled back by server)
			if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
				pcall(function()
					LocalPlayer.Character.PrimaryPart.Anchored = true
				end)
				flyState.anchored = true
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = true
			end
		else
			-- NORMAL MODE: BodyVelocity + BodyGyro
			if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
				flyState.gyro = Instance.new("BodyGyro")
				flyState.gyro.P = 9e4
				flyState.gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
				flyState.gyro.CFrame = LocalPlayer.Character.PrimaryPart.CFrame
				flyState.gyro.Parent = LocalPlayer.Character.PrimaryPart

				flyState.vel = Instance.new("BodyVelocity")
				flyState.vel.Velocity = Vector3.zero
				flyState.vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
				flyState.vel.Parent = LocalPlayer.Character.PrimaryPart
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = true
			end
		end
		flyState.liftOffTime = tick() + 1.0
		flyState.loop = RunService.RenderStepped:Connect(function()
			updateCharacter()
			if not flyState.flying or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart or not LocalPlayer.Character.PrimaryPart.Parent then return end

			-- Calculer le mouvement AVANT le gyro (evite le forward-ref nil)
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Z) then move = move + Camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move = move - Camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
			if flyState.mobileInput and flyState.mobileInput.Magnitude > 0 then
				move = move + Camera.CFrame.LookVector * flyState.mobileInput.Z + Camera.CFrame.RightVector * flyState.mobileInput.X
			end
			if flyState.mobileUpHeld then move = move + Vector3.new(0, 1, 0) end
			if flyState.mobileDownHeld then move = move - Vector3.new(0, 1, 0) end

			if flyState.saMode then
				-- SA BYPASS: CFrame-based fly (Anchored parts bypass server physics)
				local cf = LocalPlayer.Character.PrimaryPart.CFrame
				if move.Magnitude > 0.1 then
					local delta = move.Unit * flyState.speed * 0.016
					pcall(function() LocalPlayer.Character.PrimaryPart.CFrame = cf + delta end)
				end
				-- Orientation: yaw + dynamic pitch (same as normal fly)
				local camLook = Camera.CFrame.LookVector
				local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
				if flatLook.Magnitude > 0.01 then
					local yawCFrame = CFrame.new(LocalPlayer.Character.PrimaryPart.Position, LocalPlayer.Character.PrimaryPart.Position + flatLook)
					local camPitch = math.asin(math.clamp(camLook.Y, -1, 1))
					local movePitch = 0
					if move.Magnitude > 0.1 then
						local forwardDot = move:Dot(Camera.CFrame.LookVector)
						movePitch = math.clamp(forwardDot * 0.15, -0.26, 0.44)
					end
					local totalPitch = math.clamp(camPitch * 0.8 + movePitch, -0.7, 0.7) -- increased from 0.6
					pcall(function() LocalPlayer.Character.PrimaryPart.CFrame = yawCFrame * CFrame.Angles(totalPitch, 0, 0) end)
				end
			else
				-- NORMAL MODE: BodyVelocity + BodyGyro
				-- Re-attach body movers if rootPart changed (respawn)
				if flyState.gyro and flyState.gyro.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.gyro.Parent = LocalPlayer.Character.PrimaryPart end
				if flyState.vel and flyState.vel.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.vel.Parent = LocalPlayer.Character.PrimaryPart end

				-- Gyro: personnage droit + penche naturellement quand il bouge + s'incline selon ou on regarde
				if flyState.gyro then
					local camLook = Camera.CFrame.LookVector
					local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
					if flatLook.Magnitude > 0.01 then
						local yawCFrame = CFrame.new(LocalPlayer.Character.PrimaryPart.Position, LocalPlayer.Character.PrimaryPart.Position + flatLook)
						local camPitch = math.asin(math.clamp(camLook.Y, -1, 1))
						local movePitch = 0
						if move.Magnitude > 0.1 then
							local forwardDot = move:Dot(Camera.CFrame.LookVector)
							movePitch = math.clamp(forwardDot * 0.15, -0.26, 0.44)
						end
						local totalPitch = math.clamp(camPitch * 0.8 + movePitch, -0.7, 0.7) -- increased from 0.6
						flyState.gyro.CFrame = yawCFrame * CFrame.Angles(totalPitch, 0, 0)
					end
				end

				-- Velocity
				if flyState.vel then
					if move.Magnitude > 0 then
						flyState.vel.Velocity = move.Unit * flyState.speed
					else
						flyState.vel.Velocity = Vector3.zero
					end
				end
			end
		end)
	end

	-- ============= TOGGLE FLY =============
	local function toggleFly()
		if flyState.flying then
			stopFly()
		else
			startFly()
		end
	end

	-- ============= UPDATE CHARACTER =============
	local function updateCharacter()
		character = LocalPlayer.Character
		if character then
			humanoid = character:FindFirstChildOfClass("Humanoid")
			rootPart = character:FindFirstChild("HumanoidRootPart")
		else
			humanoid, rootPart = nil, nil
		end
		if not LocalPlayer.Character then return end
		-- Update character references for fly state (used in loop)
		if flyState.flying then
			if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
				-- Ensure body movers are parented to the current character (respawn handling)
				if flyState.gyro and flyState.gyro.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.gyro.Parent = LocalPlayer.Character.PrimaryPart end
				if flyState.vel and flyState.vel.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.vel.Parent = LocalPlayer.Character.PrimaryPart end
			end
		end
	end

	-- ============= SERVER AUTHORITY CHECK =============
	local function isServerAuthority()
		-- Placeholder: in a real implementation, this would check if the game has Server Authority enabled
		-- For now, we assume false (most games don't have it enabled)
		return false
	end

	-- ============= MOBILE UI =============
	local function createMobileUi()
		if flyState.mobileUiCreated then return end
		flyState.mobileUiCreated = true
		-- Implementation omitted for brevity
	end
local function shutdownPanel()
	if flyState and flyState.flying then stopFly() end
	if noclipState and noclipState.enabled then
		noclipState.enabled = false
		if noclipSwitch then noclipSwitch.set(false) end
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = true end
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
end
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

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 48, 0, 24)
	track.Position = UDim2.new(1, -60, 0.5, -12)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	track.BorderSizePixel = 0
	track.Parent = container
	createCorner(track, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 20, 0, 20)
	knob.Position = UDim2.new(0, 2, 0.5, -10)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track
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
local function createSlider(parent, labelText, yPos, min, max, default, callback, color, decimals, step)
	decimals = decimals or 0
	step = step or nil
	local function fmt(v)
		local mult = 10 ^ decimals
		return math.floor(v * mult + 0.5) / mult
	end
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -16, 0, 50)
	container.Position = UDim2.new(0, 8, 0, yPos)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	container.BorderSizePixel = 0
	container.Parent = parent
	createCorner(container, 8)
	createStroke(container, Color3.fromRGB(45, 45, 55), 1)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 18)
	label.Position = UDim2.new(0, 8, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = labelText .. ": " .. fmt(default)
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(210, 210, 210)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 6)
	track.Position = UDim2.new(0, 8, 0, 30)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	track.BorderSizePixel = 0
	track.Parent = container
	createCorner(track, 3)

	-- Bouton invisible par-dessus le track pour capter TOUS les clics (sinon certains
	-- clics sur le container parent sont perdus  le slider "marche mal")
	local hitButton = Instance.new("TextButton")
	hitButton.Size = UDim2.new(1, 0, 0, 24)
	hitButton.Position = UDim2.new(0, 0, 0, 21)
	hitButton.BackgroundTransparency = 1
	hitButton.Text = ""
	hitButton.BorderSizePixel = 0
	hitButton.AutoButtonColor = false
	hitButton.ZIndex = 10
	hitButton.Parent = container

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = color or Color3.fromRGB(80, 150, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track
	createCorner(fill, 3)

	local value = default
	local draggingSlider = false
	local function setFromInput(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		value = min + rel * (max - min)
		if step and step > 0 then
			value = math.round(value / step) * step
		end
		value = fmt(value)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		label.Text = labelText .. ": " .. value
		callback(value)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			setFromInput(input.Position.X)
		end
	end)
	-- Hit invisible capte les clics n'importe ou sur la zone (Y=21..45), pas seulement le track (6px)
	hitButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			setFromInput(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromInput(input.Position.X)
		end
	end)
	return {
		get = function() return value end,
		set = function(v)
			v = math.clamp(v, min, max)
			if step and step > 0 then v = math.round(v / step) * step end
			value = fmt(v)
			local rel = (v - min) / (max - min)
			fill.Size = UDim2.new(rel, 0, 1, 0)
			label.Text = labelText .. ": " .. value
			callback(v)
		end
	}
end
local flySwitch = createSwitch(movePage, "Fly", 10, function(on)
	if on then startFly() else stopFly() end
end)

local flySlider = createSlider(movePage, "Vitesse Fly", 52, 20, 500, flyState.speed, function(v)
	flyState.speed = math.floor(v)
end, Color3.fromRGB(100, 180, 255))

local noclipSwitch = createSwitch(movePage, "NoClip", 108, function(on)
	noclipState.enabled = on
	if not on then
		updateCharacter()
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = true end
			end
		end
		-- Active la grace anti-TP apres sortie du noclip
		if protectionsState then
			protectionsState.antiTeleportGraceUntil = tick() + 0.4
		end
	end
end)
local gotoWalkState = {
	enabled = false,
	active = false,
	target = nil,
	path = {},
	visuals = {},
	lastClick = 0,
	lastMoveTo = nil,
	recompute = nil,
	busy = false,
	followConnection = nil,
	stuckTimer = 0,
	stuckPos = nil,
	stuckJumps = 0,
	currentWaypointIdx = 1,
	lastJumpTime = 0,
}

local localState = {
	zeroGravity = false,
	normalGravity = Workspace.Gravity,
	customGravity = 196.2,
	timeOfDay = 12,
}

local zeroGSwitch = createSwitch(localPage, "Zero Gravite", 10, function(on)
	localState.zeroGravity = on
	if on then
		Workspace.Gravity = 0
	else
		Workspace.Gravity = localState.customGravity
	end

	if character then
		local hum = character:FindFirstChildWhichIsA("Humanoid")
		local animate = character:FindFirstChild("Animate")
		if hum then
			hum.PlatformStand = on
			if animate then animate.Disabled = on end
			if on then
				for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
				for _, sound in pairs(character:GetDescendants()) do
					if sound:IsA("Sound") then sound:Stop() end
				end
			end
		end
	end
	end)

	-- ============= EXPORT TO _G._P1 =============
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
	_G._P1.createCorner = createCorner
	_G._P1.createStroke = createStroke
	_G._P1.tween = tween
	_G._P1.createSwitch = createSwitch
	_G._P1.createButton = createButton
	_G._P1.createSlider = createSlider
	_G._P1.createTab = createTab
	_G._P1.switchTab = switchTab
	_G._P1.shutdownPanel = shutdownPanel
	_G._P1.startFly = startFly
	_G._P1.stopFly = stopFly
	_G._P1.updateLoad = updateLoad
	_G._P1.updateCharacter = updateCharacter
	_G._P1.flyState = flyState
	_G._P1.flySwitch = flySwitch
	_G._P1.noclipState = noclipState
	_G._P1.noclipSwitch = noclipSwitch
	_G._P1.walkSpeedState = walkSpeedState
	_G._P1.jumpState = jumpState
	_G._P1.platformState = platformState
	_G._P1.espState = espState
	_G._P1.pages = pages
	_G._P1.mainFrame = mainFrame
	_G._P1.screenGui = screenGui
	_G._P1.closeBtn = closeBtn
	_G._P1.loadingGui = loadingGui
	_G._P1.extraPage = extraPage
	_G._P1.movePage = movePage
	_G._P1.remotesPage = remotesPage
	_G._P1.registryPage = registryPage
	_G._P1.localPage = localPage
	_G._P1.protectionsPage = protectionsPage
	_G._P1.character = character
	_G._P1.humanoid = humanoid
	_G._P1.rootPart = rootPart
	_G._P1.localScroll = localScroll
	_G._P1.localState = localState
	_G._P1.panelMemory = panelMemory
	_G._P1.protectionsScroll = protectionsScroll
	_G._P1.registryScroll = registryScroll
	_G._P1.registryLayout = registryLayout
	_G._P1.gotoWalkState = gotoWalkState
	_G._P1.zeroGSwitch = zeroGSwitch

	_G.createStroke = createStroke
	_G.tween = tween
	_G.createSwitch = createSwitch
	_G.createButton = createButton
	_G.createSlider = createSlider
	_G.createTab = createTab
	_G.switchTab = switchTab
	_G.shutdownPanel = shutdownPanel
	_G.startFly = startFly
	_G.stopFly = stopFly
	_G.updateLoad = updateLoad
	_G.updateCharacter = updateCharacter
	_G.createToggle = createToggle
	_G.createSection = createSection
	_G.createInput = createInput
	_G.createDropdown = createDropdown
	_G.fullbrightSwitch = fullbrightSwitch
	_G.espSwitch = espSwitch
	_G.noclipState = noclipState
	_G.walkSpeedState = walkSpeedState
	_G.jumpState = jumpState
	_G.platformState = platformState
	_G.espState = espState
	_G.flyState = flyState
	_G.flySwitch = flySwitch
	_G.zeroGSwitch = zeroGSwitch
	_G.fullbrightState = fullbrightState
	_G.clickTPState = clickTPState
	_G.hitboxState = hitboxState
	_G.protectionsState = protectionsState
	_G.autoClickState = autoClickState
	_G.gotoWalkState = gotoWalkState
	_G.localState = localState
	_G.panelMemory = panelMemory
	_G.extraScroll = extraScroll
	_G.localScroll = localScroll
	_G.protectionsScroll = protectionsScroll
	_G.registryScroll = registryScroll
	_G.registryLayout = registryLayout
	_G.serverScroll = serverScroll
	_G.extraPage = extraPage
	_G.movePage = movePage
	_G.remotesPage = remotesPage
	_G.registryPage = registryPage
	_G.localPage = localPage
	_G.protectionsPage = protectionsPage
	_G.settingsPage = settingsPage
	_G.aboutPage = aboutPage
	_G.pages = pages
	_G.mainFrame = mainFrame
	_G.screenGui = screenGui
	_G.closeBtn = closeBtn
	_G.loadingGui = loadingGui
	_G.rootPart = rootPart
	_G.humanoid = humanoid
	_G.character = character
	_G.Camera = Workspace.CurrentCamera
	_G.HttpService = game:GetService("HttpService")
	_G.Lighting = game:GetService("Lighting")
	_G.LocalPlayer = LocalPlayer
	_G.Mouse = LocalPlayer:GetMouse()
	_G.Players = Players
	_G.ReplicatedStorage = game:GetService("ReplicatedStorage")
	_G.RunService = RunService
	_G.UserInputService = UserInputService
	_G.Workspace = Workspace

	local p2fn, p2err = loadstring(p2code)
	if not p2fn then
		updateLoad(1.0, "ERREUR: " .. tostring(p2err))
		task.wait(2)
		loadingGui:Destroy()
		warn("[AGORA] p2 syntax error: " .. tostring(p2err))
		return
	end
	
	updateLoad(1.0, "Pret!")
	task.wait(0.3)
	loadingGui:Destroy()
	
	-- Run p2
	local ok, err = pcall(p2fn)
	if not ok then
		warn("[AGORA] p2 runtime error: " .. tostring(err))
	end

end
end
end
end

-- Run the main function
main()
