-- Agora Hub [UNIVERSELLE] - Panel Roblox universel
-- LocalScript dans StarterPlayerScripts ou executeur

local SETTINGS = {
	SpiderSpeed = 24,
	SpiderHoverDistance = 3.0,
	SpiderNetworkCompensation = 0.8,
	SpiderJumpPower = 70,
	SpiderJumpCooldown = 0.4,
	SpiderTransitionSpeed = 25
}
_G.SETTINGS = SETTINGS

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

-- Helper multi-fallback pour verifier si un joueur peut chatter (client-only, pas d'acces serveur)
_G._resolveCanChat = function(target, callback)
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
		-- 5) On a VU le joueur parler dans le chat public  il peut nous parler
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
	_G._agoraChar = character
	_G._agoraHum = humanoid
	_G._agoraRoot = rootPart
end

updateCharacter()
LocalPlayer.CharacterAdded:Connect(function(char)
	char:WaitForChild("HumanoidRootPart")
	char:WaitForChild("Humanoid")
	task.wait(0.2)
	updateCharacter()
	-- Utiliser _G car flyState/noclipState/stopFly sont definis plus loin
	local fs = _G["flyState"]
	if fs and fs.flying then
		pcall(function() _G["stopFly"]() end)
	end
	-- NoClip: re-appliquer apres respawn
	local ns = _G._agora_noclipState
	local sw = _G._agora_noclipSwitch
	if ns and ns.enabled and not (humanoid and humanoid.Sit and humanoid.SeatPart) then
		-- Deconnecter l'ancienne boucle
		if ns.loop then
			ns.loop:Disconnect()
			ns.loop = nil
		end
		-- Re-activer le noclip sur le nouveau perso
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") and (p.Name ~= "HumanoidRootPart" or ns.enabled) then
					p.CanCollide = false
				end
			end
		end
		ns.loop = RunService.RenderStepped:Connect(function()
			updateCharacter()
			if not ns.enabled then return end
			if humanoid and humanoid.Sit and humanoid.SeatPart then return end
			if character then
				for _, p in ipairs(character:GetDescendants()) do
					if p:IsA("BasePart") and (p.Name ~= "HumanoidRootPart" or ns.enabled) then
						p.CanCollide = false
					end
				end
			end
		end)
		-- Garder le switch ON
		if sw then sw.set(true) end
	end
	-- ESP
	local es = _G["espState"]
	if es and (es.enabled or _G["globalESPEnabled"]) then
		pcall(function() _G["refreshESP"]() end)
	end
	-- Reload popup apres TP (Rejoindre)
	if _G._agoraAwaitingReload then
		_G._agoraAwaitingReload = false
		task.delay(1.5, function()
			pcall(function()
				local sg = Instance.new("ScreenGui")
				sg.Name = "AgoraReloadPrompt"
				sg.ResetOnSpawn = false
				sg.ZIndex = 99999
				sg.Parent = game:GetService("CoreGui")
				local frame = Instance.new("Frame")
				frame.Size = UDim2.new(0, 320, 0, 140)
				frame.Position = UDim2.new(0.5, -160, 0.5, -70)
				frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
				frame.BorderSizePixel = 0
				frame.Parent = sg
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 10)
				corner.Parent = frame
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(100, 80, 180)
				stroke.Thickness = 2
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				stroke.Parent = frame
				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(1, 0, 0, 40)
				title.BackgroundTransparency = 1
				title.Text = "[Agora] Remettre le script?"
				title.Font = Enum.Font.GothamBold
				title.TextSize = 16
				title.TextColor3 = Color3.fromRGB(255, 255, 255)
				title.Parent = frame
				local yesBtn = Instance.new("TextButton")
				yesBtn.Size = UDim2.new(0, 130, 0, 40)
				yesBtn.Position = UDim2.new(0, 15, 0, 85)
				yesBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
				yesBtn.Text = "Oui"
				yesBtn.Font = Enum.Font.GothamSemibold
				yesBtn.TextSize = 15
				yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				yesBtn.BorderSizePixel = 0
				yesBtn.Parent = frame
				local yCorner = Instance.new("UICorner")
				yCorner.CornerRadius = UDim.new(0, 8)
				yCorner.Parent = yesBtn
				local noBtn = Instance.new("TextButton")
				noBtn.Size = UDim2.new(0, 130, 0, 40)
				noBtn.Position = UDim2.new(1, -145, 0, 85)
				noBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 60)
				noBtn.Text = "Non"
				noBtn.Font = Enum.Font.GothamSemibold
				noBtn.TextSize = 15
				noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				noBtn.BorderSizePixel = 0
				noBtn.Parent = frame
				local nCorner = Instance.new("UICorner")
				nCorner.CornerRadius = UDim.new(0, 8)
				nCorner.Parent = noBtn
				yesBtn.MouseButton1Click:Connect(function()
					sg:Destroy()
					pcall(function() _G.shutdownPanel() end)
					task.wait(0.3)
					pcall(function()
						loadstring(game:HttpGet("https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p1.lua&nocache=" .. tick()))()
					end)
				end)
				noBtn.MouseButton1Click:Connect(function()
					sg:Destroy()
				end)
				task.delay(30, function() if sg and sg.Parent then sg:Destroy() end end)
			end)
		end)
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
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
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

-- Backdrop retire : il recouvrait tout l'ecran en noir semi-transparent.

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
local _dt = getDeviceType()
local _scrW = (game:GetService("GuiService"):GetScreenResolution() or Vector2.new(1280, 720)).X
local _scrH = (game:GetService("GuiService"):GetScreenResolution() or Vector2.new(1280, 720)).Y
local _panelW, _panelH = 460, 520
if _dt == "Mobile" then
	-- Mobile: panel prend quasi toute la largeur/ecran, reste lisible
	_panelW = math.min(460, math.max(300, _scrW - 20))
	_panelH = math.min(520, math.max(400, _scrH - 60))
end
mainFrame.Size = UDim2.new(0, _panelW, 0, _panelH)
mainFrame.Position = UDim2.new(0.5, -_panelW / 2, 0.5, -_panelH / 2)
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
	subtitle.Text = "Agora Hub"
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
			playSound(9042847609, 0.6)
			backdrop.BackgroundTransparency = 0

			-- Etape 2 : titre "Agora Hub" fade in (0.5s) + ding doux
			task.wait(0.3)
			_tween(title, {TextTransparency = 0}, 0.5)
			_tween(subtitle, {TextTransparency = 0}, 0.5)
			playSound(103516326607012, 0.3)

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
			playSound(836142578, 0.9)  -- Cinematic Bass Boom
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
	titleLogo.Image = "rbxassetid://102429262384981"
	titleLogo.Parent = _topBar
	_createCorner(titleLogo, 6)

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
	badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
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

-- (makeIcon removed - closeBtn already has Text="X")

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
		playSound(88442833509532, 0.22)
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
	btn.TextTruncate = Enum.TextTruncate.AtEnd
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

local homePage = createTab("Home")
local playersPage = createTab("Joueurs")
local movePage = createTab("Move")
local moveScroll = Instance.new("ScrollingFrame")
moveScroll.Size = UDim2.new(1, 0, 1, 0)
moveScroll.BackgroundTransparency = 1
moveScroll.BorderSizePixel = 0
moveScroll.ScrollBarThickness = 4
moveScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
moveScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
moveScroll.Parent = movePage
local moveLayout = Instance.new("UIListLayout")
moveLayout.Padding = UDim.new(0, 6)
moveLayout.Parent = moveScroll
local extraPage = createTab("Extra")
local remotesPage = createTab("Remotes")
local registryPage = createTab("Registry")
local localPage = createTab("Local")
local protectionsPage = createTab("Protections")


;(function() -- ============= HOME PAGE =============
	_G.CURRENT_VERSION = "v40.44"
	local CURRENT_VERSION = _G.CURRENT_VERSION
	
	local changelogEntries = {
		"v40.44: Fix detection Server Authority (carte ne reste plus bloquee sur active - sync ON/OFF + source de verite = attribut, plus de faux positifs)",
		"v40.43: Voyant rouge cheat plus lisible (texte ! visible) + badge device deplace (plus de chevauchement) + detection anti-faux-positif respawn",
		"v40.42: TP joueur fonctionne meme tres loin (RequestStreamAroundAsync charge la zone avant de teleporter)",
		"v40.41: Fix badge device (plus de chevauchement avec le bouton Pin) — place entre le nom et Pin",
		"v40.39: Popup MAJ slide-in supprime (plus de popup intrusif) — seulement l'indicateur Home + bouton",
		"v40.38: Fix stats Home (labels forward-declare) — Utilisateurs/En ligne affichent les vrais chiffres Supabase",
		"v40.37: NoClip actif en vol (HRP inclus) — traverser les murs avec le switch NoClip pendant le fly",
		"v40.36: Gravite (Zero Gravite + slider custom + reset) deplacee dans l'onglet Move",
		"v40.34: Fly mobile = joystick natif Roblox (plus de joystick custom) + monte/descend en regardant haut/bas",
		"v40.35: Ghost Tool — vrai perso teleporte 5000 studs sous la map DECALE (x+z, pas pile dessous)",
		"v40.29: Eleven Tool fix (Unequipped ne kill pas le loop + UnitRay nil guard + chat guard Nine + cleanup mort) + UIStroke Contextual partout + TextWrapped labels longs",
		"v40.28: Popup MAJ bas-droite anime slide-in (une fois, plus de spam)",
		"v40.27: Fix Eleven Tool (Backpack Instance.new -> WaitForChild) + meme fix Ghost/Spider",
		"v40.26: Fly ignore WASD pendant le chat + nettoyage complet ancien panel avant update",
		"v40.25: Indicateur MAJ Home deplace en haut (plus visible)",
		"v40.24: Suppression popup auto-update (indicateur Home seulement)",
		"v40.23: Logo panel coins arrondis + onglet Move en scroll (fix boutons superposes click-to-walk/AFK)",
		"v40.21: Fix Activity Log texte invisible (ZIndex 102 + row 48px + border + couleurs plus vives + textes plus grands)",
		"v40.20: Popup MAJ au demarrage + indicateur Home anime si Plus tard + pas de spam popup",
		"v40.19: Auto-update sans popup (indicateur Home seulement) + shutdown complet (BodyMovers+ScreenGui) + fix WalkSpeed slider",
		"v40.16: Notif join seulement amis (pinned) + fix Activity Log texte invisible (row height 42px + TextWrapped + couleurs plus vives)",
		"v40.15: Meilleurs sons (intro cinema + UI click) -- whoosh=Urgent Action stinger, ding=mixkit achievement bell, boom=Cinematic Bass Boom, click=ui-simple-button-click",
		"v40.01: Fly Physics state permanent (zero sursaut) + stop ALL anims + Landed/Climbing disabled + antiInfiniteJump fly guard",
		"v39.99: FIX noclip (p2 stale values + double loop Stepped+RenderStepped + ALL parts) + fly guard CharacterAdded",
		"v39.98: FIX noclip p2 stale char/hum/rootPart",
		"v39.97: Force PlatformStand + WalkSpeed=0 chaque frame fly + re-fix noclip/infiniteJump/antiSpeedHack",
		"v39.96: MEGA FIX 9 sursauts ? noclip fly guard + infiniteJump + Spider + dance + testVel + seated CanCollide",
		"v39.95: Stop walk/run anim en fly + WalkSpeed=0 pendant fly",
		"v39.92: Home scroll changelog + stats fallback indisponible",
		"v39.90: Fix sursauts voiture (noclip/fly seated guards) + HRP exclusion + gradual stopFly + F10 boutons mobile",
					"v39.75: Re-fix compteurs Home + contours remotes + textes + scrolls auto (ecrase par autre commit)",
		"v39.74: Langues scroll fix + SA multi-detection + Force Local + tools server + cheat thresholds",
		"v39.73: Pin joueur (epingler en haut) + notification depart + systeme notif visuel",
		"v39.71: Fly garde pose debout naturel",
		"v39.70: Fix position chute en fly",
		"v39.69: Fix NoClip/fly apres mort (scope _G)",
		"v39.68: NoClip survive respawn",
		"v39.67: Fix NoClip (boucle RenderStepped CanCollide=false)",
		"v39.88: Popup reload seulement sur \"Rejoindre ce serveur\" (pas TP joueur)",
					"v39.87: Popup reload dit \"Remettre le script?\" au lieu de \"panel\"",
					"v39.86: Fix sursauts stopFly (physics gradual) + popup reload apres Rejoindre",
					"v39.85: TP vers joueur a 4m au lieu de 2m (un peu plus loin)",
					"v39.84: Fix sursauts apres fly + Eleven Tool RenderStepped leak + zeroGravity fly guard",
					"v39.83: Protections Heartbeat ignore fly (antiFling/antiFall/antiVoid) + grace 1s",
		"v39.82: Fix sursaut post-fly (zero vel AVANT PlatformStand=false)",
		"v39.81: Fix conflit fly/noclip (exclut HRP + respecte noclip actif)",
		"v39.80: CanCollide=false en fly (fix definitif micro-sauts sol)",
		"v39.79: Fix surelever (PlatformStand once + gyro P reduit) + fix master switch protections",
		"v39.78: Fix drift fly (snap vel zero) + anti-push murs (MaxForce reduit)",
		"v39.77: Fix sursaut atterrissage fly (velocite zero + Landed + delai saut)",
		"v39.76: Fly avec PlatformStand (fix animation course + sursauts hauteur)",
		"v39.66: Fly assis garde position assise + Animate actif",
		"v39.65: Fly garde le siege (vehicule) + fix position chute",
		"v39.64: Fix saut en fly (JumpPower=0, etat Physics force, plus de pose saut)",
		"v39.63: Fly gyro smooth + fix bras leves pres du sol",
		"v39.62: TP joueur = devant lui a 2m, oriente vers lui",
		"v39.61: Fly ultra-fluide (velocity lerp + frame-rate independent)",
		"v39.56: Auto-update preserve features actives (fly/ESP/noclip)",
		"v39.55: Fix boucle popup MAJ + symboles X/-/+ + anti-doublons tools",
		"v39.54: Plate F10 hauteur pieds exacte + tools server-side priorite",
		"v39.51: Emojis ASCII + master switch Protections",
		"v39.43: Enrichissement joueurs (connexion, badges)",
		"v39.42: Fix fly + noclip + ESP + aimbot",
		"v39.41: Angel Fly + notifications + top bar overlay",
		"v39.40: Stats tab + mobile UI fly",
		"v39.39: Fix vehicules + drag autoclick",
		"v39.38: Registry + Remotes + Tags customs",
		"v39.37: Boot safe 3 layers + scroll fix"
	}
	
	-- httpGet multi-fallback
	local function httpGet(url)
		local ok, result = pcall(function() return game:HttpGet(url) end)
		if ok and result then return result end
		ok, result = pcall(function() return HttpService:GetAsync(url) end)
		if ok and result then return result end
		ok, result = pcall(function() return HttpService:RequestAsync({Url = url, Method = "GET"}) end)
		if ok and result and result.Body then return result.Body end
		ok, result = pcall(function() return syn and syn.request({Url = url, Method = "GET"}) end)
		if ok and result and result.Body then return result.Body end
		return nil
	end
	
	-- Translations (14 langues)
	local translations = {

		FR = {Home="Accueil", Joueurs="Joueurs", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registre", Local="Local", Protections="Protections", nouveautes="Nouveautes", discord="Rejoindre le Discord", langue="Langue", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Utilisateurs", enLigne="En ligne"},
		EN = {Home="Home", Joueurs="Players", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", nouveautes="Changelog", discord="Join Discord", langue="Language", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Users", enLigne="Online"},
		ES = {Home="Inicio", Joueurs="Jugadores", Move="Mover", Extra="Extra", Remotes="Remotos", Registry="Registro", Local="Local", Protections="Protecciones", nouveautes="Novedades", discord="Unirse a Discord", langue="Idioma", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Usuarios", enLigne="En linea"},
		DE = {Home="Start", Joueurs="Spieler", Move="Bewegen", Extra="Extra", Remotes="Remotes", Registry="Register", Local="Lokal", Protections="Schutz", nouveautes="Neuigkeiten", discord="Discord beitreten", langue="Sprache", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Benutzer", enLigne="Online"},
		PT = {Home="Inicio", Joueurs="Jogadores", Move="Mover", Extra="Extra", Remotes="Remotos", Registry="Registro", Local="Local", Protections="Protecoes", nouveautes="Novidades", discord="Entrar no Discord", langue="Idioma", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Usuarios", enLigne="Online"},
		IT = {Home="Home", Joueurs="Giocatori", Move="Muovi", Extra="Extra", Remotes="Remoti", Registry="Registro", Local="Locale", Protections="Protezioni", nouveautes="Novita", discord="Unisciti a Discord", langue="Lingua", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Utenti", enLigne="Online"},
		RU = {Home="", Joueurs="", Move="", Extra="", Remotes="", Registry="", Local="", Protections="", nouveautes="", discord="Discord", langue="", credits="Agora Hub [UNIVERSELLE]", utilisateurs="", enLigne=""},
		ZH = {Home="", Joueurs="", Move="", Extra="", Remotes="", Registry="", Local="", Protections="", nouveautes="", discord="Discord", langue="", credits="Agora Hub [UNIVERSELLE]", utilisateurs="", enLigne=""},
		JA = {Home="", Joueurs="", Move="", Extra="", Remotes="", Registry="", Local="", Protections="", nouveautes="", discord="Discord", langue="", credits="Agora Hub [UNIVERSELLE]", utilisateurs="", enLigne=""},
		KO = {Home="", Joueurs="", Move="", Extra="", Remotes="", Registry="", Local="", Protections="", nouveautes="", discord="Discord ", langue="", credits="Agora Hub [UNIVERSELLE]", utilisateurs="", enLigne=""},
		AR = {Home="", Joueurs="", Move="", Extra="", Remotes=" ", Registry="", Local="", Protections="", nouveautes="", discord="  Discord", langue="", credits="Agora Hub [UNIVERSELLE]", utilisateurs="", enLigne=""},
		NL = {Home="Home", Joueurs="Spelers", Move="Bewegen", Extra="Extra", Remotes="Extern", Registry="Register", Local="Lokaal", Protections="Bescherming", nouveautes="Nieuws", discord="Word lid van Discord", langue="Taal", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Gebruikers", enLigne="Online"},
		PL = {Home="Strona gowna", Joueurs="Gracze", Move="Ruch", Extra="Dodatki", Remotes="Zdalne", Registry="Rejestr", Local="Lokalne", Protections="Ochrona", nouveautes="Aktualnosci", discord="Doacz do Discord", langue="Jezyk", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Uzytkownicy", enLigne="Online"},
		TR = {Home="Ana Sayfa", Joueurs="Oyuncular", Move="Hareket", Extra="Ekstra", Remotes="Uzaktan", Registry="Kayt", Local="Yerel", Protections="Koruma", nouveautes="Guncellemeler", discord="Discord'a Katl", langue="Dil", credits="Agora Hub [UNIVERSELLE]", utilisateurs="Kullanclar", enLigne="Cevrimici"}
	}
	
	-- Langue
	local langCode = "FR"
	local function writefile(name, data)
		pcall(function() writefile(name, data) end)
	end
	local function readfile(name)
		local ok, data = pcall(function() return readfile(name) end)
		if ok and data then return data end
		return nil
	end
	local savedLang = readfile("agora_lang.txt")
	if savedLang and translations[savedLang] then langCode = savedLang end
	
	local function applyLanguage(code)
		langCode = code
		writefile("agora_lang.txt", code)
		local t = translations[code] or translations["FR"]
		-- topBar title preserved (Agora Hub)
		pcall(function() if nouveautesLabel then nouveautesLabel.Text = t.nouveautes end end)
		pcall(function() if discordLabel then discordLabel.Text = t.discord end end)
		pcall(function() if langueLabel then langueLabel.Text = t.langue end end)
		pcall(function() if creditsLabel then creditsLabel.Text = t.credits end end)
		pcall(function() if totalLabel then totalLabel.Text = t.utilisateurs .. ": ..." end end)
		pcall(function() if onlineLabel then onlineLabel.Text = t.enLigne .. ": ..." end end)
		pcall(function()
			if tabButtons then
				for name, btn in pairs(tabButtons) do
					if t[name] then btn.Text = t[name] end
				end
			end
		end)
	end
	
	-- Stats live
	local agoraStats = {totalLaunches = 0, onlineUsers = 0}
	-- Forward-declare des labels (definis plus bas) pour que fetchStats puisse les mettre a jour
	local totalLabel, onlineLabel

	local function fetchStats()
		task.spawn(function()
			local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?action=launch&user=" .. (LocalPlayer and LocalPlayer.Name or "Inconnu") .. "&uid=" .. (LocalPlayer and tostring(LocalPlayer.UserId) or "0") .. "&_=" .. math.random(100000,999999)
			local data = httpGet(url)
			if data then
				local ok, json = pcall(function() return HttpService:JSONDecode(data) end)
				if ok and json then
					agoraStats.totalLaunches = json.total_launches or json.totalLaunches or 0
					agoraStats.onlineUsers = json.online_users or json.onlineUsers or 0
					pcall(function() if totalLabel then totalLabel.Text = (translations[langCode] or translations["FR"]).utilisateurs .. ": " .. agoraStats.totalLaunches end end)
					pcall(function() if onlineLabel then onlineLabel.Text = (translations[langCode] or translations["FR"]).enLigne .. ": " .. agoraStats.onlineUsers end end)
				end
			else
				pcall(function() if totalLabel then totalLabel.Text = "Utilisateurs: indisponible" end end)
				pcall(function() if onlineLabel then onlineLabel.Text = "En ligne: indisponible" end end)
			end
		end)
	end
	
	-- === BUILD HOME UI ===
	local homeScroll = Instance.new("ScrollingFrame")
	homeScroll.Name = "HomeScroll"
	homeScroll.Size = UDim2.new(1, -10, 1, -10)
	homeScroll.Position = UDim2.new(0, 5, 0, 5)
	homeScroll.BackgroundTransparency = 1
	homeScroll.BorderSizePixel = 0
	homeScroll.ScrollBarThickness = 4
	homeScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 180, 255)
	homeScroll.CanvasSize = UDim2.new(0, 0, 0, 800)
	homeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	homeScroll.Parent = homePage
	
	local homeLayout = Instance.new("UIListLayout")
	homeLayout.Padding = UDim.new(0, 6)
	homeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	homeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	homeLayout.Parent = homeScroll
	
	local homePad = Instance.new("UIPadding")
	homePad.PaddingTop = UDim.new(0, 4)
	homePad.PaddingBottom = UDim.new(0, 8)
	homePad.PaddingLeft = UDim.new(0, 6)
	homePad.PaddingRight = UDim.new(0, 6)
	homePad.Parent = homeLayout
	
	-- Title card (version + titre ensemble)
	local titleCard = Instance.new("Frame")
	titleCard.Size = UDim2.new(1, -8, 0, 70)
	titleCard.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
	titleCard.BorderSizePixel = 0
	titleCard.LayoutOrder = 1
	titleCard.Parent = homeScroll
	createCorner(titleCard, 10)
	createStroke(titleCard, Color3.fromRGB(60, 180, 255), 1)
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -16, 0, 32)
	titleLabel.Position = UDim2.new(0, 8, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Agora Hub"
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.fromRGB(60, 180, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleCard
	
	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(1, -16, 0, 22)
	versionLabel.Position = UDim2.new(0, 8, 0, 40)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = CURRENT_VERSION
	versionLabel.Font = Enum.Font.GothamBold
	versionLabel.TextSize = 15
	versionLabel.TextColor3 = Color3.fromRGB(120, 200, 100)
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Parent = titleCard
	
	-- Changelog card
	local changelogCard = Instance.new("Frame")
	changelogCard.Size = UDim2.new(1, -8, 0, 0)
	changelogCard.Size = UDim2.new(1, -8, 0, 170)
	changelogCard.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	changelogCard.BorderSizePixel = 0
	changelogCard.LayoutOrder = 2
	changelogCard.Parent = homeScroll
	createCorner(changelogCard, 10)
	createStroke(changelogCard, Color3.fromRGB(50, 50, 70), 1)
	
	-- Titre "Nouveautes" (fixe, hors du scroll)
	local nouveautesLabel = Instance.new("TextLabel")
	nouveautesLabel.Size = UDim2.new(1, -16, 0, 24)
	nouveautesLabel.BackgroundTransparency = 1
	nouveautesLabel.Text = "Nouveautes"
	nouveautesLabel.Font = Enum.Font.GothamBold
	nouveautesLabel.TextSize = 16
	nouveautesLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	nouveautesLabel.TextXAlignment = Enum.TextXAlignment.Left
	nouveautesLabel.LayoutOrder = 0
	nouveautesLabel.Parent = changelogCard

	-- Scroll INTERNE pour le changelog (pas toute la page Home)
	local chgScroll = Instance.new("ScrollingFrame")
	chgScroll.Size = UDim2.new(1, -10, 0, 130)
	chgScroll.Position = UDim2.new(0, 5, 0, 30)
	chgScroll.BackgroundTransparency = 1
	chgScroll.BorderSizePixel = 0
	chgScroll.ScrollBarThickness = 3
	chgScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 120)
	chgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	chgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chgScroll.LayoutOrder = 1
	chgScroll.Parent = changelogCard

	local chgLayout = Instance.new("UIListLayout")
	chgLayout.Padding = UDim.new(0, 2)
	chgLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chgLayout.Parent = chgScroll

	-- Highlight les 3 dernieres versions en vert
	for idx, entry in ipairs(changelogEntries) do
		local entryLabel = Instance.new("TextLabel")
		entryLabel.Size = UDim2.new(1, 0, 0, 18)
		entryLabel.BackgroundTransparency = 1
		entryLabel.Text = entry
		entryLabel.Font = Enum.Font.Gotham
		entryLabel.TextSize = 12
		if idx <= 3 then
			entryLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
			entryLabel.Font = Enum.Font.GothamSemibold
		else
			entryLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
		end
		entryLabel.TextXAlignment = Enum.TextXAlignment.Left
		entryLabel.TextWrapped = true
		entryLabel.LayoutOrder = idx
		entryLabel.Parent = chgScroll
	end

		-- Stats card (utilisateurs + en ligne)
	local statsCard = Instance.new("Frame")
	statsCard.Size = UDim2.new(1, -8, 0, 50)
	statsCard.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	statsCard.BorderSizePixel = 0
	statsCard.LayoutOrder = 3
	statsCard.Parent = homeScroll
	createCorner(statsCard, 10)
	createStroke(statsCard, Color3.fromRGB(50, 50, 70), 1)
	
	totalLabel = Instance.new("TextLabel")
	totalLabel.Size = UDim2.new(1, -16, 0, 20)
	totalLabel.Position = UDim2.new(0, 8, 0, 6)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Text = "Utilisateurs: ..."
	totalLabel.Font = Enum.Font.GothamSemibold
	totalLabel.TextSize = 14
	totalLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.Parent = statsCard
	
	onlineLabel = Instance.new("TextLabel")
	onlineLabel.Size = UDim2.new(1, -16, 0, 20)
	onlineLabel.Position = UDim2.new(0, 8, 0, 28)
	onlineLabel.BackgroundTransparency = 1
	onlineLabel.Text = "En ligne: ..."
	onlineLabel.Font = Enum.Font.GothamSemibold
	onlineLabel.TextSize = 14
	onlineLabel.TextColor3 = Color3.fromRGB(120, 220, 140)
	onlineLabel.TextXAlignment = Enum.TextXAlignment.Left
	onlineLabel.Parent = statsCard
	
	-- Discord button
	local discordBtn = Instance.new("TextButton")
	discordBtn.Size = UDim2.new(1, -8, 0, 40)
	discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	discordBtn.BorderSizePixel = 0
	discordBtn.Text = "[Discord] Rejoindre le serveur"
	discordBtn.Font = Enum.Font.GothamBold
	discordBtn.TextSize = 15
	discordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	discordBtn.LayoutOrder = 4
	discordBtn.Parent = homeScroll
	createCorner(discordBtn, 8)
	discordBtn.MouseButton1Click:Connect(function()
		pcall(function() setclipboard("https://discord.gg/fVw2rzAMb") end)
		discordBtn.Text = "[OK] Lien copie !"
		task.delay(2, function() discordBtn.Text = "[Discord] Rejoindre le serveur" end)
	end)
	
	local discordLabel = discordBtn
	
	-- Language selector
	local langueLabel = Instance.new("TextLabel")
	langueLabel.Size = UDim2.new(1, -8, 0, 20)
	langueLabel.BackgroundTransparency = 1
	langueLabel.Text = "Langue"
	langueLabel.Font = Enum.Font.GothamBold
	langueLabel.TextSize = 14
	langueLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	langueLabel.TextXAlignment = Enum.TextXAlignment.Left
	langueLabel.LayoutOrder = 5
	langueLabel.Parent = homeScroll
	
	local langBtn = Instance.new("TextButton")
	langBtn.Size = UDim2.new(1, -8, 0, 36)
	langBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	langBtn.BorderSizePixel = 0
	langBtn.Text = "FR Francais"
	langBtn.Font = Enum.Font.Gotham
	langBtn.TextSize = 14
	langBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
	langBtn.LayoutOrder = 6
	langBtn.Parent = homeScroll
	createCorner(langBtn, 8)
	
	local langPopup = nil
	local langList = {
		{code="FR", flag="", name="Francais"},
		{code="EN", flag="", name="English"},
		{code="ES", flag="", name="Espanol"},
		{code="DE", flag="", name="Deutsch"},
		{code="PT", flag="", name="Portugues"},
		{code="IT", flag="", name="Italiano"},
		{code="RU", flag="", name="Russky"},
		{code="ZH", flag="", name="Zhongwen"},
		{code="JA", flag="", name="Nihongo"},
		{code="KO", flag="", name="Hangugeo"},
		{code="AR", flag="", name="Arabiyya"},
		{code="NL", flag="", name="Nederlands"},
		{code="PL", flag="", name="Polski"},
		{code="TR", flag="", name="Turkce"}
	}
	
	langBtn.MouseButton1Click:Connect(function()
		if langPopup then langPopup:Destroy() langPopup = nil return end
	
	-- Indicateur de mise a jour (visible seulement si MAJ disponible)
	local updInd = Instance.new("TextLabel")
	updInd.Size = UDim2.new(1, -8, 0, 24)
	updInd.BackgroundColor3 = Color3.fromRGB(30, 60, 100)
	updInd.BackgroundTransparency = 0.8
	updInd.Text = ""
	updInd.Font = Enum.Font.GothamBold
	updInd.TextSize = 11
	updInd.TextColor3 = Color3.fromRGB(100, 200, 255)
	updInd.TextXAlignment = Enum.TextXAlignment.Left
	updInd.Visible = false
	updInd.LayoutOrder = 0
	updInd.Parent = homeScroll
	createCorner(updInd, 6)
	_G._agoraUpdateIndicator = updInd

	local updBtn = Instance.new("TextButton")
	updBtn.Size = UDim2.new(1, -8, 0, 32)
	updBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
	updBtn.Text = "Mettre a jour maintenant"
	updBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	updBtn.Font = Enum.Font.GothamBold
	updBtn.TextSize = 12
	updBtn.Visible = false
	updBtn.LayoutOrder = 1
	updBtn.Parent = homeScroll
	createCorner(updBtn, 6)
	updBtn.MouseButton1Click:Connect(function()
		pcall(function() if _G._agoraPerformUpdate then _G._agoraPerformUpdate() end end)
	end)
	_G._agoraUpdateBtn = updBtn
		langPopup = Instance.new("Frame")
		langPopup.Size = UDim2.new(1, -20, 0, 280)
		langPopup.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		langPopup.BorderSizePixel = 0
		langPopup.LayoutOrder = 7
		langPopup.Parent = homeScroll
		createCorner(langPopup, 8)
		createStroke(langPopup, Color3.fromRGB(60, 180, 255), 1)
	
		local popupLayout = Instance.new("UIListLayout")
		popupLayout.Padding = UDim.new(0, 2)
		popupLayout.Parent = langPopup
	
		for _, lang in ipairs(langList) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -10, 0, 28)
			btn.Position = UDim2.new(0, 5, 0, 0)
			btn.BackgroundColor3 = lang.code == langCode and Color3.fromRGB(60, 180, 255) or Color3.fromRGB(40, 40, 55)
			btn.BorderSizePixel = 0
			btn.Text = lang.flag .. " " .. lang.name
			btn.Font = Enum.Font.Gotham
			btn.TextSize = 12
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Parent = langPopup
			createCorner(btn, 6)
			btn.MouseButton1Click:Connect(function()
				applyLanguage(lang.code)
				langBtn.Text = lang.flag .. " " .. lang.name
				langPopup:Destroy()
				langPopup = nil
			end)
		end
	end)
	
	-- Credits
	local creditsLabel = Instance.new("TextLabel")
	creditsLabel.Size = UDim2.new(1, -8, 0, 18)
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Text = "Agora Hub [UNIVERSELLE]"
	creditsLabel.Font = Enum.Font.Gotham
	creditsLabel.TextSize = 11
	creditsLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
	creditsLabel.TextXAlignment = Enum.TextXAlignment.Center
	creditsLabel.TextWrapped = true
	creditsLabel.LayoutOrder = 8
	creditsLabel.Parent = homeScroll
	
	-- Fetch stats
	fetchStats()
	task.spawn(function()
		while true do
			task.wait(60)
			fetchStats()
		end
	end)
	
	-- Apply saved language
	applyLanguage(langCode)
	
end)() -- HOME PAGE
-- ============= REGISTRY SEARCH + AUTOCOMPLETE =============
-- WRAP dans local function + appel pour isoler les locals
local function _initRegistrySearch()
	local registrySearchBox = Instance.new("TextBox")
	registrySearchBox.Size = UDim2.new(1, -10, 0, 28)
	registrySearchBox.Position = UDim2.new(0, 5, 0, 5)
	registrySearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	registrySearchBox.BackgroundTransparency = 0.2
	registrySearchBox.TextColor3 = Color3.fromRGB(230, 230, 230)
	registrySearchBox.PlaceholderText = "> Rechercher un pseudo..."
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

-- Drag manuel du mini panel autoclick (clickControl)  declenche par controlHeader
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
	btn.Image = "rbxassetid://102429262384981"
	btn.ScaleType = Enum.ScaleType.Fit
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Visible = false
	btn.ZIndex = 9999
	btn.Parent = screenGui
	_createCorner(btn, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 80, 220)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
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
		goodbye.TextWrapped = true
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
		if noclipState.loop then noclipState.loop:Disconnect() noclipState.loop = nil end
		if noclipState.loop2 then noclipState.loop2:Disconnect() noclipState.loop2 = nil end
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
	-- Stop AFK mode + gotoWalk connections
	if gotoWalkState.afkMode then stopAfkMode() end
	if gotoWalkState.followConnection then gotoWalkState.followConnection:Disconnect() gotoWalkState.followConnection = nil end
	if gotoWalkState.afkConnection then gotoWalkState.afkConnection:Disconnect() gotoWalkState.afkConnection = nil end
	-- Stop aimbot
	if _G.aimbotSwitch and _G.aimbotSwitch.get and _G.aimbotSwitch.get() then _G.aimbotSwitch.set(false) end
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
local pinnedPlayers = {} -- joueurs epingles (pin) en haut de la liste
_G._agora_pinnedPlayers = pinnedPlayers
-- Settings de notifications pour les joueurs epingles (global, pas par joueur)
local pinnedNotifSettings = {
	death = true,      -- notif quand un joueur epingle meurt
	leave = true,      -- notif quand un joueur epingle quitte
	join = true,       -- notif quand un joueur epingle rejoint
	team = false,      -- notif quand un joueur epingle change de team
	chat = false,      -- notif quand un joueur epingle parle
	userId = false,    -- copier UserId
	profile = false,   -- ouvrir profil web
}
_G._agora_pinnedNotifSettings = pinnedNotifSettings

-- Systeme de notification visuelle (bas-droite, auto-disparait 4s)
local notifFrames = {}
local function showNotif(text, color)
	color = color or Color3.fromRGB(80, 160, 255)
	local n = #notifFrames
	local notifW = _dt == "Mobile" and 300 or 240
	local notifH = _dt == "Mobile" and 44 or 32
	-- Decaler les anciennes vers le haut
	for i = 1, n do
		if notifFrames[i] and notifFrames[i].Parent then
			notifFrames[i].Position = UDim2.new(1, -(notifW + 20), 1, -60 - (n - i + 1) * (notifH + 8))
		end
	end
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, notifW, 0, notifH)
	frame.Position = UDim2.new(1, -(notifW + 20), 1, -60)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.ZIndex = 200
	frame.Parent = screenGui
	createCorner(frame, 8)
	createStroke(frame, Color3.fromRGB(255, 255, 255), 1)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -12, 1, 0)
	lbl.Position = UDim2.new(0, 6, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.TextWrapped = true
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Parent = frame
	notifFrames[#notifFrames + 1] = frame
	-- Animation slide-in
	frame.Position = UDim2.new(1, 0, 1, -60)
	tween(frame, {Position = UDim2.new(1, -(notifW + 20), 1, -60)}, 0.3)
	-- Auto-remove apres 4s
	task.delay(4, function()
		tween(frame, {Position = UDim2.new(1, 0, 1, -60), BackgroundTransparency = 1}, 0.3)
		task.wait(0.3)
		if frame and frame.Parent then frame:Destroy() end
		-- Retirer de la liste
		for i, f in ipairs(notifFrames) do
			if f == frame then table.remove(notifFrames, i) break end
		end
		-- Recaler les restantes
		for i, f in ipairs(notifFrames) do
			if f and f.Parent then
				f.Position = UDim2.new(1, -(notifW + 20), 1, -60 - (#notifFrames - i) * (notifH + 8))
			end
		end
	end)
end
_G._agora_showNotif = showNotif

-- searchBox de Joueurs = FILTRE LOCAL de la liste des joueurs connectes
-- (la recherche officielle par username Roblox reste dans Registry)
local playerSearchBox = Instance.new("TextBox")
playerSearchBox.Size = UDim2.new(1, -10, 0, 26)
playerSearchBox.Position = UDim2.new(0, 5, 0, 8)
playerSearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
playerSearchBox.BackgroundTransparency = 0.4 -- plus discret que la search box Registry
playerSearchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
playerSearchBox.PlaceholderText = "> Filtrer la liste..."
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

-- === CARTE "* MOI" (LocalPlayer)  auto-creee, toujours en haut ===
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

	-- Titre "* TOI  @pseudo"
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
			local myName = _lp.Name or "..."
			local myDisp = _lp.DisplayName or "..."
			local myUid = tostring(_lp.UserId or "...")
			local myAgeDays = _lp.AccountAge or 0
			local myYears = math.floor(myAgeDays / 365)
			local myRem = myAgeDays - (myYears * 365)
			local myMt = tostring(_lp.MembershipType or "None"):gsub("Enum.MembershipType.", "")
			local myPing = "..."
			pcall(function() myPing = tostring(math.floor((_lp.GetNetworkPing and _lp:GetNetworkPing() or 0) * 1000)) .. " ms" end)
			local myTeam = (_lp.Team and _lp.Team.Name) or "Aucune"
			local myChar = _lp.Character
			local myHp = "..."
			local myPos = "..."
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
			local myGame = tostring(game.GameId or "...")
			local myPlace = tostring(game.PlaceId or "...")

			myTitle.Text = "* TOI  @" .. myName .. " (" .. myDisp .. ")"
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
	msg.Text = "Restaurer les parametres pour @" .. lastName .. " ..."
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

-- === DETECTION DEVICE PASSIVE (heuristique de mouvement) ===
-- Roblox n'expose pas le device des autres joueurs. On l'infere du comportement :
--   Mobile  = joystick analogique -> vitesse variable, rafales courtes, peu de strafe, sauts rares
--   PC      = clavier binaire -> pleine vitesse instantanee, strafe precis, rotations rapides
--   VR      = camera continue, presque jamais de saut, mouvement lent
-- C'est une PROBABILITE, pas une certitude. ~80-90% fiable avec assez d'echantillons.
local deviceTracker = {}  -- [plr] = {samples, totalSpeed, totalVar, strafe, jumps, lastPos, lastSpeed, verdict, confidence}

local function deviceVerdict(d)
	if not d or d.samples < 8 then return "Detection...", 0 end
	local avgSpeed = d.totalSpeed / d.samples
	local speedVar = d.totalVar / d.samples
	local strafeRatio = d.strafe / math.max(1, d.samples)
	local jumpRate = d.jumps / math.max(1, d.samples)
	-- VR : quasi-zero saut + vitesse lente
	if jumpRate < 0.01 and avgSpeed < 8 then
		return "VR", 0.6
	end
	-- Mobile : forte variation de vitesse (analogique) + peu de strafe + sauts rares
	if speedVar > 0.35 and strafeRatio < 0.12 and jumpRate < 0.05 then
		return "Mobile", 0.8
	end
	-- PC : vitesse binaire (faible variation) + strafe frequent
	if speedVar < 0.25 and strafeRatio > 0.2 then
		return "PC", 0.85
	end
	-- Console : analogique comme mobile mais camera differente -> difficile
	if speedVar > 0.3 then
		return "Console", 0.5
	end
	return "PC", 0.6
end

local function trackPlayerDevice(plr)
	if deviceTracker[plr] then return end
	local d = { samples = 0, totalSpeed = 0, totalVar = 0, strafe = 0, jumps = 0, lastPos = nil, lastSpeed = 0, verdict = "Detection...", confidence = 0 }
	deviceTracker[plr] = d
	-- Sauts
	pcall(function()
		plr.CharacterAdded:Connect(function(char)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Jumping:Connect(function() d.jumps = d.jumps + 1 end)
			end
		end)
	end)
	-- Mouvement (Stepped)
	local conn
	conn = game:GetService("RunService").Stepped:Connect(function(_, dt)
		if not plr or not plr.Parent then
			if conn then conn:Disconnect() end
			deviceTracker[plr] = nil
			return
		end
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local pos = hrp.Position
		if d.lastPos then
			local speed = (pos - d.lastPos).Magnitude / math.max(0.001, dt)
			if speed > 0.5 then
				d.samples = d.samples + 1
				d.totalSpeed = d.totalSpeed + speed
				if d.lastSpeed > 0 then
					d.totalVar = d.totalVar + math.abs(speed - d.lastSpeed) / math.max(0.001, speed)
				end
				d.lastSpeed = speed
				-- Strafe : changement de direction lateral (X/Z)
				local dx = pos.X - d.lastPos.X
				local dz = pos.Z - d.lastPos.Z
				if math.abs(dx) > 0.5 and math.abs(dz) > 0.5 then
					d.strafe = d.strafe + 1
				end
			end
		end
		d.lastPos = pos
		if d.samples >= 8 and (d.samples % 8 == 0) then
			d.verdict, d.confidence = deviceVerdict(d)
		end
	end)
end

local function getPlayerDeviceLabel(plr)
	local d = deviceTracker[plr]
	if not d then return "Detection..." end
	local icon = ""
	if d.verdict == "Mobile" then icon = "" elseif d.verdict == "VR" then icon = "" elseif d.verdict == "PC" then icon = "" elseif d.verdict == "Console" then icon = "" end
	return icon .. " " .. d.verdict
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
	nameLbl.Size = UDim2.new(1, -110, 0, 18)
	nameLbl.Position = UDim2.new(0, 32, 0, 4)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = card

	-- Badge device (detection passive par mouvement) - a gauche du voyant rouge, avec emoji
	local deviceLbl = Instance.new("TextLabel")
	deviceLbl.Name = "DeviceBadge"
	deviceLbl.Size = UDim2.new(0, 72, 0, 16)
	deviceLbl.Position = UDim2.new(1, -140, 0, 4)
	deviceLbl.BackgroundTransparency = 1
	deviceLbl.Text = "Detection..."
	deviceLbl.Font = Enum.Font.GothamSemibold
	deviceLbl.TextSize = 10
	deviceLbl.TextColor3 = Color3.fromRGB(150, 200, 255)
	deviceLbl.TextXAlignment = Enum.TextXAlignment.Right
	deviceLbl.Parent = card
	-- Lancer le tracking device passif
	trackPlayerDevice(plr)
	-- Mettre a jour le badge toutes les ~2s
	task.spawn(function()
		while card and card.Parent and plr and plr.Parent do
			deviceLbl.Text = getPlayerDeviceLabel(plr)
			task.wait(2)
		end
	end)

	-- Badge local "mouvement anormal"  info seule, aucune action auto
	local moveBadge = Instance.new("TextLabel")
	moveBadge.Name = "MoveBadge"
	moveBadge.Size = UDim2.new(0, 110, 0, 16)
	moveBadge.Position = UDim2.new(1, -118, 0, 5)
	moveBadge.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
	moveBadge.BackgroundTransparency = 0.2
	moveBadge.BorderSizePixel = 0
	moveBadge.Text = "! mouv. anormal"
	moveBadge.Font = Enum.Font.GothamSemibold
	moveBadge.TextSize = 9
	moveBadge.TextColor3 = Color3.fromRGB(255, 140, 120)
	moveBadge.TextXAlignment = Enum.TextXAlignment.Center
	moveBadge.Visible = false
	moveBadge.Parent = card
	createCorner(moveBadge, 6)
	createStroke(moveBadge, Color3.fromRGB(200, 80, 80), 1)

	-- Cheat detection indicator (discreet red triangle)
	local cheatAlert = Instance.new("TextButton")
	cheatAlert.Name = "CheatAlert"
	cheatAlert.Size = UDim2.new(0, 24, 0, 24)
	cheatAlert.Position = UDim2.new(1, -60, 0, 4)
	cheatAlert.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	cheatAlert.Text = "!"
	cheatAlert.Font = Enum.Font.GothamBold
	cheatAlert.TextSize = 16
	cheatAlert.TextColor3 = Color3.fromRGB(255, 255, 255)
	cheatAlert.BorderSizePixel = 0
	cheatAlert.AutoButtonColor = false
	cheatAlert.Visible = false
	cheatAlert.ZIndex = 5
	cheatAlert.Parent = card
	createCorner(cheatAlert, 6)
	createStroke(cheatAlert, Color3.fromRGB(255, 100, 100), 1)

	-- Check for logs periodically
	task.spawn(function()
		while card and card.Parent and plr and plr.Parent do
			local logs = _G._agoraCheatLogs and _G._agoraCheatLogs[plr.UserId]
			if logs and #logs > 0 then
				cheatAlert.Visible = true
			else
				cheatAlert.Visible = false
			end
			task.wait(1.5)
		end
	end)

	-- Click to open logs popup
	cheatAlert.MouseButton1Click:Connect(function()
		pcall(function()
			local existing = screenGui:FindFirstChild("_CheatLogs_" .. plr.Name)
			if existing then existing:Destroy() return end

			local logs = _G._agoraCheatLogs and _G._agoraCheatLogs[plr.UserId] or {}
			local win = Instance.new("Frame")
			win.Name = "_CheatLogs_" .. plr.Name
			win.Size = UDim2.new(0, 340, 0, 380)
			win.Position = UDim2.new(0.5, -170, 0.5, -190)
			win.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
			win.BorderSizePixel = 0
			win.Active = true
			win.ZIndex = 100
			local okp, par = pcall(function() return game:GetService("CoreGui") end)
			if not okp or not par then par = LocalPlayer:WaitForChild("PlayerGui") end
			win.Parent = screenGui
			createCorner(win, 10)
			createStroke(win, Color3.fromRGB(200, 80, 80), 1)

			-- Drag
			local dragOff = nil
			win.InputBegan:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
					dragOff = inp.Position - win.Position
				end
			end)
			win.InputChanged:Connect(function(inp)
				if dragOff and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
					win.Position = UDim2.new(0, inp.Position.X - dragOff.X, 0, inp.Position.Y - dragOff.Y)
				end
			end)
			win.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
					dragOff = nil
				end
			end)

			-- Title
			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, -40, 0, 30)
			title.Position = UDim2.new(0, 10, 0, 8)
			title.BackgroundTransparency = 1
			title.Text = "Activity Log - " .. plr.Name
			title.Font = Enum.Font.GothamBold
			title.TextSize = 15
			title.TextColor3 = Color3.fromRGB(220, 220, 240)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = win

			-- Close button
			local closeX = Instance.new("TextButton")
			closeX.Size = UDim2.new(0, 26, 0, 26)
			closeX.Position = UDim2.new(1, -32, 0, 6)
			closeX.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			closeX.Text = "X"
			closeX.Font = Enum.Font.GothamBold
			closeX.TextSize = 13
			closeX.TextColor3 = Color3.fromRGB(255, 255, 255)
			closeX.BorderSizePixel = 0
			closeX.Parent = win
			createCorner(closeX, 6)
			closeX.MouseButton1Click:Connect(function() win:Destroy() end)

			-- Scroll for logs
			local scroll = Instance.new("ScrollingFrame")
			scroll.Size = UDim2.new(1, -16, 1, -50)
			scroll.Position = UDim2.new(0, 8, 0, 42)
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.ScrollBarThickness = 4
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			scroll.Parent = win

			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 4)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = scroll

			if #logs == 0 then
				local empty = Instance.new("TextLabel")
				empty.Size = UDim2.new(1, -10, 0, 28)
				empty.BackgroundTransparency = 1
				empty.Text = "No activity logged"
				empty.Font = Enum.Font.Gotham
				empty.TextSize = 13
				empty.TextColor3 = Color3.fromRGB(140, 140, 160)
				empty.Parent = scroll
			else
				for idx, log in ipairs(logs) do
					local row = Instance.new("Frame")
					row.Size = UDim2.new(1, -6, 0, 48)
					row.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
					row.BorderSizePixel = 1
					row.BorderColor3 = Color3.fromRGB(60, 60, 80)
					row.LayoutOrder = idx
					row.ZIndex = 101
					row.Parent = scroll
					createCorner(row, 6)

					local sevColor = Color3.fromRGB(100, 180, 255)
					if log.severity == "warn" then sevColor = Color3.fromRGB(255, 200, 80)
					elseif log.severity == "alert" then sevColor = Color3.fromRGB(255, 100, 100) end

					local sevBar = Instance.new("Frame")
					sevBar.Size = UDim2.new(0, 4, 1, -6)
					sevBar.Position = UDim2.new(0, 2, 0, 3)
					sevBar.ZIndex = 102
					sevBar.BackgroundColor3 = sevColor
					sevBar.BorderSizePixel = 0
					sevBar.Parent = row
					createCorner(sevBar, 2)

					local timeLbl = Instance.new("TextLabel")
					timeLbl.Size = UDim2.new(0, 70, 0, 20)
					timeLbl.Position = UDim2.new(0, 10, 0, 6)
					timeLbl.ZIndex = 102
					timeLbl.BackgroundTransparency = 1
					timeLbl.Text = log.time
					timeLbl.Font = Enum.Font.GothamMonospace
					timeLbl.TextSize = 11
					timeLbl.TextColor3 = sevColor
					timeLbl.TextXAlignment = Enum.TextXAlignment.Left
					timeLbl.Parent = row

					local typeLbl = Instance.new("TextLabel")
					typeLbl.Size = UDim2.new(1, -90, 0, 20)
					typeLbl.Position = UDim2.new(0, 84, 0, 6)
					typeLbl.ZIndex = 102
					typeLbl.BackgroundTransparency = 1
					typeLbl.Text = log.type
					typeLbl.Font = Enum.Font.GothamBold
					typeLbl.TextSize = 12
					typeLbl.TextColor3 = Color3.fromRGB(240, 240, 250)
					typeLbl.TextXAlignment = Enum.TextXAlignment.Left
					typeLbl.TextWrapped = true
					typeLbl.Parent = row

					local detLbl = Instance.new("TextLabel")
					detLbl.Size = UDim2.new(1, -90, 0, 18)
					detLbl.Position = UDim2.new(0, 84, 0, 26)
					detLbl.ZIndex = 102
					detLbl.BackgroundTransparency = 1
					detLbl.Text = log.detail
					detLbl.Font = Enum.Font.Gotham
					detLbl.TextSize = 11
					detLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
					detLbl.TextXAlignment = Enum.TextXAlignment.Left
					detLbl.TextWrapped = true
					detLbl.TextTruncate = Enum.TextTruncate.AtEnd
					detLbl.Parent = row
				end
			end

			scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
		end)
	end)

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
	statusCol.Text = "Statut: ..."
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
	distLbl.Text = "Distance: ..."
	distLbl.Font = Enum.Font.Gotham
	distLbl.TextSize = 10
	distLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	distLbl.TextXAlignment = Enum.TextXAlignment.Left
	distLbl.Parent = card

	local hpLbl = Instance.new("TextLabel")
	hpLbl.Size = UDim2.new(0.55, -6, 0, 14)
	hpLbl.Position = UDim2.new(0, 6, 0, 52)
	hpLbl.BackgroundTransparency = 1
	hpLbl.Text = "HP: ..."
	hpLbl.Font = Enum.Font.Gotham
	hpLbl.TextSize = 10
	hpLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	hpLbl.TextXAlignment = Enum.TextXAlignment.Left
	hpLbl.Parent = card

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Size = UDim2.new(0.55, -6, 0, 14)
	speedLbl.Position = UDim2.new(0, 6, 0, 66)
	speedLbl.BackgroundTransparency = 1
	speedLbl.Text = "Vitesse/Saut: ..."
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
	chatLbl.Text = "Chat: chargement..."
	chatLbl.Font = Enum.Font.Gotham
	chatLbl.TextSize = 10
	chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
	chatLbl.TextXAlignment = Enum.TextXAlignment.Left
	chatLbl.Parent = card

	_G._resolveCanChat(plr, function(canChat, src)
		if chatLbl and chatLbl.Parent then
			if src == "CanTalkWithMe" then
				if canChat == true then
					chatLbl.Text = "Chat: OK"
					chatLbl.TextColor3 = Color3.fromRGB(120, 220, 140)
				else
					chatLbl.Text = "Chat: bloque"
					chatLbl.TextColor3 = Color3.fromRGB(220, 120, 120)
				end
			else
				-- Pas de serveur : on montre juste si le joueur a le chat active
				if canChat == true then
					chatLbl.Text = "Chat: active (" .. src .. ")"
					chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
				elseif canChat == false then
					chatLbl.Text = "Chat: desactive (" .. src .. ")"
					chatLbl.TextColor3 = Color3.fromRGB(180, 120, 120)
				else
					chatLbl.Text = "Chat: ..."
					chatLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
				end
			end
		end
	end)

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.55, -6, 0, 14)
	statusLbl.Position = UDim2.new(0, 6, 0, 94)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "Statut: ..."
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

	-- Bouton Pin (epingler en haut de la liste)
	local pinBtn = Instance.new("TextButton")
	pinBtn.Size = UDim2.new(0, 28, 0, 18)
	pinBtn.Position = UDim2.new(1, -34, 0, 4)
	pinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	pinBtn.Text = "Pin"
	pinBtn.Font = Enum.Font.GothamSemibold
	pinBtn.TextSize = 9
	pinBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
	pinBtn.BorderSizePixel = 0
	pinBtn.Parent = card
	createCorner(pinBtn, 4)

	local function updatePinBtn()
		if pinnedPlayers[plr] then
			pinBtn.BackgroundColor3 = Color3.fromRGB(220, 170, 40)
			pinBtn.TextColor3 = Color3.new(0, 0, 0)
			card.LayoutOrder = -999 + (plr.Name:byte(1) % 100)
		else
			pinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			pinBtn.TextColor3 = Color3.fromRGB(160, 160, 170)
			card.LayoutOrder = plr.Name:byte(1) + 1000
		end
	end
	updatePinBtn()
	-- Auto-pin des amis Roblox
	task.spawn(function()
		local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
		if ok and isFriend and not pinnedPlayers[plr] then
			pinnedPlayers[plr] = true
			updatePinBtn()
		end
	end)
	
	-- Mini boutons de notification (visibles quand epingle)
	local miniBar = Instance.new("Frame")
	miniBar.Size = UDim2.new(1, -10, 0, 20)
	miniBar.Position = UDim2.new(0, 5, 1, -22)
	miniBar.BackgroundTransparency = 1
	miniBar.Visible = false
	miniBar.Parent = card
	local miniLayout = Instance.new("UIListLayout")
	miniLayout.FillDirection = Enum.FillDirection.Horizontal
	miniLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	miniLayout.Padding = UDim.new(0, 3)
	miniLayout.Parent = miniBar
	
	local function createMiniBtn(text, settingKey, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 44, 0, 18)
		btn.BackgroundColor3 = pinnedNotifSettings[settingKey] and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(40, 40, 50)
		btn.Text = text
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 9
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BorderSizePixel = 0
		btn.Parent = miniBar
		createCorner(btn, 4)
		btn.MouseButton1Click:Connect(function()
			pinnedNotifSettings[settingKey] = not pinnedNotifSettings[settingKey]
			-- Appliquer a TOUS les boutons de toutes les cartes epinglees
			btn.BackgroundColor3 = pinnedNotifSettings[settingKey] and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(40, 40, 50)
			for _, c in pairs(playerCards) do
				if c and c.Parent then
					for _, child in ipairs(c:GetDescendants()) do
						if child:IsA("TextButton") and child.Text == text then
							child.BackgroundColor3 = pinnedNotifSettings[settingKey] and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(40, 40, 50)
						end
					end
				end
			end
			if callback then callback() end
		end)
		return btn
	end
	
	createMiniBtn("Death", "death")
	createMiniBtn("Leave", "leave")
	createMiniBtn("Join", "join")
	createMiniBtn("Team", "team")
	createMiniBtn("Chat", "chat")
	createMiniBtn("UserId", "userId", function()
		if setclipboard then setclipboard(tostring(plr.UserId)) end
	end)
	createMiniBtn("Profil", "profile", function()
		pcall(function() LocalPlayer:SetCore("ShellOpenUrl", "https://www.roblox.com/users/" .. plr.UserId .. "/profile") end)
	end)
	
	-- Mettre a jour la visibilite des mini boutons selon le pin
	local oldUpdatePinBtn = updatePinBtn
	updatePinBtn = function()
		oldUpdatePinBtn()
		miniBar.Visible = pinnedPlayers[plr] ~= nil
	end
	
	pinBtn.MouseButton1Click:Connect(function()
		if pinnedPlayers[plr] then
			pinnedPlayers[plr] = nil
		else
			pinnedPlayers[plr] = true
		end
		updatePinBtn()
	end)

	local spectating = false

	tpBtn.MouseButton1Click:Connect(function()
		updateCharacter()
		if not rootPart then return end
		-- Si le character du joueur n'est pas charge (trop loin, streaming), forcer le chargement
		local targetHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not targetHrp then
			-- Essayer de charger la zone autour du joueur (streaming)
			local okReq = pcall(function()
				plr:RequestStreamAroundAsync(plr.Character and plr.Character:GetPivot().Position or Vector3.zero)
			end)
			-- Attendre que le character se charge (max 3s)
			local waited = 0
			while not targetHrp and waited < 3 do
				task.wait(0.1)
				waited = waited + 0.1
				targetHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			end
		end
		if targetHrp then
			-- Teleporter devant le joueur, oriente vers lui, a 4 metres
			local targetPos = targetHrp.Position
			local targetLook = targetHrp.CFrame.LookVector
			local tpPos = targetPos + targetLook * 4
			rootPart.CFrame = CFrame.lookAt(tpPos, targetPos)
			-- Grace anti-TP protection
			if protectionsState then
				protectionsState.antiTeleportGraceUntil = tick() + 2.0
			end
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
			arrowText.Text = ""
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
		closeX.Text = "X"
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
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
			local seen = {} -- anti-doublons: ne donne jamais 2 fois le meme tool
			if not target then return items end
			-- 1) Tools equippes (dans le Character) = les VRAIS tools serveur en main
			if target:FindFirstChildOfClass("Humanoid") then
				for _, item in ipairs(target:GetChildren()) do
					if item:IsA("Tool") and not seen[item] then
						seen[item] = true
						table.insert(items, {Name = "(EQ) " .. item.Name, Tool = item, IsServer = true})
					end
				end
			end
			-- 2) Tools dans le Backpack (local) = fallback si le serveur n'est pas dispo
			for _, item in ipairs(plr.Backpack:GetChildren()) do
				if item:IsA("Tool") and not seen[item] then
					seen[item] = true
					table.insert(items, {Name = item.Name, Tool = item, IsServer = false})
				end
			end
			-- 3) Tools dans StarterGear (parfois present)
			pcall(function()
				for _, item in ipairs(plr:GetChildren()) do
					if item.Name == "StarterGear" then
						for _, tool in ipairs(item:GetChildren()) do
							if tool:IsA("Tool") and not seen[tool] then
								seen[tool] = true
								table.insert(items, {Name = "(Gear) " .. tool.Name, Tool = tool, IsServer = false})
							end
						end
					end
				end
			end)
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
						local myBackpack = LocalPlayer:FindFirstChild("Backpack")
						if not myBackpack then return end
						-- Anti-doublon: check si on a deja un tool avec ce nom
						for _, existing in ipairs(myBackpack:GetChildren()) do
							if existing:IsA("Tool") and existing.Name == tool.Name then
								if notify then notify("Deja dans ton sac: " .. tool.Name, 2) end
								return
							end
						end
						-- Tentative serveur: equiper directement si possible
						pcall(function()
							if item.IsServer and tool.Parent == target then
								tool.Parent = myBackpack
							end
						end)
						-- Fallback: clone local
						if not myBackpack:FindFirstChild(tool.Name) then
							local clone = tool:Clone()
							clone.Parent = myBackpack
						end
						if notify then notify("Item vole: " .. tool.Name, 2) end
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
			local alreadyHave = {}
			for _, existing in ipairs(myBackpack:GetChildren()) do
				if existing:IsA("Tool") then alreadyHave[existing.Name] = true end
			end
			for _, item in ipairs(items) do
				if item.Tool and item.Tool.Parent and not alreadyHave[item.Tool.Name] then
					item.Tool:Clone().Parent = myBackpack
					alreadyHave[item.Tool.Name] = true
					stolen += 1
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
				copied += 1
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
							local inVehicle = h.SeatPart ~= nil
							-- Tolere: vehicules, sauts normaux, plateformes mobiles
							local isAirborne = (floorY > 50 and vSpeed > 10) or (vSpeed > 80)
							if flatSpeed > 2 then
								stateText = (h.WalkSpeed > 18 or flatSpeed > 18) and "Running" or "Walking"
							end
							-- Flag info uniquement : seuils hauts pour eviter faux positifs
							-- Vitesse > 100 (pas 30) OU air anormal extreme OU vertical extreme
							-- Tolere vehicules (inVehicle = jamais flag)
							if inVehicle then
								moveFlag = false
							else
								moveFlag = (flatSpeed > 100) or (isAirborne and h.WalkSpeed < 50 and vSpeed > 80) or (vSpeed > 120)
							end
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
					speedLbl.Text = "Vit: ... | Saut: ..."
					statusLbl.Text = "Statut: ..."
				end
			else
				distLbl.Text = "Distance: N/A"
				hpLbl.Text = "HP: N/A"
				speedLbl.Text = "Vit: N/A | Saut: N/A"
				statusLbl.Text = "Statut: N/A"
			end
		end
	end)

	-- === ENRICHISSEMENT v39.43 : temps de connexion + badge ordre d'arrivee ===
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
	infoBtn.Size = UDim2.new(0, 22, 0, 22)
	infoBtn.Position = UDim2.new(0, 6, 0, 3)
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
					arrivalBadge.Text = " La depuis l'ouverture du panel"
					arrivalBadge.TextColor3 = Color3.fromRGB(120, 200, 255)
				else
					local late = math.floor(now - seen)
					arrivalBadge.Text = string.format(" Arrive il y a %ds", late)
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
			copyBtn.Text = "[Copy]"
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
				copyBtn.Text = "[v] Copie"
				copyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
				task.delay(1.5, function()
					if copyBtn and copyBtn.Parent then
						copyBtn.Text = "[Copy]"
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
							table.insert(extra, "Cree le : " .. tostring(d.created or "..."))
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
								table.insert(extra, "Groupe : " .. (d.data[i].group and d.data[i].group.name or "..."))
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
					table.insert(extra, "! APIs bloquees par l'executeur")
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
								local statusIcon = ""
								if t == 3 then
									status = "Hors ligne"
									statusIcon = ""
								elseif t == 2 then
									status = "Au Studio (developpeur)"
									statusIcon = ""
								elseif t == 1 then
									-- Il joue a un jeu
									if p.lastLocation and p.lastLocation ~= "" then
										status = "En jeu : " .. tostring(p.lastLocation)
									else
										status = "En jeu"
									end
									statusIcon = ""
									if p.universeId and tostring(p.universeId) == tostring(game.GameId) then
										status = "* JOUE A CE JEU : " .. tostring(p.lastLocation or "")
										statusIcon = ""
									end
								elseif t == 0 then
									-- Online : peut etre sur le site web / chat / pas dans un jeu
									if p.lastLocation and p.lastLocation ~= "" then
										-- Last location = dernier JEU ou il a joue
										status = "En ligne (dernier jeu : " .. tostring(p.lastLocation) .. ")"
										statusIcon = ""
									else
										status = "En ligne (sur le site Roblox, pas dans un jeu)"
										statusIcon = ""
									end
								end
								table.insert(extra, statusIcon .. " Statut : " .. status)
								if p.lastLocation and p.lastLocation ~= "" then
									table.insert(extra, "   Dernier jeu : " .. tostring(p.lastLocation))
								end
								if p.universeId then
									table.insert(extra, "   UniverseId : " .. tostring(p.universeId) .. (tostring(p.universeId) == tostring(game.GameId) and " (= CE JEU)" or ""))
								end
								if p.lastOnline then
									-- Parser lastOnline ISO -> delai relatif
									local y, mo, da, h, mi, s = p.lastOnline:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
									if y then
										local epochThen = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(da), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
										local diff = os.time() - epochThen
										if diff < 60 then
											table.insert(extra, "   Vu il y a : a l'instant")
										elseif diff < 3600 then
											table.insert(extra, "   Vu il y a : " .. math.floor(diff/60) .. " min")
										elseif diff < 86400 then
											table.insert(extra, "   Vu il y a : " .. math.floor(diff/3600) .. "h " .. math.floor((diff%3600)/60) .. "min")
										elseif diff < 2592000 then
											table.insert(extra, "   Vu il y a : " .. math.floor(diff/86400) .. "j " .. math.floor((diff%86400)/3600) .. "h")
										else
											table.insert(extra, "   Vu le : " .. tostring(p.lastOnline))
										end
									else
										table.insert(extra, "   Vu la derniere fois : " .. tostring(p.lastOnline))
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
											favNote = " * (CE JEU)"
										end
										table.insert(extra, " " .. favName .. favNote)
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
					table.insert(extra, " " .. (isPremium and "Premium" or "Non-Premium") .. (mt ~= "None" and mt ~= "Premium" and (" (" .. mt .. ")") or ""))
					-- Network ping (latence)
					pcall(function()
						local ping = plr:GetNetworkPing()
						local pingIcon = ""
						if ping > 0.2 then pingIcon = "" elseif ping > 0.4 then pingIcon = "" end
						table.insert(extra, pingIcon .. " Ping : " .. math.floor(ping * 1000) .. " ms")
					end)
					-- Ami avec moi ?
					if LocalPlayer and plr ~= LocalPlayer then
						pcall(function()
							local isFriend = LocalPlayer:IsFriendsWith(plr.UserId)
							if isFriend then
								table.insert(extra, "Ami: OUI")
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
							table.insert(extra, "* DANS CE JEU")
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
	-- Notif si joueur epingle rejoint
	if pinnedNotifSettings.join and plr ~= LocalPlayer and pinnedPlayers[plr] then
		showNotif("[Pin] " .. plr.DisplayName .. " a rejoint", Color3.fromRGB(80, 200, 120))
	end
	-- Notif chat pour joueurs epingles
	if pinnedNotifSettings.chat then
		pcall(function() plr.Chatted:Connect(function(msg)
			if pinnedPlayers[plr] and #msg > 0 then
				showNotif("[Chat] " .. plr.DisplayName .. ": " .. msg:sub(1, 40), Color3.fromRGB(100, 180, 255))
			end
		end) end)
	end
	-- Notif team change pour joueurs epingles
	pcall(function() plr.TeamChanged:Connect(function()
		if pinnedPlayers[plr] and pinnedNotifSettings.team then
			showNotif("[Team] " .. plr.DisplayName .. " -> " .. tostring(plr.Team and plr.Team.Name or "Aucune"), Color3.fromRGB(200, 160, 60))
		end
	end) end)
	-- Notif mort pour joueurs epingles
	pcall(function() plr.CharacterAdded:Connect(function(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				if pinnedPlayers[plr] and pinnedNotifSettings.death then
					showNotif("[Death] " .. plr.DisplayName .. " est mort", Color3.fromRGB(220, 80, 80))
				end
			end)
		end
	end) end)
end)
Players.PlayerRemoving:Connect(function(plr)
	-- Notification si le joueur etait epingle
	if pinnedPlayers[plr] then
		if pinnedNotifSettings.leave then
			showNotif("[Pin] " .. plr.DisplayName .. " a quitte le jeu", Color3.fromRGB(220, 100, 80))
		end
		pinnedPlayers[plr] = nil
	end
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
						chatSym = data.canChat == true and "" or ""
					elseif data.canChat ~= nil then
						chatSym = data.canChat == true and " " or " "
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
					if data.canChat == true then chatSym = ""
					elseif data.canChat == false then chatSym = ""
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

-- Rafraichit l'ESP toutes les 60s sans flash (rebuild silencieux si le personnage a change)
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
	local letters = {"0","1","/","\\","[","]","{","}","<",">","#","@","%","&","*","+","-","=","...","!"}
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
	local particleLetters = {"0","1","A","B","C","X","Y","Z","<",">","/","\\","{","}","#","@","%","&","*","+","-","=","...","!","#","$","O","M","E"}
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
	local shardLetters = {"0","1","X","Y","Z","#","@","%","&","*","/","\\","M","E","O","G","[","]","{","}","<",">","!","...","$","+","-","="}
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
	local shardLetters = {"0","1","X","Y","Z","#","@","%","&","*","/","\\","M","E","O","G","[","]","{","}","<",">","!","...","$","+","-","="}
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
local flyState = { flying = false, decollage = false, speed = 120, gyro = nil, vel = nil, loop = nil, mobileInput = Vector3.zero, mobileUp = false, mobileDown = false, mobileStickId = nil, mobileBase = nil, mobileKnob = nil, mobileBasePos = nil, mobileUiCreated = false, currentVel = Vector3.zero, targetVel = Vector3.zero, seatPart = nil }
local noclipState = { enabled = false, loop = nil }
_G._agora_noclipState = noclipState
local walkSpeedState = { value = 16 }
local jumpState = { infinite = false }
local platformState = { enabled = false, part = nil, y = 0, offset = 0 }

local function stopFly()
	-- Arreter le decollage si en cours
	flyState.decollage = false
	-- Nettoyer le gyro/vel meme pendant le decollage (avant que flying = true)
	if flyState.gyro then flyState.gyro:Destroy() flyState.gyro = nil end
	if flyState.vel then flyState.vel:Destroy() flyState.vel = nil end
	if not flyState.flying then return end
	flyState.flying = false
	if flyState.loop then flyState.loop:Disconnect() flyState.loop = nil end
	if flyState.gyro then flyState.gyro:Destroy() flyState.gyro = nil end
	if flyState.vel then flyState.vel:Destroy() flyState.vel = nil end
	flyState.mobileInput = Vector3.zero
	flyState.mobileUpHeld = false
	flyState.mobileDownHeld = false
	flyState.mobileStickId = nil
	flyState.currentVel = Vector3.zero
	flyState.targetVel = Vector3.zero
	if flyState.showMobileUi then flyState.showMobileUi(false) end
	updateCharacter()
	-- Zero velocity IMMEDIAT
	if rootPart then
		pcall(function() rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
		pcall(function() rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end)
	end
	-- Garder PlatformStand 0.15s de plus pour eviter le snap physique (sursauts)
	if humanoid then
		pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true) end)
		pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
		pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true) end)
		pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
		end
	task.delay(0.15, function()
		if humanoid and humanoid.Parent then
			humanoid.PlatformStand = false
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
			task.delay(0.2, function()
				if humanoid and humanoid.Parent then
					humanoid.JumpPower = 50
					humanoid.JumpHeight = 7.2
				humanoid.WalkSpeed = walkSpeedState.value or 16
				end
			end)
		end
		-- Restaurer collision progressivement (sauf si noclip actif)
		if character and not (noclipState and noclipState.enabled) then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
		end
		local animate = character and character:FindFirstChild("Animate")
		if animate then
			animate.Disabled = false
		end
	end)
	flySwitch.set(false)
	-- Active la grace anti-TP + antiFling/Fall pour reinitialiser sans sursauts
	if protectionsState then
		protectionsState.antiTeleportGraceUntil = tick() + 2.0
		protectionsState.flyStopGraceUntil = tick() + 1.5
	end
end

-- ============= FLY MOBILE (joystick natif Roblox) =============
;(function(_fly)
	local function isMobile()
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end
	-- Plus de joystick custom : on utilise le joystick natif Roblox (Gamepad1/Thumbstick1)
	-- qui apparait automatiquement sur mobile. showMobileUi devient un no-op.
	_fly.showMobileUi = function() end
	_fly.isMobile = isMobile
end)(flyState)

local function startFly()
	updateCharacter()
	if flyState.flying or not rootPart then return end

	-- Detecter si on est assis (vehicule/seat)
	local wasSeated = humanoid and humanoid.Sit and humanoid.SeatPart
	flyState.seatPart = wasSeated or nil

	-- Son de demarrage fly (tres doux)
		-- pcall(function() playSound(88442833509532, 0.12) end)

		-- Si on est assis, on reste dans le siege : on garde la position assise
		-- PAS de Animate.Disabled, PAS de PlatformStand, juste empecher le saut
		if wasSeated and humanoid then
			-- Garder la position assise : ne PAS desactiver Animate
			-- Desactiver saut seulement
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
			humanoid.WalkSpeed = 0
			-- Desactiver etats de chute/saut au niveau moteur
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
			flyState.flying = true
			-- Loop leger : garder JumpPower=0 + si on sort du siege, activer fly normal
			flyState.loop = RunService.RenderStepped:Connect(function(dt)
				if not flyState.flying then return end
				if humanoid then
					if humanoid.JumpPower ~= 0 then humanoid.JumpPower = 0 end
					if humanoid.JumpHeight ~= 0 then humanoid.JumpHeight = 0 end
					-- Si Roblox nous sort du siege, on active le fly normal
					if not humanoid.Sit and not humanoid.SeatPart then
						-- On est sortis du siege, on active le fly normal
						flyState.seatPart = nil
						-- Creer BodyGyro + BodyVelocity maintenant
						flyState.gyro = Instance.new("BodyGyro")
						flyState.gyro.P = 5e3
						flyState.gyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
						flyState.gyro.CFrame = Camera.CFrame
						flyState.gyro.Parent = rootPart
						flyState.vel = Instance.new("BodyVelocity")
						flyState.vel.Velocity = Vector3.zero
						flyState.vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
						flyState.vel.Parent = rootPart
						-- Physics state + PlatformStand (anti-sursaut)
						humanoid.PlatformStand = true
						pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
						pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end)
						pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
						pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false) end)
						pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false) end)
						-- Remplacer le loop par le fly normal
						if flyState.loop then flyState.loop:Disconnect() flyState.loop = nil end
						flyState.loop = RunService.RenderStepped:Connect(function(dt2)
							updateCharacter()
							if not flyState.flying or not rootPart or not rootPart.Parent then return end
							if flyState.gyro and flyState.gyro.Parent ~= rootPart then flyState.gyro.Parent = rootPart end
							if flyState.vel and flyState.vel.Parent ~= rootPart then flyState.vel.Parent = rootPart end
							-- GYRO SMOOTH
							if flyState.gyro then
								local targetCF = Camera.CFrame
								local currentCF = flyState.gyro.CFrame
								flyState.gyro.CFrame = currentCF:Lerp(targetCF, 1 - math.exp(-0.25 * 60 * dt2))
							end
							-- CanCollide=false sur body parts (sauf HRP) + FORCER Physics + stop ALL anims
							if character and not (humanoid and humanoid.Sit and humanoid.SeatPart) then
								for _, part in ipairs(character:GetDescendants()) do
									if part:IsA("BasePart") and (part.Name ~= "HumanoidRootPart" or (noclipState and noclipState.enabled)) and part.CanCollide then part.CanCollide = false end
								end
							end
									if humanoid then
										pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end)
										pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
										pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false) end)
										pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false) end)
										if not humanoid.PlatformStand then humanoid.PlatformStand = true end
										if humanoid.WalkSpeed ~= 0 then humanoid.WalkSpeed = 0 end
										if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
											pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
										end
										pcall(function()
											for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
												track:Stop(0)
											end
										end)
									end
							-- Movement
							local move = Vector3.zero
							if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Z) then move += Camera.CFrame.LookVector end
							if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
							if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Camera.CFrame.RightVector end
							if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
							if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
							if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
							-- Mobile: joystick natif Roblox (Gamepad1/Thumbstick1) + LookVector camera (monte/descend en regardant haut/bas)
							local stick = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
							local sx, sy = 0, 0
							for _, s in ipairs(stick) do
								if s.KeyCode == Enum.KeyCode.Thumbstick1 then
									sx, sy = s.Position.X, s.Position.Y
								end
							end
							if math.abs(sx) > 0.1 or math.abs(sy) > 0.1 then
								move += Camera.CFrame.LookVector * -sy + Camera.CFrame.RightVector * sx
							end
							-- SMOOTH VELOCITY LERP
							if move.Magnitude > 0 then
								flyState.targetVel = move.Unit * flyState.speed
							else
								flyState.targetVel = Vector3.zero
							end
							if flyState.targetVel.Magnitude > 0 then
								local smoothFactor = 0.20
								local dot = flyState.currentVel.Unit:Dot(flyState.targetVel.Unit)
								if dot < 0.3 then smoothFactor = 0.08 end
								local alpha = 1 - math.exp(-smoothFactor * 60 * dt2)
								flyState.currentVel = flyState.currentVel:Lerp(flyState.targetVel, alpha)
							else
								local alpha = 1 - math.exp(-0.30 * 60 * dt2)
								flyState.currentVel = flyState.currentVel:Lerp(Vector3.zero, alpha)
								if flyState.currentVel.Magnitude < 0.5 then
									flyState.currentVel = Vector3.zero
								end
							end
							if flyState.vel then
								flyState.vel.Velocity = flyState.currentVel
							end
						end)
					end
				end
			end)
			-- Show mobile UI
			if flyState.isMobile and flyState.isMobile() and flyState.showMobileUi then
				flyState.showMobileUi(true)
			end
			return
		end

		-- Creer BodyGyro + BodyVelocity AVANT le decollage pour garder le follow camera
		flyState.gyro = Instance.new("BodyGyro")
		flyState.gyro.P = 5e3
		flyState.gyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		flyState.gyro.CFrame = Camera.CFrame
		flyState.gyro.Parent = rootPart

		flyState.vel = Instance.new("BodyVelocity")
		flyState.vel.Velocity = Vector3.zero
		flyState.vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		flyState.vel.Parent = rootPart

		-- PlatformStand + Physics state = ZERO sursaut permanent
		if humanoid then
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false) end)
			humanoid.PlatformStand = true
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
			humanoid.WalkSpeed = 0
			pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
			pcall(function()
				for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
					track:Stop(0)
				end
			end)
		end
		-- CanCollide=false sur body parts (HRP inclus si noclip actif = traverser les murs en vol)
		if character and not (humanoid and humanoid.Sit and humanoid.SeatPart) then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and (part.Name ~= "HumanoidRootPart" or (noclipState and noclipState.enabled)) and part.CanCollide then
					part.CanCollide = false
				end
			end
		end

		-- Decollage doux : lever en preservant la rotation (hauteur 0 = instantane)
		local decollageHeight = 0
		local startY = rootPart.Position.Y
		local targetY = startY + decollageHeight
		local startRot = rootPart.CFrame.Rotation

		flyState.decollage = true
		local decollageT = 0
		local decollageDuration = 0
		while decollageT < decollageDuration and flyState.decollage do
		                local dt = task.wait()
		                decollageT = decollageT + dt
		                local alpha = math.min(1, decollageT / decollageDuration)
		                local eased = 1 - (1 - alpha) * (1 - alpha)
		                pcall(function()
		                    if rootPart and rootPart.Parent then
		                        local cur = rootPart.Position
		                        local newY = startY + (targetY - startY) * eased
		                        -- Preserver X/Z + rotation, seulement changer Y
		                        rootPart.CFrame = CFrame.new(cur.X, newY, cur.Z) * startRot
		                        -- Le BodyGyro suit la camera en continu pendant le decollage
		                        if flyState.gyro then flyState.gyro.CFrame = Camera.CFrame end
		                    end
		                end)
		            end

		flyState.decollage = false

		if not rootPart or not rootPart.Parent then return end
		flyState.flying = true
	-- Show mobile UI on touch devices
	if flyState.isMobile and flyState.isMobile() and flyState.showMobileUi then
		flyState.showMobileUi(true)
	end

	flyState.loop = RunService.RenderStepped:Connect(function(dt)
		updateCharacter()
		if not flyState.flying or not rootPart or not rootPart.Parent then return end
		-- Re-attach body movers if rootPart changed (respawn)
		if flyState.gyro and flyState.gyro.Parent ~= rootPart then flyState.gyro.Parent = rootPart end
		if flyState.vel and flyState.vel.Parent ~= rootPart then flyState.vel.Parent = rootPart end

		-- === GYRO SMOOTH : rotation fluide vers la camera ===
		if flyState.gyro then
			-- Interpoler la rotation du gyro vers la camera (pas snap direct)
			local targetCF = Camera.CFrame
			local currentCF = flyState.gyro.CFrame
			-- Lerp rotation (slerp equivalent via Lerp sur CFrame)
			flyState.gyro.CFrame = currentCF:Lerp(targetCF, 1 - math.exp(-0.25 * 60 * dt))
		end

		-- CanCollide=false sur body parts (HRP inclus si noclip actif = traverser les murs en vol)
		if character and not (humanoid and humanoid.Sit and humanoid.SeatPart) then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and (part.Name ~= "HumanoidRootPart" or (noclipState and noclipState.enabled)) and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
		-- FORCER Physics + PlatformStand + WalkSpeed=0 chaque frame (anti-sursaut permanent)
		if humanoid then
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false) end)
			pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false) end)
			if not humanoid.PlatformStand then humanoid.PlatformStand = true end
			if humanoid.WalkSpeed ~= 0 then humanoid.WalkSpeed = 0 end
			if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
				pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
			end
			pcall(function()
				for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
					track:Stop(0)
				end
			end)
		end

		local move = Vector3.zero
		-- PC controls (clavier) -- ignorer si le joueur ecrit dans le chat
		local chatFocus = UserInputService:GetFocusedTextBox()
		if not chatFocus then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Z) then move += Camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
		end
		-- Mobile: joystick natif Roblox (Gamepad1/Thumbstick1) + LookVector camera (monte/descend en regardant haut/bas)
		local stick = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		local sx, sy = 0, 0
		for _, s in ipairs(stick) do
			if s.KeyCode == Enum.KeyCode.Thumbstick1 then
				sx, sy = s.Position.X, s.Position.Y
			end
		end
		if math.abs(sx) > 0.1 or math.abs(sy) > 0.1 then
			move += Camera.CFrame.LookVector * -sy + Camera.CFrame.RightVector * sx
		end

		-- === SMOOTH VELOCITY LERP ===
		-- Target velocity = direction * speed (or zero if no input)
		if move.Magnitude > 0 then
			flyState.targetVel = move.Unit * flyState.speed
		else
			flyState.targetVel = Vector3.zero
		end

		if flyState.targetVel.Magnitude > 0 then
			-- Smooth acceleration
			local smoothFactor = 0.20
			local dot = flyState.currentVel.Unit:Dot(flyState.targetVel.Unit)
			if dot < 0.3 then smoothFactor = 0.08 end
			local alpha = 1 - math.exp(-smoothFactor * 60 * dt)
			flyState.currentVel = flyState.currentVel:Lerp(flyState.targetVel, alpha)
		else
			-- SNAP to zero : pas de drift residuel
			local alpha = 1 - math.exp(-0.30 * 60 * dt)
			flyState.currentVel = flyState.currentVel:Lerp(Vector3.zero, alpha)
			-- Si presque zero, snap exact
			if flyState.currentVel.Magnitude < 0.5 then
				flyState.currentVel = Vector3.zero
			end
		end

		if flyState.vel then
			flyState.vel.Velocity = flyState.currentVel
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

local flySwitch = createSwitch(moveScroll, "Fly", 0, function(on)
	if on then startFly() else stopFly() end
end)

local flySlider = createSlider(moveScroll, "Vitesse Fly", 0, 20, 500, flyState.speed, function(v)
	flyState.speed = math.floor(v)
end, Color3.fromRGB(100, 180, 255))

local noclipSwitch = createSwitch(moveScroll, "NoClip", 0, function(on)
	noclipState.enabled = on
	if on then
		updateCharacter()
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
				end
			end
		end
		-- Double boucle : Stepped + RenderStepped pour max couverture
		local function setNoClip()
			if not noclipState.enabled then return end
			if humanoid and humanoid.Sit and humanoid.SeatPart then return end
			if character then
				for _, p in ipairs(character:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanCollide = false
					end
				end
			end
		end
		noclipState.loop = RunService.RenderStepped:Connect(function()
			updateCharacter()
			setNoClip()
		end)
		noclipState.loop2 = RunService.Stepped:Connect(function()
			updateCharacter()
			setNoClip()
		end)
	else
		if noclipState.loop then noclipState.loop:Disconnect() noclipState.loop = nil end
		if noclipState.loop2 then noclipState.loop2:Disconnect() noclipState.loop2 = nil end
		updateCharacter()
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
			end
		end
		if protectionsState then
			protectionsState.antiTeleportGraceUntil = tick() + 2.0
		end
	end
end)
_G._agora_noclipSwitch = noclipSwitch

local PathfindingService = game:GetService("PathfindingService")

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
	afkMode = false,
	afkConnection = nil,
	afkLastChat = 0,
	afkIndicator = nil,
}

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
	local startPos = rootPart.Position
	local startHeight = math.floor(startPos.Y)

	-- 1) Tentative avec PathfindingService Roblox (params optimises)
	local waypoints = {}
	local ok, pathOrErr = pcall(function()
		local p = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 4,
			Costs = {
				Water = 20,
				Neutral = 1,
			},
		})
		p:ComputeAsync(startPos, targetPos)
		if p.Status == Enum.PathStatus.Success then
			return p:GetWaypoints()
		end
		return nil
	end)

	if ok and pathOrErr and #pathOrErr > 0 then
		for i, wp in ipairs(pathOrErr) do
			if wp and wp.Position then
				-- Filtrer les waypoints trop haut (barrieres) ? preferer meme hauteur
				local wpHeight = wp.Position.Y
				if math.abs(wpHeight - startHeight) < 15 or i == #pathOrErr then
					table.insert(waypoints, wp.Position)
				end
			end
		end
		if #waypoints > 1 then
			table.remove(waypoints, 1)
		end
		if #waypoints > 0 then return waypoints end
	end

	-- 2) Fallback : ligne droite + raycast pour eviter les murs
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
	if rayClear(startPos, targetPos) then
		return { targetPos }
	end

	-- 3) Fallback : contourner avec raycast lateral (gauche/droite)
	local flat = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
	if flat.Magnitude > 0.1 then
		local flatDir = flat.Unit
		local right = Vector3.new(flatDir.Z, 0, -flatDir.X)
		-- Essayer gauche puis droite
		for _, offsetDir in ipairs({right, -right}) do
			for dist = 5, 20, 5 do
				local detour = startPos + flatDir * math.min(8, flat.Magnitude * 0.4) + offsetDir * dist
				if rayClear(startPos + offsetDir * dist, detour) and rayClear(detour, targetPos) then
					return { detour, targetPos }
				end
			end
		end
		-- Dernier recours : petite etape devant
		local mid = startPos + flatDir * math.min(8, flat.Magnitude * 0.5)
		return { mid + Vector3.new(0, 2, 0) }
	end
	return {}
end

-- Boucle de suivi RenderStepped : suit les waypoints, detecte les blocages, saute
local function manageFollowLoop(start)
	if start then
		-- Stop existing loop first
		if gotoWalkState.followConnection then
			gotoWalkState.followConnection:Disconnect()
			gotoWalkState.followConnection = nil
		end

		gotoWalkState.stuckTimer = tick()
		gotoWalkState.stuckPos = rootPart and rootPart.Position or nil
		gotoWalkState.stuckJumps = 0
		gotoWalkState.currentWaypointIdx = 1
		gotoWalkState.lastJumpTime = 0

		gotoWalkState.followConnection = RunService.RenderStepped:Connect(function(dt)
			if not gotoWalkState.active then return end
			updateCharacter()
			if not rootPart or not humanoid then return end

			local path = gotoWalkState.path
			if not path or #path == 0 then return end

			local idx = gotoWalkState.currentWaypointIdx
			if idx > #path then
				-- Arrive a destination : NE PAS desactiver, juste rester
				return
			end

			local wp = path[idx]
			local dist = (rootPart.Position - wp).Magnitude

			-- Assez proche du waypoint actuel ? Avancer au suivant
			if dist < 4 then
				gotoWalkState.currentWaypointIdx = idx + 1
				gotoWalkState.stuckTimer = tick()
				gotoWalkState.stuckPos = rootPart.Position
				gotoWalkState.stuckJumps = 0
				if idx + 1 <= #path then
					humanoid:MoveTo(path[idx + 1])
				end
				return
			end

			-- Detection de blocage
			local moved = gotoWalkState.stuckPos and (rootPart.Position - gotoWalkState.stuckPos).Magnitude or 999
			local timeStuck = tick() - gotoWalkState.stuckTimer

			if moved < 2 and timeStuck > 1.5 then
				-- Bloque : tenter de sauter
				if gotoWalkState.stuckJumps < 2 and tick() - gotoWalkState.lastJumpTime > 0.5 then
					humanoid.Jump = true
					gotoWalkState.stuckJumps = gotoWalkState.stuckJumps + 1
					gotoWalkState.lastJumpTime = tick()
					gotoWalkState.stuckTimer = tick()
				else
					-- Trop de sauts echoues : recalculer le chemin
					local newPath = computePathTo(gotoWalkState.target or wp)
					if #newPath > 0 then
						gotoWalkState.path = newPath
						gotoWalkState.currentWaypointIdx = 1
						gotoWalkState.stuckJumps = 0
						gotoWalkState.stuckTimer = tick()
						gotoWalkState.stuckPos = rootPart.Position
						humanoid:MoveTo(newPath[1])
						visualizeWaypoints(newPath)
					end
				end
			elseif moved >= 2 then
				-- Bouge normalement : reset stuck timer
				gotoWalkState.stuckTimer = tick()
				gotoWalkState.stuckPos = rootPart.Position
				gotoWalkState.stuckJumps = 0
			end

			-- Auto-jump si le waypoint est significativement plus haut
			local heightDiff = wp.Y - rootPart.Position.Y
			if heightDiff > 3 and tick() - gotoWalkState.lastJumpTime > 0.5 then
				humanoid.Jump = true
				gotoWalkState.lastJumpTime = tick()
			end

			-- Relancer MoveTo periodiquement pour eviter que le humanoid s'arrete
			if tick() - (gotoWalkState.lastMoveTo or 0) > 0.2 then
				humanoid:MoveTo(wp)
				gotoWalkState.lastMoveTo = tick()
			end
		end)
	else
		-- Stop the loop
		if gotoWalkState.followConnection then
			gotoWalkState.followConnection:Disconnect()
			gotoWalkState.followConnection = nil
		end
	end
end

local gotoWalkSwitch = createSwitch(moveScroll, "Go to Walk (click sol)", 0, function(on)
	gotoWalkState.enabled = on
	if on then
		gotoWalkState.active = true
		-- Indicateur flottant a lecran
		if not gotoWalkState.indicator then
			local ind = Instance.new("TextLabel")
			ind.Size = UDim2.new(0, 140, 0, 28)
			ind.Position = UDim2.new(0, 15, 0, 15)
			ind.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
			ind.BackgroundTransparency = 0.2
			ind.Text = "GOTO WALK ACTIF"
			ind.Font = Enum.Font.GothamBold
			ind.TextSize = 11
			ind.TextColor3 = Color3.new(1, 1, 1)
			ind.BorderSizePixel = 0
			ind.ZIndex = 999
			ind.Parent = screenGui
			createCorner(ind, 6)
			gotoWalkState.indicator = ind
		end
	else
		gotoWalkState.active = false
		manageFollowLoop(false)
		clearWalkVisuals()
		if gotoWalkState.indicator then
			gotoWalkState.indicator:Destroy()
			gotoWalkState.indicator = nil
		end
		-- Stopper le mode AFK aussi
		gotoWalkState.afkMode = false
		-- Garder target et path pour pouvoir reprendre
	end
end)

-- Mode AFK : auto-walk vers des points aleatoires + chat avec les gens
local function startAfkMode()
	gotoWalkState.afkMode = true
	if not gotoWalkState.enabled then
		gotoWalkSwitch.set(true)
	end
	
	local function pickRandomTarget()
		updateCharacter()
		if not rootPart then return nil end
		local origin = rootPart.Position
		-- Choisir un point aleatoire dans un rayon de 50-200 studs
		local angle = math.random() * math.pi * 2
		local dist = math.random(50, 200)
		local target = origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		-- Raycast vers le bas pour trouver le sol
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local hit = Workspace:Raycast(target + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)
		if hit then
			return hit.Position + Vector3.new(0, 2, 0)
		end
		return target
	end
	
	local function chatWithNearbyPlayers()
		updateCharacter()
		if not rootPart then return end
		local myPos = rootPart.Position
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local theirPos = plr.Character.HumanoidRootPart.Position
				local d = (myPos - theirPos).Magnitude
				if d < 20 and tick() - gotoWalkState.afkLastChat > 10 then
					gotoWalkState.afkLastChat = tick()
					local greetings = {"salut", "yo", "hello", "ca va", "hey", "bonjour", "cc"}
					local msg = greetings[math.random(1, #greetings)]
					pcall(function()
						local chatEvent = Workspace:FindFirstChild("SayMessageRequest")
						if chatEvent then
							chatEvent:FireServer(msg)
						end
					end)
					break
				end
			end
		end
	end
	
	-- Indicateur AFK
	if not gotoWalkState.afkIndicator then
		local afkInd = Instance.new("TextLabel")
		afkInd.Size = UDim2.new(0, 140, 0, 28)
		afkInd.Position = UDim2.new(0, 15, 0, 48)
		afkInd.BackgroundColor3 = Color3.fromRGB(140, 60, 160)
		afkInd.BackgroundTransparency = 0.2
		afkInd.Text = "MODE AFK ACTIF"
		afkInd.Font = Enum.Font.GothamBold
		afkInd.TextSize = 11
		afkInd.TextColor3 = Color3.new(1, 1, 1)
		afkInd.BorderSizePixel = 0
		afkInd.ZIndex = 999
		afkInd.Parent = screenGui
		createCorner(afkInd, 6)
		gotoWalkState.afkIndicator = afkInd
	end
	
	gotoWalkState.afkConnection = RunService.Heartbeat:Connect(function()
		if not gotoWalkState.afkMode then return end
		updateCharacter()
		if not rootPart or not humanoid then return end
		
		-- Si on est arrive ou qu'il n'y a pas de chemin, en choisir un nouveau
		if not gotoWalkState.path or #gotoWalkState.path == 0 or gotoWalkState.currentWaypointIdx > #gotoWalkState.path then
			task.wait(1)
			local newTarget = pickRandomTarget()
			if newTarget then
				local newPath = computePathTo(newTarget)
				if #newPath > 0 then
					gotoWalkState.target = newTarget
					gotoWalkState.path = newPath
					gotoWalkState.currentWaypointIdx = 1
					manageFollowLoop(true)
					visualizeWaypoints(newPath)
				end
			end
		end
		
		-- Chat avec les gens proches de temps en temps
		chatWithNearbyPlayers()
	end)
end

local function stopAfkMode()
	gotoWalkState.afkMode = false
	if gotoWalkState.afkConnection then
		gotoWalkState.afkConnection:Disconnect()
		gotoWalkState.afkConnection = nil
	end
	if gotoWalkState.afkIndicator then
		gotoWalkState.afkIndicator:Destroy()
		gotoWalkState.afkIndicator = nil
	end
end

local afkSwitch = createSwitch(moveScroll, "Mode AFK (auto-walk)", 0, function(on)
	if on then
		startAfkMode()
	else
		stopAfkMode()
	end
end)

local infiniteJumpSwitch = createSwitch(moveScroll, "Saut infini", 0, function(on)
	jumpState.infinite = on
end)

local function refreshNoClipSwitch()
	noclipSwitch.set(false)
end

local walkSlider = createSlider(moveScroll, "Vitesse marche", 0, 1, 250, 16, function(v)
	walkSpeedState.value = math.floor(v)
	updateCharacter()
	if humanoid then humanoid.WalkSpeed = walkSpeedState.value end
end, Color3.fromRGB(255, 100, 100))

local walkResetBtn = createButton(moveScroll, "Reset vitesse", 0, Color3.fromRGB(80, 80, 90), function()
	walkSpeedState.value = 16
	walkSlider.set(16)
	updateCharacter()
	if humanoid then humanoid.WalkSpeed = 16 end
end)

local platformLabel = Instance.new("TextLabel")
platformLabel.Size = UDim2.new(1, -16, 0, 30)
platformLabel.BackgroundTransparency = 1
platformLabel.Text = "Plateforme: F10 (+=monter -=descendre)"
platformLabel.Font = Enum.Font.Gotham
platformLabel.TextSize = 11
platformLabel.TextWrapped = true
platformLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
platformLabel.TextXAlignment = Enum.TextXAlignment.Left
platformLabel.Parent = moveScroll

-- Boutons F10 pour mobile (toggle + monter/descendre)
local platBtnRow = Instance.new("Frame")
platBtnRow.Size = UDim2.new(1, -16, 0, 36)
platBtnRow.BackgroundTransparency = 1
platBtnRow.Parent = moveScroll

local platToggleBtn = Instance.new("TextButton")
platToggleBtn.Size = UDim2.new(0.34, 0, 1, 0)
platToggleBtn.Position = UDim2.new(0, 0, 0, 0)
platToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
platToggleBtn.Text = "F10: ON"
platToggleBtn.Font = Enum.Font.GothamSemibold
platToggleBtn.TextSize = 12
platToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
platToggleBtn.BorderSizePixel = 0
platToggleBtn.Parent = platBtnRow
local pTCorner = Instance.new("UICorner")
pTCorner.CornerRadius = UDim.new(0, 6)
pTCorner.Parent = platToggleBtn

local platUpBtn = Instance.new("TextButton")
platUpBtn.Size = UDim2.new(0.31, 0, 1, 0)
platUpBtn.Position = UDim2.new(0.36, 0, 0, 0)
platUpBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
platUpBtn.Text = "+ Monter"
platUpBtn.Font = Enum.Font.GothamSemibold
platUpBtn.TextSize = 12
platUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
platUpBtn.BorderSizePixel = 0
platUpBtn.Parent = platBtnRow
local pUCorner = Instance.new("UICorner")
pUCorner.CornerRadius = UDim.new(0, 6)
pUCorner.Parent = platUpBtn

local platDownBtn = Instance.new("TextButton")
platDownBtn.Size = UDim2.new(0.31, 0, 1, 0)
platDownBtn.Position = UDim2.new(0.69, 0, 0, 0)
platDownBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
platDownBtn.Text = "- Descendre"
platDownBtn.Font = Enum.Font.GothamSemibold
platDownBtn.TextSize = 12
platDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
platDownBtn.BorderSizePixel = 0
platDownBtn.Parent = platBtnRow
local pDCorner = Instance.new("UICorner")
pDCorner.CornerRadius = UDim.new(0, 6)
pDCorner.Parent = platDownBtn

platToggleBtn.MouseButton1Click:Connect(function()
	_G._platformToggle = not _G._platformToggle
	if _G._platformToggle then
		platToggleBtn.Text = "F10: ON"
		platToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
	else
		platToggleBtn.Text = "F10: OFF"
		platToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	end
end)

platUpBtn.MouseButton1Click:Connect(function()
	_G._platformUp = true
	task.delay(0.1, function() _G._platformUp = false end)
end)

platDownBtn.MouseButton1Click:Connect(function()
	_G._platformDown = true
	task.delay(0.1, function() _G._platformDown = false end)
end)


-- ============= LOCAL (ZERO-G + TIME + GRAVITY) =============
local localState = {
	zeroGravity = false,
	normalGravity = Workspace.Gravity,
	customGravity = 196.2,
	timeOfDay = 12,
}

local zeroGSwitch = createSwitch(moveScroll, "Zero Gravite", 0, function(on)
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

-- Conteneur gravite personnalise (slider precis + input + reset)
local gravityContainer = Instance.new("Frame")
gravityContainer.Size = UDim2.new(1, -16, 0, 86)
gravityContainer.Position = UDim2.new(0, 8, 0, 56)
gravityContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
gravityContainer.BorderSizePixel = 0
gravityContainer.Parent = moveScroll
createCorner(gravityContainer, 10)
createStroke(gravityContainer, Color3.fromRGB(45, 45, 55), 1)

local gravityLabel = Instance.new("TextLabel")
gravityLabel.Size = UDim2.new(1, -10, 0, 18)
gravityLabel.Position = UDim2.new(0, 8, 0, 5)
gravityLabel.BackgroundTransparency = 1
gravityLabel.Text = "Gravite custom : 196.2"
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
	gravityLabel.Text = "Gravite custom : " .. v
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

local resetGravityBtn = createButton(moveScroll, "Reset gravite normale", 0, Color3.fromRGB(80, 80, 90), function()
	setGravityExact(196.2)
end)
resetGravityBtn.Size = UDim2.new(1, -16, 0, 30)
resetGravityBtn.Position = UDim2.new(0, 8, 0, 0)

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

-- ============= EXPORT ALL TO _G FOR P2 =============
_G._P1 = _G._P1 or {}
_G._P1["Players"] = Players
_G._P1["RunService"] = RunService
_G._P1["UserInputService"] = UserInputService
_G._P1["Workspace"] = Workspace
_G._P1["Lighting"] = Lighting
_G._P1["ReplicatedStorage"] = ReplicatedStorage
_G._P1["TweenService"] = TweenService
_G._P1["HttpService"] = HttpService
_G._P1["SoundService"] = SoundService
_G._P1["TextChatService"] = TextChatService
_G._P1["SETTINGS"] = SETTINGS
_G._P1["LocalPlayer"] = LocalPlayer
_G._P1["Mouse"] = Mouse
_G._P1["Camera"] = Camera
_G._P1["createCorner"] = createCorner
_G._P1["createStroke"] = createStroke
_G._P1["createButton"] = createButton
_G._P1["createSwitch"] = createSwitch
_G._P1["createSlider"] = createSlider
_G._P1["createTab"] = createTab
_G._P1["tween"] = tween
_G._P1["playSound"] = playSound
_G._P1["switchTab"] = switchTab
_G._P1["shutdownPanel"] = shutdownPanel
_G._P1["httpGet"] = httpGet
_G._P1["httpPost"] = httpPost
_G._P1["startFly"] = startFly
_G._P1["stopFly"] = stopFly
_G._P1["updateCharacter"] = updateCharacter
_G._P1["refreshESP"] = refreshESP
_G._P1["clearESP"] = clearESP
_G._P1["computePathTo"] = computePathTo
_G._P1["visualizeWaypoints"] = visualizeWaypoints
_G._P1["clearWalkVisuals"] = clearWalkVisuals
_G._P1["reparentChildrenToLocalScroll"] = reparentChildrenToLocalScroll
_G._P1["flyState"] = flyState
_G._P1["flySwitch"] = flySwitch
_G._P1["noclipState"] = noclipState
_G._P1["noclipSwitch"] = noclipSwitch
_G._P1["walkSpeedState"] = walkSpeedState
_G._P1["jumpState"] = jumpState
_G._P1["platformState"] = platformState
_G._P1["espState"] = espState
_G._P1["gotoWalkState"] = gotoWalkState
_G._P1["zeroGSwitch"] = zeroGSwitch
_G._P1["zeroGSwitch"] = zeroGSwitch
_G._P1["humanoid"] = humanoid
_G._P1["rootPart"] = rootPart
_G._P1["character"] = character
_G._P1["mainFrame"] = mainFrame
_G._P1["screenGui"] = screenGui
_G._P1["closeBtn"] = closeBtn
_G._P1["pages"] = pages
_G._P1["extraPage"] = extraPage
_G._P1["movePage"] = movePage
_G._P1["remotesPage"] = remotesPage
_G._P1["registryPage"] = registryPage
_G._P1["localPage"] = localPage
_G._P1["protectionsPage"] = protectionsPage
_G._P1["localScroll"] = localScroll
_G._P1["protectionsScroll"] = protectionsScroll
_G._P1["registryScroll"] = registryScroll
_G._P1["registryLayout"] = registryLayout
_G._P1["localState"] = localState
_G._P1["panelMemory"] = panelMemory
_G._P1["fullbrightSwitch"] = fullbrightSwitch
_G["Players"] = Players
_G["RunService"] = RunService
_G["UserInputService"] = UserInputService
_G["Workspace"] = Workspace
_G["Lighting"] = Lighting
_G["ReplicatedStorage"] = ReplicatedStorage
_G["TweenService"] = TweenService
_G["HttpService"] = HttpService
_G["SoundService"] = SoundService
_G["TextChatService"] = TextChatService
_G["LocalPlayer"] = LocalPlayer
_G["Mouse"] = Mouse
_G["Camera"] = Camera
_G["createCorner"] = createCorner
_G["createStroke"] = createStroke
_G["createButton"] = createButton
_G["createSwitch"] = createSwitch
_G["createSlider"] = createSlider
_G["createTab"] = createTab
_G["tween"] = tween
_G["playSound"] = playSound
_G["switchTab"] = switchTab
_G["shutdownPanel"] = shutdownPanel
_G["httpGet"] = httpGet
_G["httpPost"] = httpPost
_G["startFly"] = startFly
_G["stopFly"] = stopFly
_G["updateCharacter"] = updateCharacter
_G["refreshESP"] = refreshESP
_G["clearESP"] = clearESP
_G["computePathTo"] = computePathTo
_G["visualizeWaypoints"] = visualizeWaypoints
_G["clearWalkVisuals"] = clearWalkVisuals
_G["reparentChildrenToLocalScroll"] = reparentChildrenToLocalScroll
_G["flyState"] = flyState
_G["flySwitch"] = flySwitch
_G["noclipState"] = noclipState
_G["noclipSwitch"] = noclipSwitch
_G["walkSpeedState"] = walkSpeedState
_G["jumpState"] = jumpState
_G["platformState"] = platformState
_G["espState"] = espState
_G["gotoWalkState"] = gotoWalkState
_G["zeroGSwitch"] = zeroGSwitch
_G["zeroGSwitch"] = zeroGSwitch
_G["humanoid"] = humanoid
_G["rootPart"] = rootPart
_G["character"] = character
_G["mainFrame"] = mainFrame
_G["screenGui"] = screenGui
_G["closeBtn"] = closeBtn
_G["pages"] = pages
_G["extraPage"] = extraPage
_G["movePage"] = movePage
_G["remotesPage"] = remotesPage
_G["registryPage"] = registryPage
_G["localPage"] = localPage
_G["protectionsPage"] = protectionsPage
_G["localScroll"] = localScroll
_G["protectionsScroll"] = protectionsScroll
_G["registryScroll"] = registryScroll
_G["registryLayout"] = registryLayout
_G["localState"] = localState
_G["panelMemory"] = panelMemory
_G["fullbrightSwitch"] = fullbrightSwitch
_G["globalESPSwitch"] = globalESPSwitch
_G["gotoWalkSwitch"] = gotoWalkSwitch
_G["infiniteJumpSwitch"] = infiniteJumpSwitch

-- AUTO-LOAD PART 2 (split for Solara 200KB limit)
task.spawn(function()
    local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p2.lua&nocache=" .. tostring(tick())
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

-- AUTO-UPDATE CHECK (popup une seule fois par version distante, persiste entre reloads)
_G._agoraUpdateAvailable = false
_G._agoraUpdateVersion = nil
_G._agoraUpdateDismissed = false

-- Persistance du popup deja montre (UNE SEULE FOIS au total, pas a chaque MAJ)
local function _agoraReadShown()
	local ok, d = pcall(function() return readfile("agora_update_shown.txt") end)
	if ok and d and d == "1" then return true end
	return false
end
local function _agoraWriteShown()
	pcall(function() writefile("agora_update_shown.txt", "1") end)
end

-- Check version en arriere-plan
task.delay(8, function()
    while true do
        pcall(function()
            if not _G._agoraUpdating and not _G._agoraAU then
                _G._agoraAU = true
                local vurl = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_version.lua&nocache=" .. tostring(tick()) .. "&r=" .. tostring(math.random(100000, 999999))
                local ok, rv = pcall(function() return game:HttpGet(vurl, true) end)
                if ok and rv then
                    rv = rv:gsub('return "', ''):gsub('"', ''):gsub("%s", "")
                    local cv = (_G.CURRENT_VERSION or CURRENT_VERSION or "v0"):gsub("%s", "")
                    if rv ~= cv and rv ~= "" then
                        _G._agoraUpdateAvailable = true
                        _G._agoraUpdateVersion = rv
                        if _G._agoraUpdateIndicator then
                            pcall(function()
                                _G._agoraUpdateIndicator.Text = "  MAJ disponible: " .. rv
                                _G._agoraUpdateIndicator.Visible = true
                                _G._agoraUpdateBtn.Visible = true
                            end)
                        end
                        -- Pas de popup intrusif : l'indicateur Home + bouton MAJ suffisent (preference Emerick)
                    else
                        _G._agoraUpdateAvailable = false
                        _G._agoraUpdateVersion = nil
                        _G._agoraUpdateDismissed = false
                        _G._agoraPopupShown = false
                        if _G._agoraUpdateIndicator then
                            pcall(function()
                                _G._agoraUpdateIndicator.Visible = false
                                _G._agoraUpdateBtn.Visible = false
                            end)
                        end
                    end
                end
                _G._agoraAU = nil
            end
        end)
        task.wait(60)
    end
end)

-- Fonction de mise a jour manuelle
_G._agoraPerformUpdate = function()
    if not _G._agoraUpdateAvailable then return end
    _G._agoraUpdating = true
    _G._agoraSavedState = {}
    local switchesToSave = {
        {ref = _G.flySwitch, name = "fly"},
        {ref = _G.noclipSwitch, name = "noclip"},
        {ref = _G.globalESPSwitch, name = "globalESP"},
        {ref = _G.fullbrightSwitch, name = "fullbright"},
        {ref = _G.zeroGSwitch, name = "zeroG"},
        {ref = _G.hitboxSwitch, name = "hitbox"},
        {ref = _G.clickTPSwitch, name = "clickTP"},
        {ref = _G.gotoWalkSwitch, name = "gotoWalk"},
        {ref = _G.infiniteJumpSwitch, name = "infiniteJump"},
        {ref = _G.autoClickSwitch, name = "autoClick"},
        {ref = _G.aimbotSwitch, name = "aimbot"},
    }
    for _, s in ipairs(switchesToSave) do
        if s.ref and s.ref.get and s.ref.get() then
            _G._agoraSavedState[s.name] = true
        end
    end
    if _G.shutdownPanel then pcall(_G.shutdownPanel) end
    -- Detruire TOUTES les anciennes UI + loops avant de charger la nouvelle
    pcall(function()
        local okp, par = pcall(function() return game:GetService("CoreGui") end)
        if not okp or not par then par = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
        -- Detruire tous les ScreenGui Agora/Milan
        for _, g in ipairs(par:GetChildren()) do
            if g:IsA("ScreenGui") and (g.Name:match("Agora") or g.Name:match("Milan")) then
                g:Destroy()
            end
        end
        -- Detruire aussi les ScreenGui sans nom qui pourraient trainer
        for _, g in ipairs(par:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name == "ScreenGui" then
                g:Destroy()
            end
        end
    end)
    -- Detruire les BodyMovers sur le personnage
    pcall(function()
        local char = game:GetService("Players").LocalPlayer.Character
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BodyVelocity") or d:IsA("BodyGyro") or d:IsA("BodyAngularVelocity") or d:IsA("BodyForce") then
                    d:Destroy()
                end
            end
        end
    end)
    -- Reset flags pour que la nouvelle version parte propre
    _G._agoraAU = nil
    _G._agoraUpdateAvailable = false
    task.spawn(function()
        local aG = Instance.new("ScreenGui")
        aG.Name = "AgoraUpdAnim"
        aG.ResetOnSpawn = false
        aG.DisplayOrder = 99999
        local okp2, par2 = pcall(function() return game:GetService("CoreGui") end)
        if not okp2 or not par2 then par2 = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
        aG.Parent = par2
        local aF = Instance.new("Frame")
        aF.Size = UDim2.new(0, 320, 0, 80)
        aF.Position = UDim2.new(0.5, -160, 0.5, -40)
        aF.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
        aF.BorderSizePixel = 0
        aF.Parent = aG
        local aC = Instance.new("UICorner") aC.CornerRadius = UDim.new(0, 12) aC.Parent = aF
        local aS = Instance.new("UIStroke") aS.Color = Color3.fromRGB(100, 200, 255) aS.Thickness = 2 aS.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual aS.Parent = aF
        local aL = Instance.new("TextLabel")
        aL.Size = UDim2.new(1, 0, 1, 0)
        aL.BackgroundTransparency = 1
        aL.Text = "Mise a jour en cours..."
        aL.TextColor3 = Color3.fromRGB(100, 200, 255)
        aL.Font = Enum.Font.GothamBold
        aL.TextSize = 16
        aL.Parent = aF
        task.wait(1)
        aL.Text = "Redemarrage..."
        _G._agoraUpdating = nil
        task.wait(2)
        local rU = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p1.lua&nocache=" .. tostring(tick()) .. "&r=" .. tostring(math.random(100000, 999999))
        local okR, code2 = pcall(function() return game:HttpGet(rU, true) end)
        if okR and code2 and #code2 > 100 then
            aG:Destroy()
            local fn = loadstring(code2)
            if fn then pcall(fn) end
            task.delay(2, function()
                pcall(function()
                    if not _G._agoraSavedState then return end
                    local restoreMap = {
                        {name = "fly", ref = function() return _G.flySwitch end},
                        {name = "noclip", ref = function() return _G.noclipSwitch end},
                        {name = "globalESP", ref = function() return _G.globalESPSwitch end},
                        {name = "fullbright", ref = function() return _G.fullbrightSwitch end},
                        {name = "zeroG", ref = function() return _G.zeroGSwitch end},
                        {name = "hitbox", ref = function() return _G.hitboxSwitch end},
                        {name = "clickTP", ref = function() return _G.clickTPSwitch end},
                        {name = "gotoWalk", ref = function() return _G.gotoWalkSwitch end},
                        {name = "infiniteJump", ref = function() return _G.infiniteJumpSwitch end},
                        {name = "autoClick", ref = function() return _G.autoClickSwitch end},
                        {name = "aimbot", ref = function() return _G.aimbotSwitch end},
                    }
                    for _, r in ipairs(restoreMap) do
                        if _G._agoraSavedState[r.name] then
                            local sw = r.ref()
                            if sw and sw.set and (not sw.get or not sw.get()) then
                                sw.set(true)
                            end
                        end
                    end
                    _G._agoraSavedState = nil
                end)
            end)
        else
            aL.Text = "Erreur de chargement"
            task.wait(2) aG:Destroy()
        end
    end)
end
