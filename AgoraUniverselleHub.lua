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

-- Panel memory (session-only, pas de persistence cross-game)
local PanelMemory = {}
_G.PanelMemory = PanelMemory

-- ===== UTILITY FUNCTIONS =====
local function createCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function createStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(80, 80, 100)
	s.Thickness = thickness or 1
	s.Parent = parent
	return s
end

local function tween(obj, props, duration, callback)
	local ok, err = pcall(function()
		local t = TweenService:Create(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		t:Play()
		if callback then
			t.Completed:Connect(function()
				pcall(callback)
			end)
		end
	end)
	if not ok then
		warn("[AGORA] tween error: " .. tostring(err))
	end
end

local function playSound(id)
	task.spawn(function()
		pcall(function()
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. tostring(id)
			s.Volume = 0.5
			s.Parent = SoundService
			s:Play()
			task.delay(1, function() pcall(function() s:Destroy() end) end)
		end)
	end)
end

-- ===== SCREENGUI + MAINFRAME =====
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	warn("[AGORA] LocalPlayer not found")
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AgoraUniverselleHub"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 9999
pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not screenGui.Parent then
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Server Authority detection
_G.isServerAuthority = function()
	local ws = game:GetService("Workspace")
	local ok, am = pcall(function() return ws.AuthorityMode end)
	if ok and am == Enum.AuthorityMode.Server then return true end
	return false
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 480, 0, 520)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -260)
mainFrame.Visible = false  -- Sera révélé après l'intro
mainFrame.BackgroundTransparency = 1  -- v39.47: no flash, restored after intro
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 1
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(120, 120, 150), 1.2)

-- Safety net: force reveal after 8s
task.delay(8, function()
	pcall(function()
		if mainFrame and not mainFrame.Visible then
			mainFrame.Visible = true
			mainFrame.BackgroundTransparency = 0.35
			pcall(function() switchTab("Home") end)
		end
	end)
end)

mainFrame.Parent = screenGui

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
	title.Text = "AGORA"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 48
	title.TextColor3 = Color3.fromRGB(60, 180, 255)
	title.TextTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 102
	title.Parent = bootGui

	-- Sous-titre
	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(0.9, 0, 0, 24)
	subtitle.Position = UDim2.new(0.05, 0, 0.45, 40)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "UNIVERSELLE HUB"
	subtitle.Font = Enum.Font.GothamSemibold
	subtitle.TextSize = 16
	subtitle.TextColor3 = Color3.fromRGB(120, 120, 150)
	subtitle.TextTransparency = 1
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.ZIndex = 102
	subtitle.Parent = bootGui

	-- Tampon "UNIVERSELLE" en gros doré penché
	local uniTag = Instance.new("TextLabel")
	uniTag.Size = UDim2.new(1.2, 0, 0, 120)
	uniTag.Position = UDim2.new(-0.1, 0, 0.4, -20)
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
	stampTop.Size = UDim2.new(1.2, 0, 0, 3)
	stampTop.Position = UDim2.new(-0.1, 0, 0.4, -28)
	stampTop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stampTop.BorderSizePixel = 0
	stampTop.BackgroundTransparency = 1
	stampTop.ZIndex = 104
	stampTop.Parent = bootGui

	local stampBottom = Instance.new("Frame")
	stampBottom.Size = UDim2.new(1.2, 0, 0, 3)
	stampBottom.Position = UDim2.new(-0.1, 0, 0.4, 95)
	stampBottom.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stampBottom.BorderSizePixel = 0
	stampBottom.BackgroundTransparency = 1
	stampBottom.ZIndex = 104
	stampBottom.Parent = bootGui

	-- Animation
	task.spawn(function()
		local ok, err = pcall(function()
			-- Fade in backdrop
			_tween(backdrop, {BackgroundTransparency = 0}, 0.3)
			task.wait(0.2)

			-- Fade in title
			_tween(title, {TextTransparency = 0}, 0.5)
			task.wait(0.12)

			-- Fade in subtitle
			_tween(subtitle, {TextTransparency = 0}, 0.25)
			task.wait(0.3)

			-- BOUM: flash blanc + tampon UNIVERSELLE
			local flash = Instance.new("Frame")
			flash.Size = UDim2.new(1, 0, 1, 0)
			flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			flash.BackgroundTransparency = 1
			flash.BorderSizePixel = 0
			flash.ZIndex = 200
			flash.Parent = bootGui
			_tween(flash, {BackgroundTransparency = 0}, 0.05)
			task.wait(0.08)
			_tween(flash, {BackgroundTransparency = 1}, 0.3)

			-- Show tampon
			_tween(uniTag, {TextTransparency = 0}, 0.2)
			_tween(stampTop, {BackgroundTransparency = 0}, 0.2)
			_tween(stampBottom, {BackgroundTransparency = 0}, 0.2)
			task.wait(0.5)

			-- Fade out everything
			_tween(backdrop, {BackgroundTransparency = 1}, 0.4)
			_tween(title, {TextTransparency = 1}, 0.3)
			_tween(subtitle, {TextTransparency = 1}, 0.3)
			_tween(uniTag, {TextTransparency = 1}, 0.3)
			_tween(stampTop, {BackgroundTransparency = 1}, 0.3)
			_tween(stampBottom, {BackgroundTransparency = 1}, 0.3)
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

-- Logo dans la topBar
local logoBtn = Instance.new("ImageButton")
logoBtn.Size = UDim2.new(0, 28, 0, 28)
logoBtn.Position = UDim2.new(0, 6, 0, 5)
logoBtn.BackgroundTransparency = 1
logoBtn.Image = "rbxassetid://73314612607499"
logoBtn.Parent = topBar
logoBtn.ZIndex = 3

-- Titre dans la topBar
local topTitle = Instance.new("TextLabel")
topTitle.Size = UDim2.new(0, 120, 0, 28)
topTitle.Position = UDim2.new(0, 38, 0, 5)
topTitle.BackgroundTransparency = 1
topTitle.Text = "Agora Hub"
topTitle.Font = Enum.Font.GothamBold
topTitle.TextSize = 14
topTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
topTitle.TextXAlignment = Enum.TextXAlignment.Left
topTitle.Parent = topBar
topTitle.ZIndex = 3

-- Badge UNIVERSELLE
local badgeUni = Instance.new("TextLabel")
badgeUni.Size = UDim2.new(0, 70, 0, 18)
badgeUni.Position = UDim2.new(0, 160, 0, 10)
badgeUni.BackgroundColor3 = Color3.fromRGB(80, 60, 140)
badgeUni.BackgroundTransparency = 0.3
badgeUni.Text = "UNIVERSELLE"
badgeUni.Font = Enum.Font.GothamBold
badgeUni.TextSize = 9
badgeUni.TextColor3 = Color3.fromRGB(200, 180, 255)
badgeUni.Parent = topBar
badgeUni.ZIndex = 3
createCorner(badgeUni, 4)

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = topBar
closeBtn.ZIndex = 3
createCorner(closeBtn, 14)

-- Minimize button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -66, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
minimizeBtn.Text = "—"
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = topBar
minimizeBtn.ZIndex = 3
createCorner(minimizeBtn, 14)

-- ===== SHUTDOWN PANEL =====
local function shutdownPanel()
	-- Stop all features
	pcall(function() if _G.stopFly then _G.stopFly() end end)
	pcall(function() if _G.stopNoclip then _G.stopNoclip() end end)
	pcall(function() if _G.stopESP then _G.stopESP() end end)
	pcall(function() if _G.stopAimbot then _G.stopAimbot() end end)
	pcall(function() if _G.stopAutoClick then _G.stopAutoClick() end end)
	pcall(function() if _G.stopFullbright then _G.stopFullbright() end end)
	-- Destroy GUI
	pcall(function() if screenGui then screenGui:Destroy() end end)
end
_G.shutdownPanel = shutdownPanel

-- Close button handler
closeBtn.MouseButton1Click:Connect(function()
	playSound(6042053626)
	shutdownPanel()
end)

-- Minimize/restore
local isMinimized = false
local floatBtn = nil

local function minimizePanel()
	isMinimized = true
	tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.2)
	topBar.Visible = false
	
	-- Create floating restore button
	floatBtn = Instance.new("ImageButton")
	floatBtn.Size = UDim2.new(0, 56, 0, 56)
	floatBtn.Position = UDim2.new(0, 10, 0.5, -28)
	floatBtn.BackgroundTransparency = 1
	floatBtn.Image = "rbxassetid://73314612607499"
	floatBtn.ZIndex = 9999
	floatBtn.Parent = screenGui
	createCorner(floatBtn, 14)
	
	local pressStart = 0
	floatBtn.MouseButton1Down:Connect(function()
		pressStart = tick()
	end)
	floatBtn.MouseButton1Up:Connect(function()
		if tick() - pressStart > 2 then
			-- Long press = destroy
			shutdownPanel()
		else
			-- Short press = restore
			restorePanel()
		end
	end)
end

local function restorePanel()
	isMinimized = false
	tween(mainFrame, {Size = UDim2.new(0, 480, 0, 520), BackgroundTransparency = 0.35}, 0.2)
	topBar.Visible = true
	if floatBtn then
		pcall(function() floatBtn:Destroy() end)
		floatBtn = nil
	end
end

minimizeBtn.MouseButton1Click:Connect(function()
	playSound(6042053626)
	if isMinimized then
		restorePanel()
	else
		minimizePanel()
	end
end)

-- ===== TAB SYSTEM =====
local tabHolder = Instance.new("Frame")
tabHolder.Size = UDim2.new(1, 0, 0, 32)
tabHolder.Position = UDim2.new(0, 0, 0, 44)
tabHolder.BackgroundTransparency = 1
tabHolder.Parent = mainFrame
tabHolder.ZIndex = 2

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 1, -82)
contentFrame.Position = UDim2.new(0, 0, 0, 82)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame
contentFrame.ZIndex = 1

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
homePage = createTab("Home")

-- ============= HOME PAGE CONTENT =============
;(function()
	local _homePage = homePage
	local _mainFrame = mainFrame
	local _tween = tween
	local _createCorner = createCorner
	local _createStroke = createStroke
	local _playSound = playSound
	local _LocalPlayer = LocalPlayer
	local _Players = Players
	local _HttpService = HttpService
	local _TweenService = TweenService
	local _UserInputService = UserInputService
	local _Workspace = Workspace
	local _Lighting = Lighting
	local _ReplicatedStorage = ReplicatedStorage
	local _SoundService = SoundService
	local _RunService = RunService
	local _TextChatService = TextChatService

	-- Version
	local CURRENT_VERSION = "v39.47"

	-- Changelog
	local changelogEntries = {
		"v39.47 - Home tab restauré (onglet manquant)",
		"v39.46 - Corrections stabilité",
		"v39.45 - Fichier unique standalone",
		"v39.42 - Server Authority bypass fly",
		"v39.30 - Compteurs live + switch maître protections",
		"v39.22 - Fix exports _G mal placés",
		"v39.13 - Go to Walk pathfinding",
		"v38.93 - Split 2 parties p1/p2",
	}

	-- httpGet multi-fallback
	local function httpGet(url)
		local ok, result
		ok, result = pcall(function() return game:HttpGet(url) end)
		if ok and result and #result > 10 then return result end
		ok, result = pcall(function() return _HttpService:GetAsync(url) end)
		if ok and result and #result > 10 then return result end
		ok, result = pcall(function()
			local r = _HttpService:RequestAsync({Url=url, Method="GET"})
			if r and r.Success and r.Body then return r.Body end
		end)
		if ok and result and #result > 10 then return result end
		ok, result = pcall(function() return syn and syn.request({Url=url, Method="GET"}).Body end)
		if ok and result and #result > 10 then return result end
		return nil
	end
	_G.httpGet = httpGet

	-- writefile/readfile wrappers
	local function writefile(name, content)
		return pcall(function()
			if writefile then writefile(name, content) end
		end)
	end
	local function readfile(name)
		local ok, result = pcall(function()
			if readfile then return readfile(name) end
		end)
		if ok and result then return result end
		return nil
	end

	-- Langue
	local langCode = "FR"
	local savedLang = readfile("agora_lang.txt")
	if savedLang and #savedLang == 2 then langCode = savedLang end

	local translations = {
		FR = {Home="Accueil", Joueurs="Joueurs", Move="Mouvement", Extra="Extra", Remotes="Remotes", Registry="Registre", Local="Local", Protections="Protections", discord="Rejoindre le Discord", langue="Langue", nouveautes="Nouveautés", utilisateurs="Utilisateurs", enLigne="En ligne", credits="Agora Hub [UNIVERSELLE]"},
		EN = {Home="Home", Joueurs="Players", Move="Movement", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", discord="Join Discord", langue="Language", nouveautes="Changelog", utilisateurs="Users", enLigne="Online", credits="Agora Hub [UNIVERSAL]"},
		ES = {Home="Inicio", Joueurs="Jugadores", Move="Movimiento", Extra="Extra", Remotes="Remotos", Registry="Registro", Local="Local", Protections="Protecciones", discord="Unirse a Discord", langue="Idioma", nouveautes="Novedades", utilisateurs="Usuarios", enLigne="En línea", credits="Agora Hub [UNIVERSAL]"},
		DE = {Home="Start", Joueurs="Spieler", Move="Bewegung", Extra="Extra", Remotes="Remotes", Registry="Register", Local="Lokal", Protections="Schutz", discord="Discord beitreten", langue="Sprache", nouveautes="Neuigkeiten", utilisateurs="Benutzer", enLigne="Online", credits="Agora Hub [UNIVERSELL]"},
		IT = {Home="Home", Joueurs="Giocatori", Move="Movimento", Extra="Extra", Remotes="Remoti", Registry="Registro", Local="Locale", Protections="Protezioni", discord="Unisciti a Discord", langue="Lingua", nouveautes="Novità", utilisateurs="Utenti", enLigne="Online", credits="Agora Hub [UNIVERSALE]"},
		PT = {Home="Início", Joueurs="Jogadores", Move="Movimento", Extra="Extra", Remotes="Remotos", Registry="Registro", Local="Local", Protections="Proteções", discord="Entrar no Discord", langue="Idioma", nouveautes="Novidades", utilisateurs="Usuários", enLigne="Online", credits="Agora Hub [UNIVERSAL]"},
		RU = {Home="Главная", Joueurs="Игроки", Move="Движение", Extra="Экстра", Remotes="Удалённые", Registry="Реестр", Local="Локально", Protections="Защита", discord="Discord", langue="Язык", nouveautes="Новости", utilisateurs="Пользователи", enLigne="Онлайн", credits="Agora Hub [УНИВЕРСАЛЬНЫЙ]"},
		JP = {Home="ホーム", Joueurs="プレイヤー", Move="移動", Extra="エクストラ", Remotes="リモート", Registry="レジストリ", Local="ローカル", Protections="保護", discord="Discordに参加", langue="言語", nouveautes="更新情報", utilisateurs="ユーザー", enLigne="オンライン", credits="Agora Hub [ユニバーサル]"},
		ZH = {Home="主页", Joueurs="玩家", Move="移动", Extra="额外", Remotes="远程", Registry="注册表", Local="本地", Protections="保护", discord="加入Discord", langue="语言", nouveautes="更新", utilisateurs="用户", enLigne="在线", credits="Agora Hub [通用]"},
		KR = {Home="홈", Joueurs="플레이어", Move="이동", Extra="추가", Remotes="원격", Registry="레지스트리", Local="로컬", Protections="보호", discord="Discord 참여", langue="언어", nouveautes="업데이트", utilisateurs="사용자", enLigne="온라인", credits="Agora Hub [유니버설]"},
		AR = {Home="الرئيسية", Joueurs="اللاعبين", Move="الحركة", Extra="إضافي", Remotes="عن بعد", Registry="السجل", Local="محلي", Protections="الحماية", discord="انضم لديسكورد", langue="اللغة", nouveautes="التحديثات", utilisateurs="المستخدمين", enLigne="متصل", credits="Agora Hub [عالمي]"},
		NL = {Home="Home", Joueurs="Spelers", Move="Beweging", Extra="Extra", Remotes="Remotes", Registry="Register", Local="Lokaal", Protections="Bescherming", discord="Discord joinen", langue="Taal", nouveautes="Updates", utilisateurs="Gebruikers", enLigne="Online", credits="Agora Hub [UNIVERSEEL]"},
		PL = {Home="Start", Joueurs="Gracze", Move="Ruch", Extra="Extra", Remotes="Zdalne", Registry="Rejestr", Local="Lokalne", Protections="Ochrona", discord="Dołącz do Discord", langue="Język", nouveautes="Aktualności", utilisateurs="Użytkownicy", enLigne="Online", credits="Agora Hub [UNIWERSALNY]"},
		TR = {Home="Ana Sayfa", Joueurs="Oyuncular", Move="Hareket", Extra="Ekstra", Remotes="Uzaktan", Registry="Kayıt", Local="Yerel", Protections="Koruma", discord="Discord'a Katıl", langue="Dil", nouveautes="Güncellemeler", utilisateurs="Kullanıcılar", enLigne="Çevrimiçi", credits="Agora Hub [EVRENSEL]"},
	}

	local function applyLanguage(code)
		langCode = code
		writefile("agora_lang.txt", code)
		local t = translations[code] or translations["FR"]
		pcall(function() if titleLabel then titleLabel.Text = t.Home end end)
		pcall(function() if nouveautesLabel then nouveautesLabel.Text = t.nouveautes end end)
		pcall(function() if discordLabel then discordLabel.Text = t.discord end end)
		pcall(function() if langueLabel then langueLabel.Text = t.langue end end)
		pcall(function() if creditsLabel then creditsLabel.Text = t.credits end end)
		pcall(function() if totalLabel then totalLabel.Text = t.utilisateurs .. ": ..." end end)
		pcall(function() if onlineLabel then onlineLabel.Text = t.enLigne .. ": ..." end end)
		pcall(function()
			for name, btn in pairs(tabButtons) do
				if t[name] then btn.Text = t[name] end
			end
		end)
	end
	_G.applyLanguage = applyLanguage

	-- Stats live
	local agoraStats = {totalLaunches = 0, onlineUsers = 0}
	_G._agoraStats = agoraStats

	local function fetchStats()
		task.spawn(function()
			local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?action=launch&user=" .. (_LocalPlayer and _LocalPlayer.Name or "Inconnu") .. "&uid=" .. (_LocalPlayer and tostring(_LocalPlayer.UserId) or "0") .. "&_=" .. math.random(100000,999999)
			local data = httpGet(url)
			if data then
				local ok, json = pcall(function() return _HttpService:JSONDecode(data) end)
				if ok and json then
					agoraStats.totalLaunches = json.total_launches or 0
					agoraStats.onlineUsers = json.online_users or 0
				end
			end
		end)
	end
	fetchStats()

	task.spawn(function()
		while _homePage and _homePage.Parent do
			task.wait(60)
			fetchStats()
		end
	end)

	-- === BUILD HOME UI ===
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 28)
	titleLabel.Position = UDim2.new(0, 10, 0, 15)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "AGORA"
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = Color3.fromRGB(60, 180, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = _homePage

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, -20, 0, 18)
	subtitleLabel.Position = UDim2.new(0, 10, 0, 42)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "UNIVERSELLE HUB"
	subtitleLabel.Font = Enum.Font.GothamSemibold
	subtitleLabel.TextSize = 12
	subtitleLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = _homePage

	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, -20, 0, 1)
	sep.Position = UDim2.new(0, 10, 0, 65)
	sep.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	sep.BorderSizePixel = 0
	sep.Parent = _homePage

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(1, -20, 0, 16)
	versionLabel.Position = UDim2.new(0, 10, 0, 72)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = CURRENT_VERSION
	versionLabel.Font = Enum.Font.GothamBold
	versionLabel.TextSize = 11
	versionLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.Parent = _homePage

	local nouveautesLabel = Instance.new("TextLabel")
	nouveautesLabel.Size = UDim2.new(1, -20, 0, 16)
	nouveautesLabel.Position = UDim2.new(0, 10, 0, 92)
	nouveautesLabel.BackgroundTransparency = 1
	nouveautesLabel.Text = "Nouveautés"
	nouveautesLabel.Font = Enum.Font.GothamBold
	nouveautesLabel.TextSize = 11
	nouveautesLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	nouveautesLabel.TextXAlignment = Enum.TextXAlignment.Left
	nouveautesLabel.Parent = _homePage

	local changelogScroll = Instance.new("ScrollingFrame")
	changelogScroll.Size = UDim2.new(1, -20, 0, 120)
	changelogScroll.Position = UDim2.new(0, 10, 0, 110)
	changelogScroll.BackgroundTransparency = 1
	changelogScroll.BorderSizePixel = 0
	changelogScroll.ScrollBarThickness = 4
	changelogScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
	changelogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	changelogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	changelogScroll.Parent = _homePage

	local changelogLayout = Instance.new("UIListLayout")
	changelogLayout.Padding = UDim.new(0, 3)
	changelogLayout.SortOrder = Enum.SortOrder.LayoutOrder
	changelogLayout.Parent = changelogScroll

	for i, entry in ipairs(changelogEntries) do
		local entryLabel = Instance.new("TextLabel")
		entryLabel.Size = UDim2.new(1, -10, 0, 14)
		entryLabel.BackgroundTransparency = 1
		entryLabel.Text = entry
		entryLabel.Font = Enum.Font.Gotham
		entryLabel.TextSize = 10
		entryLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
		entryLabel.TextXAlignment = Enum.TextXAlignment.Left
		entryLabel.LayoutOrder = i
		entryLabel.Parent = changelogScroll
	end

	local discordLabel = Instance.new("TextLabel")
	discordLabel.Size = UDim2.new(1, -20, 0, 16)
	discordLabel.Position = UDim2.new(0, 10, 0, 238)
	discordLabel.BackgroundTransparency = 1
	discordLabel.Text = "Rejoindre le Discord"
	discordLabel.Font = Enum.Font.GothamBold
	discordLabel.TextSize = 11
	discordLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	discordLabel.TextXAlignment = Enum.TextXAlignment.Left
	discordLabel.Parent = _homePage

	local discordBtn = Instance.new("TextButton")
	discordBtn.Size = UDim2.new(1, -20, 0, 32)
	discordBtn.Position = UDim2.new(0, 10, 0, 256)
	discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
	discordBtn.Text = "https://discord.gg/fVw2rzAMb"
	discordBtn.Font = Enum.Font.GothamSemibold
	discordBtn.TextSize = 11
	discordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	discordBtn.BorderSizePixel = 0
	discordBtn.AutoButtonColor = false
	discordBtn.Parent = _homePage
	_createCorner(discordBtn, 8)
	discordBtn.MouseButton1Click:Connect(function()
		_playSound(6042053626)
		pcall(function() setclipboard("https://discord.gg/fVw2rzAMb") end)
	end)
	discordBtn.MouseEnter:Connect(function() _tween(discordBtn, {BackgroundColor3 = Color3.fromRGB(100, 113, 255)}, 0.1) end)
	discordBtn.MouseLeave:Connect(function() _tween(discordBtn, {BackgroundColor3 = Color3.fromRGB(88, 101, 242)}, 0.1) end)

	local langueLabel = Instance.new("TextLabel")
	langueLabel.Size = UDim2.new(1, -20, 0, 16)
	langueLabel.Position = UDim2.new(0, 10, 0, 295)
	langueLabel.BackgroundTransparency = 1
	langueLabel.Text = "Langue"
	langueLabel.Font = Enum.Font.GothamBold
	langueLabel.TextSize = 11
	langueLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	langueLabel.TextXAlignment = Enum.TextXAlignment.Left
	langueLabel.Parent = _homePage

	local langBtn = Instance.new("TextButton")
	langBtn.Size = UDim2.new(1, -20, 0, 32)
	langBtn.Position = UDim2.new(0, 10, 0, 313)
	langBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	langBtn.Text = "🌍 " .. (langCode == "FR" and "Français" or langCode)
	langBtn.Font = Enum.Font.GothamSemibold
	langBtn.TextSize = 11
	langBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
	langBtn.BorderSizePixel = 0
	langBtn.AutoButtonColor = false
	langBtn.Parent = _homePage
	_createCorner(langBtn, 8)
	_createStroke(langBtn, Color3.fromRGB(80, 80, 100), 0.8)

	local langPopup = nil
	local langCodes = {"FR", "EN", "ES", "DE", "IT", "PT", "RU", "JP", "ZH", "KR", "AR", "NL", "PL", "TR"}
	local langNames = {FR="Français", EN="English", ES="Español", DE="Deutsch", IT="Italiano", PT="Português", RU="Русский", JP="日本語", ZH="中文", KR="한국어", AR="العربية", NL="Nederlands", PL="Polski", TR="Türkçe"}
	local langFlags = {FR="🇫🇷", EN="🇬🇧", ES="🇪🇸", DE="🇩🇪", IT="🇮🇹", PT="🇵🇹", RU="🇷🇺", JP="🇯🇵", ZH="🇨🇳", KR="🇰🇷", AR="🇸🇦", NL="🇳🇱", PL="🇵🇱", TR="🇹🇷"}

	langBtn.MouseButton1Click:Connect(function()
		_playSound(6042053626)
		if langPopup and langPopup.Parent then
			langPopup:Destroy()
			langPopup = nil
			return
		end
		langPopup = Instance.new("Frame")
		langPopup.Size = UDim2.new(0, 200, 0, 280)
		langPopup.Position = UDim2.new(0.5, -100, 0.5, -140)
		langPopup.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
		langPopup.BorderSizePixel = 0
		langPopup.ZIndex = 100
		langPopup.Parent = _mainFrame
		_createCorner(langPopup, 12)
		_createStroke(langPopup, Color3.fromRGB(80, 80, 100), 1)

		local popupTitle = Instance.new("TextLabel")
		popupTitle.Size = UDim2.new(1, 0, 0, 24)
		popupTitle.BackgroundTransparency = 1
		popupTitle.Text = "Langue / Language"
		popupTitle.Font = Enum.Font.GothamBold
		popupTitle.TextSize = 13
		popupTitle.TextColor3 = Color3.fromRGB(200, 200, 210)
		popupTitle.ZIndex = 101
		popupTitle.Parent = langPopup

		local popupScroll = Instance.new("ScrollingFrame")
		popupScroll.Size = UDim2.new(1, -4, 1, -28)
		popupScroll.Position = UDim2.new(0, 2, 0, 26)
		popupScroll.BackgroundTransparency = 1
		popupScroll.BorderSizePixel = 0
		popupScroll.ScrollBarThickness = 3
		popupScroll.CanvasSize = UDim2.new(0, 0, 0, #langCodes * 36)
		popupScroll.ZIndex = 101
		popupScroll.Parent = langPopup

		for i, code in ipairs(langCodes) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -6, 0, 32)
			btn.Position = UDim2.new(0, 3, 0, (i-1) * 36)
			btn.BackgroundColor3 = code == langCode and Color3.fromRGB(55, 90, 180) or Color3.fromRGB(35, 35, 45)
			btn.Text = langFlags[code] .. " " .. langNames[code]
			btn.Font = Enum.Font.GothamSemibold
			btn.TextSize = 12
			btn.TextColor3 = Color3.fromRGB(220, 220, 230)
			btn.BorderSizePixel = 0
			btn.AutoButtonColor = false
			btn.ZIndex = 102
			btn.Parent = popupScroll
			_createCorner(btn, 6)
			btn.MouseButton1Click:Connect(function()
				applyLanguage(code)
				langBtn.Text = "🌍 " .. langNames[code]
				pcall(function() langPopup:Destroy() end)
				langPopup = nil
			end)
		end
	end)

	local totalLabel = Instance.new("TextLabel")
	totalLabel.Size = UDim2.new(1, -20, 0, 16)
	totalLabel.Position = UDim2.new(0, 10, 0, 352)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Text = "Utilisateurs: ..."
	totalLabel.Font = Enum.Font.Gotham
	totalLabel.TextSize = 10
	totalLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.Parent = _homePage

	local onlineLabel = Instance.new("TextLabel")
	onlineLabel.Size = UDim2.new(1, -20, 0, 16)
	onlineLabel.Position = UDim2.new(0, 10, 0, 370)
	onlineLabel.BackgroundTransparency = 1
	onlineLabel.Text = "En ligne: ..."
	onlineLabel.Font = Enum.Font.Gotham
	onlineLabel.TextSize = 10
	onlineLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
	onlineLabel.TextXAlignment = Enum.TextXAlignment.Left
	onlineLabel.Parent = _homePage

	task.spawn(function()
		while _homePage and _homePage.Parent do
			task.wait(5)
			pcall(function()
				totalLabel.Text = "Utilisateurs: " .. tostring(agoraStats.totalLaunches)
				onlineLabel.Text = "En ligne: " .. tostring(agoraStats.onlineUsers)
			end)
		end
	end)

	local creditsLabel = Instance.new("TextLabel")
	creditsLabel.Size = UDim2.new(1, -20, 0, 16)
	creditsLabel.Position = UDim2.new(0, 10, 0, 395)
	creditsLabel.BackgroundTransparency = 1
	creditsLabel.Text = "Agora Hub [UNIVERSELLE]"
	creditsLabel.Font = Enum.Font.Gotham
	creditsLabel.TextSize = 9
	creditsLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
	creditsLabel.TextXAlignment = Enum.TextXAlignment.Center
	creditsLabel.Parent = _homePage

	applyLanguage(langCode)
end)()