-- PANIC KILL: force close all MilanEmerickPanel GUIs and stop loops
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Destroy all ScreenGuis created by the panel
for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
	if gui:IsA("ScreenGui") and (gui.Name == "MilanEmerickPanel" or gui.Name == "AutoClickTargetGui" or gui.Name:match("^TempESPArrow")) then
		gui:Destroy()
	end
end

-- Destroy panel ESP folder
local espFolder = Workspace:FindFirstChild("PanelESP")
if espFolder then espFolder:Destroy() end

-- Stop body movers on current character
if LocalPlayer.Character then
	local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		for _, v in ipairs(hrp:GetChildren()) do
			if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") or v:IsA("AlignOrientation") or v:IsA("AlignPosition") then
				v:Destroy()
			end
		end
		-- Reset physics
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.Sit = false
	end
	-- Remove fake tools
	for _, t in ipairs(LocalPlayer.Character:GetChildren()) do
		if t.Name == "AutoClickTool" or t.Name == "ElevenTool" then t:Destroy() end
	end
end

-- Remove fake tools in backpack
if LocalPlayer:FindFirstChild("Backpack") then
	for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
		if t.Name == "AutoClickTool" or t.Name == "ElevenTool" then t:Destroy() end
	end
end

-- Disconnect renderstepped if possible (best effort via named tables not available, so kill movers above)
print("[PANIC] Panel forcibly closed")
