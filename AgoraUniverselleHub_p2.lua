-- Agora Hub [UNIVERSELLE] - Part 2
-- Restore locals from Part 1
local TweenService = _G._P1.TweenService
local movePage = _G._P1.movePage
local activeTab = _G._P1.activeTab
local tabButtons = _G._P1.tabButtons
local contentFrame = _G._P1.contentFrame
local playersPage = _G._P1.playersPage
local homePage = _G._P1.homePage
local protectionsPage = _G._P1.protectionsPage
local Camera = _G._P1.Camera
local HttpService = _G._P1.HttpService
local Lighting = _G._P1.Lighting
local LocalPlayer = _G._P1.LocalPlayer
local Mouse = _G._P1.Mouse
local Players = _G._P1.Players
local ReplicatedStorage = _G._P1.ReplicatedStorage
local RunService = _G._P1.RunService
local UserInputService = _G._P1.UserInputService
local Workspace = _G._P1.Workspace
local character = _G._P1.character
local closeBtn = _G._P1.closeBtn
local espState = _G._P1.espState
local extraPage = _G._P1.extraPage
local flyState = _G._P1.flyState
local flySwitch = _G._P1.flySwitch
local gotoWalkState = _G._P1.gotoWalkState
local humanoid = _G._P1.humanoid
local loadingGui = _G._P1.loadingGui
local localPage = _G._P1.localPage
local localScroll = _G._P1.localScroll
local localState = _G._P1.localState
local mainFrame = _G._P1.mainFrame
local noclipState = _G._P1.noclipState
local noclipSwitch = _G._P1.noclipSwitch
local pages = _G._P1.pages
local panelMemory = _G._P1.panelMemory
local platformState = _G._P1.platformState
local protectionsScroll = _G._P1.protectionsScroll
local registryLayout = _G._P1.registryLayout
local registryPage = _G._P1.registryPage
local registryScroll = _G._P1.registryScroll
local remotesPage = _G._P1.remotesPage
local rootPart = _G._P1.rootPart
local screenGui = _G._P1.screenGui
local walkSpeedState = _G._P1.walkSpeedState
local zeroGSwitch = _G._P1.zeroGSwitch
local jumpState = _G._P1.jumpState
local createTab = _G.createTab
local createSwitch = _G.createSwitch
local createButton = _G.createButton
local createCorner = _G.createCorner
local createStroke = _G.createStroke
local tween = _G.tween
local switchTab = _G.switchTab
local playSound = _G.playSound
local shutdownPanel = _G.shutdownPanel
local updateLoad = _G.updateLoad
local updateCharacter = _G.updateCharacter
local makeIcon = _G.makeIcon
local addGlow = _G.addGlow
local httpGet = _G.httpGet
local httpPost = _G.httpPost
local createPlayerEntry = _G.createPlayerEntry
local _resolveCanChat = _G._resolveCanChat

-- ============= ESP =============
local espFolder = Instance.new("Folder")
espFolder.Name = "PanelESP"
espFolder.Parent = Workspace

local espState = { enabled = false, individual = {}, chatIcons = true }

local function distanceColor(dist)
	if dist < 50 then return Color3.fromRGB(80, 255, 120)
	elseif dist < 200 then return Color3.fromRGB(255, 200, 80)
	else return Color3.fromRGB(255, 80, 80) end
end
_G.distanceColor = distanceColor

local function ensureESPForPlayer(plr)
	if espState.individual[plr] then return espState.individual[plr] end
	local data = { hl = nil, bill = nil, label = nil, targetPart = nil, humanoid = nil }
	espState.individual[plr] = data
	return data
end
_G.ensureESPForPlayer = ensureESPForPlayer

local function buildESP(plr)
	local data = ensureESPForPlayer(plr)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local targetPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChildWhichIsA("BasePart")
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
_G.buildESP = buildESP

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

		-- icone chat isolee a cote du nom (pas de texte)
		data.chatIcon = Instance.new("TextLabel")
		data.chatIcon.Size = UDim2.new(0, 20, 0, 20)
		data.chatIcon.Position = UDim2.new(0, 226, 0, 0)
		data.chatIcon.BackgroundTransparency = 1
		data.chatIcon.Text = "?"
		data.chatIcon.Font = Enum.Font.GothamBold
		data.chatIcon.TextSize = 14
		data.chatIcon.TextColor3 = Color3.new(1, 1, 1)
		data.chatIcon.TextStrokeTransparency = 0.2
		data.chatIcon.Visible = false
		data.chatIcon.Parent = data.bill
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
_G.clearESP = clearESP

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
_G.refreshESP = refreshESP
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
_G.blinkESP = blinkESP
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
			-- icone chat isolee (toggle)
			if data.chatIcon then
				data.chatIcon.Visible = espState.chatIcons and (data.canChat == true)
			end
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
					data.label.Text = ">> " .. plr.Name .. " [" .. math.floor(dist) .. " studs] HP:" .. hp
					data.label.TextColor3 = pulse and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 0, 0)
				end
				if data.bill then data.bill.Enabled = true end
			else
				local col = distanceColor(dist)
				if data.label then
					local hp = data.humanoid and math.floor(data.humanoid.Health) or 0
					data.label.Text = plr.Name .. " [" .. math.floor(dist) .. " studs] HP:" .. hp
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
	local hrp = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Torso") or plr.Character:FindFirstChild("UpperTorso") or plr.Character:FindFirstChildWhichIsA("BasePart")
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
_G.applyGlobalESPToPlayer = applyGlobalESPToPlayer

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


updateLoad(0.22, "Animations...")
task.wait(0.05)
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
_G.typewriterEffect = typewriterEffect
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
_G.matrixRain = matrixRain
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
	bootGui.Name = "MilanEmerickBoot"
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
_G.bootSequence = bootSequence

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
		if not ok then warn("[MILAN] boot crash: " .. tostring(err)) end
		pcall(function() if bootGui and bootGui.Parent then bootGui:Destroy() end end)
		if onComplete then pcall(function() onComplete() end) end
	end)
end

updateLoad(0.30, "Mouvement...")
task.wait(0.05)
-- ============= MOVE =============
local flyState = { flying = false, speed = 120, gyro = nil, vel = nil, loop = nil, mobileInput = Vector3.zero, mobileUp = false, mobileDown = false, mobileStickId = nil, mobileBase = nil, mobileKnob = nil, mobileBasePos = nil, mobileUiCreated = false, saMode = false, anchored = false }
local noclipState = { enabled = false }
local walkSpeedState = { value = 16 }
local jumpState = { infinite = false }
local platformState = { enabled = false, part = nil, y = 0, offset = 0 }

local flySwitch  -- forward-declare (assigned later)
local function stopFly()
	if not flyState.flying then return end
	flyState.flying = false
	if flyState.loop then flyState.loop:Disconnect() flyState.loop = nil end

	if flyState.saMode then
		-- SA mode: unanchor
		pcall(function()
			local char = LocalPlayer.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.Anchored = false
			end
		end)
		flyState.anchored = false
	else
		-- Normal mode: destroy body movers
		if flyState.gyro then flyState.gyro:Destroy() flyState.gyro = nil end
		if flyState.vel then flyState.vel:Destroy() flyState.vel = nil end
	end

	flyState.mobileInput = Vector3.zero
	flyState.mobileUpHeld = false
	flyState.mobileDownHeld = false
	flyState.mobileStickId = nil
	if flyState.showMobileUi then flyState.showMobileUi(false) end
	updateCharacter()
	if humanoid then humanoid.PlatformStand = false end
	flySwitch.set(false)
	-- Active la grace anti-TP pour reinitialiser la baseline sans bounce
	if protectionsState then
		protectionsState.antiTeleportGraceUntil = tick() + 0.4
	end
end

_G.stopFly = stopFly

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
		upBtn.Text = "?"
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
		dnBtn.Text = "?"
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

local function isServerAuthority()
	local ws = game:GetService("Workspace")
	local ok, am = pcall(function() return ws.AuthorityMode end)
	if ok and am == Enum.AuthorityMode.Server then return true end
	return false
end

local function startFly()
	updateCharacter()
	if flyState.flying or not rootPart then return end
	flyState.flying = true
	flyState.saMode = isServerAuthority()

	if flyState.saMode then
		-- SERVER AUTHORITY BYPASS: Anchored + CFrame (BodyVelocity rolled back by server)
		if humanoid then humanoid.PlatformStand = true end
		flyState.anchored = true
		pcall(function() rootPart.Anchored = true end)
		if humanoid then
			pcall(function() humanoid.PlatformStand = true end)
		end
	else
		-- NORMAL MODE: BodyVelocity + BodyGyro
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

		-- SURELEVATION: lever le personnage pendant 1s pour eviter le bruit de marche
		flyState.liftOffTime = tick() + 1.0
		task.spawn(function()
			while flyState.flying and tick() < (flyState.liftOffTime or 0) do
				task.wait(0.03)
				if rootPart and flyState.vel then
					local remaining = (flyState.liftOffTime or 0) - tick()
					local liftSpeed = math.max(remaining, 0) * 8
					flyState.vel.Velocity = Vector3.new(0, liftSpeed, 0)
				end
			end
		end)
	end

	-- Show mobile UI on touch devices
	if flyState.isMobile and flyState.isMobile() and flyState.showMobileUi then
		flyState.showMobileUi(true)
	end

	flyState.loop = RunService.RenderStepped:Connect(function()
		updateCharacter()
		if not flyState.flying or not rootPart or not rootPart.Parent then return end

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
			local cf = rootPart.CFrame
			if move.Magnitude > 0.1 then
				local delta = move.Unit * flyState.speed * 0.016
				pcall(function() rootPart.CFrame = cf + delta end)
			end
			-- Orientation: yaw + dynamic pitch (same as normal fly)
			local camLook = Camera.CFrame.LookVector
			local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
			if flatLook.Magnitude > 0.01 then
				local yawCFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
				local camPitch = math.asin(math.clamp(camLook.Y, -1, 1))
				local movePitch = 0
				if move.Magnitude > 0.1 then
					local forwardDot = move:Dot(Camera.CFrame.LookVector)
					movePitch = math.clamp(forwardDot * 0.15, -0.26, 0.44)
				end
				local totalPitch = math.clamp(camPitch * 0.6 + movePitch, -0.7, 0.7)
				pcall(function() rootPart.CFrame = yawCFrame * CFrame.Angles(totalPitch, 0, 0) end)
			end
		else
			-- NORMAL MODE: BodyVelocity + BodyGyro
			-- Re-attach body movers if rootPart changed (respawn)
			if flyState.gyro and flyState.gyro.Parent ~= rootPart then flyState.gyro.Parent = rootPart end
			if flyState.vel and flyState.vel.Parent ~= rootPart then flyState.vel.Parent = rootPart end

			-- Gyro: personnage droit + penche naturellement quand il bouge + s'incline selon ou on regarde
			if flyState.gyro then
				local camLook = Camera.CFrame.LookVector
				local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
				if flatLook.Magnitude > 0.01 then
					local yawCFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
					local camPitch = math.asin(math.clamp(camLook.Y, -1, 1))
					local movePitch = 0
					if move.Magnitude > 0.1 then
						local forwardDot = move:Dot(Camera.CFrame.LookVector)
						movePitch = math.clamp(forwardDot * 0.15, -0.26, 0.44)
					end
					local totalPitch = math.clamp(camPitch * 0.6 + movePitch, -0.7, 0.7)
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

_G.startFly = startFly

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
	-- clics sur le container parent sont perdus -> le slider "marche mal")
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

_G.createSlider = createSlider

flySwitch = createSwitch(movePage, "Fly", 10, function(on)
	if on then startFly() else stopFly() end
end)

local flySlider = createSlider(movePage, "Vitesse Fly", 52, 20, 500, flyState.speed, function(v)
	flyState.speed = math.floor(v)
end, Color3.fromRGB(100, 180, 255))

local noclipSwitch = createSwitch(movePage, "NoClip", 108, function(on)
	noclipState.enabled = on
	if not on then
		updateCharacter()
		local char = LocalPlayer.Character
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
			end
		end
		-- Active la grace anti-TP apres sortie du noclip
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
_G.clearWalkVisuals = clearWalkVisuals
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
_G.visualizeWaypoints = visualizeWaypoints
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

	local myPos = rootPart.Position
	local flatDist = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Magnitude
	local waypoints = {}

	-- Helper: raycast clearance check
	local function rayClear(from, to)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local dir = to - from
		local dist = dir.Magnitude
		if dist < 0.1 then return true end
		local hit = Workspace:Raycast(from, dir.Unit * dist, params)
		return hit == nil
	end

	-- Helper: find best height for a direction
	local function findBestHeight(from, dir, dist)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude
		local heights = {0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15}
		local bestH = nil
		local bestScore = math.huge
		for _, h in ipairs(heights) do
			local origin = from + Vector3.new(0, h, 0)
			local hit = Workspace:Raycast(origin, dir * (dist + 1), params)
			if not hit then
				local score = math.abs(h - math.max(0, targetPos.Y - from.Y))
				if score < bestScore then bestScore = score; bestH = h end
			end
		end
		return bestH
	end

	-- 1) PathfindingService Roblox (parametres optimises longues distances)
	local ok, pathOrErr = pcall(function()
		local p = PathfindingService:CreatePath({
			AgentRadius = 1.5,
			AgentHeight = 4.5,
			AgentCanJump = true,
			AgentCanClimb = true,
			WaypointSpacing = 6,
			Costs = { Climbing = 3, Jumping = 2 }
		})
		p:ComputeAsync(myPos, targetPos)
		return p:GetWaypoints()
	end)

	if ok and pathOrErr and #pathOrErr > 0 then
		for i, wp in ipairs(pathOrErr) do
			if wp and wp.Position then table.insert(waypoints, wp.Position) end
		end
		if #waypoints > 1 then table.remove(waypoints, 1) end
		if #waypoints > 0 then return waypoints end
	end

	-- 2) Longue distance: decouper le trajet en segments de 25 studs
	if flatDist > 30 then
		local dir = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Unit
		local segmentLen = 25
		local segments = math.floor(flatDist / segmentLen)
		local prevPos = myPos
		
		for i = 1, segments do
			local segTarget = myPos + dir * (i * segmentLen)
			-- Find ground at this point
			local gParams = RaycastParams.new()
			gParams.FilterDescendantsInstances = {character}
			gParams.FilterType = Enum.RaycastFilterType.Exclude
			local ground = Workspace:Raycast(segTarget + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), gParams)
			if ground then
				segTarget = Vector3.new(segTarget.X, ground.Position.Y + 2, segTarget.Z)
			end
			-- Check if clear path to this segment
			if rayClear(prevPos, segTarget) then
				table.insert(waypoints, segTarget)
				prevPos = segTarget
			else
				-- Try to find a path around obstacle at this segment
				local bestH = findBestHeight(prevPos, dir, segmentLen)
				if bestH then
					local mid = prevPos + dir * (segmentLen * 0.5)
					segTarget = Vector3.new(mid.X, prevPos.Y + bestH, mid.Z)
					table.insert(waypoints, segTarget)
					prevPos = segTarget
				else
					-- Try going around: left/right offsets
					local offsets = {Vector3.new(0,0,5), Vector3.new(0,0,-5), Vector3.new(5,0,0), Vector3.new(-5,0,0)}
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
						-- Just add the target anyway, MoveTo will handle
						table.insert(waypoints, segTarget)
						prevPos = segTarget
					end
				end
			end
		end
		-- Final segment to exact target
		if rayClear(prevPos, targetPos) then
			table.insert(waypoints, targetPos)
		else
			-- Try to find ground at target
			local gParams = RaycastParams.new()
			gParams.FilterDescendantsInstances = {character}
			gParams.FilterType = Enum.RaycastFilterType.Exclude
			local ground = Workspace:Raycast(targetPos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), gParams)
			if ground then
				table.insert(waypoints, Vector3.new(targetPos.X, ground.Position.Y + 2, targetPos.Z))
			else
				table.insert(waypoints, targetPos)
			end
		end
		if #waypoints > 0 then return waypoints end
	end

	-- 3) Multi-hauteur raycast (courte distance)
	local function findClearPath(from, to)
		local dir = to - from
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		local d = flatDir.Magnitude
		if d < 0.5 then return to end
		local unit = flatDir / d
		local bestH = findBestHeight(from, unit, d)
		if bestH then
			local mid = from + unit * math.min(10, d * 0.35)
			return Vector3.new(mid.X, from.Y + bestH, mid.Z)
		end
		return nil
	end

	local mid = findClearPath(myPos, targetPos)
	if mid then
		local mid2 = findClearPath(mid, targetPos)
		if mid2 then return {mid, mid2} end
		return {mid}
	end

	-- 4) Fallback final: step forward
	local flat = Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z)
	if flat.Magnitude > 0.1 then
		local step = myPos + flat.Unit * math.min(6, flat.Magnitude * 0.3)
		local gParams = RaycastParams.new()
		gParams.FilterDescendantsInstances = {character}
		gParams.FilterType = Enum.RaycastFilterType.Exclude
		local ground = Workspace:Raycast(step + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), gParams)
		if ground then step = Vector3.new(step.X, ground.Position.Y + 2, step.Z) end
		return { step }
	end
	return {}
end

_G.computePathTo = computePathTo

local gotoWalkSwitch = createSwitch(movePage, "Go to Walk (click sol)", 150, function(on)
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
_G.refreshNoClipSwitch = refreshNoClipSwitch

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

local zeroGSwitch = createSwitch(localPage, "Zero Gravite", 10, function(on)
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
_=(function()
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

local function _agoraSetGravityExact(v)
	v = tonumber(v)
	if not v then return end
	v = math.clamp(math.floor(v + 0.5), 0, 300)
	localState.customGravity = v
	Workspace.Gravity = v
	gravityLabel.Text = "Gravite custom : " .. v
	gravityInput.Text = tostring(v)
	gravityFill.Size = UDim2.new(v / 300, 0, 1, 0)
end
_G._agoraSetGravityExact = _agoraSetGravityExact

local draggingGravity = false
local function gravityFromX(x)
	local rel = math.clamp((x - gravityTrack.AbsolutePosition.X) / gravityTrack.AbsoluteSize.X, 0, 1)
	return math.floor(rel * 300 + 0.5)
end
_G.gravityFromX = gravityFromX

gravityTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingGravity = true
		_G._agoraSetGravityExact(gravityFromX(input.Position.X))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingGravity = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if draggingGravity and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		_G._agoraSetGravityExact(gravityFromX(input.Position.X))
	end
end)

gravityInput.FocusLost:Connect(function(enterPressed)
	_G._agoraSetGravityExact(gravityInput.Text)
end)

local resetGravityBtn = createButton(localPage, "Reset gravite normale", 148, Color3.fromRGB(80, 80, 90), function()
	_G._agoraSetGravityExact(196.2)
end)
resetGravityBtn.Size = UDim2.new(1, -16, 0, 30)
resetGravityBtn.Position = UDim2.new(0, 8, 0, 148)
end)()

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
	_G._agoraSetGravityExact(196.2)
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

-- Toggle icones chat sur l'ESP
local chatIconsSwitch = createSwitch(localPage, "Icones chat ESP", 448, function(on)
	espState.chatIcons = on
end)
chatIconsSwitch.set(true)


updateLoad(0.40, "Auto Clicker...")
task.wait(0.05)


-- Export createSlider for any late use
_G.createSlider = createSlider

-- Reveal panel and switch to Home
task.spawn(function()
    task.wait(0.1)
    pcall(function()
        if mainFrame and not mainFrame.Visible then
            mainFrame.Visible = true
        end
    end)
    pcall(function()
        if pages and pages["Home"] then
            switchTab("Home")
        end
    end)
    pcall(function()
        if loadingGui and loadingGui.Parent then
            loadingGui:Destroy()
        end
    end)
end)
