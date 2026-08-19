-- ============================================================
--  DELIVERY TP TOOL  (script executor / LocalScript)
--  Livre des objets (bouteilles, etc.) vers un point choisi.
--
--  FONCTIONNEMENT :
--  1) Un switch "Witch" dans le GUI.
--  2) Quand tu l'actives -> il te demande de CLICKER l'endroit
--     ou les objets doivent arriver (destination).
--  3) Ensuite, TOUT ce que tu clickes avec ta souris se
--     teleporte a cette destination.
--  4) Re-clic sur le switch pour desactiver.
--
--  USAGE : colle dans ton executor (Solara, etc.) et execute.
-- ============================================================

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

-- ============ ETAT ============
local state = {
	active = false,        -- le switch est ON
	waitingDest = false,    -- on attend que tu clickes la destination
	dest = nil,            -- CFrame de destination
	destMarker = nil,       -- marqueur visuel de la destination
	destConn = nil,
}

-- ============ HELPERS ============
local function notify(msg, color)
	pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "DeliveryNotify"
		gui.ResetOnSpawn = false
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, 320, 0, 40)
		f.Position = UDim2.new(0.5, -160, 0.1, 0)
		f.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		f.BorderSizePixel = 0
		f.ZIndex = 999
		f.Parent = gui
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = f
		local s = Instance.new("UIStroke") s.Color = color or Color3.fromRGB(100, 200, 255) s.Thickness = 1.5 s.Parent = f
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -12, 1, 0)
		t.Position = UDim2.new(0, 6, 0, 0)
		t.BackgroundTransparency = 1
		t.Text = msg
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextSize = 13
		t.Font = Enum.Font.GothamSemibold
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.Parent = f
		task.delay(2.5, function()
			pcall(function() gui:Destroy() end)
		end)
	end)
end

-- Marqueur visuel de la destination (sphere cyan)
local function clearDestMarker()
	if state.destMarker then
		pcall(function() state.destMarker:Destroy() end)
		state.destMarker = nil
	end
	if state.destConn then
		pcall(function() state.destConn:Disconnect() end)
		state.destConn = nil
	end
end

local function showDestMarker(cf)
	clearDestMarker()
	local m = Instance.new("Part")
	m.Name = "DeliveryDestMarker"
	m.Anchored = true
	m.CanCollide = false
	m.Transparency = 0.4
	m.Size = Vector3.new(3, 3, 3)
	m.Shape = Enum.PartType.Ball
	m.Color = Color3.fromRGB(0, 255, 200)
	m.Material = Enum.Material.Neon
	m.Parent = workspace
	state.destMarker = m
	-- Pulse animation
	state.destConn = RunService.RenderStepped:Connect(function()
		if state.destMarker and state.destMarker.Parent then
			local s = 3 + math.sin(tick() * 4) * 0.5
			state.destMarker.Size = Vector3.new(s, s, s)
		end
	end)
end

-- Teleporte un objet vers la destination
local function teleportObject(obj)
	if not obj or not state.dest then return end
	pcall(function()
		-- Si c'est un modele, teleporter tout le modele
		if obj:IsA("Model") then
			local pivot = obj:GetPivot()
			local dest = state.dest.Position + Vector3.new(0, 2, 0)
			obj:PivotTo(CFrame.new(dest) * (pivot - pivot.Position))
		elseif obj:IsA("BasePart") then
			obj.CFrame = state.dest * CFrame.new(0, 2, 0)
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- ============ DETECTION DU CLIC ============
-- Quand le switch est actif, chaque clic souris teleporte la cible
local clickConn = UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if not state.active then return end

	-- Si on attend la destination, ce clic definit la destination
	if state.waitingDest then
		local hit = Mouse.Hit
		if hit then
			state.dest = hit
			state.waitingDest = false
			showDestMarker(hit)
			notify("Destination definie ! Clique sur les objets a livrer.", Color3.fromRGB(0, 255, 200))
		end
		return
	end

	-- Sinon, teleporter la cible clique
	local target = Mouse.Target
	if target then
		-- Remonter au modele parent si c'est une partie d'un modele
		local model = target:FindFirstAncestorOfClass("Model")
		if model and model ~= LocalPlayer.Character then
			teleportObject(model)
		else
			teleportObject(target)
		end
	end
end)

-- ============ GUI ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeliveryTPGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 90)
mainFrame.Position = UDim2.new(0.5, -120, 0.5, -45)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 10) mc.Parent = mainFrame
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(80, 80, 100) ms.Thickness = 1.5 ms.Parent = mainFrame

-- Titre
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Delivery TP"
title.TextColor3 = Color3.fromRGB(230, 230, 255)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = mainFrame

-- Statut
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 18)
status.Position = UDim2.new(0, 8, 0, 30)
status.BackgroundTransparency = 1
status.Text = "Switch OFF"
status.TextColor3 = Color3.fromRGB(150, 150, 160)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Center
status.Parent = mainFrame

-- Switch (bouton toggle)
local switchBtn = Instance.new("TextButton")
switchBtn.Size = UDim2.new(0, 120, 0, 30)
switchBtn.Position = UDim2.new(0.5, -60, 0, 52)
switchBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
switchBtn.BorderSizePixel = 0
switchBtn.Text = "Witch: OFF"
switchBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
switchBtn.TextSize = 13
switchBtn.Font = Enum.Font.GothamBold
switchBtn.Parent = mainFrame
local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 6) sc.Parent = switchBtn

-- Drag (deplacer le GUI)
local dragging, dragStart, frameStart = false, nil, nil
mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		frameStart = mainFrame.Position
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
	end
end)

-- Toggle du switch
switchBtn.MouseButton1Click:Connect(function()
	state.active = not state.active
	if state.active then
		switchBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
		switchBtn.Text = "Witch: ON"
		status.Text = "Clique sur la DESTINATION..."
		status.TextColor3 = Color3.fromRGB(0, 255, 200)
		state.waitingDest = true
		notify("Witch active ! Clique sur l'endroit ou livrer les objets.", Color3.fromRGB(0, 255, 200))
	else
		switchBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		switchBtn.Text = "Witch: OFF"
		status.Text = "Switch OFF"
		status.TextColor3 = Color3.fromRGB(150, 150, 160)
		state.waitingDest = false
		clearDestMarker()
		notify("Witch desactivee.", Color3.fromRGB(200, 200, 210))
	end
end)

-- ============ CLEANUP ============
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
end)
