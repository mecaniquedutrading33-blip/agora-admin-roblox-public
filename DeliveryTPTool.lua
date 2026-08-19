-- ============================================================
--  SUPPLYBOX TP TOOL  (sans GUI - anti-cheat bloque les GUI)
--  Teleporte TOUS les parts nommes "SupplyBox" vers une
--  position precise.
--
--  FONCTIONNEMENT :
--  Appuie sur  =  pour teleporter TOUS les SupplyBox vers
--  Vector3.new(20.700, 1.500, -10.900).
--  Appuie encore sur  =  pour re-teleporter (si de nouveaux
--  SupplyBox apparaissent).
--
--  USAGE : colle dans ton executor (Solara, etc.) et execute.
-- ============================================================

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============ CONFIG ============
local TARGET_NAME = "SupplyBox"
local DEST_POS = Vector3.new(20.700, 1.500, -10.900)

-- ============ ETAT ============
local state = {
	active = false,
	lastCount = 0,
}

-- ============ HELPERS ============
local function notify(msg, color)
	pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "SupplyNotify"
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

-- Teleporte TOUS les SupplyBox vers la destination
-- Chaque box est etalee legerement autour du point pour ne pas s'empiler
local function teleportAllSupplyBoxes()
	local count = 0
	pcall(function()
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name == TARGET_NAME then
				-- Etaler chaque box autour du point (offset aleatoire dans un rayon de 3 studs)
				-- pour eviter qu'elles s'empilent toutes au meme endroit
				local spread = Vector3.new(
					(math.random() - 0.5) * 6,
					0,
					(math.random() - 0.5) * 6
				)
				obj.CFrame = CFrame.new(DEST_POS + spread)
				obj.AssemblyLinearVelocity = Vector3.zero
				obj.AssemblyAngularVelocity = Vector3.zero
				-- Garder la collision active pour que la machine puisse les prendre
				obj.CanCollide = true
				count = count + 1
			end
		end
	end)
	state.lastCount = count
	return count
end

-- ============ RACCOURCI CLAVIER ============
--  =  : teleporter TOUS les SupplyBox vers la destination
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Equals then
		local n = teleportAllSupplyBoxes()
		state.active = true
		notify("Teleporte " .. n .. " SupplyBox vers (20.7, 1.5, -10.9)", Color3.fromRGB(0, 255, 200))
	end
end)

-- ============ CLEANUP ============
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
end)
