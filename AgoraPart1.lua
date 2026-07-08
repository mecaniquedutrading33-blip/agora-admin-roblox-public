
local SETTINGS = {
	SpiderSpeed = 16,
	SpiderHoverDistance = 2.6,
	SpiderNetworkCompensation = 0.8,
	SpiderJP=60,
	SpiderJumpCooldown = 0.5,
	SpiderTransitionSpeed = 15
}

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
	local ok, argGame = pcall(function() return ... end)
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

local function _buildPanel()
if not game then
	warn("[AGORA] game est nil — exécuteur incompatible ou loadstring mal formé")
	return
end

local Pls = game:GetService("Pls")
local RS = game:GetService("RS")
local UIS = game:GetService("UIS")
local TextChatService = game:GetService("TextChatService")
local WS = game:GetService("WS")
local Lt = game:GetService("Lt")
local RSv = game:GetService("RSv")
local TSv = game:GetService("TSv")
local HS = game:GetService("HS")
local SoundService = game:GetService("SoundService")

_G._resolveCanChat = function(target, callback)
	task.spawn(function()
		local result, src = nil, "non vérifiable"
		local uid = (typeof(target) == "Instance" and target:IsA("Player") and target.UserId) or tonumber(target)

		if uid and LP then
			local rf = RSv:FFC("AgoraCanChatRF")
			if rf and rf:IsA("RemoteFunction") then
				local ok, r = pcall(function() return rf:IS(uid) end)
				if ok and r ~= nil then
					result, src = r, "CanTalkWithMe"
				end
			end
		end

		if result == nil and uid then
			local ok, r = pcall(function() return TextChatService:CanUserChatAsync(uid) end)
			if ok then result, src = r, "ChatEnabled" end
		end

		if result == nil and typeof(target) == "Instance" and target:IsA("Player") then
			local ok, r = pcall(function() return target.CanChat end)
			if ok then result, src = r, "Player.CanChat" end
		end
		if result == nil and typeof(target) == "Instance" and target:IsA("Player") and LP then
			local ok, r = pcall(function() return target:CanChatWith(LP.UserId) end)
			if ok then result, src = r, "CanChatWith" end
		end
		if result == nil and typeof(target) == "Instance" and target:IsA("Player") then
			local ok, r = pcall(function()
				local chans = TextChatService:FFC("TextChannels")
				if not chans then return nil end
				local general = chans:FFC("RBXGeneral")
				if not general then return nil end
				for _, sp in ipairs(general:GC()) do
					if sp:IsA("TextSource") and tostring(sp.UserId) == tostring(target.UserId) then
						return true
					end
				end
				return false
			end)
			if ok then result, src = r, "TextChannels" end
		end
		if result == nil and uid and _G._chatSeenPls[uid] then
			local since = tick() - _G._chatSeenPls[uid]
			if since <= 600 then
				result, src = true, "Vu parler"
			else
				_G._chatSeenPls[uid] = nil
			end
		end
		pcall(function() callback(result, src) end)
	end)
end

_G._chatSeenPls = {}
task.spawn(function()
	local ok, svc = pcall(function() return game:GetService("TextChatService") end)
	if not ok or not svc then return end
	local ok2 = pcall(function()
		svc.MessageReceived:Cn(function(msg)
			if not (msg and msg.TextSource and msg.TextSource.UserId) then return end
			local uid = tonumber(msg.TextSource.UserId)
			if uid then
				_G._chatSeenPls[uid] = tick()
			end
		end)
	end)
	if not ok2 then
		pcall(function()
			local default = game:GetService("RSv"):WFC("DefaultChatSystemChatEvents", 3)
			if default then
				local ev = default:FFC("OnMessageDoneFiltering")
				if ev then
					ev.OnClientEvent:Cn(function(data)
						local uid = tonumber(data and data.SpeakerUserId)
						if uid then _G._chatSeenPls[uid] = tick() end
					end)
				end
			end
		end)
	end
end)

local function playSound(id, vol)
	if not id then return end
	pcall(function()
		local s = I.n("Sound")
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume = vol or 0.4
		s.Pa=SoundService
		if s.IsLoaded then
			s:Play()
		else
			s.Loaded:Cn(function()
				s:Play()
			end)
		end
		local len = (s.TimeLength and s.TimeLength > 0) and s.TimeLength or 3
		task.delay(len + 0.2, function()
			pcall(function() s:D() end)
		end)
	end)
end

local function httpGet(url)
	local ok, r = pcall(function() return game:HGet(url) end)
	if ok and r and r ~= "" then return r end
	ok, r = pcall(function() return game:HGet(url, true) end)
	if ok and r and r ~= "" then return r end
	ok, r = pcall(function()
		local resp = HS:RA({
			Url = url,
			Method = "GET",
			Headers = {["Content-Type"] = "application/json"}
		})
		if resp and resp.Success and resp.Body then return resp.Body end
	end)
	if ok and r and r ~= "" then return r end
	ok, r = pcall(function() return HS:GA(url) end)
	if ok and r and r ~= "" then return r end
	ok, r = pcall(function() return HS:GA(url, true) end)
	if ok and r and r ~= "" then return r end
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		ok, r = pcall(function() return req({Url=url, Method="GET"}).Body end)
		if ok and r and r ~= "" then return r end
	end
	if req then
		ok, r = pcall(function() return req({
			Url = url,
			Method = "GET",
			Headers = {["User-Agent"] = "Roblox/WinInet", ["Accept"] = "*/*"}
		}).Body end)
		if ok and r and r ~= "" then return r end
	end
	ok, r = pcall(function() return game:HPost(url, "", true, "application/json") end)
	if ok and r and r ~= "" then return r end
	return nil
end

local function httpPost(url, body)
	local ok, r = pcall(function() return game:HGet(url, true, body) end)
	if ok and r and r ~= "" then return r end
	ok, r = pcall(function() return HS:PA(url, body) end)
	if ok and r and r ~= "" then return r end
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		ok, r = pcall(function() return req({Url=url, Method="POST", Body=body, Headers={["Content-Type"]="application/json"}}).Body end)
		if ok and r and r ~= "" then return r end
	end
	return nil
end

local LP = Pls.LP
local Camera = WS.CurrentCamera
local Mouse = LP:GetMouse()

if not _G.PanelMemory then
	_G.PanelMemory = { dontAskRestore = false, lastEchoPlayerN=nil }
end
local panelMemory = _G.PanelMemory

local character, humanoid, rootPart
local function updateCharacter()
	character = LP.Character
	if character then
		humanoid = character:FFCOC("Humanoid")
		rootPt=character:FFC("HumanoidRootPart")
	else
		humanoid, rootPt=nil, nil
	end
end

updateCharacter()
LP.CharacterAdded:Cn(function(char)
	char:WFC("HumanoidRootPart")
	char:WFC("Humanoid")
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
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		return "Mobile"
	elseif UIS.GamepadEnabled then
		return "Console"
	else
		return "PC"
	end
end

local function createCorner(parent, radius)
	local c = I.n("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Pa=parent
	return c
end

local function createStroke(parent, color, thickness)
	local s = I.n("UIStroke")
	s.C=color or C3(60, 60, 60)
	s.Thickness = thickness or 1
	s.Pa=parent
	return s
end

local function tween(obj, props, duration)
	if not obj or not obj.Parent then return end
	pcall(function()
		TSv:Create(obj, TweenInfo.new(duration or 0.2, E.EasingStyle.Quad, E.EasingDirection.Out), props):Play()
	end)
end

local screenGui = I.n("ScreenGui")
screenGui.N="MilanEmerickPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = E.ZIndexBehavior.Sibling
screenGui.Pa=LP:WFC("PlayerGui", 10)

local mainFrame = I.n("Frame")
mainFrame.N="MainFrame"
mainFrame.S=U2(0, 460, 0, 520)
mainFrame.P=U2(0.5, -230, 0.5, -260)
mainFrame.V=false  -- Sera révélé après l'intro
task.delay(0, function()
	local function clampFrame()
		local abs = mainFrame.AbsoluteSize
		local scr = screenGui.AbsoluteSize
		local x = math.clamp(mainFrame.AbsolutePosition.X, 0, math.max(0, scr.X - abs.X))
		local y = math.clamp(mainFrame.AbsolutePosition.Y, 0, math.max(0, scr.Y - abs.Y))
		mainFrame.P=U2(0, x, 0, y)
	end
	clampFrame()
	task.wait(0.1)
	clampFrame()
end)
mainFrame.BC3=C3(18, 18, 22)
mainFrame.BTr=0.35
mainFrame.BSP=0
mainFrame.Pa=screenGui
mainFrame.CD=true
mainFrame.ZIndex = 1
createCorner(mainFrame, 14)
createStroke(mainFrame, C3(120, 120, 150), 1.2)

;(function()
	local _mainFrame = mainFrame
	local _screenGui = screenGui
	local _LP = LP
	local _TSv = TSv
	local _tween = tween
	local _createCorner = createCorner

	local bootGui = I.n("ScreenGui")
	bootGui.N="MilanEmerickIntro"
	bootGui.ResetOnSpawn = false
	bootGui.DisplayOrder = 99999
	bootGui.IgnoreGuiInset = true
	bootGui.Pa=_LP:WFC("PlayerGui")

	local backdrop = I.n("Frame")
	backdrop.N="Backdrop"
	backdrop.S=U2(1, 0, 1, 0)
	backdrop.BC3=C3(0, 0, 0)
	backdrop.BSP=0
	backdrop.ZIndex = 100
	backdrop.Pa=bootGui

	local vignette = I.n("ImageLabel")
	vignette.N="Vignette"
	vignette.S=U2(1.4, 0, 1.4, 0)
	vignette.P=U2(-0.2, 0, -0.2, 0)
	vignette.BTr=1
	vignette.Im="rbxassetid://9638773891"
	vignette.IC3=C3(120, 90, 30)
	vignette.IT=0.6
	vignette.ZIndex = 101
	vignette.Pa=bootGui

	local title = I.n("TextLabel")
	title.N="Title"
	title.S=U2(0.9, 0, 0, 50)
	title.P=U2(0.05, 0, 0.45, -10)
	title.BTr=1
	title.F=E.F.GothamBlack
	title.T="Agora Hub"
	title.TSz=38
	title.TC3=C3(220, 220, 240)
	title.TT=1
	title.TextStrokeTr=0.5
	title.TextStrokeColor3 = C3(40, 40, 50)
	title.ZIndex = 102
	title.Pa=bootGui

	local subtitle = I.n("TextLabel")
	subtitle.N="Subtitle"
	subtitle.S=U2(0.9, 0, 0, 20)
	subtitle.P=U2(0.05, 0, 0.45, 36)
	subtitle.BTr=1
	subtitle.F=E.F.Gotham
	subtitle.T="by Milan & Emerick"
	subtitle.TSz=13
	subtitle.TC3=C3(150, 150, 170)
	subtitle.TT=1
	subtitle.ZIndex = 102
	subtitle.Pa=bootGui

	local uniTag = I.n("TextLabel")
	uniTag.N="UniTag"
	uniTag.S=U2(1.1, 0, 0, 130)
	uniTag.P=U2(-0.05, 0, 0.4, 0)
	uniTag.AnchorPoint = Vector2.new(0, 0)
	uniTag.BTr=1
	uniTag.Rotation = -8
	uniTag.F=E.F.GothamBlack
	uniTag.T="UNIVERSELLE"
	uniTag.TSc=false
	uniTag.TSz=110
	uniTag.TC3=C3(255, 220, 120)
	uniTag.TextStrokeTr=0.2
	uniTag.TextStrokeColor3 = C3(120, 80, 0)
	uniTag.TT=1
	uniTag.ZIndex = 103
	uniTag.Pa=bootGui

	local stampTop = I.n("Frame")
	stampTop.N="StampTop"
	stampTop.S=U2(0.8, 0, 0, 2)
	stampTop.P=U2(0.1, 0, 0.41, 0)
	stampTop.BC3=C3(0, 0, 0)
	stampTop.BSP=0
	stampTop.BTr=1
	stampTop.ZIndex = 103
	stampTop.Pa=bootGui

	local stampBot = I.n("Frame")
	stampBot.N="StampBot"
	stampBot.S=U2(0.8, 0, 0, 2)
	stampBot.P=U2(0.1, 0, 0.68, 0)
	stampBot.BC3=C3(0, 0, 0)
	stampBot.BSP=0
	stampBot.BTr=1
	stampBot.ZIndex = 103
	stampBot.Pa=bootGui

	local flash = I.n("Frame")
	flash.N="Flash"
	flash.S=U2(1, 0, 1, 0)
	flash.BC3=C3(255, 255, 255)
	flash.BTr=1
	flash.BSP=0
	flash.ZIndex = 110
	flash.Pa=bootGui

	task.spawn(function()
		local ok, err = pcall(function()
			playSound(9114850423, 0.5)
			backdrop.BTr=0

			task.wait(0.3)
			_tween(title, {TT=0}, 0.5)
			_tween(subtitle, {TT=0}, 0.5)
			playSound(6042053626, 0.25)

			task.wait(1.0)

			flash.BTr=0
			uniTag.TT=0
			stampTop.BTr=0
			stampBot.BTr=0

			uniTag.S=U2(0, 0, 0, 0)
			uniTag.P=U2(0.5, 0, 0.5, 0)
			uniTag.AnchorPoint = Vector2.new(0.5, 0.5)
			uniTag.Rotation = 4  -- rotation d'entrée (corrigée à -8 à la fin)
			playSound(4590662766, 0.85)  -- boom impact
			_tween(uniTag, {S=U2(1.2, 0, 0, 140), Rotation = -10}, 0.12, E.EasingStyle.Back, E.EasingDirection.Out)
			_tween(flash, {BTr=1}, 0.25)
			task.wait(0.12)
			_tween(uniTag, {S=U2(1.1, 0, 0, 130), Rotation = -8}, 0.25, E.EasingStyle.Quad, E.EasingDirection.Out)

			task.wait(1.2)

			_tween(title, {TT=1}, 0.3)
			_tween(subtitle, {TT=1}, 0.3)
			_tween(uniTag, {TT=1, Rotation = -12}, 0.4)
			_tween(stampTop, {BTr=1}, 0.3)
			_tween(stampBot, {BTr=1}, 0.3)
			_tween(vignette, {IT=1}, 0.3)
			task.wait(0.3)
			_tween(backdrop, {BTr=1}, 0.4)
			task.wait(0.5)
		end)

		if not ok then
			warn("[MILAN] Intro crash: " .. tostring(err))
		end

		pcall(function() if bootGui and bootGui.Parent then bootGui:D() end end)
		pcall(function()
			_mainFrame.V=true
		end)
	end)
end)()

local topBar = I.n("Frame")
topBar.S=U2(1, 0, 0, 38)
topBar.BC3=C3(28, 28, 35)
topBar.BTr=0.45
topBar.BSP=0
topBar.Pa=mainFrame
topBar.ZIndex = 2
createCorner(topBar, 14)
createStroke(topBar, C3(80, 80, 100), 0.8)

;(function()
	local _topBar = topBar
	local _createCorner = createCorner
	local _createStroke = createStroke

	local titleLogo = I.n("ImageLabel")
	titleLogo.N="TitleLogo"
	titleLogo.S=U2(0, 22, 0, 22)
	titleLogo.P=U2(0, 8, 0.5, 0)
	titleLogo.AnchorPoint = Vector2.new(0, 0.5)
	titleLogo.BTr=1
	titleLogo.Im="rbxassetid://73314612607499"
	titleLogo.Pa=_topBar

	local uniBadge = I.n("TextLabel")
	uniBadge.N="UniBadge"
	uniBadge.S=U2(0, 90, 0, 18)
	uniBadge.P=U2(0, 134, 0.5, 0)
	uniBadge.AnchorPoint = Vector2.new(0, 0.5)
	uniBadge.BC3=C3(60, 30, 110)
	uniBadge.BTr=0.15
	uniBadge.BSP=0
	uniBadge.F=E.F.GothamBlack
	uniBadge.T="UNIVERSELLE"
	uniBadge.TSz=9
	uniBadge.TC3=C3(220, 180, 255)
	uniBadge.Rotation = -8
	uniBadge.ZIndex = 5
	uniBadge.Pa=_topBar
	_createCorner(uniBadge, 4)
	local badgeStroke = I.n("UIStroke")
	badgeStroke.C=C3(150, 100, 220)
	badgeStroke.Thickness = 1
	badgeStroke.Pa=uniBadge
end)()

local titleLabel = I.n("TextLabel")
titleLabel.S=U2(1, -110, 1, 0)
titleLabel.P=U2(0, 36, 0, 0)
titleLabel.BTr=1
titleLabel.T="Agora Hub"
titleLabel.F=E.F.GothamBold
titleLabel.TSz=14
titleLabel.TC3=C3(230, 230, 230)
titleLabel.TXA=E.TX.Left
titleLabel.Pa=topBar

local function addGlow(frame)
	local glow = I.n("ImageLabel")
	glow.N="Glow"
	glow.S=U2(1, 60, 1, 60)
	glow.P=U2(0, -30, 0, -30)
	glow.BTr=1
	glow.Im="rbxassetid://9638773891"
	glow.IC3=C3(80, 120, 255)
	glow.IT=0.85
	glow.ZIndex = -1
	glow.Pa=frame
	return glow
end

local mainGlow = addGlow(mainFrame)

task.spawn(function()
	while mainGlow and mainGlow.Parent do
		for i = 0.82, 0.92, 0.003 do
			mainGlow.IT=i
			task.wait(0.03)
		end
		for i = 0.92, 0.82, -0.003 do
			mainGlow.IT=i
			task.wait(0.03)
		end
	end
end)
local closeBtn = I.n("TextButton")
closeBtn.S=U2(0, 28, 0, 28)
closeBtn.P=U2(1, -34, 0, 5)
closeBtn.BC3=C3(220, 60, 60)
closeBtn.T=""
closeBtn.ABC=false
closeBtn.BSP=0
closeBtn.Pa=topBar
createCorner(closeBtn, 8)

local minimizeBtn = I.n("TextButton")
minimizeBtn.N="MinimizeBtn"
minimizeBtn.S=U2(0, 28, 0, 28)
minimizeBtn.P=U2(1, -68, 0, 5)
minimizeBtn.BC3=C3(28, 28, 42)
minimizeBtn.T="—"
minimizeBtn.F=E.F.GothamBold
minimizeBtn.TSz=18
minimizeBtn.TC3=C3(200, 200, 220)
minimizeBtn.ABC=false
minimizeBtn.BSP=0
minimizeBtn.Pa=topBar
createCorner(minimizeBtn, 8)

local function makeIcon(btn, txt)
	local l = I.n("TextLabel")
	l.S=U2(1, 0, 1, 0)
	l.BTr=1
	l.T=txt
	l.F=E.F.GothamBold
	l.TSz=18
	l.TC3=Color3.new(1, 1, 1)
	l.Pa=btn
end

makeIcon(closeBtn, "×")

local function createButton(parent, text, yPos, color, callback)
	local btn = I.n("TextButton")
	btn.S=U2(1, -20, 0, 34)
	btn.P=U2(0, 10, 0, yPos)
	btn.BC3=color or C3(45, 75, 160)
	btn.T=text
	btn.F=E.F.GothamSemibold
	btn.TSz=13
	btn.TC3=Color3.new(1, 1, 1)
	btn.BSP=0
	btn.ABC=false
	btn.Pa=parent
	createCorner(btn, 8)
	btn.MouseEnter:Cn(function() tween(btn, {BC3=color and color:Lerp(Color3.new(1,1,1), 0.15) or C3(60, 95, 200)}, 0.1) end)
	btn.MouseLeave:Cn(function() tween(btn, {BC3=color or C3(45, 75, 160)}, 0.1) end)
	btn.MouseButton1Click:Cn(function()
		playSound(6042053626, 0.22)
		if callback then callback() end
	end)
	return btn
end

local tabBar = I.n("Frame")
tabBar.S=U2(1, -20, 0, 34)
tabBar.P=U2(0, 10, 0, 44)
tabBar.BC3=C3(28, 28, 35)
tabBar.BSP=0
tabBar.Pa=mainFrame
createCorner(tabBar, 10)

local tabHolder = I.n("Frame")
tabHolder.S=U2(1, -8, 1, -8)
tabHolder.P=U2(0, 4, 0, 4)
tabHolder.BTr=1
tabHolder.Pa=tabBar

local tabLayout = I.n("UIListLayout")
tabLayout.FillDirection = E.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.HorizontalAlignment = E.HorizontalAlignment.Center
tabLayout.SortOrder = E.SortOrder.LayoutOrder
tabLayout.Pa=tabHolder

local contentFrame = I.n("Frame")
contentFrame.S=U2(1, -20, 1, -122)
contentFrame.P=U2(0, 10, 0, 82)
contentFrame.BTr=1
contentFrame.Pa=mainFrame

local pages = {}
local tabButtons = {}
local activeTab = "Joueurs"

local function switchTab(name)
	activeTab = name
	for n, page in pairs(pages) do
		page.V=(n == name)
		if n == name then
			tween(page, {BTr=1}, 0)
		end
	end
	for n, btn in pairs(tabButtons) do
		local active = (n == name)
		tween(btn, {BC3=active and C3(55, 90, 180) or C3(40, 40, 50)}, 0.15)
		btn.TC3=active and Color3.new(1, 1, 1) or C3(160, 160, 160)
	end
end

local function createTab(name)
	local btn = I.n("TextButton")
	btn.S=U2(0.115, -2, 1, 0)
		btn.BC3=C3(40, 40, 50)
		btn.T=name
		btn.F=E.F.GothamSemibold
		btn.TSc=true
		btn.TC3=C3(160, 160, 160)
		btn.BSP=0
		btn.ABC=false
	btn.Pa=tabHolder
	createCorner(btn, 6)
	btn.MouseButton1Click:Cn(function() switchTab(name) end)
	btn.MouseEnter:Cn(function() if activeTab ~= name then tween(btn, {BC3=C3(50, 50, 65)}, 0.1) end end)
	btn.MouseLeave:Cn(function() if activeTab ~= name then tween(btn, {BC3=C3(40, 40, 50)}, 0.1) end end)
	local page = I.n("Frame")
	page.S=U2(1, 0, 1, 0)
	page.BTr=1
	page.V=false
	page.Pa=contentFrame
	pages[name] = page
	tabButtons[name] = btn
	return page
end

;(function()
	local homePage = createTab("Home")

	local bgFrame = I.n("Frame")
	bgFrame.S=U2(1, 0, 1, 0)
	bgFrame.BC3=C3(18, 18, 26)
	bgFrame.BSP=0
	bgFrame.Pa=homePage
	createCorner(bgFrame, 10)

	local title = I.n("TextLabel")
	title.S=U2(1, -20, 0, 36)
	title.P=U2(0, 10, 0, 15)
	title.BTr=1
	title.T="AGORA"
	title.F=E.F.GothamBlack
	title.TSz=32
	title.TC3=C3(130, 150, 255)
	title.Pa=bgFrame

	local subtitle = I.n("TextLabel")
	subtitle.S=U2(1, -20, 0, 20)
	subtitle.P=U2(0, 10, 0, 48)
	subtitle.BTr=1
	subtitle.T="Universelle Hub"
	subtitle.F=E.F.Gotham
	subtitle.TSz=16
	subtitle.TC3=C3(100, 100, 130)
	subtitle.Pa=bgFrame

	local sep1 = I.n("Frame")
	sep1.S=U2(0.8, 0, 0, 1)
	sep1.P=U2(0.1, 0, 0, 76)
	sep1.BC3=C3(50, 50, 65)
	sep1.BSP=0
	sep1.Pa=bgFrame

	local versionLabel = I.n("TextLabel")
	versionLabel.S=U2(1, -20, 0, 18)
	versionLabel.P=U2(0, 10, 0, 82)
	versionLabel.BTr=1
	versionLabel.T="v39.15"
	versionLabel.F=E.F.GothamSemibold
	versionLabel.TSz=12
	versionLabel.TC3=C3(100, 220, 120)
	versionLabel.TXA=E.TX.Center
	versionLabel.Pa=bgFrame

	local changelogBox = I.n("Frame")
	changelogBox.S=U2(1, -30, 0, 125)
	changelogBox.P=U2(0, 15, 0, 105)
	changelogBox.BC3=C3(14, 14, 20)
	changelogBox.BSP=0
	changelogBox.Pa=bgFrame
	createCorner(changelogBox, 8)

	local changelogTitle = I.n("TextLabel")
	changelogTitle.S=U2(1, -10, 0, 20)
	changelogTitle.P=U2(0, 8, 0, 6)
	changelogTitle.BTr=1
	changelogTitle.T="Nouveautes"
	changelogTitle.F=E.F.GothamBold
	changelogTitle.TSz=13
	changelogTitle.TC3=C3(140, 160, 255)
	changelogTitle.TXA=E.TX.Left
	changelogTitle.Pa=changelogBox

	local changelogScroll = I.n("ScrollingFrame")
	changelogScroll.S=U2(1, -10, 1, -30)
	changelogScroll.P=U2(0, 5, 0, 28)
	changelogScroll.BTr=1
	changelogScroll.BSP=0
	changelogScroll.SBT=3
	changelogScroll.ScrollBarIC3=C3(60, 60, 80)
	changelogScroll.AutomaticCanvasS=E.AutomaticSize.Y
	changelogScroll.CanvasS=U2(0, 0, 0, 200)
	changelogScroll.Pa=changelogBox

	local changelogLayout = I.n("UIListLayout")
	changelogLayout.SortOrder = E.SortOrder.LayoutOrder
	changelogLayout.Padding = UDim.new(0, 3)
	changelogLayout.Pa=changelogScroll

	local changelogEntries = {
		"v38.97 — Tri remotes + traduction langue",
		"+ Remotes interceptes tries en haut de la liste automatiquement",
		"+ Auto-refresh de la liste remotes toutes les 5s",
		"+ Detection amelioree (SG, tous les joueurs, dedup)",
		"+ Traduction des onglets et labels dans 14 langues",
		"+ Changement de langue fonctionne maintenant",
	}

	for i, entry in ipairs(changelogEntries) do
		local line = I.n("TextLabel")
		line.S=U2(1, 0, 0, 16)
		line.BTr=1
		line.T=entry
		line.F=(i == 1) and E.F.GothamSemibold or E.F.Gotham
		line.TSz=(i == 1) and 12 or 11
		line.TC3=(i == 1) and C3(100, 220, 120) or C3(150, 150, 165)
		line.TXA=E.TX.Left
		line.LO=i
		line.Pa=changelogScroll
	end

	local discordBtn = I.n("TextButton")
	discordBtn.S=U2(0.7, 0, 0, 32)
	discordBtn.P=U2(0.15, 0, 0, 238)
	discordBtn.BC3=C3(88, 101, 242)
	discordBtn.T="Rejoindre le Discord"
	discordBtn.F=E.F.GothamBold
	discordBtn.TSz=14
	discordBtn.TC3=Color3.new(1, 1, 1)
	discordBtn.BSP=0
	discordBtn.ABC=true
	discordBtn.Pa=bgFrame
	createCorner(discordBtn, 8)

	local copyLabel = I.n("TextLabel")
	copyLabel.S=U2(1, 0, 0, 16)
	copyLabel.P=U2(0, 0, 1, 3)
	copyLabel.BTr=1
	copyLabel.T=""
	copyLabel.F=E.F.Gotham
	copyLabel.TSz=10
	copyLabel.TC3=C3(100, 220, 120)
	copyLabel.Pa=bgFrame

	discordBtn.MouseButton1Click:Cn(function()
		pcall(function()
			local link = "https://discord.gg/fVw2rzAMb"
			local ok = pcall(function() setclipboard(link) end)
			if ok then
				copyLabel.T="Lien copie dans le presse-papiers!"
			else
				ok = pcall(function() toclipboard(link) end)
				if ok then
					copyLabel.T="Lien copie dans le presse-papiers!"
				else
					copyLabel.T="Lien: " .. link
				end
			end
			playSound(6042053626, 0.3)
		end)
		task.delay(5, function()
			pcall(function() copyLabel.T="" end)
		end)
	end)
	discordBtn.MouseEnter:Cn(function() tween(discordBtn, {BC3=C3(100, 115, 255)}, 0.15) end)
	discordBtn.MouseLeave:Cn(function() tween(discordBtn, {BC3=C3(88, 101, 242)}, 0.15) end)

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

	local langBtn = I.n("TextButton")
	langBtn.S=U2(0.7, 0, 0, 34)
	langBtn.P=U2(0.15, 0, 0, 275)
	langBtn.BC3=C3(30, 30, 42)
	langBtn.T="🌍 Langue"
	langBtn.F=E.F.GothamSemibold
	langBtn.TSz=14
	langBtn.TC3=C3(200, 210, 255)
	langBtn.BSP=0
	langBtn.ABC=true
	langBtn.Pa=bgFrame
	createCorner(langBtn, 8)

	local langMenu = I.n("Frame")
	langMenu.S=U2(0, 200, 0, 280)
	langMenu.P=U2(0.5, -100, 0.5, -140)
	langMenu.BC3=C3(20, 20, 28)
	langMenu.BSP=0
	langMenu.V=false
	langMenu.ZIndex = 100
	langMenu.Pa=bgFrame
	createCorner(langMenu, 10)

	local langMenuTitle = I.n("TextLabel")
	langMenuTitle.S=U2(1, -10, 0, 24)
	langMenuTitle.P=U2(0, 10, 0, 8)
	langMenuTitle.BTr=1
	langMenuTitle.T="Choisir la langue"
	langMenuTitle.F=E.F.GothamBold
	langMenuTitle.TSz=14
	langMenuTitle.TC3=C3(140, 160, 255)
	langMenuTitle.TXA=E.TX.Center
	langMenuTitle.ZIndex = 101
	langMenuTitle.Pa=langMenu

	local langMenuScroll = I.n("ScrollingFrame")
	langMenuScroll.S=U2(1, -10, 1, -40)
	langMenuScroll.P=U2(0, 5, 0, 34)
	langMenuScroll.BTr=1
	langMenuScroll.BSP=0
	langMenuScroll.SBT=3
	langMenuScroll.AutomaticCanvasS=E.AutomaticSize.Y
	langMenuScroll.CanvasS=U2(0, 0, 0, 200)
	langMenuScroll.ZIndex = 101
	langMenuScroll.Pa=langMenu

	local langMenuLayout = I.n("UIListLayout")
	langMenuLayout.SortOrder = E.SortOrder.LayoutOrder
	langMenuLayout.Padding = UDim.new(0, 4)
	langMenuLayout.Pa=langMenuScroll

	local currentLangN="Français"
	for _, l in ipairs(languages) do
		if l.code == selectedLang then currentLangN=l.name break end
	end
	langBtn.T="🌍 " .. currentLangName

	for _, lang in ipairs(languages) do
		local lBtn = I.n("TextButton")
		lBtn.S=U2(1, 0, 0, 30)
		lBtn.BC3=(lang.code == selectedLang) and C3(55, 90, 180) or C3(30, 30, 40)
		lBtn.T=lang.flag .. "  " .. lang.name
		lBtn.F=E.F.Gotham
		lBtn.TSz=12
		lBtn.TC3=Color3.new(1, 1, 1)
		lBtn.BSP=0
		lBtn.LO=_
		lBtn.ZIndex = 101
		lBtn.Pa=langMenuScroll
		createCorner(lBtn, 6)

		lBtn.MouseButton1Click:Cn(function()
			selectedLang = lang.code
			saveLang(lang.code)
			langBtn.T="🌍 " .. lang.name
			if _G._agoraApplyLang then _G._agoraApplyLang(lang.code) end
			for _, child in ipairs(langMenuScroll:GC()) do
				if child:IsA("TextButton") then
					child.BC3=C3(30, 30, 40)
				end
			end
			lBtn.BC3=C3(55, 90, 180)
			playSound(6042053626, 0.2)
			task.wait(0.15)
			langMenu.V=false
		end)
	end

	local langCloseBtn = I.n("TextButton")
	langCloseBtn.S=U2(0, 24, 0, 24)
	langCloseBtn.P=U2(1, -28, 0, 4)
	langCloseBtn.BC3=C3(200, 60, 60)
	langCloseBtn.T="✕"
	langCloseBtn.F=E.F.GothamBold
	langCloseBtn.TSz=12
	langCloseBtn.TC3=Color3.new(1, 1, 1)
	langCloseBtn.BSP=0
	langCloseBtn.ZIndex = 102
	langCloseBtn.Pa=langMenu
	createCorner(langCloseBtn, 6)
	langCloseBtn.MouseButton1Click:Cn(function()
		langMenu.V=false
	end)

	langBtn.MouseButton1Click:Cn(function()
		langMenu.V=not langMenu.Visible
		playSound(6042053626, 0.2)
	end)

	local translations = {
		FR = { Home="Home", Joueurs="Joueurs", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", discord="Rejoindre le Discord", langue="Langue", nouveautes="Nouveautes", utilisateurs="Lancements", enLigne="En ligne", credits="Agora Universelle" },
		EN = { Home="Home", Joueurs="Pls", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", discord="Join Discord", langue="Language", nouveautes="What's New", utilisateurs="Launches", enLigne="Online", credits="Agora Universelle" },
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
			for name, btn in pairs(tabButtons) do
				if t[name] and btn then btn.T=t[name] end
			end
			if t.discord and discordBtn then discordBtn.T=t.discord end
			if t.langue and langBtn then langBtn.T="🌍 " .. (t.langue or "Langue") end
			if t.nouveautes and changelogTitle then changelogTitle.T=t.nouveautes end
			if t.utilisateurs and totalLabel then totalLabel.T=(t.utilisateurs or "Lancements") .. ": " .. tostring((_G._agoraStats and _G._agoraStats.totalLaunches) or 0) end
			if t.enLigne and onlineLabel then onlineLabel.T=(t.enLigne or "En ligne") .. ": " .. tostring((_G._agoraStats and _G._agoraStats.onlineUsers) or 0) end
			if t.credits and credits then credits.T=t.credits end
		end)
	end

	applyLanguage(selectedLang)

	_G._agoraApplyLang = applyLanguage

	_G._agoraStats = { totalLaunches = 0, onlineUsers = 0 }

	local statsBox = I.n("Frame")
	statsBox.S=U2(1, -30, 0, 50)
	statsBox.P=U2(0, 15, 0, 340)
	statsBox.BC3=C3(14, 14, 20)
	statsBox.BSP=0
	statsBox.Pa=bgFrame
	createCorner(statsBox, 8)

	local statsLayout = I.n("UIListLayout")
	statsLayout.FillDirection = E.FillDirection.Horizontal
	statsLayout.HorizontalAlignment = E.HorizontalAlignment.Center
	statsLayout.VerticalAlignment = E.VerticalAlignment.Center
	statsLayout.Padding = UDim.new(0.05, 0)
	statsLayout.Pa=statsBox

	local totalLabel = I.n("TextLabel")
	totalLabel.S=U2(0, 160, 0, 36)
	totalLabel.BTr=1
	totalLabel.F=E.F.GothamSemibold
	totalLabel.TSz=13
	totalLabel.TC3=C3(160, 180, 255)
	totalLabel.T="Lancements: 0"
	totalLabel.Pa=statsBox

	local onlineLabel = I.n("TextLabel")
	onlineLabel.S=U2(0, 160, 0, 36)
	onlineLabel.BTr=1
	onlineLabel.F=E.F.GothamSemibold
	onlineLabel.TSz=13
	onlineLabel.TC3=C3(100, 220, 120)
	onlineLabel.T="En ligne: 0"
	onlineLabel.Pa=statsBox

	task.spawn(function()
		local function updateStats()
			task.spawn(function()
				local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?action=launch&user=" .. HS:UrlEncode(LP.Name) .. "&uid=" .. tostring(LP.UserId)
				local resp = httpGet(url)
				if resp and resp ~= "" then
					local parsed = nil
					pcall(function() parsed = HS:JSD(resp) end)
					if parsed then
						_G._agoraStats.totalLaunches = tonumber(parsed.total_launches) or 0
						_G._agoraStats.onlineUsers = tonumber(parsed.online_users) or 0
						totalLabel.T="Lancements: " .. tostring(_G._agoraStats.totalLaunches)
						onlineLabel.T="En ligne: " .. tostring(_G._agoraStats.onlineUsers)
					end
				end
			end)
		end

		updateStats()

		while homePage and homePage.Parent do
			task.wait(60)
			updateStats()
		end
	end)

	local credits = I.n("TextLabel")
	credits.S=U2(1, -20, 0, 16)
	credits.P=U2(0, 10, 0, 400)
	credits.BTr=1
	credits.T="Agora Universelle"
	credits.F=E.F.Gotham
	credits.TSz=10
	credits.TC3=C3(80, 80, 100)
	credits.Pa=bgFrame
end)()

local playersPage = createTab("Joueurs")
local movePage = createTab("Move")
local extraPage = createTab("Extra")
local remotesPage = createTab("Remotes")
local registryPage = createTab("Registry")
local localPage = createTab("Local")
local protectionsPage = createTab("Protections")

local function _initRegistrySearch()
	local registrySearchBox = I.n("TextBox")
	registrySearchBox.S=U2(1, -10, 0, 28)
	registrySearchBox.P=U2(0, 5, 0, 5)
	registrySearchBox.BC3=C3(28, 28, 35)
	registrySearchBox.BTr=0.2
	registrySearchBox.TC3=C3(230, 230, 230)
	registrySearchBox.PlaceholderT="Rechercher un pseudo Roblox..."
	registrySearchBox.T=""
	registrySearchBox.F=E.F.Gotham
	registrySearchBox.TSz=12
	registrySearchBox.TXA=E.TX.Center
	registrySearchBox.CTOF=false
	registrySearchBox.Pa=registryPage
	createCorner(registrySearchBox, 8)
	createStroke(registrySearchBox, C3(80, 80, 100), 1)

	local registryClearBtn = I.n("TextButton")
	registryClearBtn.S=U2(0, 22, 0, 22)
	registryClearBtn.P=U2(1, -28, 0, 8)
	registryClearBtn.BC3=C3(180, 60, 60)
	registryClearBtn.T="X"
	registryClearBtn.TC3=C3(255, 255, 255)
	registryClearBtn.F=E.F.GothamBold
	registryClearBtn.TSz=11
	registryClearBtn.BSP=0
	registryClearBtn.V=false -- caché quand la searchBox est vide
	registryClearBtn.ZIndex = registrySearchBox.ZIndex + 1
	registryClearBtn.ABC=true
	registryClearBtn.Pa=registryPage
	createCorner(registryClearBtn, 11) -- rond
	registryClearBtn.MouseButton1Click:Cn(function()
		registrySearchBox.T=""
		registryClearBtn.V=false
		suggestionsFrame.V=false
	end)
	registrySearchBox:GetPropertyChangedSignal("Text"):Cn(function()
		registryClearBtn.V=(registrySearchBox.Text ~= "")
	end)

	local suggestionsFrame = I.n("Frame")
	suggestionsFrame.S=U2(1, -10, 0, 0) -- hauteur auto
	suggestionsFrame.AutomaticS=E.AutomaticSize.Y
	suggestionsFrame.P=U2(0, 5, 0, 38)
	suggestionsFrame.BC3=C3(20, 20, 28)
	suggestionsFrame.BSP=0
	suggestionsFrame.V=false -- caché par défaut
	suggestionsFrame.Pa=registryPage
	createCorner(suggestionsFrame, 6)
	createStroke(suggestionsFrame, C3(70, 70, 100), 1)

	local suggestionsLayout = I.n("UIListLayout")
	suggestionsLayout.Padding = UDim.new(0, 2)
	suggestionsLayout.SortOrder = E.SortOrder.LayoutOrder
	suggestionsLayout.Pa=suggestionsFrame

	local suggestionsPadding = I.n("UIPadding")
	suggestionsPadding.PaddingTop = UDim.new(0, 4)
	suggestionsPadding.PaddingBottom = UDim.new(0, 4)
	suggestionsPadding.PaddingLeft = UDim.new(0, 4)
	suggestionsPadding.PaddingRight = UDim.new(0, 4)
	suggestionsPadding.Pa=suggestionsFrame

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
		"Vzlom_Emk", "MilanAC", "Eme_Giroux", "RobloxDev", "TestAccount",
	}

	local function fuzzyScore(query, name)
		if not query or query == "" then return nil end
		query = string.lower(query)
		name = string.lower(name)

		if string.sub(name, 1, #query) == query then
			return 1000 - #name -- plus court = mieux
		end

		local sPos = string.find(name, query, 1, true)
		if sPos then
			return 500 - sPos
		end

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

	local function updateSuggestions(queryText)
		for _, child in ipairs(suggestionsFrame:GC()) do
			if child:IsA("TextButton") then child:D() end
		end

		if not queryText or queryText == "" or #queryText < 1 then
			suggestionsFrame.V=false
			return
		end

		local candidates = {}
		for _, plr in ipairs(Pls:GetPls()) do
			table.insert(candidates, plr.Name)
		end
		for _, name in ipairs(popularNames) do
			table.insert(candidates, name)
		end

		local scored = {}
		for _, name in ipairs(candidates) do
			local score = fuzzyScore(queryText, name)
			if score then
				table.insert(scored, {name = name, score = score})
			end
		end
		table.sort(scored, function(a, b) return a.score > b.score end)

		local top3 = {}
		for i = 1, math.min(3, #scored) do
			table.insert(top3, scored[i].name)
		end

		if #top3 == 0 then
			suggestionsFrame.V=false
			return
		end

		for i, name in ipairs(top3) do
			local btn = I.n("TextButton")
			btn.S=U2(1, 0, 0, 22)
			btn.BC3=C3(35, 35, 50)
			btn.BSP=0
			btn.T="  " .. i .. ". " .. name
			btn.F=E.F.Gotham
			btn.TSz=11
			btn.TC3=C3(220, 220, 240)
			btn.TXA=E.TX.Left
			btn.LO=i
			btn.Pa=suggestionsFrame
			createCorner(btn, 4)

			btn.MouseButton1Click:Cn(function()
				registrySearchBox.T=name
				registrySearchBox:CaptureFocus()
				updateSuggestions(name)
			end)

			btn.MouseEnter:Cn(function()
				btn.BC3=C3(60, 60, 100)
			end)
			btn.MouseLeave:Cn(function()
				btn.BC3=C3(35, 35, 50)
			end)
		end

		local helpLabel = I.n("TextLabel")
		helpLabel.N="HelpLabel"
		helpLabel.S=U2(1, -10, 0, 16)
		helpLabel.P=U2(0, 5, 0, 0)
		helpLabel.BTr=1
		helpLabel.T=""
		helpLabel.F=E.F.Gotham
		helpLabel.TSz=9
		helpLabel.TC3=C3(120, 180, 140)
		helpLabel.TXA=E.TX.Left
		helpLabel.LO=100
		helpLabel.Pa=suggestionsFrame

		suggestionsFrame.V=true
	end

	registrySearchBox:GetPropertyChangedSignal("Text"):Cn(function()
		updateSuggestions(registrySearchBox.Text)
	end)

	registrySearchBox.FocusLost:Cn(function(enterPressed)
		if enterPressed then
			pcall(function() runRegistrySearch(registrySearchBox.Text) end)
		end
		task.delay(3, function()
			if not registrySearchBox:IsFocused() then
				suggestionsFrame.V=false
			end
		end)
	end)

end
_initRegistrySearch()

local registryScroll = I.n("ScrollingFrame")
registryScroll.S=U2(1, 0, 1, -40) -- 40px = search box (33) + gap (7)
registryScroll.P=U2(0, 0, 0, 40)
registryScroll.BTr=1
registryScroll.SBT=4
registryScroll.BSP=0
registryScroll.AutomaticCanvasS=E.AutomaticSize.Y
registryScroll.CanvasS=U2(0, 0, 0, 2000)
registryScroll.Pa=registryPage
createCorner(registryScroll, 4)

local registryLayout = I.n("UIListLayout")
registryLayout.Padding = UDim.new(0, 6)
registryLayout.SortOrder = E.SortOrder.LayoutOrder
registryLayout.Pa=registryScroll

local registryPadding = I.n("UIPadding")
registryPadding.PaddingTop = UDim.new(0, 4)
registryPadding.PaddingBottom = UDim.new(0, 4)
registryPadding.PaddingLeft = UDim.new(0, 6)
registryPadding.PaddingRight = UDim.new(0, 6)
registryPadding.Pa=registryScroll

local localScroll = I.n("ScrollingFrame")
localScroll.S=U2(1, 0, 1, 0)
localScroll.BTr=1
localScroll.SBT=4
localScroll.BSP=0
localScroll.CanvasS=U2(0, 0, 0, 900)
localScroll.AutomaticCanvasS=E.AutomaticSize.Y
localScroll.Pa=localPage

local localLayout = I.n("UIListLayout")
localLayout.Padding = UDim.new(0, 6)
localLayout.SortOrder = E.SortOrder.LayoutOrder
localLayout.Pa=localScroll

local protectionsScroll = I.n("ScrollingFrame")
protectionsScroll.N="ProtectionsScroll"
protectionsScroll.S=U2(1, 0, 1, 0)
protectionsScroll.P=U2(0, 0, 0, 0)
protectionsScroll.BTr=1
protectionsScroll.SBT=4
protectionsScroll.BSP=0
protectionsScroll.CanvasS=U2(0, 0, 0, 0)
protectionsScroll.AutomaticCanvasS=E.AutomaticSize.Y
protectionsScroll.Pa=protectionsPage

local protectionsLayout = I.n("UIListLayout")
protectionsLayout.Padding = UDim.new(0, 6)
protectionsLayout.SortOrder = E.SortOrder.LayoutOrder
protectionsLayout.Pa=protectionsScroll

protectionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Cn(function()
	protectionsScroll.CanvasS=U2(0, 0, 0, protectionsLayout.AbsoluteContentSize.Y + 10)
end)
task.defer(function()
	protectionsScroll.CanvasS=U2(0, 0, 0, protectionsLayout.AbsoluteContentSize.Y + 10)
end)

local function reparentChildrenToLocalScroll()
	for _, child in ipairs(localPage:GC()) do
		if child ~= localScroll then
			child.Pa=localScroll
			if child:IsA("GuiObject") and child.LayoutOrder == 0 then
				child.LO=(#localScroll:GC() - 1)
			end
		end
	end
end

local dragging, dragStart, startPos

topBar.InputBegan:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		input.Changed:Cn(function()
			if input.UserInputState == E.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UIS.InputChanged:Cn(function(input)
	if dragging and (input.UserInputType == E.UserInputType.MouseMovement or input.UserInputType == E.UserInputType.Touch) then
		local delta = input.Position - dragStart
		local absS=mainFrame.AbsoluteSize
		local newX = math.clamp(startPos.X.Offset + delta.X, 0, screenGui.AbsoluteSize.X - absSize.X)
		local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, screenGui.AbsoluteSize.Y - absSize.Y)
		mainFrame.P=U2(0, newX, 0, newY)
	end
end)

local ccInputConn = UIS.InputChanged:Cn(function(input)
	if ccDragging and (input.UserInputType == E.UserInputType.MouseMovement or input.UserInputType == E.UserInputType.Touch) then
		local delta = input.Position - ccDragStart
		local absS=clickControl.AbsoluteSize
		local newX = math.clamp(ccStartPos.X.Offset + delta.X, 0, screenGui.AbsoluteSize.X - absSize.X)
		local newY = math.clamp(ccStartPos.Y.Offset + delta.Y, 0, screenGui.AbsoluteSize.Y - absSize.Y)
		clickControl.P=U2(0, newX, 0, newY)
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

	local btn = I.n("ImageButton")
	btn.N="RestoreBtn"
	btn.S=U2(0, 56, 0, 56)
	btn.P=U2(0, 12, 0.5, -28)
	btn.BC3=C3(28, 28, 42)
	btn.Im="rbxassetid://73314612607499"
	btn.ST=E.ScaleType.Fit
	btn.ABC=false
	btn.BSP=0
	btn.V=false
	btn.ZIndex = 9999
	btn.Pa=screenGui
	_createCorner(btn, 14)
	local stroke = I.n("UIStroke")
	stroke.C=C3(120, 80, 220)
	stroke.Thickness = 2
	stroke.Pa=btn

		local longPressProgress = nil
		local lpStartTime = 0

		local function destroyAllPanel()
			if longPressProgress and longPressProgress.Parent then
				longPressProgress:D()
			end
			pcall(shutdownPanel)
			btn.V=false
			for _, gui in ipairs(game.Pls.LP.PlayerGui:GC()) do
				if gui.Name == "MilanEmerickPanel" or gui.Name == "AgoraAdminUniverselle" then
					pcall(function() gui:D() end)
				end
			end
			pcall(function()
				if game.CG:FFC("MilanEmerickPanel") then
					game.CG.MilanEmerickPanel:D()
				end
			end)
			print("[Agora Universelle] Panel detruit.")
		end

		local function startLongPress()
			lpStartTime = tick()
			if not longPressProgress or not longPressProgress.Parent then
				longPressProgress = I.n("Frame")
				longPressProgress.S=U2(1.4, 0, 1.4, 0)
				longPressProgress.P=U2(0.5, 0, 0.5, 0)
				longPressProgress.AnchorPoint = Vector2.new(0.5, 0.5)
				longPressProgress.BC3=C3(180, 60, 60)
				longPressProgress.BTr=0.6
				longPressProgress.BSP=0
				longPressProgress.ZIndex = btn.ZIndex - 1
				longPressProgress.Pa=btn
				_createCorner(longPressProgress, 1)
			end
			longPressProgress.V=true
			longPressProgress.S=U2(1, 0, 1, 0)
			longPressProgress.BTr=1
			_tween(longPressProgress, {S=U2(1.4, 0, 1.4, 0), BTr=0.6}, 2)
		end
		local function endLongPress()
			local longPressed = lpStartTime > 0 and (tick() - lpStartTime) >= 2
			lpStartTime = longPressed and -1 or 0
			if longPressed then
				destroyAllPanel()
			end
			if longPressProgress and longPressProgress.Parent then
				_tween(longPressProgress, {S=U2(1, 0, 1, 0), BTr=1}, 0.2)
			end
		end

		btn.MouseButton1Down:Cn(startLongPress)
		btn.MouseLeave:Cn(endLongPress)
		btn.MouseButton1Up:Cn(endLongPress)

		btn.MouseButton1Click:Cn(function()
			if lpStartTime == -1 then
				lpStartTime = 0
				return
			end
			minimized = false
			_contentFrame.V=true
			_tabBar.V=true
			_topBar.V=true
			_minimizeBtn.V=true
			_closeBtn.V=true
			_tween(_mainFrame, {S=U2(0, 460, 0, 520), BTr=0.35}, 0.25)
			btn.V=false
		end)

	btn.MouseEnter:Cn(function()
		_tween(btn, {S=U2(0, 62, 0, 62)}, 0.15)
	end)
	btn.MouseLeave:Cn(function()
		_tween(btn, {S=U2(0, 56, 0, 56)}, 0.15)
	end)

	_minimizeBtn.MouseButton1Click:Cn(function()
		minimized = true
		_contentFrame.V=false
		_tabBar.V=false
		_topBar.V=false
		_minimizeBtn.V=false
		_closeBtn.V=false
		_tween(_mainFrame, {S=U2(0, 0, 0, 0), BTr=1}, 0.25)
		btn.V=true
	end)
end)()

closeBtn.MouseButton1Click:Cn(function()
	local confirm = I.n("Frame")
	confirm.S=U2(0, 260, 0, 140)
	confirm.P=U2(0.5, -130, 0.5, -70)
	confirm.BC3=C3(25, 25, 30)
	confirm.BSP=0
	confirm.ZIndex = 200
	confirm.Pa=screenGui
	createCorner(confirm, 12)
	createStroke(confirm, C3(80, 80, 100), 1)

	local msg = I.n("TextLabel")
	msg.S=U2(1, -20, 0, 50)
	msg.P=U2(0, 10, 0, 15)
	msg.BTr=1
	msg.T="Fermer le panel ?"
	msg.F=E.F.GothamSemibold
	msg.TSz=16
	msg.TC3=Color3.new(1, 1, 1)
	msg.ZIndex = 201
	msg.Pa=confirm

	local yes = createButton(confirm, "Oui", 75, C3(200, 60, 60), function()
		confirm:D()
		pcall(shutdownPanel)
		local flash = I.n("Frame")
		flash.S=U2(1, 0, 1, 0)
		flash.BC3=C3(255, 255, 255)
		flash.BTr=1
		flash.BSP=0
		flash.ZIndex = 999
		flash.Pa=screenGui
		tween(flash, {BTr=0.4}, 0.1)
		task.wait(0.1)
		tween(flash, {BTr=1}, 0.3)
		task.delay(0.4, function() if flash and flash.Parent then flash:D() end end)

		for i = 1, 6 do
			local gb = I.n("Frame")
			gb.S=U2(1, 0, 0, math.random(2, 8))
			gb.P=U2(0, 0, math.random() * 0.95, 0)
			gb.BC3=C3(math.random(100, 255), math.random(100, 255), math.random(100, 255))
			gb.BTr=0.4
			gb.BSP=0
			gb.ZIndex = 990
			gb.Pa=screenGui
			task.spawn(function()
				task.wait(i * 0.05)
				tween(gb, {BTr=1, P=U2(0, math.random(-20, 20), gb.Position.Y.Scale, 0)}, 0.2)
				task.delay(0.3, function() if gb and gb.Parent then gb:D() end end)
			end)
		end

		mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		local oldPos = mainFrame.Position
		mainFrame.P=U2(0.5, 0, 0.5, 0)
		tween(mainFrame, {
			S=U2(0, 0, 0, 0),
			Rotation = 12,
			BTr=1,
		}, 0.4, E.EasingStyle.Back, E.EasingDirection.In)
		local goodbye = I.n("TextLabel")
		goodbye.S=U2(1, 0, 0, 40)
		goodbye.P=U2(0, 0, 0.5, -20)
		goodbye.BTr=1
		goodbye.T="Au revoir " .. LP.DisplayName .. " revenez vite... 3:)"
		goodbye.F=E.F.GothamBold
		goodbye.TSz=22
		goodbye.TC3=C3(120, 255, 180)
		goodbye.TextStrokeTr=0.3
		goodbye.TT=1
		goodbye.ZIndex = 1000
		goodbye.Pa=screenGui
		task.wait(0.2)
		tween(goodbye, {TT=0}, 0.3)
		task.wait(1.2)
		tween(goodbye, {TT=1}, 0.5)
		task.wait(0.6)
		screenGui.Enabled = false
		if goodbye and goodbye.Parent then goodbye:D() end
	end)
	yes.S=U2(0.45, -10, 0, 34)
	yes.P=U2(0.05, 5, 0, 75)
	yes.ZIndex = 201

	local no = createButton(confirm, "Non", 75, C3(60, 160, 90), function()
		confirm:D()
	end)
	no.S=U2(0.45, -10, 0, 34)
	no.P=U2(0.55, -5, 0, 75)
	no.ZIndex = 201

	confirm:TweenPosition(U2(0.5, -130, 0.5, -70), E.EasingDirection.Out, E.EasingStyle.Back, 0.25, true)
end)

local function shutdownPanel()
	if flyState and flyState.flying then stopFly() end
	if noclipState and noclipState.enabled then
		noclipState.enabled = false
		if noclipSwitch then noclipSwitch.set(false) end
		if character then
			for _, p in ipairs(character:GD()) do
				if p:IsA("BasePart") then p.CC=true end
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
		autoClickState.toolA=false
		if stopAutoClickEngine then stopAutoClickEngine() end
		removeFakeTool()
		if clickControl then clickControl.V=false end
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
			platformState.part:D()
			platformState.part = nil
		end
	end
	_G._agoraAimbotEnabled = false
	pcall(function()
		Lt.Ambient = C3(128, 128, 128)
		Lt.OutdoorAmbient = C3(128, 128, 128)
	end)
end

local function createSwitch(parent, labelText, yPos, callback, defaultOn)
	local container = I.n("Frame")
	container.S=U2(1, -20, 0, 36)
	container.P=U2(0, 10, 0, yPos)
	container.BC3=C3(25, 25, 30)
	container.BSP=0
	container.Pa=parent
	createCorner(container, 8)
	createStroke(container, C3(45, 45, 55), 1)

	local label = I.n("TextLabel")
	label.S=U2(1, -70, 1, 0)
	label.P=U2(0, 12, 0, 0)
	label.BTr=1
	label.T=labelText
	label.F=E.F.GothamSemibold
	label.TSz=13
	label.TC3=C3(210, 210, 210)
	label.TXA=E.TX.Left
	label.Pa=container
	label.ZIndex = 4

	local track = I.n("Frame")
	track.S=U2(0, 48, 0, 24)
	track.P=U2(1, -60, 0.5, -12)
	track.BC3=C3(60, 60, 70)
	track.BSP=0
	track.Pa=container
	track.ZIndex = 5
	createCorner(track, 12)

	local knob = I.n("Frame")
	knob.S=U2(0, 20, 0, 20)
	knob.P=U2(0, 2, 0.5, -10)
	knob.BC3=Color3.new(1, 1, 1)
	knob.BSP=0
	knob.Pa=track
	knob.ZIndex = 6
	createCorner(knob, 10)

	local state = defaultOn or false
	local function update(animate)
		local dur = animate and 0.15 or 0
		tween(track, {BC3=state and C3(60, 190, 120) or C3(60, 60, 70)}, dur)
		tween(knob, {P=state and U2(1, -22, 0.5, -10) or U2(0, 2, 0.5, -10)}, dur)
	end
	update(false)

	local function toggle()
		state = not state
		update(true)
		callback(state)
	end

	local hitbox = I.n("TextButton")
	hitbox.N="SwitchHitbox"
	hitbox.S=U2(1, 0, 1, 0)
	hitbox.BTr=1
	hitbox.T=""
	hitbox.Pa=container
	hitbox.ZIndex = 10

	container.CD=true

	hitbox.MouseButton1Click:Cn(toggle)

	return {
		set = function(v)
			state = v
			update(true)
			callback(v)
		end,
		get = function() return state end
	}
end

local playerCards = {}
local playerSearchQuery = "" -- query actuelle (vide = pas de filtre)

local playerSearchBox = I.n("TextBox")
playerSearchBox.S=U2(1, -10, 0, 26)
playerSearchBox.P=U2(0, 5, 0, 8)
playerSearchBox.BC3=C3(28, 28, 35)
playerSearchBox.BTr=0.4 -- plus discret que la search box Registry
playerSearchBox.TC3=C3(200, 200, 200)
playerSearchBox.PlaceholderT="🔎 Filtrer la liste des joueurs..."
playerSearchBox.T=""
playerSearchBox.F=E.F.Gotham
playerSearchBox.TSz=11
playerSearchBox.TXA=E.TX.Left
playerSearchBox.CTOF=false
playerSearchBox.Pa=playersPage
createCorner(playerSearchBox, 6)
createStroke(playerSearchBox, C3(60, 60, 80), 1)

local playerClearBtn = I.n("TextButton")
playerClearBtn.S=U2(0, 20, 0, 20)
playerClearBtn.P=U2(1, -25, 0, 11)
playerClearBtn.BC3=C3(180, 60, 60)
playerClearBtn.T="X"
playerClearBtn.TC3=C3(255, 255, 255)
playerClearBtn.F=E.F.GothamBold
playerClearBtn.TSz=10
playerClearBtn.BSP=0
playerClearBtn.V=false
playerClearBtn.ZIndex = playerSearchBox.ZIndex + 1
playerClearBtn.ABC=true
playerClearBtn.Pa=playersPage
createCorner(playerClearBtn, 10)
playerClearBtn.MouseButton1Click:Cn(function()
	playerSearchBox.T=""
	playerClearBtn.V=false
end)

local psbPad = I.n("UIPadding")
psbPad.PaddingLeft = UDim.new(0, 8)
psbPad.Pa=playerSearchBox

local playersScroll = I.n("ScrollingFrame")
playersScroll.S=U2(1, -10, 1, -48)
playersScroll.P=U2(0, 5, 0, 40)
playersScroll.BTr=1
playersScroll.SBT=4
playersScroll.BSP=0
playersScroll.Pa=playersPage

local playersLayout = I.n("UIListLayout")
playersLayout.Padding = UDim.new(0, 6)
playersLayout.SortOrder = E.SortOrder.LayoutOrder
playersLayout.Pa=playersScroll

playersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Cn(function()
	playersScroll.CanvasS=U2(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end)
task.defer(function()
	playersScroll.CanvasS=U2(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end)

;(function(_createCorner, _createStroke)
	local myCard = I.n("Frame")
	myCard.N="MyCard"
	myCard.S=U2(1, -8, 0, 0)
	myCard.AutomaticS=E.AutomaticSize.Y
	myCard.BC3=C3(45, 30, 70)
	myCard.BSP=0
	myCard.LO=-100 -- toujours en premier
	myCard.Pa=playersScroll
	_createCorner(myCard, 8)
	_createStroke(myCard, C3(180, 130, 255), 1.5)

	local myTitle = I.n("TextLabel")
	myTitle.S=U2(1, -16, 0, 22)
	myTitle.P=U2(0, 8, 0, 6)
	myTitle.BTr=1
	myTitle.F=E.F.GothamBlack
	myTitle.TSz=14
	myTitle.TC3=C3(220, 180, 255)
	myTitle.TXA=E.TX.Left
	myTitle.Pa=myCard

	local myContent = I.n("TextLabel")
	myContent.N="MyContent"
	myContent.S=U2(1, -16, 0, 0)
	myContent.P=U2(0, 8, 0, 30)
	myContent.AutomaticS=E.AutomaticSize.Y
	myContent.BTr=1
	myContent.F=E.F.Gotham
	myContent.TSz=11
	myContent.TC3=C3(210, 210, 230)
	myContent.TXA=E.TX.Left
	myContent.TYA=E.TY.Top
	myContent.TW=true
	myContent.Pa=myCard

	local function updateMyCard()
		pcall(function()
			local _lp = LP
			local myN=_lp.Name or "?"
			local myDisp = _lp.DisplayName or "?"
			local myUid = tostring(_lp.UserId or "?")
			local myAgeDays = _lp.AccountAge or 0
			local myYears = math.floor(myAgeDays / 365)
			local myRem = myAgeDays - (myYears * 365)
			local myMt = tostring(_lp.MembershipType or "None"):gsub("E.MembershipType.", "")
			local myPing = "?"
			pcall(function() myPing = tostring(math.floor((_lp.GetNetworkPing and _lp:GetNetworkPing() or 0) * 1000)) .. " ms" end)
			local myTeam = (_lp.Team and _lp.Team.Name) or "Aucune"
			local myChar = _lp.Character
			local myHp = "?"
			local myPos = "?"
			pcall(function()
				if myChar then
					local h = myChar:FFCOC("Humanoid")
					if h then myHp = tostring(math.floor(h.Health)) .. "/" .. tostring(math.floor(h.MaxHealth)) end
					local hrp = myChar:FFC("HumanoidRootPart")
					if hrp then
						local p = hrp.Position
						myPos = string.format("(%.0f, %.0f, %.0f)", p.X, p.Y, p.Z)
					end
				end
			end)
			local myGame = tostring(game.GameId or "?")
			local myPlace = tostring(game.PlaceId or "?")

			myTitle.T="👑 TOI — @" .. myName .. " (" .. myDisp .. ")"
			myContent.T=table.concat({
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
	task.spawn(function()
		while true do
			task.wait(1)
			updateMyCard()
		end
	end)
end)(createCorner, createStroke)

playerSearchBox:GetPropertyChangedSignal("Text"):Cn(function()
	local q = playerSearchBox.Text:lower():gsub("%s+", "")
	playerClearBtn.V=(playerSearchBox.Text ~= "")
	for plr, card in pairs(playerCards) do
		local n = plr.Name:lower()
		local d = plr.DisplayName:lower()
		local match = (q == "") or (n:find(q, 1, true) ~= nil) or (d:find(q, 1, true) ~= nil)
		card.V=match
	end
end)

local echoStatusLabel = I.n("TextLabel")
echoStatusLabel.S=U2(1, -20, 0, 18)
echoStatusLabel.P=U2(0, 10, 1, -26)
echoStatusLabel.BTr=1
echoStatusLabel.T="Echo: aucun"
echoStatusLabel.F=E.F.Gotham
echoStatusLabel.TSz=10
echoStatusLabel.TC3=C3(160, 160, 160)
echoStatusLabel.TXA=E.TX.Left
echoStatusLabel.Pa=mainFrame

local selectedEchoPlayer = nil

local function showRestorePopup(lastName)
	if panelMemory.dontAskRestore then return end
	if not lastName then return end
	local current = Pls:FFC(lastName)
	if not current then return end

	local popup = I.n("Frame")
	popup.S=U2(0, 300, 0, 130)
	popup.P=U2(0.5, -150, 0.5, -65)
	popup.BC3=C3(25, 25, 30)
	popup.BSP=0
	popup.ZIndex = 500
	popup.Pa=screenGui
	createCorner(popup, 12)
	createStroke(popup, C3(80, 80, 100), 1)

	local msg = I.n("TextLabel")
	msg.S=U2(1, -20, 0, 44)
	msg.P=U2(0, 10, 0, 12)
	msg.BTr=1
	msg.T="Restaurer les paramètres pour @" .. lastName .. " ?"
	msg.F=E.F.GothamSemibold
	msg.TSz=14
	msg.TC3=Color3.new(1, 1, 1)
	msg.ZIndex = 501
	msg.Pa=popup

	local restoreBtn = createButton(popup, "Restaurer", 70, C3(60, 160, 90), function()
		selectedEchoPlayer = current
		echoStatusLabel.T="Echo: @" .. current.Name
		echoStatusLabel.TC3=C3(120, 200, 120)
		popup:D()
	end)
	restoreBtn.S=U2(0.32, -8, 0, 30)
	restoreBtn.P=U2(0.02, 4, 0, 70)
	restoreBtn.ZIndex = 501

	local neverBtn = createButton(popup, "Ne plus afficher", 70, C3(120, 120, 120), function()
		panelMemory.dontAskRestore = true
		popup:D()
	end)
	neverBtn.S=U2(0.36, -8, 0, 30)
	neverBtn.P=U2(0.36, 4, 0, 70)
	neverBtn.ZIndex = 501

	local cancelBtn = createButton(popup, "Annuler", 70, C3(200, 60, 60), function()
		popup:D()
	end)
	cancelBtn.S=U2(0.28, -8, 0, 30)
	cancelBtn.P=U2(0.74, -4, 0, 70)
	cancelBtn.ZIndex = 501

	popup:TweenPosition(U2(0.5, -150, 0.5, -65), E.EasingDirection.Out, E.EasingStyle.Back, 0.25, true)
end

local function createPlayerEntry(plr)
	local card = I.n("Frame")
	card.S=U2(1, -8, 0, 196)
	card.BC3=C3(28, 28, 35)
	card.BSP=0
	card.LO=plr.Name:byte(1)
	card.Pa=playersScroll
	createCorner(card, 10)
	createStroke(card, C3(45, 45, 55), 1)

	local nameLbl = I.n("TextLabel")
	nameLbl.S=U2(1, -80, 0, 18)
	nameLbl.P=U2(0, 6, 0, 4)
	nameLbl.BTr=1
	nameLbl.T=plr.DisplayName .. " (@" .. plr.Name .. ")"
	nameLbl.F=E.F.GothamBold
	nameLbl.TSz=13
	nameLbl.TC3=C3(230, 230, 230)
	nameLbl.TXA=E.TX.Left
	nameLbl.Pa=card

	local playerChatBadge = I.n("TextLabel")
	playerChatBadge.N="PlayerChatBadge"
	playerChatBadge.S=U2(0, 24, 0, 20)
	playerChatBadge.P=U2(0, 6, 0, 4)
	playerChatBadge.BTr=1
	playerChatBadge.T="💬"
	playerChatBadge.F=E.F.GothamBold
	playerChatBadge.TSz=14
	playerChatBadge.TC3=C3(220, 220, 255)
	playerChatBadge.TXA=E.TX.Center
	playerChatBadge.V=false
	playerChatBadge.Pa=card
	playerChatBadge.ZIndex = 6

	nameLbl.S=U2(1, -108, 0, 18)
	nameLbl.P=U2(0, 30, 0, 4)

	local moveBadge = I.n("TextLabel")
	moveBadge.N="MoveBadge"
	moveBadge.S=U2(0, 24, 0, 20)
	moveBadge.P=U2(1, -32, 0, 2)
	moveBadge.BTr=1
	moveBadge.BSP=0
	moveBadge.T="🔺"
	moveBadge.F=E.F.GothamBold
	moveBadge.TSz=15
	moveBadge.TC3=C3(255, 80, 80)
	moveBadge.TXA=E.TX.Center
	moveBadge.V=false
	moveBadge.Pa=card
	moveBadge.ZIndex = 6

	local moveDetail = I.n("TextLabel")
	moveDetail.N="MoveDetail"
	moveDetail.S=U2(1, -12, 0, 14)
	moveDetail.P=U2(0, 6, 0, 108)
	moveDetail.BTr=1
	moveDetail.T=""
	moveDetail.F=E.F.Gotham
	moveDetail.TSz=9
	moveDetail.TC3=C3(255, 100, 100)
	moveDetail.TXA=E.TX.Left
	moveDetail.TW=true
	moveDetail.Pa=card

	local cheatNotes = I.n("TextLabel")
	cheatNotes.N="CheatNotes"
	cheatNotes.S=U2(1, -12, 0, 34)
	cheatNotes.P=U2(0, 6, 0, 140)
	cheatNotes.BTr=1
	cheatNotes.T=""
	cheatNotes.F=E.F.Gotham
	cheatNotes.TSz=9
	cheatNotes.TC3=C3(255, 120, 120)
	cheatNotes.TXA=E.TX.Left
	cheatNotes.TW=true
	cheatNotes.TYA=E.TY.Top
	cheatNotes.Pa=card

	local lastMoveFlagAt = 0
	local lastMoveReason = ""
	local MOVE_FLAG_DURATION = 3
	local lastChatCheck = 0

	local infoLeft = I.n("TextLabel")
	infoLeft.S=U2(0.55, -6, 0, 14)
	infoLeft.P=U2(0, 6, 0, 24)
	infoLeft.BTr=1
	local days = plr.AccountAge
	local years = math.floor(days / 365)
	local remainingDays = days - (years * 365)
	infoLeft.T="ID: " .. plr.UserId .. " | Âge: " .. days .. "j (" .. years .. (years <= 1 and " an" or " ans") .. ")"
	infoLeft.F=E.F.Gotham
	infoLeft.TSz=10
	infoLeft.TC3=C3(180, 180, 180)
	infoLeft.TXA=E.TX.Left
	infoLeft.Pa=card

	local statusCol = I.n("TextLabel")
	statusCol.N="StatusCol"
	statusCol.S=U2(0.42, -6, 0, 60)
	statusCol.P=U2(0.55, 0, 0, 24)
	statusCol.BTr=1
	statusCol.T="Statut: ?"
	statusCol.F=E.F.GothamSemibold
	statusCol.TSz=10
	statusCol.TC3=C3(180, 200, 230)
	statusCol.TXA=E.TX.Right
	statusCol.TYA=E.TY.Top
	statusCol.TW=true
	statusCol.Pa=card

	local distLbl = I.n("TextLabel")
	distLbl.S=U2(0.55, -6, 0, 14)
	distLbl.P=U2(0, 6, 0, 38)
	distLbl.BTr=1
	distLbl.T="Distance: ?"
	distLbl.F=E.F.Gotham
	distLbl.TSz=10
	distLbl.TC3=C3(180, 180, 180)
	distLbl.TXA=E.TX.Left
	distLbl.Pa=card

	local hpLbl = I.n("TextLabel")
	hpLbl.S=U2(0.55, -6, 0, 14)
	hpLbl.P=U2(0, 6, 0, 52)
	hpLbl.BTr=1
	hpLbl.T="HP: ?"
	hpLbl.F=E.F.Gotham
	hpLbl.TSz=10
	hpLbl.TC3=C3(180, 180, 180)
	hpLbl.TXA=E.TX.Left
	hpLbl.Pa=card

	local speedLbl = I.n("TextLabel")
	speedLbl.S=U2(0.55, -6, 0, 14)
	speedLbl.P=U2(0, 6, 0, 66)
	speedLbl.BTr=1
	speedLbl.T="Vitesse/Saut: ?"
	speedLbl.F=E.F.Gotham
	speedLbl.TSz=10
	speedLbl.TC3=C3(180, 180, 180)
	speedLbl.TXA=E.TX.Left
	speedLbl.Pa=card

	local chatLbl = I.n("TextLabel")
	chatLbl.N="ChatLabel"
	chatLbl.S=U2(0.55, -6, 0, 14)
	chatLbl.P=U2(0, 6, 0, 80)
	chatLbl.BTr=1
	chatLbl.T="💬 can_chat: chargement..."
	chatLbl.F=E.F.Gotham
	chatLbl.TSz=10
	chatLbl.TC3=C3(180, 180, 180)
	chatLbl.TXA=E.TX.Left
	chatLbl.Pa=card

	_G._resolveCanChat(plr, function(canChat, src)
		if chatLbl and chatLbl.Parent then
			if src == "CanTalkWithMe" then
				if canChat == true then
					chatLbl.T="💬 Peut me parler"
					chatLbl.TC3=C3(120, 220, 140)
				else
					chatLbl.T="🚫 Ne peut pas me parler"
					chatLbl.TC3=C3(220, 120, 120)
				end
			else
				if canChat == true then
					chatLbl.T="💬 Chat activé (" .. src .. ")"
					chatLbl.TC3=C3(180, 180, 180)
				elseif canChat == false then
					chatLbl.T="🚫 Chat désactivé (" .. src .. ")"
					chatLbl.TC3=C3(180, 120, 120)
				else
					chatLbl.T="💬 Chat: non vérifiable"
					chatLbl.TC3=C3(180, 180, 180)
				end
			end
		end
	end)

	local statusLbl = I.n("TextLabel")
	statusLbl.S=U2(0.55, -6, 0, 14)
	statusLbl.P=U2(0, 6, 0, 94)
	statusLbl.BTr=1
	statusLbl.T="Statut: ?"
	statusLbl.F=E.F.Gotham
	statusLbl.TSz=10
	statusLbl.TC3=C3(180, 180, 180)
	statusLbl.TXA=E.TX.Left
	statusLbl.Pa=card

	local tpBtn = I.n("TextButton")
	tpBtn.S=U2(0, 54, 0, 24)
	tpBtn.P=U2(1, -128, 0, 26)
	tpBtn.BC3=C3(45, 110, 190)
	tpBtn.T="TP"
	tpBtn.F=E.F.GothamSemibold
	tpBtn.TSz=11
	tpBtn.TC3=Color3.new(1, 1, 1)
	tpBtn.BSP=0
	tpBtn.Pa=card
	createCorner(tpBtn, 6)

	local specBtn = I.n("TextButton")
	specBtn.S=U2(0, 68, 0, 24)
	specBtn.P=U2(1, -70, 0, 26)
	specBtn.BC3=C3(190, 120, 50)
	specBtn.T="Spectate"
	specBtn.F=E.F.GothamSemibold
	specBtn.TSz=11
	specBtn.TC3=Color3.new(1, 1, 1)
	specBtn.BSP=0
	specBtn.Pa=card
	createCorner(specBtn, 6)

	local echoBtn = I.n("TextButton")
	echoBtn.S=U2(0, 54, 0, 24)
	echoBtn.P=U2(1, -128, 0, 54)
	echoBtn.BC3=C3(90, 60, 160)
	echoBtn.T="Echo"
	echoBtn.F=E.F.GothamSemibold
	echoBtn.TSz=11
	echoBtn.TC3=Color3.new(1, 1, 1)
	echoBtn.BSP=0
	echoBtn.Pa=card
	createCorner(echoBtn, 6)

	local espBtn = I.n("TextButton")
	espBtn.S=U2(0, 68, 0, 24)
	espBtn.P=U2(1, -70, 0, 54)
	espBtn.BC3=C3(60, 140, 80)
	espBtn.T="ESP"
	espBtn.F=E.F.GothamSemibold
	espBtn.TSz=11
	espBtn.TC3=Color3.new(1, 1, 1)
	espBtn.BSP=0
	espBtn.Pa=card
	createCorner(espBtn, 6)

	local invBtn = I.n("TextButton")
	invBtn.S=U2(0, 54, 0, 24)
	invBtn.P=U2(1, -128, 0, 82)
	invBtn.BC3=C3(60, 90, 150)
	invBtn.T="Voir Inv"
	invBtn.F=E.F.GothamSemibold
	invBtn.TSz=11
	invBtn.TC3=Color3.new(1, 1, 1)
	invBtn.BSP=0
	invBtn.Pa=card
	createCorner(invBtn, 6)

	local skinBtn = I.n("TextButton")
	skinBtn.S=U2(0, 68, 0, 24)
	skinBtn.P=U2(1, -70, 0, 82)
	skinBtn.BC3=C3(140, 60, 160)
	skinBtn.T="Copy Skin"
	skinBtn.F=E.F.GothamSemibold
	skinBtn.TSz=11
	skinBtn.TC3=Color3.new(1, 1, 1)
	skinBtn.BSP=0
	skinBtn.Pa=card
	createCorner(skinBtn, 6)

	local spectating = false

	tpBtn.MouseButton1Click:Cn(function()
		updateCharacter()
		if plr.Character and plr.Character:FFC("HumanoidRootPart") and rootPart then
			rootPart.CF=plr.Character.HumanoidRootPart.CFrame + V3(0, 3, 0)
		end
	end)

	specBtn.MouseButton1Click:Cn(function()
		spectating = not spectating
		if spectating and plr.Character and plr.Character:FFCOC("Humanoid") then
			Camera.CSu=plr.Character:FFCOC("Humanoid")
			specBtn.T="Stop"
			specBtn.BC3=C3(160, 60, 60)
		else
			updateCharacter()
			if humanoid then Camera.CSu=humanoid end
			spectating = false
			specBtn.T="Spectate"
			specBtn.BC3=C3(190, 120, 50)
		end
	end)

	echoBtn.MouseButton1Click:Cn(function()
		if selectedEchoPlayer == plr then
			selectedEchoPlayer = nil
			echoBtn.BC3=C3(90, 60, 160)
			echoStatusLabel.T="Echo: aucun"
			echoStatusLabel.TC3=C3(160, 160, 160)
		else
			selectedEchoPlayer = plr
			panelMemory.lastEchoPlayerN=plr.Name
			echoBtn.BC3=C3(120, 200, 100)
			echoStatusLabel.T="Echo: @" .. plr.Name
			echoStatusLabel.TC3=C3(120, 200, 120)
		end
	end)

	local tempEspA=false
	espBtn.MouseButton1Click:Cn(function()
		if tempEspActive then return end
		tempEspA=true
		espBtn.T="5s"
		espBtn.BC3=C3(255, 180, 60)
		local targetChar = plr.Character
		local targetHrp = targetChar and targetChar:FFC("HumanoidRootPart")
		local targetHead = targetChar and targetChar:FFC("Head")
		local arrowGui, arrowLbl

		if targetHead then
			local arrowAdorn = I.n("BillboardGui")
			arrowAdorn.N="TempESPArrow"
			arrowAdorn.AlwaysOnTop = true
			arrowAdorn.S=U2(0, 80, 0, 60)
			arrowAdorn.StudsOffset = V3(0, 4, 0)
			arrowAdorn.Adornee = targetHead
			arrowAdorn.Pa=targetHead
			arrowGui = arrowAdorn

			local arrowT=I.n("TextLabel")
			arrowText.S=U2(1, 0, 1, 0)
			arrowText.BTr=1
			arrowText.T="▼"
			arrowText.F=E.F.GothamBlack
			arrowText.TSz=36
			arrowText.TC3=C3(0, 255, 120)
			arrowText.TextStrokeTr=0.2
			arrowText.TextStrokeColor3 = C3(0, 0, 0)
			arrowText.Pa=arrowAdorn
			arrowLbl = arrowText

			task.spawn(function()
				local up = true
				while arrowAdorn and arrowAdorn.Parent do
					arrowAdorn.StudsOffset = V3(0, up and 4.6 or 3.4, 0)
					up = not up
					task.wait(0.25)
				end
			end)
		end

		if targetHrp and rootPart then
			local camStart = Camera.CFrame
			local targetCF = CFrame.new(Camera.CFrame.Position, targetHrp.Position)
			TSv:Create(Camera, TweenInfo.new(0.4, E.EasingStyle.Quad, E.EasingDirection.Out), {CF=targetCF}):Play()
		end

		togglePlayerESP(plr)

		task.delay(5, function()
			togglePlayerESP(plr)
			if arrowGui then arrowGui:D() end
			local char = plr.Character
			if char then
				for _, v in ipairs(char:GD()) do
					if v.Name == "TempESPArrow" then v:D() end
				end
			end
			espBtn.T="ESP"
			espBtn.BC3=C3(60, 140, 80)
			tempEspA=false
		end)
	end)

	local function showInventoryGui()
		local existing = screenGui:FFC("_InvPanel_" .. plr.Name)
		if existing then existing:D() end

		local win = I.n("Frame")
		win.N="_InvPanel_" .. plr.Name
		win.S=U2(0, 300, 0, 320)
		win.P=U2(0.5, -150, 0.5, -160)
		win.BC3=C3(20, 20, 26)
		win.BTr=0.1
		win.BSP=0
		win.A=true
		win.Draggable = true
		win.Pa=screenGui
		createCorner(win, 10)
		createStroke(win, C3(100, 100, 130), 1.2)

		local title = I.n("TextLabel")
		title.S=U2(1, -40, 0, 30)
		title.P=U2(0, 10, 0, 0)
		title.BTr=1
		title.T="Inv de @" .. plr.Name
		title.F=E.F.GothamBold
		title.TSz=13
		title.TC3=C3(255, 255, 255)
		title.TXA=E.TX.Left
		title.Pa=win

		local closeX = I.n("TextButton")
		closeX.S=U2(0, 26, 0, 26)
		closeX.P=U2(1, -32, 0, 4)
		closeX.BC3=C3(180, 60, 60)
		closeX.T="×"
		closeX.F=E.F.GothamBold
		closeX.TSz=16
		closeX.TC3=Color3.new(1, 1, 1)
		closeX.BSP=0
		closeX.Pa=win
		createCorner(closeX, 6)
		closeX.MouseButton1Click:Cn(function() win:D() end)

		local stealAll = I.n("TextButton")
		stealAll.S=U2(1, -20, 0, 28)
		stealAll.P=U2(0, 10, 0, 32)
		stealAll.BC3=C3(180, 90, 50)
		stealAll.T="Tout voler"
		stealAll.F=E.F.GothamBold
		stealAll.TSz=12
		stealAll.TC3=Color3.new(1, 1, 1)
		stealAll.BSP=0
		stealAll.Pa=win
		createCorner(stealAll, 6)

		local list = I.n("ScrollingFrame")
		list.S=U2(1, -20, 1, -72)
		list.P=U2(0, 10, 0, 66)
		list.BC3=C3(28, 28, 35)
		list.BTr=0.3
		list.SBT=4
		list.BSP=0
		list.CanvasS=U2(0, 0, 0, 0)
		list.Pa=win
		createCorner(list, 6)
		createStroke(list, C3(60, 60, 75), 1)

		local layout = I.n("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = E.SortOrder.LayoutOrder
		layout.Pa=list

		local function collectItems()
			local target = plr.Character
			local items = {}
			if not target then return items end
			for _, item in ipairs(plr.Backpack:GC()) do
				if item:IsA("Tool") then table.insert(items, {N=item.Name, Tool = item}) end
			end
			if target:FFCOC("Humanoid") then
				for _, item in ipairs(target:GC()) do
					if item:IsA("Tool") then table.insert(items, {N="(EQ) " .. item.Name, Tool = item}) end
				end
			end
			return items
		end

		local function refreshList()
			for _, c in ipairs(list:GC()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:D() end end
			local items = collectItems()
			if #items == 0 then
				local none = I.n("TextLabel")
				none.S=U2(1, -10, 0, 28)
				none.BTr=1
				none.T="(inventaire vide)"
				none.F=E.F.GothamSemibold
				none.TSz=12
				none.TC3=C3(180, 180, 180)
				none.Pa=list
			else
				for idx, item in ipairs(items) do
					local row = I.n("Frame")
					row.S=U2(1, -8, 0, 28)
					row.BC3=C3(35, 35, 45)
					row.BSP=0
					row.LO=idx
					row.Pa=list
					createCorner(row, 5)

					local nameLbl = I.n("TextLabel")
					nameLbl.S=U2(1, -76, 1, 0)
					nameLbl.P=U2(0, 8, 0, 0)
					nameLbl.BTr=1
					nameLbl.T=item.Name
					nameLbl.F=E.F.GothamSemibold
					nameLbl.TSz=11
					nameLbl.TC3=C3(230, 230, 230)
					nameLbl.TXA=E.TX.Left
					nameLbl.TTr=E.TextTruncate.AtEnd
					nameLbl.Pa=row

					local take = I.n("TextButton")
					take.S=U2(0, 56, 0, 22)
					take.P=U2(1, -62, 0.5, -11)
					take.BC3=C3(60, 150, 90)
					take.T="Voler"
					take.F=E.F.GothamBold
					take.TSz=11
					take.TC3=Color3.new(1, 1, 1)
					take.BSP=0
					take.Pa=row
					createCorner(take, 5)
					take.MouseButton1Click:Cn(function()
						local tool = item.Tool
						if not tool or not tool.Parent then return end
						local clone = tool:Cl()
						local myBackpack = LP:FFC("Backpack")
						if not myBackpack then return end
						clone.Pa=myBackpack
						if notify then notify("Item volé: " .. clone.Name, 2) end
						task.wait(0.1)
						refreshList()
					end)
				end
			end
			list.CanvasS=U2(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
		end

		stealAll.MouseButton1Click:Cn(function()
			local items = collectItems()
			local stolen = 0
			local myBackpack = LP:FFC("Backpack")
			if not myBackpack then return end
			for _, item in ipairs(items) do
				if item.Tool and item.Tool.Parent then
					item.Tool:Cl().Pa=myBackpack
					stolen += 1
				end
			end
			if notify then notify("Volés: " .. stolen .. " item(s)", 2) end
			task.wait(0.1)
			refreshList()
		end)

		refreshList()

		local refreshConn
		refreshConn = task.spawn(function()
			while win and win.Parent do
				task.wait(2)
				if win and win.Parent then refreshList() end
			end
		end)
		win.Destroying:Cn(function()
			if refreshConn then pcall(task.cancel, refreshConn) end
		end)
	end

	invBtn.MouseButton1Click:Cn(showInventoryGui)

	skinBtn.MouseButton1Click:Cn(function()
		local target = plr.Character
		if not target then return end
		updateCharacter()
		if not character then return end
		local copied = 0
		for _, part in ipairs(target:GD()) do
			if part:IsA("Clothing") or part:IsA("BodyColors") or part:IsA("Accessory") or part:IsA("ShirtGraphic") then
				local clone = part:Cl()
				local name = clone.Name
				if name == "BodyColors" then
					local existing = character:FFCOC("BodyColors")
					if existing then existing:D() end
				end
				for _, existing in ipairs(character:GD()) do
					if existing:IsA("Accessory") and existing.Name == clone.Name then
						existing:D()
					end
				end
				clone.Pa=character
				copied += 1
			end
		end
		local hum = character:FFCOC("Humanoid")
		if hum then
			hum:ApplyDescription(hum:GetAppliedDescription())
		end
		local note = I.n("TextLabel")
		note.S=U2(0, 220, 0, 30)
		note.P=U2(0.5, -110, 0, 80)
		note.BTr=1
		note.T=copied > 0 and "Skin copié en local (" .. copied .. ")" or "Rien à copier"
		note.F=E.F.GothamBold
		note.TSz=13
		note.TC3=copied > 0 and C3(120, 255, 180) or C3(255, 120, 120)
		note.ZIndex = 200
		note.Pa=screenGui
		tween(note, {TT=0}, 0.3)
		task.delay(2.5, function()
			tween(note, {TT=1}, 0.3)
			task.delay(0.35, function() if note then note:D() end end)
		end)
	end)

	task.spawn(function()
		while card.Parent do
			task.wait(0.6)
			updateCharacter()
			local char = plr.Character
			if char and rootPart then
				local hrp = char:FFC("HumanoidRootPart")
				if hrp then
					local dist = (hrp.Position - rootPart.Position).Magnitude
					distLbl.T="Distance: " .. math.floor(dist) .. " studs"
					distLbl.TC3=dist < 50 and C3(120, 255, 120) or dist < 200 and C3(255, 200, 100) or C3(255, 120, 120)
				else
					distLbl.T="Distance: N/A"
				end
				local h = char:FFCOC("Humanoid")
				if h then
					hpLbl.T="HP: " .. math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth)
					speedLbl.T="Vit: " .. math.floor(h.WalkSpeed) .. " | Saut: " .. math.floor(h.JumpPower)

					local hrp = char:FFC("HumanoidRootPart")
					local stateT="Standing"
					local moveFlag = false
					if h.Health <= 0 then
						stateT="Dead"
					elseif h.Sit then
						stateT="Seated"
					elseif h:GetState() == E.HumanoidStateType.Jumping then
						stateT="Jumping"
					elseif h:GetState() == E.HumanoidStateType.Freefall then
						stateT="Falling"
					elseif hrp then
						local vel = hrp.AssemblyLinearVelocity
						local flatSpeed = V3(vel.X, 0, vel.Z).Magnitude
						local vSpeed = math.abs(vel.Y)
						local floorY = hrp.Position.Y - 3
						local isAirborne = (floorY > 20 and vSpeed > 15) or (vSpeed > 70)
						if flatSpeed > 2 then
							stateT=(h.WalkSpeed > 18 or flatSpeed > 18) and "Running" or "Walking"
						end
						local suspiciousHorizontal = (flatSpeed > 55) or (flatSpeed > 35 and flatSpeed > h.WalkSpeed * 2.2)
						local suspiciousVertical = (vSpeed > 90)
						local suspiciousAirborne = isAirborne and (flatSpeed > 25 or vSpeed > 60)
						local now = tick()
						local reason = ""
						if suspiciousHorizontal then
							reason = "Vit. " .. math.floor(flatSpeed) .. " (max " .. math.floor(h.WalkSpeed) .. ")"
						elseif suspiciousVertical then
							reason = "Air " .. math.floor(vSpeed) .. " studs/s"
						elseif suspiciousAirborne then
							reason = "Airborne " .. math.floor(flatSpeed) .. "/s"
						end
						if suspiciousHorizontal or suspiciousVertical or suspiciousAirborne then
							lastMoveFlagAt = now
							lastMoveReason = reason
							moveFlag = true
						elseif now - lastMoveFlagAt < MOVE_FLAG_DURATION then
							moveFlag = true
						end
					end
					statusLbl.T="Statut: " .. stateText
					pcall(function()
						if moveFlag then
							moveBadge.V=true
							moveDetail.T="🔺 " .. lastMoveReason
							local ts = os.date("%H:%M:%S")
							local line = "[" .. ts .. "] " .. stateText .. " — " .. lastMoveReason
							if not cheatNotes.Text:find(line, 1, true) then
								if #cheatNotes.Text > 0 then
									cheatNotes.T=line .. "\n" .. cheatNotes.Text
								else
									cheatNotes.T=line
								end
								if #cheatNotes.Text > 240 then
									cheatNotes.T=cheatNotes.Text:sub(1, 240) .. "…"
								end
							end
							card.BC3=C3(38, 25, 25)
							createStroke(card, C3(160, 70, 70), 1.2)
						else
							moveBadge.V=false
							moveDetail.T=""
							card.BC3=C3(28, 28, 35)
							createStroke(card, C3(45, 45, 55), 1)
						end
						local now2 = tick()
						if now2 - lastChatCheck > 0.5 then
							lastChatCheck = now2
							local seenChat = plr.UserId and _G._chatSeenPls[plr.UserId]
							local sinceChat = seenChat and (now2 - seenChat) or math.huge
							playerChatBadge.V=(seenChat and sinceChat <= 600)
						end
					end)
				else
					hpLbl.T="HP: mort"
					speedLbl.T="Vit: ? | Saut: ?"
					statusLbl.T="Statut: ?"
				end
			else
				distLbl.T="Distance: N/A"
				hpLbl.T="HP: N/A"
				speedLbl.T="Vit: N/A | Saut: N/A"
				statusLbl.T="Statut: N/A"
			end
		end
	end)

	local connTimeLbl = I.n("TextLabel")
	connTimeLbl.S=U2(0.55, -6, 0, 14)
	connTimeLbl.P=U2(0, 6, 0, 116)
	connTimeLbl.BTr=1
	connTimeLbl.T="Connecté: ?"
	connTimeLbl.F=E.F.Gotham
	connTimeLbl.TSz=10
	connTimeLbl.TC3=C3(160, 200, 240)
	connTimeLbl.TXA=E.TX.Left
	connTimeLbl.Pa=card

	local arrivalBadge = I.n("TextLabel")
	arrivalBadge.S=U2(0.55, -6, 0, 14)
	arrivalBadge.P=U2(0, 6, 0, 130)
	arrivalBadge.BTr=1
	arrivalBadge.T=""
	arrivalBadge.F=E.F.GothamSemibold
	arrivalBadge.TSz=10
	arrivalBadge.TC3=C3(255, 200, 80)
	arrivalBadge.TXA=E.TX.Left
	arrivalBadge.Pa=card

	local infoBtn = I.n("TextButton")
	infoBtn.S=U2(0, 24, 0, 24)
	infoBtn.P=U2(1, -32, 0, 4)
	infoBtn.BC3=C3(60, 60, 100)
	infoBtn.T="i"
	infoBtn.F=E.F.GothamBold
	infoBtn.TSz=13
	infoBtn.TC3=C3(180, 200, 255)
	infoBtn.BSP=0
	infoBtn.ABC=false
	infoBtn.Pa=card
	createCorner(infoBtn, 12)

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
					connTimeLbl.T=string.format("Connecté: %dh %dm %ds", hrs, mins, secs)
				elseif mins > 0 then
					connTimeLbl.T=string.format("Connecté: %dm %ds", mins, secs)
				else
					connTimeLbl.T=string.format("Connecté: %ds", secs)
				end

				local bootRef = _JOIN_TIMESTAMPS["__panelBoot__"] or firstSeenTick
				if seen <= bootRef + 0.5 then
					arrivalBadge.T="● Là depuis l'ouverture du panel"
					arrivalBadge.TC3=C3(120, 200, 255)
				else
					local late = math.floor(now - seen)
					arrivalBadge.T=string.format("● Arrivé il y a %ds", late)
					arrivalBadge.TC3=C3(180, 220, 140)
				end
				end) -- ferme pcall
				task.wait(1)
				end -- ferme while
				end) -- ferme task.spawn

	infoBtn.MouseButton1Click:Cn(function()
		pcall(function()
			local existing = screenGui:FFC("_InfoPanel_" .. plr.Name)
			if existing then existing:D() return end

			local win = I.n("Frame")
			win.N="_InfoPanel_" .. plr.Name
			win.S=U2(0, 380, 0, 500)
			win.P=U2(0.5, -190, 0.5, -250)
			win.BC3=C3(20, 20, 26)
			win.BTr=0.05
			win.BSP=0
			win.A=true
			win.Draggable = true
			win.Pa=screenGui
			createCorner(win, 10)
			createStroke(win, C3(120, 80, 255), 1.2)

			local title = I.n("TextLabel")
			title.S=U2(1, -100, 0, 28)
			title.P=U2(0, 10, 0, 0)
			title.BTr=1
			title.T="Détails : @" .. plr.Name
			title.F=E.F.GothamBold
			title.TSz=14
			title.TC3=C3(255, 255, 255)
			title.TXA=E.TX.Left
			title.Pa=win

			local copyBtn = I.n("TextButton")
			copyBtn.S=U2(0, 60, 0, 22)
			copyBtn.P=U2(1, -100, 0, 6)
			copyBtn.BC3=C3(60, 120, 200)
			copyBtn.T="📋 Copier"
			copyBtn.F=E.F.GothamBold
			copyBtn.TSz=11
			copyBtn.TC3=C3(255, 255, 255)
			copyBtn.BSP=0
			copyBtn.Pa=win
			createCorner(copyBtn, 4)

			local closeX = I.n("TextButton")
			closeX.S=U2(0, 26, 0, 26)
			closeX.P=U2(1, -32, 0, 4)
			closeX.BC3=C3(180, 60, 60)
			closeX.T="X"
			closeX.F=E.F.GothamBold
			closeX.TSz=13
			closeX.TC3=C3(255, 255, 255)
			closeX.BSP=0
			closeX.Pa=win
			createCorner(closeX, 6)
			closeX.MouseButton1Click:Cn(function() win:D() end)

			local scrollFrame = I.n("ScrollingFrame")
			scrollFrame.N="InfoScroll"
			scrollFrame.S=U2(1, -20, 1, -40)
			scrollFrame.P=U2(0, 10, 0, 32)
			scrollFrame.BTr=1
			scrollFrame.BSP=0
			scrollFrame.SBT=6
			scrollFrame.ScrollBarIC3=C3(120, 80, 255)
			scrollFrame.CanvasS=U2(0, 0, 0, 1500)
			scrollFrame.AutomaticCanvasS=E.AutomaticSize.Y
			scrollFrame.Pa=win
			createCorner(scrollFrame, 4)

			pcall(function()
				local img = I.n("ImageLabel")
				img.N="AvatarImg"
				img.S=U2(0, 72, 0, 72)
				img.P=U2(0, 8, 0, 4)
				img.BC3=C3(40, 40, 50)
				img.BSP=0
				img.Pa=scrollFrame
				createCorner(img, 36)
				local ok, content = pcall(function()
					return Pls:GUTA(plr.UserId, E.ThumbnailType.HeadShot, E.ThumbnailSize.Size150x150)
				end)
				if ok and content then
					img.Im=content
				else
					img.Im="rbxassetid://0"
				end
			end)

			local infoT=I.n("TextLabel")
			infoText.N="InfoText"
			infoText.S=U2(1, -100, 0, 1500)
			infoText.P=U2(0, 88, 0, 4)
			infoText.BTr=1
			infoText.TXA=E.TX.Left
			infoText.TYA=E.TY.Top
			infoText.F=E.F.Gotham
			infoText.TSz=13
			infoText.TC3=C3(240, 240, 255)
			infoText.TW=true
			infoText.Pa=scrollFrame

			local allLines = {}
			local function setText(lines)
				if type(lines) == "table" then
					allLines = lines
				else
					allLines = {tostring(lines)}
				end
				infoText.T=table.concat(allLines, "\n")
			end
			copyBtn.MouseButton1Click:Cn(function()
				local txt = table.concat(allLines, "\n")
				pcall(function()
					if setclipboard then
						setclipboard(txt)
					elseif toclipboard then
						toclipboard(txt)
					end
				end)
				copyBtn.T="✓ Copié"
				copyBtn.BC3=C3(60, 180, 100)
				task.delay(1.5, function()
					if copyBtn and copyBtn.Parent then
						copyBtn.T="📋 Copier"
						copyBtn.BC3=C3(60, 120, 200)
					end
				end)
			end)

			local days = plr.AccountAge
			local years = math.floor(days / 365)
			local rem = days - years * 365
			local myUserId = LP and LP.UserId or 0
			local isFriend = false
			pcall(function()
				if LP and LP:IsFriendsWith(plr.UserId) then isFriend = true end
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

			task.spawn(function()
				local extra = {}
				pcall(function()
					local resp = game:HGet("https://users.roblox.com/v1/users/" .. plr.UserId, true)
					if resp and resp ~= "" then
						local d = HS:JSD(resp)
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
					local resp = game:HGet("https://friends.roblox.com/v1/users/" .. plr.UserId .. "/friends/count")
					if resp and resp ~= "" then
						local d = HS:JSD(resp)
						if d and d.count then
							table.insert(extra, "Amis : " .. tostring(d.count))
						end
					end
				end)
				pcall(function()
					local resp = game:HGet("https://users.roblox.com/v1/users/" .. plr.UserId .. "/groups")
					if resp and resp ~= "" then
						local d = HS:JSD(resp)
						if d and d.data and #d.data > 0 then
							local n = math.min(3, #d.data)
							for i = 1, n do
								table.insert(extra, "Groupe : " .. (d.data[i].group and d.data[i].group.name or "?"))
							end
						end
					end
				end)
				local apiOk = false
				pcall(function()
					if game and game.HttpGet then
						local test = game:HGet("https://users.roblox.com/v1/users/" .. plr.UserId)
						if test and test ~= "" then apiOk = true end
					end
				end)
				if not apiOk then
					table.insert(extra, "---")
					table.insert(extra, "! APIs Roblox bloquees par l'exécuteur")
					table.insert(extra, "(présence, favoris, profil détaillés indisponibles)")
				else
					pcall(function()
						local resp = game:HGet("https://presence.roblox.com/v1/presence/users", true, HS:JSE({userIds = {plr.UserId}}))
						if resp and resp ~= "" then
							local d = HS:JSD(resp)
							if d and d.userPresences and d.userPresences[1] then
								local p = d.userPresences[1]
								local t = tonumber(p.userPresenceType) or 0
								local status = "Inconnu"
								local statusIcon = "○"
								if t == 3 then
									status = "Hors ligne"
									statusIcon = "○"
								elseif t == 2 then
									status = "Au Studio (développeur)"
									statusIcon = "🛠"
								elseif t == 1 then
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
									if p.lastLocation and p.lastLocation ~= "" then
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
					pcall(function()
						local resp = game:HGet("https://games.roblox.com/v1/users/" .. plr.UserId .. "/favorite/games?sortOrder=Desc&limit=5")
						if resp and resp ~= "" then
							local d = HS:JSD(resp)
							if d and d.data and #d.data > 0 then
								table.insert(extra, "--- Jeux favoris (" .. #d.data .. ") ---")
								for i, g in ipairs(d.data) do
									if i > 5 then break end
									if g.name then
										local favN=g.name:sub(1, 40) .. (g.name:len() > 40 and "..." or "")
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
					table.insert(extra, "---")
					local mt = tostring(plr.MembershipType):gsub("E.MembershipType.", "")
					local isPremium = (mt == "Premium" or plr.MembershipType == E.MembershipType.Premium)
					table.insert(extra, "💎 " .. (isPremium and "Premium" or "Non-Premium") .. (mt ~= "None" and mt ~= "Premium" and (" (" .. mt .. ")") or ""))
					pcall(function()
						local ping = plr:GetNetworkPing()
						local pingIcon = "🟢"
						if ping > 0.2 then pingIcon = "🟡" elseif ping > 0.4 then pingIcon = "🔴" end
						table.insert(extra, pingIcon .. " Ping : " .. math.floor(ping * 1000) .. " ms")
					end)
					if LP and plr ~= LP then
						pcall(function()
							local isFriend = LP:IsFriendsWith(plr.UserId)
							if isFriend then
								table.insert(extra, "👥 Ami avec toi : OUI")
							end
						end)
					end
					if plr ~= LP then
						local placeId = game.PlaceId
						pcall(function()
							local hasAsset = game:GetService("MPS"):UserOwnsGamePassAsync(plr.UserId, 0)
						end)
						if plr.GameId and tostring(plr.GameId) == tostring(placeId) then
							table.insert(extra, "★ EST DANS CE JEU MAINTENANT")
						end
					end
					end
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
	if plr == LP then return end
	if playerCards[plr] and playerCards[plr].Parent then return end
	createPlayerEntry(plr)
	playersScroll.CanvasS=U2(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

local function removePlayerCard(plr)
	if playerCards[plr] then
		playerCards[plr]:D()
		playerCards[plr] = nil
	end
	if selectedEchoPlayer == plr then
		selectedEchoPlayer = nil
		echoStatusLabel.T="Echo: aucun"
		echoStatusLabel.TC3=C3(160, 160, 160)
	end
	playersScroll.CanvasS=U2(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

local function refreshPlsList()
	local existing = {}
	for plr, card in pairs(playerCards) do
		if card and card.Parent then
			existing[plr] = true
		else
			playerCards[plr] = nil
		end
	end
	for _, plr in ipairs(Pls:GetPls()) do
		if plr ~= LP and not existing[plr] then
			createPlayerEntry(plr)
		end
	end
	playersScroll.CanvasS=U2(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end

Pls.PlayerAdded:Cn(function(plr)
	task.wait(0.3)
	addPlayerCard(plr)
end)
Pls.PlayerRemoving:Cn(function(plr)
	task.wait(0.1)
	removePlayerCard(plr)
end)
playersLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Cn(function()
	playersScroll.CanvasS=U2(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
end)
refreshPlsList()

if panelMemory.lastEchoPlayerName and not panelMemory.dontAskRestore then
	task.delay(1.5, function()
		showRestorePopup(panelMemory.lastEchoPlayerName)
	end)
end

for plr, card in pairs(playerCards) do
	if card then
		card.V=true
	end
end

local function sendEchoMessage(text)
	local channels = TextChatService:FFC("TextChannels")
	if not channels then return end
	local general = channels:FFC("RBXGeneral")
	if not general then return end
	pcall(function() general:SendAsync(text) end)
end

TextChatService.MessageReceived:Cn(function(msg)
	if not selectedEchoPlayer then return end
	local src = msg.TextSource
	if not src then return end
	local sender = Pls:GPBU(src.UserId)
	if sender ~= selectedEchoPlayer then return end
	task.spawn(sendEchoMessage, msg.Text)
end)

local espFolder = I.n("Folder")
espFolder.N="PanelESP"
espFolder.Pa=WS

local espState = { enabled = false, individual = {}, chatIcons = true }

local function distanceColor(dist)
	if dist < 50 then return C3(80, 255, 120)
	elseif dist < 200 then return C3(255, 200, 80)
	else return C3(255, 80, 80) end
end

local function ensureESPForPlayer(plr)
	if espState.individual[plr] then return espState.individual[plr] end
	local data = { hl = nil, bill = nil, label = nil, targetPt=nil, humanoid = nil }
	espState.individual[plr] = data
	return data
end

local function buildESP(plr)
	local data = ensureESPForPlayer(plr)
	local char = plr.Character
	if not char then return end
	local hum = char:FFCOC("Humanoid")
	local targetPt=char:FFC("Head") or char:FFC("HumanoidRootPart")
	if not targetPart then return end

	if data.hl and data.hl.Adornee ~= char then data.hl:D() data.hl = nil end
	if not data.hl or not data.hl.Parent then
		data.hl = I.n("Highlight")
		data.hl.Adornee = char
		data.hl.FillTr=0.65
		data.hl.OutlineTr=0.15
		data.hl.OutlineC=Color3.new(1, 1, 1)
		data.hl.DepthMode = E.HighlightDepthMode.AlwaysOnTop
		data.hl.Pa=espFolder
	end

	if data.bill and data.bill.Adornee ~= targetPart then data.bill:D() data.bill = nil end
	if not data.bill or not data.bill.Parent then
		data.bill = I.n("BillboardGui")
		data.bill.Adornee = targetPart
		data.bill.S=U2(0, 220, 0, 46)
		data.bill.StudsOffset = V3(0, 3, 0)
		data.bill.AlwaysOnTop = true
		data.bill.Pa=espFolder

		data.label = I.n("TextLabel")
		data.label.S=U2(1, 0, 1, 0)
		data.label.BTr=1
		data.label.F=E.F.GothamSemibold
		data.label.TSz=13
		data.label.TC3=Color3.new(1, 1, 1)
		data.label.TextStrokeTr=0.3
		data.label.Pa=data.bill

		data.chatIcon = I.n("TextLabel")
		data.chatIcon.S=U2(0, 20, 0, 20)
		data.chatIcon.P=U2(0, 226, 0, 0)
		data.chatIcon.BTr=1
		data.chatIcon.T="💬"
		data.chatIcon.F=E.F.GothamBold
		data.chatIcon.TSz=14
		data.chatIcon.TC3=Color3.new(1, 1, 1)
		data.chatIcon.TextStrokeTr=0.2
		data.chatIcon.V=false
		data.chatIcon.Pa=data.bill
	end
	data.targetPt=targetPart
	data.humanoid = hum
	data.canChat = nil
	_G._resolveCanChat(plr, function(canChat, src)
		if data then data.canChat = canChat end
		data.canChatSrc = src
	end)
	return data
end

local function clearESP()
	for _, child in ipairs(espFolder:GC()) do child:D() end
	espState.individual = {}
end

local function refreshESP()
	if not (espState.enabled or globalESPEnabled) then return end
	for _, plr in ipairs(Pls:GetPls()) do
		if plr ~= LP then
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

RS.RenderStepped:Cn(function()
	updateCharacter()
	if not rootPart then return end
	for plr, data in pairs(espState.individual) do
		if data.active and data.targetPart and data.targetPart.Parent then
			local dist = (data.targetPart.Position - rootPart.Position).Magnitude
			if data.chatIcon then
				data.chatIcon.V=espState.chatIcons and (data.canChat == true)
			end
			if data.blink then
				local pulse = (tick() % 0.5) < 0.25
				if data.hl then
					data.hl.FillC=pulse and C3(255, 255, 0) or C3(255, 0, 0)
					data.hl.FillTr=pulse and 0.35 or 0.75
					data.hl.OutlineC=pulse and C3(255, 255, 255) or C3(255, 0, 0)
					data.hl.Enabled = true
				end
				if data.label then
					local hp = data.humanoid and math.floor(data.humanoid.Health) or 0
					data.label.T=">> " .. plr.Name .. " [" .. math.floor(dist) .. " studs] HP:" .. hp
					data.label.TC3=pulse and C3(255, 255, 0) or C3(255, 0, 0)
				end
				if data.bill then data.bill.Enabled = true end
			else
				local col = distanceColor(dist)
				if data.label then
					local hp = data.humanoid and math.floor(data.humanoid.Health) or 0
					data.label.T=plr.Name .. " [" .. math.floor(dist) .. " studs] HP:" .. hp
					data.label.TC3=col
				end
				if data.hl then
					data.hl.FillC=col
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
	if plr == LP then return end
	if not plr.Character then return end
	local hrp = plr.Character:FFC("HumanoidRootPart")
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

for _, plr in ipairs(Pls:GetPls()) do
	if plr ~= LP then
		plr.CharacterAdded:Cn(function()
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

Pls.PlayerAdded:Cn(function(plr)
	if plr == LP then return end
	plr.CharacterAdded:Cn(function()
		task.wait(0.3)
		if espState.enabled then applyGlobalESPToPlayer(plr) end
	end)
end)

task.spawn(function()
	while true do
		task.wait(60)
		refreshESP()
	end
end)

local function typewriterEffect(label, text, speed)
	speed = speed or 0.02
	local chars = text:split("")
	local current = ""
	for i = 1, #chars do
		current = current .. chars[i]
		label.T=current
		task.wait(speed)
	end
end

local function matrixRain(parent, duration)
	duration = duration or 1
	local letters = {"0","1","/","\\","[","]","{","}","<",">","#","@","%","&","*","+","-","=","?","!"}
	local startTime = tick()
	local con
	con = RS.RenderStepped:Cn(function()
		if tick() - startTime > duration then
			con:DC()
			return
		end
		for i = 1, 8 do
			local lbl = I.n("TextLabel")
			lbl.S=U2(0, 12, 0, 16)
			lbl.P=U2(math.random(), 0, math.random(-0.15, 0.1), 0)
			lbl.BTr=1
			lbl.T=letters[math.random(1, #letters)]
			lbl.F=E.F.Code
			lbl.TSz=math.random(9, 14)
			lbl.TC3=C3(0, 255, 120)
			lbl.TT=math.random(30, 70) / 100
			lbl.ZIndex = 99
			lbl.Pa=parent
			local speed = math.random(12, 35) / 10
			tween(lbl, {P=U2(lbl.Position.X.Scale, 0, 1.2, 0), TT=1}, speed)
			task.delay(speed + 0.1, function() if lbl then lbl:D() end end)
		end
	end)
end

local function bootSequence(onComplete)
	local bootGui = I.n("ScreenGui")
	bootGui.N="MilanEmerickBoot"
	bootGui.ResetOnSpawn = false
	bootGui.DisplayOrder = 99999
	bootGui.IgnoreGuiInset = true
	bootGui.Pa=LP:WFC("PlayerGui")

	local screenW = workspace.CurrentCamera.ViewportSize.X
	local screenH = workspace.CurrentCamera.ViewportSize.Y

	local backdrop = I.n("Frame")
	backdrop.S=U2(1, 0, 1, 0)
	backdrop.BC3=C3(0, 0, 0)
	backdrop.BTr=0
	backdrop.BSP=0
	backdrop.ZIndex = 100
	backdrop.Pa=bootGui

	local vignette = I.n("ImageLabel")
	vignette.N="Vignette"
	vignette.S=U2(1.5, 0, 1.5, 0)
	vignette.P=U2(-0.25, 0, -0.25, 0)
	vignette.BTr=1
	vignette.Im="rbxassetid://9638773891"
	vignette.IC3=C3(0, 0, 0)
	vignette.IT=0.5
	vignette.ZIndex = 101
	vignette.Pa=backdrop

	local particleLetters = {"0","1","A","B","C","X","Y","Z","<",">","/","\\","{","}","#","@","%","&","*","+","-","=","?","!","#","$","O","M","E"}
	local particles = {}
	for i = 1, 60 do
		local p = I.n("TextLabel")
		p.S=U2(0, math.random(10, 18), 0, math.random(12, 22))
		p.P=U2(math.random() * 1.1 - 0.05, 0, -0.1, 0)
		p.BTr=1
		p.T=particleLetters[math.random(1, #particleLetters)]
		p.F=(math.random() > 0.5) and E.F.Code or E.F.GothamBold
		p.TSz=math.random(10, 22)
		p.TC3=C3(0, 255, math.random(80, 200))
		p.TT=0.3
		p.TextStrokeTr=0.6
		p.Rotation = math.random(-15, 15)
		p.ZIndex = 102
		p.Pa=backdrop
		table.insert(particles, p)
	end

	local title = I.n("TextLabel")
	title.N="BootTitle"
	title.S=U2(1, 0, 0, 90)
	title.P=U2(0, 0, 0.32, 0)
	title.BTr=1
	title.T=""
	title.F=E.F.GothamBlack
	title.TSz=72
	title.TC3=C3(255, 255, 255)
	title.TextStrokeColor3 = C3(0, 200, 255)
	title.TextStrokeTr=0.4
	title.TT=1
	title.ZIndex = 200
	title.Pa=backdrop

	local subtitle = I.n("TextLabel")
	subtitle.S=U2(1, 0, 0, 28)
	subtitle.P=U2(0, 0, 0.46, 0)
	subtitle.BTr=1
	subtitle.T="[ SYSTEM BOOT // INITIALIZING ]"
	subtitle.F=E.F.Code
	subtitle.TSz=16
	subtitle.TC3=C3(0, 255, 180)
	subtitle.TT=1
	subtitle.ZIndex = 200
	subtitle.Pa=backdrop

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
		local l = I.n("TextLabel")
		l.S=U2(0.6, 0, 0, 18)
		l.P=U2(0.05, 0, 0.55, (i-1) * 20)
		l.BTr=1
		l.T=""
		l.F=E.F.Code
		l.TSz=12
		l.TC3=C3(0, 255, 120)
		l.TT=1
		l.TXA=E.TX.Left
		l.ZIndex = 200
		l.Pa=backdrop
		logs[i] = l
	end

	local progTrack = I.n("Frame")
	progTrack.S=U2(0.4, 0, 0, 4)
	progTrack.P=U2(0.3, 0, 0.82, 0)
	progTrack.BC3=C3(40, 40, 50)
	progTrack.BSP=0
	progTrack.ZIndex = 200
	progTrack.Pa=backdrop

	local progFill = I.n("Frame")
	progFill.S=U2(0, 0, 1, 0)
	progFill.BC3=C3(0, 200, 255)
	progFill.BSP=0
	progFill.ZIndex = 201
	progFill.Pa=progTrack

	local pctLabel = I.n("TextLabel")
	pctLabel.S=U2(0.2, 0, 0, 24)
	pctLabel.P=U2(0.4, 0, 0.84, 0)
	pctLabel.BTr=1
	pctLabel.T="0%"
	pctLabel.F=E.F.Code
	pctLabel.TSz=14
	pctLabel.TC3=C3(0, 200, 255)
	pctLabel.TT=1
	pctLabel.ZIndex = 200
	pctLabel.Pa=backdrop

	local scanline = I.n("Frame")
	scanline.S=U2(1, 0, 0, 2)
	scanline.P=U2(0, 0, 0, 0)
	scanline.BC3=C3(0, 200, 255)
	scanline.BTr=0.3
	scanline.BSP=0
	scanline.ZIndex = 150
	scanline.Pa=backdrop

	local glitchBars = {}
	for i = 1, 3 do
		local gb = I.n("Frame")
		gb.S=U2(1, 0, 0, math.random(2, 8))
		gb.P=U2(0, 0, math.random() * 0.8 + 0.1, 0)
		gb.BC3=C3(0, 200, 255)
		gb.BTr=0.5
		gb.BSP=0
		gb.ZIndex = 180
		gb.Pa=backdrop
		table.insert(glitchBars, gb)
	end

	task.spawn(function()
		local ti = TweenInfo.new
	local shardLetters = {"0","1","X","Y","Z","#","@","%","&","*","/","\\","M","E","O","G","[","]","{","}","<",">","!","?","$","+","-","="}
	local shardCount = 35
	local shards = {}
	for i = 1, shardCount do
		local s = I.n("TextLabel")
		s.S=U2(0, math.random(16, 38), 0, math.random(18, 44))
		s.P=U2(math.random() * 0.95, 0, math.random() * 0.95, 0)
		s.BTr=1
		s.T=shardLetters[math.random(1, #shardLetters)]
		s.F=(math.random() > 0.5) and E.F.Code or E.F.GothamBold
		s.TSz=math.random(14, 32)
		local colChoice = math.random(1, 6)
		if colChoice == 1 then s.TC3=C3(255, 60, 80) -- rouge
		elseif colChoice == 2 then s.TC3=C3(60, 255, 120) -- vert
		elseif colChoice == 3 then s.TC3=C3(80, 160, 255) -- bleu
		elseif colChoice == 4 then s.TC3=C3(255, 230, 60) -- jaune
		elseif colChoice == 5 then s.TC3=C3(255, 80, 220) -- magenta
		else s.TC3=C3(60, 240, 255) end -- cyan
		s.TextStrokeColor3 = C3(0, 0, 0)
		s.TextStrokeTr=0.3
		s.TT=1 -- invisible au depart, on les fait apparaitre en saccade
		s.Rotation = math.random(-30, 30)
		s.ZIndex = 105
		s.Pa=backdrop
		table.insert(shards, s)
	end

	local scratchLines = {}
	for i = 1, 8 do
		local line = I.n("Frame")
		line.S=U2(0, math.random(120, 280), 0, math.random(1, 3))
		line.P=U2(math.random() * 0.8, 0, math.random() * 0.95, 0)
		line.BC3=(math.random() > 0.5) and C3(255, 100, 100) or C3(100, 200, 255)
		line.BTr=1
		line.BSP=0
		line.Rotation = math.random(-45, 45)
		line.ZIndex = 110
		line.Pa=backdrop
		table.insert(scratchLines, line)
	end

	local fractureLines = {}
	for i = 1, 4 do
		local fl = I.n("Frame")
		fl.S=U2(1.2, 0, 0, 2)
		fl.P=U2(-0.1, 0, math.random() * 0.9, 0)
		fl.BC3=C3(255, 255, 255)
		fl.BTr=1
		fl.BSP=0
		fl.ZIndex = 108
		fl.Pa=backdrop
		table.insert(fractureLines, fl)
	end

	task.spawn(function()
		for pass = 1, 3 do
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TT=math.random(20, 50) / 100}, 0.05)
				end)
				task.wait(0.02 + math.random() * 0.03)
			end
			task.wait(0.15)
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TT=1}, 0.05)
				end)
				task.wait(0.01)
			end
			task.wait(0.1)
		end
		for i, s in ipairs(shards) do
			task.spawn(function()
				tween(s, {TT=0.4}, 0.2)
			end)
			task.wait(0.02)
		end
		for i = 1, 5 do
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BTr=0.4}, 0.04)
				end)
			end
			task.wait(0.08)
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BTr=1}, 0.05)
				end)
			end
			task.wait(0.06)
		end
		for _, fl in ipairs(fractureLines) do
			task.spawn(function()
				tween(fl, {BTr=0.5}, 0.06)
				task.wait(0.1)
				tween(fl, {BTr=1}, 0.1)
			end)
			task.wait(0.08)
		end
		task.wait(0.5)
		for i, s in ipairs(shards) do
			if s and s.Parent then tween(s, {TT=1}, 0.4) end
		end
		for _, l in ipairs(scratchLines) do
			if l and l.Parent then tween(l, {BTr=1}, 0.3) end
		end
		for _, fl in ipairs(fractureLines) do
			if fl and fl.Parent then tween(fl, {BTr=1}, 0.3) end
		end
	end)

	local shardLetters = {"0","1","X","Y","Z","#","@","%","&","*","/","\\","M","E","O","G","[","]","{","}","<",">","!","?","$","+","-","="}
	local shardCount = 35
	local shards = {}
	for i = 1, shardCount do
		local s = I.n("TextLabel")
		s.S=U2(0, math.random(16, 38), 0, math.random(18, 44))
		s.P=U2(math.random() * 0.95, 0, math.random() * 0.95, 0)
		s.BTr=1
		s.T=shardLetters[math.random(1, #shardLetters)]
		s.F=(math.random() > 0.5) and E.F.Code or E.F.GothamBold
		s.TSz=math.random(14, 32)
		local colChoice = math.random(1, 6)
		if colChoice == 1 then s.TC3=C3(255, 60, 80)
		elseif colChoice == 2 then s.TC3=C3(60, 255, 120)
		elseif colChoice == 3 then s.TC3=C3(80, 160, 255)
		elseif colChoice == 4 then s.TC3=C3(255, 230, 60)
		elseif colChoice == 5 then s.TC3=C3(255, 80, 220)
		else s.TC3=C3(60, 240, 255) end
		s.TextStrokeColor3 = C3(0, 0, 0)
		s.TextStrokeTr=0.3
		s.TT=1
		s.Rotation = math.random(-30, 30)
		s.ZIndex = 105
		s.Pa=backdrop
		table.insert(shards, s)
	end

	local scratchLines = {}
	for i = 1, 8 do
		local line = I.n("Frame")
		line.S=U2(0, math.random(120, 280), 0, math.random(1, 3))
		line.P=U2(math.random() * 0.8, 0, math.random() * 0.95, 0)
		line.BC3=(math.random() > 0.5) and C3(255, 100, 100) or C3(100, 200, 255)
		line.BTr=1
		line.BSP=0
		line.Rotation = math.random(-45, 45)
		line.ZIndex = 110
		line.Pa=backdrop
		table.insert(scratchLines, line)
	end

	local fractureLines = {}
	for i = 1, 4 do
		local fl = I.n("Frame")
		fl.S=U2(1.2, 0, 0, 2)
		fl.P=U2(-0.1, 0, math.random() * 0.9, 0)
		fl.BC3=C3(255, 255, 255)
		fl.BTr=1
		fl.BSP=0
		fl.ZIndex = 108
		fl.Pa=backdrop
		table.insert(fractureLines, fl)
	end

	task.spawn(function()
		for pass = 1, 3 do
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TT=math.random(20, 50) / 100}, 0.05)
				end)
				task.wait(0.02 + math.random() * 0.03)
			end
			task.wait(0.15)
			for i, s in ipairs(shards) do
				task.spawn(function()
					tween(s, {TT=1}, 0.05)
				end)
				task.wait(0.01)
			end
			task.wait(0.1)
		end
		for i, s in ipairs(shards) do
			task.spawn(function()
				tween(s, {TT=0.4}, 0.2)
			end)
			task.wait(0.02)
		end
		for i = 1, 5 do
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BTr=0.4}, 0.04)
				end)
			end
			task.wait(0.08)
			for _, l in ipairs(scratchLines) do
				task.spawn(function()
					tween(l, {BTr=1}, 0.05)
				end)
			end
			task.wait(0.06)
		end
		for _, fl in ipairs(fractureLines) do
			task.spawn(function()
				tween(fl, {BTr=0.5}, 0.06)
				task.wait(0.1)
				tween(fl, {BTr=1}, 0.1)
			end)
			task.wait(0.08)
		end
		task.wait(0.5)
		for i, s in ipairs(shards) do
			if s and s.Parent then tween(s, {TT=1}, 0.4) end
		end
		for _, l in ipairs(scratchLines) do
			if l and l.Parent then tween(l, {BTr=1}, 0.3) end
		end
		for _, fl in ipairs(fractureLines) do
			if fl and fl.Parent then tween(fl, {BTr=1}, 0.3) end
		end
	end)

		TSv:Create(scanline, ti(1.2, E.EasingStyle.Quad, E.EasingDirection.InOut), {P=U2(0, 0, 1, 0)}):Play()

		for i, p in ipairs(particles) do
			task.spawn(function()
				local dur = math.random(15, 30) / 10
				tween(p, {P=U2(p.Position.X.Scale, 0, 1.1, 0), TT=1}, dur)
				task.delay(dur + 0.1, function() if p and p.Parent then p:D() end end)
			end)
			task.wait(0.04)
		end

		title.TT=0
		local targetT="MILAN  x  EMERICK"
		local glitchChars = {"!", "@", "#", "$", "%", "&", "*", "X", "0", "1", "#", "$"}
		for i = 1, #targetText do
			if math.random() < 0.3 then
				title.T=title.Text .. glitchChars[math.random(1, #glitchChars)]
				task.wait(0.04)
				title.T=targetText:sub(1, i)
			else
				title.T=targetText:sub(1, i)
			end
			task.wait(0.06 + math.random() * 0.04)
		end

		for i = 1, 3 do
			tween(title, {TSz=76}, 0.1)
			task.wait(0.1)
			tween(title, {TSz=72}, 0.1)
			task.wait(0.1)
		end

		title.TextStrokeTr=0
		tween(subtitle, {TT=0.1}, 0.4)

		for _, gb in ipairs(glitchBars) do
			task.spawn(function()
				tween(gb, {P=U2(0, 0, math.random(), 0), BTr=0.9}, 0.2)
				task.wait(0.2)
				if gb and gb.Parent then gb:D() end
			end)
		end

		for i, log in ipairs(logs) do
			tween(log, {TT=0.3}, 0.2)
			local text = logTexts[i]
			for j = 1, #text do
				log.T=text:sub(1, j)
				task.wait(0.015)
			end
			local pct = i / #logTexts
			TSv:Create(progFill, ti(0.3), {S=U2(pct * 0.4, 0, 1, 0)}):Play()
			pctLabel.T=math.floor(pct * 100) .. "%"
			tween(pctLabel, {TT=0.2}, 0.2)
			if i == 3 or i == 6 then
				task.spawn(function()
					for _ = 1, 4 do
						title.P=U2(0, math.random(-3, 3), 0.32, math.random(-2, 2))
						task.wait(0.04)
					end
					title.P=U2(0, 0, 0.32, 0)
				end)
			end
			task.wait(0.15)
		end

		progFill.BC3=C3(0, 255, 120)
		TSv:Create(progFill, ti(0.3), {S=U2(0.4, 0, 1, 0)}):Play()
		pctLabel.T="100%"
		pctLabel.TC3=C3(0, 255, 120)
		task.wait(0.5)

		local flash = I.n("Frame")
		flash.S=U2(1, 0, 1, 0)
		flash.BC3=C3(255, 255, 255)
		flash.BTr=1
		flash.BSP=0
		flash.ZIndex = 500
		flash.Pa=backdrop
		tween(flash, {BTr=0.3}, 0.08)
		task.wait(0.08)
		tween(flash, {BTr=1}, 0.3)
		task.delay(0.4, function() if flash and flash.Parent then flash:D() end end)

		TSv:Create(title, ti(0.6, E.EasingStyle.Back, E.EasingDirection.In), {P=U2(0, 0, 0.45, 0), TSz=28, TT=0.5}):Play()
		TSv:Create(subtitle, ti(0.6), {TT=1}):Play()
		for _, log in ipairs(logs) do
			TSv:Create(log, ti(0.4), {TT=1}):Play()
		end
		TSv:Create(progTrack, ti(0.4), {BTr=1}):Play()
		TSv:Create(progFill, ti(0.4), {BTr=1}):Play()
		TSv:Create(pctLabel, ti(0.4), {TT=1}):Play()
		tween(backdrop, {BTr=1}, 0.7)

		for _, p in ipairs(particles) do
			if p and p.Parent then tween(p, {TT=1}, 0.4) end
		end

		task.wait(0.8)
	end)

	task.defer(function()
		local ok, err = pcall(function()
			for _ = 1, 50 do
				if not backdrop or not backdrop.Parent then break end
				task.wait(0.1)
			end
		end)
		if not ok then warn("[MILAN] boot crash: " .. tostring(err)) end
		pcall(function() if bootGui and bootGui.Parent then bootGui:D() end end)
		if onComplete then pcall(function() onComplete() end) end
	end)
end

local flyState = { flying = false, speed = 120, gyro = nil, vel = nil, loop = nil, mobileInput = Vector3.zero, mobileUp = false, mobileDown = false, mobileStickId = nil, mobileBase = nil, mobileKnob = nil, mobileBasePos = nil, mobileUiCreated = false }
local noclipState = { enabled = false }
local walkSpeedState = { value = 16 }
local jumpState = { infinite = false }
local platformState = { enabled = false, part = nil, y = 0, offset = 0 }

local function stopFly()
	if not flyState.flying then return end
	flyState.flying = false
	if flyState.loop then flyState.loop:DC() flyState.loop = nil end
	if flyState.gyro then flyState.gyro:D() flyState.gyro = nil end
	if flyState.vel then flyState.vel:D() flyState.vel = nil end
	flyState.mobileInput = Vector3.zero
	flyState.mobileUpHeld = false
	flyState.mobileDownHeld = false
	flyState.mobileStickId = nil
	if flyState.showMobileUi then flyState.showMobileUi(false) end
	updateCharacter()
	if humanoid then humanoid.PS=false end
	flySwitch.set(false)
	if protectionsState then
		protectionsState.antiTeleportGraceUntil = tick() + 0.4
	end
end

;(function(_fly, _screenGui)
	local function isMobile()
		return UIS.TouchEnabled and not UIS.KeyboardEnabled
	end
	local function ensureMobileUi()
		if _fly.mobileUiCreated then return end
		_fly.mobileUiCreated = true
		local base = I.n("Frame")
		base.N="FlyJoystickBase"
		base.S=U2(0, 110, 0, 110)
		base.P=U2(0, 30, 1, -240)
		base.BC3=C3(20, 20, 32)
		base.BTr=0.35
		base.BSP=0
		base.V=false
		base.ZIndex = 50
		base.Pa=_screenGui
		local bc = I.n("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Pa=base
		local bs = I.n("UIStroke")
		bs.C=C3(140, 100, 230)
		bs.Thickness = 2
		bs.Tr=0.4
		bs.Pa=base
		local knob = I.n("Frame")
		knob.N="Knob"
		knob.S=U2(0, 50, 0, 50)
		knob.P=U2(0.5, -25, 0.5, -25)
		knob.BC3=C3(180, 140, 255)
		knob.BSP=0
		knob.ZIndex = 51
		knob.Pa=base
		local kc = I.n("UICorner")
		kc.CornerRadius = UDim.new(1, 0)
		kc.Pa=knob
		local upBtn = I.n("TextButton")
		upBtn.N="FlyUp"
		upBtn.S=U2(0, 60, 0, 60)
		upBtn.P=U2(0, 30, 1, -130)
		upBtn.BC3=C3(20, 20, 32)
		upBtn.BTr=0.35
		upBtn.BSP=0
		upBtn.T="▲"
		upBtn.TC3=C3(140, 100, 230)
		upBtn.F=E.F.GothamBold
		upBtn.TSz=22
		upBtn.V=false
		upBtn.ZIndex = 50
		upBtn.Pa=_screenGui
		local uc = I.n("UICorner")
		uc.CornerRadius = UDim.new(1, 0)
		uc.Pa=upBtn
		local us = I.n("UIStroke")
		us.C=C3(140, 100, 230)
		us.Thickness = 2
		us.Tr=0.4
		us.Pa=upBtn
		local dnBtn = I.n("TextButton")
		dnBtn.N="FlyDown"
		dnBtn.S=U2(0, 60, 0, 60)
		dnBtn.P=U2(0, 100, 1, -130)
		dnBtn.BC3=C3(20, 20, 32)
		dnBtn.BTr=0.35
		dnBtn.BSP=0
		dnBtn.T="▼"
		dnBtn.TC3=C3(140, 100, 230)
		dnBtn.F=E.F.GothamBold
		dnBtn.TSz=22
		dnBtn.V=false
		dnBtn.ZIndex = 50
		dnBtn.Pa=_screenGui
		local dc = I.n("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Pa=dnBtn
		local ds = I.n("UIStroke")
		ds.C=C3(140, 100, 230)
		ds.Thickness = 2
		ds.Tr=0.4
		ds.Pa=dnBtn
		_fly.mobileBase = base
		_fly.mobileKnob = knob
		_fly.mobileUp = upBtn
		_fly.mobileDown = dnBtn
		base.InputBegan:Cn(function(input)
			if input.UserInputType == E.UserInputType.Touch then
				_fly.mobileStickId = input
			end
		end)
		upBtn.MouseButton1Down:Cn(function() _fly.mobileUpHeld = true end)
		upBtn.MouseButton1Up:Cn(function() _fly.mobileUpHeld = false end)
		dnBtn.MouseButton1Down:Cn(function() _fly.mobileDownHeld = true end)
		dnBtn.MouseButton1Up:Cn(function() _fly.mobileDownHeld = false end)
		upBtn.InputBegan:Cn(function(i) if i.UserInputType == E.UserInputType.Touch or i.UserInputType == E.UserInputType.MouseButton1 then _fly.mobileUpHeld = true end end)
		upBtn.InputEnded:Cn(function() _fly.mobileUpHeld = false end)
		dnBtn.InputBegan:Cn(function(i) if i.UserInputType == E.UserInputType.Touch or i.UserInputType == E.UserInputType.MouseButton1 then _fly.mobileDownHeld = true end end)
		dnBtn.InputEnded:Cn(function() _fly.mobileDownHeld = false end)
	end
	UIS.InputChanged:Cn(function(input, gpe)
		if not _fly.flying or not _fly.mobileStickId then return end
		if gpe then return end
		if input ~= _fly.mobileStickId then return end
		if input.UserInputState == E.UserInputState.End then
			_fly.mobileStickId = nil
			_fly.mobileInput = Vector3.zero
			if _fly.mobileKnob then _fly.mobileKnob.P=U2(0.5, -25, 0.5, -25) end
			return
		end
		local base = _fly.mobileBase
		if not base or not _fly.mobileKnob then return end
		local center = base.AbsolutePosition + base.AbsoluteSize / 2
		local radius = base.AbsoluteSize.X / 2
		local delta = input.Position - center
		local dist = math.min(delta.Magnitude, radius)
		local dir = delta.Magnitude > 0 and delta.Unit or Vector2.new(0, 0)
		local knobOffset = dir * dist
		_fly.mobileKnob.P=U2(0.5, knobOffset.X - 25, 0.5, knobOffset.Y - 25)
		_fly.mobileInput = V3(dir.X, 0, dir.Y)
	end)
	_fly.showMobileUi = function(visible)
		ensureMobileUi()
		if _fly.mobileBase then _fly.mobileBase.V=visible end
		if _fly.mobileUp then _fly.mobileUp.V=visible end
		if _fly.mobileDown then _fly.mobileDown.V=visible end
	end
	_fly.isMobile = isMobile
end)(flyState, screenGui)

local function startFly()
	updateCharacter()
	if flyState.flying or not rootPart then return end
	flyState.flying = true

	flyState.gyro = I.n("BodyGyro")
	flyState.gyro.P = 9e4
	flyState.gyro.MaxTo=V3(9e9, 9e9, 9e9)
	flyState.gyro.CF=rootPart.CFrame
	flyState.gyro.Pa=rootPart

	flyState.vel = I.n("BodyVelocity")
	flyState.vel.Vl=Vector3.zero
	flyState.vel.MaxForce = V3(9e9, 9e9, 9e9)
	flyState.vel.Pa=rootPart

	if humanoid then humanoid.PS=true end

	if flyState.isMobile and flyState.isMobile() and flyState.showMobileUi then
		flyState.showMobileUi(true)
	end

	flyState.loop = RS.RenderStepped:Cn(function()
		updateCharacter()
		if not flyState.flying or not rootPart or not rootPart.Parent then return end
		if flyState.gyro and flyState.gyro.Parent ~= rootPart then flyState.gyro.Pa=rootPart end
		if flyState.vel and flyState.vel.Parent ~= rootPart then flyState.vel.Pa=rootPart end
		if flyState.gyro then flyState.gyro.CF=Camera.CFrame end

		local move = Vector3.zero
		if UIS:IsKeyDown(E.KeyCode.W) or UIS:IsKeyDown(E.KeyCode.Z) then move += Camera.CFrame.LookVector end
		if UIS:IsKeyDown(E.KeyCode.S) then move -= Camera.CFrame.LookVector end
		if UIS:IsKeyDown(E.KeyCode.A) or UIS:IsKeyDown(E.KeyCode.Q) then move -= Camera.CFrame.RightVector end
		if UIS:IsKeyDown(E.KeyCode.D) then move += Camera.CFrame.RightVector end
		if UIS:IsKeyDown(E.KeyCode.Space) then move += V3(0, 1, 0) end
		if UIS:IsKeyDown(E.KeyCode.LeftControl) or UIS:IsKeyDown(E.KeyCode.LeftShift) then move -= V3(0, 1, 0) end
		if flyState.mobileInput and flyState.mobileInput.Magnitude > 0 then
			move += Camera.CFrame.LookVector * flyState.mobileInput.Z + Camera.CFrame.RightVector * flyState.mobileInput.X
		end
		if flyState.mobileUpHeld then move += V3(0, 1, 0) end
		if flyState.mobileDownHeld then move -= V3(0, 1, 0) end

		if flyState.vel then
			flyState.vel.Vl=move.Magnitude > 0 and move.Unit * flyState.speed or Vector3.zero
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
	local container = I.n("Frame")
	container.S=U2(1, -16, 0, 50)
	container.P=U2(0, 8, 0, yPos)
	container.BC3=C3(25, 25, 30)
	container.BSP=0
	container.Pa=parent
	createCorner(container, 8)
	createStroke(container, C3(45, 45, 55), 1)

	local label = I.n("TextLabel")
	label.S=U2(1, -10, 0, 18)
	label.P=U2(0, 8, 0, 4)
	label.BTr=1
	label.T=labelText .. ": " .. fmt(default)
	label.F=E.F.GothamSemibold
	label.TSz=12
	label.TC3=C3(210, 210, 210)
	label.TXA=E.TX.Left
	label.Pa=container

	local track = I.n("Frame")
	track.S=U2(1, -16, 0, 6)
	track.P=U2(0, 8, 0, 30)
	track.BC3=C3(45, 45, 55)
	track.BSP=0
	track.Pa=container
	createCorner(track, 3)

	local hitButton = I.n("TextButton")
	hitButton.S=U2(1, 0, 0, 24)
	hitButton.P=U2(0, 0, 0, 21)
	hitButton.BTr=1
	hitButton.T=""
	hitButton.BSP=0
	hitButton.ABC=false
	hitButton.ZIndex = 10
	hitButton.Pa=container

	local fill = I.n("Frame")
	fill.S=U2((default - min) / (max - min), 0, 1, 0)
	fill.BC3=color or C3(80, 150, 255)
	fill.BSP=0
	fill.Pa=track
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
		fill.S=U2(rel, 0, 1, 0)
		label.T=labelText .. ": " .. value
		callback(value)
	end

	track.InputBegan:Cn(function(input)
		if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
			draggingSlider = true
			setFromInput(input.Position.X)
		end
	end)
	hitButton.InputBegan:Cn(function(input)
		if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
			draggingSlider = true
			setFromInput(input.Position.X)
		end
	end)
	UIS.InputEnded:Cn(function(input)
		if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
			draggingSlider = false
		end
	end)
	UIS.InputChanged:Cn(function(input)
		if draggingSlider and (input.UserInputType == E.UserInputType.MouseMovement or input.UserInputType == E.UserInputType.Touch) then
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
			fill.S=U2(rel, 0, 1, 0)
			label.T=labelText .. ": " .. value
			callback(v)
		end
	}
end

local flySwitch = createSwitch(movePage, "Fly", 10, function(on)
	if on then startFly() else stopFly() end
end)

local flySlider = createSlider(movePage, "Vitesse Fly", 52, 20, 500, flyState.speed, function(v)
	flyState.speed = math.floor(v)
end, C3(100, 180, 255))

local noclipSwitch = createSwitch(movePage, "NoClip", 108, function(on)
	noclipState.enabled = on
	if not on then
		updateCharacter()
		if character then
			for _, p in ipairs(character:GD()) do
				if p:IsA("BasePart") then p.CC=true end
			end
		end
		if protectionsState then
			protectionsState.antiTeleportGraceUntil = tick() + 0.4
		end
	end
end)

local PFS = game:GetService("PFS")

local gotoWalkState = { enabled = false, active = false, target = nil, path = {}, visuals = {}, lastClick = 0, lastMoveTo = nil, recompute = nil, busy = false }

local function clearWalkVisuals()
	for _, v in ipairs(gotoWalkState.visuals) do
		if v and v.Parent then v:D() end
	end
	gotoWalkState.visuals = {}
end

local function visualizeWaypoints(waypoints)
	clearWalkVisuals()
	for i, wp in ipairs(waypoints) do
		local dot = I.n("Part")
		dot.An=true
		dot.CC=false
		dot.Tr=0.45
		dot.Sh=E.PartType.Ball
		dot.S=V3(0.6, 0.6, 0.6)
		dot.C=i == #waypoints and C3(0, 255, 120) or C3(120, 180, 255)
		dot.P=wp + V3(0, 0.2, 0)
		dot.Pa=WS
		table.insert(gotoWalkState.visuals, dot)
		if i > 1 then
			local prev = waypoints[i - 1]
			local seg = I.n("Part")
			seg.An=true
			seg.CC=false
			seg.Tr=0.7
			local len = (wp - prev).Magnitude
			if len > 0.1 then
				seg.S=V3(0.15, 0.15, len)
				seg.CF=CFrame.lookAt(prev, wp) * CFrame.new(0, 0, -len / 2)
			else
				seg.S=V3(0.15, 0.15, 0.1)
				seg.CF=CFrame.new((prev + wp) / 2)
			end
			seg.C=C3(200, 200, 255)
			seg.Pa=WS
			table.insert(gotoWalkState.visuals, seg)
		end
	end
end

local function computePathTo(targetPos)
	updateCharacter()
	if not rootPart or not humanoid then return {} end

	local myPos = rootPart.Position
	local flatDist = V3(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Magnitude
	local waypoints = {}

	local function rayClear(from, to)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = E.RaycastFilterType.Exclude
		local dir = to - from
		local dist = dir.Magnitude
		if dist < 0.1 then return true end
		local hit = WS:Raycast(from, dir.Unit * dist, params)
		return hit == nil
	end

	local function findBestHeight(from, dir, dist)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = E.RaycastFilterType.Exclude
		local heights = {0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15}
		local bestH = nil
		local bestScore = math.huge
		for _, h in ipairs(heights) do
			local origin = from + V3(0, h, 0)
			local hit = WS:Raycast(origin, dir * (dist + 1), params)
			if not hit then
				local score = math.abs(h - math.max(0, targetPos.Y - from.Y))
				if score < bestScore then bestScore = score; bestH = h end
			end
		end
		return bestH
	end

	local ok, pathOrErr = pcall(function()
		local p = PFS:CP({
			AgentRadius = 1.5,
			AgentHeight = 4.5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 6,
			Costs = { Climbing = 3, Jumping = 2 }
		})
		p:CA(myPos, targetPos)
		return p:GW()
	end)

	if ok and pathOrErr and #pathOrErr > 0 then
		for i, wp in ipairs(pathOrErr) do
			if wp and wp.Position then table.insert(waypoints, wp.Position) end
		end
		if #waypoints > 1 then table.remove(waypoints, 1) end
		if #waypoints > 0 then return waypoints end
	end

	if flatDist > 30 then
		local dir = V3(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Unit
		local segmentLen = 25
		local segments = math.floor(flatDist / segmentLen)
		local prevPos = myPos

		for i = 1, segments do
			local segTarget = myPos + dir * (i * segmentLen)
			local gParams = RaycastParams.new()
			gParams.FilterDescendantsInstances = {character}
			gParams.FilterType = E.RaycastFilterType.Exclude
			local ground = WS:Raycast(segTarget + V3(0, 30, 0), V3(0, -60, 0), gParams)
			if ground then
				segTarget = V3(segTarget.X, ground.Position.Y + 2, segTarget.Z)
			end
			if rayClear(prevPos, segTarget) then
				table.insert(waypoints, segTarget)
				prevPos = segTarget
			else
				local bestH = findBestHeight(prevPos, dir, segmentLen)
				if bestH then
					local mid = prevPos + dir * (segmentLen * 0.5)
					segTarget = V3(mid.X, prevPos.Y + bestH, mid.Z)
					table.insert(waypoints, segTarget)
					prevPos = segTarget
				else
					local offsets = {V3(0,0,5), V3(0,0,-5), V3(5,0,0), V3(-5,0,0)}
					local found = false
					for _, off in ipairs(offsets) do
						local tryPos = segTarget + off
						if rayClear(prevPos, tryPos) then
							table.insert(waypoints, tryPos)
							prevPos = tryPos
							found = true
							break
						end
					end
					if not found then
						table.insert(waypoints, segTarget)
						prevPos = segTarget
					end
				end
			end
		end
		if rayClear(prevPos, targetPos) then
			table.insert(waypoints, targetPos)
		else
			local gParams = RaycastParams.new()
			gParams.FilterDescendantsInstances = {character}
			gParams.FilterType = E.RaycastFilterType.Exclude
			local ground = WS:Raycast(targetPos + V3(0, 30, 0), V3(0, -60, 0), gParams)
			if ground then
				table.insert(waypoints, V3(targetPos.X, ground.Position.Y + 2, targetPos.Z))
			else
				table.insert(waypoints, targetPos)
			end
		end
		if #waypoints > 0 then return waypoints end
	end

	local function findClearPath(from, to)
		local dir = to - from
		local flatDir = V3(dir.X, 0, dir.Z)
		local d = flatDir.Magnitude
		if d < 0.5 then return to end
		local unit = flatDir / d
		local bestH = findBestHeight(from, unit, d)
		if bestH then
			local mid = from + unit * math.min(10, d * 0.35)
			return V3(mid.X, from.Y + bestH, mid.Z)
		end
		return nil
	end

	local mid = findClearPath(myPos, targetPos)
	if mid then
		local mid2 = findClearPath(mid, targetPos)
		if mid2 then return {mid, mid2} end
		return {mid}
	end

	local flat = V3(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
	if flat.Magnitude > 0.1 then
		local step = myPos + flat.Unit * math.min(6, flat.Magnitude * 0.3)
		local gParams = RaycastParams.new()
		gParams.FilterDescendantsInstances = {character}
		gParams.FilterType = E.RaycastFilterType.Exclude
		local ground = WS:Raycast(step + V3(0, 10, 0), V3(0, -20, 0), gParams)
		if ground then step = V3(step.X, ground.Position.Y + 2, step.Z) end
		return { step }
	end
	return {}
endlocal gotoWalkSwitch = createSwitch(movePage, "Go to Walk (click sol)", 150, function(on)
	gotoWalkState.enabled = on
	if not on then
		gotoWalkState.active = false
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
	if humanoid then humanoid.WS=walkSpeedState.value end
end, C3(255, 100, 100))

local walkResetBtn = createButton(movePage, "Reset vitesse", 288, C3(80, 80, 90), function()
	walkSpeedState.value = 16
	walkSlider.set(16)
	updateCharacter()
	if humanoid then humanoid.WS=16 end
end)

local platformLabel = I.n("TextLabel")
platformLabel.S=U2(1, -16, 0, 30)
platformLabel.P=U2(0, 8, 0, 328)
platformLabel.BTr=1
platformLabel.T="Plateforme: F10 (+=monter -=descendre)"
platformLabel.F=E.F.Gotham
platformLabel.TSz=11
platformLabel.TC3=C3(180, 180, 180)
platformLabel.TXA=E.TX.Left
platformLabel.Pa=movePage

local localState = {
	zeroG=false,
	normalG=WS.Gravity,
	customG=196.2,
	timeOfDay = 12,
}

local zeroGSwitch = createSwitch(localPage, "Zero Gravité", 10, function(on)
	localState.zeroG=on
	if on then
		WS.G=0
	else
		WS.G=localState.customGravity
	end

	local character = LP.Character
	if character then
		local hum = character:FindFirstChildWhichIsA("Humanoid")
		local animate = character:FFC("Animate")
		if hum then
			hum.PS=on
			if animate then animate.Disabled = on end
			if on then
				for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
				for _, sound in pairs(character:GD()) do
					if sound:IsA("Sound") then sound:Stop() end
				end
			end
		end
	end
end)

;(function()
local gravityContainer = I.n("Frame")
gravityContainer.S=U2(1, -16, 0, 86)
gravityContainer.P=U2(0, 8, 0, 56)
gravityContainer.BC3=C3(25, 25, 30)
gravityContainer.BSP=0
gravityContainer.Pa=localPage
createCorner(gravityContainer, 10)
createStroke(gravityContainer, C3(45, 45, 55), 1)

local gravityLabel = I.n("TextLabel")
gravityLabel.S=U2(1, -10, 0, 18)
gravityLabel.P=U2(0, 8, 0, 5)
gravityLabel.BTr=1
gravityLabel.T="Gravité custom : 196.2"
gravityLabel.F=E.F.GothamSemibold
gravityLabel.TSz=12
gravityLabel.TC3=C3(210, 210, 210)
gravityLabel.TXA=E.TX.Left
gravityLabel.Pa=gravityContainer

local gravityTrack = I.n("Frame")
gravityTrack.S=U2(1, -110, 0, 6)
gravityTrack.P=U2(0, 8, 0, 30)
gravityTrack.BC3=C3(45, 45, 55)
gravityTrack.BSP=0
gravityTrack.Pa=gravityContainer
createCorner(gravityTrack, 3)

local gravityFill = I.n("Frame")
gravityFill.S=U2(196.2 / 300, 0, 1, 0)
gravityFill.BC3=C3(120, 80, 255)
gravityFill.BSP=0
gravityFill.Pa=gravityTrack
createCorner(gravityFill, 3)

local gravityInput = I.n("TextBox")
gravityInput.S=U2(0, 80, 0, 22)
gravityInput.P=U2(1, -90, 0, 22)
gravityInput.BC3=C3(35, 35, 42)
gravityInput.TC3=C3(230, 230, 230)
gravityInput.PlaceholderT="196.2"
gravityInput.T="196.2"
gravityInput.F=E.F.Gotham
gravityInput.TSz=12
gravityInput.TXA=E.TX.Center
gravityInput.CTOF=true
gravityInput.Pa=gravityContainer
createCorner(gravityInput, 6)
createStroke(gravityInput, C3(80, 80, 100), 1)

	_G._agoraSetGravityExact = function(v)
	v = tonumber(v)
	if not v then return end
	v = math.clamp(math.floor(v + 0.5), 0, 300)
	localState.customG=v
	WS.G=v
	gravityLabel.T="Gravité custom : " .. v
	gravityInput.T=tostring(v)
	gravityFill.S=U2(v / 300, 0, 1, 0)
end

local draggingG=false
local function gravityFromX(x)
	local rel = math.clamp((x - gravityTrack.AbsolutePosition.X) / gravityTrack.AbsoluteSize.X, 0, 1)
	return math.floor(rel * 300 + 0.5)
end

gravityTrack.InputBegan:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		draggingG=true
		_G._agoraSetGravityExact(gravityFromX(input.Position.X))
	end
end)
UIS.InputEnded:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		draggingG=false
	end
end)
UIS.InputChanged:Cn(function(input)
	if draggingGravity and (input.UserInputType == E.UserInputType.MouseMovement or input.UserInputType == E.UserInputType.Touch) then
		_G._agoraSetGravityExact(gravityFromX(input.Position.X))
	end
end)

gravityInput.FocusLost:Cn(function(enterPressed)
	_G._agoraSetGravityExact(gravityInput.Text)
end)

local resetGravityBtn = createButton(localPage, "Reset gravité normale", 148, C3(80, 80, 90), function()
	_G._agoraSetGravityExact(196.2)
end)
resetGravityBtn.S=U2(1, -16, 0, 30)
resetGravityBtn.P=U2(0, 8, 0, 148)
end)()

local timeSwitch = createSwitch(localPage, "Temps custom", 200, function(on)
	if on then
		Lt.TimeOfDay = string.format("%02d:00:00", localState.timeOfDay)
	else
		Lt.TimeOfDay = "12:00:00"
	end
end)

createSlider(localPage, "Heure du jour", 246, 0, 24, 12, function(v)
	localState.timeOfDay = math.floor(v)
	Lt.TimeOfDay = string.format("%02d:00:00", localState.timeOfDay)
end, C3(255, 180, 60))

createSwitch(localPage, "Freeze temps", 292, function(on)
	if on then
		Lt.ClockTime = localState.timeOfDay
	end
end)

createButton(localPage, "Reset monde", 348, C3(80, 80, 90), function()
	WS.G=localState.normalGravity
	Lt.TimeOfDay = "12:00:00"
	zeroGSwitch.set(false)
	localState.customG=196.2
	_G._agoraSetGravityExact(196.2)
	localState.timeOfDay = 12
end)

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

local chatIconsSwitch = createSwitch(localPage, "Icônes chat ESP", 448, function(on)
	espState.chatIcons = on
end)
chatIconsSwitch.set(true)

local autoClickState = {
	toolA=false,   -- le switch (faux tool dans le backpack)
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
		autoClickState.fakeTool:D()
	end
	autoClickState.fakeTool = nil
end

local function createFakeTool()
	local backpack = LP:FFC("Backpack")
	if not backpack then return end
	removeFakeTool()
	local tool = I.n("Tool")
	tool.N="AutoClicker_Tool"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Configurer puis activer l'autoclick"
	local h = I.n("Part")
	h.N="Handle"
	h.S=V3(0.1, 0.1, 0.1)
	h.Tr=1
	h.CC=false
	h.An=true
	h.Pa=tool
	tool.Equipped:Cn(function()
		clickControl.V=true
		task.defer(clampControl)
	end)
	tool.Unequipped:Cn(function()
	end)
	tool.Pa=backpack
	autoClickState.fakeTool = tool
	return tool
end

local function stopAutoClickEngine()
	autoClickState.clickEnabled = false
	if autoClickState.activeThread then
		autoClickState.activeThread = nil
	end
	destroyAutoClickMarker()
	statusLabel.T="Statut : arret"
	statusLabel.TC3=C3(200, 200, 200)
	pcall(hideMarker)
end

local function onToolDeactivated()
	stopAutoClickEngine()
end

local VirtualInputManager
pcall(function()
	VirtualInputManager = (getvirtualinputmanager and getvirtualinputmanager()) or game:GetService("VirtualInputManager")
end)

local acTarget = {
	captured = false,
	position = Vector2.new(0, 0),   -- position écran
	worldHit = nil,                 -- Mouse.Hit sous le curseur à la capture
	worldTarget = nil,              -- l'instance Part/GUI sous le curseur à la capture
	targetType = "any",             -- "any" | "world" | "gui"
	markerPt=nil                -- Part 3D visuelle au worldHit.Position (marker dans la map)
}

;(function()
	function destroyAutoClickMarker()
		if acTarget.markerPart and acTarget.markerPart.Parent then
			pcall(function() acTarget.markerPart:D() end)
		end
		acTarget.markerPt=nil
	end
	function refreshAutoClickMarker()
		destroyAutoClickMarker()
		if not acTarget.worldHit then return end
		local marker = I.n("Part")
		marker.N="AutoClickMarker"
		marker.S=V3(0.6, 0.6, 0.6)
		marker.Sh=E.PartType.Ball
		marker.An=true
		marker.CC=false
		marker.CSh=false
		marker.Mt=E.Material.Neon
		marker.C=C3(255, 80, 80)
		marker.Tr=0.3
		marker.P=acTarget.worldHit.Position
		marker.Pa=workspace
		acTarget.markerPt=marker
	end
end)()

local function captureTargetFromCursor()
	local mouse = LP:GetMouse()
	if not mouse then return false end
	acTarget.captured = true
	acTarget.position = UIS:GetMouseLocation()
	acTarget.worldHit = mouse.Hit
	acTarget.worldTarget = mouse.Target
	refreshAutoClickMarker()
	return true
end

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
						if not best or (as.X * as.Y) < (best.AbsoluteSize.X * best.AbsoluteSize.Y) then
							best = obj
						end
					end
				end
			end
		end
		for _, child in ipairs(obj:GC()) do
			local ok, _ = pcall(walk, child)
			if not ok then end
		end
	end
	pcall(walk, root)
	return best
end

local function findClickDetectorAtScreen(point)
	local camera = WS.CurrentCamera
	if not camera then return nil end
	local unit = camera:ScreenPointToRay(point.X, point.Y)
	local hit = WS:Raycast(unit.Origin, unit.Direction * 1000)
	if not hit then return nil end
	local inst = hit.Instance
	if inst and inst:IsA("ClickDetector") then return inst end
	if inst then
		local cd = inst:FFCOC("ClickDetector")
		if cd then return cd end
		if inst.Parent then
			local cd2 = inst.Parent:FFCOC("ClickDetector")
			if cd2 then return cd2 end
		end
	end
	return nil
end

local function fireClickFixed(useNative)
	if not acTarget.captured then return false end
	local pt = acTarget.position
	local clicked = false
	local mode = acTarget.targetType

	if mode == "any" or mode == "gui" then
		local playerGui = LP:FFC("PlayerGui")
		if playerGui then
			local btn = findGuiButtonAt(pt, playerGui)
			if btn then
				pcall(function()
					btn.MouseEnter:F()
					btn.MouseButton1Down:F(pt - btn.AbsolutePosition)
					btn.MouseButton1Click:F()
					btn.MouseButton1Up:F(pt - btn.AbsolutePosition)
				end)
				clicked = true
			end
		end
	end

	if not clicked and (mode == "any" or mode == "world") then
		local cd = findClickDetectorAtScreen(pt)
		if cd then
			pcall(function() fireclickdetector(cd) end)
			clicked = true
		end
	end

	if not clicked and (mode == "any" or mode == "world") then
		local cam = workspace.CurrentCamera
		if cam then
			local ray = cam:ScreenPointToRay(pt.X, pt.Y)
			local pp = nil
			for _, desc in ipairs(workspace:GD()) do
				if desc:IsA("ProximityPrompt") and desc.Enabled and desc.Parent then
					local att = desc.Parent
					if att:IsA("Attachment") and att.Parent then
						local p3 = att.WorldPosition
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

	if not clicked and (mode == "any" or mode == "world") and VirtualInputManager then
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(pt.X, pt.Y, 0, true, game, 0)
			task.wait(0.01)
			VirtualInputManager:SendMouseButtonEvent(pt.X, pt.Y, 0, false, game, 0)
		end)
		clicked = true
	end

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
	if not acTarget.captured then
		if not captureTargetFromCursor() then return end
	end
	autoClickState.clickEnabled = true
	statusLabel.T="Statut : actif"
	statusLabel.TC3=C3(80, 220, 120)
	local threadId = {}
	autoClickState.activeThread = threadId
	local interval = math.max(0.001, autoClickState.speed)
	local useNative = (acTarget.targetType ~= "gui")
	task.spawn(function()
		while autoClickState.clickEnabled and autoClickState.activeThread == threadId do
			fireClickFixed(useNative)
			task.wait(interval)
		end
	end)
end

local autoClickContainer = I.n("Frame")
autoClickContainer.S=U2(1, -16, 0, 260)
autoClickContainer.P=U2(0, 8, 0, 460)
autoClickContainer.BC3=C3(25, 25, 30)
autoClickContainer.BSP=0
autoClickContainer.Pa=localPage
createCorner(autoClickContainer, 10)
createStroke(autoClickContainer, C3(45, 45, 55), 1)

local autoClickTitle = I.n("TextLabel")
autoClickTitle.S=U2(1, -10, 0, 18)
autoClickTitle.P=U2(0, 8, 0, 6)
autoClickTitle.BTr=1
autoClickTitle.T="Auto Clicker"
autoClickTitle.F=E.F.GothamBold
autoClickTitle.TSz=13
autoClickTitle.TC3=C3(210, 210, 210)
autoClickTitle.TXA=E.TX.Left
autoClickTitle.Pa=autoClickContainer

local infoLabel = I.n("TextLabel")
infoLabel.S=U2(1, -16, 0, 28)
infoLabel.P=U2(0, 8, 0, 22)
infoLabel.BTr=1
infoLabel.T="1) Choisis la cible (Les 2 / Monde / GUI). 2) Place le curseur sur l'item. 3) Clic '1 Clic ici' OU 'Démarrer AutoClick' — la position est FIXÉE à l'écran et le clic est répété même si tu bouges la souris."
infoLabel.F=E.F.Gotham
infoLabel.TSz=10
infoLabel.TC3=C3(160, 160, 160)
infoLabel.TW=true
infoLabel.TXA=E.TX.Left
infoLabel.Pa=autoClickContainer

local acMarker = I.n("Frame")
acMarker.N="_ACMarker"
acMarker.S=U2(0, 14, 0, 14)
acMarker.BC3=C3(255, 60, 60)
acMarker.BTr=0.25
acMarker.BSP=0
acMarker.V=false
acMarker.ZIndex = 130
acMarker.AnchorPoint = Vector2.new(0.5, 0.5)
acMarker.Pa=screenGui
createCorner(acMarker, 7)

local acMarkerStroke = I.n("UIStroke")
acMarkerStroke.C=C3(255, 200, 200)
acMarkerStroke.Thickness = 1.5
acMarkerStroke.Pa=acMarker

local function showMarkerAt(screenPos)
	acMarker.V=true
	acMarker.P=U2(0, screenPos.X, 0, screenPos.Y)
end
local function hideMarker()
	acMarker.V=false
end

local _origCapture = captureTargetFromCursor
captureTargetFromCursor = function()
	local ok = _origCapture()
	if ok then showMarkerAt(acTarget.position) end
	return ok
end

local autoClickSwitch = createSwitch(autoClickContainer, "Activer (touche G) - ouvre mini panel", 56, function(on)
	autoClickState.toolA=on
	if on then
		clickControl.V=true
	else
		stopAutoClickEngine()
		clickControl.V=false
	end
	setAutoClickSave()
end)

UIS.InputBegan:Cn(function(input, gpe)
	if gpe then return end
	if input.KeyCode == E.KeyCode.G then
		if clickControl then
			clickControl.V=not clickControl.Visible
			autoClickState.toolA=clickControl.Visible
		end
	end
end)

local modeFrame = I.n("Frame")
modeFrame.S=U2(1, -16, 0, 26)
modeFrame.P=U2(0, 8, 0, 100)
modeFrame.BTr=1
modeFrame.Pa=autoClickContainer

local modes = {any = "Les 2", world = "Monde", gui = "GUI"}
local modeOrder = {"any", "world", "gui"}
local modeBtns = {}
for i, m in ipairs(modeOrder) do
	local btn = I.n("TextButton")
	btn.S=U2(0.32, -2, 1, 0)
	btn.P=U2((i - 1) * 0.34, 0, 0, 0)
	btn.BC3=C3(45, 45, 55)
	btn.T=modes[m]
	btn.F=E.F.GothamSemibold
	btn.TSz=11
	btn.TC3=C3(200, 200, 200)
	btn.BSP=0
	btn.ABC=false
	btn.Pa=modeFrame
	createCorner(btn, 6)
	modeBtns[m] = btn
	btn.MouseButton1Click:Cn(function()
		acTarget.targetType = m
		for _, b in pairs(modeBtns) do tween(b, {BC3=C3(45, 45, 55)}, 0.1) end
		tween(btn, {BC3=C3(60, 120, 200)}, 0.1)
	end)
end
tween(modeBtns["any"], {BC3=C3(60, 120, 200)}, 0)

local speedLabel = I.n("TextLabel")
speedLabel.S=U2(1, -10, 0, 16)
speedLabel.P=U2(0, 8, 0, 132)
speedLabel.BTr=1
speedLabel.T="Vitesse : 0.05s"
speedLabel.F=E.F.Gotham
speedLabel.TSz=11
speedLabel.TC3=C3(180, 180, 180)
speedLabel.TXA=E.TX.Left
speedLabel.Pa=autoClickContainer

local speedSliderTrack = I.n("Frame")
speedSliderTrack.S=U2(1, -16, 0, 6)
speedSliderTrack.P=U2(0, 8, 0, 152)
speedSliderTrack.BC3=C3(45, 45, 55)
speedSliderTrack.BSP=0
speedSliderTrack.Pa=autoClickContainer
createCorner(speedSliderTrack, 3)

local speedFill = I.n("Frame")
speedFill.S=U2(0.5, 0, 1, 0)
speedFill.BC3=C3(120, 80, 255)
speedFill.BSP=0
speedFill.Pa=speedSliderTrack
createCorner(speedFill, 3)

local draggingSpeed = false
local function speedFromX(x)
	local rel = math.clamp((x - speedSliderTrack.AbsolutePosition.X) / speedSliderTrack.AbsoluteSize.X, 0, 1)
	return 0.001 + rel * 0.199
end
local function setSpeed(s)
	s = math.clamp(math.floor(s * 1000) / 1000, 0.001, 0.2)
	autoClickState.speed = s
	speedLabel.T="Vitesse : " .. s .. "s"
	speedFill.S=U2((s - 0.001) / 0.199, 0, 1, 0)
	if autoClickState.clickEnabled then startAutoClickEngine() end
	setAutoClickSave()
end
setSpeed(0.05)

speedSliderTrack.InputBegan:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		draggingSpeed = true
		setSpeed(speedFromX(input.Position.X))
	end
end)
UIS.InputEnded:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		draggingSpeed = false
	end
end)
UIS.InputChanged:Cn(function(input)
	if draggingSpeed and (input.UserInputType == E.UserInputType.MouseMovement or input.UserInputType == E.UserInputType.Touch) then
		setSpeed(speedFromX(input.Position.X))
	end
end)

local clickControl = I.n("Frame")
clickControl.N="AutoClickControl"
clickControl.S=U2(0, 140, 0, 170)
clickControl.P=U2(0.5, -70, 0.5, -85)
clickControl.BC3=C3(22, 22, 28)
clickControl.BTr=0.15
clickControl.BSP=0
clickControl.ZIndex = 120
clickControl.Pa=screenGui
clickControl.A=true
clickControl.V=false
createCorner(clickControl, 12)
createStroke(clickControl, C3(80, 80, 100), 1)

local controlHeader = I.n("TextButton")
controlHeader.ABC=false
controlHeader.S=U2(1, 0, 0, 24)
controlHeader.BTr=1
controlHeader.T=":: AutoClick ::"
controlHeader.F=E.F.GothamBold
controlHeader.TSz=12
controlHeader.TC3=C3(230, 230, 230)
controlHeader.ZIndex = 122
controlHeader.Pa=clickControl

local ccDragging, ccDragStart, ccStartPos = false, nil, nil
controlHeader.InputBegan:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		ccDragging = true
		ccDragStart = input.Position
		ccStartPos = clickControl.Position
	end
end)
UIS.InputChanged:Cn(function(input)
	if ccDragging and (input.UserInputType == E.UserInputType.MouseMovement or input.UserInputType == E.UserInputType.Touch) then
		if ccStartPos and ccDragStart then
			local dx = input.Position.X - ccDragStart.X
			local dy = input.Position.Y - ccDragStart.Y
			clickControl.P=U2(ccStartPos.X.Scale, ccStartPos.X.Offset + dx, ccStartPos.Y.Scale, ccStartPos.Y.Offset + dy)
		end
	end
end)
UIS.InputEnded:Cn(function(input)
	if input.UserInputType == E.UserInputType.MouseButton1 or input.UserInputType == E.UserInputType.Touch then
		ccDragging = false
	end
end)

local statusLabel = I.n("TextLabel")
statusLabel.S=U2(0.9, 0, 0, 16)
statusLabel.P=U2(0.05, 0, 0, 26)
statusLabel.BTr=1
statusLabel.T="Statut : arret"
statusLabel.F=E.F.Gotham
statusLabel.TSz=10
statusLabel.TC3=C3(200, 200, 200)
statusLabel.ZIndex = 122
statusLabel.Pa=clickControl

local execBtn = I.n("TextButton")
execBtn.S=U2(0.9, 0, 0, 28)
execBtn.P=U2(0.05, 0, 0, 46)
execBtn.ZIndex = 122
execBtn.BC3=C3(60, 120, 200)
execBtn.T="1 Clic ici"
execBtn.F=E.F.GothamSemibold
execBtn.TSz=10
execBtn.TC3=Color3.new(1, 1, 1)
execBtn.BSP=0
execBtn.ABC=false
execBtn.Pa=clickControl
createCorner(execBtn, 6)
execBtn.MouseButton1Click:Cn(function()
	captureTargetFromCursor()
	fireClickFixed(true)
end)

local multiBtn = I.n("TextButton")
multiBtn.S=U2(0.9, 0, 0, 28)
multiBtn.P=U2(0.05, 0, 0, 78)
multiBtn.ZIndex = 122
multiBtn.BC3=C3(80, 60, 160)
multiBtn.T="Multi Clic x5"
multiBtn.F=E.F.GothamSemibold
multiBtn.TSz=10
multiBtn.TC3=Color3.new(1, 1, 1)
multiBtn.BSP=0
multiBtn.ABC=false
multiBtn.Pa=clickControl
createCorner(multiBtn, 6)
multiBtn.MouseButton1Click:Cn(function()
	captureTargetFromCursor()
	for i = 1, 5 do
		task.delay((i - 1) * 0.01, function() fireClickFixed(true) end)
	end
end)

local toggleClickBtn = I.n("TextButton")
toggleClickBtn.S=U2(0.9, 0, 0, 28)
toggleClickBtn.P=U2(0.05, 0, 0, 110)
toggleClickBtn.ZIndex = 122
toggleClickBtn.BC3=C3(60, 160, 90)
toggleClickBtn.T="Demarrer AutoClick"
toggleClickBtn.F=E.F.GothamSemibold
toggleClickBtn.TSz=10
toggleClickBtn.TC3=Color3.new(1, 1, 1)
toggleClickBtn.BSP=0
toggleClickBtn.ABC=false
toggleClickBtn.Pa=clickControl
createCorner(toggleClickBtn, 6)
toggleClickBtn.MouseButton1Click:Cn(function()
	if autoClickState.clickEnabled then
		stopAutoClickEngine()
		toggleClickBtn.T="Demarrer AutoClick"
		toggleClickBtn.BC3=C3(60, 160, 90)
	else
		captureTargetFromCursor()
		startAutoClickEngine()
		toggleClickBtn.T="Arreter AutoClick"
		toggleClickBtn.BC3=C3(200, 80, 80)
	end
end)

local closeControlBtn = I.n("TextButton")
closeControlBtn.S=U2(0.9, 0, 0, 18)
closeControlBtn.P=U2(0.05, 0, 0, 142)
closeControlBtn.ZIndex = 122
closeControlBtn.BTr=1
closeControlBtn.T="Cacher"
closeControlBtn.F=E.F.Gotham
closeControlBtn.TSz=10
closeControlBtn.TC3=C3(180, 180, 180)
closeControlBtn.BSP=0
closeControlBtn.ABC=false
closeControlBtn.Pa=clickControl
closeControlBtn.MouseButton1Click:Cn(function()
	clickControl.V=false
end)

local dragHandle = I.n("TextButton")
dragHandle.N="DragHandle"
dragHandle.S=U2(0, 22, 0, 22)
dragHandle.P=U2(1, -24, 1, -24)
dragHandle.BC3=C3(60, 60, 80)
dragHandle.T="•"
dragHandle.F=E.F.GothamBold
dragHandle.TSz=14
dragHandle.TC3=C3(200, 200, 220)
dragHandle.ZIndex = 125
dragHandle.Pa=clickControl
createCorner(dragHandle, 11)

local function clampControl()
	local s = screenGui.AbsoluteSize
	local sz = clickControl.AbsoluteSize
	local x = math.clamp(clickControl.AbsolutePosition.X, 0, math.max(0, s.X - sz.X))
	local y = math.clamp(clickControl.AbsolutePosition.Y, 0, math.max(0, s.Y - sz.Y))
	clickControl.P=U2(0, x, 0, y)
end

clickControl:GetPropertyChangedSignal("Position"):Cn(function()
	task.defer(clampControl)
end)

local controlToggle = createButton(autoClickContainer, "Afficher/Cacher panneau", 198, C3(80, 60, 160), function()
	clickControl.V=not clickControl.Visible
end)
controlToggle.S=U2(1, -16, 0, 28)
controlToggle.P=U2(0, 8, 0, 226)

if panelMemory.autoClick and panelMemory.autoClick.pos then
	local p = panelMemory.autoClick.pos
	clickControl.P=U2(p[1], p[2], p[3], p[4])
end
if panelMemory.autoClick and panelMemory.autoClick.speed then
	setSpeed(panelMemory.autoClick.speed)
end
if panelMemory.autoClick and panelMemory.autoClick.targetType then
	local saved = panelMemory.autoClick.targetType
	if modes[saved] then
		acTarget.targetType = saved
		for _, b in pairs(modeBtns) do tween(b, {BC3=C3(45, 45, 55)}, 0.1) end
		tween(modeBtns[saved], {BC3=C3(60, 120, 200)}, 0.1)
	end
elseif panelMemory.autoClick and panelMemory.autoClick.mode then
	local saved = panelMemory.autoClick.mode
	if saved == "rapid" or saved == "auto" then saved = "any" end
	if modes[saved] then
		acTarget.targetType = saved
		for _, b in pairs(modeBtns) do tween(b, {BC3=C3(45, 45, 55)}, 0.1) end
		tween(modeBtns[saved], {BC3=C3(60, 120, 200)}, 0.1)
	end
end

clickControl:GetPropertyChangedSignal("Position"):Cn(function()
	autoClickState.controlPos = clickControl.Position
	setAutoClickSave()
end)
reparentChildrenToLocalScroll()

localScroll.CanvasS=U2(0, 0, 0, 900)

task.delay(0, function()
	local function clampFrame()
		local abs = mainFrame.AbsoluteSize
		local scr = screenGui.AbsoluteSize
		local x = math.clamp(mainFrame.AbsolutePosition.X, 0, math.max(0, scr.X - abs.X))
		local y = math.clamp(mainFrame.AbsolutePosition.Y, 0, math.max(0, scr.Y - abs.Y))
		mainFrame.P=U2(0, x, 0, y)
	end
	clampFrame()
	task.wait(0.1)
	clampFrame()
end)

RS.RenderStepped:Cn(function()
	if localState.zeroGravity then
		local char = LP.Character
		local hrp = char and char:FFC("HumanoidRootPart")
		local cam = WS.CurrentCamera
		if hrp and UIS:IsKeyDown(E.KeyCode.W) then
			hrp.AssemblyLinearVl=cam.CFrame.LookVector * 16
		end
	end
end)

UIS.JumpRequest:Cn(function()
	if jumpState.infinite and humanoid then
		humanoid:CS(E.HumanoidStateType.Jumping)
	end
end)

UIS.InputBegan:Cn(function(input, gpe)
	if gpe then return end
	if input.KeyCode == E.KeyCode.E then
		if flyState.flying then
			stopFly()
		else
			startFly()
		end
	end
	if input.KeyCode == E.KeyCode.F10 then
		platformState.enabled = not platformState.enabled
		if platformState.enabled then
			if not platformState.part then
				platformState.part = I.n("Part")
				platformState.part.An=true
				platformState.part.CC=true
				platformState.part.Tr=1
				platformState.part.N="InvisiblePlatform"
				platformState.part.S=V3(2000, 1, 2000)
				platformState.part.Pa=WS
			end
			local seatPt=humanoid and humanoid.SeatPart
			local capturedY
			if seatPart and seatPart:IsA("BasePart") then
				local seatModel = seatPart:FFAOC("Model") or seatPart.Parent
				if seatModel and seatModel ~= character then
					local ok, cf, size = pcall(function() return seatModel:GBB() end)
					if ok and cf and size then
						capturedY = cf.Position.Y - size.Y / 2 - 1.5
					end
				end
				if not capturedY and seatPart then
					local cf = seatPart.CFrame
					local size = seatPart.Size
					capturedY = cf.Position.Y - size.Y / 2 - 1.5
				end
			elseif character then
				local ok, cf, size = pcall(function() return character:GBB() end)
				if ok and cf and size then
					capturedY = cf.Position.Y - size.Y / 2 - 0.2
				elseif rootPart then
					capturedY = rootPart.Position.Y - 3
				else
					capturedY = (character:GP().Position.Y) - 3
				end
			end
			if capturedY then
				platformState.y = capturedY
				platformState.offset = 0
				platformState.smoothedOffset = 0
				local anchorPos = rootPart and rootPart.Position or (humanoid and humanoid.SeatPart and humanoid.SeatPart.Position)
				if anchorPos then
					platformState.part.CF=CFrame.new(anchorPos.X, capturedY, anchorPos.Z)
				else
					platformState.part.CF=CFrame.new(0, capturedY, 0)
				end
			end
		else
			if platformState.part then
				platformState.part:D()
				platformState.part = nil
			end
		end
	end
end)

RS.Stepped:Cn(function(_, dt)
	updateCharacter()
	if noclipState.enabled and character then
		for _, p in ipairs(character:GD()) do
			if p:IsA("BasePart") then p.CC=false end
		end
	end
	if platformState.enabled and platformState.part then
		if UIS:IsKeyDown(E.KeyCode.Equals) or UIS:IsKeyDown(E.KeyCode.KeypadPlus) then
			platformState.offset += 25 * dt
		end
		if UIS:IsKeyDown(E.KeyCode.Minus) or UIS:IsKeyDown(E.KeyCode.KeypadMinus) then
			platformState.offset -= 25 * dt
		end
		local smoothing = math.min(1, dt * 12)
		platformState.smoothedOffset = platformState.smoothedOffset + (platformState.offset - platformState.smoothedOffset) * smoothing
		local cur = platformState.part.CFrame
		platformState.part.CF=CFrame.new(cur.X, platformState.y + platformState.smoothedOffset, cur.Z)
	end
	if humanoid and rootPart and gotoWalkState.active and #gotoWalkState.path > 0 then
		local wp = gotoWalkState.path[1]
		local myPos = rootPart.Position
		local flatDist = V3(myPos.X - wp.X, 0, myPos.Z - wp.Z).Magnitude

		local charWidth = 2 -- largeur approximative du personnage (HumanoidRootPart size)
		local charHeight = 5 -- hauteur approximative (tete + torse + jambes)
		local crawlMode = false

		local function checkPassage(pos, height, width)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {character}
			params.FilterType = E.RaycastFilterType.Exclude
			local topHit = WS:Raycast(pos, V3(0, height, 0), params)
			if topHit then
				local clearance = (topHit.Position - pos).Y
				if clearance < charHeight then
					if clearance >= 1.5 then
						crawlMode = true
						return "crawl"
					else
						return "blocked"
					end
				end
			end
			local leftHit = WS:Raycast(pos, V3(-width/2, 0, 0), params)
			local rightHit = WS:Raycast(pos, V3(width/2, 0, 0), params)
			if leftHit or rightHit then
				return "tight"
			end
			return "clear"
		end

		local passage = checkPassage(wp, charHeight, charWidth)
		if passage == "crawl" then
			pcall(function()
				humanoid.HH=0
				local root = rootPart
				if root then
					root.S=V3(2, 1, 1)
				end
			end)
		elseif passage == "clear" then
			pcall(function()
				humanoid.HH=2
				local root = rootPart
				if root then
					root.S=V3(2, 5, 1)
				end
			end)
		end

		local heightDiff = wp.Y - myPos.Y
		if heightDiff > 2.5 and flatDist < 8 then
			pcall(function()
				humanoid.Jump = true
			end)
		end
		local frontParams = RaycastParams.new()
		frontParams.FilterDescendantsInstances = {character}
		frontParams.FilterType = E.RaycastFilterType.Exclude
		local frontRay = WS:Raycast(myPos, rootPart.CFrame.LookVector * 4, frontParams)
		if frontRay and heightDiff > 0 then
			pcall(function()
				humanoid.Jump = true
			end)
		end

		local vel = rootPart.AssemblyLinearVelocity
		local flatSpeed = V3(vel.X, 0, vel.Z).Magnitude
		if flatDist > 3 and flatSpeed < 1 then
			if gotoWalkState.stuckSince == nil then gotoWalkState.stuckSince = tick() end
			if tick() - gotoWalkState.stuckSince > 0.5 then
				pcall(function() humanoid.Jump = true end)
				if tick() - gotoWalkState.stuckSince > 2 and gotoWalkState.target then
					gotoWalkState.stuckSince = nil
					local newPath = computePathTo(gotoWalkState.target)
					if not newPath or #newPath == 0 then
						local offsets = {V3(4,0,0), V3(-4,0,0), V3(0,0,4), V3(0,0,-4), V3(4,0,4), V3(-4,0,-4)}
						for _, off in ipairs(offsets) do
							newPath = computePathTo(gotoWalkState.target + off)
							if newPath and #newPath > 0 then break end
						end
					end
					if newPath and #newPath > 0 then
						gotoWalkState.path = newPath
						visualizeWaypoints(newPath)
						humanoid:MT(newPath[1])
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
				clearWalkVisuals()
			else
				humanoid:MT(gotoWalkState.path[1])
				gotoWalkState.lastMoveTo = tick()
			end
		else
			if tick() - (gotoWalkState.lastMoveTo or 0) > 4 then
				humanoid:MT(wp)
				gotoWalkState.lastMoveTo = tick()
			end
		end
	end

	if humanoid and math.abs(humanoid.WalkSpeed - walkSpeedState.value) > 0.5 and not flyState.flying then
			humanoid.WS=walkSpeedState.value
		end
	end)

	RS.RenderStepped:Cn(function()
		pcall(function()
			local char = LP.Character
			local hum = char and char:FFCOC("Humanoid")
			if hum and not flyState.flying then
				local target = walkSpeedState.value
				if math.abs(hum.WalkSpeed - target) > 0.5 then
					hum.WS=target
				end
			end
		end)
	end)

_G._a_buildPanel=_buildPanel
_G._a_initRegistrySearch=_initRegistrySearch
_G._aaddGlow=addGlow
_G._aaddPlayerCard=addPlayerCard
_G._aapplyGlobalESPToPlayer=applyGlobalESPToPlayer
_G._ablinkESP=blinkESP
_G._abootSequence=bootSequence
_G._abuildESP=buildESP
_G._acaptureTargetFromCursor=captureTargetFromCursor
_G._aclampControl=clampControl
_G._aclearESP=clearESP
_G._aclearWalkVisuals=clearWalkVisuals
_G._acomputePathTo=computePathTo
_G._acreateButton=createButton
_G._acreateCorner=createCorner
_G._acreateFakeTool=createFakeTool
_G._acreatePlayerEntry=createPlayerEntry
_G._acreateSlider=createSlider
_G._acreateStroke=createStroke
_G._acreateSwitch=createSwitch
_G._acreateTab=createTab
_G._adistanceColor=distanceColor
_G._aensureESPForPlayer=ensureESPForPlayer
_G._afindClickDetectorAtScreen=findClickDetectorAtScreen
_G._afindGuiButtonAt=findGuiButtonAt
_G._afireClickFixed=fireClickFixed
_G._agetDeviceType=getDeviceType
_G._agravityFromX=gravityFromX
_G._ahideMarker=hideMarker
_G._ahttpGet=httpGet
_G._ahttpPost=httpPost
_G._amakeIcon=makeIcon
_G._amatrixRain=matrixRain
_G._aonToolDeactivated=onToolDeactivated
_G._aplaySound=playSound
_G._arefreshESP=refreshESP
_G._arefreshNoClipSwitch=refreshNoClipSwitch
_G._arefreshPlsList=refreshPlsList
_G._aremoveFakeTool=removeFakeTool
_G._aremovePlayerCard=removePlayerCard
_G._areparentChildrenToLocalScroll=reparentChildrenToLocalScroll
_G._asendEchoMessage=sendEchoMessage
_G._asetAutoClickSave=setAutoClickSave
_G._asetSpeed=setSpeed
_G._ashowMarkerAt=showMarkerAt
_G._ashowRestorePopup=showRestorePopup
_G._ashutdownPanel=shutdownPanel
_G._aspeedFromX=speedFromX
_G._astartAutoClickEngine=startAutoClickEngine
_G._astartFly=startFly
_G._astopAutoClickEngine=stopAutoClickEngine
_G._astopFly=stopFly
_G._aswitchTab=switchTab
_G._atween=tween
_G._atypewriterEffect=typewriterEffect
_G._aupdateCharacter=updateCharacter
_G._avisualizeWaypoints=visualizeWaypoints
_G._aCamera=Camera
_G._aHS=HS
_G._aLt=Lt
_G._aLP=LP
_G._aMouse=Mouse
_G._aPFS=PFS
_G._aPls=Pls
_G._aRSv=RSv
_G._aRS=RS
_G._aSoundService=SoundService
_G._aTextChatService=TextChatService
_G._aTSv=TSv
_G._aUIS=UIS
_G._aWS=WS
_G._a_game=_game
_G._a_origCapture=_origCapture
_G._aacMarker=acMarker
_G._aacMarkerStroke=acMarkerStroke
_G._aacTarget=acTarget
_G._aactiveTab=activeTab
_G._aautoClickContainer=autoClickContainer
_G._aautoClickState=autoClickState
_G._aautoClickSwitch=autoClickSwitch
_G._aautoClickTitle=autoClickTitle
_G._accInputConn=ccInputConn
_G._achatIconsSwitch=chatIconsSwitch
_G._aclickControl=clickControl
_G._acloseBtn=closeBtn
_G._acloseControlBtn=closeControlBtn
_G._acontentFrame=contentFrame
_G._acontrolHeader=controlHeader
_G._acontrolToggle=controlToggle
_G._adragHandle=dragHandle
_G._adraggingGravity=draggingGravity
_G._adraggingSpeed=draggingSpeed
_G._aechoStatusLabel=echoStatusLabel
_G._aespFolder=espFolder
_G._aespState=espState
_G._aexecBtn=execBtn
_G._aextraPage=extraPage
_G._aflySlider=flySlider
_G._aflyState=flyState
_G._aflySwitch=flySwitch
_G._aglobalESPEnabled=globalESPEnabled
_G._aglobalESPSwitch=globalESPSwitch
_G._agotoWalkState=gotoWalkState
_G._agravityContainer=gravityContainer
_G._agravityFill=gravityFill
_G._agravityInput=gravityInput
_G._agravityLabel=gravityLabel
_G._agravityTrack=gravityTrack
_G._ainfoLabel=infoLabel
_G._ajumpState=jumpState
_G._alocalLayout=localLayout
_G._alocalPage=localPage
_G._alocalScroll=localScroll
_G._alocalState=localState
_G._amainFrame=mainFrame
_G._amainGlow=mainGlow
_G._aminimizeBtn=minimizeBtn
_G._aminimized=minimized
_G._amodeBtns=modeBtns
_G._amodeFrame=modeFrame
_G._amodeOrder=modeOrder
_G._amodes=modes
_G._amovePage=movePage
_G._amultiBtn=multiBtn
_G._anoclipState=noclipState
_G._anoclipSwitch=noclipSwitch
_G._apages=pages
_G._apanelMemory=panelMemory
_G._aplatformLabel=platformLabel
_G._aplatformState=platformState
_G._aplayerCards=playerCards
_G._aplayerClearBtn=playerClearBtn
_G._aplayerSearchBox=playerSearchBox
_G._aplayerSearchQuery=playerSearchQuery
_G._aplayersLayout=playersLayout
_G._aplayersPage=playersPage
_G._aplayersScroll=playersScroll
_G._aprotectionsLayout=protectionsLayout
_G._aprotectionsPage=protectionsPage
_G._aprotectionsScroll=protectionsScroll
_G._apsbPad=psbPad
_G._aregistryLayout=registryLayout
_G._aregistryPadding=registryPadding
_G._aregistryPage=registryPage
_G._aregistryScroll=registryScroll
_G._aremotesPage=remotesPage
_G._aresetGravityBtn=resetGravityBtn
_G._ascreenGui=screenGui
_G._aselectedEchoPlayer=selectedEchoPlayer
_G._aspeedFill=speedFill
_G._aspeedLabel=speedLabel
_G._aspeedSliderTrack=speedSliderTrack
_G._astatusLabel=statusLabel
_G._atabBar=tabBar
_G._atabButtons=tabButtons
_G._atabHolder=tabHolder
_G._atabLayout=tabLayout
_G._atimeSwitch=timeSwitch
_G._atitleLabel=titleLabel
_G._atoggleClickBtn=toggleClickBtn
_G._atopBar=topBar
_G._awalkResetBtn=walkResetBtn
_G._awalkSlider=walkSlider
_G._awalkSpeedState=walkSpeedState
_G._azeroGSwitch=zeroGSwitch
_G._aDone=true
