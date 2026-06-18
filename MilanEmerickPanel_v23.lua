-- Panel Roblox universel amélioré - by Milan & Emerick
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

local walkSpeedState = { value = 16 }
local jumpPowerState = { value = 50 }
local flyState = { flying = false, speed = 120, gyro = nil, vel = nil, loop = nil }
local noclipState = { enabled = false }
local platformState = { enabled = false, part = nil, y = 0, offset = 0 }

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
	TweenService:Create(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MilanEmerickPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Backdrop retiré : il recouvrait tout l'écran en noir semi-transparent.

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 460, 0, 520)
mainFrame.Position = UDim2.new(0.5, -230, 0.5, -260)
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
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 1
createCorner(mainFrame, 14)
createStroke(mainFrame, Color3.fromRGB(120, 120, 150), 1.2)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
topBar.BackgroundTransparency = 0.45
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
topBar.ZIndex = 2
createCorner(topBar, 14)
createStroke(topBar, Color3.fromRGB(80, 80, 100), 0.8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Milan & Emerick Panel | " .. getDeviceType()
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
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -68, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
minimizeBtn.Text = ""
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
makeIcon(minimizeBtn, "−")

local function createButton(parent, text, yPos, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 34)
	btn.Position = UDim2.new(0, 8, 0, yPos)
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
	btn.MouseButton1Click:Connect(callback)
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
	btn.Size = UDim2.new(0, 70, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	btn.Text = name
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 10
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
local serverPage = createTab("Serveur")
local localPage = createTab("Local")
local protectionsPage = createTab("Protections")

local protectionsScroll = Instance.new("ScrollingFrame")
protectionsScroll.Size = UDim2.new(1, 0, 1, 0)
protectionsScroll.BackgroundTransparency = 1
protectionsScroll.ScrollBarThickness = 4
protectionsScroll.BorderSizePixel = 0
protectionsScroll.CanvasSize = UDim2.new(0, 0, 0, 900)
protectionsScroll.Parent = protectionsPage

local protectionsLayout = Instance.new("UIListLayout")
protectionsLayout.Padding = UDim.new(0, 6)
protectionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
protectionsLayout.Parent = protectionsScroll

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

local minimized = false
minimizeBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	contentFrame.Visible = not minimized
	tabBar.Visible = not minimized
	tween(mainFrame, {Size = minimized and UDim2.new(0, 460, 0, 52) or UDim2.new(0, 460, 0, 520)}, 0.2)
end)

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
		local goodbye = Instance.new("TextLabel")
		goodbye.Size = UDim2.new(1, 0, 0, 40)
		goodbye.Position = UDim2.new(0, 0, 0.5, -20)
		goodbye.BackgroundTransparency = 1
		goodbye.Text = "Au revoir " .. LocalPlayer.DisplayName .. " revenez vite... 3:)"
		goodbye.Font = Enum.Font.GothamBold
		goodbye.TextSize = 22
		goodbye.TextColor3 = Color3.fromRGB(120, 255, 180)
		goodbye.TextTransparency = 1
		goodbye.ZIndex = 1000
		goodbye.Parent = screenGui
		TweenService:Create(goodbye, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
		task.delay(2.5, function()
			TweenService:Create(goodbye, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			task.delay(0.6, function()
				screenGui.Enabled = false
				if goodbye then goodbye:Destroy() end
			end)
		end)
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

local function createSwitch(parent, labelText, yPos, callback, defaultOn)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -16, 0, 36)
	container.Position = UDim2.new(0, 8, 0, yPos)
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
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -10, 0, 28)
searchBox.Position = UDim2.new(0, 5, 0, 5)
searchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
searchBox.BackgroundTransparency = 0.2
searchBox.TextColor3 = Color3.fromRGB(230, 230, 230)
searchBox.PlaceholderText = "Rechercher un joueur..."
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.TextXAlignment = Enum.TextXAlignment.Center
searchBox.ClearTextOnFocus = false
searchBox.Parent = playersPage
createCorner(searchBox, 8)
createStroke(searchBox, Color3.fromRGB(80, 80, 100), 1)

local playersScroll = Instance.new("ScrollingFrame")
playersScroll.Size = UDim2.new(1, -10, 1, -55)
playersScroll.Position = UDim2.new(0, 5, 0, 38)
playersScroll.BackgroundTransparency = 1
playersScroll.ScrollBarThickness = 4
playersScroll.BorderSizePixel = 0
playersScroll.Parent = playersPage

local playersLayout = Instance.new("UIListLayout")
playersLayout.Padding = UDim.new(0, 6)
playersLayout.SortOrder = Enum.SortOrder.LayoutOrder
playersLayout.Parent = playersScroll

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
	card.Size = UDim2.new(1, -8, 0, 108)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	card.BorderSizePixel = 0
	card.LayoutOrder = plr.Name:byte(1)
	card.Parent = playersScroll
	createCorner(card, 10)
	createStroke(card, Color3.fromRGB(45, 45, 55), 1)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -12, 0, 18)
	nameLbl.Position = UDim2.new(0, 6, 0, 4)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = card

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

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.55, -6, 0, 14)
	statusLbl.Position = UDim2.new(0, 6, 0, 80)
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

	local invBtn = Instance.new("TextButton")
	invBtn.Size = UDim2.new(0, 80, 0, 24)
	invBtn.Position = UDim2.new(1, -70, 0, 82)
	invBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
	invBtn.Text = "Inventaire"
	invBtn.Font = Enum.Font.GothamSemibold
	invBtn.TextSize = 10
	invBtn.TextColor3 = Color3.new(1, 1, 1)
	invBtn.BorderSizePixel = 0
	invBtn.Parent = card
	createCorner(invBtn, 6)

	local inventoryOpen = false
	local invFrame = nil

	local function closeInventory()
		if invFrame then
			invFrame:Destroy()
			invFrame = nil
		end
		inventoryOpen = false
		invBtn.Text = "Inventaire"
		invBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
	end

	local function refreshInventory()
		if not invFrame then return end
		for _, c in ipairs(invFrame.ScrollingFrame:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
		end
		local items = {}
		if LocalPlayer:FindFirstChild("Backpack") then
			for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
				if tool:IsA("Tool") then table.insert(items, tool) end
			end
		end
		local char = LocalPlayer.Character
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then table.insert(items, tool) end
			end
		end
		if #items == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, -10, 0, 30)
			empty.Position = UDim2.new(0, 5, 0, 5)
			empty.BackgroundTransparency = 1
			empty.Text = "Inventaire vide"
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 12
			empty.TextColor3 = Color3.fromRGB(180, 180, 180)
			empty.Parent = invFrame.ScrollingFrame
		else
			for i, tool in ipairs(items) do
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -10, 0, 28)
				row.Position = UDim2.new(0, 5, 0, (i - 1) * 32)
				row.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
				row.Text = tool.Name
				row.Font = Enum.Font.GothamSemibold
				row.TextSize = 11
				row.TextColor3 = Color3.new(1, 1, 1)
				row.BorderSizePixel = 0
				row.Parent = invFrame.ScrollingFrame
				createCorner(row, 6)
				row.MouseButton1Click:Connect(function()
					-- cloner l'outil dans notre backpack si possible
					local clone = tool:Clone()
					if clone then
						clone.Parent = LocalPlayer.Backpack
					end
				end)
			end
		end
		invFrame.ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#items * 32, invFrame.ScrollingFrame.AbsoluteSize.Y))
	end

	invBtn.MouseButton1Click:Connect(function()
		if inventoryOpen then
			closeInventory()
		else
			inventoryOpen = true
			invBtn.Text = "Fermer"
			invBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60)

			invFrame = Instance.new("Frame")
			invFrame.Size = UDim2.new(0, 260, 0, 300)
			local bx, by = invBtn.AbsolutePosition.X, invBtn.AbsolutePosition.Y
			invFrame.Position = UDim2.new(0, math.max(10, bx - 270), 0, math.min(by, screenGui.AbsoluteSize.Y - 310))
			invFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
			invFrame.BorderSizePixel = 0
			invFrame.ZIndex = 1000
			invFrame.Parent = screenGui
			createCorner(invFrame, 10)
			createStroke(invFrame, Color3.fromRGB(80, 80, 100), 1)

			-- Créer le ScrollingFrame AVANT refreshInventory
			local scroll = Instance.new("ScrollingFrame")
			scroll.Name = "ScrollingFrame"
			scroll.Size = UDim2.new(1, -10, 1, -38)
			scroll.Position = UDim2.new(0, 5, 0, 32)
			scroll.BackgroundTransparency = 1
			scroll.ScrollBarThickness = 4
			scroll.BorderSizePixel = 0
			scroll.ZIndex = 1001
			scroll.Parent = invFrame

			local invTitle = Instance.new("TextLabel")
			invTitle.Size = UDim2.new(1, -10, 0, 24)
			invTitle.Position = UDim2.new(0, 5, 0, 5)
			invTitle.BackgroundTransparency = 1
			invTitle.Text = "Inventaire de @" .. plr.Name
			invTitle.Font = Enum.Font.GothamBold
			invTitle.TextSize = 12
			invTitle.TextColor3 = Color3.new(1, 1, 1)
			invTitle.ZIndex = 1001
			invTitle.Parent = invFrame

			local closeBtn = Instance.new("TextButton")
			closeBtn.Size = UDim2.new(0, 24, 0, 24)
			closeBtn.Position = UDim2.new(1, -29, 0, 5)
			closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
			closeBtn.Text = "X"
			closeBtn.Font = Enum.Font.GothamBold
			closeBtn.TextSize = 12
			closeBtn.TextColor3 = Color3.new(1, 1, 1)
			closeBtn.BorderSizePixel = 0
			closeBtn.ZIndex = 1001
			closeBtn.Parent = invFrame
			createCorner(closeBtn, 6)
			closeBtn.MouseButton1Click:Connect(closeInventory)

			refreshInventory()
		end
	end)

	plr.Backpack.ChildAdded:Connect(function() if inventoryOpen then refreshInventory() end end)
	plr.Backpack.ChildRemoved:Connect(function() if inventoryOpen then refreshInventory() end end)
	plr.CharacterAdded:Connect(function() if inventoryOpen then task.delay(0.5, refreshInventory) end end)

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
						if flatSpeed > 2 then
							stateText = (h.WalkSpeed > 18 or flatSpeed > 18) and "Running" or "Walking"
						end
					end
					statusLbl.Text = "Statut: " .. stateText
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

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = searchBox.Text:lower():gsub("%s+", "")
	local matches = {}
	for plr, card in pairs(playerCards) do
		if not plr or not card then continue end
		local match = q == "" or plr.Name:lower():find(q, 1, true) ~= nil or plr.DisplayName:lower():find(q, 1, true) ~= nil
		card.Visible = match
		if match and q ~= "" then table.insert(matches, plr) end
	end
	playersScroll.CanvasSize = UDim2.new(0, 0, 0, playersLayout.AbsoluteContentSize.Y + 10)
	if #matches == 1 then
		local singlePlr = matches[1]
		if singlePlr and singlePlr.Character then
			local card = playerCards[singlePlr]
			if card and card.Parent then
				tween(card, {BackgroundColor3 = Color3.fromRGB(70, 50, 100)}, 0.2)
				task.delay(1.2, function()
					if card and card.Parent then
						tween(card, {BackgroundColor3 = Color3.fromRGB(28, 28, 35)}, 0.3)
					end
				end)
			end
		end
	end
end)

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
	return data
end

local function clearESP()
	for _, child in ipairs(espFolder:GetChildren()) do child:Destroy() end
	espState.individual = {}
end

local function refreshESP()
	clearESP()
	if not espState.enabled then return end
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
	local bootGui = Instance.new("ScreenGui")
	bootGui.Name = "MilanEmerickBoot"
	bootGui.ResetOnSpawn = false
	bootGui.DisplayOrder = 9999
	bootGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local bootFrame = Instance.new("Frame")
	bootFrame.Size = UDim2.new(1, 0, 1, 0)
	bootFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
	bootFrame.BackgroundTransparency = 0.15
	bootFrame.BorderSizePixel = 0
	bootFrame.ZIndex = 100
	bootFrame.Parent = bootGui

	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.new(1.5, 0, 1.5, 0)
	vignette.Position = UDim2.new(-0.25, 0, -0.25, 0)
	vignette.BackgroundTransparency = 1
	vignette.Image = "rbxassetid://9638773891"
	vignette.ImageColor3 = Color3.fromRGB(0, 0, 0)
	vignette.ImageTransparency = 0.45
	vignette.ZIndex = 101
	vignette.Parent = bootFrame

	local title = Instance.new("TextLabel")
	title.Name = "BootTitle"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0.38, 0)
	title.BackgroundTransparency = 1
	title.Text = "MILAN  x  EMERICK"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 44
	title.TextColor3 = Color3.fromRGB(230, 230, 255)
	title.TextTransparency = 1
	title.TextStrokeTransparency = 0.85
	title.ZIndex = 102
	title.Parent = bootFrame

	local helloLabel = Instance.new("TextLabel")
	helloLabel.Size = UDim2.new(1, 0, 0, 32)
	helloLabel.Position = UDim2.new(0, 0, 0.48, 0)
	helloLabel.BackgroundTransparency = 1
	helloLabel.Text = "Bonjour " .. LocalPlayer.DisplayName
	helloLabel.Font = Enum.Font.GothamBold
	helloLabel.TextSize = 20
	helloLabel.TextColor3 = Color3.fromRGB(120, 255, 180)
	helloLabel.TextTransparency = 1
	helloLabel.ZIndex = 102
	helloLabel.Parent = bootFrame

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.Position = UDim2.new(0, 0, 0.54, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "PANEL // SYSTEM BOOT"
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextSize = 15
	subtitle.TextColor3 = Color3.fromRGB(120, 180, 255)
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 102
	subtitle.Parent = bootFrame

	local progress = Instance.new("Frame")
	progress.Size = UDim2.new(0, 0, 0, 3)
	progress.Position = UDim2.new(0.35, 0, 0.60, 0)
	progress.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
	progress.BorderSizePixel = 0
	progress.ZIndex = 102
	progress.Parent = bootFrame

	local progressGlow = Instance.new("ImageLabel")
	progressGlow.Size = UDim2.new(1, 40, 1, 20)
	progressGlow.Position = UDim2.new(0, -20, 0, -10)
	progressGlow.BackgroundTransparency = 1
	progressGlow.Image = "rbxassetid://9638773891"
	progressGlow.ImageColor3 = Color3.fromRGB(80, 150, 255)
	progressGlow.ImageTransparency = 0.7
	progressGlow.ZIndex = 101
	progressGlow.Parent = progress

	local lines = {}
	for i = 1, 6 do
		local line = Instance.new("TextLabel")
		line.Size = UDim2.new(1, -40, 0, 20)
		line.Position = UDim2.new(0, 20, 0.64, (i - 1) * 22)
		line.BackgroundTransparency = 1
		line.Text = ""
		line.Font = Enum.Font.Code
		line.TextSize = 13
		line.TextColor3 = Color3.fromRGB(0, 255, 120)
		line.TextTransparency = 1
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.ZIndex = 102
		line.Parent = bootFrame
		lines[i] = line
	end

	local bootMessages = {
		"> Initializing core modules...",
		"> Mounting interface...",
		"> Synchronizing player data...",
		"> Linking camera feed...",
		"> Establishing secure handshake...",
		"> Welcome, " .. LocalPlayer.Name .. "."
	}

	local function glitchOnce()
		local original = title.Text
		local glitchChars = {"!", "@", "#", "$", "%", "&", "*", "x", "0", "1"}
		local g = ""
		for j = 1, #original do
			if math.random() < 0.25 then
				g = g .. glitchChars[math.random(1, #glitchChars)]
			else
				g = g .. original:sub(j, j)
			end
		end
		title.Text = g
		task.wait(0.05)
		title.Text = original
	end

	matrixRain(bootFrame, 2.8)

	task.spawn(function()
		local ti = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(title, ti, {TextTransparency = 0}):Play()
		task.wait(0.15)
		TweenService:Create(helloLabel, ti, {TextTransparency = 0}):Play()
		task.wait(0.15)
		TweenService:Create(subtitle, ti, {TextTransparency = 0}):Play()
		for _, line in ipairs(lines) do
			TweenService:Create(line, ti, {TextTransparency = 0.25}):Play()
		end

		for i, msg in ipairs(bootMessages) do
			local line = lines[i]
			for j = 1, #msg do
				line.Text = msg:sub(1, j)
				task.wait(0.018)
			end
			local pct = i / #bootMessages
			TweenService:Create(progress, TweenInfo.new(0.25), {Size = UDim2.new(pct * 0.3, 0, 0, 3)}):Play()
			if i == 3 or i == 5 then
				glitchOnce()
			end
			task.wait(0.25)
		end

		progress.BackgroundColor3 = Color3.fromRGB(60, 255, 120)
		TweenService:Create(progress, TweenInfo.new(0.25), {Size = UDim2.new(0.3, 0, 0, 3)}):Play()
		task.wait(0.6)

		TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(helloLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(progress, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
		TweenService:Create(bootFrame, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()

		for _, line in ipairs(lines) do
			TweenService:Create(line, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
		end
		task.wait(1.0)
		bootGui:Destroy()
		if onComplete then onComplete() end
	end)
end

-- ============= MOVE =============
local flyState = { flying = false, speed = 120, gyro = nil, vel = nil, loop = nil }
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
	updateCharacter()
	if humanoid then humanoid.PlatformStand = false end
	flySwitch.set(false)
end

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

	flyState.loop = RunService.RenderStepped:Connect(function()
		updateCharacter()
		if not flyState.flying or not rootPart then return end
		if flyState.gyro then flyState.gyro.CFrame = Camera.CFrame end

		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Z) then move += Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end

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
	end
end)

createSwitch(movePage, "Saut infini", 150, function(on)
	jumpState.infinite = on
end)

local function refreshNoClipSwitch()
	noclipSwitch.set(false)
end

local walkSlider = createSlider(movePage, "Vitesse marche", 192, 1, 250, 16, function(v)
	walkSpeedState.value = math.floor(v)
	updateCharacter()
	if humanoid then humanoid.WalkSpeed = walkSpeedState.value end
end, Color3.fromRGB(255, 100, 100))

local walkResetBtn = createButton(movePage, "Reset vitesse", 246, Color3.fromRGB(80, 80, 90), function()
	walkSpeedState.value = 16
	walkSlider.set(16)
	updateCharacter()
end)

local jumpSlider = createSlider(movePage, "Puissance saut", 296, 10, 300, 50, function(v)
	jumpPowerState.value = math.floor(v)
	updateCharacter()
	if humanoid then humanoid.JumpPower = jumpPowerState.value end
end, Color3.fromRGB(255, 200, 100))

local jumpResetBtn = createButton(movePage, "Reset saut", 350, Color3.fromRGB(80, 80, 90), function()
	jumpPowerState.value = 50
	jumpSlider.set(50)
	updateCharacter()
	if humanoid then humanoid.JumpPower = 50 end
end)

local speedLockConnection = RunService.RenderStepped:Connect(function()
	updateCharacter()
	if humanoid then
		if humanoid.WalkSpeed ~= walkSpeedState.value then
			humanoid.WalkSpeed = walkSpeedState.value
		end
		if humanoid.JumpPower ~= jumpPowerState.value then
			humanoid.JumpPower = jumpPowerState.value
		end
	end
end)

local platformLabel = Instance.new("TextLabel")
platformLabel.Size = UDim2.new(1, -16, 0, 30)
platformLabel.Position = UDim2.new(0, 8, 0, 400)
platformLabel.BackgroundTransparency = 1
platformLabel.Text = "Plateforme invisible : F10 ON/OFF | + monter | - descendre"
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
	active = false,
	speed = 0.05,
	mode = "auto",
	activeThread = nil,
	clickTarget = nil,     -- BillboardGui côté joueur
	worldTarget = nil,     -- Part 3D invisible dans le workspace
	worldConnections = {},
}

local function setAutoClickSave()
	local savedPos = nil
	if autoClickState.worldTarget then
		savedPos = {autoClickState.worldTarget.Position.X, autoClickState.worldTarget.Position.Y, autoClickState.worldTarget.Position.Z}
	end
	panelMemory.autoClick = {
		speed = autoClickState.speed,
		mode = autoClickState.mode,
		targetWorldPos = savedPos,
	}
end

local function fireClickAtPos(x, y)
	for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
		if gui ~= screenGui and gui:IsA("ScreenGui") then
			local ap, as = gui.AbsolutePosition, gui.AbsoluteSize
			if as.X > 0 and as.Y > 0 and x >= ap.X and x <= ap.X + as.X and y >= ap.Y and y <= ap.Y + as.Y then
				local function fireBtn(obj)
					if obj:IsA("TextButton") or obj:IsA("ImageButton") then
						local bap, bas = obj.AbsolutePosition, obj.AbsoluteSize
						if bas.X > 0 and bas.Y > 0 and x >= bap.X and x <= bap.X + bas.X and y >= bap.Y and y <= bap.Y + bas.Y then
							pcall(function()
								obj.MouseButton1Down:Fire(Vector2.new(x - bap.X, y - bap.Y))
								obj.MouseButton1Click:Fire()
								obj.MouseButton1Up:Fire(Vector2.new(x - bap.X, y - bap.Y))
							end)
						end
					end
					for _, c in ipairs(obj:GetChildren()) do fireBtn(c) end
				end
				fireBtn(gui)
			end
		end
	end
	local ray = Workspace.CurrentCamera:ScreenPointToRay(x, y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = {LocalPlayer.Character}
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result and result.Instance then
		local tgt = result.Instance
		if tgt:IsA("ClickDetector") then fireclickdetector(tgt); return end
		local cd = tgt:FindFirstChildOfClass("ClickDetector")
		if cd then fireclickdetector(cd); return end
		local model = tgt:FindFirstAncestorOfClass("Model")
		if model then
			pcall(function()
				for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
					if r:IsA("RemoteEvent") and (r.Name:lower():find("click") or r.Name:lower():find("activate")) then
						r:FireServer(model, tgt, result.Position)
					end
				end
			end)
		end
	end
end

local function stopAutoClickEngine()
	autoClickState.active = false
	autoClickState.activeThread = nil
end

local function startAutoClickEngine()
	if not autoClickState.worldTarget then return end
	stopAutoClickEngine()
	autoClickState.active = true
	local interval = math.max(0.001, autoClickState.speed)
	local threadId = {}
	autoClickState.activeThread = threadId
	local function loop()
		while autoClickState.active and autoClickState.activeThread == threadId and autoClickState.worldTarget and autoClickState.worldTarget.Parent do
			local worldPos = autoClickState.worldTarget.Position
			local screenPos, onScreen = Camera:WorldToScreenPoint(worldPos)
			if onScreen then
				fireClickAtPos(screenPos.X, screenPos.Y)
			end
			task.wait(interval)
		end
	end
	if autoClickState.mode == "rapid" then
		for i = 1, 3 do task.spawn(loop) end
	else
		task.spawn(loop)
	end
end

local function removeClickTarget()
	stopAutoClickEngine()
	if autoClickState.worldTarget then
		for _, c in ipairs(autoClickState.worldConnections) do
			pcall(function() c:Disconnect() end)
		end
		autoClickState.worldConnections = {}
		autoClickState.worldTarget:Destroy()
		autoClickState.worldTarget = nil
	end
	if autoClickState.clickTarget then
		autoClickState.clickTarget:Destroy()
		autoClickState.clickTarget = nil
	end
end

local function worldToScreenPoint(worldPos)
	local pos, onScreen = Camera:WorldToScreenPoint(worldPos)
	return pos, onScreen
end

local function createClickTarget()
	removeClickTarget()

	-- Part 3D invisible attaché devant le joueur à 10 studs
	local part = Instance.new("Part")
	part.Name = "AutoClickWorldTarget"
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Transparency = 0.6
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	part.Color = Color3.fromRGB(255, 50, 50)
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Ball
	part.Parent = Workspace
	autoClickState.worldTarget = part

	-- Placement initial : au sol devant toi (raycast), pas dans les airs
	local function getGroundPosInFront(distance)
		local cam = Workspace.CurrentCamera
		local start = cam.CFrame.Position
		local dir = cam.CFrame.LookVector
		local goal = start + dir * distance
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = {LocalPlayer.Character, part}
		local result = Workspace:Raycast(goal + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), params)
		if result then
			return result.Position + Vector3.new(0, 0.2, 0)
		else
			return goal
		end
	end
	part.CFrame = CFrame.new(getGroundPosInFront(10))

	-- Cercle visible via BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AutoClickIndicator"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 28, 0, 28)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Adornee = part
	billboard.Parent = part

	local h = Instance.new("Frame")
	h.Size = UDim2.new(0, 14, 0, 2)
	h.Position = UDim2.new(0.5, -7, 0.5, -1)
	h.BackgroundColor3 = Color3.new(1, 1, 1)
	h.BorderSizePixel = 0
	h.Parent = billboard

	local v = Instance.new("Frame")
	v.Size = UDim2.new(0, 2, 0, 14)
	v.Position = UDim2.new(0.5, -1, 0.5, -7)
	v.BackgroundColor3 = Color3.new(1, 1, 1)
	v.BorderSizePixel = 0
	v.Parent = billboard

	autoClickState.clickTarget = billboard

	-- Bouger la cible 3D avec la souris (clic maintenu)
	local draggingWorld = false
	local dragWorldStart = nil
	local startWorldPos = nil

	local downConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local screenPos = UserInputService:GetMouseLocation()
			local ap = billboard.AbsolutePosition
			local as = billboard.AbsoluteSize
			local inside = screenPos.X >= ap.X and screenPos.X <= ap.X + as.X and screenPos.Y >= ap.Y and screenPos.Y <= ap.Y + as.Y
			if inside then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
					removeClickTarget()
					placeBtn.Text = "Placer cible"
					placeBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
					setAutoClickSave()
					_updateBtnState()
				else
					draggingWorld = true
					dragWorldStart = input.Position
					startWorldPos = part.Position
				end
			end
		end
	end)

	local changeConn = UserInputService.InputChanged:Connect(function(input)
		if not draggingWorld then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local screenNow = UserInputService:GetMouseLocation()
		local ray = Camera:ScreenPointToRay(screenNow.X, screenNow.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = {LocalPlayer.Character, part}
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if result then
			part.CFrame = CFrame.new(result.Position + result.Normal * 0.3)
		end
		setAutoClickSave()
	end)

	local upConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingWorld = false
		end
	end)

	table.insert(autoClickState.worldConnections, downConn)
	table.insert(autoClickState.worldConnections, changeConn)
	table.insert(autoClickState.worldConnections, upConn)

	placeBtn.Text = "Cible placee"
	placeBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	setAutoClickSave()
	_updateBtnState()
	return billboard
end

--- UI ---
local autoClickContainer = Instance.new("Frame")
autoClickContainer.Size = UDim2.new(1, -16, 0, 166)
autoClickContainer.Position = UDim2.new(0, 8, 0, 460)
autoClickContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
autoClickContainer.BorderSizePixel = 0
autoClickContainer.Parent = localPage
createCorner(autoClickContainer, 10)
createStroke(autoClickContainer, Color3.fromRGB(45, 45, 55), 1)

local acTitle = Instance.new("TextLabel")
acTitle.Size = UDim2.new(1, -10, 0, 18)
acTitle.Position = UDim2.new(0, 8, 0, 4)
acTitle.BackgroundTransparency = 1
acTitle.Text = "Auto Clicker"
acTitle.Font = Enum.Font.GothamBold
acTitle.TextSize = 13
acTitle.TextColor3 = Color3.fromRGB(210, 210, 210)
acTitle.TextXAlignment = Enum.TextXAlignment.Left
acTitle.Parent = autoClickContainer

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -16, 0, 26)
infoLabel.Position = UDim2.new(0, 8, 0, 20)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Placer cible = drag l'indicateur. Clic sur indicateur = supprimer. Start = autoclick."
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 9
infoLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
infoLabel.TextWrapped = true
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = autoClickContainer

--- Place
placeBtn = Instance.new("TextButton")
placeBtn.Size = UDim2.new(1, -16, 0, 30)
placeBtn.Position = UDim2.new(0, 8, 0, 50)
placeBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
placeBtn.Text = "Placer cible"
placeBtn.Font = Enum.Font.GothamBold
placeBtn.TextSize = 12
placeBtn.TextColor3 = Color3.new(1, 1, 1)
placeBtn.BorderSizePixel = 0
placeBtn.AutoButtonColor = false
placeBtn.Parent = autoClickContainer
createCorner(placeBtn, 8)
placeBtn.MouseButton1Click:Connect(function()
	if autoClickState.clickTarget then
		removeClickTarget()
		placeBtn.Text = "Placer cible"
		placeBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
		setAutoClickSave()
	else
		createClickTarget()
	end
end)

--- Start / Stop
startStopBtn = Instance.new("TextButton")
startStopBtn.Size = UDim2.new(1, -16, 0, 30)
startStopBtn.Position = UDim2.new(0, 8, 0, 84)
startStopBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
startStopBtn.Text = "Start"
startStopBtn.Font = Enum.Font.GothamBold
startStopBtn.TextSize = 12
startStopBtn.TextColor3 = Color3.new(1, 1, 1)
startStopBtn.BorderSizePixel = 0
startStopBtn.AutoButtonColor = false
startStopBtn.Parent = autoClickContainer
createCorner(startStopBtn, 8)

local function _updateBtnState()
	if autoClickState.clickTarget then
		placeBtn.Text = "Cible placee"
		placeBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	else
		placeBtn.Text = "Placer cible"
		placeBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
	end
	if autoClickState.active then
		startStopBtn.Text = "Stop"
		startStopBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	else
		startStopBtn.Text = "Start"
		startStopBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	end
end

startStopBtn.MouseButton1Click:Connect(function()
	if autoClickState.active then
		stopAutoClickEngine()
	else
		startAutoClickEngine()
	end
	_updateBtnState()
end)

--- Mode
local modeFrame = Instance.new("Frame")
modeFrame.Size = UDim2.new(1, -16, 0, 24)
modeFrame.Position = UDim2.new(0, 8, 0, 118)
modeFrame.BackgroundTransparency = 1
modeFrame.Parent = autoClickContainer

local modes = {auto = "Auto", rapid = "Rapid"}
local modeOrder = {"auto", "rapid"}
local modeBtns = {}
for i, m in ipairs(modeOrder) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.48, -3, 1, 0)
	btn.Position = UDim2.new((i - 1) * 0.52, 0, 0, 0)
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
		autoClickState.mode = m
		for _, b in pairs(modeBtns) do tween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		tween(btn, {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
		if autoClickState.active then startAutoClickEngine() end
		setAutoClickSave()
	end)
end
tween(modeBtns["auto"], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0)

--- Speed
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -10, 0, 14)
speedLabel.Position = UDim2.new(0, 8, 0, 145)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Vitesse : 0.05s"
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 10
speedLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = autoClickContainer

--- Restore
if panelMemory.autoClick and panelMemory.autoClick.speed then
	autoClickState.speed = panelMemory.autoClick.speed
	speedLabel.Text = "Vitesse : " .. autoClickState.speed .. "s"
end
if panelMemory.autoClick and panelMemory.autoClick.mode and modes[panelMemory.autoClick.mode] then
	autoClickState.mode = panelMemory.autoClick.mode
	for _, b in pairs(modeBtns) do tween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0) end
	tween(modeBtns[autoClickState.mode], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0)
end
if panelMemory.autoClick and panelMemory.autoClick.targetWorldPos then
	local p = panelMemory.autoClick.targetWorldPos
	createClickTarget()
	if autoClickState.worldTarget then
		autoClickState.worldTarget.Position = Vector3.new(p[1], p[2], p[3])
		setAutoClickSave()
	end
end

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
				platformState.part.Size = Vector3.new(200, 1, 200)
				platformState.part.Parent = Workspace
			end
			updateCharacter()
			local target = (humanoid and humanoid.SeatPart) or rootPart
			if target then
				local cf, size = character:GetBoundingBox()
				platformState.y = cf.Position.Y - size.Y / 2
				platformState.offset = 0
				platformState.part.CFrame = CFrame.new(target.Position.X, platformState.y - 0.5, target.Position.Z)
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
		updateCharacter()
		local target = (humanoid and humanoid.SeatPart) or rootPart
		if target then
			if UserInputService:IsKeyDown(Enum.KeyCode.Equals) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadPlus) then
				platformState.offset += 25 * dt
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Minus) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadMinus) then
				platformState.offset -= 25 * dt
			end
			platformState.part.CFrame = CFrame.new(target.Position.X, platformState.y + platformState.offset - 0.5, target.Position.Z)
		end
	end
	if humanoid and math.abs(humanoid.WalkSpeed - walkSpeedState.value) > 1 and not flyState.flying then
		humanoid.WalkSpeed = walkSpeedState.value
	end
	if humanoid and math.abs(humanoid.JumpPower - jumpPowerState.value) > 1 and not flyState.flying then
		humanoid.JumpPower = jumpPowerState.value
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
	antiKill = true,
	antiAFK = true,
	antiAFKLastAction = tick(),
	antiKillSavedCFrame = nil,
	lastSafeCFrame = nil,
	lastHrpPosition = nil,
}

local function savePreDeathPosition()
	if not protectionsState.antiKill then return end
	updateCharacter()
	if rootPart then
		protectionsState.antiKillSavedCFrame = rootPart.CFrame
	end
end

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
	end
end) -- antiKill CharacterAdded

local function neutralizeSeat(seat)
	if not seat then return end
	if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
		seat.Disabled = true
		seat.CanTouch = false
		seat:SetAttribute("Neutralized", true)
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
		-- auto-cleanup si nouveau personnage
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

	-- Anti Fling : vitesse verticale extrême
	if protectionsState.antiFling then
		if math.abs(vel.Y) > 500 then
			rootPart.AssemblyLinearVelocity = Vector3.new(vel.X * 0.1, 0, vel.Z * 0.1)
		end
	end

	-- Anti Seat
	if protectionsState.antiSeat then
		if humanoid.Sit then
			humanoid.Sit = false
		end
		local seat = humanoid.SeatPart
		if seat then
			humanoid.Sit = false
		end
	end

	-- Anti Teleport
	if protectionsState.antiTeleport and not flyState.flying and not noclipState.enabled then
		local last = protectionsState.lastHrpPosition
		if last then
			local dist = (pos - last).Magnitude
			if dist > 200 then
				rootPart.CFrame = protectionsState.lastSafeCFrame or CFrame.new(last)
				rootPart.AssemblyLinearVelocity = Vector3.zero
			else
				protectionsState.lastSafeCFrame = rootPart.CFrame
				protectionsState.lastHrpPosition = pos
			end
		else
			protectionsState.lastSafeCFrame = rootPart.CFrame
			protectionsState.lastHrpPosition = pos
		end
	end

	-- Anti Fall : sous la map ou chute très rapide
	if protectionsState.antiFall then
		if vel.Y < -100 and pos.Y < -500 then
			rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
			if protectionsState.lastSafeCFrame then
				rootPart.CFrame = protectionsState.lastSafeCFrame
			end
		end
	end
end)

-- Anti AFK : petit mouvement toutes les 5 minutes pour éviter le kick
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

-- ============= EXTRA =============
local fullbrightState = { enabled = false, old = {} }
local clickTPState = { enabled = false }
local hitboxState = { enabled = false }

local fullbrightSwitch = createSwitch(extraPage, "Fullbright", 10, function(on)
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

createSwitch(extraPage, "Click TP (Ctrl+clic)", 52, function(on)
	clickTPState.enabled = on
end)

createSwitch(extraPage, "Hitbox expander", 94, function(on)
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

createButton(extraPage, "Obtenir Ghost V4", 140, Color3.fromRGB(110, 60, 160), function()
	giveGhostTool()
end)
createButton(extraPage, "Obtenir Eleven Master", 182, Color3.fromRGB(60, 120, 160), function()
	giveElevenTool()
end)
createButton(extraPage, "Obtenir Spider Tool", 224, Color3.fromRGB(60, 160, 90), function()
	giveSpiderTool()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and clickTPState.enabled then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			updateCharacter()
			if Mouse.Hit and rootPart then
				rootPart.CFrame = Mouse.Hit + Vector3.new(0, 3, 0)
			end
		end
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

Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
	if fullbrightState.enabled then
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	end
end)

-- ============= SERVEUR =============
local serverScroll = Instance.new("ScrollingFrame")
serverScroll.Size = UDim2.new(1, -10, 1, -10)
serverScroll.Position = UDim2.new(0, 5, 0, 5)
serverScroll.BackgroundTransparency = 1
serverScroll.ScrollBarThickness = 4
serverScroll.Parent = serverPage

local serverLayout = Instance.new("UIListLayout")
serverLayout.Padding = UDim.new(0, 6)
serverLayout.SortOrder = Enum.SortOrder.LayoutOrder
serverLayout.Parent = serverScroll

local function addServerStat(name)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 42)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	card.BorderSizePixel = 0
	card.Parent = serverScroll
	createCorner(card, 8)
	createStroke(card, Color3.fromRGB(45, 45, 55), 1)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 0, 18)
	label.Position = UDim2.new(0, 8, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = name
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(180, 180, 180)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -12, 0, 16)
	value.Position = UDim2.new(0, 8, 0, 22)
	value.BackgroundTransparency = 1
	value.Text = "..."
	value.Font = Enum.Font.Gotham
	value.TextSize = 12
	value.TextColor3 = Color3.fromRGB(230, 230, 230)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = card
	return value
end

local statPlayers = addServerStat("Joueurs en ligne")
local statFPS = addServerStat("FPS")
local statPing = addServerStat("Ping moyen")
local statTime = addServerStat("Heure serveur")
local statJobId = addServerStat("Job ID")
local statPlaceId = addServerStat("Place ID")
local statCreator = addServerStat("Créateur")

serverScroll.CanvasSize = UDim2.new(0, 0, 0, serverLayout.AbsoluteContentSize.Y + 10)
serverLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	serverScroll.CanvasSize = UDim2.new(0, 0, 0, serverLayout.AbsoluteContentSize.Y + 10)
end)

local fps = 60
local lastFrame = tick()
RunService.RenderStepped:Connect(function()
	local now = tick()
	local dt = now - lastFrame
	lastFrame = now
	fps = math.clamp(1 / dt, 1, 240)
end)

task.spawn(function()
	while task.wait(1) do
		statPlayers.Text = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers)
		statFPS.Text = tostring(math.floor(fps))
		local ping = LocalPlayer:GetNetworkPing() * 1000
		statPing.Text = string.format("%.0f ms", ping)
		statTime.Text = os.date("%H:%M:%S")
		local ok, jobId = pcall(function() return game.JobId end)
		statJobId.Text = (ok and jobId and jobId ~= "") and jobId:sub(1, 20) .. "..." or "N/A"
		local ok2, placeId = pcall(function() return game.PlaceId end)
		statPlaceId.Text = ok2 and tostring(placeId) or "N/A"
		local ok3, creator = pcall(function() return game.CreatorId end)
		statCreator.Text = ok3 and tostring(creator) or "N/A"
	end
end)

-- ============= OUTILS =============
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
LocalPlayer.Chatted:Connect(function(msg)
	local m = msg:lower()
	if m == ";fly" then flySwitch.set(true)
	elseif m == ";unfly" then flySwitch.set(false)
	elseif m == ";noclip" then noclipSwitch.set(true)
	elseif m == ";unnoclip" then noclipSwitch.set(false)
	elseif m == ";esp" then espState.enabled = true refreshESP()
	elseif m == ";unesp" then espState.enabled = false clearESP()
	elseif m == ";fullbright" then fullbrightSwitch.set(true)
	elseif m == ";unfullbright" then fullbrightSwitch.set(false)
	elseif m == ";zerog" then zeroGSwitch.set(true)
	elseif m == ";unzerog" then zeroGSwitch.set(false)
	end
end)

-- ============= CRÉDITS =============
local credits = Instance.new("TextLabel")
credits.Size = UDim2.new(1, 0, 0, 18)
credits.Position = UDim2.new(0, 0, 1, -20)
credits.BackgroundTransparency = 1
credits.Text = "Panel by Milan & Emerick"
credits.Font = Enum.Font.GothamBold
credits.TextSize = 11
credits.TextColor3 = Color3.fromRGB(140, 140, 180)
credits.Parent = mainFrame

bootSequence(function()
	switchTab("Joueurs")
end)