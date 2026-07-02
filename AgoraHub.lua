-- Agora Hub [UNIVERSELLE] - Panel Roblox universel
-- LocalScript dans StarterPlayerScripts ou exécuteur

local SETTINGS = {
	SpiderSpeed = 16,
	SpiderHoverDistance = 2.6,
	SpiderNetworkCompensation = 0.8,
	SpiderJumpPower = 60,
	SpiderJumpCooldown = 0.5,
	SpiderTransitionSpeed = 15
}

-- SAFEGUARD EXECUTEUR: certains loadstring ne passent pas 'game' en global #1
-- On récupère game via getfenv ou le premier argument de loadstring
if not game then
	local ok, envGame = pcall(function() return getfenv().game end)
	if ok and envGame then
		game = envGame
	end
end

-- WRAP PANEL IN LOCAL FUNCTION to avoid Solara 200-register chunk limit
local function _buildPanel()
if not game then
	warn("[AGORA] game est nil — exécuteur incompatible ou loadstring mal formé")
	return
end

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

-- Helper HTTP multi-exécuteur (essaie game:HttpGet, GetAsync, request/syn.request)
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
	if flyState.flying then
		stopFly()
	end
	if noclipState.enabled then
		noclipState.enabled = false
		refreshNoClipSwitch()
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
	btn.Size = UDim2.new(0.135, -2, 1, 0)
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
-- ============= REGISTRY CHARGÉ VIA LOADSTRING =============
;(function(_registryPage)
	task.spawn(function()
		local projectRef = "hlxbqtayotwdtspkrlol"
		local url = "https://" .. projectRef .. ".supabase.co/functions/v1/agora-universelle?file=AgoraTab_Registry.lua&nocache=" .. tick()
		local ok, src = pcall(function() return game:HttpGet(url) end)
		if not ok or not src or src == "" then
			warn("[AGORA] Impossible de charger Registry: " .. tostring(src))
			local err = Instance.new("TextLabel")
			err.Size = UDim2.new(1, -20, 0, 60)
			err.Position = UDim2.new(0, 10, 0, 10)
			err.BackgroundTransparency = 1
			err.Text = "Registre indisponible (réseau/exécuteur)."
			err.TextWrapped = true
			err.TextColor3 = Color3.fromRGB(200, 80, 80)
			err.Font = Enum.Font.Gotham
			err.TextSize = 12
			err.Parent = _registryPage
			return
		end
		local fn, ferr = loadstring(src)
		if not fn then
			warn("[AGORA] Erreur loadstring Registry: " .. tostring(ferr))
			return
		end
		local build = fn()
		if type(build) ~= "function" then
			warn("[AGORA] Registry n'a pas retourné une fonction")
			return
		end
		local ok2, err2 = pcall(function()
			build(_registryPage, {
				Players = Players, RunService = RunService, UserInputService = UserInputService,
				TextChatService = TextChatService, Workspace = Workspace, Lighting = Lighting,
				ReplicatedStorage = ReplicatedStorage, TweenService = TweenService,
				HttpService = HttpService, SoundService = SoundService,
				LocalPlayer = LocalPlayer, Camera = Camera, Mouse = Mouse,
				screenGui = screenGui, mainFrame = mainFrame,
				createCorner = createCorner, createStroke = createStroke, tween = tween,
				createButton = createButton, createTab = createTab, createSwitch = createSwitch,
				playSound = playSound, httpGet = httpGet, httpPost = httpPost,
				updateCharacter = updateCharacter, getDeviceType = getDeviceType,
			})
		end)
		if not ok2 then
			warn("[AGORA] Erreur exécution Registry: " .. tostring(err2))
		end
	end)
end)(registryPage)
-- ============= CRÉDITS =============
;(function(_mainFrame)
	local credits = Instance.new("TextLabel")
	credits.Size = UDim2.new(1, 0, 0, 18)
	credits.Position = UDim2.new(0, 0, 1, -20)
	credits.BackgroundTransparency = 1
	credits.Text = "Agora Universelle"
	credits.Font = Enum.Font.GothamBold
	credits.TextSize = 11
	credits.TextColor3 = Color3.fromRGB(140, 140, 180)
	credits.Parent = _mainFrame
end)(mainFrame)

-- BOOT SAFE 3 LAYERS:
-- Layer 1: reveal immédiat à 0.5s (filet de sécurité absolu)
-- Layer 2: reveal à 3s si pas encore visible (fallback)
-- Layer 3: switchTab après reveal (parse-time IIFE) + bootSequence call explicite
;(function(_pages, _switchTab)
	-- LAYER 1: reveal immédiat à 0.5s
	task.delay(0.5, function()
		pcall(function()
			if mainFrame and not mainFrame.Visible then
				mainFrame.Visible = true
			end
		end)
	end)
	-- LAYER 2: switchTab Joueurs
	pcall(function() _switchTab("Joueurs") end)
	-- LAYER 3: fallback à 3s (au cas où)
	task.delay(3, function()
		pcall(function()
			if mainFrame and not mainFrame.Visible then
				mainFrame.Visible = true
			end
			if _pages and _pages["Joueurs"] and not _pages["Joueurs"].Visible then
				pcall(function() _switchTab("Joueurs") end)
			end
		end)
	end)
end)(pages, switchTab)

-- FALLBACK absolu: si l'intro n'a jamais révélé le panel, le forcer visible + onglet Joueurs après 5s
task.delay(5, function()
	pcall(function()
		if mainFrame and not mainFrame.Visible then
			warn("[AGORA] Fallback reveal: panel forcé visible")
			mainFrame.Visible = true
		end
		if pages and pages["Joueurs"] and not pages["Joueurs"].Visible then
			switchTab("Joueurs")
		end
	end)
end)

-- Lancer l'intro cinéma si on veut (désactivée par défaut car elle bloque le fallback)
-- pcall(function() bootSequence(function()
-- 	pcall(function() mainFrame.Visible = true end)
-- 	switchTab("Joueurs")
-- end) end)

end
_buildPanel()