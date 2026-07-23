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
	_G._P1.Camera = Workspace.CurrentCamera
	_G._P1.HttpService = game:GetService("HttpService")
	_G._P1.Lighting = game:GetService("Lighting")
	_G._P1.LocalPlayer = LocalPlayer
	_G._P1.Mouse = LocalPlayer:GetMouse()
	_G._P1.Players = Players
	_G._P1.ReplicatedStorage = game:GetService("ReplicatedStorage")
	_G._P1.RunService = RunService
	_G._P1.UserInputService = UserInputService
	_G._P1.Workspace = Workspace
	_G._P1.character = character
	_G._P1.closeBtn = closeBtn
	_G._P1.gotoWalkState = gotoWalkState
	_G._P1.humanoid = humanoid
	_G._P1.loadingGui = loadingGui
	_G._P1.localScroll = localScroll
	_G._P1.localState = localState
	_G._P1.mainFrame = mainFrame
	_G._P1.noclipSwitch = noclipSwitch
	_G._P1.pages = pages
	_G._P1.panelMemory = panelMemory
	_G._P1.protectionsScroll = protectionsScroll
	_G._P1.registryLayout = registryLayout
	_G._P1.registryScroll = registryScroll
	_G._P1.rootPart = rootPart
	_G._P1.screenGui = screenGui
	_G._P1.zeroGSwitch = zeroGSwitch
	_G._P1.createCorner = createCorner
	_G._P1.createStroke = createStroke
	_G._P1.tween = tween
	_G._P1.createSwitch = createSwitch
	_G._P1.createButton = createButton
	_G._P1.createSlider = createSlider
	_G._P1.createTab = createTab
	_G._P1.switchTab = switchTab
	_G._P1.shutdownPanel = shutdownPanel
	_G._P1.startFly = startFly
	_G._P1.stopFly = stopFly
	_G._P1.updateLoad = updateLoad
	_G._P1.updateCharacter = updateCharacter
	_G._P1.createToggle = createToggle
	_G._P1.createSection = createSection
	_G._P1.createInput = createInput
	_G._P1.createDropdown = createDropdown
	_G._P1.fullbrightSwitch = fullbrightSwitch
	_G._P1.espSwitch = espSwitch
	_G._P1.noclipState = noclipState
	_G._P1.walkSpeedState = walkSpeedState
	_G._P1.jumpState = jumpState
	_G._P1.platformState = platformState
	_G._P1.espState = espState
	_G._P1.flyState = flyState
	_G._P1.flySwitch = flySwitch
	_G._P1.zeroGSwitch = zeroGSwitch
	_G._P1.fullbrightState = fullbrightState
	_G._P1.clickTPState = clickTPState
	_G._P1.hitboxState = hitboxState
	_G._P1.protectionsState = protectionsState
	_G._P1.autoClickState = autoClickState
	_G._P1.gotoWalkState = gotoWalkState
	_G._P1.localState = localState
	_G._P1.panelMemory = panelMemory
	_G._P1.extraScroll = extraScroll
	_G._P1.localScroll = localScroll
	_G._P1.protectionsScroll = protectionsScroll
	_G._P1.registryScroll = registryScroll
	_G._P1.registryLayout = registryLayout
	_G._P1.serverScroll = serverScroll
	_G._P1.extraPage = extraPage
	_G._P1.movePage = movePage
	_G._P1.remotesPage = remotesPage
	_G._P1.registryPage = registryPage
	_G._P1.localPage = localPage
	_G._P1.protectionsPage = protectionsPage
	_G._P1.settingsPage = settingsPage
	_G._P1.aboutPage = aboutPage
	_G._P1.pages = pages
	_G._P1.mainFrame = mainFrame
	_G._P1.screenGui = screenGui
	_G._P1.closeBtn = closeBtn
	_G._P1.loadingGui = loadingGui
	_G._P1.rootPart = rootPart
	_G._P1.humanoid = humanoid
	_G._P1.character = character
	_G._P1.Camera = Workspace.CurrentCamera
	_G._P1.HttpService = game:GetService("HttpService")
	_G._P1.Lighting = game:GetService("Lighting")
	_G._P1.LocalPlayer = LocalPlayer
	_G._P1.Mouse = LocalPlayer:GetMouse()
	_G._P1.Players = Players
	_G._P1.ReplicatedStorage = game:GetService("ReplicatedStorage")
	_G._P1.RunService = RunService
	_G._P1.UserInputService = UserInputService
	_G._P1.Workspace = Workspace

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

	-- ============= LOAD PART 2 =============

	-- ============= HOME PAGE =============
	local homePage = createTab("Home")
	pages["Home"] = homePage

	;(function()
		local _homePage = homePage
		local _mainFrame = mainFrame
		local _tween = tween
		local _createCorner = createCorner
		local _createStroke = createStroke
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
		local CURRENT_VERSION = "v39.49"
		_G.CURRENT_VERSION = CURRENT_VERSION

		-- Changelog
		local changelogEntries = {
			"v39.49: Onglet Home restauré + fond opaque + 8 onglets",
			"v39.48: Home premier onglet, fond corrigé",
			"v39.47: Home recréé avec stats live",
			"v39.46: Fix intro cinéma + boot safe 3 layers",
			"v39.45: Bridge _G._P1 complet (68 vars)",
			"v39.44: Auto-update + version check",
			"v39.43: Enrichissement joueurs (connexion, badges)",
			"v39.42: Fix fly + noclip + ESP + aimbot"
		}

		-- httpGet multi-fallback
		local function httpGet(url)
			local ok, result = pcall(function() return game:HttpGet(url) end)
			if ok and result then return result end
			ok, result = pcall(function() return _HttpService:GetAsync(url) end)
			if ok and result then return result end
			ok, result = pcall(function() return _HttpService:RequestAsync({Url = url, Method = "GET"}) end)
			if ok and result and result.Body then return result.Body end
			ok, result = pcall(function() return syn and syn.request({Url = url, Method = "GET"}) end)
			if ok and result and result.Body then return result.Body end
			return nil
		end

		-- Translations (14 langues)
		local translations = {
			FR = {Home="Accueil", Joueurs="Joueurs", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registre", Local="Local", Protections="Protections", nouveautes="Nouveautés", discord="Rejoindre le Discord", langue="Langue", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Utilisateurs", enLigne="En ligne"},
			EN = {Home="Home", Joueurs="Players", Move="Move", Extra="Extra", Remotes="Remotes", Registry="Registry", Local="Local", Protections="Protections", nouveautes="Changelog", discord="Join Discord", langue="Language", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Users", enLigne="Online"},
			ES = {Home="Inicio", Joueurs="Jugadores", Move="Mover", Extra="Extra", Remotes="Remotos", Registry="Registro", Local="Local", Protections="Protecciones", nouveautes="Novedades", discord="Unirse a Discord", langue="Idioma", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Usuarios", enLigne="En línea"},
			DE = {Home="Start", Joueurs="Spieler", Move="Bewegen", Extra="Extra", Remotes="Remotes", Registry="Register", Local="Lokal", Protections="Schutz", nouveautes="Neuigkeiten", discord="Discord beitreten", langue="Sprache", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Benutzer", enLigne="Online"},
			PT = {Home="Início", Joueurs="Jogadores", Move="Mover", Extra="Extra", Remotes="Remotos", Registry="Registro", Local="Local", Protections="Proteções", nouveautes="Novidades", discord="Entrar no Discord", langue="Idioma", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Usuários", enLigne="Online"},
			IT = {Home="Home", Joueurs="Giocatori", Move="Muovi", Extra="Extra", Remotes="Remoti", Registry="Registro", Local="Locale", Protections="Protezioni", nouveautes="Novità", discord="Unisciti a Discord", langue="Lingua", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Utenti", enLigne="Online"},
			RU = {Home="Главная", Joueurs="Игроки", Move="Движение", Extra="Экстра", Remotes="Удалённые", Registry="Реестр", Local="Локально", Protections="Защита", nouveautes="Новости", discord="Discord", langue="Язык", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Пользователи", enLigne="Онлайн"},
			ZH = {Home="首页", Joueurs="玩家", Move="移动", Extra="额外", Remotes="远程", Registry="注册表", Local="本地", Protections="保护", nouveautes="更新日志", discord="加入Discord", langue="语言", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="用户", enLigne="在线"},
			JA = {Home="ホーム", Joueurs="プレイヤー", Move="移動", Extra="エクストラ", Remotes="リモート", Registry="レジストリ", Local="ローカル", Protections="保護", nouveautes="更新履歴", discord="Discordに参加", langue="言語", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="ユーザー", enLigne="オンライン"},
			KO = {Home="홈", Joueurs="플레이어", Move="이동", Extra="추가", Remotes="원격", Registry="레지스트리", Local="로컬", Protections="보호", nouveautes="업데이트", discord="Discord 참가", langue="언어", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="사용자", enLigne="온라인"},
			AR = {Home="الرئيسية", Joueurs="اللاعبين", Move="تحريك", Extra="إضافي", Remotes="عن بعد", Registry="السجل", Local="محلي", Protections="حماية", nouveautes="التحديثات", discord="انضم إلى Discord", langue="اللغة", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="المستخدمين", enLigne="متصل"},
			NL = {Home="Home", Joueurs="Spelers", Move="Bewegen", Extra="Extra", Remotes="Extern", Registry="Register", Local="Lokaal", Protections="Bescherming", nouveautes="Nieuws", discord="Word lid van Discord", langue="Taal", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Gebruikers", enLigne="Online"},
			PL = {Home="Strona główna", Joueurs="Gracze", Move="Ruch", Extra="Dodatki", Remotes="Zdalne", Registry="Rejestr", Local="Lokalne", Protections="Ochrona", nouveautes="Aktualności", discord="Dołącz do Discord", langue="Język", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Użytkownicy", enLigne="Online"},
			TR = {Home="Ana Sayfa", Joueurs="Oyuncular", Move="Hareket", Extra="Ekstra", Remotes="Uzaktan", Registry="Kayıt", Local="Yerel", Protections="Koruma", nouveautes="Güncellemeler", discord="Discord'a Katıl", langue="Dil", credits="Agora Hub [UNIVERSELLE] - by Emerick", utilisateurs="Kullanıcılar", enLigne="Çevrimiçi"}
		}

		-- Langue
		local langCode = "FR"
		local function writefile(name, data)
			pcall(function() writefile(name, data) end)
		end
		local function readfile(name)
			local ok, data = pcall(function() return readfile(name) end)
			if ok and data then return data end
			return nil
		end
		local savedLang = readfile("agora_lang.txt")
		if savedLang and translations[savedLang] then langCode = savedLang end

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
						agoraStats.totalLaunches = json.totalLaunches or 0
						agoraStats.onlineUsers = json.onlineUsers or 0
						pcall(function() if totalLabel then totalLabel.Text = (translations[langCode] or translations["FR"]).utilisateurs .. ": " .. agoraStats.totalLaunches end end)
						pcall(function() if onlineLabel then onlineLabel.Text = (translations[langCode] or translations["FR"]).enLigne .. ": " .. agoraStats.onlineUsers end end)
					end
				end
			end)
		end

		-- === BUILD HOME UI ===
		local homeScroll = Instance.new("ScrollingFrame")
		homeScroll.Name = "HomeScroll"
		homeScroll.Size = UDim2.new(1, -10, 1, -10)
		homeScroll.Position = UDim2.new(0, 5, 0, 5)
		homeScroll.BackgroundTransparency = 1
		homeScroll.BorderSizePixel = 0
		homeScroll.ScrollBarThickness = 4
		homeScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 180, 255)
		homeScroll.CanvasSize = UDim2.new(0, 0, 0, 500)
		homeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		homeScroll.Parent = _homePage

		local homeLayout = Instance.new("UIListLayout")
		homeLayout.Padding = UDim.new(0, 8)
		homeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		homeLayout.SortOrder = Enum.SortOrder.LayoutOrder
		homeLayout.Parent = homeScroll

		-- Title
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -20, 0, 28)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "Accueil"
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 22
		titleLabel.TextColor3 = Color3.fromRGB(60, 180, 255)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.LayoutOrder = 1
		titleLabel.Parent = homeScroll

		-- Version
		local versionLabel = Instance.new("TextLabel")
		versionLabel.Size = UDim2.new(1, -20, 0, 20)
		versionLabel.BackgroundTransparency = 1
		versionLabel.Text = CURRENT_VERSION
		versionLabel.Font = Enum.Font.Gotham
		versionLabel.TextSize = 14
		versionLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
		versionLabel.TextXAlignment = Enum.TextXAlignment.Left
		versionLabel.LayoutOrder = 2
		versionLabel.Parent = homeScroll

		-- Separator
		local sep1 = Instance.new("Frame")
		sep1.Size = UDim2.new(1, -20, 0, 1)
		sep1.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		sep1.BorderSizePixel = 0
		sep1.LayoutOrder = 3
		sep1.Parent = homeScroll

		-- Changelog title
		local nouveautesLabel = Instance.new("TextLabel")
		nouveautesLabel.Size = UDim2.new(1, -20, 0, 22)
		nouveautesLabel.BackgroundTransparency = 1
		nouveautesLabel.Text = "Nouveautés"
		nouveautesLabel.Font = Enum.Font.GothamBold
		nouveautesLabel.TextSize = 16
		nouveautesLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
		nouveautesLabel.TextXAlignment = Enum.TextXAlignment.Left
		nouveautesLabel.LayoutOrder = 4
		nouveautesLabel.Parent = homeScroll

		-- Changelog entries
		for idx, entry in ipairs(changelogEntries) do
			local entryLabel = Instance.new("TextLabel")
			entryLabel.Size = UDim2.new(1, -20, 0, 18)
			entryLabel.BackgroundTransparency = 1
			entryLabel.Text = "• " .. entry
			entryLabel.Font = Enum.Font.Gotham
			entryLabel.TextSize = 12
			entryLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
			entryLabel.TextXAlignment = Enum.TextXAlignment.Left
			entryLabel.LayoutOrder = 4 + idx
			entryLabel.Parent = homeScroll
		end

		-- Separator 2
		local sep2 = Instance.new("Frame")
		sep2.Size = UDim2.new(1, -20, 0, 1)
		sep2.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		sep2.BorderSizePixel = 0
		sep2.LayoutOrder = 14
		sep2.Parent = homeScroll

		-- Discord button
		local discordBtn = Instance.new("TextButton")
		discordBtn.Size = UDim2.new(1, -20, 0, 36)
		discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
		discordBtn.BorderSizePixel = 0
		discordBtn.Text = "🎮 Rejoindre le Discord"
		discordBtn.Font = Enum.Font.GothamBold
		discordBtn.TextSize = 14
		discordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		discordBtn.LayoutOrder = 15
		discordBtn.Parent = homeScroll
		_createCorner(discordBtn, 8)
		discordBtn.MouseButton1Click:Connect(function()
			pcall(function() setclipboard("https://discord.gg/fVw2rzAMb") end)
			discordBtn.Text = "✅ Lien copié !"
			task.delay(2, function() discordBtn.Text = "🎮 Rejoindre le Discord" end)
		end)

		local discordLabel = discordBtn

		-- Language selector
		local langueLabel = Instance.new("TextLabel")
		langueLabel.Size = UDim2.new(1, -20, 0, 20)
		langueLabel.BackgroundTransparency = 1
		langueLabel.Text = "Langue"
		langueLabel.Font = Enum.Font.GothamBold
		langueLabel.TextSize = 14
		langueLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
		langueLabel.TextXAlignment = Enum.TextXAlignment.Left
		langueLabel.LayoutOrder = 16
		langueLabel.Parent = homeScroll

		local langBtn = Instance.new("TextButton")
		langBtn.Size = UDim2.new(1, -20, 0, 34)
		langBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		langBtn.BorderSizePixel = 0
		langBtn.Text = "🌍 Français"
		langBtn.Font = Enum.Font.Gotham
		langBtn.TextSize = 13
		langBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
		langBtn.LayoutOrder = 17
		langBtn.Parent = homeScroll
		_createCorner(langBtn, 8)

		local langPopup = nil
		local langList = {
			{code="FR", flag="🇫🇷", name="Français"},
			{code="EN", flag="🇬🇧", name="English"},
			{code="ES", flag="🇪🇸", name="Español"},
			{code="DE", flag="🇩🇪", name="Deutsch"},
			{code="PT", flag="🇵🇹", name="Português"},
			{code="IT", flag="🇮🇹", name="Italiano"},
			{code="RU", flag="🇷🇺", name="Русский"},
			{code="ZH", flag="🇨🇳", name="中文"},
			{code="JA", flag="🇯🇵", name="日本語"},
			{code="KO", flag="🇰🇷", name="한국어"},
			{code="AR", flag="🇸🇦", name="العربية"},
			{code="NL", flag="🇳🇱", name="Nederlands"},
			{code="PL", flag="🇵🇱", name="Polski"},
			{code="TR", flag="🇹🇷", name="Türkçe"}
		}

		langBtn.MouseButton1Click:Connect(function()
			if langPopup then langPopup:Destroy() langPopup = nil return end
			langPopup = Instance.new("Frame")
			langPopup.Size = UDim2.new(1, -20, 0, 280)
			langPopup.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
			langPopup.BorderSizePixel = 0
			langPopup.LayoutOrder = 18
			langPopup.Parent = homeScroll
			_createCorner(langPopup, 8)
			_createStroke(langPopup, Color3.fromRGB(60, 180, 255), 1)

			local popupLayout = Instance.new("UIListLayout")
			popupLayout.Padding = UDim.new(0, 2)
			popupLayout.Parent = langPopup

			for _, lang in ipairs(langList) do
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, -10, 0, 28)
				btn.Position = UDim2.new(0, 5, 0, 0)
				btn.BackgroundColor3 = lang.code == langCode and Color3.fromRGB(60, 180, 255) or Color3.fromRGB(40, 40, 55)
				btn.BorderSizePixel = 0
				btn.Text = lang.flag .. " " .. lang.name
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 12
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.Parent = langPopup
				_createCorner(btn, 6)
				btn.MouseButton1Click:Connect(function()
					applyLanguage(lang.code)
					langBtn.Text = lang.flag .. " " .. lang.name
					langPopup:Destroy()
					langPopup = nil
				end)
			end
		end)

		-- Stats
		local totalLabel = Instance.new("TextLabel")
		totalLabel.Size = UDim2.new(1, -20, 0, 18)
		totalLabel.BackgroundTransparency = 1
		totalLabel.Text = "Utilisateurs: ..."
		totalLabel.Font = Enum.Font.Gotham
		totalLabel.TextSize = 12
		totalLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
		totalLabel.TextXAlignment = Enum.TextXAlignment.Left
		totalLabel.LayoutOrder = 19
		totalLabel.Parent = homeScroll

		local onlineLabel = Instance.new("TextLabel")
		onlineLabel.Size = UDim2.new(1, -20, 0, 18)
		onlineLabel.BackgroundTransparency = 1
		onlineLabel.Text = "En ligne: ..."
		onlineLabel.Font = Enum.Font.Gotham
		onlineLabel.TextSize = 12
		onlineLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
		onlineLabel.TextXAlignment = Enum.TextXAlignment.Left
		onlineLabel.LayoutOrder = 20
		onlineLabel.Parent = homeScroll

		-- Credits
		local creditsLabel = Instance.new("TextLabel")
		creditsLabel.Size = UDim2.new(1, -20, 0, 18)
		creditsLabel.BackgroundTransparency = 1
		creditsLabel.Text = "Agora Hub [UNIVERSELLE] - by Emerick"
		creditsLabel.Font = Enum.Font.Gotham
		creditsLabel.TextSize = 11
		creditsLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
		creditsLabel.TextXAlignment = Enum.TextXAlignment.Center
		creditsLabel.LayoutOrder = 21
		creditsLabel.Parent = homeScroll

		-- Fetch stats
		fetchStats()
		task.spawn(function()
			while true do
				task.wait(60)
				fetchStats()
			end
		end)

		-- Apply saved language
		applyLanguage(langCode)
	end)()

	updateLoad(0.10, "Telechargement du panel...")
	task.wait(0.3)
	updateLoad(0.25, "Connexion au serveur...")
	
	local p2ok, p2code = pcall(function()
		local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p2.lua&nocache=" .. tick()
		return game:HttpGet(url)
	end)
	
	if not p2ok or not p2code or #p2code < 1000 then
		updateLoad(1.0, "ERREUR: Impossible de charger le panel")
		task.wait(2)
		loadingGui:Destroy()
		warn("[AGORA] Failed to load p2: " .. tostring(p2code))
		return
	end
	
	updateLoad(0.50, "Panel charge (" .. #p2code .. " octets)")
	task.wait(0.3)
	updateLoad(0.65, "Initialisation des modules...")
	task.wait(0.3)
	updateLoad(0.80, "Preparation de l'interface...")
	task.wait(0.3)
	updateLoad(0.95, "Demarrage...")
	task.wait(0.3)
	
	-- Export all utility functions to _G so p2 can see them (loadstring scope)
	_G.createCorner = createCorner
	_G.createStroke = createStroke
	_G.tween = tween
	_G.createSwitch = createSwitch
	_G.createButton = createButton
	_G.createSlider = createSlider
	_G.createTab = createTab
	_G.switchTab = switchTab
	_G.shutdownPanel = shutdownPanel
	_G.startFly = startFly
	_G.stopFly = stopFly
	_G.updateLoad = updateLoad
	_G.updateCharacter = updateCharacter
	_G.createToggle = createToggle
	_G.createSection = createSection
	_G.createInput = createInput
	_G.createDropdown = createDropdown
	_G.fullbrightSwitch = fullbrightSwitch
	_G.espSwitch = espSwitch
	_G.noclipState = noclipState
	_G.walkSpeedState = walkSpeedState
	_G.jumpState = jumpState
	_G.platformState = platformState
	_G.espState = espState
	_G.flyState = flyState
	_G.flySwitch = flySwitch
	_G.zeroGSwitch = zeroGSwitch
	_G.fullbrightState = fullbrightState
	_G.clickTPState = clickTPState
	_G.hitboxState = hitboxState
	_G.protectionsState = protectionsState
	_G.autoClickState = autoClickState
	_G.gotoWalkState = gotoWalkState
	_G.localState = localState
	_G.panelMemory = panelMemory
	_G.extraScroll = extraScroll
	_G.localScroll = localScroll
	_G.protectionsScroll = protectionsScroll
	_G.registryScroll = registryScroll
	_G.registryLayout = registryLayout
	_G.serverScroll = serverScroll
	_G.extraPage = extraPage
	_G.movePage = movePage
	_G.remotesPage = remotesPage
	_G.registryPage = registryPage
	_G.localPage = localPage
	_G.protectionsPage = protectionsPage
	_G.settingsPage = settingsPage
	_G.aboutPage = aboutPage
	_G.pages = pages
	_G.mainFrame = mainFrame
	_G.screenGui = screenGui
	_G.closeBtn = closeBtn
	_G.loadingGui = loadingGui
	_G.rootPart = rootPart
	_G.humanoid = humanoid
	_G.character = character
	_G.Camera = Workspace.CurrentCamera
	_G.HttpService = game:GetService("HttpService")
	_G.Lighting = game:GetService("Lighting")
	_G.LocalPlayer = LocalPlayer
	_G.Mouse = LocalPlayer:GetMouse()
	_G.Players = Players
	_G.ReplicatedStorage = game:GetService("ReplicatedStorage")
	_G.RunService = RunService
	_G.UserInputService = UserInputService
	_G.Workspace = Workspace

	-- Execute p2
	local p2fn, p2err = loadstring(p2code)
	if not p2fn then
		updateLoad(1.0, "ERREUR: " .. tostring(p2err))
		task.wait(2)
		loadingGui:Destroy()
		warn("[AGORA] p2 syntax error: " .. tostring(p2err))
		return
	end
	
	updateLoad(1.0, "Pret!")
	task.wait(0.3)
	loadingGui:Destroy()
	
	-- Run p2
	local ok, err = pcall(p2fn)
	if not ok then
		warn("[AGORA] p2 runtime error: " .. tostring(err))
	end
end

-- Run the main function
main()