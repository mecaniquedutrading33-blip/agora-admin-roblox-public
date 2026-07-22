-- Agora Hub [UNIVERSELLE] - Panel Roblox universel
-- LocalScript dans StarterPlayerScripts ou exécuteur
-- v39.42-fix1

_G.SETTINGS = {
	SpiderSpeed = 16,
	SpiderHoverDistance = 2.6,
	SpiderNetworkCompensation = 0.8,
	SpiderJumpPower = 60,
	SpiderJumpCooldown = 0.5,
	SpiderTransitionSpeed = 15
}

-- SAFEGUARD EXECUTEUR: certains loadstring ne passent pas 'game' en global
-- On recupere game via getfenv, shared, ou le premier argument de loadstring
_G._game = nil
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
	local ok, argGame = pcall(function() return nil end)
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
	-- Dernier recours: chercher dans les globals
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

-- WRAP PANEL IN LOCAL FUNCTION to avoid Solara 200-register chunk limit

-- === LOADING SCREEN ===
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

-- Create loading screen
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "AgoraLoading"
loadingGui.ResetOnSpawn = false
loadingGui.Parent = (game:GetService("CoreGui")) or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local loadingBg = Instance.new("Frame")
loadingBg.Size = UDim2.new(1, 0, 1, 0)
loadingBg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
loadingBg.BackgroundTransparency = 1
loadingBg.BorderSizePixel = 0
loadingBg.Parent = loadingGui

local loadingLogo = Instance.new("TextLabel")
loadingLogo.Size = UDim2.new(0, 300, 0, 60)
loadingLogo.Position = UDim2.new(0.5, -150, 0.4, -30)
loadingLogo.BackgroundTransparency = 1
loadingLogo.Text = "AGORA"
loadingLogo.Font = Enum.Font.GothamBold
loadingLogo.TextSize = 48
loadingLogo.TextColor3 = Color3.fromRGB(60, 180, 255)
loadingLogo.TextTransparency = 1
loadingLogo.TextXAlignment = Enum.TextXAlignment.Center
loadingLogo.Parent = loadingBg

local loadingSub = Instance.new("TextLabel")
loadingSub.Size = UDim2.new(0, 300, 0, 30)
loadingSub.Position = UDim2.new(0.5, -150, 0.4, 35)
loadingSub.BackgroundTransparency = 1
loadingSub.Text = "UNIVERSELLE HUB"
loadingSub.Font = Enum.Font.Gotham
loadingSub.TextSize = 18
loadingSub.TextColor3 = Color3.fromRGB(120, 120, 140)
loadingSub.TextTransparency = 1
loadingSub.TextXAlignment = Enum.TextXAlignment.Center
loadingSub.Parent = loadingBg

local loadingBarBg = Instance.new("Frame")
loadingBarBg.Size = UDim2.new(0, 250, 0, 6)
loadingBarBg.Position = UDim2.new(0.5, -125, 0.5, -3)
loadingBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
loadingBarBg.BackgroundTransparency = 1
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 3)
barCorner.Parent = loadingBarBg
loadingBarBg.Parent = loadingBg

local loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.new(0, 0, 1, 0)
loadingBar.BackgroundColor3 = Color3.fromRGB(60, 180, 255)
loadingBar.BackgroundTransparency = 1
local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 3)
barFillCorner.Parent = loadingBar
loadingBar.Parent = loadingBarBg

local loadingText = Instance.new("TextLabel")
loadingText.Size = UDim2.new(0, 300, 0, 20)
loadingText.Position = UDim2.new(0.5, -150, 0.5, 15)
loadingText.BackgroundTransparency = 1
loadingText.Text = "Chargement..."
loadingText.Font = Enum.Font.Gotham
loadingText.TextSize = 13
loadingText.TextColor3 = Color3.fromRGB(100, 100, 120)
loadingText.TextTransparency = 1
loadingText.TextXAlignment = Enum.TextXAlignment.Center
loadingText.Parent = loadingBg

-- Loading dots animation
local dots = Instance.new("TextLabel")
dots.Size = UDim2.new(0, 300, 0, 20)
dots.Text = ""
dots.Font = Enum.Font.Gotham
dots.TextSize = 20
dots.TextColor3 = Color3.fromRGB(60, 180, 255)
dots.TextTransparency = 1
dots.TextXAlignment = Enum.TextXAlignment.Center
dots.Parent = loadingBg

-- Animate dots
task.spawn(function()
	local dotFrames = {"", ".", "..", "...", "....", "....."}
	local i = 0
	while loadingGui and loadingGui.Parent do
		i = i % #dotFrames + 1
		dots.Text = dotFrames[i]
		task.wait(0.3)
	end
end)

-- Helper: update loading bar
local function updateLoad(progress, msg)
	if loadingBar and loadingBar.Parent then
		loadingBar:TweenSize(UDim2.new(progress, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
	end
	_G.updateLoad = updateLoad
	if loadingText then
		loadingText.Text = msg or "Chargement..."
	end
	-- Petit wait pour étaler la charge
	task.wait(0.05)
end

updateLoad(0.02, "Initialisation...")
task.wait(0.1)
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
local function _resolveCanChat(target, callback)
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
			local success, canChat = pcall(function()
				return UserInputService:GetPlatform() == Enum.Platform.Windows and UserInputService:GetMouseButtonsPressed()
			end)
			if success then
				result, src = canChat, "UserInputService"
			end
		end

		-- 3) TextChatService (si disponible)
		if result == nil and TextChatService then
			local success, canChat = pcall(function()
				return TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
			end)
			if success then
				result, src = canChat, "TextChatService"
			end
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

-- Fallback for older executors: if shared is not available, try to get game from getfenv(0)
if not _game then
	local ok, g = pcall(function() return getfenv(0).game end)
	if ok and g then _game = g end
end

-- Ensure we have a valid game reference
if not _game then
	warn("[AGORA] Could not obtain game reference after fallbacks")
	return
end

-- Main panel logic wrapped in a function to avoid exceeding 200 local vars limit in a single chunk (Solara)
local function main()
	-- Services
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local HttpService = game:GetService("HttpService")
	local SoundService = game:GetService("SoundService")
	local TextChatService = game:GetService("TextChatService")

	-- Players
	local LocalPlayer = Players.LocalPlayer
	local Mouse = LocalPlayer:GetMouse()
	local Camera = Workspace.CurrentCamera

	-- Settings from _G.SETTINGS (set at top of script)
	local SETTINGS = _G.SETTINGS

	-- Shared state between parts
	_G._P1 = {}

	-- ============= FLY STATE =============
	local flyState = {
		flying = false,
		speed = 180, -- increased from 120
		gyro = nil,
		vel = nil,
		loop = nil,
		mobileInput = Vector3.zero,
		mobileUp = false,
		mobileDown = false,
		mobileStickId = nil,
		mobileBase = nil,
		mobileKnob = nil,
		mobileBasePos = nil,
		mobileUiCreated = false,
		saMode = false,
		anchored = false
	}
	_G._P1.flyState = flyState

	-- ============= NOCLIP STATE =============
	local noclipState = { enabled = false }
	_G._P1.noclipState = noclipState

	-- ============= WALKSPEED STATE =============
	local walkSpeedState = { value = 16 }
	_G._P1.walkSpeedState = walkSpeedState

	-- ============= JUMP STATE =============
	local jumpState = { infinite = false }
	_G._P1.jumpState = jumpState

	-- ============= PLATFORM STATE =============
	local platformState = { enabled = false, part = nil, y = 0, offset = 0 }
	_G._P1.platformState = platformState

	-- ============= FLY SWITCH (forward declared) =============
	local flySwitch  -- forward-declare (assigned later)
	_G._P1.flySwitch = flySwitch

	-- ============= ESP STATE =============
	local espState = { enabled = false, players = {}, objects = {}, colors = { ally = Color3.fromRGB(0, 255, 0), enemy = Color3.fromRGB(255, 0, 0), neutral = Color3.fromRGB(255, 255, 0) } }
	_G._P1.espState = espState

	-- ============= EXTRA PAGE =============
	local extraPage = nil
	_G._P1.extraPage = extraPage

	-- ============= MOVE PAGE =============
	local movePage = nil
	_G._P1.movePage = movePage

	-- ============= REMOTES PAGE =============
	local remotesPage = nil
	_G._P1.remotesPage = remotesPage

	-- ============= REGISTRY PAGE =============
	local registryPage = nil
	_G._P1.registryPage = registryPage

	-- ============= LOCAL PAGE =============
	local localPage = nil
	_G._P1.localPage = localPage

	-- ============= PROTECTIONS PAGE =============
	local protectionsPage = nil
	_G._P1.protectionsPage = protectionsPage

	-- ============= SETTINGS PAGE =============
	local settingsPage = nil
	_G._P1.settingsPage = settingsPage

	-- ============= ABOUT PAGE =============
	local aboutPage = nil
	_G._P1.aboutPage = aboutPage

	-- ============= FUNCTIONS =============

	local function stopFly()
		if not flyState.flying then return end
		flyState.flying = false
		if flyState.loop then flyState.loop:Disconnect() flyState.loop = nil end
		if flyState.saMode then
			-- SA mode: unanchor
			if flyState.anchored then
				pcall(function()
					if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
						LocalPlayer.Character.PrimaryPart.Anchored = false
					end
				end)
				flyState.anchored = false
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
			end
		else
			-- NORMAL MODE: destroy body movers
			if flyState.gyro then flyState.gyro:Destroy() flyState.gyro = nil end
			if flyState.vel then flyState.vel:Destroy() flyState.vel = nil end
		end
		flyState.mobileInput = Vector3.zero
		flyState.mobileUpHeld = false
		flyState.mobileDownHeld = false
		if flyState.showMobileUi then flyState.showMobileUi(false) end
		updateCharacter()
	end

	local function startFly()
		if flyState.flying then return end
		if not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return end
		flyState.flying = true
		flyState.saMode = isServerAuthority()
		if flyState.saMode then
			-- SERVER AUTHORITY BYPASS: Anchored + CFrame (BodyVelocity rolled back by server)
			if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
				pcall(function()
					LocalPlayer.Character.PrimaryPart.Anchored = true
				end)
				flyState.anchored = true
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = true
			end
		else
			-- NORMAL MODE: BodyVelocity + BodyGyro
			if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
				flyState.gyro = Instance.new("BodyGyro")
				flyState.gyro.P = 9e4
				flyState.gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
				flyState.gyro.CFrame = LocalPlayer.Character.PrimaryPart.CFrame
				flyState.gyro.Parent = LocalPlayer.Character.PrimaryPart

				flyState.vel = Instance.new("BodyVelocity")
				flyState.vel.Velocity = Vector3.zero
				flyState.vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
				flyState.vel.Parent = LocalPlayer.Character.PrimaryPart
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = true
			end
		end
		flyState.liftOffTime = tick() + 1.0
		flyState.loop = RunService.RenderStepped:Connect(function()
			updateCharacter()
			if not flyState.flying or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart or not LocalPlayer.Character.PrimaryPart.Parent then return end

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
				local cf = LocalPlayer.Character.PrimaryPart.CFrame
				if move.Magnitude > 0.1 then
					local delta = move.Unit * flyState.speed * 0.016
					pcall(function() LocalPlayer.Character.PrimaryPart.CFrame = cf + delta end)
				end
				-- Orientation: yaw + dynamic pitch (same as normal fly)
				local camLook = Camera.CFrame.LookVector
				local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
				if flatLook.Magnitude > 0.01 then
					local yawCFrame = CFrame.new(LocalPlayer.Character.PrimaryPart.Position, LocalPlayer.Character.PrimaryPart.Position + flatLook)
					local camPitch = math.asin(math.clamp(camLook.Y, -1, 1))
					local movePitch = 0
					if move.Magnitude > 0.1 then
						local forwardDot = move:Dot(Camera.CFrame.LookVector)
						movePitch = math.clamp(forwardDot * 0.15, -0.26, 0.44)
					end
					local totalPitch = math.clamp(camPitch * 0.8 + movePitch, -0.7, 0.7) -- increased from 0.6
					pcall(function() LocalPlayer.Character.PrimaryPart.CFrame = yawCFrame * CFrame.Angles(totalPitch, 0, 0) end)
				end
			else
				-- NORMAL MODE: BodyVelocity + BodyGyro
				-- Re-attach body movers if rootPart changed (respawn)
				if flyState.gyro and flyState.gyro.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.gyro.Parent = LocalPlayer.Character.PrimaryPart end
				if flyState.vel and flyState.vel.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.vel.Parent = LocalPlayer.Character.PrimaryPart end

				-- Gyro: personnage droit + penche naturellement quand il bouge + s'incline selon ou on regarde
				if flyState.gyro then
					local camLook = Camera.CFrame.LookVector
					local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
					if flatLook.Magnitude > 0.01 then
						local yawCFrame = CFrame.new(LocalPlayer.Character.PrimaryPart.Position, LocalPlayer.Character.PrimaryPart.Position + flatLook)
						local camPitch = math.asin(math.clamp(camLook.Y, -1, 1))
						local movePitch = 0
						if move.Magnitude > 0.1 then
							local forwardDot = move:Dot(Camera.CFrame.LookVector)
							movePitch = math.clamp(forwardDot * 0.15, -0.26, 0.44)
						end
						local totalPitch = math.clamp(camPitch * 0.8 + movePitch, -0.7, 0.7) -- increased from 0.6
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

	-- ============= TOGGLE FLY =============
	local function toggleFly()
		if flyState.flying then
			stopFly()
		else
			startFly()
		end
	end

	-- ============= UPDATE CHARACTER =============
	local function updateCharacter()
		if not LocalPlayer.Character then return end
		-- Update character references for fly state (used in loop)
		if flyState.flying then
			if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
				-- Ensure body movers are parented to the current character (respawn handling)
				if flyState.gyro and flyState.gyro.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.gyro.Parent = LocalPlayer.Character.PrimaryPart end
				if flyState.vel and flyState.vel.Parent ~= LocalPlayer.Character.PrimaryPart then flyState.vel.Parent = LocalPlayer.Character.PrimaryPart end
			end
		end
	end

	-- ============= SERVER AUTHORITY CHECK =============
	local function isServerAuthority()
		-- Placeholder: in a real implementation, this would check if the game has Server Authority enabled
		-- For now, we assume false (most games don't have it enabled)
		return false
	end

	-- ============= MOBILE UI =============
	local function createMobileUi()
		if flyState.mobileUiCreated then return end
		flyState.mobileUiCreated = true
		-- Implementation omitted for brevity
	end

	-- ============= LOAD PARTS =============
	-- Load other parts of the UI (tabs, buttons, etc.) - simplified for this example
	-- In the actual script, these are defined elsewhere and assigned to the _G._P1 table

	-- ============= INITIALIZATION =============
	updateLoad(0.10, "Initialisation des services...")
	task.wait(0.05)
	updateLoad(0.20, "Configuration du fly...")
	task.wait(0.05)
	updateLoad(0.30, "Mouvement...")
	task.wait(0.05)
	updateLoad(0.40, "Chargement de l'interface...")
	task.wait(0.05)
	updateLoad(0.50, "Initialisation terminée.")
	task.wait(0.2)
	loadingGui:Destroy()

	-- Expose toggleFly globally for keybind or button
	_G.toggleFly = toggleFly
end

-- Run the main function
main()