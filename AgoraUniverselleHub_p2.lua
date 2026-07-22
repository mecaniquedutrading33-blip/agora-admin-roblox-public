-- BRIDGE: restore Part 1 locals
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

-- RESTORE UTILITY FUNCTIONS FROM _G (loadstring sandbox doesn't share globals)
local createCorner = _G.createCorner
local createStroke = _G.createStroke
local createButton = _G.createButton
local createSwitch = _G.createSwitch
local createSlider = _G.createSlider
local switchTab = _G.switchTab
local updateLoad = _G.updateLoad
local tween = _G.tween
local shutdownPanel = _G.shutdownPanel
local startFly = _G.startFly
local stopFly = _G.stopFly
local updateCharacter = _G.updateCharacter
local refreshESP = _G.refreshESP
local clearESP = _G.clearESP
local computePathTo = _G.computePathTo
local visualizeWaypoints = _G.visualizeWaypoints
local clearWalkVisuals = _G.clearWalkVisuals
local reparentChildrenToLocalScroll = _G.reparentChildrenToLocalScroll
local httpGet = _G.httpGet
local joinOrIndi = _G.joinOrIndi or function(list, sep, max)
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
_G.setAutoClickSave = setAutoClickSave
end

local function removeFakeTool()
	if autoClickState.fakeTool and autoClickState.fakeTool.Parent then
		autoClickState.fakeTool:Destroy()
	end
_G.removeFakeTool = removeFakeTool
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
_G.createFakeTool = createFakeTool

local function stopAutoClickEngine()
	autoClickState.clickEnabled = false
	if autoClickState.activeThread then
		autoClickState.activeThread = nil
	end
_G.stopAutoClickEngine = stopAutoClickEngine
	destroyAutoClickMarker()
	statusLabel.Text = "Statut : arret"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	pcall(hideMarker)
end

local function onToolDeactivated()
	-- quand le tool est retiré de l'inventaire / personnage mort
	stopAutoClickEngine()
end
_G.onToolDeactivated = onToolDeactivated

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
_=(function()
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
_G.captureTargetFromCursor = captureTargetFromCursor

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
_G.findGuiButtonAt = findGuiButtonAt
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
_G.findClickDetectorAtScreen = findClickDetectorAtScreen
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
_G.fireClickFixed = fireClickFixed
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
_G.startAutoClickEngine = startAutoClickEngine
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
_G.showMarkerAt = showMarkerAt
local function hideMarker()
	acMarker.Visible = false
end
_G.hideMarker = hideMarker

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
_G.speedFromX = speedFromX
local function setSpeed(s)
	s = math.clamp(math.floor(s * 1000) / 1000, 0.001, 0.2)
	autoClickState.speed = s
	speedLabel.Text = "Vitesse : " .. s .. "s"
	speedFill.Size = UDim2.new((s - 0.001) / 0.199, 0, 1, 0)
	if autoClickState.clickEnabled then startAutoClickEngine() end
	setAutoClickSave()
end
_G.setSpeed = setSpeed
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
_G.clampControl = clampControl

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
				if not capturedY and seatPart then
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
	local char = LocalPlayer.Character
	if noclipState.enabled and char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CanCollide = false end
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
		local myPos = rootPart.Position
		local flatDist = Vector3.new(myPos.X - wp.X, 0, myPos.Z - wp.Z).Magnitude
		
		-- === DETECTION DIMENSIONS PERSONNAGE ===
		local charWidth = 2 -- largeur approximative du personnage (HumanoidRootPart size)
		local charHeight = 5 -- hauteur approximative (tete + torse + jambes)
		local crawlMode = false
		
		-- Raycast box pour verifier si on passe en hauteur
		local function checkPassage(pos, height, width)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {character}
			params.FilterType = Enum.RaycastFilterType.Exclude
			-- Check hauteur: raycast du sol vers le haut
			local topHit = Workspace:Raycast(pos, Vector3.new(0, height, 0), params)
			if topHit then
				local clearance = (topHit.Position - pos).Y
				if clearance < charHeight then
					-- Trop bas pour marcher, verifie si on peut ramper
					if clearance >= 1.5 then
						crawlMode = true
						return "crawl"
					else
						return "blocked"
					end
				end
			end
			-- Check largeur: raycast a gauche et droite
			local leftHit = Workspace:Raycast(pos, Vector3.new(-width/2, 0, 0), params)
			local rightHit = Workspace:Raycast(pos, Vector3.new(width/2, 0, 0), params)
			if leftHit or rightHit then
				return "tight"
			end
			return "clear"
		end
		
		-- Verifie le passage au prochain waypoint
		local passage = checkPassage(wp, charHeight, charWidth)
		if passage == "crawl" then
			-- Coucher le personnage (ramper)
			pcall(function()
				humanoid.HipHeight = 0
				local root = rootPart
				if root then
					root.Size = Vector3.new(2, 1, 1)
				end
			end)
		elseif passage == "clear" then
			-- Restaurer la posture normale
			pcall(function()
				humanoid.HipHeight = 2
				local root = rootPart
				if root then
					root.Size = Vector3.new(2, 5, 1)
				end
			end)
		end
		
		-- === SAUT INTELLIGENT ===
		-- Verifie si le prochain waypoint est plus haut que la position actuelle
		local heightDiff = wp.Y - myPos.Y
		if heightDiff > 2.5 and flatDist < 8 then
			-- Le waypoint est plus haut et proche -> sauter
			pcall(function()
				humanoid.Jump = true
			end)
		end
		-- Verifie aussi s'il y a un obstacle devant qui necessite un saut
		local frontParams = RaycastParams.new()
		frontParams.FilterDescendantsInstances = {character}
		frontParams.FilterType = Enum.RaycastFilterType.Exclude
		local frontRay = Workspace:Raycast(myPos, rootPart.CFrame.LookVector * 4, frontParams)
		if frontRay and heightDiff > 0 then
			-- Obstacle devant et on doit monter -> sauter
			pcall(function()
				humanoid.Jump = true
			end)
		end
		
		-- === DETECTION DE BLOCAGE ===
		local vel = rootPart.AssemblyLinearVelocity
		local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		if flatDist > 3 and flatSpeed < 1 then
			if gotoWalkState.stuckSince == nil then gotoWalkState.stuckSince = tick() end
			if tick() - gotoWalkState.stuckSince > 0.5 then
				-- Sauter pour franchir l'obstacle
				pcall(function() humanoid.Jump = true end)
				-- Si toujours bloque apres 2s, recalcule
				if tick() - gotoWalkState.stuckSince > 2 and gotoWalkState.target then
					gotoWalkState.stuckSince = nil
					local newPath = computePathTo(gotoWalkState.target)
					if not newPath or #newPath == 0 then
						local offsets = {Vector3.new(4,0,0), Vector3.new(-4,0,0), Vector3.new(0,0,4), Vector3.new(0,0,-4), Vector3.new(4,0,4), Vector3.new(-4,0,-4)}
						for _, off in ipairs(offsets) do
							newPath = computePathTo(gotoWalkState.target + off)
							if newPath and #newPath > 0 then break end
						end
					end
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
				clearWalkVisuals()
			else
				humanoid:MoveTo(gotoWalkState.path[1])
				gotoWalkState.lastMoveTo = tick()
			end
		else
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


updateLoad(0.50, "Modules extra...")
task.wait(0.05)
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
_G._initServerStatsCard = _initServerStatsCard

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
_G._initServerInfoCard = _initServerInfoCard
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

updateLoad(0.60, "Aimbot...")
task.wait(0.05)
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
	_G._agoraAimbotEnabled = false
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
	mainSwitchLabel.ZIndex = 4
	local mainSwitch = createSwitch(mainSwitchRow, "", 0, function(on)
		aimbotEnabled = on
		_G._agoraAimbotEnabled = on
	end)
	mainSwitch.Size = UDim2.new(0.3, -4, 0.85, 0)
	mainSwitch.Position = UDim2.new(0.7, 4, 0.075, 0)
	mainSwitch.set(_G._agoraAimbotEnabled)

	-- Toggle auto-clic
	_G._agoraAimbotAutoClick = _G._agoraAimbotAutoClick or false
	local clickSwitch = createSwitch(clickSwitchRow, "", 0, function(on)
		aimbotAutoClick = on
		_G._agoraAimbotAutoClick = on
	end)
	clickSwitch.Size = UDim2.new(0.3, -4, 0.85, 0)
	clickSwitch.Position = UDim2.new(0.7, 4, 0.075, 0)
	clickSwitch.set(_G._agoraAimbotAutoClick)

	-- Slider de distance max (clic gauche = -25, clic droit = +25)
	_G._agoraAimbotMaxDist = _G._agoraAimbotMaxDist or 300
	local aimbotMaxDist = _G._agoraAimbotMaxDist or 300
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
		_G._agoraAimbotMaxDist = aimbotMaxDist
		distLabel.Text = "📏 Distance max : " .. aimbotMaxDist .. " studs"
	end)
	distSlider.MouseButton2Click:Connect(function()
		aimbotMaxDist = math.min(1000, aimbotMaxDist + 25)
		_G._agoraAimbotMaxDist = aimbotMaxDist
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
		if not _G._agoraAimbotEnabled then
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
				if (targetPos - myPos).Magnitude <= (_G._agoraAimbotMaxDist or 300) then
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
_G._initAimbot = _initAimbot
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
			if _G._agoraAimbotAutoClick and tick() - lastClickTick > 0.1 then
				pcall(function() mouse1click() end)
				lastClickTick = tick()
			end
		else
			if aimCircle.Visible then aimCircle.Visible = false end
			aimStatusLabel.Text = "Aucune cible visible (hors portée ou derrière un mur)"
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
		warn("[MilanEmerickPanel] " .. tostring(msg))
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
-- === SERVER AUTHORITY DETECTION + DISABLE ===
_=(function()
	-- Frame container
	local saCard = Instance.new("Frame")
	saCard.Name = "ServerAuthorityCard"
	saCard.Size = UDim2.new(1, -10, 0, 0)
	saCard.AutomaticSize = Enum.AutomaticSize.Y
	saCard.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	saCard.BorderSizePixel = 0
	saCard.LayoutOrder = 999
	saCard.Parent = extraScroll
	createCorner(saCard, 8)
	createStroke(saCard, Color3.fromRGB(80, 80, 120), 1)

	local saPad = Instance.new("UIPadding")
	saPad.PaddingTop = UDim.new(0, 8)
	saPad.PaddingBottom = UDim.new(0, 8)
	saPad.PaddingLeft = UDim.new(0, 12)
	saPad.PaddingRight = UDim.new(0, 12)
	saPad.Parent = saCard

	-- Title
	local saTitle = Instance.new("TextLabel")
	saTitle.Size = UDim2.new(1, 0, 0, 16)
	saTitle.BackgroundTransparency = 1
	saTitle.Text = "Server Authority"
	saTitle.Font = Enum.Font.GothamBold
	saTitle.TextSize = 12
	saTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
	saTitle.TextXAlignment = Enum.TextXAlignment.Left
	saTitle.Parent = saCard

	-- Status label
	local saStatus = Instance.new("TextLabel")
	saStatus.Size = UDim2.new(1, 0, 0, 14)
	saStatus.Position = UDim2.new(0, 0, 0, 18)
	saStatus.BackgroundTransparency = 1
	saStatus.Text = "Detection..."
	saStatus.Font = Enum.Font.GothamSemibold
	saStatus.TextSize = 11
	saStatus.TextColor3 = Color3.fromRGB(150, 150, 160)
	saStatus.TextXAlignment = Enum.TextXAlignment.Left
	saStatus.Parent = saCard

	-- Detect Server Authority
	local saActive = false
	local saMode = "Inconnu"
	pcall(function()
		local ws = game:GetService("Workspace")
		if ws:FindFirstChild("AuthorityMode") or ws:IsA("Instance") then
			local am = ws.AuthorityMode
			if am == Enum.AuthorityMode.Server then
				saActive = true
				saMode = "ACTIF"
			elseif am == Enum.AuthorityMode.Client then
				saActive = false
				saMode = "Desactive"
			else
				saMode = tostring(am)
			end
		else
			-- AuthorityMode property might not exist (old games)
			local ok2 = pcall(function()
				local am = ws:GetAttribute("AuthorityMode")
				if am then
					saMode = tostring(am)
					saActive = (am == "Server" or am == 1)
				end
			end)
			if not ok2 then
				saMode = "Non supporte"
			end
		end
	end)

	-- Update status display
	if saActive then
		saStatus.Text = "Status: ACTIF (fly bypass disponible!)"
		saStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
	else
		saStatus.Text = "Status: " .. saMode .. " (fly/noclip OK)"
		saStatus.TextColor3 = Color3.fromRGB(100, 220, 120)
	end

	-- Info label (visible only if SA active)
	local saInfo = Instance.new("TextLabel")
	saInfo.Size = UDim2.new(1, 0, 0, 14)
	saInfo.Position = UDim2.new(0, 0, 0, 36)
	saInfo.BackgroundTransparency = 1
	saInfo.Text = "Tenter de desactiver localement:"
	saInfo.Font = Enum.Font.Gotham
	saInfo.TextSize = 10
	saInfo.TextColor3 = Color3.fromRGB(160, 160, 170)
	saInfo.TextXAlignment = Enum.TextXAlignment.Left
	saInfo.Visible = saActive
	saInfo.Parent = saCard

	-- Disable button (visible only if SA active)
	local saBtn = Instance.new("TextButton")
	saBtn.Size = UDim2.new(1, 0, 0, 30)
	saBtn.Position = UDim2.new(0, 0, 0, 54)
	saBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	saBtn.Text = "Tenter de desactiver"
	saBtn.Font = Enum.Font.GothamSemibold
	saBtn.TextSize = 12
	saBtn.TextColor3 = Color3.new(1, 1, 1)
	saBtn.BorderSizePixel = 0
	saBtn.AutoButtonColor = false
	saBtn.Visible = saActive
	saBtn.Parent = saCard
	createCorner(saBtn, 8)

	saBtn.MouseButton1Click:Connect(function()
		pcall(function()
			local ws = game:GetService("Workspace")
			-- Try setting AuthorityMode to Client
			pcall(function()
				ws.AuthorityMode = Enum.AuthorityMode.Client
			end)
			-- Try removing other SA properties
			pcall(function()
				if ws.NextGenerationReplication then ws.NextGenerationReplication = false end
			end)
			pcall(function()
				if ws.PlayerScriptsUseInputActionSystem then ws.PlayerScriptsUseInputActionSystem = false end
			end)
			pcall(function()
				if ws.UseFixedSimulation then ws.UseFixedSimulation = false end
			end)
		end)
		-- Re-check
		local stillActive = false
		pcall(function()
			local ws = game:GetService("Workspace")
			if ws.AuthorityMode == Enum.AuthorityMode.Server then
				stillActive = true
			end
		end)
		if stillActive then
			saStatus.Text = "Status: ACTIF (desactivation echouee)"
			saStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
			saBtn.Text = "Reessayer"
		else
			saStatus.Text = "Status: Desactive localement"
			saStatus.TextColor3 = Color3.fromRGB(100, 220, 120)
			saBtn.Text = "Reactiver"
			saBtn.BackgroundColor3 = Color3.fromRGB(100, 180, 100)
		end
	end)
end)()
-- === EMOTES SYSTEM (deplace de Home vers Extra, animations custom) ===
_=(function()
	local screenGui = _G._P1.screenGui or _G._P1.loadingGui
	local LocalPlayer = _G._P1.LocalPlayer
	local UserInputService = _G._P1.UserInputService
	local RunService = _G._P1.RunService
	local playSound = _G.playSound or function() end
	local tween = _G.tween or function() end

	-- Helper: UICorner direct (pas de reliance sur createCorner)
	local function corner(obj, r)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, r or 6)
		c.Parent = obj
		return c
	end
	local function stroke(obj, color, thick)
		local s = Instance.new("UIStroke")
		s.Color = color or Color3.fromRGB(80, 80, 100)
		s.Thickness = thick or 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = obj
		return s
	end

	-- Bouton Emotes dans Extra
	local emoteBtn = Instance.new("TextButton")
	emoteBtn.Size = UDim2.new(1, -10, 0, 32)
	emoteBtn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
	emoteBtn.Text = "🎭 Emotes"
	emoteBtn.Font = Enum.Font.GothamSemibold
	emoteBtn.TextSize = 13
	emoteBtn.TextColor3 = Color3.fromRGB(220, 180, 255)
	emoteBtn.BorderSizePixel = 0
	emoteBtn.AutoButtonColor = true
	emoteBtn.LayoutOrder = 500
	emoteBtn.Parent = extraScroll
	corner(emoteBtn, 8)
	stroke(emoteBtn, Color3.fromRGB(80, 60, 120), 1)

	-- Fenetre draggable
	local emoteWin = Instance.new("Frame")
	emoteWin.Size = UDim2.new(0, 260, 0, 460)
	emoteWin.Position = UDim2.new(0.5, -130, 0.15, 0)
	emoteWin.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	emoteWin.BorderSizePixel = 0
	emoteWin.Visible = false
	emoteWin.ZIndex = 300
	emoteWin.Parent = screenGui
	corner(emoteWin, 10)
	stroke(emoteWin, Color3.fromRGB(100, 80, 140), 1.5)

	-- Barre de titre (draggable) + stop emote always visible
	local emoteTitleBar = Instance.new("Frame")
	emoteTitleBar.Size = UDim2.new(1, 0, 0, 36)
	emoteTitleBar.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
	emoteTitleBar.BorderSizePixel = 0
	emoteTitleBar.ZIndex = 301
	emoteTitleBar.Parent = emoteWin
	corner(emoteTitleBar, 10)

	local emoteTitle = Instance.new("TextLabel")
	emoteTitle.Size = UDim2.new(0, 80, 1, 0)
	emoteTitle.Position = UDim2.new(0, 8, 0, 0)
	emoteTitle.BackgroundTransparency = 1
	emoteTitle.Text = "🎭 Emotes"
	emoteTitle.Font = Enum.Font.GothamBold
	emoteTitle.TextSize = 14
	emoteTitle.TextColor3 = Color3.fromRGB(200, 170, 255)
	emoteTitle.TextXAlignment = Enum.TextXAlignment.Left
	emoteTitle.ZIndex = 302
	emoteTitle.Parent = emoteTitleBar

	-- Bouton STOP toujours visible (dans la title bar)
	local stopBtn = Instance.new("TextButton")
	stopBtn.Size = UDim2.new(0, 80, 0, 28)
	stopBtn.Position = UDim2.new(1, -120, 0, 4)
	stopBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	stopBtn.Text = "⏹ Stop"
	stopBtn.Font = Enum.Font.GothamBold
	stopBtn.TextSize = 13
	stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	stopBtn.BorderSizePixel = 0
	stopBtn.ZIndex = 302
	stopBtn.Parent = emoteTitleBar
	corner(stopBtn, 6)

	-- Bouton X CIRCULAIRE (UICorner direct, radius = moitie de la taille = cercle parfait)
	local emoteClose = Instance.new("TextButton")
	emoteClose.Size = UDim2.new(0, 28, 0, 28)
	emoteClose.Position = UDim2.new(1, -34, 0, 4)
	emoteClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	emoteClose.Text = "✕"
	emoteClose.Font = Enum.Font.GothamBold
	emoteClose.TextSize = 14
	emoteClose.TextColor3 = Color3.new(1, 1, 1)
	emoteClose.BorderSizePixel = 0
	emoteClose.ZIndex = 302
	emoteClose.Parent = emoteTitleBar
	-- CIRCULAIRE: UICorner radius 12 = moitie de 24px = cercle
	corner(emoteClose, 14)

	-- Scroll des emotes
	local emoteScroll = Instance.new("ScrollingFrame")
	emoteScroll.Size = UDim2.new(1, -10, 1, -44)
	emoteScroll.Position = UDim2.new(0, 5, 0, 38)
	emoteScroll.BackgroundTransparency = 1
	emoteScroll.BorderSizePixel = 0
	emoteScroll.ScrollBarThickness = 4
	emoteScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	emoteScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	emoteScroll.ZIndex = 301
	emoteScroll.Parent = emoteWin

	local emoteLayout = Instance.new("UIListLayout")
	emoteLayout.SortOrder = Enum.SortOrder.LayoutOrder
	emoteLayout.Padding = UDim.new(0, 3)
	emoteLayout.Parent = emoteScroll

	-- === SYSTEME D'ANIMATION ===
	local currentTrack = nil
	local currentAnim = nil
	local customLoop = nil  -- pour animations scriptees (CFrame)

	local function getChar()
		local char = LocalPlayer.Character
		if not char then return nil, nil end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
		return char, hum, root, torso
	end

	local function stopAll()
		pcall(function()
			if currentTrack then currentTrack:Stop(0.3) end
			if _G._currentEmoteTrack then _G._currentEmoteTrack:Stop(0.3) end
			currentTrack = nil
		end)
		if customLoop then
			customLoop:Disconnect()
			customLoop = nil
		end
		-- Reset character sans casser la rotation naturelle
		pcall(function()
			local char, hum, root = getChar()
			if hum then
				hum.JumpPower = 50
				hum.WalkSpeed = (_G._P1 and _G._P1.walkSpeedState and _G._P1.walkSpeedState.value) or 16
				hum.PlatformStand = false
			end
		end)
		if playSound then playSound(6042053626, 0.2) end
		-- Reset active button highlight
		if activeEmoteBtn then
			pcall(tween, activeEmoteBtn, {BackgroundColor3 = Color3.fromRGB(25, 25, 35)}, 0.2)
			activeEmoteBtn = nil
		end
	end

	-- Jouer une animation Roblox (par ID)
	local function playAnim(animId, isLoop)
		stopAll()
		local ok, err = pcall(function()
			local char, hum = getChar()
			if not hum then 
				if notify then notify("Pas de personnage", "Reviens a la vie d'abord!") end
				return 
			end
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = hum
			end
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. tostring(animId)
			local track = animator:LoadAnimation(anim)
			track.Looped = isLoop or false
			track:Play()
			currentTrack = track
			currentAnim = anim
			_G._currentEmoteTrack = track
			if not isLoop then
				task.delay(track.Length + 0.5, function()
					pcall(function() if track then track:Stop(0.3) end end)
				end)
			end
		end)
		if not ok and notify then
			notify("Emote erreur", "Animation invalide ou bloquee")
		end
		if playSound then playSound(6042053626, 0.2) end
	end

	-- === ANIMATIONS SCRIPTEES (CFrame, pas besoin d'IDs) ===
	-- Ces animations manipulent directement les CFrame des body parts
	-- Elles marchent PARTOUT (pas besoin de permission animation)

	local function startCustom(fn)
		stopAll()
		local char, hum, root, torso = getChar()
		if not root then 
			if notify then notify("Pas de personnage", "Reviens a la vie d'abord!") end
			return 
		end
		if playSound then playSound(6042053626, 0.2) end
		customLoop = RunService.RenderStepped:Connect(function(dt)
			-- Re-fetch character chaque frame pour survivre respawns
			local c, h, r, t = getChar()
			if r then
				pcall(fn, dt, c, h, r, t)
			end
		end)
	end

	-- 1. ROULADE DE BUCHE (log roll) - tourne sur le cote
	local function doLogRoll(dt, char, hum, root, torso)
		local t = tick()
		-- Tourne le personnage sur le cote (axe X)
		root.CFrame = root.CFrame * CFrame.Angles(dt * 6, 0, 0)
		-- Leve legerement pour ne pas clip dans le sol
		-- Ne pas override la velocity naturelle
		pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 5, 0) end)
	end

	-- 2. CRISE D'EPILEPSIE - tremblements rapides + rotation aleatoire
	local function doSeizure(dt, char, hum, root, torso)
		local t = tick()
		-- Tremblements rapides en position
		local shakeX = math.random(-100, 100) / 1000
		local shakeY = math.random(-100, 100) / 1000
		local shakeZ = math.random(-100, 100) / 1000
		root.CFrame = root.CFrame * CFrame.new(shakeX, shakeY, shakeZ)
		-- Rotation rapide aleatoire
		root.CFrame = root.CFrame * CFrame.Angles(math.random(-50, 50) / 100, math.random(-50, 50) / 100, math.random(-50, 50) / 100)
		-- Sauts aleatoires
		if math.random() < 0.3 then
			hum.Jump = true
		end
	end

	-- 3. SPIN FOU - tourne sur place rapidement
	local function doSpin(dt, char, hum, root, torso)
		root.CFrame = root.CFrame * CFrame.Angles(0, dt * 15, 0)
	end

	-- 4. BAGARRE INVISIBLE - coups de poing dans le vide
	local function doGhostFight(dt, char, hum, root, torso)
		local t = tick()
		local punchPhase = math.sin(t * 8)
		if punchPhase > 0.5 then
			-- Coup droit
			root.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(-20))
		elseif punchPhase < -0.5 then
			-- Coup gauche
			root.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(20))
		else
			root.CFrame = root.CFrame * CFrame.Angles(0, 0, 0)
		end
		-- Petit saut occasionnel
		if math.random() < 0.05 then
			hum.Jump = true
		end
	end

	-- 5. DANSE DU VERMISSEAU - le personnage rampe et ondule
	local function doWormDance(dt, char, hum, root, torso)
		local t = tick()
		-- Ondulation verticale
		local wave = math.sin(t * 6) * 3
		root.CFrame = root.CFrame * CFrame.new(0, wave, 0)
		-- Inclinaison avant/arriere
		root.CFrame = root.CFrame * CFrame.Angles(math.sin(t * 4) * 0.3, 0, 0)
		-- Lentement avance
		root.CFrame = root.CFrame * CFrame.new(0, 0, -dt * 2)
	end

	-- 6. HELICOPTERE - tourne les bras (rotation Y complete)
	local function doHelicopter(dt, char, hum, root, torso)
		root.CFrame = root.CFrame * CFrame.Angles(0, dt * 10, 0)
		-- Leve legerement
		pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 30, 0) end)
	end

	-- 7. NAGE A SEC - mouvement de nage sur terre
	local function doDrySwim(dt, char, hum, root, torso)
		local t = tick()
		-- Alternance bras gauche/droit
		local phase = math.sin(t * 5)
		root.CFrame = root.CFrame * CFrame.Angles(math.rad(15), 0, phase * 0.3)
		-- Avance lentement
		root.CFrame = root.CFrame * CFrame.new(0, 0, -dt * 1.5)
	end

	-- 8. TREMBLEMENT DE TERRE - sautillements rapides
	local function doEarthquake(dt, char, hum, root, torso)
		local t = tick()
		if math.sin(t * 12) > 0 then
			hum.Jump = true
		end
		root.CFrame = root.CFrame * CFrame.new(math.random(-50, 50) / 200, 0, math.random(-50, 50) / 200)
	end

	-- 9. MOONWALK - recule en moonwalk
	local function doMoonwalk(dt, char, hum, root, torso)
		local t = tick()
		-- Incline en arriere
		root.CFrame = root.CFrame * CFrame.Angles(math.rad(-10), 0, 0)
		-- Recule
		root.CFrame = root.CFrame * CFrame.new(0, 0, dt * 8)
		-- Petit bounce
		if math.sin(t * 8) > 0.7 then
			hum.Jump = true
		end
	end

	-- 10. POULE QUI COURT - petites strides rapides + tressautement
	local function doChickenRun(dt, char, hum, root, torso)
		local t = tick()
		-- Tressautement rapide
		root.CFrame = root.CFrame * CFrame.new(0, math.abs(math.sin(t * 15)) * 1.5, 0)
		-- Penche en avant
		root.CFrame = root.CFrame * CFrame.Angles(math.rad(20), 0, 0)
		-- Court vers l'avant
		root.CFrame = root.CFrame * CFrame.new(0, 0, -dt * 6)
	end

	stopBtn.MouseButton1Click:Connect(stopAll)

	-- Categories
	local function addCategory(text, order)
		local cat = Instance.new("TextLabel")
		cat.Size = UDim2.new(1, 0, 0, 20)
		cat.BackgroundTransparency = 1
		cat.Text = text
		cat.Font = Enum.Font.GothamBold
		cat.TextSize = 11
		cat.TextColor3 = Color3.fromRGB(150, 130, 200)
		cat.TextXAlignment = Enum.TextXAlignment.Left
		cat.LayoutOrder = order
		cat.ZIndex = 301
		cat.Parent = emoteScroll
	end

	local activeEmoteBtn = nil
	local function addEmote(label, fn, order)
		local eBtn = Instance.new("TextButton")
		eBtn.Size = UDim2.new(1, 0, 0, 28)
		eBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		eBtn.Text = label
		eBtn.Font = Enum.Font.Gotham
		eBtn.TextSize = 12
		eBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
		eBtn.BorderSizePixel = 0
		eBtn.LayoutOrder = order
		eBtn.ZIndex = 301
		eBtn.Parent = emoteScroll
		corner(eBtn, 6)
		local origColor = Color3.fromRGB(25, 25, 35)
		eBtn.MouseEnter:Connect(function() pcall(tween, eBtn, {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}, 0.12) end)
		eBtn.MouseLeave:Connect(function() pcall(tween, eBtn, {BackgroundColor3 = origColor}, 0.12) end)
		eBtn.MouseButton1Click:Connect(function()
			-- Reset previous active button
			if activeEmoteBtn and activeEmoteBtn ~= eBtn then
				pcall(tween, activeEmoteBtn, {BackgroundColor3 = Color3.fromRGB(25, 25, 35)}, 0.2)
				activeEmoteBtn = nil
			end
			-- Highlight this button
			pcall(tween, eBtn, {BackgroundColor3 = Color3.fromRGB(60, 40, 80)}, 0.15)
			activeEmoteBtn = eBtn
			fn()
		end)
	end

	-- === RESET CHARACTER (en cas de jambes figees) ===
	addCategory("🔧 RESET", 50)
	addEmote("🔄 Reset personnage", function()
		stopAll()
		task.wait(0.1)
		pcall(function()
			local char, hum, root = getChar()
			if hum then
				hum.PlatformStand = false
				hum.JumpPower = 50
				hum.WalkSpeed = (_G._P1 and _G._P1.walkSpeedState and _G._P1.walkSpeedState.value) or 16
				hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			if notify then notify("Reset", "Personnage reinitialise!") end
		end)
	end, 51)

	-- === ANIMATIONS SCRIPTEES (marchent partout, pas besoin d'IDs) ===
	addCategory("🤣 MOVEMENTS FUN (custom)", 100)
	addEmote("🪵 Roulade de buche", function() startCustom(doLogRoll) end, 101)
	addEmote("😵 Crise d'epilepsie", function() startCustom(doSeizure) end, 102)
	addEmote("🌀 Spin fou", function() startCustom(doSpin) end, 103)
	addEmote("👻 Bagarre invisible", function() startCustom(doGhostFight) end, 104)
	addEmote("🪱 Danse du vermisseau", function() startCustom(doWormDance) end, 105)
	addEmote("🚁 Helicoptere", function() startCustom(doHelicopter) end, 106)
	addEmote("🏊 Nage a sec", function() startCustom(doDrySwim) end, 107)
	addEmote("🌍 Tremblement de terre", function() startCustom(doEarthquake) end, 108)
	addEmote("🕺 Moonwalk", function() startCustom(doMoonwalk) end, 109)
	addEmote("🐔 Poule qui court", function() startCustom(doChickenRun) end, 110)

	-- === EMOTES CLASSIQUES (R15 built-in pack, toujours valides) ===
	addCategory("🙋 EMOTES CLASSIQUES", 200)
	addEmote("👋 Saluer", function() playAnim(507770239, false) end, 201)
	addEmote("👉 Pointer", function() playAnim(507770039, false) end, 202)
	addEmote("👀 Me regarder", function() playAnim(507770453, true) end, 203)
	addEmote("🎉 Acclamer", function() playAnim(507770677, true) end, 204)
	addEmote("😄 Rire aux eclats", function() playAnim(507770818, false) end, 205)
	addEmote("🙇 S'incliner", function() playAnim(507770143, false) end, 206)
	addEmote("👋 Faire coucou", function() playAnim(507770018, false) end, 207)
	addEmote("😢 Pleurer", function() playAnim(507771675, true) end, 208)

	-- === DANSES ===
	addCategory("💃 DANSES", 300)
	addEmote("💃 Danse 1", function() playAnim(507771019, false) end, 301)
	addEmote("🕺 Danse 2", function() playAnim(507771238, false) end, 302)
	addEmote("🤸 Danse 3 / Breakdance", function() playAnim(507771475, false) end, 303)
	addEmote("💃 Floss", function() playAnim(4562795588, false) end, 304)
	addEmote("🎉 Danse folle", function() playAnim(5915756891, false) end, 305)
	addEmote("🤖 The Robot", function() playAnim(4145675840, false) end, 306)
	addEmote("🤖 The Robot 2", function() playAnim(4145721148, false) end, 307)
	addEmote("🤖 The Robot 3", function() playAnim(4145739796, false) end, 308)
	addEmote("🎵 Pop Lock", function() playAnim(5145477480, false) end, 309)
	addEmote("🇷🇺 Kazachok", function() playAnim(3360689775, false) end, 310)
	addEmote("🎶 Bhangra", function() playAnim(3341856292, false) end, 311)
	addEmote("🔥 Hype", function() playAnim(5227113470, false) end, 312)
	addEmote("🔥 Hype 2", function() playAnim(6102658794, false) end, 313)
	addEmote("🧍 T-Pose", function() playAnim(6180856777, false) end, 314)

	-- === FUN & DRÔLE ===
	addCategory("😜 FUN", 400)
	addEmote("😱 Panique", function() playAnim(128856001, false) end, 401)
	addEmote("😴 S'endormir", function() playAnim(5846585438, true) end, 402)
	addEmote("🤯 Tomber de chaise", function() playAnim(1088597938, false) end, 403)
	addEmote("😵 Faceplant", function() playAnim(5848298071, false) end, 404)
	addEmote("🍂 Tomber (falling)", function() playAnim(507771896, false) end, 405)
	addEmote("😭 Pleurer a chaudes larmes", function() playAnim(507771675, true) end, 406)

	-- === GYMNASTIQUE & ACROBATIES ===
	addCategory("🤸 GYMNASTIQUE", 500)
	addEmote("🤸 Backflip", function() playAnim(6108278401, false) end, 501)
	addEmote("🤸 Frontflip", function() playAnim(6108278904, false) end, 502)
	addEmote("🤸 Cartwheel (roue)", function() playAnim(6108279758, false) end, 503)
	addEmote("🤸 Appui tete", function() playAnim(6108280253, false) end, 504)
	addEmote("🤸 Toupie tete", function() playAnim(6108280896, false) end, 505)
	addEmote("🤸 Saut tournoyant", function() playAnim(6108281614, false) end, 506)
	addEmote("🤸 Bond", function() playAnim(6108282273, false) end, 507)
	addEmote("🤸 Rondade", function() playAnim(6108282878, false) end, 508)
	addEmote("🤸 Saut groupe", function() playAnim(6108283532, false) end, 509)
	addEmote("🤸 Aerial", function() playAnim(6108284061, false) end, 510)
	addEmote("🤸 Back tuck", function() playAnim(6108284712, false) end, 511)
	addEmote("🤸 Front tuck", function() playAnim(6108285406, false) end, 512)

	-- === SAUTS & MOUVEMENTS ===
	addCategory("🏃 SAUTS", 600)
	addEmote("🦘 Saut normal", function() playAnim(507772438, false) end, 601)
	addEmote("🧗 Escalade", function() playAnim(507772525, true) end, 602)

	-- Dragging de la fenetre
	local dragging = false
	local dragStart, startPos
	emoteTitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = emoteWin.Position
		end
	end)
	emoteTitleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			emoteWin.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- Toggle fenetre
	emoteBtn.MouseButton1Click:Connect(function()
		emoteWin.Visible = not emoteWin.Visible
		if playSound then playSound(6042053626, 0.2) end
	end)
	emoteClose.MouseButton1Click:Connect(function()
		emoteWin.Visible = false
		if playSound then playSound(6042053626, 0.2) end
	end)

	-- Cleanup au shutdown
	if _G._shutdownCallbacks then
		_G._shutdownCallbacks[#_G._shutdownCallbacks + 1] = function()
			pcall(function()
				stopAll()
				if emoteWin then emoteWin:Destroy() end
			end)
		end
	end

	_G._stopEmote = stopAll
	_G._playEmote = playAnim
end)()

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


updateLoad(0.70, "Protections...")
task.wait(0.05)
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
_G.neutralizeSeat = neutralizeSeat
end

local function restoreSeat(seat)
	if not seat then return end
	if (seat:IsA("Seat") or seat:IsA("VehicleSeat")) and seat:GetAttribute("Neutralized") then
		seat.Disabled = false
		seat.CanTouch = true
		seat:SetAttribute("Neutralized", nil)
	end
_G.restoreSeat = restoreSeat
end

local function createAntiSeatSitWatcher()
	local function onCharacter(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			hum = char:WaitForChild("Humanoid")
		end
_G.createAntiSeatSitWatcher = createAntiSeatSitWatcher
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
_G.createProtectionSwitch = createProtectionSwitch
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

-- Switch "Tout activer" — bascule toutes les protections d'un coup
local allProtectionSwitches = {}
local function addProtectionSwitch(name, label, y)
	local sw = createProtectionSwitch(name, label, y)
	table.insert(allProtectionSwitches, sw)
	return sw
end

createSwitch(protectionsScroll, "Tout activer / desactiver", 0, function(on)
	for _, sw in ipairs(allProtectionSwitches) do
		pcall(function() sw.set(on) end)
	end
end)

addProtectionSwitch("antiFling", "Anti Fling", 10)
addProtectionSwitch("antiSeat", "Anti Seat", 52)
addProtectionSwitch("antiTeleport", "Anti Teleport", 94)
addProtectionSwitch("antiFall", "Anti Fall", 136)
addProtectionSwitch("antiKill", "Anti Kill / Spawn TP", 178)
addProtectionSwitch("antiAFK", "Anti AFK (5 min)", 220)
addProtectionSwitch("antiSpeedHack", "Anti Speed Hack", 262)
addProtectionSwitch("antiGodMode", "Anti God Mode", 304)
addProtectionSwitch("antiParalyze", "Anti Paralyze / Freeze", 346)
addProtectionSwitch("antiBlind", "Anti Blind / Dark", 388)
addProtectionSwitch("antiGrab", "Anti Grab / Fling CFrame", 430)

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

-- === NOUVELLES PROTECTIONS v39.29 ===
task.spawn(function()
	while true do
		task.wait(0.1)
		updateCharacter()
		if not rootPart or not humanoid then continue end
		
		-- Anti Speed Hack: clamp vélocité horizontale
		if protectionsState.antiSpeedHack then
			local vel = rootPart.AssemblyLinearVelocity
			local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			local maxSpeed = (humanoid.WalkSpeed or 16) * 2.5 + 20
			if flatSpeed > maxSpeed and not humanoid.Sit and not flyState.flying and not noclipState.enabled then
				local ratio = maxSpeed / flatSpeed
				rootPart.AssemblyLinearVelocity = Vector3.new(vel.X * ratio, vel.Y, vel.Z * ratio)
			end
		end
		
		-- Anti God Mode
		if protectionsState.antiGodMode then
			if humanoid.Health > humanoid.MaxHealth and humanoid.MaxHealth > 0 then
				pcall(function() humanoid.Health = humanoid.MaxHealth end)
			end
		end
		
		-- Anti Paralyze
		if protectionsState.antiParalyze then
			if humanoid.PlatformStand then
				pcall(function() humanoid.PlatformStand = false end)
			end
			if not protectionsState._legitWalkSpeed then
				protectionsState._legitWalkSpeed = humanoid.WalkSpeed
			end
			if humanoid.WalkSpeed == 0 and protectionsState._legitWalkSpeed and protectionsState._legitWalkSpeed > 0 then
				pcall(function() humanoid.WalkSpeed = protectionsState._legitWalkSpeed end)
			end
		end
		
		-- Anti Blind
		if protectionsState.antiBlind then
			if not protectionsState.lastLightingAmbient then
				protectionsState.lastLightingAmbient = Lighting.Ambient
				protectionsState.lastLightingBrightness = Lighting.Brightness
			end
			local amb = Lighting.Ambient
			if amb.R < 0.1 and amb.G < 0.1 and amb.B < 0.1 then
				pcall(function()
					Lighting.Ambient = protectionsState.lastLightingAmbient or Color3.fromRGB(128, 128, 128)
					Lighting.Brightness = protectionsState.lastLightingBrightness or 2
				end)
			end
			if Lighting.FogEnd < 10 and Lighting.FogStart >= 0 then
				pcall(function() Lighting.FogEnd = 1e9 end)
			end
		end
		
		-- Anti Grab
		if protectionsState.antiGrab and not flyState.flying and not noclipState.enabled then
			local pos = rootPart.Position
			local lastPos = protectionsState.lastHrpPosition
			if lastPos then
				local delta = (pos - lastPos).Magnitude
				if delta > 100 then
					if protectionsState.lastSafeCFrame then
						pcall(function() rootPart.CFrame = protectionsState.lastSafeCFrame end)
					end
					rootPart.AssemblyLinearVelocity = Vector3.zero
				end
			end
			if not protectionsState.antiTeleport then
				protectionsState.lastSafeCFrame = rootPart.CFrame
				protectionsState.lastHrpPosition = pos
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
	warnTitle.Text = "! ATTENTION - REMOTES DU JEU"
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
		local seen = {}
		local function addRemote(obj)
			if obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
				local fn = obj:GetFullName()
				if not seen[fn] then
					seen[fn] = true
					table.insert(remotes, obj)

				end
_G._wrapRemotes = _wrapRemotes
			end
		end
		pcall(function()
			for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do addRemote(obj) end
		end)
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do addRemote(obj) end
		end)
		pcall(function()
			for _, obj in ipairs(game.Players.LocalPlayer:GetDescendants()) do addRemote(obj) end
		end)
		pcall(function()
			for _, obj in ipairs(game:GetService("StarterGui"):GetDescendants()) do addRemote(obj) end
		end)
		pcall(function()
			for _, obj in ipairs(game:GetService("Players"):GetChildren()) do
				if obj:IsA("Player") then
					for _, desc in ipairs(obj:GetDescendants()) do addRemote(desc) end
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
	refreshRemotesBtn.Position = UDim2.new(1, -32, 0, 5)
	refreshRemotesBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
	refreshRemotesBtn.BorderSizePixel = 0
	refreshRemotesBtn.Text = "R"
	refreshRemotesBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
	refreshRemotesBtn.TextSize = 14
	refreshRemotesBtn.Font = Enum.Font.GothamBold
	refreshRemotesBtn.Parent = remoteHeader
	createCorner(refreshRemotesBtn, 4)

	-- Barre de recherche pour filtrer les remotes par nom
	local remotesSearchBox = Instance.new("TextBox")
	remotesSearchBox.Size = UDim2.new(1, -8, 0, 28)
	remotesSearchBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	remotesSearchBox.BorderSizePixel = 0
	remotesSearchBox.Text = ""
	remotesSearchBox.PlaceholderText = "Filtrer les remotes par nom..."
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

	-- Row: argsBox + fireBtn cote a cote
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
	local refreshLock = false
	local function refreshRemotesList(force)
		if refreshLock and not force then return end
		refreshLock = true
		-- Check if we already have cards (don't destroy if just updating)
		local existingCards = {}
		for _, child in ipairs(remoteListFrame:GetChildren()) do
			if child:IsA("Frame") then
				existingCards[child.Name] = child
			end
		end
		
		local remotes = collectRemotes()
		remoteCount.Text = "Remotes detectes : " .. #remotes
		table.sort(remotes, function(a, b)
			return a.Name < b.Name
		end)
		
		-- Only destroy+recreate if the remote list changed (new/removed remotes)
		local needRebuild = force or #remotes ~= #existingCards
		if not needRebuild then
			-- Just update LayoutOrder for sorting
			for i, remote in ipairs(remotes) do
				local cardName = remote:GetFullName():gsub("[^%w]", "_")
				local card = existingCards[cardName]
				if card then
					card.LayoutOrder = i
		
				end
			end
		else
			-- Full rebuild (new remotes detected)
			for _, child in ipairs(remoteListFrame:GetChildren()) do
				if child:IsA("Frame") then child:Destroy() end
			end
			for _, remote in ipairs(remotes) do
				makeRemoteCard(remote)
			end
		end
		refreshLock = false
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

updateLoad(0.80, "Registry...")
task.wait(0.05)
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
_G.joinOrIndi = function(list, sep, max)
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

_G.buildRegistrySection = buildRegistrySection

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
	_=(function()
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
_G.renderResult = renderResult
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
		wLbl.Text = "! APIs Roblox bloquees par l'exécuteur — essaie Synapse X, Wave ou Fluxus pour voir les détails (jeux favoris, badges, groupes, etc.)"
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
	table.insert(lines, "  💰 Robux            : " .. (data.robux or "Indisponible"))
	local badgesText = joinOrIndi(data.badgesList, ", ", 10)
	table.insert(lines, "  🏅 Badges           : " .. badgesText)
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
			table.insert(lines, "  ! Pas dans ce serveur (vérification impossible)")
		end
	else
		table.insert(lines, "  ! userId manquant")
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
		
		-- 3b) Native Roblox data (no HTTP needed - works on ALL executors)
		pcall(function()
			-- Get display name via native API
			local name = Players:GetNameFromUserIdAsync(userId)
			if name and name ~= "" then data.displayName = name end
		end)
		pcall(function()
			-- Check if user is online on THIS server
			local player = Players:GetPlayerByUserId(userId)
			if player then
				data.presenceType = 2 -- "En jeu"
				data.presencePlaceId = tostring(game.PlaceId)
				data.presenceLastLocation = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "?"
				-- Get their friends list (native)
				local friends = player:GetFriendsOnline()
				if friends and #friends > 0 then
					data.friendsList = {}
					for i, f in ipairs(friends) do
						if i > 5 then break end
						table.insert(data.friendsList, f.Username or f.Name or "?")
					end
				end
			end
		end)
		pcall(function()
			-- Get account age in days (native)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				data.accountAgeDays = player.AccountAge
			end
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
				-- 6s) Robux (economy)
				pcall(function()
					local r = httpGet("https://economy.roblox.com/v1/users/" .. userId .. "/currency")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.robux then data.robux = d2.robux end
					end
				end)
				-- 6t) Badges list (names)
				pcall(function()
					local r = httpGet("https://badges.roblox.com/v1/users/" .. userId .. "/badges?limit=20&sortOrder=Desc")
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.data and #d2.data > 0 then
							data.badgesList = {}
							for i, b in ipairs(d2.data) do
								if i > 10 then break end
								if b.name then table.insert(data.badgesList, b.name) end
							end
						end
					end
				end)
				-- 6u) Description complete
				pcall(function()
					local r = httpGet("https://accountinformation.roblox.com/v1/description/" .. userId)
					if r and r ~= "" then
						local d2 = HttpService:JSONDecode(r)
						if d2 and d2.description then data.blurb = d2.description end
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
					statusLbl.Text = "! @" .. username .. " (ID:" .. userId .. ") — APIs externes bloquées par l'exécuteur. Lien : " .. data.profileUrl
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
			if child:IsA("GuiObject") and child.LayoutOrder == 0 then
				child.LayoutOrder = (#rs:GetChildren() - 1)
			end
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

updateLoad(0.90, "Chat commands...")
task.wait(0.05)
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

updateLoad(0.95, "Finalisation...")
task.wait(0.05)
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
	pcall(function() _switchTab("Home") end)
		-- LAYER 3: fallback à 3s (au cas où)
		task.delay(3, function()
			pcall(function()
				if mainFrame and not mainFrame.Visible then
					mainFrame.Visible = true
				end
				if _pages and _pages["Home"] and not _pages["Home"].Visible then
					pcall(function() _switchTab("Home") end)
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
		if pages and pages["Home"] and not pages["Home"].Visible then
				switchTab("Home")
		end
	end)
end)

-- Lancer l'intro cinéma si on veut (désactivée par défaut car elle bloque le fallback)
-- pcall(function() bootSequence(function()
-- 	pcall(function() mainFrame.Visible = true end)
-- 	switchTab("Joueurs")
-- end) end)


-- Remove loading screen
pcall(function() if loadingGui then loadingGui:Destroy() end end)