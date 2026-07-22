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
local _resolveCanChat = function(target, callback)
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
		if result == nil and uid and _chatSeenPlayers[uid] then
			local since = tick() - _chatSeenPlayers[uid]
			if since <= 600 then
				result, src = true, "Vu parler"
			else
				_chatSeenPlayers[uid] = nil
			end
		end
		pcall(function() callback(result, src) end)
	end)
end

-- Client-only chat detection: remember players whose public messages we actually saw
local _chatSeenPlayers = {}
task.spawn(function()
	local ok, svc = pcall(function() return game:GetService("TextChatService") end)
	if not ok or not svc then return end
	local ok2 = pcall(function()
		svc.MessageReceived:Connect(function(msg)
			if not (msg and msg.TextSource and msg.TextSource.UserId) then return end
			local uid = tonumber(msg.TextSource.UserId)
			if uid then
				_chatSeenPlayers[uid] = tick()
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
						if uid then _chatSeenPlayers[uid] = tick() end
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
if not PanelMemory then
	local PanelMemory = { dontAskRestore = false, lastEchoPlayerName = nil }
end
local panelMemory = PanelMemory

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
screenGui.Name = "AgoraUniverselleHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Backdrop retiré : il recouvrait tout l'écran en noir semi-transparent.

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 480, 0, 520)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -260)
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
mainFrame.BackgroundTransparency = 1  -- v39.45: no flash, restored after intro
-- SAFETY NET: force panel visible after 8s even if intro crashes
task.delay(8, function()
	pcall(function()
		if mainFrame and not mainFrame.Visible then
			mainFrame.Visible = true
			mainFrame.BackgroundTransparency = 0.35
			pcall(function() switchTab("Home") end)
		end
	end)
end)
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
	title.Text = "Agora Admin"
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
	subtitle.Text = "by Agora Admin"
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
			warn("[AGORA] Intro crash: " .. tostring(err))
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
titleLabel.Text = "Agora Admin [UNIVERSELLE]"
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

-- ============= REGISTRY SEARCH + AUTOCOMPLETE =============
-- WRAP dans local function + appel pour isoler les locals
local function _initRegistrySearch()
	local registrySearchBox = Instance.new("TextBox")
	registrySearchBox.Size = UDim2.new(1, -10, 0, 28)
	registrySearchBox.Position = UDim2.new(0, 5, 0, 5)
	registrySearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	registrySearchBox.BackgroundTransparency = 0.2
	registrySearchBox.TextColor3 = Color3.fromRGB(230, 230, 230)
	registrySearchBox.PlaceholderText = "🔍 Rechercher un pseudo Roblox..."
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
		"Vzlom_Emk", "AlexPro", "NovaStar", "RobloxDev", "TestAccount",
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

-- ============= REGISTRY SCROLL =============
-- registryScroll commence juste après la search box + un peu de gap pour les suggestions
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
protectionsScroll.Parent = protectionsPage

local protectionsLayout = Instance.new("UIListLayout")
protectionsLayout.Padding = UDim.new(0, 6)
protectionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
protectionsLayout.Parent = protectionsScroll

-- FIX: CanvasSize handler manquant + force remeasure après 1er render
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
		end
	end
end

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

-- Drag manuel du mini panel autoclick (clickControl) — déclenché par controlHeader
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
;(function()
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
			btn.Visible = false
			for _, gui in ipairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
				if gui.Name == "AgoraUniverselleHub" or gui.Name == "AgoraAdminUniverselle" then
					pcall(function() gui:Destroy() end)
				end
			end
			pcall(function()
				if game.CoreGui:FindFirstChild("AgoraUniverselleHub") then
					game.CoreGui.AgoraUniverselleHub:Destroy()
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
			_tween(_mainFrame, {Size = UDim2.new(0, 480, 0, 520), BackgroundTransparency = 0.35}, 0.25)
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

-- ============= JOUEURS =============
local playerCards = {}
local playerSearchQuery = "" -- query actuelle (vide = pas de filtre)

-- searchBox de Joueurs = FILTRE LOCAL de la liste des joueurs connectés
-- (la recherche officielle par username Roblox reste dans Registry)
local playerSearchBox = Instance.new("TextBox")
playerSearchBox.Size = UDim2.new(1, -10, 0, 26)
playerSearchBox.Position = UDim2.new(0, 5, 0, 8)
playerSearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
playerSearchBox.BackgroundTransparency = 0.4 -- plus discret que la search box Registry
playerSearchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
playerSearchBox.PlaceholderText = "🔎 Filtrer la liste des joueurs..."
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
playersScroll.Parent = playersPage

-- Stats serveur déplacées vers l'onglet Extra (card "Stats serveur")
-- playersScroll prend maintenant toute la place disponible sous la searchBox
local playersLayout = Instance.new("UIListLayout")
playersLayout.Padding = UDim.new(0, 6)
playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
playersLayout.Parent = playersScroll

-- === CARTE "👑 MOI" (LocalPlayer) — auto-créée, toujours en haut ===
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

	-- Titre "👑 TOI — @pseudo"
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

			myTitle.Text = "👑 TOI — @" .. myName .. " (" .. myDisp .. ")"
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
	msg.Text = "Restaurer les paramètres pour @" .. lastName .. " ?"
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

local function createPlayerEntry(plr)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 182)
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

	-- Badge local "mouvement anormal" — info seule, aucune action auto
	local moveBadge = Instance.new("TextLabel")
	moveBadge.Name = "MoveBadge"
	moveBadge.Size = UDim2.new(0, 110, 0, 16)
	moveBadge.Position = UDim2.new(1, -118, 0, 5)
	moveBadge.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
	moveBadge.BackgroundTransparency = 0.2
	moveBadge.BorderSizePixel = 0
	moveBadge.Text = "⚠ mouv. anormal"
	moveBadge.Font = Enum.Font.GothamSemibold
	moveBadge.TextSize = 9
	moveBadge.TextColor3 = Color3.fromRGB(255, 140, 120)
	moveBadge.TextXAlignment = Enum.TextXAlignment.Center
	moveBadge.Visible = false
	moveBadge.Parent = card
	createCorner(moveBadge, 6)
	createStroke(moveBadge, Color3.fromRGB(200, 80, 80), 1)

	local infoLeft = Instance.new("TextLabel")
	infoLeft.Size = UDim2.new(0.55, -6, 0, 14)
	infoLeft.Position = UDim2.new(0, 6, 0, 24)
	infoLeft.BackgroundTransparency = 1
	local days = plr.AccountAge
	local years = math.floor(days / 365)
	local remainingDays = days - (years * 365)
	infoLeft.Text = "ID: " .. plr.UserId .. " | Âge: " .. days .. "j (" .. years .. (years <= 1 and " an" or " ans") .. ")"
	infoLeft.Font = Enum.Font.Gotham
	infoLeft.TextSize = 10
	infoLeft.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLeft.TextXAlignment = Enum.TextXAlignment.Left
	infoLeft.Parent = card

	-- === Colonne droite : statut Roblox + jeu actuel + dernière connexion ===
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
	chatLbl.Text = "💬 can_chat: chargement..."
	chatLbl.Font = Enum.Font.Gotham
	chatLbl.TextSize = 10
	chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	chatLbl.TextXAlignment = Enum.TextXAlignment.Left
	chatLbl.Parent = card

	_G._resolveCanChat(plr, function(canChat, src)
		if chatLbl and chatLbl.Parent then
			if src == "CanTalkWithMe" then
				if canChat == true then
					chatLbl.Text = "💬 Peut me parler"
					chatLbl.TextColor3 = Color3.fromRGB(120, 220, 140)
				else
					chatLbl.Text = "🚫 Ne peut pas me parler"
					chatLbl.TextColor3 = Color3.fromRGB(220, 120, 120)
				end
			else
				-- Pas de serveur : on montre juste si le joueur a le chat activé
				if canChat == true then
					chatLbl.Text = "💬 Chat activé (" .. src .. ")"
					chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
				elseif canChat == false then
					chatLbl.Text = "🚫 Chat désactivé (" .. src .. ")"
					chatLbl.TextColor3 = Color3.fromRGB(180, 120, 120)
				else
					chatLbl.Text = "💬 Chat: non vérifiable"
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
			arrowText.Text = "▼"
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
		-- Fermer toute fenêtre d'inventaire déjà ouverte pour ce joueur
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
		closeX.Text = "×"
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
						if notify then notify("Item volé: " .. clone.Name, 2) end
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
			if notify then notify("Volés: " .. stolen .. " item(s)", 2) end
			task.wait(0.1)
			refreshList()
		end)

		refreshList()

		-- Auto-refresh toutes les 2s tant que la fenêtre est ouverte
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
		-- Copie locale des vêtements/corps uniquement (local uniquement)
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
		note.Text = copied > 0 and "Skin copié en local (" .. copied .. ")" or "Rien à copier"
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
						local isAirborne = (floorY > 20 and vSpeed > 5) or (vSpeed > 40)
						if flatSpeed > 2 then
							stateText = (h.WalkSpeed > 18 or flatSpeed > 18) and "Running" or "Walking"
						end
						-- Flag info uniquement : vitesse réelle > 30 OU air anormal OU vitesse verticale extrême
						moveFlag = (flatSpeed > 30) or (isAirborne and h.WalkSpeed < 30) or (vSpeed > 50)
					end
					statusLbl.Text = "Statut: " .. stateText
					pcall(function()
						if moveFlag then
							moveBadge.Visible = true
							card.BackgroundColor3 = Color3.fromRGB(38, 25, 25)
							createStroke(card, Color3.fromRGB(160, 70, 70), 1.2)
						else
							moveBadge.Visible = false
							card.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
							createStroke(card, Color3.fromRGB(45, 45, 55), 1)
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

	-- === ENRICHISSEMENT v39.43 : temps de connexion + badge ordre d'arrivée ===
	-- Ligne du bas : "Connecté depuis 12m 34s" + badge "Arrivé avant toi" / "Arrivé il y a Xs"
	local connTimeLbl = Instance.new("TextLabel")
	connTimeLbl.Size = UDim2.new(0.55, -6, 0, 14)
	connTimeLbl.Position = UDim2.new(0, 6, 0, 116)
	connTimeLbl.BackgroundTransparency = 1
	connTimeLbl.Text = "Connecté: ?"
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

	-- Bouton "i" : ouvre un popup détail avec toutes les infos Roblox du joueur
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

	-- Boucle live : met à jour le timer et le badge toutes les secondes
	-- Timestamp = moment où le panel a vu ce player pour la 1ère fois
	-- Pour les players déjà là au boot, c'est approximatif (= temps depuis l'ouverture du panel)
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
					connTimeLbl.Text = string.format("Connecté: %dh %dm %ds", hrs, mins, secs)
				elseif mins > 0 then
					connTimeLbl.Text = string.format("Connecté: %dm %ds", mins, secs)
				else
					connTimeLbl.Text = string.format("Connecté: %ds", secs)
				end

				-- Badge "arrivée" : compare au 1er player tracké
				local bootRef = _JOIN_TIMESTAMPS["__panelBoot__"] or firstSeenTick
				if seen <= bootRef + 0.5 then
					arrivalBadge.Text = "● Là depuis l'ouverture du panel"
					arrivalBadge.TextColor3 = Color3.fromRGB(120, 200, 255)
				else
					local late = math.floor(now - seen)
					arrivalBadge.Text = string.format("● Arrivé il y a %ds", late)
					arrivalBadge.TextColor3 = Color3.fromRGB(180, 220, 140)
				end
				end) -- ferme pcall
				task.wait(1)
				end -- ferme while
				end) -- ferme task.spawn

				-- Popup de détails complet sur clic "i"
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
			title.Text = "Détails : @" .. plr.Name
			title.Font = Enum.Font.GothamBold
			title.TextSize = 14
			title.TextColor3 = Color3.fromRGB(255, 255, 255)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = win

			-- Bouton Copier (à gauche du X)
			local copyBtn = Instance.new("TextButton")
			copyBtn.Size = UDim2.new(0, 60, 0, 22)
			copyBtn.Position = UDim2.new(1, -100, 0, 6)
			copyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
			copyBtn.Text = "📋 Copier"
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
				copyBtn.Text = "✓ Copié"
				copyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
				task.delay(1.5, function()
					if copyBtn and copyBtn.Parent then
						copyBtn.Text = "📋 Copier"
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
				"JobId : " .. (game.JobId ~= "" and game.JobId or "(même serveur)"),
				"Ami avec toi : " .. (isFriend and "OUI" or "non"),
				"--- Chargement Roblox API... ---"
			})

			-- Fetch détails Roblox (async, pcall, timeout 5s)
			task.spawn(function()
				local extra = {}
				pcall(function()
					local resp = game:HttpGet("https://users.roblox.com/v1/users/" .. plr.UserId, true)
					if resp and resp ~= "" then
						local d = HttpService:JSONDecode(resp)
						if d then
							table.insert(extra, "Créé le : " .. tostring(d.created or "?"))
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
				-- Test rapide des APIs Roblox (peuvent être bloquées par l'exécuteur)
				local apiOk = false
				pcall(function()
					if game and game.HttpGet then
						-- Test court : la 1ère API Roblox accessible
						local test = game:HttpGet("https://users.roblox.com/v1/users/" .. plr.UserId)
						if test and test ~= "" then apiOk = true end
					end
				end)
				if not apiOk then
					table.insert(extra, "---")
					table.insert(extra, "⚠ APIs Roblox bloquées par l'exécuteur")
					table.insert(extra, "(présence, favoris, profil détaillés indisponibles)")
				else
					-- Présence actuelle : est-ce qu'il joue EN CE MOMENT à ce jeu précis ?
					pcall(function()
						local resp = game:HttpGet("https://presence.roblox.com/v1/presence/users", true, HttpService:JSONEncode({userIds = {plr.UserId}}))
						if resp and resp ~= "" then
							local d = HttpService:JSONDecode(resp)
							if d and d.userPresences and d.userPresences[1] then
								local p = d.userPresences[1]
								-- userPresenceType: 0=Online, 1=InGame, 2=InStudio, 3=Offline
								-- userPresenceType+1: 1=Online, 2=InGame, 3=InStudio, 4=Offline (selon versions API)
								local t = tonumber(p.userPresenceType) or 0
								-- Détection plus fine du statut
								local status = "Inconnu"
								local statusIcon = "○"
								if t == 3 then
									status = "Hors ligne"
									statusIcon = "○"
								elseif t == 2 then
									status = "Au Studio (développeur)"
									statusIcon = "🛠"
								elseif t == 1 then
									-- Il joue à un jeu
									if p.lastLocation and p.lastLocation ~= "" then
										status = "En jeu : " .. tostring(p.lastLocation)
									else
										status = "En jeu"
									end
									statusIcon = "▶"
									if p.universeId and tostring(p.universeId) == tostring(game.GameId) then
										status = "★ JOUE À CE JEU : " .. tostring(p.lastLocation or "")
										statusIcon = "★"
									end
								elseif t == 0 then
									-- Online : peut être sur le site web / chat / pas dans un jeu
									if p.lastLocation and p.lastLocation ~= "" then
										-- Last location = dernier JEU où il a joué
										status = "En ligne (dernier jeu : " .. tostring(p.lastLocation) .. ")"
										statusIcon = "●"
									else
										status = "En ligne (sur le site Roblox, pas dans un jeu)"
										statusIcon = "●"
									end
								end
								table.insert(extra, statusIcon .. " Statut : " .. status)
								if p.lastLocation and p.lastLocation ~= "" then
									table.insert(extra, "  • Dernier jeu : " .. tostring(p.lastLocation))
								end
								if p.universeId then
									table.insert(extra, "  • UniverseId : " .. tostring(p.universeId) .. (tostring(p.universeId) == tostring(game.GameId) and " (= CE JEU)" or ""))
								end
								if p.lastOnline then
									-- Parser lastOnline ISO -> délai relatif
									local y, mo, da, h, mi, s = p.lastOnline:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
									if y then
										local epochThen = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(da), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
										local diff = os.time() - epochThen
										if diff < 60 then
											table.insert(extra, "  • Vu il y a : à l'instant")
										elseif diff < 3600 then
											table.insert(extra, "  • Vu il y a : " .. math.floor(diff/60) .. " min")
										elseif diff < 86400 then
											table.insert(extra, "  • Vu il y a : " .. math.floor(diff/3600) .. "h " .. math.floor((diff%3600)/60) .. "min")
										elseif diff < 2592000 then
											table.insert(extra, "  • Vu il y a : " .. math.floor(diff/86400) .. "j " .. math.floor((diff%86400)/3600) .. "h")
										else
											table.insert(extra, "  • Vu le : " .. tostring(p.lastOnline))
										end
									else
										table.insert(extra, "  • Vu la dernière fois : " .. tostring(p.lastOnline))
									end
								end
							end
						end
					end)
					-- Jeux favoris (jusqu'à 5)
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
											favNote = " ★ (CE JEU)"
										end
										table.insert(extra, "• " .. favName .. favNote)
									end
								end
							end
						end
					end)
					-- Méthodes natives Roblox (marchent même si l'exécuteur bloque HttpGet)
					table.insert(extra, "---")
					-- Membership (Premium/BC)
					local mt = tostring(plr.MembershipType):gsub("Enum.MembershipType.", "")
					local isPremium = (mt == "Premium" or plr.MembershipType == Enum.MembershipType.Premium)
					table.insert(extra, "💎 " .. (isPremium and "Premium" or "Non-Premium") .. (mt ~= "None" and mt ~= "Premium" and (" (" .. mt .. ")") or ""))
					-- Network ping (latence)
					pcall(function()
						local ping = plr:GetNetworkPing()
						local pingIcon = "🟢"
						if ping > 0.2 then pingIcon = "🟡" elseif ping > 0.4 then pingIcon = "🔴" end
						table.insert(extra, pingIcon .. " Ping : " .. math.floor(ping * 1000) .. " ms")
					end)
					-- Ami avec moi ?
					if LocalPlayer and plr ~= LocalPlayer then
						pcall(function()
							local isFriend = LocalPlayer:IsFriendsWith(plr.UserId)
							if isFriend then
								table.insert(extra, "👥 Ami avec toi : OUI")
							end
						end)
					end
					-- Joue à CE JEU (vérif locale, pas besoin d'API)
					if plr ~= LocalPlayer then
						local placeId = game.PlaceId
						pcall(function()
							local hasAsset = game:GetService("MarketplaceService"):UserOwnsGamePassAsync(plr.UserId, 0)
						end)
						-- Si le player est dans CE JEU, son GameId = placeId
						if plr.GameId and tostring(plr.GameId) == tostring(placeId) then
							table.insert(extra, "★ EST DANS CE JEU MAINTENANT")
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

local function addPlayerCard(plr)
	if plr == LocalPlayer then return end
	if playerCards[plr] and playerCards[plr].Parent then return end
	createPlayerEntry(plr)
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

local function removePlayerCard(plr)
	if playerCards[plr] then
		playerCards[plr]:Destroy()
		playerCards[plr] = nil
	end
	if selectedEchoPlayer == plr then
		selectedEchoPlayer = nil
		echoStatusLabel.Text = "Echo: aucun"
		echoStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	end
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

local function refreshPlayersList()
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

-- Pop-up de restauration au démarrage
if panelMemory.lastEchoPlayerName and not panelMemory.dontAskRestore then
	task.delay(1.5, function()
		showRestorePopup(panelMemory.lastEchoPlayerName)
	end)
end

-- searchBox de Joueurs supprimée (doublon avec Registry)
-- Plus de filtre local ici, le filtrage se fait dans Registry
-- Toutes les cartes sont toujours visibles par défaut
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

TextChatService.MessageReceived:Connect(function(msg)
	if not selectedEchoPlayer then return end
	local src = msg.TextSource
	if not src then return end
	local sender = Players:GetPlayerByUserId(src.UserId)
	if sender ~= selectedEchoPlayer then return end
	task.spawn(sendEchoMessage, msg.Text)
end)


-- ============= ESP =============
local espFolder = Instance.new("Folder")
espFolder.Name = "PanelESP"
espFolder.Parent = Workspace

local espState = { enabled = false, individual = {} }

local function distanceColor(dist)
	if dist < 50 then return Color3.fromRGB(80, 255, 120)
	elseif dist < 200 then return Color3.fromRGB(255, 200, 80)
	else return Color3.fromRGB(255, 80, 80) end
end

local function ensureESPForPlayer(plr)
	if espState.individual[plr] then return espState.individual[plr] end
	local data = { hl = nil, bill = nil, label = nil, targetPart = nil, humanoid = nil }
	espState.individual[plr] = data
	return data
end

local function buildESP(plr)
	local data = ensureESPForPlayer(plr)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local targetPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not targetPart then return end

	if data.hl and data.hl.Adornee ~= char then data.hl:Destroy() data.hl = nil end
	if not data.hl or not data.hl.Parent then
		data.hl = Instance.new("Highlight")
		data.hl.Adornee = char
		data.hl.FillTransparency = 0.65
		data.hl.OutlineTransparency = 0.15
		data.hl.OutlineColor = Color3.new(1, 1, 1)
		data.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		data.hl.Parent = espFolder
	end

	if data.bill and data.bill.Adornee ~= targetPart then data.bill:Destroy() data.bill = nil end
	if not data.bill or not data.bill.Parent then
		data.bill = Instance.new("BillboardGui")
		data.bill.Adornee = targetPart
		data.bill.Size = UDim2.new(0, 220, 0, 46)
		data.bill.StudsOffset = Vector3.new(0, 3, 0)
		data.bill.AlwaysOnTop = true
		data.bill.Parent = espFolder

		data.label = Instance.new("TextLabel")
		data.label.Size = UDim2.new(1, 0, 1, 0)
		data.label.BackgroundTransparency = 1
		data.label.Font = Enum.Font.GothamSemibold
		data.label.TextSize = 13
		data.label.TextColor3 = Color3.new(1, 1, 1)
		data.label.TextStrokeTransparency = 0.3
		data.label.Parent = data.bill
	end
	data.targetPart = targetPart
	data.humanoid = hum
	data.canChat = nil
	_G._resolveCanChat(plr, function(canChat, src)
		if data then data.canChat = canChat end
		data.canChatSrc = src
	end)
	return data
end

local function clearESP()
	for _, child in ipairs(espFolder:GetChildren()) do child:Destroy() end
	espState.individual = {}
end

local function refreshESP()
	if not (espState.enabled or globalESPEnabled) then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local data = buildESP(plr)
			if data then
				data.active = true
				if data.hl then data.hl.Enabled = true end
				if data.bill then data.bill.Enabled = true end
			end
		end
	end
end

function togglePlayerESP(plr)
	local data = ensureESPForPlayer(plr)
	if data.active then
		data.active = false
		if data.hl then data.hl.Enabled = false end
		if data.bill then data.bill.Enabled = false end
	else
		data.active = true
		buildESP(plr)
		if data.hl then data.hl.Enabled = true end
		if data.bill then data.bill.Enabled = true end
	end
end

local function blinkESP(plr, duration)
	duration = duration or 3
	local data = ensureESPForPlayer(plr)
	if not data.active then
		data.active = true
		buildESP(plr)
		if data.hl then data.hl.Enabled = true end
		if data.bill then data.bill.Enabled = true end
	end
	data.blink = true
	task.delay(duration, function()
		if data then data.blink = false end
	end)
end

RunService.RenderStepped:Connect(function()
	updateCharacter()
	if not rootPart then return end
	for plr, data in pairs(espState.individual) do
		if data.active and data.targetPart and data.targetPart.Parent then
			local dist = (data.targetPart.Position - rootPart.Position).Magnitude
			if data.blink then
				local pulse = (tick() % 0.5) < 0.25
				if data.hl then
					data.hl.FillColor = pulse and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
					data.hl.FillTransparency = pulse and 0.35 or 0.75
					data.hl.OutlineColor = pulse and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 0, 0)
					data.hl.Enabled = true
				end
				if data.label then
					local hp = data.humanoid and math.floor(data.humanoid.Health) or 0
					local chatSym = ""
					if data.canChatSrc == "CanTalkWithMe" then
						chatSym = data.canChat == true and " 💬" or " 🚫"
					elseif data.canChat ~= nil then
						chatSym = data.canChat == true and " 📢" or " 🔕"
					end
					data.label.Text = ">> " .. plr.Name .. " [" .. math.floor(dist) .. " studs] HP:" .. hp .. chatSym
					data.label.TextColor3 = pulse and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
				end
				if data.bill then data.bill.Enabled = true end
			else
				local col = distanceColor(dist)
				if data.label then
					local hp = data.humanoid and math.floor(data.humanoid.Health) or 0
					local chatSym = ""
					if data.canChat == true then chatSym = " 💬"
					elseif data.canChat == false then chatSym = " 🚫"
					end
					data.label.Text = plr.Name .. " [" .. math.floor(dist) .. " studs] HP:" .. hp .. chatSym
					data.label.TextColor3 = col
				end
				if data.hl then
					data.hl.FillColor = col
					data.hl.Enabled = true
				end
				if data.bill then data.bill.Enabled = true end
			end
		else
			if data.hl then data.hl.Enabled = false end
			if data.bill then data.bill.Enabled = false end
		end
	end
end)

local function applyGlobalESPToPlayer(plr)
	if plr == LocalPlayer then return end
	if not plr.Character then return end
	local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		task.delay(0.5, function() applyGlobalESPToPlayer(plr) end)
		return
	end
	local data = buildESP(plr)
	if data then
		data.active = true
		if data.hl then data.hl.Enabled = true end
		if data.bill then data.bill.Enabled = true end
	end
end

for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= LocalPlayer then
		plr.CharacterAdded:Connect(function()
			task.wait(0.3)
			if espState.enabled then applyGlobalESPToPlayer(plr) end
		end)
		if plr.Character then
			task.spawn(function()
				task.wait(0.3)
				if espState.enabled then applyGlobalESPToPlayer(plr) end
			end)
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	if plr == LocalPlayer then return end
	plr.CharacterAdded:Connect(function()
		task.wait(0.3)
		if espState.enabled then applyGlobalESPToPlayer(plr) end
	end)
end)

-- Rafraîchit l'ESP toutes les 60s sans flash (rebuild silencieux si le personnage a changé)
task.spawn(function()
	while true do
		task.wait(60)
		refreshESP()
	end
end)


-- ============= ANIMATIONS =============
local function typewriterEffect(label, text, speed)
	speed = speed or 0.02
	local chars = text:split("")
	local current = ""
	for i = 1, #chars do
		current = current .. chars[i]
		label.Text = current
		task.wait(speed)
	end
end


local function matrixRain(parent, duration)
	duration = duration or 1
	local letters = {"0","1","/","\\","[","]","{","}","<",">","#","@","%","&","*","+","-","=","?","!"}
	local startTime = tick()
	local con
	con = RunService.RenderStepped:Connect(function()
		if tick() - startTime > duration then
			con:Disconnect()
			return
		end
		for i = 1, 8 do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0, 12, 0, 16)
			lbl.Position = UDim2.new(math.random(), 0, math.random(-0.15, 0.1), 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = letters[math.random(1, #letters)]
			lbl.Font = Enum.Font.Code
			lbl.TextSize = math.random(9, 14)
			lbl.TextColor3 = Color3.fromRGB(0, 255, 120)
			lbl.TextTransparency = math.random(30, 70) / 100
			lbl.ZIndex = 99
			lbl.Parent = parent
			local speed = math.random(12, 35) / 10
			tween(lbl, {Position = UDim2.new(lbl.Position.X.Scale, 0, 1.2, 0), TextTransparency = 1}, speed)
			task.delay(speed + 0.1, function() if lbl then lbl:Destroy() end end)
		end
	end)
end

local function bootSequence(onComplete)
	-- BOOT ANIMATION v2 : "Genesis" - le panel s'assemble piece par piece avec effets cinematiques
	-- Layer 1 boot-safe : pcall dans le task.spawn
	local bootGui = Instance.new("ScreenGui")
	bootGui.Name = "AgoraUniverselleBoot"
	bootGui.ResetOnSpawn = false
	bootGui.DisplayOrder = 99999
	bootGui.IgnoreGuiInset = true
	bootGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local screenW = workspace.CurrentCamera.ViewportSize.X
	local screenH = workspace.CurrentCamera.ViewportSize.Y

	-- Fond fullscreen noir
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 100
	backdrop.Parent = bootGui

	-- Vignette subtile
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.new(1.5, 0, 1.5, 0)
	vignette.Position = UDim2.new(-0.25, 0, -0.25, 0)
	vignette.BackgroundTransparency = 1
	vignette.Image = "rbxassetid://9638773891"
	vignette.ImageColor3 = Color3.fromRGB(0, 0, 0)
	vignette.ImageTransparency = 0.5
	vignette.ZIndex = 101
	vignette.Parent = backdrop

	-- Particules de fond qui tombent (effet Matrix ameliore)
	local particleLetters = {"0","1","A","B","C","X","Y","Z","<",">","/","\\","{","}","#","@","%","&","*","+","-","=","?","!","#","$","O","M","E"}
	local particles = {}
	for i = 1, 60 do
		local p = Instance.new("TextLabel")
		p.Size = UDim2.new(0, math.random(10, 18), 0, math.random(12, 22))
		p.Position = UDim2.new(math.random() * 1.1 - 0.05, 0, -0.1, 0)
		p.BackgroundTransparency = 1
		p.Text = particleLetters[math.random(1, #particleLetters)]
		p.Font = (math.random() > 0.5) and Enum.Font.Code or Enum.Font.GothamBold
		p.TextSize = math.random(10, 22)
		p.TextColor3 = Color3.fromRGB(0, 255, math.random(80, 200))
		p.TextTransparency = 0.3
		p.TextStrokeTransparency = 0.6
		p.Rotation = math.random(-15, 15)
		p.ZIndex = 102
		p.Parent = backdrop
		table.insert(particles, p)
	end

	-- Titre principal - glitch + typewriter
	local title = Instance.new("TextLabel")
	title.Name = "BootTitle"
	title.Size = UDim2.new(1, 0, 0, 90)
	title.Position = UDim2.new(0, 0, 0.32, 0)
	title.BackgroundTransparency = 1
	title.Text = ""
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 72
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = Color3.fromRGB(0, 200, 255)
	title.TextStrokeTransparency = 0.4
	title.TextTransparency = 1
	title.ZIndex = 200
	title.Parent = backdrop

	-- Sous-titre
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 28)
	subtitle.Position = UDim2.new(0, 0, 0.46, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "[ SYSTEM BOOT // INITIALIZING ]"
	subtitle.Font = Enum.Font.Code
	subtitle.TextSize = 16
	subtitle.TextColor3 = Color3.fromRGB(0, 255, 180)
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 200
	subtitle.Parent = backdrop

	-- Lignes de log
	local logs = {}
	local logTexts = {
		">> Loading core modules...",
		">> Mounting interface components...",
		">> Building tab structures...",
		">> Linking player database...",
		">> Establishing secure channels...",
		">> Verifying input handlers...",
		">> Compiling ESP systems...",
		">> Calibrating fly physics...",
		">> Ready."
	}
	for i = 1, #logTexts do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.6, 0, 0, 18)
		l.Position = UDim2.new(0.05, 0, 0.55, (i-1) * 20)
		l.BackgroundTransparency = 1
		l.Text = ""
		l.Font = Enum.Font.Code
		l.TextSize = 12
		l.TextColor3 = Color3.fromRGB(0, 255, 120)
		l.TextTransparency = 1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 200
		l.Parent = backdrop
		logs[i] = l
	end

	-- Barre de progression
	local progTrack = Instance.new("Frame")
	progTrack.Size = UDim2.new(0.4, 0, 0, 4)
	progTrack.Position = UDim2.new(0.3, 0, 0.82, 0)
	progTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	progTrack.BorderSizePixel = 0
	progTrack.ZIndex = 200
	progTrack.Parent = backdrop

	local progFill = Instance.new("Frame")
	progFill.Size = UDim2.new(0, 0, 1, 0)
	progFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	progFill.BorderSizePixel = 0
	progFill.ZIndex = 201
	progFill.Parent = progTrack

	-- Pourcentage affiche
	local pctLabel = Instance.new("TextLabel")
	pctLabel.Size = UDim2.new(0.2, 0, 0, 24)
	pctLabel.Position = UDim2.new(0.4, 0, 0.84, 0)
	pctLabel.BackgroundTransparency = 1
	pctLabel.Text = "0%"
	pctLabel.Font = Enum.Font.Code
	pctLabel.TextSize = 14
	pctLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
	pctLabel.TextTransparency = 1
	pctLabel.ZIndex = 200
	pctLabel.Parent = backdrop

	-- Scanline qui descend
	local scanline = Instance.new("Frame")
	scanline.Size = UDim2.new(1, 0, 0, 2)
	scanline.Position = UDim2.new(0, 0, 0, 0)
	scanline.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	scanline.BackgroundTransparency = 0.3
	scanline.BorderSizePixel = 0
	scanline.ZIndex = 150
	scanline.Parent = backdrop

	-- Glitch bars
	local glitchBars = {}
	for i = 1, 3 do
		local gb = Instance.new("Frame")
		gb.Size = UDim2.new(1, 0, 0, math.random(2, 8))
		gb.Position = UDim2.new(0, 0, math.random() * 0.8 + 0.1, 0)
		gb.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
		gb.BackgroundTransparency = 0.5
		gb.BorderSizePixel = 0
		gb.ZIndex = 180
		gb.Parent = backdrop
		table.insert(glitchBars, gb)
	end

	-- ANIMATION PRINCIPALE
	task.spawn(function()
		local ti = TweenInfo.new
		-- ===== SHARDS D'ECRAN CASSE + LIGNES SACCROCHEES MULTICOLORE =====
	-- Effet "broken screen" : on dessine des eclats triangulaires colores qui apparaissent
	-- en chaos sur tout l'ecran avant que le panel ne se forme
	local shardLetters = {"0","1","X","Y","Z","#","@","%","&","*","/","\\","M","E","O","G","[","]","{","}","<",">","!","?","$","+","-","="}
	local shardCount = 35
	local shards = {}
	for i = 1, shardCount do
		local s = Instance.new("TextLabel")
		s.Size = UDim2.new(0, math.random(16, 38), 0, math.random(18, 44))
		s.Position = UDim2.new(math.random() * 0.95, 0, math.random() * 0.95, 0)
		s.BackgroundTransparency = 1
		s.Text = shardLetters[math.random(1, #shardLetters)]
		s.Font = (math.random() > 0.5) and Enum.Font.Code or Enum.Font.GothamBold
		s.TextSize = math.random(14, 32)
		-- Couleurs multicolore : rouge, vert, bleu, jaune, magenta, cyan
		local colChoice = math.random(1, 6)
		if colChoice == 1 then s.TextColor3 = Color3.fromRGB(255, 60, 80) -- rouge
		elseif colChoice == 2 then s.TextColor3 = Color3.fromRGB(60, 255, 120) -- vert
		elseif colChoice == 3 then s.TextColor3 = Color3.fromRGB(80, 160, 255) -- bleu
		elseif colChoice == 4 then s.TextColor3 = Color3.fromRGB(255, 230, 60) -- jaune
		elseif colChoice == 5 then s.TextColor3 = Color3.fromRGB(255, 80, 220) -- magenta
		else s.TextColor3 = Color3.fromRGB(60, 240, 255) end -- cyan
		s.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		s.TextStrokeTransparency = 0.3
		s.TextTransparency = 1 -- invisible au depart, on les fait apparaitre en saccade
		s.Rotation = math.random(-30, 30)
		s.ZIndex = 105
		s.Parent = backdrop
		table.insert(shards, s)
	end

	-- Lignes saccrochees (scratch lines) : barres diagonales qui apparaissent/disparaissent
	local scratchLines = {}
	for i = 1, 8 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, math.random(120, 280), 0, math.random(1, 3))
		line.Position = UDim2.new(math.random() * 0.8, 0, math.random() * 0.95, 0)
		line.BackgroundColor3 = (math.random() > 0.5) and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 200, 255)
		line.BackgroundTransparency = 1
		line.BorderSizePixel = 0
		line.Rotation = math.random(-45, 45)
		line.ZIndex = 110
		line.Parent = backdrop
		table.insert(scratchLines, line)
	end

	-- Lignes de fracture (horizontales) qui apparaissent en saccade
	local fractureLines = {}
	for i = 1, 4 do
		local fl = Instance.new("Frame")
		fl.Size = UDim2.new(1.2, 0, 0, 2)
		fl.Position = UDim2.new(-0.1, 0, math.random() * 0.9, 0)
		fl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		fl.BackgroundTransparency = 1
		fl.BorderSizePixel = 0
		fl.ZIndex = 108
		fl.Parent = backdrop
		table.insert(fractureLines, fl)
	end

	-- ANIMATION SHARDS (parallele au scanline)
	task.spawn(function()
		-- Apparition saccadee des shards
		for pass = 1, 3 do
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TextTransparency = math.random(20, 50) / 100}, 0.05)
				end)
				task.wait(0.02 + math.random() * 0.03)
			end
			task.wait(0.15)
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TextTransparency = 1}, 0.05)
				end)
				task.wait(0.01)
			end
			task.wait(0.1)
		end
		-- Apparition finale longue
		for i, s in ipairs(shards) do
			task.spawn(function()
				tween(s, {TextTransparency = 0.4}, 0.2)
			end)
			task.wait(0.02)
		end
		-- Lignes saccrochees : flash rapide
		for i = 1, 5 do
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BackgroundTransparency = 0.4}, 0.04)
				end)
			end
			task.wait(0.08)
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BackgroundTransparency = 1}, 0.05)
				end)
			end
			task.wait(0.06)
		end
		-- Fracture lines flash
		for _, fl in ipairs(fractureLines) do
			task.spawn(function()
				tween(fl, {BackgroundTransparency = 0.5}, 0.06)
				task.wait(0.1)
				tween(fl, {BackgroundTransparency = 1}, 0.1)
			end)
			task.wait(0.08)
		end
		task.wait(0.5)
		-- Fade out final
		for i, s in ipairs(shards) do
			if s and s.Parent then tween(s, {TextTransparency = 1}, 0.4) end
		end
		for _, l in ipairs(scratchLines) do
			if l and l.Parent then tween(l, {BackgroundTransparency = 1}, 0.3) end
		end
		for _, fl in ipairs(fractureLines) do
			if fl and fl.Parent then tween(fl, {BackgroundTransparency = 1}, 0.3) end
		end
	end)

	-- ===== SHARDS D'ECRAN CASSE + LIGNES SACCROCHEES MULTICOLORE =====
	local shardLetters = {"0","1","X","Y","Z","#","@","%","&","*","/","\\","M","E","O","G","[","]","{","}","<",">","!","?","$","+","-","="}
	local shardCount = 35
	local shards = {}
	for i = 1, shardCount do
		local s = Instance.new("TextLabel")
		s.Size = UDim2.new(0, math.random(16, 38), 0, math.random(18, 44))
		s.Position = UDim2.new(math.random() * 0.95, 0, math.random() * 0.95, 0)
		s.BackgroundTransparency = 1
		s.Text = shardLetters[math.random(1, #shardLetters)]
		s.Font = (math.random() > 0.5) and Enum.Font.Code or Enum.Font.GothamBold
		s.TextSize = math.random(14, 32)
		local colChoice = math.random(1, 6)
		if colChoice == 1 then s.TextColor3 = Color3.fromRGB(255, 60, 80)
		elseif colChoice == 2 then s.TextColor3 = Color3.fromRGB(60, 255, 120)
		elseif colChoice == 3 then s.TextColor3 = Color3.fromRGB(80, 160, 255)
		elseif colChoice == 4 then s.TextColor3 = Color3.fromRGB(255, 230, 60)
		elseif colChoice == 5 then s.TextColor3 = Color3.fromRGB(255, 80, 220)
		else s.TextColor3 = Color3.fromRGB(60, 240, 255) end
		s.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		s.TextStrokeTransparency = 0.3
		s.TextTransparency = 1
		s.Rotation = math.random(-30, 30)
		s.ZIndex = 105
		s.Parent = backdrop
		table.insert(shards, s)
	end

	local scratchLines = {}
	for i = 1, 8 do
		local line = Instance.new("Frame")
		line.Size = UDim2.new(0, math.random(120, 280), 0, math.random(1, 3))
		line.Position = UDim2.new(math.random() * 0.8, 0, math.random() * 0.95, 0)
		line.BackgroundColor3 = (math.random() > 0.5) and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 200, 255)
		line.BackgroundTransparency = 1
		line.BorderSizePixel = 0
		line.Rotation = math.random(-45, 45)
		line.ZIndex = 110
		line.Parent = backdrop
		table.insert(scratchLines, line)
	end

	local fractureLines = {}
	for i = 1, 4 do
		local fl = Instance.new("Frame")
		fl.Size = UDim2.new(1.2, 0, 0, 2)
		fl.Position = UDim2.new(-0.1, 0, math.random() * 0.9, 0)
		fl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		fl.BackgroundTransparency = 1
		fl.BorderSizePixel = 0
		fl.ZIndex = 108
		fl.Parent = backdrop
		table.insert(fractureLines, fl)
	end

	-- ANIMATION SHARDS (parallele au scanline)
	task.spawn(function()
		for pass = 1, 3 do
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TextTransparency = math.random(20, 50) / 100}, 0.05)
				end)
				task.wait(0.02 + math.random() * 0.03)
			end
			task.wait(0.15)
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TextTransparency = 1}, 0.05)
				end)
				task.wait(0.01)
			end
			task.wait(0.1)
		end
		for i, s in ipairs(shards) do
			task.spawn(function()
				tween(s, {TextTransparency = 0.4}, 0.2)
			end)
			task.wait(0.02)
		end
		for i = 1, 5 do
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BackgroundTransparency = 0.4}, 0.04)
				end)
			end
			task.wait(0.08)
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BackgroundTransparency = 1}, 0.05)
				end)
			end
			task.wait(0.06)
		end
		for _, fl in ipairs(fractureLines) do
			task.spawn(function()
				tween(fl, {BackgroundTransparency = 0.5}, 0.06)
				task.wait(0.1)
				tween(fl, {BackgroundTransparency = 1}, 0.1)
			end)
			task.wait(0.08)
		end
		task.wait(0.5)
		for i, s in ipairs(shards) do
			if s and s.Parent then tween(s, {TextTransparency = 1}, 0.4) end
		end
		for _, l in ipairs(scratchLines) do
			if l and l.Parent then tween(l, {BackgroundTransparency = 1}, 0.3) end
		end
		for _, fl in ipairs(fractureLines) do
			if fl and fl.Parent then tween(fl, {BackgroundTransparency = 1}, 0.3) end
		end
	end)

	-- 1) Scanline descend
		TweenService:Create(scanline, ti(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Position = UDim2.new(0, 0, 1, 0)}):Play()

		-- 2) Particules tombent en cascade
		for i, p in ipairs(particles) do
			task.spawn(function()
				local dur = math.random(15, 30) / 10
				tween(p, {Position = UDim2.new(p.Position.X.Scale, 0, 1.1, 0), TextTransparency = 1}, dur)
				task.delay(dur + 0.1, function() if p and p.Parent then p:Destroy() end end)
			end)
			task.wait(0.04)
		end

		-- 3) Titre typewriter + glitch
		title.TextTransparency = 0
		local targetText = "MILAN  x  EMERICK"
		local glitchChars = {"!", "@", "#", "$", "%", "&", "*", "X", "0", "1", "#", "$"}
		for i = 1, #targetText do
			if math.random() < 0.3 then
				title.Text = title.Text .. glitchChars[math.random(1, #glitchChars)]
				task.wait(0.04)
				title.Text = targetText:sub(1, i)
			else
				title.Text = targetText:sub(1, i)
			end
			task.wait(0.06 + math.random() * 0.04)
		end

		-- Pulse du titre
		for i = 1, 3 do
			tween(title, {TextSize = 76}, 0.1)
			task.wait(0.1)
			tween(title, {TextSize = 72}, 0.1)
			task.wait(0.1)
		end

		-- 4) Sous-titre
		title.TextStrokeTransparency = 0
		tween(subtitle, {TextTransparency = 0.1}, 0.4)

		-- 5) Glitch bars flash
		for _, gb in ipairs(glitchBars) do
			task.spawn(function()
				tween(gb, {Position = UDim2.new(0, 0, math.random(), 0), BackgroundTransparency = 0.9}, 0.2)
				task.wait(0.2)
				if gb and gb.Parent then gb:Destroy() end
			end)
		end

		-- 6) Logs typewriter
		for i, log in ipairs(logs) do
			tween(log, {TextTransparency = 0.3}, 0.2)
			local text = logTexts[i]
			for j = 1, #text do
				log.Text = text:sub(1, j)
				task.wait(0.015)
			end
			local pct = i / #logTexts
			TweenService:Create(progFill, ti(0.3), {Size = UDim2.new(pct * 0.4, 0, 1, 0)}):Play()
			pctLabel.Text = math.floor(pct * 100) .. "%"
			tween(pctLabel, {TextTransparency = 0.2}, 0.2)
			if i == 3 or i == 6 then
				task.spawn(function()
					for _ = 1, 4 do
						title.Position = UDim2.new(0, math.random(-3, 3), 0.32, math.random(-2, 2))
						task.wait(0.04)
					end
					title.Position = UDim2.new(0, 0, 0.32, 0)
				end)
			end
			task.wait(0.15)
		end

		progFill.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
		TweenService:Create(progFill, ti(0.3), {Size = UDim2.new(0.4, 0, 1, 0)}):Play()
		pctLabel.Text = "100%"
		pctLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
		task.wait(0.5)

		-- 7) Phase finale : flash + zoom + fade out
		local flash = Instance.new("Frame")
		flash.Size = UDim2.new(1, 0, 1, 0)
		flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.ZIndex = 500
		flash.Parent = backdrop
		tween(flash, {BackgroundTransparency = 0.3}, 0.08)
		task.wait(0.08)
		tween(flash, {BackgroundTransparency = 1}, 0.3)
		task.delay(0.4, function() if flash and flash.Parent then flash:Destroy() end end)

		TweenService:Create(title, ti(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, 0.45, 0), TextSize = 28, TextTransparency = 0.5}):Play()
		TweenService:Create(subtitle, ti(0.6), {TextTransparency = 1}):Play()
		for _, log in ipairs(logs) do
			TweenService:Create(log, ti(0.4), {TextTransparency = 1}):Play()
		end
		TweenService:Create(progTrack, ti(0.4), {BackgroundTransparency = 1}):Play()
		TweenService:Create(progFill, ti(0.4), {BackgroundTransparency = 1}):Play()
		TweenService:Create(pctLabel, ti(0.4), {TextTransparency = 1}):Play()
		tween(backdrop, {BackgroundTransparency = 1}, 0.7)

		for _, p in ipairs(particles) do
			if p and p.Parent then tween(p, {TextTransparency = 1}, 0.4) end
		end

		task.wait(0.8)
	end)

	-- Layer 1 : pcall sur l'ensemble
	task.defer(function()
		local ok, err = pcall(function()
			for _ = 1, 50 do
				if not backdrop or not backdrop.Parent then break end
				task.wait(0.1)
			end
		end)
		if not ok then warn("[AGORA] boot crash: " .. tostring(err)) end
		pcall(function() if bootGui and bootGui.Parent then bootGui:Destroy() end end)
		if onComplete then pcall(function() onComplete() end) end
	end)
end

-- ============= MOVE =============
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
	flyState.mobileInput = Vector3.zero
	flyState.mobileUpHeld = false
	flyState.mobileDownHeld = false
	flyState.mobileStickId = nil
	if flyState.showMobileUi then flyState.showMobileUi(false) end
	updateCharacter()
	if humanoid then humanoid.PlatformStand = false end
	flySwitch.set(false)
	-- Active la grâce anti-TP pour réinitialiser la baseline sans bounce
	if protectionsState then
		protectionsState.antiTeleportGraceUntil = tick() + 0.4
	end
end

-- ============= FLY MOBILE JOYSTICK (auto-show on touch devices) =============
;(function(_fly, _screenGui)
	local function isMobile()
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end
	local function ensureMobileUi()
		if _fly.mobileUiCreated then return end
		_fly.mobileUiCreated = true
		local base = Instance.new("Frame")
		base.Name = "FlyJoystickBase"
		base.Size = UDim2.new(0, 110, 0, 110)
		base.Position = UDim2.new(0, 30, 1, -240)
		base.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
		base.BackgroundTransparency = 0.35
		base.BorderSizePixel = 0
		base.Visible = false
		base.ZIndex = 50
		base.Parent = _screenGui
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = base
		local bs = Instance.new("UIStroke")
		bs.Color = Color3.fromRGB(140, 100, 230)
		bs.Thickness = 2
		bs.Transparency = 0.4
		bs.Parent = base
		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.new(0, 50, 0, 50)
		knob.Position = UDim2.new(0.5, -25, 0.5, -25)
		knob.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
		knob.BorderSizePixel = 0
		knob.ZIndex = 51
		knob.Parent = base
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(1, 0)
		kc.Parent = knob
		local upBtn = Instance.new("TextButton")
		upBtn.Name = "FlyUp"
		upBtn.Size = UDim2.new(0, 60, 0, 60)
		upBtn.Position = UDim2.new(0, 30, 1, -130)
		upBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
		upBtn.BackgroundTransparency = 0.35
		upBtn.BorderSizePixel = 0
		upBtn.Text = "▲"
		upBtn.TextColor3 = Color3.fromRGB(140, 100, 230)
		upBtn.Font = Enum.Font.GothamBold
		upBtn.TextSize = 22
		upBtn.Visible = false
		upBtn.ZIndex = 50
		upBtn.Parent = _screenGui
		local uc = Instance.new("UICorner")
		uc.CornerRadius = UDim.new(1, 0)
		uc.Parent = upBtn
		local us = Instance.new("UIStroke")
		us.Color = Color3.fromRGB(140, 100, 230)
		us.Thickness = 2
		us.Transparency = 0.4
		us.Parent = upBtn
		local dnBtn = Instance.new("TextButton")
		dnBtn.Name = "FlyDown"
		dnBtn.Size = UDim2.new(0, 60, 0, 60)
		dnBtn.Position = UDim2.new(0, 100, 1, -130)
		dnBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
		dnBtn.BackgroundTransparency = 0.35
		dnBtn.BorderSizePixel = 0
		dnBtn.Text = "▼"
		dnBtn.TextColor3 = Color3.fromRGB(140, 100, 230)
		dnBtn.Font = Enum.Font.GothamBold
		dnBtn.TextSize = 22
		dnBtn.Visible = false
		dnBtn.ZIndex = 50
		dnBtn.Parent = _screenGui
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dnBtn
		local ds = Instance.new("UIStroke")
		ds.Color = Color3.fromRGB(140, 100, 230)
		ds.Thickness = 2
		ds.Transparency = 0.4
		ds.Parent = dnBtn
		_fly.mobileBase = base
		_fly.mobileKnob = knob
		_fly.mobileUp = upBtn
		_fly.mobileDown = dnBtn
		-- Joystick drag handler
		base.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				_fly.mobileStickId = input
			end
		end)
		upBtn.MouseButton1Down:Connect(function() _fly.mobileUpHeld = true end)
		upBtn.MouseButton1Up:Connect(function() _fly.mobileUpHeld = false end)
		dnBtn.MouseButton1Down:Connect(function() _fly.mobileDownHeld = true end)
		dnBtn.MouseButton1Up:Connect(function() _fly.mobileDownHeld = false end)
		-- Use direct touch state via .TouchEnded events
		upBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then _fly.mobileUpHeld = true end end)
		upBtn.InputEnded:Connect(function() _fly.mobileUpHeld = false end)
		dnBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then _fly.mobileDownHeld = true end end)
		dnBtn.InputEnded:Connect(function() _fly.mobileDownHeld = false end)
	end
	-- Track mobile joystick in RenderStepped via global InputChanged
	UserInputService.InputChanged:Connect(function(input, gpe)
		if not _fly.flying or not _fly.mobileStickId then return end
		if gpe then return end
		if input ~= _fly.mobileStickId then return end
		if input.UserInputState == Enum.UserInputState.End then
			_fly.mobileStickId = nil
			_fly.mobileInput = Vector3.zero
			if _fly.mobileKnob then _fly.mobileKnob.Position = UDim2.new(0.5, -25, 0.5, -25) end
			return
		end
		-- Convert position relative to joystick base
		local base = _fly.mobileBase
		if not base or not _fly.mobileKnob then return end
		local center = base.AbsolutePosition + base.AbsoluteSize / 2
		local radius = base.AbsoluteSize.X / 2
		local delta = input.Position - center
		local dist = math.min(delta.Magnitude, radius)
		local dir = delta.Magnitude > 0 and delta.Unit or Vector2.new(0, 0)
		local knobOffset = dir * dist
		_fly.mobileKnob.Position = UDim2.new(0.5, knobOffset.X - 25, 0.5, knobOffset.Y - 25)
		-- Normalized input for camera-relative direction (-1..1)
		_fly.mobileInput = Vector3.new(dir.X, 0, dir.Y)
	end)
	-- Public API used by startFly/stopFly
	_fly.showMobileUi = function(visible)
		ensureMobileUi()
		if _fly.mobileBase then _fly.mobileBase.Visible = visible end
		if _fly.mobileUp then _fly.mobileUp.Visible = visible end
		if _fly.mobileDown then _fly.mobileDown.Visible = visible end
	end
	_fly.isMobile = isMobile
end)(flyState, screenGui)

local function startFly()
	updateCharacter()
	if flyState.flying or not rootPart then return end
	flyState.flying = true

	flyState.gyro = Instance.new("BodyGyro")
	flyState.gyro.P = 9e4
	flyState.gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	flyState.gyro.CFrame = rootPart.CFrame
	flyState.gyro.Parent = rootPart

	flyState.vel = Instance.new("BodyVelocity")
	flyState.vel.Velocity = Vector3.zero
	flyState.vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	flyState.vel.Parent = rootPart

	if humanoid then humanoid.PlatformStand = true end

	-- Show mobile UI on touch devices
	if flyState.isMobile and flyState.isMobile() and flyState.showMobileUi then
		flyState.showMobileUi(true)
	end

	flyState.loop = RunService.RenderStepped:Connect(function()
		updateCharacter()
		if not flyState.flying or not rootPart or not rootPart.Parent then return end
		-- Re-attach body movers if rootPart changed (respawn)
		if flyState.gyro and flyState.gyro.Parent ~= rootPart then flyState.gyro.Parent = rootPart end
		if flyState.vel and flyState.vel.Parent ~= rootPart then flyState.vel.Parent = rootPart end
		if flyState.gyro then flyState.gyro.CFrame = Camera.CFrame end

		local move = Vector3.zero
		-- PC controls (clavier)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Z) then move = move + Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move = move - Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
		-- Mobile controls (joystick + boutons)
		if flyState.mobileInput and flyState.mobileInput.Magnitude > 0 then
			move = move + Camera.CFrame.LookVector * flyState.mobileInput.Z + Camera.CFrame.RightVector * flyState.mobileInput.X
		end
		if flyState.mobileUpHeld then move = move + Vector3.new(0, 1, 0) end
		if flyState.mobileDownHeld then move = move - Vector3.new(0, 1, 0) end

		if flyState.vel then
			flyState.vel.Velocity = move.Magnitude > 0 and move.Unit * flyState.speed or Vector3.zero
		end
	end)
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
	-- clics sur le container parent sont perdus → le slider "marche mal")
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
	-- Hit invisible capte les clics n'importe où sur la zone (Y=21..45), pas seulement le track (6px)
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
		-- Active la grâce anti-TP après sortie du noclip
		if protectionsState then
			protectionsState.antiTeleportGraceUntil = tick() + 0.4
		end
	end
end)

local PathfindingService = game:GetService("PathfindingService")

local gotoWalkState = { enabled = false, active = false, target = nil, path = {}, visuals = {}, lastClick = 0, lastMoveTo = nil, recompute = nil, busy = false }

local function clearWalkVisuals()
	for _, v in ipairs(gotoWalkState.visuals) do
		if v and v.Parent then v:Destroy() end
	end
	gotoWalkState.visuals = {}
end

local function visualizeWaypoints(waypoints)
	clearWalkVisuals()
	for i, wp in ipairs(waypoints) do
		local dot = Instance.new("Part")
		dot.Anchored = true
		dot.CanCollide = false
		dot.Transparency = 0.45
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.6, 0.6, 0.6)
		dot.Color = i == #waypoints and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(120, 180, 255)
		dot.Position = wp + Vector3.new(0, 0.2, 0)
		dot.Parent = Workspace
		table.insert(gotoWalkState.visuals, dot)
		if i > 1 then
			local prev = waypoints[i - 1]
			local seg = Instance.new("Part")
			seg.Anchored = true
			seg.CanCollide = false
			seg.Transparency = 0.7
			local len = (wp - prev).Magnitude
			if len > 0.1 then
				seg.Size = Vector3.new(0.15, 0.15, len)
				seg.CFrame = CFrame.lookAt(prev, wp) * CFrame.new(0, 0, -len / 2)
			else
				seg.Size = Vector3.new(0.15, 0.15, 0.1)
				seg.CFrame = CFrame.new((prev + wp) / 2)
			end
			seg.Color = Color3.fromRGB(200, 200, 255)
			seg.Parent = Workspace
			table.insert(gotoWalkState.visuals, seg)
		end
	end
end

-- Calcule un trajet vers targetPos. Retourne une liste de waypoints (Vector3) ou {} si impossible.
local function computePathTo(targetPos)
	updateCharacter()
	if not rootPart or not humanoid then return {} end

	-- 1) Tentative avec PathfindingService Roblox (le plus fiable)
	local waypoints = {}
	local ok, pathOrErr = pcall(function()
		local p = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
		})
		p:ComputeAsync(rootPart.Position, targetPos)
		return p:GetWaypoints()
	end)

	if ok and pathOrErr and #pathOrErr > 0 then
		for i, wp in ipairs(pathOrErr) do
			if wp and wp.Position then
				table.insert(waypoints, wp.Position)
			end
		end
		-- On retire le waypoint 1 (position actuelle) pour éviter un MoveTo immédiat dans le vide
		if #waypoints > 1 then
			table.remove(waypoints, 1)
		end
		return waypoints
	end

	-- 2) Fallback : ligne droite + raycast pour éviter les murs
	local function rayClear(a, b)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local dir = b - a
		local dist = dir.Magnitude
		if dist < 0.1 then return true end
		local hit = Workspace:Raycast(a, dir.Unit * dist, params)
		return hit == nil
	end
	if rayClear(rootPart.Position, targetPos) then
		return { targetPos }
	end

	-- 3) Fallback final : petite étape devant, on laisse MoveTo gérer
	local flat = Vector3.new(targetPos.X - rootPart.Position.X, 0, targetPos.Z - rootPart.Position.Z)
	if flat.Magnitude > 0.1 then
		local mid = rootPart.Position + flat.Unit * math.min(8, flat.Magnitude * 0.5)
		return { mid + Vector3.new(0, 2, 0) }
	end
	return {}
end

local gotoWalkSwitch = createSwitch(movePage, "Go to Walk (click sol)", 150, function(on)
	gotoWalkState.enabled = on
	gotoWalkState.active = on
	if not on then
		gotoWalkState.target = nil
		gotoWalkState.path = {}
		clearWalkVisuals()
	end
end)

createSwitch(movePage, "Saut infini", 192, function(on)
	jumpState.infinite = on
end)

local function refreshNoClipSwitch()
	noclipSwitch.set(false)
end

local walkSlider = createSlider(movePage, "Vitesse marche", 234, 1, 250, 16, function(v)
	walkSpeedState.value = math.floor(v)
	updateCharacter()
	if humanoid then humanoid.WalkSpeed = walkSpeedState.value end
end, Color3.fromRGB(255, 100, 100))

local walkResetBtn = createButton(movePage, "Reset vitesse", 288, Color3.fromRGB(80, 80, 90), function()
	walkSpeedState.value = 16
	walkSlider.set(16)
	updateCharacter()
	if humanoid then humanoid.WalkSpeed = 16 end
end)

local platformLabel = Instance.new("TextLabel")
platformLabel.Size = UDim2.new(1, -16, 0, 30)
platformLabel.Position = UDim2.new(0, 8, 0, 328)
platformLabel.BackgroundTransparency = 1
platformLabel.Text = "Plateforme: F10 (+=monter -=descendre)"
platformLabel.Font = Enum.Font.Gotham
platformLabel.TextSize = 11
platformLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
platformLabel.TextXAlignment = Enum.TextXAlignment.Left
platformLabel.Parent = movePage


-- ============= LOCAL (ZERO-G + TIME + GRAVITY) =============
local localState = {
	zeroGravity = false,
	normalGravity = Workspace.Gravity,
	customGravity = 196.2,
	timeOfDay = 12,
}

local zeroGSwitch = createSwitch(localPage, "Zero Gravité", 10, function(on)
	localState.zeroGravity = on
	if on then
		Workspace.Gravity = 0
	else
		Workspace.Gravity = localState.customGravity
	end

	local character = LocalPlayer.Character
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

-- Conteneur gravité personnalisé (slider précis + input + reset)
local gravityContainer = Instance.new("Frame")
gravityContainer.Size = UDim2.new(1, -16, 0, 86)
gravityContainer.Position = UDim2.new(0, 8, 0, 56)
gravityContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
gravityContainer.BorderSizePixel = 0
gravityContainer.Parent = localPage
createCorner(gravityContainer, 10)
createStroke(gravityContainer, Color3.fromRGB(45, 45, 55), 1)

local gravityLabel = Instance.new("TextLabel")
gravityLabel.Size = UDim2.new(1, -10, 0, 18)
gravityLabel.Position = UDim2.new(0, 8, 0, 5)
gravityLabel.BackgroundTransparency = 1
gravityLabel.Text = "Gravité custom : 196.2"
gravityLabel.Font = Enum.Font.GothamSemibold
gravityLabel.TextSize = 12
gravityLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
gravityLabel.TextXAlignment = Enum.TextXAlignment.Left
gravityLabel.Parent = gravityContainer

local gravityTrack = Instance.new("Frame")
gravityTrack.Size = UDim2.new(1, -110, 0, 6)
gravityTrack.Position = UDim2.new(0, 8, 0, 30)
gravityTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
gravityTrack.BorderSizePixel = 0
gravityTrack.Parent = gravityContainer
createCorner(gravityTrack, 3)

local gravityFill = Instance.new("Frame")
gravityFill.Size = UDim2.new(196.2 / 300, 0, 1, 0)
gravityFill.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
gravityFill.BorderSizePixel = 0
gravityFill.Parent = gravityTrack
createCorner(gravityFill, 3)

local gravityInput = Instance.new("TextBox")
gravityInput.Size = UDim2.new(0, 80, 0, 22)
gravityInput.Position = UDim2.new(1, -90, 0, 22)
gravityInput.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
gravityInput.TextColor3 = Color3.fromRGB(230, 230, 230)
gravityInput.PlaceholderText = "196.2"
gravityInput.Text = "196.2"
gravityInput.Font = Enum.Font.Gotham
gravityInput.TextSize = 12
gravityInput.TextXAlignment = Enum.TextXAlignment.Center
gravityInput.ClearTextOnFocus = true
gravityInput.Parent = gravityContainer
createCorner(gravityInput, 6)
createStroke(gravityInput, Color3.fromRGB(80, 80, 100), 1)

local function setGravityExact(v)
	v = tonumber(v)
	if not v then return end
	v = math.clamp(math.floor(v + 0.5), 0, 300)
	localState.customGravity = v
	Workspace.Gravity = v
	gravityLabel.Text = "Gravité custom : " .. v
	gravityInput.Text = tostring(v)
	gravityFill.Size = UDim2.new(v / 300, 0, 1, 0)
end

local draggingGravity = false
local function gravityFromX(x)
	local rel = math.clamp((x - gravityTrack.AbsolutePosition.X) / gravityTrack.AbsoluteSize.X, 0, 1)
	return math.floor(rel * 300 + 0.5)
end

gravityTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingGravity = true
		setGravityExact(gravityFromX(input.Position.X))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingGravity = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if draggingGravity and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		setGravityExact(gravityFromX(input.Position.X))
	end
end)

gravityInput.FocusLost:Connect(function(enterPressed)
	setGravityExact(gravityInput.Text)
end)

local resetGravityBtn = createButton(localPage, "Reset gravité normale", 148, Color3.fromRGB(80, 80, 90), function()
	setGravityExact(196.2)
end)
resetGravityBtn.Size = UDim2.new(1, -16, 0, 30)
resetGravityBtn.Position = UDim2.new(0, 8, 0, 148)

local timeSwitch = createSwitch(localPage, "Temps custom", 200, function(on)
	if on then
		Lighting.TimeOfDay = string.format("%02d:00:00", localState.timeOfDay)
	else
		Lighting.TimeOfDay = "12:00:00"
	end
end)

createSlider(localPage, "Heure du jour", 246, 0, 24, 12, function(v)
	localState.timeOfDay = math.floor(v)
	Lighting.TimeOfDay = string.format("%02d:00:00", localState.timeOfDay)
end, Color3.fromRGB(255, 180, 60))

createSwitch(localPage, "Freeze temps", 292, function(on)
	if on then
		Lighting.ClockTime = localState.timeOfDay
	end
end)

createButton(localPage, "Reset monde", 348, Color3.fromRGB(80, 80, 90), function()
	Workspace.Gravity = localState.normalGravity
	Lighting.TimeOfDay = "12:00:00"
	zeroGSwitch.set(false)
	localState.customGravity = 196.2
	setGravityExact(196.2)
	localState.timeOfDay = 12
end)

-- Switch ESP Global dans l'onglet Local
local globalESPEnabled = false
local globalESPSwitch = createSwitch(localPage, "ESP Global", 404, function(on)
	globalESPEnabled = on
	espState.enabled = on
	if on then
		refreshESP()
	else
		clearESP()
	end
end)


-- ============= AUTO CLICKER =============
local autoClickState = {
	toolActive = false,   -- le switch (faux tool dans le backpack)
	clickEnabled = false, -- le moteur d'autoclick actif
	speed = 0.05,
	mode = "auto",        -- "auto" | "rapid"
	activeThread = nil,
	fakeTool = nil,
	controlPos = nil,
}

local function setAutoClickSave()
	if not autoClickState then return end
	panelMemory.autoClick = {
		pos = autoClickState.controlPos and {autoClickState.controlPos.X.Scale, autoClickState.controlPos.X.Offset, autoClickState.controlPos.Y.Scale, autoClickState.controlPos.Y.Offset},
		speed = autoClickState.speed,
	}
	if acTarget and acTarget.targetType then
		panelMemory.autoClick.targetType = acTarget.targetType
	end
end

local function removeFakeTool()
	if autoClickState.fakeTool and autoClickState.fakeTool.Parent then
		autoClickState.fakeTool:Destroy()
	end
	autoClickState.fakeTool = nil
end

local function createFakeTool()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then return end
	removeFakeTool()
	local tool = Instance.new("Tool")
	tool.Name = "AutoClicker_Tool"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Configurer puis activer l'autoclick"
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(0.1, 0.1, 0.1)
	h.Transparency = 1
	h.CanCollide = false
	h.Anchored = true
	h.Parent = tool
	-- Quand on s'équipe du tool, on ouvre le mini panel
	tool.Equipped:Connect(function()
		clickControl.Visible = true
		task.defer(clampControl)
	end)
	tool.Unequipped:Connect(function()
		-- on ne cache pas le panel pour garder le controle visible
	end)
	tool.Parent = backpack
	autoClickState.fakeTool = tool
	return tool
end

local function stopAutoClickEngine()
	autoClickState.clickEnabled = false
	if autoClickState.activeThread then
		autoClickState.activeThread = nil
	end
	destroyAutoClickMarker()
	statusLabel.Text = "Statut : arret"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	pcall(hideMarker)
end

local function onToolDeactivated()
	-- quand le tool est retiré de l'inventaire / personnage mort
	stopAutoClickEngine()
end

local VirtualInputManager
pcall(function()
	VirtualInputManager = (getvirtualinputmanager and getvirtualinputmanager()) or game:GetService("VirtualInputManager")
end)

-- Position FIXE capturée quand l'utilisateur clique "Démarrer AutoClick".
-- C'est cette position qu'on réutilise à chaque tick (le curseur peut bouger).
local acTarget = {
	captured = false,
	position = Vector2.new(0, 0),   -- position écran
	worldHit = nil,                 -- Mouse.Hit sous le curseur à la capture
	worldTarget = nil,              -- l'instance Part/GUI sous le curseur à la capture
	targetType = "any",             -- "any" | "world" | "gui"
	markerPart = nil                -- Part 3D visuelle au worldHit.Position (marker dans la map)
}

-- Fonctions marker autoclick: définies inline ci-dessous
;(function()
	function destroyAutoClickMarker()
		if acTarget.markerPart and acTarget.markerPart.Parent then
			pcall(function() acTarget.markerPart:Destroy() end)
		end
		acTarget.markerPart = nil
	end
	function refreshAutoClickMarker()
		destroyAutoClickMarker()
		if not acTarget.worldHit then return end
		local marker = Instance.new("Part")
		marker.Name = "AutoClickMarker"
		marker.Size = Vector3.new(0.6, 0.6, 0.6)
		marker.Shape = Enum.PartType.Ball
		marker.Anchored = true
		marker.CanCollide = false
		marker.CastShadow = false
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(255, 80, 80)
		marker.Transparency = 0.3
		marker.Position = acTarget.worldHit.Position
		marker.Parent = workspace
		acTarget.markerPart = marker
	end
end)()

-- Met à jour la position FIXE = le curseur au moment de l'appel
local function captureTargetFromCursor()
	local mouse = LocalPlayer:GetMouse()
	if not mouse then return false end
	acTarget.captured = true
	acTarget.position = UserInputService:GetMouseLocation()
	acTarget.worldHit = mouse.Hit
	acTarget.worldTarget = mouse.Target
	refreshAutoClickMarker()
	return true
end

-- Trouve le bouton GUI au point (Vector2) en descendant l'arbre GUI
local function findGuiButtonAt(point, root)
	if not root then return nil end
	local best = nil
	local function walk(obj)
		if obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("TextButton") then
			if obj.Visible and obj.Active ~= false then
				local ap = obj.AbsolutePosition
				local as = obj.AbsoluteSize
				if as.X > 0 and as.Y > 0 then
					if point.X >= ap.X and point.X <= ap.X + as.X
						and point.Y >= ap.Y and point.Y <= ap.Y + as.Y then
						-- Préfère le bouton le plus profond (plus petit)
						if not best or (as.X * as.Y) < (best.AbsoluteSize.X * best.AbsoluteSize.Y) then
							best = obj
						end
					end
				end
			end
		end
		for _, child in ipairs(obj:GetChildren()) do
			local ok, _ = pcall(walk, child)
			if not ok then end
		end
	end
	pcall(walk, root)
	return best
end

-- ClickDetector sous le point écran — raycast caméra vers l'arrière
local function findClickDetectorAtScreen(point)
	local camera = Workspace.CurrentCamera
	if not camera then return nil end
	local unit = camera:ScreenPointToRay(point.X, point.Y)
	local hit = Workspace:Raycast(unit.Origin, unit.Direction * 1000)
	if not hit then return nil end
	local inst = hit.Instance
	if inst and inst:IsA("ClickDetector") then return inst end
	if inst then
		local cd = inst:FindFirstChildOfClass("ClickDetector")
		if cd then return cd end
		if inst.Parent then
			local cd2 = inst.Parent:FindFirstChildOfClass("ClickDetector")
			if cd2 then return cd2 end
		end
	end
	return nil
end

-- Un seul clic à la position FIXE acTarget (pas le curseur actuel)
local function fireClickFixed(useNative)
	if not acTarget.captured then return false end
	local pt = acTarget.position
	local clicked = false
	local mode = acTarget.targetType

	-- 1) GUI au point fixe
	if mode == "any" or mode == "gui" then
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			local btn = findGuiButtonAt(pt, playerGui)
			if btn then
				pcall(function()
					btn.MouseEnter:Fire()
					btn.MouseButton1Down:Fire(pt - btn.AbsolutePosition)
					btn.MouseButton1Click:Fire()
					btn.MouseButton1Up:Fire(pt - btn.AbsolutePosition)
				end)
				clicked = true
			end
		end
	end

	-- 2) ClickDetector dans le monde au point fixe
	if not clicked and (mode == "any" or mode == "world") then
		local cd = findClickDetectorAtScreen(pt)
		if cd then
			pcall(function() fireclickdetector(cd) end)
			clicked = true
		end
	end

	-- 2b) ProximityPrompt dans le monde au point fixe (clic souris direct)
	if not clicked and (mode == "any" or mode == "world") then
		local cam = workspace.CurrentCamera
		if cam then
			local ray = cam:ScreenPointToRay(pt.X, pt.Y)
			local pp = nil
			-- Cherche un ProximityPrompt dont l'ObjectText chevauche le curseur
			for _, desc in ipairs(workspace:GetDescendants()) do
				if desc:IsA("ProximityPrompt") and desc.Enabled and desc.Parent then
					local att = desc.Parent
					if att:IsA("Attachment") and att.Parent then
						local p3 = att.WorldPosition
						-- Projection du point curseur sur le rayon, distance au point 3D
						local toPoint = p3 - ray.Origin
						local t = toPoint:Dot(ray.Direction)
						if t > 0 then
							local closest = ray.Origin + ray.Direction * t
							if (closest - p3).Magnitude <= math.max(2, desc.MaxActivationDistance) then
								pp = desc
								break
							end
						end
					end
				end
			end
			if pp then
				pcall(function() fireproximityprompt(pp) end)
				clicked = true
			end
		end
	end

	-- 2c) Fallback : clic souris NATIF en mode world/any quand aucune cible API ne répond
	-- (VIM one-shot, pas en loop : contourne les GuiObject custom qui n'écoutent pas :Fire())
	if not clicked and (mode == "any" or mode == "world") and VirtualInputManager then
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(pt.X, pt.Y, 0, true, game, 0)
			task.wait(0.01)
			VirtualInputManager:SendMouseButtonEvent(pt.X, pt.Y, 0, false, game, 0)
		end)
		clicked = true
	end

	-- 3) Vrai clic souris natif au point FIXE (manuel uniquement)
	if useNative and VirtualInputManager then
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(pt.X, pt.Y, 0, true, game, 0)
			task.wait(0.005)
			VirtualInputManager:SendMouseButtonEvent(pt.X, pt.Y, 0, false, game, 0)
		end)
		clicked = true
	end

	return clicked
end

local function startAutoClickEngine()
	stopAutoClickEngine()
	-- Auto-capture : si rien n'est capturé, on prend la position du curseur maintenant
	if not acTarget.captured then
		if not captureTargetFromCursor() then return end
	end
	autoClickState.clickEnabled = true
	statusLabel.Text = "Statut : actif"
	statusLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
	local threadId = {}
	autoClickState.activeThread = threadId
	local interval = math.max(0.001, autoClickState.speed)
	-- Boucle : utilise VIM fallback (force=true) pour attraper les clics souris natifs du jeu
	-- En mode "gui" seul, on n'utilise PAS le VIM (risque de cliquer dans le jeu derrière les menus)
	local useNative = (acTarget.targetType ~= "gui")
	task.spawn(function()
		while autoClickState.clickEnabled and autoClickState.activeThread == threadId do
			fireClickFixed(useNative)
			task.wait(interval)
		end
	end)
end

local autoClickContainer = Instance.new("Frame")
autoClickContainer.Size = UDim2.new(1, -16, 0, 260)
autoClickContainer.Position = UDim2.new(0, 8, 0, 460)
autoClickContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
autoClickContainer.BorderSizePixel = 0
autoClickContainer.Parent = localPage
createCorner(autoClickContainer, 10)
createStroke(autoClickContainer, Color3.fromRGB(45, 45, 55), 1)

local autoClickTitle = Instance.new("TextLabel")
autoClickTitle.Size = UDim2.new(1, -10, 0, 18)
autoClickTitle.Position = UDim2.new(0, 8, 0, 6)
autoClickTitle.BackgroundTransparency = 1
autoClickTitle.Text = "Auto Clicker"
autoClickTitle.Font = Enum.Font.GothamBold
autoClickTitle.TextSize = 13
autoClickTitle.TextColor3 = Color3.fromRGB(210, 210, 210)
autoClickTitle.TextXAlignment = Enum.TextXAlignment.Left
autoClickTitle.Parent = autoClickContainer

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -16, 0, 28)
infoLabel.Position = UDim2.new(0, 8, 0, 22)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "1) Choisis la cible (Les 2 / Monde / GUI). 2) Place le curseur sur l'item. 3) Clic '1 Clic ici' OU 'Démarrer AutoClick' — la position est FIXÉE à l'écran et le clic est répété même si tu bouges la souris."
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 10
infoLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
infoLabel.TextWrapped = true
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = autoClickContainer

-- Marqueur visuel : petit point rouge à la position FIXE capturée
local acMarker = Instance.new("Frame")
acMarker.Name = "_ACMarker"
acMarker.Size = UDim2.new(0, 14, 0, 14)
acMarker.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
acMarker.BackgroundTransparency = 0.25
acMarker.BorderSizePixel = 0
acMarker.Visible = false
acMarker.ZIndex = 130
acMarker.AnchorPoint = Vector2.new(0.5, 0.5)
acMarker.Parent = screenGui
createCorner(acMarker, 7)

local acMarkerStroke = Instance.new("UIStroke")
acMarkerStroke.Color = Color3.fromRGB(255, 200, 200)
acMarkerStroke.Thickness = 1.5
acMarkerStroke.Parent = acMarker

local function showMarkerAt(screenPos)
	acMarker.Visible = true
	acMarker.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
end
local function hideMarker()
	acMarker.Visible = false
end

local _origCapture = captureTargetFromCursor
captureTargetFromCursor = function()
	local ok = _origCapture()
	if ok then showMarkerAt(acTarget.position) end
	return ok
end

-- Switch : active/désactive UNIQUEMENT le faux tool dans le backpack
local autoClickSwitch = createSwitch(autoClickContainer, "Activer (touche G) - ouvre mini panel", 56, function(on)
	autoClickState.toolActive = on
	if on then
		-- Plus de fake tool : on ouvre juste le mini panel flottant
		clickControl.Visible = true
	else
		stopAutoClickEngine()
		clickControl.Visible = false
	end
	setAutoClickSave()
end)

-- Raccourci touche G : toggle le mini panel d'autoclick (pas besoin de tool !)
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.G then
		if clickControl then
			clickControl.Visible = not clickControl.Visible
			autoClickState.toolActive = clickControl.Visible
			-- Sync le switch visuellement (mais sans declencher la callback)
			-- (le state du switch est gere en interne, pas besoin de le toucher)
		end
	end
end)

local modeFrame = Instance.new("Frame")
modeFrame.Size = UDim2.new(1, -16, 0, 26)
modeFrame.Position = UDim2.new(0, 8, 0, 100)
modeFrame.BackgroundTransparency = 1
modeFrame.Parent = autoClickContainer

local modes = {any = "Les 2", world = "Monde", gui = "GUI"}
local modeOrder = {"any", "world", "gui"}
local modeBtns = {}
for i, m in ipairs(modeOrder) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.32, -2, 1, 0)
	btn.Position = UDim2.new((i - 1) * 0.34, 0, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	btn.Text = modes[m]
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 11
	btn.TextColor3 = Color3.fromRGB(200, 200, 200)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = modeFrame
	createCorner(btn, 6)
	modeBtns[m] = btn
	btn.MouseButton1Click:Connect(function()
		acTarget.targetType = m
		for _, b in pairs(modeBtns) do tween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		tween(btn, {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
	end)
end
tween(modeBtns["any"], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -10, 0, 16)
speedLabel.Position = UDim2.new(0, 8, 0, 132)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Vitesse : 0.05s"
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 11
speedLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = autoClickContainer

local speedSliderTrack = Instance.new("Frame")
speedSliderTrack.Size = UDim2.new(1, -16, 0, 6)
speedSliderTrack.Position = UDim2.new(0, 8, 0, 152)
speedSliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
speedSliderTrack.BorderSizePixel = 0
speedSliderTrack.Parent = autoClickContainer
createCorner(speedSliderTrack, 3)

local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.new(0.5, 0, 1, 0)
speedFill.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
speedFill.BorderSizePixel = 0
speedFill.Parent = speedSliderTrack
createCorner(speedFill, 3)

local draggingSpeed = false
local function speedFromX(x)
	local rel = math.clamp((x - speedSliderTrack.AbsolutePosition.X) / speedSliderTrack.AbsoluteSize.X, 0, 1)
	return 0.001 + rel * 0.199
end
local function setSpeed(s)
	s = math.clamp(math.floor(s * 1000) / 1000, 0.001, 0.2)
	autoClickState.speed = s
	speedLabel.Text = "Vitesse : " .. s .. "s"
	speedFill.Size = UDim2.new((s - 0.001) / 0.199, 0, 1, 0)
	if autoClickState.clickEnabled then startAutoClickEngine() end
	setAutoClickSave()
end
setSpeed(0.05)

speedSliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSpeed = true
		setSpeed(speedFromX(input.Position.X))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSpeed = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		setSpeed(speedFromX(input.Position.X))
	end
end)

-- Mini panneau de contrôle flottant
local clickControl = Instance.new("Frame")
clickControl.Name = "AutoClickControl"
clickControl.Size = UDim2.new(0, 140, 0, 170)
clickControl.Position = UDim2.new(0.5, -70, 0.5, -85)
clickControl.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
clickControl.BackgroundTransparency = 0.15
clickControl.BorderSizePixel = 0
clickControl.ZIndex = 120
clickControl.Parent = screenGui
clickControl.Active = true
clickControl.Visible = false
-- PAS de Draggable Roblox (entre en conflit avec le drag manuel sur controlHeader)
createCorner(clickControl, 12)
createStroke(clickControl, Color3.fromRGB(80, 80, 100), 1)

local controlHeader = Instance.new("TextButton")
controlHeader.AutoButtonColor = false
controlHeader.Size = UDim2.new(1, 0, 0, 24)
controlHeader.BackgroundTransparency = 1
controlHeader.Text = ":: AutoClick ::"
controlHeader.Font = Enum.Font.GothamBold
controlHeader.TextSize = 12
controlHeader.TextColor3 = Color3.fromRGB(230, 230, 230)
controlHeader.ZIndex = 122
controlHeader.Parent = clickControl

-- Drag manuel du clickControl depuis le header (TextButton avec AutoButtonColor=false)
-- Listener global sur UserInputService pour que le drag suive la souris même hors du header
local ccDragging, ccDragStart, ccStartPos = false, nil, nil
controlHeader.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		ccDragging = true
		ccDragStart = input.Position
		ccStartPos = clickControl.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if ccDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		if ccStartPos and ccDragStart then
			local dx = input.Position.X - ccDragStart.X
			local dy = input.Position.Y - ccDragStart.Y
			clickControl.Position = UDim2.new(ccStartPos.X.Scale, ccStartPos.X.Offset + dx, ccStartPos.Y.Scale, ccStartPos.Y.Offset + dy)
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		ccDragging = false
	end
end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 16)
statusLabel.Position = UDim2.new(0.05, 0, 0, 26)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Statut : arret"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.ZIndex = 122
statusLabel.Parent = clickControl

local execBtn = Instance.new("TextButton")
execBtn.Size = UDim2.new(0.9, 0, 0, 28)
execBtn.Position = UDim2.new(0.05, 0, 0, 46)
execBtn.ZIndex = 122
execBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
execBtn.Text = "1 Clic ici"
execBtn.Font = Enum.Font.GothamSemibold
execBtn.TextSize = 10
execBtn.TextColor3 = Color3.new(1, 1, 1)
execBtn.BorderSizePixel = 0
execBtn.AutoButtonColor = false
execBtn.Parent = clickControl
createCorner(execBtn, 6)
execBtn.MouseButton1Click:Connect(function()
	captureTargetFromCursor()
	fireClickFixed(true)
end)

local multiBtn = Instance.new("TextButton")
multiBtn.Size = UDim2.new(0.9, 0, 0, 28)
multiBtn.Position = UDim2.new(0.05, 0, 0, 78)
multiBtn.ZIndex = 122
multiBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
multiBtn.Text = "Multi Clic x5"
multiBtn.Font = Enum.Font.GothamSemibold
multiBtn.TextSize = 10
multiBtn.TextColor3 = Color3.new(1, 1, 1)
multiBtn.BorderSizePixel = 0
multiBtn.AutoButtonColor = false
multiBtn.Parent = clickControl
createCorner(multiBtn, 6)
multiBtn.MouseButton1Click:Connect(function()
	captureTargetFromCursor()
	for i = 1, 5 do
		task.delay((i - 1) * 0.01, function() fireClickFixed(true) end)
	end
end)

local toggleClickBtn = Instance.new("TextButton")
toggleClickBtn.Size = UDim2.new(0.9, 0, 0, 28)
toggleClickBtn.Position = UDim2.new(0.05, 0, 0, 110)
toggleClickBtn.ZIndex = 122
toggleClickBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
toggleClickBtn.Text = "Demarrer AutoClick"
toggleClickBtn.Font = Enum.Font.GothamSemibold
toggleClickBtn.TextSize = 10
toggleClickBtn.TextColor3 = Color3.new(1, 1, 1)
toggleClickBtn.BorderSizePixel = 0
toggleClickBtn.AutoButtonColor = false
toggleClickBtn.Parent = clickControl
createCorner(toggleClickBtn, 6)
toggleClickBtn.MouseButton1Click:Connect(function()
	if autoClickState.clickEnabled then
		stopAutoClickEngine()
		toggleClickBtn.Text = "Demarrer AutoClick"
		toggleClickBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	else
		captureTargetFromCursor()
		startAutoClickEngine()
		toggleClickBtn.Text = "Arreter AutoClick"
		toggleClickBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	end
end)

local closeControlBtn = Instance.new("TextButton")
closeControlBtn.Size = UDim2.new(0.9, 0, 0, 18)
closeControlBtn.Position = UDim2.new(0.05, 0, 0, 142)
closeControlBtn.ZIndex = 122
closeControlBtn.BackgroundTransparency = 1
closeControlBtn.Text = "Cacher"
closeControlBtn.Font = Enum.Font.Gotham
closeControlBtn.TextSize = 10
closeControlBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
closeControlBtn.BorderSizePixel = 0
closeControlBtn.AutoButtonColor = false
closeControlBtn.Parent = clickControl
closeControlBtn.MouseButton1Click:Connect(function()
	clickControl.Visible = false
end)

-- Petite poignée de drag en bas à droite du panneau
local dragHandle = Instance.new("TextButton")
dragHandle.Name = "DragHandle"
dragHandle.Size = UDim2.new(0, 22, 0, 22)
dragHandle.Position = UDim2.new(1, -24, 1, -24)
dragHandle.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
dragHandle.Text = "•"
dragHandle.Font = Enum.Font.GothamBold
dragHandle.TextSize = 14
dragHandle.TextColor3 = Color3.fromRGB(200, 200, 220)
dragHandle.ZIndex = 125
dragHandle.Parent = clickControl
createCorner(dragHandle, 11)

local function clampControl()
	local s = screenGui.AbsoluteSize
	local sz = clickControl.AbsoluteSize
	local x = math.clamp(clickControl.AbsolutePosition.X, 0, math.max(0, s.X - sz.X))
	local y = math.clamp(clickControl.AbsolutePosition.Y, 0, math.max(0, s.Y - sz.Y))
	clickControl.Position = UDim2.new(0, x, 0, y)
end

clickControl:GetPropertyChangedSignal("Position"):Connect(function()
	task.defer(clampControl)
end)

local controlToggle = createButton(autoClickContainer, "Afficher/Cacher panneau", 198, Color3.fromRGB(80, 60, 160), function()
	clickControl.Visible = not clickControl.Visible
end)
controlToggle.Size = UDim2.new(1, -16, 0, 28)
controlToggle.Position = UDim2.new(0, 8, 0, 226)

-- Restaurer sauvegarde
if panelMemory.autoClick and panelMemory.autoClick.pos then
	local p = panelMemory.autoClick.pos
	clickControl.Position = UDim2.new(p[1], p[2], p[3], p[4])
end
if panelMemory.autoClick and panelMemory.autoClick.speed then
	setSpeed(panelMemory.autoClick.speed)
end
if panelMemory.autoClick and panelMemory.autoClick.targetType then
	local saved = panelMemory.autoClick.targetType
	if modes[saved] then
		acTarget.targetType = saved
		for _, b in pairs(modeBtns) do tween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		tween(modeBtns[saved], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
	end
elseif panelMemory.autoClick and panelMemory.autoClick.mode then
	local saved = panelMemory.autoClick.mode
	if saved == "rapid" or saved == "auto" then saved = "any" end
	if modes[saved] then
		acTarget.targetType = saved
		for _, b in pairs(modeBtns) do tween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		tween(modeBtns[saved], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
	end
end

clickControl:GetPropertyChangedSignal("Position"):Connect(function()
	autoClickState.controlPos = clickControl.Position
	setAutoClickSave()
end)
-- Déplace tous les contrôles locaux dans la scrollview
reparentChildrenToLocalScroll()

-- Agrandit le scroll pour accueillir l'autoclicker
localScroll.CanvasSize = UDim2.new(0, 0, 0, 900)

-- Empêche le panel d'être poussé sous le chat au démarrage
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

RunService.RenderStepped:Connect(function()
	if localState.zeroGravity then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local cam = Workspace.CurrentCamera
		if hrp and UserInputService:IsKeyDown(Enum.KeyCode.W) then
			hrp.AssemblyLinearVelocity = cam.CFrame.LookVector * 16
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if jumpState.infinite and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E then
		if flyState.flying then
			stopFly()
		else
			startFly()
		end
	end
	if input.KeyCode == Enum.KeyCode.F10 then
		platformState.enabled = not platformState.enabled
		if platformState.enabled then
			if not platformState.part then
				platformState.part = Instance.new("Part")
				platformState.part.Anchored = true
				platformState.part.CanCollide = true
				platformState.part.Transparency = 1
				platformState.part.Name = "InvisiblePlatform"
				-- Plate GIGANTESQUE (couvre la map entière) et FIXE en X/Z : on ne suit plus la position
				platformState.part.Size = Vector3.new(2000, 1, 2000)
				platformState.part.Parent = Workspace
			end
			-- Détermine la hauteur initiale de la plate selon le contexte (à pied / en voiture)
			-- La plate ne suit PAS la position, seulement la hauteur capturée ici
			local seatPart = humanoid and humanoid.SeatPart
			local capturedY
			if seatPart and seatPart:IsA("BasePart") then
				-- En voiture : plate sous les roues (marge 1.5 stud pour pas toucher le châssis)
				local seatModel = seatPart:FindFirstAncestorOfClass("Model") or seatPart.Parent
				if seatModel and seatModel ~= character then
					local ok, cf, size = pcall(function() return seatModel:GetBoundingBox() end)
					if ok and cf and size then
						capturedY = cf.Position.Y - size.Y / 2 - 1.5
					end
				end
				if not capturedY then
					local cf = seatPart.CFrame
					local size = seatPart.Size
					capturedY = cf.Position.Y - size.Y / 2 - 1.5
				end
			elseif character then
				-- À pied : sous nos pieds (marge 0.2 stud)
				local ok, cf, size = pcall(function() return character:GetBoundingBox() end)
				if ok and cf and size then
					capturedY = cf.Position.Y - size.Y / 2 - 0.2
				elseif rootPart then
					capturedY = rootPart.Position.Y - 3
				else
					capturedY = (character:GetPivot().Position.Y) - 3
				end
			end
			if capturedY then
				platformState.y = capturedY
				platformState.offset = 0
				platformState.smoothedOffset = 0
				-- Centre la plate sur le joueur/voiture au moment du toggle, puis elle reste FIXE
				local anchorPos = rootPart and rootPart.Position or (humanoid and humanoid.SeatPart and humanoid.SeatPart.Position)
				if anchorPos then
					platformState.part.CFrame = CFrame.new(anchorPos.X, capturedY, anchorPos.Z)
				else
					platformState.part.CFrame = CFrame.new(0, capturedY, 0)
				end
			end
		else
			if platformState.part then
				platformState.part:Destroy()
				platformState.part = nil
			end
		end
	end
end)

RunService.Stepped:Connect(function(_, dt)
	updateCharacter()
	if noclipState.enabled and character then
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
	if platformState.enabled and platformState.part then
		-- Plate FIXE en X/Z : on ne tracke plus la position, on ajuste juste la hauteur
		-- avec les touches +/-
		if UserInputService:IsKeyDown(Enum.KeyCode.Equals) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadPlus) then
			platformState.offset = platformState.offset + 25 * dt
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Minus) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadMinus) then
			platformState.offset = platformState.offset - 25 * dt
		end
		-- Lissage de la position verticale (évite les sauts secs)
		local smoothing = math.min(1, dt * 12)
		platformState.smoothedOffset = platformState.smoothedOffset + (platformState.offset - platformState.smoothedOffset) * smoothing
		-- Conserve la position X/Z initiale, change juste Y
		local cur = platformState.part.CFrame
		platformState.part.CFrame = CFrame.new(cur.X, platformState.y + platformState.smoothedOffset, cur.Z)
	end
	-- Go to Walk : déplace le humanoid vers chaque waypoint avec MoveTo
	-- Go to Walk : deplace le humanoid vers chaque waypoint avec MoveTo + saut auto si bloque
	if humanoid and rootPart and gotoWalkState.active and #gotoWalkState.path > 0 then
		local wp = gotoWalkState.path[1]
		local flatDist = Vector3.new(rootPart.Position.X - wp.X, 0, rootPart.Position.Z - wp.Z).Magnitude
		-- Detection de blocage : vitesse reelle trop faible par rapport a la distance
		local vel = rootPart.AssemblyLinearVelocity
		local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		if flatDist > 3 and flatSpeed < 1 then
			-- Bloque
			if gotoWalkState.stuckSince == nil then gotoWalkState.stuckSince = tick() end
			if tick() - gotoWalkState.stuckSince > 0.5 then
				-- Raycast devant : si on touche un mur, on saute
				local frontParams = RaycastParams.new()
				frontParams.FilterDescendantsInstances = {character}
				frontParams.FilterType = Enum.RaycastFilterType.Exclude
				local frontRay = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 3, frontParams)
				if frontRay then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					task.wait(0.1)
					humanoid.Jump = true
				end
				-- Si toujours bloque apres 2s, on recalcule le chemin
				if tick() - gotoWalkState.stuckSince > 2.5 and gotoWalkState.target then
					gotoWalkState.stuckSince = nil
					local newPath = computePathTo(gotoWalkState.target)
					if newPath and #newPath > 0 then
						gotoWalkState.path = newPath
						visualizeWaypoints(newPath)
						humanoid:MoveTo(newPath[1])
						gotoWalkState.lastMoveTo = tick()
					end
				end
			end
		else
			gotoWalkState.stuckSince = nil
		end
		if flatDist < 3 then
			table.remove(gotoWalkState.path, 1)
			if #gotoWalkState.path == 0 then
				gotoWalkState.target = nil
				gotoWalkState.active = false
				gotoWalkSwitch.set(false)
				clearWalkVisuals()
			else
				humanoid:MoveTo(gotoWalkState.path[1])
				gotoWalkState.lastMoveTo = tick()
			end
		else
			-- Re-emit MoveTo periodiquement car Roblox l'abandonne apres 8s
			if tick() - (gotoWalkState.lastMoveTo or 0) > 4 then
				humanoid:MoveTo(wp)
				gotoWalkState.lastMoveTo = tick()
			end
		end
	end
	
	if humanoid and math.abs(humanoid.WalkSpeed - walkSpeedState.value) > 0.5 and not flyState.flying then
			humanoid.WalkSpeed = walkSpeedState.value
		end
	end)


	-- ===== Boucle ISOLÉE pour maintenir WalkSpeed (ne dépend pas de platform/gotoWalk) =====
	-- Si la grosse boucle au-dessus crash (ex: gotoWalk avec humanoid nil), WalkSpeed est quand
	-- même appliqué. Cette boucle est pcall-wrapped donc JAMAIS elle ne s'arrête.
	RunService.RenderStepped:Connect(function()
		pcall(function()
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and not flyState.flying then
				local target = walkSpeedState.value
				if math.abs(hum.WalkSpeed - target) > 0.5 then
					hum.WalkSpeed = target
				end
			end
		end)
	end)


-- ============= EXTRA =============
local fullbrightState = { enabled = false, old = {} }
local clickTPState = { enabled = false }
local hitboxState = { enabled = false }

-- FIX: extraPage overflow (17+ items Y=10..730 > panel height 520px). Wrap in ScrollingFrame.
local extraScroll = Instance.new("ScrollingFrame")
extraScroll.Name = "ExtraScroll"
extraScroll.Size = UDim2.new(1, -10, 1, -10)
extraScroll.Position = UDim2.new(0, 5, 0, 5)
extraScroll.BackgroundTransparency = 1
extraScroll.ScrollBarThickness = 4
extraScroll.BorderSizePixel = 0
extraScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
extraScroll.Parent = extraPage

local extraLayout = Instance.new("UIListLayout")
extraLayout.Padding = UDim.new(0, 6)
extraLayout.SortOrder = Enum.SortOrder.LayoutOrder
extraLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
extraLayout.Parent = extraScroll

extraLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	extraScroll.CanvasSize = UDim2.new(0, 0, 0, extraLayout.AbsoluteContentSize.Y + 10)
end)
task.defer(function()
	extraScroll.CanvasSize = UDim2.new(0, 0, 0, extraLayout.AbsoluteContentSize.Y + 10)
end)

-- === Carte "Stats serveur" (6 stats en grille) — déplacée depuis Joueurs (trop large) ===
-- WRAP dans local function + appel pour isoler les locals
local function _initServerStatsCard()
	local statsCard = Instance.new("Frame")
	statsCard.Name = "StatsCard"
	statsCard.Size = UDim2.new(1, -10, 0, 0)
	statsCard.AutomaticSize = Enum.AutomaticSize.Y
	statsCard.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	statsCard.BorderSizePixel = 0
	statsCard.LayoutOrder = 1 -- AVANT serverInfoCard (LayoutOrder 0 sera mis à 0 après)
	statsCard.Parent = extraScroll
	createCorner(statsCard, 8)
	createStroke(statsCard, Color3.fromRGB(80, 80, 120), 1)

	local statsPadding = Instance.new("UIPadding")
	statsPadding.PaddingTop = UDim.new(0, 8)
	statsPadding.PaddingBottom = UDim.new(0, 8)
	statsPadding.PaddingLeft = UDim.new(0, 12)
	statsPadding.PaddingRight = UDim.new(0, 12)
	statsPadding.Parent = statsCard

	local statsTitle = Instance.new("TextLabel")
	statsTitle.Size = UDim2.new(1, 0, 0, 16)
	statsTitle.BackgroundTransparency = 1
	statsTitle.Text = "📊 Stats serveur"
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.TextSize = 12
	statsTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
	statsTitle.TextXAlignment = Enum.TextXAlignment.Left
	statsTitle.LayoutOrder = 1
	statsTitle.Parent = statsCard

	-- Container pour la grille de stats (2 lignes × 3 colonnes)
	local statsGrid = Instance.new("Frame")
	statsGrid.Size = UDim2.new(1, 0, 0, 90) -- 2 lignes × 42 + gap 6 = 90
	statsGrid.BackgroundTransparency = 1
	statsGrid.LayoutOrder = 2
	statsGrid.Parent = statsCard

	local statsGridLayout = Instance.new("UIGridLayout")
	statsGridLayout.CellSize = UDim2.new(0, 100, 0, 38)
	statsGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	statsGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsGridLayout.Parent = statsGrid

	-- Helper local pour créer une stat cell dans la grille
	local function addGridStat(parent, name, layoutOrder)
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
		cell.BorderSizePixel = 0
		cell.LayoutOrder = layoutOrder
		cell.Parent = parent
		createCorner(cell, 6)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 0, 12)
		label.Position = UDim2.new(0, 4, 0, 2)
		label.BackgroundTransparency = 1
		label.Text = name
		label.Font = Enum.Font.GothamSemibold
		label.TextSize = 8
		label.TextColor3 = Color3.fromRGB(150, 150, 170)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = cell

		local value = Instance.new("TextLabel")
		value.Size = UDim2.new(1, -8, 0, 18)
		value.Position = UDim2.new(0, 4, 0, 16)
		value.BackgroundTransparency = 1
		value.Text = "..."
		value.Font = Enum.Font.GothamBold
		value.TextSize = 11
		value.TextColor3 = Color3.fromRGB(230, 230, 240)
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.TextTruncate = Enum.TextTruncate.AtEnd
		value.Parent = cell
		return value
	end

	-- Créer les 6 stats dans la grille (LayoutOrder 1-6)
	local statPlayers = addGridStat(statsGrid, "Joueurs", 1)
	local statFPS = addGridStat(statsGrid, "FPS", 2)
	local statPing = addGridStat(statsGrid, "Ping", 3)
	local statTime = addGridStat(statsGrid, "Heure", 4)
	local statJobId = addGridStat(statsGrid, "Job ID", 5)
	local statPlaceId = addGridStat(statsGrid, "Place ID", 6)

	-- FPS counter
	local _fps = 60
	local _lastFrame = tick()
	pcall(function()
		RunService.RenderStepped:Connect(function()
			local now = tick()
			local dt = now - _lastFrame
			_lastFrame = now
			if dt > 0 then _fps = math.clamp(1 / dt, 1, 240) end
		end)
	end)

	-- Update loop pour les 6 stats
	task.spawn(function()
		while task.wait(1) do
			pcall(function()
				statPlayers.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers)
				statFPS.Text = tostring(math.floor(_fps))
				local ping = LocalPlayer:GetNetworkPing() * 1000
				statPing.Text = string.format("%.0f ms", ping)
				statTime.Text = os.date("%H:%M:%S")
				local okJ, jobId = pcall(function() return game.JobId end)
				statJobId.Text = (okJ and jobId and jobId ~= "") and jobId:sub(1, 12) .. "..." or "N/A"
				local okP, placeId = pcall(function() return game.PlaceId end)
				statPlaceId.Text = okP and tostring(placeId) or "N/A"
			end)
		end
	end)
end
_initServerStatsCard()

-- === Carte "Infos serveur" (Créateur du jeu) — déplacée depuis Joueurs (était trop large) ===
-- WRAP dans local function + appel pour isoler les locals (réduit les 200 registres)
local function _initServerInfoCard()
	local serverInfoCard = Instance.new("Frame")
	serverInfoCard.Name = "ServerInfoCard"
	serverInfoCard.Size = UDim2.new(1, -10, 0, 0)
	serverInfoCard.AutomaticSize = Enum.AutomaticSize.Y
	serverInfoCard.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	serverInfoCard.BorderSizePixel = 0
	serverInfoCard.LayoutOrder = 2 -- sous la carte "Stats serveur" (LayoutOrder 1)
	serverInfoCard.Parent = extraScroll
	createCorner(serverInfoCard, 8)
	createStroke(serverInfoCard, Color3.fromRGB(80, 80, 120), 1)

	local serverInfoPadding = Instance.new("UIPadding")
	serverInfoPadding.PaddingTop = UDim.new(0, 8)
	serverInfoPadding.PaddingBottom = UDim.new(0, 8)
	serverInfoPadding.PaddingLeft = UDim.new(0, 12)
	serverInfoPadding.PaddingRight = UDim.new(0, 12)
	serverInfoPadding.Parent = serverInfoCard

	local serverInfoTitle = Instance.new("TextLabel")
	serverInfoTitle.Size = UDim2.new(1, 0, 0, 16)
	serverInfoTitle.BackgroundTransparency = 1
	serverInfoTitle.Text = "🖥️ Infos serveur"
	serverInfoTitle.Font = Enum.Font.GothamBold
	serverInfoTitle.TextSize = 12
	serverInfoTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
	serverInfoTitle.TextXAlignment = Enum.TextXAlignment.Left
	serverInfoTitle.LayoutOrder = 1
	serverInfoTitle.Parent = serverInfoCard

	local serverInfoText = Instance.new("TextLabel")
	serverInfoText.Size = UDim2.new(1, 0, 0, 0)
	serverInfoText.AutomaticSize = Enum.AutomaticSize.Y
	serverInfoText.BackgroundTransparency = 1
	serverInfoText.Text = "Chargement..."
	serverInfoText.Font = Enum.Font.Gotham
	serverInfoText.TextSize = 10
	serverInfoText.TextColor3 = Color3.fromRGB(180, 180, 200)
	serverInfoText.TextXAlignment = Enum.TextXAlignment.Left
	serverInfoText.TextYAlignment = Enum.TextYAlignment.Top
	serverInfoText.TextWrapped = true
	serverInfoText.LayoutOrder = 2
	serverInfoText.Parent = serverInfoCard

	-- UIListLayout pour empiler verticalement les enfants
	local serverInfoLayout = Instance.new("UIListLayout")
	serverInfoLayout.Padding = UDim.new(0, 4)
	serverInfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	serverInfoLayout.Parent = serverInfoCard

	-- Update loop pour la carte "Infos serveur" dans Extra
	task.spawn(function()
		while task.wait(2) do
			pcall(function()
				local lines = {}
				local okCreator, creatorId = pcall(function() return game.CreatorId end)
				if okCreator and creatorId and creatorId ~= 0 then
					table.insert(lines, "  🎮 Créateur du jeu (CreatorId) : " .. tostring(creatorId))
					local okCreatorType, creatorType = pcall(function() return game.CreatorType end)
					if okCreatorType then
						table.insert(lines, "  📌 Type créateur    : " .. tostring(creatorType))
					end
					local okName, gameName = pcall(function() return game.Name end)
					if okName then
						table.insert(lines, "  🎯 Nom du jeu       : " .. tostring(gameName))
					end
					local okVIP, vipOwnerId = pcall(function() return game.VIPServerOwnerId end)
					if okVIP and vipOwnerId and vipOwnerId ~= 0 then
						table.insert(lines, "  👑 Proprio VIP     : " .. tostring(vipOwnerId))
					end
					local okVIPId, vipId = pcall(function() return game.VIPServerId end)
					if okVIPId and vipId and vipId ~= "" then
						table.insert(lines, "  🔑 VIP Server ID    : " .. tostring(vipId):sub(1, 24))
					end
				else
					table.insert(lines, "  🎮 Créateur : Indisponible")
				end
				serverInfoText.Text = table.concat(lines, "\n")
			end)
		end
	end)
end
_initServerInfoCard()

-- ============= AIMBOT =============
-- Verrouille la souris sur la TÊTE du joueur le plus proche du CENTRE de l'écran
-- - Filtre "pas à travers les murs" : raycast camera → head, vérifie qu'on touche le character
-- - Filtre "à l'écran" : WorldToScreenPoint.Z > 0 et X/Y dans les bornes
-- - Pas de visée amis (seulement les joueurs, pas le local player)
-- - Option clic auto : mouse1click à chaque frame sur la cible
-- Wrap dans local function + appel pour isoler les locals (limite 200 registers)
local function _initAimbot()
	local aimbotCard = Instance.new("Frame")
	aimbotCard.Name = "AimbotCard"
	aimbotCard.Size = UDim2.new(1, -10, 0, 0)
	aimbotCard.AutomaticSize = Enum.AutomaticSize.Y
	aimbotCard.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	aimbotCard.BorderSizePixel = 0
	aimbotCard.LayoutOrder = 4 -- après serverInfoCard
	aimbotCard.Parent = extraScroll
	createCorner(aimbotCard, 8)
	createStroke(aimbotCard, Color3.fromRGB(180, 80, 80), 1)

	-- UIListLayout OBLIGATOIRE pour que les enfants se positionnent en colonne
	-- Sans ça, les enfants s'empilent tous à (0,0) et se chevauchent
	local aimbotLayout = Instance.new("UIListLayout")
	aimbotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	aimbotLayout.Padding = UDim.new(0, 4)
	aimbotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	aimbotLayout.Parent = aimbotCard

	local aimbotPad = Instance.new("UIPadding")
	aimbotPad.PaddingTop = UDim.new(0, 8)
	aimbotPad.PaddingBottom = UDim.new(0, 8)
	aimbotPad.PaddingLeft = UDim.new(0, 12)
	aimbotPad.PaddingRight = UDim.new(0, 12)
	aimbotPad.Parent = aimbotCard

	local aimbotTitle = Instance.new("TextLabel")
	aimbotTitle.Size = UDim2.new(1, 0, 0, 16)
	aimbotTitle.BackgroundTransparency = 1
	aimbotTitle.Text = "🎯 Aimbot (verrouille le centre écran sur la cible)"
	aimbotTitle.Font = Enum.Font.GothamBold
	aimbotTitle.TextSize = 12
	aimbotTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
	aimbotTitle.TextXAlignment = Enum.TextXAlignment.Left
	aimbotTitle.LayoutOrder = 1
	aimbotTitle.Parent = aimbotCard

	-- Toggle principal (aim ON/OFF)
	local aimbotEnabled = false
	local aimbotAutoClick = false
	local aimbotMaxDist = 300 -- studs (par défaut)

	-- Status label (en haut, avant les switches)
	local aimStatusLabel = Instance.new("TextLabel")
	aimStatusLabel.Size = UDim2.new(1, 0, 0, 16)
	aimStatusLabel.BackgroundTransparency = 1
	aimStatusLabel.Text = "⏸ Aim inactif"
	aimStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	aimStatusLabel.Font = Enum.Font.Gotham
	aimStatusLabel.TextSize = 10
	aimStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	aimStatusLabel.LayoutOrder = 2
	aimStatusLabel.Parent = aimbotCard

	local mainSwitchRow = Instance.new("Frame")
	mainSwitchRow.Size = UDim2.new(1, 0, 0, 26)
	mainSwitchRow.BackgroundTransparency = 1
	mainSwitchRow.LayoutOrder = 3
	mainSwitchRow.Parent = aimbotCard
	local mainSwitchLabel = Instance.new("TextLabel")
	mainSwitchLabel.Size = UDim2.new(0.7, 0, 1, 0)
	mainSwitchLabel.BackgroundTransparency = 1
	mainSwitchLabel.Text = "Aim ON / OFF"
	mainSwitchLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	mainSwitchLabel.Font = Enum.Font.Gotham
	mainSwitchLabel.TextSize = 11
	mainSwitchLabel.TextXAlignment = Enum.TextXAlignment.Left
	mainSwitchLabel.Parent = mainSwitchRow
	local mainSwitch = createSwitch(mainSwitchRow, "", 1, function(on)
		aimbotEnabled = on
	end)
	mainSwitch.Size = UDim2.new(0.3, -4, 1, 0)
	mainSwitch.Position = UDim2.new(0.7, 4, 0, 0)

	-- Toggle auto-clic
	local clickSwitchRow = Instance.new("Frame")
	clickSwitchRow.Size = UDim2.new(1, 0, 0, 26)
	clickSwitchRow.BackgroundTransparency = 1
	clickSwitchRow.LayoutOrder = 4
	clickSwitchRow.Parent = aimbotCard
	local clickSwitchLabel = Instance.new("TextLabel")
	clickSwitchLabel.Size = UDim2.new(0.7, 0, 1, 0)
	clickSwitchLabel.BackgroundTransparency = 1
	clickSwitchLabel.Text = "🎯 Clic auto sur cible"
	clickSwitchLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	clickSwitchLabel.Font = Enum.Font.Gotham
	clickSwitchLabel.TextSize = 11
	clickSwitchLabel.TextXAlignment = Enum.TextXAlignment.Left
	clickSwitchLabel.Parent = clickSwitchRow
	local clickSwitch = createSwitch(clickSwitchRow, "", 1, function(on)
		aimbotAutoClick = on
	end)
	clickSwitch.Size = UDim2.new(0.3, -4, 1, 0)
	clickSwitch.Position = UDim2.new(0.7, 4, 0, 0)

	-- Slider de distance max (clic gauche = -25, clic droit = +25)
	local distRow = Instance.new("Frame")
	distRow.Size = UDim2.new(1, 0, 0, 26)
	distRow.BackgroundTransparency = 1
	distRow.LayoutOrder = 5
	distRow.Parent = aimbotCard
	local distLabel = Instance.new("TextLabel")
	distLabel.Size = UDim2.new(0.5, 0, 1, 0)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = "📏 Distance max : " .. aimbotMaxDist .. " studs"
	distLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextSize = 11
	distLabel.TextXAlignment = Enum.TextXAlignment.Left
	distLabel.Parent = distRow
	local distSlider = Instance.new("TextButton")
	distSlider.Size = UDim2.new(0.5, -4, 1, 0)
	distSlider.Position = UDim2.new(0.5, 4, 0, 0)
	distSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	distSlider.BorderSizePixel = 0
	distSlider.Text = "—   +"
	distSlider.TextColor3 = Color3.fromRGB(180, 180, 220)
	distSlider.Font = Enum.Font.Gotham
	distSlider.TextSize = 10
	distSlider.Parent = distRow
	createCorner(distSlider, 4)
	distSlider.MouseButton1Click:Connect(function()
		aimbotMaxDist = math.max(50, aimbotMaxDist - 25)
		distLabel.Text = "📏 Distance max : " .. aimbotMaxDist .. " studs"
	end)
	distSlider.MouseButton2Click:Connect(function()
		aimbotMaxDist = math.min(1000, aimbotMaxDist + 25)
		distLabel.Text = "📏 Distance max : " .. aimbotMaxDist .. " studs"
	end)

	-- Label d'aide sous les switches
	local helpLbl = Instance.new("TextLabel")
	helpLbl.Size = UDim2.new(1, 0, 0, 28)
	helpLbl.BackgroundTransparency = 1
	helpLbl.Text = "ℹ️  Active Aim puis vise une cible à l'écran. Clic auto tire quand verrouillé."
	helpLbl.TextColor3 = Color3.fromRGB(150, 150, 170)
	helpLbl.Font = Enum.Font.Gotham
	helpLbl.TextSize = 10
	helpLbl.TextXAlignment = Enum.TextXAlignment.Left
	helpLbl.TextWrapped = true
	helpLbl.LayoutOrder = 6
	helpLbl.Parent = aimbotCard

	-- Indicateur visuel : cercle rouge qui apparaît sur la cible actuelle
	local aimCircle = Instance.new("Frame")
	aimCircle.Size = UDim2.new(0, 60, 0, 60)
	aimCircle.BackgroundTransparency = 1
	aimCircle.BorderSizePixel = 0
	aimCircle.Visible = false
	aimCircle.ZIndex = 999
	aimCircle.Parent = screenGui
	local aimCircleCorner = Instance.new("UICorner")
	aimCircleCorner.CornerRadius = UDim.new(1, 0)
	aimCircleCorner.Parent = aimCircle
	local aimCircleStroke = Instance.new("UIStroke")
	aimCircleStroke.Color = Color3.fromRGB(255, 60, 60)
	aimCircleStroke.Thickness = 3
	aimCircleStroke.Transparency = 0.3
	aimCircleStroke.Parent = aimCircle

	-- Boucle aimbot sur RenderStepped
	local cam = workspace.CurrentCamera
	local localPlayer = Players.LocalPlayer
	local lastClickTick = 0
	local renderConn = RunService.RenderStepped:Connect(function()
		if not aimbotEnabled then
			if aimCircle.Visible then aimCircle.Visible = false end
			return
		end
		if not localPlayer or not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
			return
		end
		local bestTarget = nil
		local bestDistFromCenter = math.huge
		local screenCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
		local myChar = localPlayer.Character
		local myPos = myChar.HumanoidRootPart.Position
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= localPlayer and plr.Character and plr.Character:FindFirstChild("Head") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
				local targetHead = plr.Character.Head
				local targetPos = targetHead.Position
				if (targetPos - myPos).Magnitude <= aimbotMaxDist then
					local screenPos, onScreen = cam:WorldToScreenPoint(targetPos)
					if onScreen and screenPos.Z > 0 then
						local origin = cam.CFrame.Position
						local direction = (targetPos - origin)
						local rayParams = RaycastParams.new()
						rayParams.FilterDescendantsInstances = {myChar, plr.Character}
						rayParams.FilterType = Enum.RaycastFilterType.Exclude
						local result = workspace:Raycast(origin, direction, rayParams)
						if result == nil then
							local dx = screenPos.X - screenCenter.X
							local dy = screenPos.Y - screenCenter.Y
							local distFromCenter = math.sqrt(dx * dx + dy * dy)
							if distFromCenter < bestDistFromCenter then
								bestDistFromCenter = distFromCenter
								bestTarget = {player = plr, head = targetHead, screen = Vector2.new(screenPos.X, screenPos.Y)}
							end
						end
					end
				end
			end
		end
		if bestTarget then
			local dx = bestTarget.screen.X - screenCenter.X
			local dy = bestTarget.screen.Y - screenCenter.Y
			local smoothX = dx * 0.33
			local smoothY = dy * 0.33
			pcall(function() mousemoverel(smoothX, smoothY) end)
			aimCircle.Position = UDim2.new(0, bestTarget.screen.X - 30, 0, bestTarget.screen.Y - 30)
			if not aimCircle.Visible then aimCircle.Visible = true end
			aimStatusLabel.Text = "🎯 Verrouillé : " .. bestTarget.player.DisplayName .. " (dist: " .. math.floor(bestDistFromCenter) .. "px)"
			aimStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			if aimbotAutoClick and tick() - lastClickTick > 0.1 then
				pcall(function() mouse1click() end)
				lastClickTick = tick()
			end
		else
			if aimCircle.Visible then aimCircle.Visible = false end
			aimStatusLabel.Text = "🔍 Aucune cible visible (hors portée ou derrière un mur)"
			aimStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
		end
	end)
end
_initAimbot()

local fullbrightSwitch = createSwitch(extraScroll, "Fullbright", 0, function(on)
	fullbrightState.enabled = on
	if on then
		fullbrightState.old.ambient = Lighting.Ambient
		fullbrightState.old.outdoor = Lighting.OutdoorAmbient
		fullbrightState.old.brightness = Lighting.Brightness
		fullbrightState.old.time = Lighting.ClockTime
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
	else
		Lighting.Ambient = fullbrightState.old.ambient or Lighting.Ambient
		Lighting.OutdoorAmbient = fullbrightState.old.outdoor or Lighting.OutdoorAmbient
		Lighting.Brightness = fullbrightState.old.brightness or Lighting.Brightness
		Lighting.ClockTime = fullbrightState.old.time or Lighting.ClockTime
	end
end)

local clickTPSwitch = createSwitch(extraScroll, "Click TP (Ctrl+clic)", 0, function(on)
	clickTPState.enabled = on
end)

local hitboxSwitch = createSwitch(extraScroll, "Hitbox expander", 0, function(on)
	hitboxState.enabled = on
	if not on then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = plr.Character.HumanoidRootPart
				hrp.Size = Vector3.new(2, 2, 1)
				hrp.Transparency = 1
				hrp.Color = Color3.fromRGB(255, 255, 255)
				hrp.CanCollide = false
			end
		end
	end
end)

createButton(extraScroll, "Obtenir Ghost V4", 0, Color3.fromRGB(110, 60, 160), function()
	giveGhostTool()
end)
createButton(extraScroll, "Obtenir Eleven Master", 0, Color3.fromRGB(60, 120, 160), function()
	giveElevenTool()
end)
createButton(extraScroll, "Obtenir Spider Tool", 0, Color3.fromRGB(60, 160, 90), function()
	giveSpiderTool()
end)

-- Fallback notify global si le panel n'en fournit pas
if type(notify) ~= "function" then
	notify = function(msg, dur)
		warn("[AgoraUniverselleHub] " .. tostring(msg))
	end
end

-- === FEATURES UNIVERSELLES (marchent sur tous les jeux Roblox) ===
local fpsBoostState = { enabled = false, saved = {} }
createSwitch(extraScroll, "FPS Boost (qualité↓)", 0, function(on)
	fpsBoostState.enabled = on
	if on then
		fpsBoostState.saved = {
			quality = UserSettings().GameSettings.SavedQualityLevel,
			meshDetail = Workspace.StreamingMinRadius,
			partCap = Workspace.PartMaterialOptions and 0 or 0,
		}
		pcall(function() UserSettings().GameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		pcall(function() Lighting.GlobalShadows = false end)
		pcall(function() Lighting.FogEnd = 9e9 end)
		pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
	else
		pcall(function() UserSettings().GameSettings.SavedQualityLevel = fpsBoostState.saved.quality or Enum.SavedQualitySetting.Automatic end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
		pcall(function() Lighting.GlobalShadows = true end)
	end
end)

local antiVoidState = { enabled = false }
createSwitch(extraScroll, "Anti-Void (y<-2000)", 0, function(on)
	antiVoidState.enabled = on
end)

-- Rejoin le même serveur (universel)
createButton(extraScroll, "Rejoindre ce serveur", 0, Color3.fromRGB(70, 130, 200), function()
	pcall(function()
		local TeleportService = game:GetService("TeleportService")
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end)

-- Bouton panique : ferme tout d'un coup (Shift+P)
local panicEnabled = false
createSwitch(extraScroll, "Bouton panique (Shift+P)", 0, function(on)
	panicEnabled = on
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	-- Bouton panique : Shift+P = fermeture instantanée et indétectable
	if panicEnabled and input.KeyCode == Enum.KeyCode.P
		and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		pcall(shutdownPanel)
		if screenGui then screenGui:Destroy() end
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and clickTPState.enabled then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			updateCharacter()
			if Mouse.Hit and rootPart then
				rootPart.CFrame = Mouse.Hit + Vector3.new(0, 3, 0)
			end
		end
	end

	-- Go to Walk : click sol = calcul d'itinéraire et marche auto
	if input.UserInputType == Enum.UserInputType.MouseButton1 and gotoWalkState.enabled then
		local now = tick()
		if now - gotoWalkState.lastClick < 0.25 then return end
		gotoWalkState.lastClick = now

		if gotoWalkState.busy then return end
		gotoWalkState.busy = true
		task.spawn(function()
			local ok, err = pcall(function()
				updateCharacter()
				if not Mouse or not Mouse.Hit then return end
				local targetPos = Mouse.Hit.Position + Vector3.new(0, 3, 0)
				gotoWalkState.target = targetPos
				local waypoints = computePathTo(targetPos)
				gotoWalkState.path = waypoints
				gotoWalkState.active = #waypoints > 0
				if #waypoints > 0 and humanoid then
					humanoid:MoveTo(waypoints[1])
					gotoWalkState.lastMoveTo = tick()
				end
				visualizeWaypoints(waypoints)
			end)
			if not ok and err then
				warn("[GoToWalk] " .. tostring(err))
			end
			gotoWalkState.busy = false
		end)
	end
end)

task.spawn(function()
	while task.wait(0.4) do
		if hitboxState.enabled then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
					local hrp = plr.Character.HumanoidRootPart
					if hrp.Size.X ~= 15 then
						hrp.Size = Vector3.new(15, 15, 15)
						hrp.Transparency = 0.7
						hrp.Color = Color3.fromRGB(255, 0, 0)
						hrp.CanCollide = false
					end
				end
			end
		end
	end
end)


-- ============= PROTECTIONS =============
local protectionsState = {
	antiFling = false,
	antiSeat = false,
	antiSeatWatcher = nil,
	antiSeatSitWatcher = nil,
	antiTeleport = false,
	antiFall = false,
	antiKill = false,
	antiAFK = false,
	antiAFKLastAction = tick(),
	antiKillSavedCFrame = nil,
	lastSafeCFrame = nil,
	lastHrpPosition = nil,
}

LocalPlayer.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		if not protectionsState.antiKill then return end
		updateCharacter()
		if rootPart then
			protectionsState.antiKillSavedCFrame = rootPart.CFrame
		end
	end)
	if not protectionsState.antiKill then return end
	local hrp = char:WaitForChild("HumanoidRootPart")
	task.wait(0.2)
	if protectionsState.antiKillSavedCFrame then
		hrp.CFrame = protectionsState.antiKillSavedCFrame
		protectionsState.antiKillSavedCFrame = nil
		-- Resync la baseline anti-TP pour éviter un bounce après le reteleport
		protectionsState.lastSafeCFrame = hrp.CFrame
		protectionsState.lastHrpPosition = hrp.Position
		protectionsState.antiTeleportGraceUntil = tick() + 0.5
	end
end)

local function neutralizeSeat(seat)
	if not seat then return end
	if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
		seat.Disabled = true
		seat.CanTouch = false
		seat:SetAttribute("Neutralized", true)
	end
end

local function restoreSeat(seat)
	if not seat then return end
	if (seat:IsA("Seat") or seat:IsA("VehicleSeat")) and seat:GetAttribute("Neutralized") then
		seat.Disabled = false
		seat.CanTouch = true
		seat:SetAttribute("Neutralized", nil)
	end
end

local function createAntiSeatSitWatcher()
	local function onCharacter(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			hum = char:WaitForChild("Humanoid")
		end
		local con
		con = hum:GetPropertyChangedSignal("Sit"):Connect(function()
			if not protectionsState.antiSeat then
				if con then con:Disconnect() end
				return
			end
			if hum.Sit then hum.Sit = false end
		end)
		char.AncestryChanged:Connect(function()
			if con then con:Disconnect() end
		end)
	end
	if LocalPlayer.Character then
		task.spawn(onCharacter, LocalPlayer.Character)
	end
	return LocalPlayer.CharacterAdded:Connect(onCharacter)
end

local function createProtectionSwitch(name, label, y)
	return createSwitch(protectionsScroll, label, y, function(on)
		protectionsState[name] = on
		if name == "antiSeat" then
			if on then
				if protectionsState.antiSeatWatcher then
					protectionsState.antiSeatWatcher:Disconnect()
					protectionsState.antiSeatWatcher = nil
				end
				if protectionsState.antiSeatSitWatcher then
					protectionsState.antiSeatSitWatcher:Disconnect()
					protectionsState.antiSeatSitWatcher = nil
				end
				for _, obj in ipairs(Workspace:GetDescendants()) do
					neutralizeSeat(obj)
				end
				protectionsState.antiSeatWatcher = Workspace.DescendantAdded:Connect(function(obj)
					if obj:IsA("Seat") or obj:IsA("VehicleSeat") then
						neutralizeSeat(obj)
					end
				end)
				protectionsState.antiSeatSitWatcher = createAntiSeatSitWatcher()
			else
				if protectionsState.antiSeatWatcher then
					protectionsState.antiSeatWatcher:Disconnect()
					protectionsState.antiSeatWatcher = nil
				end
				if protectionsState.antiSeatSitWatcher then
					protectionsState.antiSeatSitWatcher:Disconnect()
					protectionsState.antiSeatSitWatcher = nil
				end
				-- Restaurer TOUS les sièges neutralisés pour qu'on puisse se rassoir
				for _, obj in ipairs(Workspace:GetDescendants()) do
					restoreSeat(obj)
				end
			end
		end
		if name == "antiTeleport" and on then
			updateCharacter()
			if rootPart then
				protectionsState.lastSafeCFrame = rootPart.CFrame
				protectionsState.lastHrpPosition = rootPart.Position
			end
		end
	end)
end

createProtectionSwitch("antiFling", "Anti Fling", 10)
createProtectionSwitch("antiSeat", "Anti Seat", 52)
createProtectionSwitch("antiTeleport", "Anti Teleport", 94)
createProtectionSwitch("antiFall", "Anti Fall", 136)
createProtectionSwitch("antiKill", "Anti Kill / Spawn TP", 178)
createProtectionSwitch("antiAFK", "Anti AFK (5 min)", 220)

RunService.Heartbeat:Connect(function()
	updateCharacter()
	if not rootPart or not humanoid then return end

	local pos = rootPart.Position
	local vel = rootPart.AssemblyLinearVelocity

	if protectionsState.antiFling then
		if math.abs(vel.Y) > 500 then
			rootPart.AssemblyLinearVelocity = Vector3.new(vel.X * 0.1, 0, vel.Z * 0.1)
		end
	end

	if protectionsState.antiSeat then
		if humanoid.Sit then
			humanoid.Sit = false
		end
		local seat = humanoid.SeatPart
		if seat then
			humanoid.Sit = false
		end
	end

	-- Anti-Teleport : ne JAMAIS déclencher pendant le fly/noclip.
	-- On fige le lastSafeCFrame pendant le fly et on donne une grâce de 0.4s après
	-- l'arrêt du fly pour réinitialiser la baseline avant de comparer les deltas.
	local function isAntiTpSuspended()
		return flyState.flying or noclipState.enabled
	end

	if protectionsState.antiTeleport then
		if isAntiTpSuspended() then
			-- Pendant fly/noclip, on met à jour la baseline en continu pour que l'atterrissage ne soit pas vu comme un TP
			protectionsState.lastSafeCFrame = rootPart.CFrame
			protectionsState.lastHrpPosition = pos
		else
			local last = protectionsState.lastHrpPosition
			if last then
				local flatDelta = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z)
				local dist = flatDelta.Magnitude + math.abs(pos.Y - last.Y) * 0.5
				-- Grâce après fly : pendant 0.4s après la sortie de fly, on réinitialise la baseline au lieu de comparer
				local graceUntil = protectionsState.antiTeleportGraceUntil or 0
				if tick() < graceUntil then
					protectionsState.lastSafeCFrame = rootPart.CFrame
					protectionsState.lastHrpPosition = pos
				elseif dist > 250 then
					rootPart.CFrame = protectionsState.lastSafeCFrame or CFrame.new(last + Vector3.new(0, 3, 0))
					rootPart.AssemblyLinearVelocity = Vector3.zero
				elseif vel.Magnitude < 400 then
					protectionsState.lastSafeCFrame = rootPart.CFrame
					protectionsState.lastHrpPosition = pos
				end
			else
				protectionsState.lastSafeCFrame = rootPart.CFrame
				protectionsState.lastHrpPosition = pos
			end
		end
	end

	if protectionsState.antiFall then
		if vel.Y < -100 and pos.Y < -500 then
			rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
			if protectionsState.lastSafeCFrame then
				rootPart.CFrame = protectionsState.lastSafeCFrame
			end
		end
	end

	if antiVoidState.enabled and pos.Y < -2000 and protectionsState.lastSafeCFrame then
		rootPart.CFrame = protectionsState.lastSafeCFrame
		rootPart.AssemblyLinearVelocity = Vector3.zero
	end
end)

task.spawn(function()
	while true do
		task.wait(10)
		if protectionsState.antiAFK then
			local now = tick()
			if now - protectionsState.antiAFKLastAction >= 300 then
				updateCharacter()
				if humanoid then
					humanoid:Move(Vector3.new(0.1, 0, 0), false)
					task.wait(0.15)
					if humanoid then humanoid:Move(Vector3.new(0, 0, 0), false) end
					protectionsState.antiAFKLastAction = now
				end
			end
		end
	end
end)

Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
	if fullbrightState.enabled then
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	end
end)


-- ============= REMOTES (anciennement SERVEUR) =============
-- Cet onglet liste tous les RemoteEvents/RemoteFunctions du jeu et permet de les Fire
-- avec nos propres arguments. ATTENTION : ça touche au serveur.
local serverScroll = Instance.new("ScrollingFrame")
serverScroll.Size = UDim2.new(1, -10, 1, -10)
serverScroll.Position = UDim2.new(0, 5, 0, 5)
serverScroll.BackgroundTransparency = 1
serverScroll.ScrollBarThickness = 4
serverScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
serverScroll.CanvasSize = UDim2.new(0, 0, 0, 2000)
serverScroll.Parent = remotesPage
createCorner(serverScroll, 4)

local serverLayout = Instance.new("UIListLayout")
serverLayout.Padding = UDim.new(0, 6)
serverLayout.SortOrder = Enum.SortOrder.LayoutOrder
serverLayout.Parent = serverScroll

-- Wrap du contenu Remotes dans une fonction locale pour limiter les 200 registers
local function _wrapRemotes()
	-- Avertissement en haut
	local remoteWarn = Instance.new("Frame")
	remoteWarn.Size = UDim2.new(1, -8, 0, 60)
	remoteWarn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	remoteWarn.BorderSizePixel = 0
	remoteWarn.LayoutOrder = -100
	remoteWarn.Parent = serverScroll
	createCorner(remoteWarn, 6)
	createStroke(remoteWarn, Color3.fromRGB(220, 80, 80), 1.5)

	local warnTitle = Instance.new("TextLabel")
	warnTitle.Size = UDim2.new(1, -16, 0, 22)
	warnTitle.Position = UDim2.new(0, 8, 0, 6)
	warnTitle.BackgroundTransparency = 1
	warnTitle.Text = "⚠ ATTENTION — REMOTES DU JEU"
	warnTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
	warnTitle.TextSize = 14
	warnTitle.Font = Enum.Font.GothamBold
	warnTitle.TextXAlignment = Enum.TextXAlignment.Left
	warnTitle.Parent = remoteWarn

	local warnDesc = Instance.new("TextLabel")
	warnDesc.Size = UDim2.new(1, -16, 0, 30)
	warnDesc.Position = UDim2.new(0, 8, 0, 28)
	warnDesc.BackgroundTransparency = 1
	warnDesc.Text = "Tu peux Fire n'importe quel RemoteEvent/Function du jeu avec tes propres arguments. Ça touche directement au serveur — utilise avec précaution."
	warnDesc.TextColor3 = Color3.fromRGB(220, 200, 200)
	warnDesc.TextSize = 11
	warnDesc.Font = Enum.Font.Gotham
	warnDesc.TextWrapped = true
	warnDesc.TextXAlignment = Enum.TextXAlignment.Left
	warnDesc.TextYAlignment = Enum.TextYAlignment.Top
	warnDesc.Parent = remoteWarn

	-- Helpers: scanne tous les remotes du jeu
	local function collectRemotes()
		local remotes = {}
		pcall(function()
			for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
				if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
					table.insert(remotes, obj)
				end
			end
		end)
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
					table.insert(remotes, obj)
				end
			end
		end)
		pcall(function()
			for _, obj in ipairs(game.Players.LocalPlayer:GetDescendants()) do
				if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
					table.insert(remotes, obj)
				end
			end
		end)
		return remotes
	end

	-- Header "Remotes détectés (N)" + bouton refresh
	local remoteHeader = Instance.new("Frame")
	remoteHeader.Size = UDim2.new(1, -8, 0, 32)
	remoteHeader.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	remoteHeader.BorderSizePixel = 0
	remoteHeader.LayoutOrder = -50
	remoteHeader.Parent = serverScroll
	createCorner(remoteHeader, 4)

	local remoteCount = Instance.new("TextLabel")
	remoteCount.Size = UDim2.new(1, -50, 1, 0)
	remoteCount.Position = UDim2.new(0, 8, 0, 0)
	remoteCount.BackgroundTransparency = 1
	remoteCount.Text = "Remotes détectés : 0"
	remoteCount.TextColor3 = Color3.fromRGB(200, 200, 220)
	remoteCount.TextSize = 12
	remoteCount.Font = Enum.Font.GothamBold
	remoteCount.TextXAlignment = Enum.TextXAlignment.Left
	remoteCount.Parent = remoteHeader

	local refreshRemotesBtn = Instance.new("TextButton")
	refreshRemotesBtn.Size = UDim2.new(0, 28, 0, 22)
	refreshRemotesBtn.Position = UDim2.new(1, -36, 0, 5)
	refreshRemotesBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
	refreshRemotesBtn.BorderSizePixel = 0
	refreshRemotesBtn.Text = "↻"
	refreshRemotesBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
	refreshRemotesBtn.TextSize = 16
	refreshRemotesBtn.Font = Enum.Font.GothamBold
	refreshRemotesBtn.Parent = remoteHeader
	createCorner(refreshRemotesBtn, 4)

	-- Barre de recherche pour filtrer les remotes par nom
	local remotesSearchBox = Instance.new("TextBox")
	remotesSearchBox.Size = UDim2.new(1, -8, 0, 28)
	remotesSearchBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	remotesSearchBox.BorderSizePixel = 0
	remotesSearchBox.Text = ""
	remotesSearchBox.PlaceholderText = "🔍 Filtrer les remotes par nom..."
	remotesSearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	remotesSearchBox.Font = Enum.Font.Gotham
	remotesSearchBox.TextSize = 12
	remotesSearchBox.TextColor3 = Color3.fromRGB(230, 230, 230)
	remotesSearchBox.ClearTextOnFocus = false
	remotesSearchBox.LayoutOrder = -40
	remotesSearchBox.Parent = serverScroll
	createCorner(remotesSearchBox, 6)
	createStroke(remotesSearchBox, Color3.fromRGB(60, 60, 80), 1)

	-- Container des cartes de remotes
	local remoteListFrame = Instance.new("Frame")
	remoteListFrame.Size = UDim2.new(1, 0, 0, 0)
	remoteListFrame.BackgroundTransparency = 1
	remoteListFrame.AutomaticSize = Enum.AutomaticSize.Y
	remoteListFrame.LayoutOrder = 0
	remoteListFrame.Parent = serverScroll

	local remoteListLayout = Instance.new("UIListLayout")
	remoteListLayout.Padding = UDim.new(0, 4)
	remoteListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	remoteListLayout.Parent = remoteListFrame

	-- Fonction: crée une carte pour un remote
	local function makeRemoteCard(remote)
	local isFunction = remote:IsA("RemoteFunction")
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	card.BorderSizePixel = 0
	card.LayoutOrder = 1
	card.Parent = remoteListFrame
	createCorner(card, 6)
	createStroke(card, isFunction and Color3.fromRGB(255, 180, 80) or Color3.fromRGB(80, 180, 255), 1)
	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 6)
	cardPadding.PaddingBottom = UDim.new(0, 6)
	cardPadding.PaddingLeft = UDim.new(0, 8)
	cardPadding.PaddingRight = UDim.new(0, 8)
	cardPadding.Parent = card

	-- UIListLayout pour empiler header / row / result proprement
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 6)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	cardLayout.Parent = card

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 0)
	header.AutomaticSize = Enum.AutomaticSize.Y
	header.BackgroundTransparency = 1
	header.Text = (isFunction and "[FN] " or "[EV] ") .. remote:GetFullName()
	header.TextColor3 = isFunction and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(140, 200, 255)
	header.TextSize = 11
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextWrapped = true
	header.LayoutOrder = 1
	header.Parent = card

	-- Row: argsBox + fireBtn côte à côte
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1
	row.LayoutOrder = 2
	row.Parent = card

	local argsBox = Instance.new("TextBox")
	argsBox.Name = "ArgsBox"
	argsBox.Size = UDim2.new(1, -72, 1, 0)
	argsBox.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	argsBox.BorderSizePixel = 0
	argsBox.Text = ""
	argsBox.PlaceholderText = "args (ex: \"hello\", 42, true)"
	argsBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	argsBox.TextColor3 = Color3.fromRGB(220, 220, 240)
	argsBox.TextSize = 11
	argsBox.Font = Enum.Font.Code
	argsBox.TextXAlignment = Enum.TextXAlignment.Left
	argsBox.ClearTextOnFocus = false
	argsBox.Parent = row
	createCorner(argsBox, 4)

	local fireBtn = Instance.new("TextButton")
	fireBtn.Name = "FireBtn"
	fireBtn.Size = UDim2.new(0, 64, 1, 0)
	fireBtn.Position = UDim2.new(1, -64, 0, 0)
	fireBtn.AnchorPoint = Vector2.new(0, 0)
	fireBtn.BackgroundColor3 = isFunction and Color3.fromRGB(180, 100, 30) or Color3.fromRGB(40, 120, 200)
	fireBtn.BorderSizePixel = 0
	fireBtn.Text = isFunction and "Invoke" or "Fire"
	fireBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	fireBtn.TextSize = 12
	fireBtn.Font = Enum.Font.GothamBold
	fireBtn.Parent = row
	createCorner(fireBtn, 4)

	local resultLbl = Instance.new("TextLabel")
	resultLbl.Name = "ResultLbl"
	resultLbl.Size = UDim2.new(1, 0, 0, 0)
	resultLbl.AutomaticSize = Enum.AutomaticSize.Y
	resultLbl.BackgroundTransparency = 1
	resultLbl.Text = ""
	resultLbl.TextColor3 = Color3.fromRGB(180, 220, 180)
	resultLbl.TextSize = 10
	resultLbl.Font = Enum.Font.Code
	resultLbl.TextWrapped = true
	resultLbl.TextXAlignment = Enum.TextXAlignment.Left
	resultLbl.TextYAlignment = Enum.TextYAlignment.Top
	resultLbl.Visible = false
	resultLbl.LayoutOrder = 3
	resultLbl.Parent = card

		-- Parseur d'arguments simples
		local function parseArgs(str)
			if not str or str == "" then return {} end
			local args = {}
			local i = 1
			while i <= #str do
				while i <= #str and str:sub(i, i):match("%s") do i = i + 1 end
				if i > #str then break end
				local c = str:sub(i, i)
				if c == '"' then
					local j = i + 1
					local s = ""
					while j <= #str and str:sub(j, j) ~= '"' do
						s = s .. str:sub(j, j)
						j = j + 1
					end
					table.insert(args, s)
					i = j + 1
				elseif c == "t" and str:sub(i, i+3) == "true" then
					table.insert(args, true)
					i = i + 4
				elseif c == "f" and str:sub(i, i+4) == "false" then
					table.insert(args, false)
					i = i + 5
				elseif c == "n" and str:sub(i, i+2) == "nil" then
					table.insert(args, nil)
					i = i + 3
				elseif c:match("%d") or c == "-" then
					local j = i
					while j <= #str and (str:sub(j, j):match("[%d%.%-eE+]")) do
						j = j + 1
					end
					local numStr = str:sub(i, j - 1)
					local num = tonumber(numStr)
					if num then
						table.insert(args, num)
					else
						table.insert(args, numStr)
					end
					i = j
				else
					local j = i
					while j <= #str and str:sub(j, j) ~= "," do
						j = j + 1
					end
					local tok = str:sub(i, j - 1):match("^%s*(.-)%s*$")
					if tok ~= "" then
						local num = tonumber(tok)
						if num then
							table.insert(args, num)
						else
							table.insert(args, tok)
						end
					end
					i = j
				end
				while i <= #str and str:sub(i, i) == "," do i = i + 1 end
			end
			return args
		end

		fireBtn.MouseButton1Click:Connect(function()
		local args = parseArgs(argsBox.Text)
		resultLbl.Visible = true
		resultLbl.Text = "→ Envoi en cours..."
			resultLbl.TextColor3 = Color3.fromRGB(180, 180, 220)
			local ok, err = pcall(function()
				if isFunction then
					local result = remote:InvokeServer(unpack(args))
					resultLbl.Text = "✓ Réponse : " .. tostring(result)
				else
					remote:FireServer(unpack(args))
					resultLbl.Text = "✓ Fire envoyé (" .. #args .. " args)"
				end
			end)
			if not ok then
				resultLbl.Text = "✗ Erreur : " .. tostring(err)
				resultLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
			else
				resultLbl.TextColor3 = Color3.fromRGB(120, 220, 160)
			end
		end)
	end

	-- Remplit la liste
	local function refreshRemotesList()
		for _, child in ipairs(remoteListFrame:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		local remotes = collectRemotes()
		remoteCount.Text = "Remotes détectés : " .. #remotes
		for _, remote in ipairs(remotes) do
			makeRemoteCard(remote)
		end
	end

	refreshRemotesBtn.MouseButton1Click:Connect(refreshRemotesList)
	task.defer(refreshRemotesList)

	-- Filtre de recherche: affiche/masque les cartes selon le texte
	local function applyRemotesFilter()
		local query = remotesSearchBox.Text:lower()
		for _, child in ipairs(remoteListFrame:GetChildren()) do
			if child:IsA("Frame") then
				if query == "" then
					child.Visible = true
				else
					-- Récupère le nom du remote depuis le header (1er enfant TextLabel)
					local headerLabel = child:FindFirstChildWhichIsA("TextLabel")
					local name = headerLabel and headerLabel.Text or ""
					child.Visible = name:lower():find(query, 1, true) ~= nil
				end
			end
		end
	end
	remotesSearchBox:GetPropertyChangedSignal("Text"):Connect(applyRemotesFilter)
end
_wrapRemotes() -- Exécute le wrap (IIFE pattern pour limiter les 200 registers)

-- ============= REGISTRE DES COMPTES ROBLOX =============
-- Recherche un joueur Roblox hors-jeu par username/displayname, affiche tout : profil, blurb, ban, groupes, jeux.
-- Wrapper function pour isoler les locals du scope global (evite "exceeded 200 local registers" sur les gros panels)
local function buildRegistrySection(parentPage)
	-- Refonte v38.14 : PAS de wrapper registryCard.
	-- Tous les enfants (titre, subtitle, status, resultScroll) sont dans registryScroll DIRECTEMENT.
	-- Chaque enfant a un LayoutOrder pour empiler verticalement via registryLayout (UIListLayout parent).
	-- ResultScroll a une TAILLE FIXE (pas de scroll imbriqué foireux).

local registryTitle = Instance.new("TextLabel")
registryTitle.Name = "RegistryTitle"
registryTitle.Size = UDim2.new(1, -16, 0, 22)
registryTitle.BackgroundTransparency = 1
registryTitle.Text = "📜 Registre des comptes Roblox"
registryTitle.Font = Enum.Font.GothamBold
registryTitle.TextSize = 14
registryTitle.TextColor3 = Color3.fromRGB(230, 230, 255)
registryTitle.TextXAlignment = Enum.TextXAlignment.Left
registryTitle.LayoutOrder = 1
registryTitle.Parent = registryScroll

local registrySubtitle = Instance.new("TextLabel")
registrySubtitle.Name = "RegistrySubtitle"
registrySubtitle.Size = UDim2.new(1, -16, 0, 14)
registrySubtitle.BackgroundTransparency = 1
registrySubtitle.Text = "Recherche un compte Roblox hors-jeu (par username)"
registrySubtitle.Font = Enum.Font.Gotham
registrySubtitle.TextSize = 10
registrySubtitle.TextColor3 = Color3.fromRGB(160, 160, 180)
registrySubtitle.TextXAlignment = Enum.TextXAlignment.Left
registrySubtitle.LayoutOrder = 2
registrySubtitle.Parent = registryScroll

-- Label de statut (GLOBAL pour runRegistrySearch top-level)
statusLbl = Instance.new("TextLabel")
statusLbl.Name = "RegistryStatus"
statusLbl.Size = UDim2.new(1, -16, 0, 16)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "💡 Tape un pseudo ci-dessus et appuie sur Enter"
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 10
statusLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextWrapped = true
statusLbl.LayoutOrder = 3
statusLbl.Parent = registryScroll

-- Scroll pour les résultats de recherche (taille FIXE, pas de scroll imbriqué)
resultScroll = Instance.new("ScrollingFrame")
resultScroll.Name = "RegistryResults"
resultScroll.Size = UDim2.new(1, -10, 1, -70) -- prend tout l'espace restant sous titre+subtitle+status
resultScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
resultScroll.BorderSizePixel = 0
resultScroll.ScrollBarThickness = 6
resultScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
resultScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
resultScroll.LayoutOrder = 4
resultScroll.Parent = registryScroll
createCorner(resultScroll, 6)
createStroke(resultScroll, Color3.fromRGB(60, 60, 80), 1)

local resultLayout = Instance.new("UIListLayout")
resultLayout.Padding = UDim.new(0, 6)
resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultLayout.Parent = resultScroll

-- Helper: join a list into a string with separator, or "Indisponible" if empty
local function joinOrIndi(list, sep, max)
	if not list or type(list) ~= "table" or #list == 0 then
		return "Indisponible"
	end
	local n = math.min(#list, max or #list)
	local parts = {}
	for i = 1, n do
		parts[#parts + 1] = tostring(list[i])
	end
	return table.concat(parts, sep)
end

-- ============= TAGS CUSTOMS + BARRE D'ACTIONS + DEVICE DETECTION =============
-- Tout est wrappé dans une IIFE pour économiser les locals top-level (limite CLI Luau 200)
-- Le code expose : getUserTags, addTagToUser, removeTagFromUser, openTagPopup, detectLocalDevice
local getUserTags, addTagToUser, removeTagFromUser, openTagPopup, detectLocalDevice
do
	local _TAG_STORE = {} -- _TAG_STORE[userId] = { tags = {...}, lastSeen = "..." }
	local _tagPopup = nil

	function getUserTags(userId)
		if not _TAG_STORE[userId] then return {} end
		return _TAG_STORE[userId].tags or {}
	end

	function addTagToUser(userId, tag)
		tag = tag:match("^%s*(.-)%s*$") -- trim
		if tag == "" or #tag > 20 then return false end
		if not _TAG_STORE[userId] then
			_TAG_STORE[userId] = { tags = {}, lastSeen = os.date("%Y-%m-%d") }
		end
		for _, t in ipairs(_TAG_STORE[userId].tags) do
			if t:lower() == tag:lower() then return false end
		end
		table.insert(_TAG_STORE[userId].tags, tag)
		_TAG_STORE[userId].lastSeen = os.date("%Y-%m-%d")
		return true
	end

	function removeTagFromUser(userId, tag)
		if not _TAG_STORE[userId] then return false end
		for i, t in ipairs(_TAG_STORE[userId].tags) do
			if t:lower() == tag:lower() then
				table.remove(_TAG_STORE[userId].tags, i)
				return true
			end
		end
		return false
	end

	local function closeTagPopup()
		if _tagPopup and _tagPopup.Parent then _tagPopup:Destroy() end
		_tagPopup = nil
	end

	function openTagPopup(userId, username, parentRef)
		closeTagPopup()
		local overlay = Instance.new("Frame")
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.4
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 50
		overlay.Parent = parentRef
		overlay.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				closeTagPopup()
			end
		end)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 280, 0, 220)
		card.Position = UDim2.new(0.5, -140, 0.5, -110)
		card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		card.BorderSizePixel = 0
		card.ZIndex = 51
		card.Parent = overlay
		createCorner(card, 10)
		createStroke(card, Color3.fromRGB(120, 80, 255), 2)
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 26)
		title.BackgroundTransparency = 1
		title.Text = "🏷️ Tags — @" .. (username or "?")
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.ZIndex = 52
		title.Parent = card
		local subtitle = Instance.new("TextLabel")
		subtitle.Size = UDim2.new(1, -16, 0, 16)
		subtitle.Position = UDim2.new(0, 8, 0, 26)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = "Tape un tag et appuie sur Ajouter (max 20 car.)"
		subtitle.TextColor3 = Color3.fromRGB(180, 180, 200)
		subtitle.Font = Enum.Font.Gotham
		subtitle.TextSize = 10
		subtitle.TextXAlignment = Enum.TextXAlignment.Left
		subtitle.ZIndex = 52
		subtitle.Parent = card
		local tagInput = Instance.new("TextBox")
		tagInput.Size = UDim2.new(1, -16, 0, 28)
		tagInput.Position = UDim2.new(0, 8, 0, 46)
		tagInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		tagInput.TextColor3 = Color3.fromRGB(255, 255, 255)
		tagInput.PlaceholderText = "ex: VIP, cheater, à surveiller..."
		tagInput.Text = ""
		tagInput.Font = Enum.Font.Gotham
		tagInput.TextSize = 12
		tagInput.ClearTextOnFocus = false
		tagInput.ZIndex = 52
		tagInput.Parent = card
		createCorner(tagInput, 6)
		local listLabel = Instance.new("TextLabel")
		listLabel.Size = UDim2.new(1, -16, 0, 50)
		listLabel.Position = UDim2.new(0, 8, 0, 80)
		listLabel.BackgroundTransparency = 1
		listLabel.Font = Enum.Font.Gotham
		listLabel.TextSize = 11
		listLabel.TextWrapped = true
		listLabel.TextXAlignment = Enum.TextXAlignment.Left
		listLabel.TextYAlignment = Enum.TextYAlignment.Top
		listLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
		listLabel.ZIndex = 52
		listLabel.Parent = card
		local function refreshList()
			local tags = getUserTags(userId)
			if #tags == 0 then
				listLabel.Text = "Aucun tag pour l'instant"
				listLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
			else
				local parts = {}
				for _, t in ipairs(tags) do parts[#parts + 1] = "• " .. t end
				listLabel.Text = table.concat(parts, "\n")
				listLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
			end
		end
		refreshList()
		local addBtn = Instance.new("TextButton")
		addBtn.Size = UDim2.new(0.5, -12, 0, 30)
		addBtn.Position = UDim2.new(0, 8, 0, 140)
		addBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
		addBtn.Text = "➕ Ajouter"
		addBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		addBtn.Font = Enum.Font.GothamBold
		addBtn.TextSize = 12
		addBtn.BorderSizePixel = 0
		addBtn.ZIndex = 52
		addBtn.Parent = card
		createCorner(addBtn, 6)
		addBtn.MouseButton1Click:Connect(function()
			if addTagToUser(userId, tagInput.Text) then tagInput.Text = "" ; refreshList() end
		end)
		local removeBtn = Instance.new("TextButton")
		removeBtn.Size = UDim2.new(0.5, -12, 0, 30)
		removeBtn.Position = UDim2.new(0.5, 4, 0, 140)
		removeBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
		removeBtn.Text = "➖ Retirer dernier"
		removeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		removeBtn.Font = Enum.Font.GothamBold
		removeBtn.TextSize = 11
		removeBtn.BorderSizePixel = 0
		removeBtn.ZIndex = 52
		removeBtn.Parent = card
		createCorner(removeBtn, 6)
		removeBtn.MouseButton1Click:Connect(function()
			local tags = getUserTags(userId)
			if #tags > 0 then removeTagFromUser(userId, tags[#tags]) ; refreshList() end
		end)
		tagInput.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				if addTagToUser(userId, tagInput.Text) then tagInput.Text = "" ; refreshList() end
			end
		end)
		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 30, 0, 30)
		closeBtn.Position = UDim2.new(1, -36, 0, 6)
		closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 14
		closeBtn.BorderSizePixel = 0
		closeBtn.ZIndex = 52
		closeBtn.Parent = card
		createCorner(closeBtn, 15)
		closeBtn.MouseButton1Click:Connect(function() closeTagPopup() end)
		_tagPopup = overlay
	end

	-- === DÉTECTION APPAREIL (seulement pour le local player) ===
	function detectLocalDevice()
		local ok, result = pcall(function()
			local touchOn = UserInputService.TouchEnabled
			local kbOn = UserInputService.KeyboardEnabled
			local mouseOn = UserInputService.MouseEnabled
			local gamepadOn = UserInputService.GamepadEnabled
			local vrOn = UserInputService.VREnabled
			if vrOn then return "🥽 VR (casque)"
			elseif gamepadOn and not kbOn and not mouseOn then return "🎮 Console (manette)"
			elseif touchOn and not kbOn and not mouseOn then return "📱 Mobile (tactile)"
			elseif touchOn and kbOn then return "💻 PC + tactile (tablette/laptop)"
			elseif kbOn and mouseOn then return "💻 PC (clavier+souris)"
			elseif kbOn then return "💻 PC (clavier seul)"
			else return "❓ Inconnu" end
		end)
		if not ok then return nil end
		return result
	end
end
-- ============= FIN TAGS CUSTOMS + BARRE D'ACTIONS + DEVICE DETECTION =============

-- Affiche un résultat (un compte) — UNE seule grosse bulle unie, sans RichText/HTML
-- Apparition ligne par ligne (typewriter) pour faciliter la lecture
local function renderResult(data, parent)
	-- Grosse carte unie
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 0) -- hauteur auto, ajustée après
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	card.BorderSizePixel = 0
	card.Parent = parent
	createCorner(card, 8)
	createStroke(card, Color3.fromRGB(60, 60, 90), 1)

	-- Badges VERIFIED / PREMIUM / BANNED en haut à droite de la carte
	;(function()
		local hasVerified = data.isVerified == true
		local hasPremium = data.isPremium == true
		local isBanned = data.isBanned == true
		if not hasVerified and not hasPremium and not isBanned then return end
		local headerY = 0
		if hasVerified then
			local v = Instance.new("TextLabel")
			v.Size = UDim2.new(0, 70, 0, 18)
			v.Position = UDim2.new(1, -82, 0, 8)
			v.BackgroundColor3 = Color3.fromRGB(50, 130, 220)
			v.BackgroundTransparency = 0.2
			v.BorderSizePixel = 0
			v.Font = Enum.Font.GothamBlack
			v.Text = "✓ VÉRIFIÉ"
			v.TextSize = 9
			v.TextColor3 = Color3.fromRGB(220, 240, 255)
			v.ZIndex = 5
			v.Parent = card
			createCorner(v, 4)
		end
		if hasPremium then
			local p = Instance.new("TextLabel")
			p.Size = UDim2.new(0, 60, 0, 18)
			p.Position = UDim2.new(1, -156, 0, 8)
			p.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
			p.BackgroundTransparency = 0.15
			p.BorderSizePixel = 0
			p.Font = Enum.Font.GothamBlack
			p.Text = "💎 PREMIUM"
			p.TextSize = 9
			p.TextColor3 = Color3.fromRGB(60, 40, 0)
			p.ZIndex = 5
			p.Parent = card
			createCorner(p, 4)
		end
		if isBanned then
			local b = Instance.new("TextLabel")
			b.Size = UDim2.new(0, 50, 0, 18)
			b.Position = UDim2.new(1, -210, 0, 8)
			b.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			b.BackgroundTransparency = 0.15
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamBlack
			b.Text = "🚫 BANNI"
			b.TextSize = 9
			b.TextColor3 = Color3.fromRGB(255, 220, 220)
			b.ZIndex = 5
			b.Parent = card
			createCorner(b, 4)
		end
	end)()

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = card

	-- Layout vertical : header (encadré API bloquée + nom) en haut, puis content (texte + avatar)
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = card

	-- === EN-TÊTE : bandeau d'avertissement si APIs bloquées ===
	local apiBlocked = (data.apiBlocked == true) or (
		not data.created and not data.friendCount and not data.isBanned
		and not data.isPremium and not data.badgeCount and not data.langName
		and not data.groups and not data.games and not data.favGames
	)
	if apiBlocked then
		local warnBar = Instance.new("Frame")
		warnBar.Name = "APIWarning"
		warnBar.Size = UDim2.new(1, 0, 0, 36)
		warnBar.BackgroundColor3 = Color3.fromRGB(80, 40, 20)
		warnBar.BorderSizePixel = 0
		warnBar.LayoutOrder = 0
		warnBar.Parent = card
		createCorner(warnBar, 6)
		createStroke(warnBar, Color3.fromRGB(255, 150, 50), 1.2)
		local wLbl = Instance.new("TextLabel")
		wLbl.Size = UDim2.new(1, -16, 1, 0)
		wLbl.Position = UDim2.new(0, 8, 0, 0)
		wLbl.BackgroundTransparency = 1
		wLbl.Text = "⚠️  APIs Roblox bloquées par l'exécuteur — essaie Synapse X, Wave ou Fluxus pour voir les détails (jeux favoris, badges, groupes, etc.)"
		wLbl.Font = Enum.Font.GothamBold
		wLbl.TextSize = 10
		wLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
		wLbl.TextXAlignment = Enum.TextXAlignment.Left
		wLbl.TextYAlignment = Enum.TextYAlignment.Center
		wLbl.TextWrapped = true
		wLbl.Parent = warnBar
	end

	-- === Contenu : Frame horizontal qui contient le texte à gauche et l'avatar à droite ===
	local contentRow = Instance.new("Frame")
	contentRow.Name = "ContentRow"
	contentRow.Size = UDim2.new(1, 0, 0, 200) -- sera ajusté par AutomaticSize
	contentRow.AutomaticSize = Enum.AutomaticSize.Y
	contentRow.BackgroundTransparency = 1
	contentRow.BorderSizePixel = 0
	contentRow.LayoutOrder = 1
	contentRow.Parent = card
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	contentLayout.Parent = contentRow

	-- === Colonne gauche : TextLabel avec toutes les infos ===
	local big = Instance.new("TextLabel")
	big.Name = "InfoLabel"
	big.Size = UDim2.new(1, -180, 0, 0) -- largeur réduite pour laisser place à l'avatar à droite
	big.AutomaticSize = Enum.AutomaticSize.Y
	big.BackgroundTransparency = 1
	big.Text = ""
	big.Font = Enum.Font.GothamSemibold
	big.TextSize = 11
	big.TextColor3 = Color3.fromRGB(220, 220, 235)
	big.TextXAlignment = Enum.TextXAlignment.Left
	big.TextYAlignment = Enum.TextYAlignment.Top
	big.TextWrapped = true
	big.RichText = false
	big.LayoutOrder = 1
	big.Parent = contentRow

	-- === Colonne droite : ImageLabel avec la photo 2D du joueur (thumbnail) ===
	-- Fallback: InsertService (avatar 3D manequin) est bloqué par certains exécuteurs → on affiche la photo thumbnail
	local avatarHolder = Instance.new("Frame")
	avatarHolder.Name = "AvatarHolder"
	avatarHolder.Size = UDim2.new(0, 160, 0, 200)
	avatarHolder.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	avatarHolder.BorderSizePixel = 0
	avatarHolder.LayoutOrder = 2
	avatarHolder.Parent = contentRow
	createCorner(avatarHolder, 8)
	createStroke(avatarHolder, Color3.fromRGB(120, 80, 255), 1.5)

	-- Label "Chargement..." par-dessus tant que la photo n'est pas prête
	local avatarLoading = Instance.new("TextLabel")
	avatarLoading.Size = UDim2.new(1, 0, 1, 0)
	avatarLoading.BackgroundTransparency = 1
	avatarLoading.Text = "🖼️\nChargement\nphoto..."
	avatarLoading.Font = Enum.Font.GothamSemibold
	avatarLoading.TextSize = 11
	avatarLoading.TextColor3 = Color3.fromRGB(150, 150, 180)
	avatarLoading.TextWrapped = true
	avatarLoading.ZIndex = 5
	avatarLoading.Parent = avatarHolder

	-- ImageLabel (photo 2D du joueur, thumbnail 150x150)
	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Name = "AvatarImg"
	avatarImg.Size = UDim2.new(1, -8, 1, -8)
	avatarImg.Position = UDim2.new(0, 4, 0, 4)
	avatarImg.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	avatarImg.BackgroundTransparency = 1
	avatarImg.BorderSizePixel = 0
	avatarImg.ScaleType = Enum.ScaleType.Fit
	avatarImg.Image = "" -- sera rempli après chargement
	avatarImg.ZIndex = 2
	avatarImg.Parent = avatarHolder
	createCorner(avatarImg, 6)

	-- Construire la liste des lignes (une par champ)
	local friendsText = joinOrIndi(data.friendsList, ", ", 5)
	local groupsText = joinOrIndi(data.groupsList, ", ", 3)
	local gamesText = joinOrIndi(data.games, " | ", 5)
	local favText = joinOrIndi(data.favGames, " | ", 5)
	local outfitText = joinOrIndi(data.outfits, " | ", 3)
	local histText = joinOrIndi(data.usernameHistory, " → ", 4)
	local invText = joinOrIndi(data.inventoryItems, ", ", 8)

	local presenceText = "Indisponible"
	if data.presenceType == 0 then presenceText = "🔘 Hors ligne"
	elseif data.presenceType == 1 then presenceText = "🟢 En ligne"
	elseif data.presenceType == 2 then presenceText = "🎮 En jeu"
	elseif data.presenceType == 3 then presenceText = "🎨 Dans Studio"
	end
	if data.presenceLastOnline and data.presenceLastOnline ~= "" then
		presenceText = presenceText .. "  (dernière: " .. data.presenceLastOnline .. ")"
	end

	-- Couleurs sémantiques via codes ANSI-like → texte brut (couleur uniforme)
	-- (On garde UNE seule couleur — pas de distinction label/valeur, comme demandé)
	local function line(emoji, label, value)
		if value == nil or value == "" or value == "N/A" then
			return "  " .. emoji .. "  " .. label .. " : Indisponible"
		end
		return "  " .. emoji .. "  " .. label .. " : " .. tostring(value)
	end

	local lines = {}
	table.insert(lines, "━━━━━━━━━ " .. (data.username or "?") .. " ━━━━━━━━━")
	table.insert(lines, "  💬 Can chat        : [CHATSTATUS]")
	table.insert(lines, "  🆔 User ID          : " .. (data.userId or "Indisponible"))

	-- Mise à jour async du statut chat (API native Roblox)
	if data.userId then
		_G._resolveCanChat(data.userId, function(result, src)
			local chatText
			if src == "CanTalkWithMe" then
				if result == true then
					chatText = "  💬 Peut me parler    : oui"
				elseif result == false then
					chatText = "  🚫 Peut me parler    : non"
				else
					chatText = "  💬 Peut me parler    : inconnu"
				end
			else
				if result == true then
					chatText = "  📢 Chat activé       : oui (" .. src .. ")"
				elseif result == false then
					chatText = "  🔕 Chat activé       : non (" .. src .. ")"
				else
					chatText = "  💬 Chat                : non vérifiable"
				end
			end
			if big and big.Parent then
				pcall(function()
					big.Text = big.Text:gsub("  💬 Can chat        : %[CHATSTATUS%]", chatText, 1)
				end)
			end
		end)
	end
	table.insert(lines, "  📛 Display Name     : " .. (data.displayName or "Indisponible"))
	table.insert(lines, "  📝 Bio / Blurb      : " .. (data.blurb or "Indisponible"))
	if data.customTags and #data.customTags > 0 then
		table.insert(lines, "  🏷️  TAGS CUSTOMS     : " .. table.concat(data.customTags, " • "))
	else
		table.insert(lines, "  🏷️  TAGS CUSTOMS     : aucun (clique 🏷️ Tag en bas de la carte)")
	end
	-- Appareil (seulement pour le local player — Roblox n'expose pas le device des autres)
	if data.deviceHint then
		table.insert(lines, "  📱 Appareil        : " .. data.deviceHint)
	else
		table.insert(lines, "  📱 Appareil        : Indisponible (visible seulement pour ton propre compte)")
	end
	table.insert(lines, "  📅 Date d'inscription : " .. (data.created or (data.createdEst and ("~" .. data.createdEst .. " (estimé via ID)") or "Indisponible")))
	table.insert(lines, "  🔞 Âge du compte    : " .. (data.accountAge or "Indisponible"))
	if data.idHint then table.insert(lines, "  🆔 Heuristique ID   : " .. data.idHint) end
	table.insert(lines, "  ⭐ Vérifié          : " .. (data.hasVerifiedBadge == true and "OUI" or (data.hasVerifiedBadge == false and "non" or "Indisponible")))
	table.insert(lines, "  💎 Premium          : " .. (data.isPremium == true and "OUI" or (data.isPremium == false and "non" or "Indisponible")))
	if data.premiumUntil then table.insert(lines, "  ⭐ Premium jusqu'au : " .. tostring(data.premiumUntil):sub(1, 10)) end
	table.insert(lines, "  📧 Email lié        : " .. (data.hasEmail == true and "oui" or (data.hasEmail == false and "non" or "Indisponible")))
	table.insert(lines, "  ✓  Email vérifié    : " .. (data.emailVerified == true and "oui" or (data.emailVerified == false and "non" or "Indisponible")))
	table.insert(lines, "  🌐 Langue du compte : " .. (data.locale or "Indisponible"))
	table.insert(lines, "  🚫 Statut compte    : " .. (data.isBanned == true and "🔴 Banni" or (data.isBanned == false and "🟢 Actif" or "Indisponible")))
	table.insert(lines, "  📛 Banni            : " .. (data.banReason or (data.isBanned and "Oui (raison indisponible)" or "Non")))
	table.insert(lines, "  🟢 Présence actuelle : " .. presenceText)
	table.insert(lines, "  🎮 En jeu (placeId) : " .. (data.presencePlaceId or "Indisponible"))
	table.insert(lines, "  ⏰ Dernière connexion : " .. (data.lastOnlineText or "Indisponible"))
	table.insert(lines, "  💱 Trade privacy    : " .. (data.tradePrivacy or "Indisponible"))
	table.insert(lines, "  💱 Trades entrants  : " .. (data.tradesInbound or "Indisponible"))
	table.insert(lines, "  💱 Trades sortants  : " .. (data.tradesOutbound or "Indisponible"))
	table.insert(lines, "  💱 Trades actifs    : " .. (data.tradesActive or "Indisponible"))
	-- === LIVE (serveur actuel) : check via natives Roblox ===
	table.insert(lines, "  ━━━━━━━━━━ LIVE (ce serveur) ━━━━━━━━━━")
	if data.userId and Players then
		local liveFound = false
		pcall(function()
			local target = Players:GetPlayerByUserId(data.userId)
			if target then
				liveFound = true
				local _ageDays = target.AccountAge or 0
				local _ageYears = math.floor(_ageDays / 365)
				local _ageRem = _ageDays - (_ageYears * 365)
				local _mt = tostring(target.MembershipType or "None"):gsub("Enum.MembershipType.", "")
				local _teamName = (target.Team and target.Team.Name) or "Aucune"
				local _ping = "?"
				pcall(function() _ping = tostring(math.floor((target.GetNetworkPing and target:GetNetworkPing() or 0) * 1000)) .. " ms" end)
				local _loaded = (target.HasAppearanceLoaded and "Oui") or "Non"
				local _isFriend = (target.IsFriendsWith and LocalPlayer and target:IsFriendsWith(LocalPlayer.UserId)) and "Oui" or "Non"
				local _charOk = target.Character ~= nil
				local _humOk = _charOk and target.Character:FindFirstChildOfClass("Humanoid") ~= nil
				local _hp = "?"
				local _maxHp = "?"
				pcall(function() if _humOk then local h = target.Character:FindFirstChildOfClass("Humanoid"); _hp = tostring(math.floor(h.Health)); _maxHp = tostring(math.floor(h.MaxHealth)) end end)
				table.insert(lines, "  🔴 Présent ici     : OUI (connecté à ce serveur)")
				table.insert(lines, "  ├─ AccountAge      : " .. _ageYears .. " an(s) " .. _ageRem .. "j (" .. _ageDays .. " jours)")
				table.insert(lines, "  ├─ Membership      : " .. _mt)
				table.insert(lines, "  ├─ Team            : " .. _teamName)
				table.insert(lines, "  ├─ GameId courant  : " .. tostring(game.GameId or "?") .. " / PlaceId " .. tostring(game.PlaceId or "?"))
				table.insert(lines, "  ├─ NetworkPing     : " .. _ping)
				table.insert(lines, "  ├─ Avatar chargé   : " .. _loaded)
				table.insert(lines, "  ├─ Ami avec toi    : " .. _isFriend)
				table.insert(lines, "  └─ HP / MaxHP      : " .. _hp .. " / " .. _maxHp)
				-- Groupes clés (natives Roblox : pas d'HTTP)
				;(function(_t, _ll, _lp)
					local _groups = {
						{1, "Roblox (officiel)"},
						{1200769, "Groupe Officiel"},
						{687101511, "Vzlom_Emk"},
					}
					for _, g in ipairs(_groups) do
						local ok, rank, isIn = pcall(function()
							local r = _t:GetRankInGroup(g[1])
							local b = _t:IsInGroup(g[1])
							return r, b
						end)
						if ok then
							local role = isIn and "Membre (rank " .. tostring(rank) .. ")" or "Non-membre"
							_ll:insert("  └─ " .. g[2] .. " (g" .. g[1] .. ") : " .. role)
						end
					end
					-- Badges Officier / Admin (natives : pas d'HTTP)
					local ok2, has = pcall(function()
						local bs = game:GetService("BadgeService")
						return bs and bs:UserHasBadgeAsync(_t.UserId, 1)
					end)
					if ok2 and has then _ll:insert("  └─ 🛡️ Badge Administrator : OUI") end
					local ok3, hasOfficial = pcall(function()
						local bs = game:GetService("BadgeService")
						return bs and bs:UserHasBadgeAsync(_t.UserId, 2)
					end)
					if ok3 and hasOfficial then _ll:insert("  └─ 🛡️ Badge Official : OUI") end
				end)(target, lines, LocalPlayer)
			end
		end)
		if not liveFound then
			table.insert(lines, "  ⚠ Pas dans ce serveur (vérification impossible)")
		end
	else
		table.insert(lines, "  ⚠ userId manquant")
	end
	table.insert(lines, "  👥 Amis (nb)        : " .. (data.friendCount or "Indisponible"))
	table.insert(lines, "  👥 Top 5 amis       : " .. friendsText)
	table.insert(lines, "  👥 Followers        : " .. (data.followerCount or "Indisponible"))
	table.insert(lines, "  👥 Following        : " .. (data.followingCount or "Indisponible"))
	table.insert(lines, "  🏅 Badges           : " .. (data.badgeCount or "Indisponible"))
	table.insert(lines, "  👕 Hats équipés     : " .. (data.wearingCount or "Indisponible"))
	table.insert(lines, "  👕 Total hats       : " .. (data.avatarHatCount or "Indisponible"))
	table.insert(lines, "  👕 Body colors      : " .. (data.avatarBody or "Indisponible"))
	table.insert(lines, "  📂 Groupes (rôle)   : " .. groupsText)
	table.insert(lines, "  🎮 Jeux créés       : " .. gamesText)
	table.insert(lines, "  ⭐ Jeux favoris     : " .. favText)
	table.insert(lines, "  👗 Tenues sauvegardées : " .. outfitText)
	table.insert(lines, "  🔄 Anciens usernames : " .. histText)
	table.insert(lines, "  🎒 Inventaire (total) : " .. invText)

	-- Animation typewriter: apparition ligne par ligne (toutes les 25ms = ~40 lignes/sec)
	-- Si la recherche est rapide, on peut tout afficher direct, sinon on anime
	task.spawn(function()
		local animDelay = 0.025 -- 25ms par ligne
		for i, l in ipairs(lines) do
			-- Si la carte est détruite avant la fin (nouvelle recherche), on arrête
			if not big or not big.Parent then return end
			local currentText = big.Text
			if currentText == "" then
				big.Text = l
			else
				big.Text = currentText .. "\n" .. l
			end
			-- Resize le card si nécessaire (automaticSize fait le job, mais on force)
			if i % 5 == 0 then
				pcall(function() big.Size = UDim2.new(1, -24, 0, big.TextBounds.Y + 4) end)
			end
			task.wait(animDelay)
		end
		-- Final resize
		pcall(function() big.Size = UDim2.new(1, -180, 0, big.TextBounds.Y + 4) end)
	end)

	-- === Charger la photo thumbnail dans l'ImageLabel ===
	-- Approche : URL Roblox directe (marche même quand Players:GetUserThumbnailAsync bloque)
	-- Format: http://www.roblox.com/Thumbs/Avatar.ashx?x=150&y=150&userId={userId}
	if data.userId then
		local userId = data.userId
		-- URL directe thumbnail Roblox (image PNG, marche via ContentProvider)
		local directUrl = "http://www.roblox.com/Thumbs/Avatar.ashx?x=150&y=150&userId=" .. tostring(userId)
		task.spawn(function()
			pcall(function()
				avatarImg.Image = directUrl
				-- Attendre un peu que l'image charge, puis enlever le label
				task.delay(1.5, function()
					if avatarLoading and avatarLoading.Parent then
						avatarLoading:Destroy()
					end
				end)
			end)
		end)
		-- Fallback optionnel via data.avatarUrl (ThumbnailAsync déjà chargé)
		if data.avatarUrl and data.avatarUrl ~= "" then
			task.delay(0.5, function()
				pcall(function()
					avatarImg.Image = data.avatarUrl
				end)
			end)
		end
	end

	-- ============= BARRE D'ACTIONS EN BAS DE LA CARTE =============
	-- Wrap dans un IIFE pour économiser les locals top-level
	do
		local actionsRow = Instance.new("Frame")
		actionsRow.Size = UDim2.new(1, -16, 0, 30)
		actionsRow.Position = UDim2.new(0, 8, 0, 100) -- position fixe (le big TextLabel est plus haut)
		actionsRow.BackgroundTransparency = 1
		actionsRow.ZIndex = 5
		actionsRow.Parent = card
		local actionsLayout = Instance.new("UIListLayout")
		actionsLayout.FillDirection = Enum.FillDirection.Horizontal
		actionsLayout.Padding = UDim.new(0, 6)
		actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		actionsLayout.Parent = actionsRow
		local function makeActionBtn(text, color, layoutOrder, onClick)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 100, 0, 28)
			btn.BackgroundColor3 = color
			btn.Text = text
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.BorderSizePixel = 0
			btn.LayoutOrder = layoutOrder
			btn.ZIndex = 6
			btn.AutoButtonColor = true
			btn.Parent = actionsRow
			createCorner(btn, 6)
			if onClick then btn.MouseButton1Click:Connect(onClick) end
			return btn
		end
		if data.userId then
			makeActionBtn("🏷️ Tag", Color3.fromRGB(180, 100, 220), 1, function()
				openTagPopup(data.userId, data.username, screenGui)
			end)
			makeActionBtn("📋 ID", Color3.fromRGB(80, 130, 200), 2, function()
				pcall(function() setclipboard(tostring(data.userId)) end)
			end)
			makeActionBtn("🔗 Profil", Color3.fromRGB(80, 180, 120), 3, function()
				pcall(function() setclipboard("https://www.roblox.com/users/" .. tostring(data.userId) .. "/profile") end)
			end)
			-- Rejoindre ce joueur : tente TeleportToPlaceInstance avec son gameId si dispo
			if data.gameId or data.placeId then
				makeActionBtn("🌐 Rejoindre", Color3.fromRGB(70, 130, 200), 4, function()
					pcall(function()
						local TS = game:GetService("TeleportService")
						local pid = data.placeId or data.gameId
						if data.gameInstanceId and data.gameInstanceId ~= "" then
							TS:TeleportToPlaceInstance(pid, data.gameInstanceId, LocalPlayer)
						else
							TS:Teleport(pid, LocalPlayer)
						end
					end)
				end)
			else
				makeActionBtn("🌐 Profil web", Color3.fromRGB(70, 130, 200), 4, function()
					pcall(function() setclipboard("https://www.roblox.com/users/" .. tostring(data.userId) .. "/profile") end)
				end)
			end
		end
	end

	return card
end
function runRegistrySearch(query)
	if not query or query == "" then
		statusLbl.Text = "Tape un username d'abord."
		statusLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
		return
	end
	statusLbl.Text = "Test API Roblox..."
	statusLbl.TextColor3 = Color3.fromRGB(120, 200, 255)

	-- Vider les anciens résultats
	for _, c in ipairs(resultScroll:GetChildren()) do
		if c:IsA("Frame") and c ~= statusLbl then c:Destroy() end
	end

	task.spawn(function()
		-- 1) Résoudre username -> userId via Players:GetUserIdFromNameAsync (NATUREL Roblox, pas d'API externe)
		local userId, displayName, username
		local ok, uid = pcall(function()
			return Players:GetUserIdFromNameAsync(query)
		end)
		if not ok or not uid or uid == 0 then
			-- Pas trouvé : on peut quand même afficher le userId si l'user tape un nombre
			local asNumber = tonumber(query)
			if asNumber and asNumber > 0 then
				userId = asNumber
				username = "UserId:" .. asNumber
				displayName = "?"
			else
				statusLbl.Text = "✗ Username introuvable : @" .. query
				statusLbl.TextColor3 = Color3.fromRGB(220, 100, 100)
				return
			end
		else
			userId = uid
			username = query
			-- Display name : on l'a pas via GetUserIdFromNameAsync, fallback
			displayName = query
		end

		-- Si on a toujours pas de userId, abandonner
		if not userId then
			statusLbl.Text = "Aucun résultat pour \"" .. query .. "\""
			statusLbl.TextColor3 = Color3.fromRGB(220, 100, 100)
			return
		end

		statusLbl.Text = "Trouvé : @" .. username .. " — chargement détails..."
		statusLbl.TextColor3 = Color3.fromRGB(120, 220, 160)

		-- 2) Récupérer détails profil
		local data = {
			userId = userId,
			displayName = displayName,
			username = username
		}
		-- 2) Profil détaillé (helper multi-exécuteur : HttpGet, GetAsync, syn.request)
		pcall(function()
			local r = httpGet("https://users.roblox.com/v1/users/" .. userId)
			if r and r ~= "" then
				local d2 = HttpService:JSONDecode(r)
				if d2 then
									data.created = d2.created
									data.isBanned = d2.isBanned
									data.blurb = d2.description
									data.locale = d2.locale or nil
									data.hasVerifiedBadge = d2.hasVerifiedBadge or false
									-- Noms de langue courants : en_US, fr_FR, es_ES, de_DE, etc.
									if data.locale then
										local langMap = {
											en_US = "Anglais (US)", en_GB = "Anglais (UK)",
											fr_FR = "Français", es_ES = "Espagnol", es_MX = "Espagnol (Mexique)",
											de_DE = "Allemand", it_IT = "Italien", pt_BR = "Portugais (BR)",
											pt_PT = "Portugais (PT)", ru_RU = "Russe", zh_CN = "Chinois (Simplifié)",
											zh_TW = "Chinois (Traditionnel)", ja_JP = "Japonais", ko_KR = "Coréen",
											pl_PL = "Polonais", nl_NL = "Néerlandais", tr_TR = "Turc",
											ar_EG = "Arabe", vi_VN = "Vietnamien", th_TH = "Thaïlandais",
											id_ID = "Indonésien", ms_MY = "Malais", fil_PH = "Filipino",
										}
										data.langName = langMap[data.locale] or data.locale
									end
									if d2.created then
						-- Format ISO 8601: "2021-04-08T15:32:19.847Z" -> parser en epoch
						local y, mo, da = d2.created:match("^(%d+)%-(%d+)%-(%d+)")
						if y and mo and da then
							local epochThen = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(da), hour=0, min=0, sec=0})
							local epochDiff = os.time() - epochThen
							local years = math.floor(epochDiff / 31536000)
							local days = math.floor((epochDiff % 31536000) / 86400)
							local hours = math.floor((epochDiff % 86400) / 3600)
							if years > 0 then
								data.accountAge = years .. " an(s) " .. days .. "j"
							elseif days > 0 then
								data.accountAge = days .. " jour(s) " .. hours .. "h"
							else
								data.accountAge = hours .. " heure(s)"
							end
						end
					end
				end
			end
		end)

		-- 3) Avatar (via Players:GetUserThumbnailAsync, NATIF Roblox, pas besoin de HttpGet)
		pcall(function()
			data.avatarUrl = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)

		-- 4) Friends count
		pcall(function()
			local r = httpGet("https://friends.roblox.com/v1/users/" .. userId .. "/friends/count")
			if r and r ~= "" then
				local d2 = HttpService:JSONDecode(r)
				if d2 and d2.count then data.friendCount = d2.count end
			end
		end)

		-- 5) Groupes
		pcall(function()
			local r = httpGet("https://users.roblox.com/v1/users/" .. userId .. "/groups")
			if r and r ~= "" then
				local d2 = HttpService:JSONDecode(r)
				if d2 and d2.data and #d2.data > 0 then
					data.groups = {}
					for i, g in ipairs(d2.data) do
						if i > 5 then break end
						if g.group and g.group.name then
							table.insert(data.groups, g.group.name)
						end
					end
				end
			end
		end)

		-- 6) Jeux
			pcall(function()
				local r = httpGet("https://games.roblox.com/v2/users/" .. userId .. "/games?sortOrder=Desc&limit=5")
				if r and r ~= "" then
					local d2 = HttpService:JSONDecode(r)
					if d2 and d2.data and #d2.data > 0 then
						data.games = {}
						for i, g in ipairs(d2.data) do
							if i > 5 then break end
							if g.name then table.insert(data.games, g.name) end
						end
					end
				end
			end)

			-- 6b) Jeux favoris
			pcall(function()
				local r = httpGet("https://games.roblox.com/v1/users/" .. userId .. "/favorite/games?sortOrder=Desc&limit=5")
				if r and r ~= "" then
					local d2 = HttpService:JSONDecode(r)
					if d2 and d2.data and #d2.data > 0 then
						data.favGames = {}
						for i, g in ipairs(d2.data) do
							if i > 5 then break end
							if g.name then table.insert(data.favGames, g.name) end
						end
					end
				end
			end)

			-- 6c) Premium (via API Roblox)
			pcall(function()
				local r = httpGet("https://premiumfeatures.roblox.com/v1/users/" .. userId .. "/validate-membership")
				if r and r ~= "" then
					local isPremium = (r == "true")
					data.isPremium = isPremium
				end
			end)

			-- 6d) Badges count
			pcall(function()
				local r = httpGet("https://badges.roblox.com/v1/users/" .. userId .. "/badges?limit=1&sortOrder=Desc")
				if r and r ~= "" then
					local d2 = HttpService:JSONDecode(r)
					if d2 and d2.data then data.badgeCount = #d2.data end
				end
			end)

			-- 6e) Followers / Following count
			pcall(function()
				local r = httpGet("https://friends.roblox.com/v1/users/" .. userId .. "/followings/count")
				if r and r ~= "" then
					local d2 = HttpService:JSONDecode(r)
					if d2 and d2.count then data.followingCount = d2.count end
				end
			end)
			pcall(function()
				local r = httpGet("https://friends.roblox.com/v1/users/" .. userId .. "/followers/count")
				if r and r ~= "" then
					local d2 = HttpService:JSONDecode(r)
					if d2 and d2.count then data.followerCount = d2.count end
				end
			end)

			-- 6f) Présence en temps réel (en ligne / en jeu / au studio)
			pcall(function()
				local body = HttpService:JSONEncode({userIds = {userId}})
				local r = httpGet("https://presence.roblox.com/v1/presence/users?userIds=" .. tostring(userId))
				if r and r ~= "" then
					local d = HttpService:JSONDecode(r)
					if d and d.userPresences and d.userPresences[1] then
						local p = d.userPresences[1]
						data.presenceType = p.userPresenceType
						data.presenceLastLocation = p.lastLocation
						data.presenceLastOnline = p.lastOnline
						data.presencePlaceId = p.placeId
						data.presenceUniverseId = p.universeId
					end
				end
			end)

			-- 6g) Avatar items (ce qu'il porte)
				pcall(function()
					local r = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/avatar")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 then
							data.avatarHatCount = d2.numHats or 0
							data.avatarBody = d2.bodyColors and "Personnalisé" or "Classique"
						end
					end
				end)

				-- 6h) Currently wearing (accessoires actuellement équipés)
				pcall(function()
					local r = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/currently-wearing")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.assetIds then
							data.wearingCount = #d2.assetIds
						end
					end
				end)

				-- 6i) Tenues (outfits)
				pcall(function()
					local r = httpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/outfits?page=1&itemsPerPage=10&isEditable=false")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.data and #d2.data > 0 then
							data.outfits = {}
							for i, o in ipairs(d2.data) do
								if i > 5 then break end
								if o.name then table.insert(data.outfits, o.name) end
							end
						end
					end
				end)

				-- 6j) Historique des usernames (avec dates)
				pcall(function()
					local r = httpGet("https://users.roblox.com/v1/users/" .. userId .. "/username-history?limit=10&sortOrder=Desc")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.data and #d2.data > 0 then
							data.usernameHistory = {}
							for i, h in ipairs(d2.data) do
								if i > 5 then break end
								if h.name then
									local entry = h.name
									if h.created then
										entry = entry .. " (" .. tostring(h.created):sub(1, 10) .. ")"
									end
									table.insert(data.usernameHistory, entry)
								end
							end
						end
					end
				end)

				-- 6k) Groupes avec RÔLE (top 5)
				pcall(function()
					local r = httpGet("https://groups.roblox.com/v2/users/" .. userId .. "/groups/roles?includeLocked=true")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.data and #d2.data > 0 then
							data.groupsWithRole = {}
							for i, g in ipairs(d2.data) do
								if i > 5 then break end
								local entry = {name=g.group.name or "?", role=(g.role and g.role.name) or "Membre"}
								table.insert(data.groupsWithRole, entry)
							end
						end
					end
				end)

				-- 6l) Amis (top 5)
				pcall(function()
					local r = httpGet("https://friends.roblox.com/v1/users/" .. userId .. "/friends?page=1&itemsPerPage=5")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.data and #d2.data > 0 then
							data.friendsList = {}
							for i, f in ipairs(d2.data) do
								if i > 5 then break end
								if f.name then table.insert(data.friendsList, f.name) end
							end
						end
					end
				end)

				-- 6m) Inventaire détaillé (counts par type d'asset)
				pcall(function()
					local assetTypes = {
						"Hat", "HairAccessory", "FaceAccessory", "NeckAccessory",
						"ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
						"Audio", "Badge"
					}
					data.inventory = {}
					for _, atype in ipairs(assetTypes) do
						local ok, r = pcall(function()
							return httpGet("https://inventory.roblox.com/v2/users/" .. userId .. "/inventory/" .. atype .. "?page=1&itemsPerPage=1&sortOrder=Desc")
						end)
						if ok and r and r ~= "" then
							local d2 = HttpService:JSONDecode(r)
							if d2 and d2.totalCount then
								data.inventory[atype] = d2.totalCount
							end
						end
					end
				end)

				-- 6n) Last online timestamp
				pcall(function()
					local r = httpGet("https://presence.roblox.com/v1/presence/last-online?userId=" .. tostring(userId))
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.lastOnline then
							data.lastOnline = d2.lastOnline
							-- Format epoch ISO
							local now = os.time()
							local diff = now - d2.lastOnline
							if diff < 60 then data.lastOnlineText = "À l'instant"
							elseif diff < 3600 then data.lastOnlineText = math.floor(diff/60) .. " min"
							elseif diff < 86400 then data.lastOnlineText = math.floor(diff/3600) .. "h"
							elseif diff < 604800 then data.lastOnlineText = math.floor(diff/86400) .. "j"
							else data.lastOnlineText = math.floor(diff/2592000) .. " mois"
							end
						end
					end
				end)

				-- 6o) Email vérifié / statut 2FA
				pcall(function()
					local r = httpGet("https://accountinformation.roblox.com/v1/users/" .. userId .. "/email")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 then
							data.hasEmail = d2.emailAddress and d2.emailAddress ~= "" or false
							data.emailVerified = d2.verified or false
						end
					end
				end)

				-- 6p) Premium subscription details (date d'expiration)
				pcall(function()
					local r = httpGet("https://billing.roblox.com/v1/users/" .. userId .. "/subscription")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.expirationDate then
							data.premiumUntil = d2.expirationDate
						end
					end
				end)

				-- 6q) Stats de jeux créés (visites, favoris, etc.) via placeIds
				pcall(function()
					if data.games and #data.games > 0 then
						-- data.games est une liste de NOMS. On a besoin des universeIds. Skip pour cette version.
					end
				end)

				-- 6r) Trade activity (counts)
				pcall(function()
					local r = httpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trade-privacy")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 then
							data.tradePrivacy = d2.tradePrivacy
						end
					end
				end)
				pcall(function()
					local r = httpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trades/inbound/count")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.count then data.tradesInbound = d2.count end
					end
				end)
				pcall(function()
					local r = httpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trades/outbound/count")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.count then data.tradesOutbound = d2.count end
					end
				end)
				pcall(function()
					local r = httpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trades/active/count")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.count then data.tradesActive = d2.count end
					end
				end)

		-- 7) Afficher
				-- Compteur d'APIs qui ont répondu (au moins 1 = l'exécuteur autorise HttpGet externe)
				local apiSuccessCount = 0
				if data.created then apiSuccessCount = apiSuccessCount + 1 end
				if data.friendCount or data.followerCount then apiSuccessCount = apiSuccessCount + 1 end
				if data.games or data.favGames then apiSuccessCount = apiSuccessCount + 1 end
				if data.wearingCount or data.outfits then apiSuccessCount = apiSuccessCount + 1 end
				if data.groupsWithRole then apiSuccessCount = apiSuccessCount + 1 end
				if data.friendsList then apiSuccessCount = apiSuccessCount + 1 end
				if data.usernameHistory then apiSuccessCount = apiSuccessCount + 1 end
				if data.lastOnlineText then apiSuccessCount = apiSuccessCount + 1 end
				data.apiOk = apiSuccessCount >= 2
				data.profileUrl = "https://www.roblox.com/users/" .. tostring(userId) .. "/profile"

				if data.apiOk then
					statusLbl.Text = "✅ " .. apiSuccessCount .. " APIs OK pour @" .. username
					statusLbl.TextColor3 = Color3.fromRGB(120, 220, 140)
				else
					statusLbl.Text = "⚠ @" .. username .. " (ID:" .. userId .. ") — APIs externes bloquées par l'exécuteur. Lien : " .. data.profileUrl
					statusLbl.TextColor3 = Color3.fromRGB(255, 180, 90)
				end

				-- === HEURISTIQUES LOCALES (marchent même si HttpGet bloqué) ===
				-- Estimer la date de création du compte à partir de l'UserId
				-- Les IDs Roblox sont séquentiels : ID 1 = 2003, ID 10000000 ≈ 2006, ID 100000000 ≈ 2010,
				-- ID 1000000000 ≈ 2015, ID 10000000000 ≈ 2020, ID 100000000000 ≈ 2024
				if userId and not data.created then
					-- Formule simple : année ≈ 2003 + log10(userId) * 4
					local estYear = 2003 + math.floor(math.log10(math.max(userId, 1)) * 4)
					estYear = math.min(estYear, 2026)
					estYear = math.max(estYear, 2003)
					data.createdEst = estYear
					if data.accountAge == nil then
						data.accountAge = "~" .. (2026 - estYear) .. " an(s) (estimé)"
					end
				end

				-- Détecter si l'ID est très petit (compte ancien) ou très grand (compte récent)
				if userId then
					if userId < 1000000 then
						data.idHint = "🟢 Compte ANCIEN (beta tester probable)"
					elseif userId < 10000000 then
						data.idHint = "🟢 Compte ancien (2010+)"
					elseif userId < 100000000 then
						data.idHint = "🟡 Compte ~2010-2015"
					elseif userId < 1000000000 then
						data.idHint = "🟡 Compte ~2015-2020"
					elseif userId < 10000000000 then
						data.idHint = "🟠 Compte ~2020-2024"
					else
						data.idHint = "🔴 Compte TRÈS RÉCENT (2024+)"
					end
				end

				-- Marquer l'API comme bloquée si toutes les HttpGet ont échoué
				if not data.apiOk then
					data.apiBlocked = true
				end

				-- === DÉTECTION APPAREIL (seulement pour le local player) ===
				-- Roblox n'expose pas le device des autres joueurs au LocalScript
				-- On peut détecter le nôtre via UserInputService
				if userId and Players.LocalPlayer and userId == Players.LocalPlayer.UserId then
					data.deviceHint = detectLocalDevice()
				end

				renderResult(data, resultScroll)

			end)
		end

end
-- Construit la section Registry dans l'onglet Registry (parentPage = registryPage)
-- Tout le contenu (searchBox, searchBtn, registryCard) est reparenté vers registryScroll à la fin
buildRegistrySection(registryPage)

-- Reparent: tous les enfants directs de registryPage (sauf registryScroll) vont dans registryScroll
-- Wrap dans une IIFE anonyme avec ';' pour économiser les registres du chunk
;(function(rp, rs, rl)
	for _, child in ipairs(rp:GetChildren()) do
		if child ~= rs then
			child.Parent = rs
		end
	end
	rs.CanvasSize = UDim2.new(0, 0, 0, rl.AbsoluteContentSize.Y + 10)
	rl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		rs.CanvasSize = UDim2.new(0, 0, 0, rl.AbsoluteContentSize.Y + 10)
	end)
end)(registryPage, registryScroll, registryLayout)
task.defer(function()
	registryScroll.CanvasSize = UDim2.new(0, 0, 0, registryLayout.AbsoluteContentSize.Y + 10)
end)

-- (L'update des stats FPS/ping est maintenant dans la page Joueurs)

function giveGhostTool()
	if LocalPlayer.Backpack:FindFirstChild("Invisible_V4") or (character and character:FindFirstChild("Invisible_V4")) then return end
	for _, v in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
		if v:IsA("ScreenGui") and (v.Name:find("Chronos") or v.Name:find("Ghost")) then v:Destroy() end
	end

	local tool = Instance.new("Tool")
	tool.Name = "Invisible_V4"
	tool.RequiresHandle = false
	tool.Parent = LocalPlayer:WaitForChild("Backpack")

	local isInvisible = false
	local ghostChar = nil
	local ghostConn = nil
	local ghostMouse = LocalPlayer:GetMouse()
	local OFFSET_UNDER = -30

	local function remoteClick()
		local target = ghostMouse.Target
		if target then
			local detector = target:FindFirstChildOfClass("ClickDetector") or (target.Parent and target.Parent:FindFirstChildOfClass("ClickDetector"))
			if detector then pcall(function() fireclickdetector(detector) end) end
		end
	end

	tool.Activated:Connect(function()
		local char = LocalPlayer.Character
		if not char then return end
		if not isInvisible then
			isInvisible = true
			char.Archivable = true
			ghostChar = char:Clone()
			ghostChar.Name = "Ghost_Player"
			ghostChar.Parent = Workspace
			local gh = ghostChar:FindFirstChildOfClass("Humanoid")
			if gh then gh.HipHeight = gh.HipHeight + 0.001 end
			for _, p in ipairs(ghostChar:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = 0.5
					p.CanCollide = true
					if p.Name:find("Foot") or p.Name:find("Leg") then p.CanCollide = false end
				end
			end
			local targetCf = char:GetPivot() * CFrame.new(0, OFFSET_UNDER, 0)
			for _ = 1, 3 do
				char:PivotTo(targetCf)
				RunService.Heartbeat:Wait()
			end
			if char.PrimaryPart then char.PrimaryPart.Anchored = true end
			for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
			Camera.CameraSubject = gh
			ghostConn = RunService.RenderStepped:Connect(function()
				if isInvisible and ghostChar and LocalPlayer.Character then
					local realHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
					local ghostHum = ghostChar:FindFirstChildOfClass("Humanoid")
					if realHum and ghostHum then
						ghostHum:Move(realHum.MoveDirection, false)
						if realHum.Jump then ghostHum.Jump = true end
					end
				end
			end)
		else
			isInvisible = false
			if ghostConn then ghostConn:Disconnect() end
			if ghostChar then
				local lastPos = ghostChar:GetPivot()
				if char.PrimaryPart then
					char.PrimaryPart.Anchored = false
					char.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
					char.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
				end
				for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
				char:PivotTo(lastPos)
				Camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
				ghostChar:Destroy()
				ghostChar = nil
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and isInvisible and input.UserInputType == Enum.UserInputType.MouseButton1 then
			remoteClick()
		end
	end)
end

function giveElevenTool()
	if LocalPlayer.Backpack:FindFirstChild("Eleven_Master_PZ70") or (character and character:FindFirstChild("Eleven_Master_PZ70")) then return end
	local tool = Instance.new("Tool")
	tool.Name = "Eleven_Master_PZ70"
	tool.RequiresHandle = true
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(0.1, 0.1, 0.1)
	h.Transparency = 1
	h.CanCollide = false
	h.Parent = tool
	tool.Parent = LocalPlayer:WaitForChild("Backpack")

	local targetPart = nil
	local bp, bg = nil, nil
	local distance = 25
	local active = false
	local rotationMode = false
	local lockedZoom = 10
	local ghostActive = false
	local ghostChar = nil
	local ghostConn = nil
	local eMouse = LocalPlayer:GetMouse()
	local heldConn = nil

	local function isPlayerPart(part)
		if not part then return false end
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Character == model then return true end
			end
		end
		return false
	end

	local function findTarget()
		local tgt = eMouse.Target
		if tgt and tgt:IsA("BasePart") and not tgt.Anchored and not isPlayerPart(tgt) then
			local model = tgt:FindFirstAncestorOfClass("Model")
			if model then
				local main = model:FindFirstChild("DriveSeat") or model:FindFirstChildOfClass("VehicleSeat") or tgt
				if main and main:IsA("BasePart") and not main.Anchored then return main end
			end
			return tgt
		end
		return nil
	end

	local function cleanupHolding()
		if heldConn then heldConn:Disconnect() heldConn = nil end
		if targetPart then
			targetPart.CanCollide = true
			targetPart.CanTouch = true
			targetPart.CanQuery = true
		end
		if bp then bp:Destroy() bp = nil end
		if bg then bg:Destroy() bg = nil end
		targetPart = nil
		rotationMode = false
		LocalPlayer.CameraMaxZoomDistance = 100
		LocalPlayer.CameraMinZoomDistance = 0.5
	end

	RunService.RenderStepped:Connect(function()
		if active and targetPart and bp then
			if not targetPart.Parent then cleanupHolding() return end
			LocalPlayer.CameraMaxZoomDistance = lockedZoom
			LocalPlayer.CameraMinZoomDistance = lockedZoom
			if not rotationMode then
				local ray = eMouse.UnitRay
				bp.Position = ray.Origin + ray.Direction * distance
				bp.P = 20000
				bp.MaxForce = Vector3.one * math.huge
			end
		elseif active then
			LocalPlayer.CameraMaxZoomDistance = 100
			LocalPlayer.CameraMinZoomDistance = 0.5
		end
	end)

	eMouse.Button1Down:Connect(function()
		if active then
			if targetPart then
				cleanupHolding()
				return
			end
			local tgt = findTarget()
			if tgt then
				targetPart = tgt
				targetPart.Anchored = false
				targetPart.CanCollide = false
				targetPart.CanTouch = false
				local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if r then lockedZoom = (Camera.CFrame.Position - r.Position).Magnitude end
				bp = Instance.new("BodyPosition", targetPart)
				bp.MaxForce = Vector3.one * math.huge
				bp.P = 20000
				bp.D = 1250
				bp.Position = targetPart.Position
				bg = Instance.new("BodyGyro", targetPart)
				bg.MaxTorque = Vector3.one * math.huge
				bg.P = 15000
				bg.D = 800
				bg.CFrame = targetPart.CFrame
				-- anti-ownership steal
				if targetPart:IsA("BasePart") then
					pcall(function() targetPart:SetNetworkOwner(LocalPlayer) end)
				end
				-- reset collisions si le part est détruit/reparenté
				heldConn = targetPart.AncestryChanged:Connect(function(_, newParent)
					if not newParent then cleanupHolding() end
				end)
			end
		end
	end)

	eMouse.Button1Up:Connect(function()
		cleanupHolding()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Nine then
			ghostActive = not ghostActive
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not char or not root then return end
			if ghostActive then
				char.Archivable = true
				ghostChar = char:Clone()
				char.Archivable = false
				for _, v in ipairs(ghostChar:GetDescendants()) do
					if v:IsA("BasePart") or v:IsA("Decal") then v.Transparency = 0.5 end
				end
				ghostChar.Parent = Workspace
				root.Anchored = true
				ghostConn = RunService.RenderStepped:Connect(function()
					if ghostChar and char:FindFirstChildOfClass("Humanoid") then
						local gcHum = ghostChar:FindFirstChildOfClass("Humanoid")
						if gcHum then
							gcHum:Move(char.Humanoid.MoveDirection, false)
							if char.Humanoid.Jump then gcHum.Jump = true end
							Camera.CameraSubject = gcHum
							for _, part in ipairs(ghostChar:GetDescendants()) do
								if part:IsA("BasePart") then part.CanCollide = false end
							end
						end
					end
				end)
			else
				if ghostConn then ghostConn:Disconnect() end
				if ghostChar then
					root.Anchored = false
					root.CFrame = ghostChar:FindFirstChild("HumanoidRootPart") and ghostChar.HumanoidRootPart.CFrame or root.CFrame
					Camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
					ghostChar:Destroy()
					ghostChar = nil
				end
			end
		end
		if targetPart then
			if input.KeyCode == Enum.KeyCode.Plus or input.KeyCode == Enum.KeyCode.KeypadPlus then
				rotationMode = not rotationMode
			elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
				targetPart.Anchored = true
				cleanupHolding()
			end
		end
	end)

	eMouse.WheelForward:Connect(function()
		if active and targetPart then
			if rotationMode and bg then bg.CFrame = bg.CFrame * CFrame.Angles(math.rad(15), 0, 0)
			else distance = math.clamp(distance + 5, 5, 300) end
		end
	end)
	eMouse.WheelBackward:Connect(function()
		if active and targetPart then
			if rotationMode and bg then bg.CFrame = bg.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
			else distance = math.clamp(distance - 5, 5, 300) end
		end
	end)

	tool.Equipped:Connect(function() active = true end)
	tool.Unequipped:Connect(function()
		active = false
		cleanupHolding()
	end)
end
function giveSpiderTool()
	if LocalPlayer.Backpack:FindFirstChild("SpiderTool") or (character and character:FindFirstChild("SpiderTool")) then return end

	local tool = Instance.new("Tool")
	tool.Name = "SpiderTool"
	tool.RequiresHandle = false
	tool.Parent = LocalPlayer:WaitForChild("Backpack")

	local connection = nil
	local jumpConnection = nil
	local isClimbing = false
	local currentHitNormal = Vector3.new(0, 1, 0)
	local smoothedNormal = Vector3.new(0, 1, 0)
	local jumpCooldown = false
	local bodyVelocity, bodyGyro, attachment = nil, nil, nil

	tool.Equipped:Connect(function()
		local char = LocalPlayer.Character
		if not char then return end
		local root = char:WaitForChild("HumanoidRootPart")
		local hum = char:WaitForChild("Humanoid")

		attachment = Instance.new("Attachment")
		attachment.Parent = root

		bodyVelocity = Instance.new("LinearVelocity")
		bodyVelocity.MaxForce = math.huge
		bodyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		bodyVelocity.Enabled = false
		bodyVelocity.Attachment0 = attachment
		bodyVelocity.Parent = root

		bodyGyro = Instance.new("AlignOrientation")
		bodyGyro.Mode = Enum.OrientationAlignmentMode.OneAttachment
		bodyGyro.MaxTorque = math.huge
		bodyGyro.Responsiveness = 200
		bodyGyro.Enabled = false
		bodyGyro.Attachment0 = attachment
		bodyGyro.Parent = root

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {char, tool}
		params.FilterType = Enum.RaycastFilterType.Exclude

		jumpConnection = UserInputService.JumpRequest:Connect(function()
			if isClimbing and not jumpCooldown then
				jumpCooldown = true
				isClimbing = false
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
				if bodyVelocity then bodyVelocity.Enabled = false end
				if bodyGyro then bodyGyro.Enabled = false end
				root.AssemblyLinearVelocity = (currentHitNormal * SETTINGS.SpiderJumpPower) + Vector3.new(0, SETTINGS.SpiderJumpPower * 0.5, 0)
				task.delay(SETTINGS.SpiderJumpCooldown, function() jumpCooldown = false end)
			end
		end)

		connection = RunService.RenderStepped:Connect(function(deltaTime)
			if jumpCooldown then
				hum.AutoRotate = true
				return
			end

			local pos = root.Position
			local look = root.CFrame.LookVector
			local up = root.CFrame.UpVector
			local right = root.CFrame.RightVector

			local rayForward = Workspace:Raycast(pos, look * 4.5, params)
			local rayBackward = Workspace:Raycast(pos, -look * 4.5, params)
			local rayDown = Workspace:Raycast(pos, -up * 8, params)
			local rayOuterFwd = Workspace:Raycast(pos + look * 3.5, (-up * 3 - look * 2).Unit * 12, params)
			local rayOuterBack = Workspace:Raycast(pos - look * 3.5, (-up * 3 + look * 2).Unit * 12, params)
			local rayOuterRight = Workspace:Raycast(pos + right * 3.5, (-up * 3 - right * 2).Unit * 12, params)
			local rayOuterLeft = Workspace:Raycast(pos - right * 3.5, (-up * 3 + right * 2).Unit * 12, params)

			local hitNormal, hitPosition, isAttached = Vector3.new(0, 1, 0), pos, false

			if rayForward then hitNormal, hitPosition, isAttached = rayForward.Normal, rayForward.Position, true
			elseif rayBackward then hitNormal, hitPosition, isAttached = rayBackward.Normal, rayBackward.Position, true
			elseif rayDown then hitNormal, hitPosition, isAttached = rayDown.Normal, rayDown.Position, true
			elseif rayOuterFwd then hitNormal, hitPosition, isAttached = rayOuterFwd.Normal, rayOuterFwd.Position, true
			elseif rayOuterBack then hitNormal, hitPosition, isAttached = rayOuterBack.Normal, rayOuterBack.Position, true
			elseif rayOuterRight then hitNormal, hitPosition, isAttached = rayOuterRight.Normal, rayOuterRight.Position, true
			elseif rayOuterLeft then hitNormal, hitPosition, isAttached = rayOuterLeft.Normal, rayOuterLeft.Position, true
			end

			local onFloor = hitNormal.Y > 0.85
			local wasClimbing = isClimbing
			isClimbing = isAttached and not onFloor
			currentHitNormal = hitNormal

			if isClimbing then
				smoothedNormal = smoothedNormal:Lerp(hitNormal, deltaTime * SETTINGS.SpiderTransitionSpeed)
				hum.AutoRotate = false
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
				if hum:GetState() ~= Enum.HumanoidStateType.RunningNoPhysics then
					hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
				end
				bodyVelocity.Enabled = true
				bodyGyro.Enabled = true

				local flatMove = hum.MoveDirection
				local wallMoveDir = Vector3.zero
				if flatMove.Magnitude > 0.001 then
					local axis = Vector3.new(0, 1, 0):Cross(smoothedNormal)
					local climbDir = flatMove
					if axis.Magnitude > 0.001 then
						local angle = math.acos(math.clamp(Vector3.new(0, 1, 0):Dot(smoothedNormal), -1, 1))
						climbDir = CFrame.fromAxisAngle(axis.Unit, angle) * flatMove
					end
					local walkDir = flatMove - (flatMove:Dot(smoothedNormal) * smoothedNormal)
					if walkDir.Magnitude > 0.001 then walkDir = walkDir.Unit end
					local w = 0
					if smoothedNormal.Y > 0.2 then
						w = math.clamp((smoothedNormal.Y - 0.2) / 0.5, 0, 1)
					elseif smoothedNormal.Y < -0.2 then
						w = math.clamp((math.abs(smoothedNormal.Y) - 0.2) / 0.5, 0, 1)
					end
					wallMoveDir = climbDir:Lerp(walkDir, w)
					if wallMoveDir.Magnitude > 0.001 then wallMoveDir = wallMoveDir.Unit end
				end

				local distFromWall = math.abs((pos - hitPosition):Dot(smoothedNormal))
				local hover = SETTINGS.SpiderHoverDistance
				if wallMoveDir.Magnitude > 0.1 then hover = hover + SETTINGS.SpiderNetworkCompensation end
				local pushForce = (hover - distFromWall) * 15

				bodyVelocity.VectorVelocity = (wallMoveDir * SETTINGS.SpiderSpeed) + (smoothedNormal * pushForce)

				if wallMoveDir.Magnitude > 0.1 then
					bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, wallMoveDir, smoothedNormal)
				else
					local currentLook = root.CFrame.LookVector
					local projectedLook = currentLook - (currentLook:Dot(smoothedNormal) * smoothedNormal)
					if projectedLook.Magnitude > 0.001 then
						bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, projectedLook, smoothedNormal)
					else
						bodyGyro.CFrame = CFrame.lookAt(Vector3.zero, currentLook, smoothedNormal)
					end
				end
			else
				smoothedNormal = Vector3.new(0, 1, 0)
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				if wasClimbing then hum:ChangeState(Enum.HumanoidStateType.Running) end
				hum.AutoRotate = true
				bodyVelocity.Enabled = false
				bodyGyro.Enabled = false
			end
		end)
	end)

	tool.Unequipped:Connect(function()
		if connection then connection:Disconnect() connection = nil end
		if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
		isClimbing = false
		jumpCooldown = false
		smoothedNormal = Vector3.new(0, 1, 0)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum then
			hum.AutoRotate = true
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end
		if bodyVelocity then bodyVelocity:Destroy() end
		if bodyGyro then bodyGyro:Destroy() end
		if attachment then attachment:Destroy() end
		bodyVelocity, bodyGyro, attachment = nil, nil, nil
		if root then
			local look = root.CFrame.LookVector
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(look.X, look.Z), 0)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- ============= CHAT COMMANDS =============
-- Wrap dans IIFE avec paramètres pour éviter la limite d'upvalues (200)
;(function(_fly, _noclip, _esp, _fullbright, _zeroG, _localPlayer)
	_localPlayer.Chatted:Connect(function(msg)
		local m = msg:lower()
		if m == ";fly" then _fly.set(true)
		elseif m == ";unfly" then _fly.set(false)
		elseif m == ";noclip" then _noclip.set(true)
		elseif m == ";unnoclip" then _noclip.set(false)
		elseif m == ";esp" then _esp.enabled = true refreshESP()
		elseif m == ";unesp" then _esp.enabled = false clearESP()
		elseif m == ";fullbright" then _fullbright.set(true)
		elseif m == ";unfullbright" then _fullbright.set(false)
		elseif m == ";zerog" then _zeroG.set(true)
		elseif m == ";unzerog" then _zeroG.set(false)
		end
	end)
end)(flySwitch, noclipSwitch, espState, fullbrightSwitch, zeroGSwitch, LocalPlayer)

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
-- Layer 3: switchTab après reveal
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
