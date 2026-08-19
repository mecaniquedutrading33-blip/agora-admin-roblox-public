-- ============================================================
--  DELIVERY TP TOOL  (sans GUI - anti-cheat bloque les GUI)
--  Livre des objets (bouteilles, etc.) vers un point choisi.
--
--  FONCTIONNEMENT (raccourcis clavier) :
--  1) Appuie sur  =  pour ACTIVER / DESACTIVER le mode.
--  2) Quand c'est actif, appuie sur  -  pour choisir la
--     DESTINATION (clique ensuite l'endroit ou livrer).
--  3) Ensuite, TOUT ce que tu clickes avec ta souris se
--     teleporte a cette destination.
--
--  USAGE : colle dans ton executor (Solara, etc.) et execute.
-- ============================================================

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============ ETAT ============
local state = {
	active = false,        -- le mode est ON
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
-- Quand le mode est actif, chaque clic souris teleporte la cible
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
		local model = target:FindFirstAncestorOfClass("Model")
		if model and model ~= LocalPlayer.Character then
			teleportObject(model)
		else
			teleportObject(target)
		end
	end
end)

-- ============ RACCOURCIS CLAVIER ============
--  =  : activer / desactiver
--  -  : choisir la destination (quand actif)
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Equals then
		-- Toggle actif/inactif
		state.active = not state.active
		if state.active then
			state.waitingDest = true
			notify("Mode ACTIVE ! Appuie sur - puis clique la destination.", Color3.fromRGB(0, 255, 200))
		else
			state.waitingDest = false
			clearDestMarker()
			notify("Mode desactive.", Color3.fromRGB(200, 200, 210))
		end
	elseif input.KeyCode == Enum.KeyCode.Minus then
		-- Choisir la destination
		if state.active then
			state.waitingDest = true
			notify("Clique sur la DESTINATION...", Color3.fromRGB(0, 255, 200))
		else
			notify("Active d'abord avec =", Color3.fromRGB(255, 180, 60))
		end
	end
end)

-- ============ CLEANUP ============
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
end)
