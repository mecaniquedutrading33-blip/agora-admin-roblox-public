
-- ============= MOVE =============
local flyState = { flying = false, speed = 120, gyro = nil, vel = nil, loop = nil, mobileInput = Vector3.zero, mobileUp = false, mobileDown = false, mobileStickId = nil, mobileBase = nil, mobileKnob = nil, mobileBasePos = nil, mobileUiCreated = false }
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
	flyState.mobileInput = Vector3.zero
	flyState.mobileUpHeld = false
	flyState.mobileDownHeld = false
	flyState.mobileStickId = nil
	if flyState.showMobileUi then flyState.showMobileUi(false) end
	_G._aupdateCharacter()
	if humanoid then humanoid.PlatformStand = false end
	flySwitch.set(false)
	-- Active la grâce anti-TP pour réinitialiser la baseline sans bounce
	if protectionsState then
		protectionsState.antiTeleportGraceUntil = tick() + 0.4
	end
end

-- ============= FLY MOBILE JOYSTICK (auto-show on touch devices) =============
;(function(_fly, _screenGui)
	local function isMobile()
		return _G._aUserInputService.TouchEnabled and not _G._aUserInputService.KeyboardEnabled
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
		upBtn.Text = "▲"
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
		dnBtn.Text = "▼"
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
	_G._aUserInputService.InputChanged:Connect(function(input, gpe)
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

local function startFly()
	_G._aupdateCharacter()
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

	-- Show mobile UI on touch devices
	if flyState.isMobile and flyState.isMobile() and flyState.showMobileUi then
		flyState.showMobileUi(true)
	end

	flyState.loop = _G._aRunService.RenderStepped:Connect(function()
		_G._aupdateCharacter()
		if not flyState.flying or not rootPart or not rootPart.Parent then return end
		-- Re-attach body movers if rootPart changed (respawn)
		if flyState.gyro and flyState.gyro.Parent ~= rootPart then flyState.gyro.Parent = rootPart end
		if flyState.vel and flyState.vel.Parent ~= rootPart then flyState.vel.Parent = rootPart end
		if flyState.gyro then flyState.gyro.CFrame = _G._aCamera.CFrame end

		local move = Vector3.zero
		-- PC controls (clavier)
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.W) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.Z) then move += _G._aCamera.CFrame.LookVector end
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.S) then move -= _G._aCamera.CFrame.LookVector end
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.A) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= _G._aCamera.CFrame.RightVector end
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.D) then move += _G._aCamera.CFrame.RightVector end
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
		-- Mobile controls (joystick + boutons)
		if flyState.mobileInput and flyState.mobileInput.Magnitude > 0 then
			move += _G._aCamera.CFrame.LookVector * flyState.mobileInput.Z + _G._aCamera.CFrame.RightVector * flyState.mobileInput.X
		end
		if flyState.mobileUpHeld then move += Vector3.new(0, 1, 0) end
		if flyState.mobileDownHeld then move -= Vector3.new(0, 1, 0) end

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
	_G._acreateCorner(container, 8)
	_G._acreateStroke(container, Color3.fromRGB(45, 45, 55), 1)

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
	_G._acreateCorner(track, 3)

	-- Bouton invisible par-dessus le track pour capter TOUS les clics (sinon certains
	-- clics sur le container parent sont perdus → le slider "marche mal")
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
	_G._acreateCorner(fill, 3)

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
	-- Hit invisible capte les clics n'importe où sur la zone (Y=21..45), pas seulement le track (6px)
	hitButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			setFromInput(input.Position.X)
		end
	end)
	_G._aUserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end)
	_G._aUserInputService.InputChanged:Connect(function(input)
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

local flySwitch = _G._acreateSwitch(_G._amovePage, "Fly", 10, function(on)
	if on then startFly() else stopFly() end
end)

local flySlider = createSlider(_G._amovePage, "Vitesse Fly", 52, 20, 500, flyState.speed, function(v)
	flyState.speed = math.floor(v)
end, Color3.fromRGB(100, 180, 255))

local noclipSwitch = _G._acreateSwitch(_G._amovePage, "NoClip", 108, function(on)
	noclipState.enabled = on
	if not on then
		_G._aupdateCharacter()
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = true end
			end
		end
		-- Active la grâce anti-TP après sortie du noclip
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
			seg.Color = Color3.fromRGB(200, 200, 255)
			seg.Parent = Workspace
			table.insert(gotoWalkState.visuals, seg)
		end
	end
end

-- Calcule un trajet vers targetPos. Retourne une liste de waypoints (Vector3) ou {} si impossible.
local function computePathTo(targetPos)
	_G._aupdateCharacter()
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
		local hit = _G._aWorkspace:Raycast(from, dir.Unit * dist, params)
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
			local hit = _G._aWorkspace:Raycast(origin, dir * (dist + 1), params)
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
			local ground = _G._aWorkspace:Raycast(segTarget + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), gParams)
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
			local ground = _G._aWorkspace:Raycast(targetPos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), gParams)
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
		local ground = _G._aWorkspace:Raycast(step + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), gParams)
		if ground then step = Vector3.new(step.X, ground.Position.Y + 2, step.Z) end
		return { step }
	end
	return {}
endlocal gotoWalkSwitch = _G._acreateSwitch(_G._amovePage, "Go to Walk (click sol)", 150, function(on)
	gotoWalkState.enabled = on
	if not on then
		gotoWalkState.active = false
		gotoWalkState.target = nil
		gotoWalkState.path = {}
		clearWalkVisuals()
	end
end)

_G._acreateSwitch(_G._amovePage, "Saut infini", 192, function(on)
	jumpState.infinite = on
end)

local function refreshNoClipSwitch()
	noclipSwitch.set(false)
end

local walkSlider = createSlider(_G._amovePage, "Vitesse marche", 234, 1, 250, 16, function(v)
	walkSpeedState.value = math.floor(v)
	_G._aupdateCharacter()
	if humanoid then humanoid.WalkSpeed = walkSpeedState.value end
end, Color3.fromRGB(255, 100, 100))

local walkResetBtn = _G._acreateButton(_G._amovePage, "Reset vitesse", 288, Color3.fromRGB(80, 80, 90), function()
	walkSpeedState.value = 16
	walkSlider.set(16)
	_G._aupdateCharacter()
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
	normalGravity = _G._aWorkspace.Gravity,
	customGravity = 196.2,
	timeOfDay = 12,
}

local zeroGSwitch = _G._acreateSwitch(_G._alocalPage, "Zero Gravité", 10, function(on)
	localState.zeroGravity = on
	if on then
		_G._aWorkspace.Gravity = 0
	else
		_G._aWorkspace.Gravity = localState.customGravity
	end

	local character = _G._aLocalPlayer.Character
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
;(function()
local gravityContainer = Instance.new("Frame")
gravityContainer.Size = UDim2.new(1, -16, 0, 86)
gravityContainer.Position = UDim2.new(0, 8, 0, 56)
gravityContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
gravityContainer.BorderSizePixel = 0
gravityContainer.Parent = localPage
_G._acreateCorner(gravityContainer, 10)
_G._acreateStroke(gravityContainer, Color3.fromRGB(45, 45, 55), 1)

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
_G._acreateCorner(gravityTrack, 3)

local gravityFill = Instance.new("Frame")
gravityFill.Size = UDim2.new(196.2 / 300, 0, 1, 0)
gravityFill.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
gravityFill.BorderSizePixel = 0
gravityFill.Parent = gravityTrack
_G._acreateCorner(gravityFill, 3)

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
_G._acreateCorner(gravityInput, 6)
_G._acreateStroke(gravityInput, Color3.fromRGB(80, 80, 100), 1)

	_G._agoraSetGravityExact = function(v)
	v = tonumber(v)
	if not v then return end
	v = math.clamp(math.floor(v + 0.5), 0, 300)
	localState.customGravity = v
	_G._aWorkspace.Gravity = v
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
		_G._agoraSetGravityExact(gravityFromX(input.Position.X))
	end
end)
_G._aUserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingGravity = false
	end
end)
_G._aUserInputService.InputChanged:Connect(function(input)
	if draggingGravity and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		_G._agoraSetGravityExact(gravityFromX(input.Position.X))
	end
end)

gravityInput.FocusLost:Connect(function(enterPressed)
	_G._agoraSetGravityExact(gravityInput.Text)
end)

local resetGravityBtn = _G._acreateButton(_G._alocalPage, "Reset gravité normale", 148, Color3.fromRGB(80, 80, 90), function()
	_G._agoraSetGravityExact(196.2)
end)
resetGravityBtn.Size = UDim2.new(1, -16, 0, 30)
resetGravityBtn.Position = UDim2.new(0, 8, 0, 148)
end)()

local timeSwitch = _G._acreateSwitch(_G._alocalPage, "Temps custom", 200, function(on)
	if on then
		_G._aLighting.TimeOfDay = string.format("%02d:00:00", localState.timeOfDay)
	else
		_G._aLighting.TimeOfDay = "12:00:00"
	end
end)

createSlider(_G._alocalPage, "Heure du jour", 246, 0, 24, 12, function(v)
	localState.timeOfDay = math.floor(v)
	_G._aLighting.TimeOfDay = string.format("%02d:00:00", localState.timeOfDay)
end, Color3.fromRGB(255, 180, 60))

_G._acreateSwitch(_G._alocalPage, "Freeze temps", 292, function(on)
	if on then
		_G._aLighting.ClockTime = localState.timeOfDay
	end
end)

_G._acreateButton(_G._alocalPage, "Reset monde", 348, Color3.fromRGB(80, 80, 90), function()
	_G._aWorkspace.Gravity = localState.normalGravity
	_G._aLighting.TimeOfDay = "12:00:00"
	zeroGSwitch.set(false)
	localState.customGravity = 196.2
	_G._agoraSetGravityExact(196.2)
	localState.timeOfDay = 12
end)

-- Switch ESP Global dans l'onglet Local
local globalESPEnabled = false
local globalESPSwitch = _G._acreateSwitch(_G._alocalPage, "ESP Global", 404, function(on)
	globalESPEnabled = on
	_G._aespState.enabled = on
	if on then
		_G._arefreshESP()
	else
		_G._aclearESP()
	end
end)

-- Toggle icônes chat sur l'ESP
local chatIconsSwitch = _G._acreateSwitch(_G._alocalPage, "Icônes chat ESP", 448, function(on)
	_G._aespState.chatIcons = on
end)
chatIconsSwitch.set(true)


_G._aupdateLoad(0.40, "Auto Clicker...")
task.wait(0.05)
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
	_G._apanelMemory.autoClick = {
		pos = autoClickState.controlPos and {autoClickState.controlPos.X.Scale, autoClickState.controlPos.X.Offset, autoClickState.controlPos.Y.Scale, autoClickState.controlPos.Y.Offset},
		speed = autoClickState.speed,
	}
	if acTarget and acTarget.targetType then
		_G._apanelMemory.autoClick.targetType = acTarget.targetType
	end
end

local function removeFakeTool()
	if autoClickState.fakeTool and autoClickState.fakeTool.Parent then
		autoClickState.fakeTool:Destroy()
	end
	autoClickState.fakeTool = nil
end

local function createFakeTool()
	local backpack = _G._aLocalPlayer:FindFirstChild("Backpack")
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

local function stopAutoClickEngine()
	autoClickState.clickEnabled = false
	if autoClickState.activeThread then
		autoClickState.activeThread = nil
	end
	destroyAutoClickMarker()
	statusLabel.Text = "Statut : arret"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	pcall(hideMarker)
end

local function onToolDeactivated()
	-- quand le tool est retiré de l'inventaire / personnage mort
	stopAutoClickEngine()
end

local VirtualInputManager
pcall(function()
	VirtualInputManager = (getvirtualinputmanager and getvirtualinputmanager()) or game:GetService("VirtualInputManager")
end)

-- Position FIXE capturée quand l'utilisateur clique "Démarrer AutoClick".
-- C'est cette position qu'on réutilise à chaque tick (le curseur peut bouger).
local acTarget = {
	captured = false,
	position = Vector2.new(0, 0),   -- position écran
	worldHit = nil,                 -- _G._aMouse.Hit sous le curseur à la capture
	worldTarget = nil,              -- l'instance Part/GUI sous le curseur à la capture
	targetType = "any",             -- "any" | "world" | "gui"
	markerPart = nil                -- Part 3D visuelle au worldHit.Position (marker dans la map)
}

-- Fonctions marker autoclick: définies inline ci-dessous
;(function()
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
	local mouse = _G._aLocalPlayer:Get_G._aMouse()
	if not mouse then return false end
	acTarget.captured = true
	acTarget.position = _G._aUserInputService:GetMouseLocation()
	acTarget.worldHit = mouse.Hit
	acTarget.worldTarget = mouse.Target
	refreshAutoClickMarker()
	return true
end

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
	local camera = _G._aWorkspace.CurrentCamera
	if not camera then return nil end
	local unit = camera:ScreenPointToRay(point.X, point.Y)
	local hit = _G._aWorkspace:Raycast(unit.Origin, unit.Direction * 1000)
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
		local playerGui = _G._aLocalPlayer:FindFirstChild("PlayerGui")
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
_G._acreateCorner(autoClickContainer, 10)
_G._acreateStroke(autoClickContainer, Color3.fromRGB(45, 45, 55), 1)

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
_G._acreateCorner(acMarker, 7)

local acMarkerStroke = Instance.new("UIStroke")
acMarkerStroke.Color = Color3.fromRGB(255, 200, 200)
acMarkerStroke.Thickness = 1.5
acMarkerStroke.Parent = acMarker

local function showMarkerAt(screenPos)
	acMarker.Visible = true
	acMarker.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
end
local function hideMarker()
	acMarker.Visible = false
end

local _origCapture = captureTargetFromCursor
captureTargetFromCursor = function()
	local ok = _origCapture()
	if ok then showMarkerAt(acTarget.position) end
	return ok
end

-- Switch : active/désactive UNIQUEMENT le faux tool dans le backpack
local autoClickSwitch = _G._acreateSwitch(autoClickContainer, "Activer (touche G) - ouvre mini panel", 56, function(on)
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
_G._aUserInputService.InputBegan:Connect(function(input, gpe)
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
	_G._acreateCorner(btn, 6)
	modeBtns[m] = btn
	btn.MouseButton1Click:Connect(function()
		acTarget.targetType = m
		for _, b in pairs(modeBtns) do _G._atween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		_G._atween(btn, {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
	end)
end
_G._atween(modeBtns["any"], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0)

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
_G._acreateCorner(speedSliderTrack, 3)

local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.new(0.5, 0, 1, 0)
speedFill.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
speedFill.BorderSizePixel = 0
speedFill.Parent = speedSliderTrack
_G._acreateCorner(speedFill, 3)

local draggingSpeed = false
local function speedFromX(x)
	local rel = math.clamp((x - speedSliderTrack.AbsolutePosition.X) / speedSliderTrack.AbsoluteSize.X, 0, 1)
	return 0.001 + rel * 0.199
end
local function setSpeed(s)
	s = math.clamp(math.floor(s * 1000) / 1000, 0.001, 0.2)
	autoClickState.speed = s
	speedLabel.Text = "Vitesse : " .. s .. "s"
	speedFill.Size = UDim2.new((s - 0.001) / 0.199, 0, 1, 0)
	if autoClickState.clickEnabled then startAutoClickEngine() end
	setAutoClickSave()
end
setSpeed(0.05)

speedSliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSpeed = true
		setSpeed(speedFromX(input.Position.X))
	end
end)
_G._aUserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingSpeed = false
	end
end)
_G._aUserInputService.InputChanged:Connect(function(input)
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
_G._acreateCorner(clickControl, 12)
_G._acreateStroke(clickControl, Color3.fromRGB(80, 80, 100), 1)

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
-- Listener global sur _G._aUserInputService pour que le drag suive la souris même hors du header
local ccDragging, ccDragStart, ccStartPos = false, nil, nil
controlHeader.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		ccDragging = true
		ccDragStart = input.Position
		ccStartPos = clickControl.Position
	end
end)
_G._aUserInputService.InputChanged:Connect(function(input)
	if ccDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		if ccStartPos and ccDragStart then
			local dx = input.Position.X - ccDragStart.X
			local dy = input.Position.Y - ccDragStart.Y
			clickControl.Position = UDim2.new(ccStartPos.X.Scale, ccStartPos.X.Offset + dx, ccStartPos.Y.Scale, ccStartPos.Y.Offset + dy)
		end
	end
end)
_G._aUserInputService.InputEnded:Connect(function(input)
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
_G._acreateCorner(execBtn, 6)
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
_G._acreateCorner(multiBtn, 6)
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
_G._acreateCorner(toggleClickBtn, 6)
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
_G._acreateCorner(dragHandle, 11)

local function clampControl()
	local s = _G._ascreenGui.AbsoluteSize
	local sz = clickControl.AbsoluteSize
	local x = math.clamp(clickControl.AbsolutePosition.X, 0, math.max(0, s.X - sz.X))
	local y = math.clamp(clickControl.AbsolutePosition.Y, 0, math.max(0, s.Y - sz.Y))
	clickControl.Position = UDim2.new(0, x, 0, y)
end

clickControl:GetPropertyChangedSignal("Position"):Connect(function()
	task.defer(clampControl)
end)

local controlToggle = _G._acreateButton(autoClickContainer, "Afficher/Cacher panneau", 198, Color3.fromRGB(80, 60, 160), function()
	clickControl.Visible = not clickControl.Visible
end)
controlToggle.Size = UDim2.new(1, -16, 0, 28)
controlToggle.Position = UDim2.new(0, 8, 0, 226)

-- Restaurer sauvegarde
if _G._apanelMemory.autoClick and _G._apanelMemory.autoClick.pos then
	local p = _G._apanelMemory.autoClick.pos
	clickControl.Position = UDim2.new(p[1], p[2], p[3], p[4])
end
if _G._apanelMemory.autoClick and _G._apanelMemory.autoClick.speed then
	setSpeed(_G._apanelMemory.autoClick.speed)
end
if _G._apanelMemory.autoClick and _G._apanelMemory.autoClick.targetType then
	local saved = _G._apanelMemory.autoClick.targetType
	if modes[saved] then
		acTarget.targetType = saved
		for _, b in pairs(modeBtns) do _G._atween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		_G._atween(modeBtns[saved], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
	end
elseif _G._apanelMemory.autoClick and _G._apanelMemory.autoClick.mode then
	local saved = _G._apanelMemory.autoClick.mode
	if saved == "rapid" or saved == "auto" then saved = "any" end
	if modes[saved] then
		acTarget.targetType = saved
		for _, b in pairs(modeBtns) do _G._atween(b, {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}, 0.1) end
		_G._atween(modeBtns[saved], {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}, 0.1)
	end
end

clickControl:GetPropertyChangedSignal("Position"):Connect(function()
	autoClickState.controlPos = clickControl.Position
	setAutoClickSave()
end)
-- Déplace tous les contrôles locaux dans la scrollview
_G._areparentChildrenToLocalScroll()

-- Agrandit le scroll pour accueillir l'autoclicker
_G._alocalScroll.CanvasSize = UDim2.new(0, 0, 0, 900)

-- Empêche le panel d'être poussé sous le chat au démarrage
task.delay(0, function()
	local function clampFrame()
		local abs = _G._amainFrame.AbsoluteSize
		local scr = _G._ascreenGui.AbsoluteSize
		local x = math.clamp(_G._amainFrame.AbsolutePosition.X, 0, math.max(0, scr.X - abs.X))
		local y = math.clamp(_G._amainFrame.AbsolutePosition.Y, 0, math.max(0, scr.Y - abs.Y))
		_G._amainFrame.Position = UDim2.new(0, x, 0, y)
	end
	clampFrame()
	task.wait(0.1)
	clampFrame()
end)

_G._aRunService.RenderStepped:Connect(function()
	if localState.zeroGravity then
		local char = _G._aLocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local cam = _G._aWorkspace.CurrentCamera
		if hrp and _G._aUserInputService:IsKeyDown(Enum.KeyCode.W) then
			hrp.AssemblyLinearVelocity = cam.CFrame.LookVector * 16
		end
	end
end)

_G._aUserInputService.JumpRequest:Connect(function()
	if jumpState.infinite and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

_G._aUserInputService.InputBegan:Connect(function(input, gpe)
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

_G._aRunService.Stepped:Connect(function(_, dt)
	_G._aupdateCharacter()
	if noclipState.enabled and character then
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
	if platformState.enabled and platformState.part then
		-- Plate FIXE en X/Z : on ne tracke plus la position, on ajuste juste la hauteur
		-- avec les touches +/-
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.Equals) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.KeypadPlus) then
			platformState.offset += 25 * dt
		end
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.Minus) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.KeypadMinus) then
			platformState.offset -= 25 * dt
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
			local topHit = _G._aWorkspace:Raycast(pos, Vector3.new(0, height, 0), params)
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
			local leftHit = _G._aWorkspace:Raycast(pos, Vector3.new(-width/2, 0, 0), params)
			local rightHit = _G._aWorkspace:Raycast(pos, Vector3.new(width/2, 0, 0), params)
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
		local frontRay = _G._aWorkspace:Raycast(myPos, rootPart.CFrame.LookVector * 4, frontParams)
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
	_G._aRunService.RenderStepped:Connect(function()
		pcall(function()
			local char = _G._aLocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and not flyState.flying then
				local target = walkSpeedState.value
				if math.abs(hum.WalkSpeed - target) > 0.5 then
					hum.WalkSpeed = target
				end
			end
		end)
	end)


_G._aupdateLoad(0.50, "Modules extra...")
task.wait(0.05)
_G._acaptureTargetFromCursor=captureTargetFromCursor
_G._aclampControl=clampControl
_G._aclearWalkVisuals=clearWalkVisuals
_G._acomputePathTo=computePathTo
_G._acreateFakeTool=createFakeTool
_G._acreateSlider=createSlider
_G._afindClickDetectorAtScreen=findClickDetectorAtScreen
_G._afindGuiButtonAt=findGuiButtonAt
_G._afireClickFixed=fireClickFixed
_G._agravityFromX=gravityFromX
_G._ahideMarker=hideMarker
_G._aonToolDeactivated=onToolDeactivated
_G._arefreshNoClipSwitch=refreshNoClipSwitch
_G._aremoveFakeTool=removeFakeTool
_G._asetAutoClickSave=setAutoClickSave
_G._asetSpeed=setSpeed
_G._ashowMarkerAt=showMarkerAt
_G._aspeedFromX=speedFromX
_G._astartAutoClickEngine=startAutoClickEngine
_G._astartFly=startFly
_G._astopAutoClickEngine=stopAutoClickEngine
_G._astopFly=stopFly
_G._avisualizeWaypoints=visualizeWaypoints
_G._aPathfindingService=PathfindingService
_G._a_origCapture=_origCapture
_G._aacMarker=acMarker
_G._aacMarkerStroke=acMarkerStroke
_G._aacTarget=acTarget
_G._aautoClickContainer=autoClickContainer
_G._aautoClickState=autoClickState
_G._aautoClickSwitch=autoClickSwitch
_G._aautoClickTitle=autoClickTitle
_G._achatIconsSwitch=chatIconsSwitch
_G._aclickControl=clickControl
_G._acloseControlBtn=closeControlBtn
_G._acontrolHeader=controlHeader
_G._acontrolToggle=controlToggle
_G._adragHandle=dragHandle
_G._adraggingGravity=draggingGravity
_G._adraggingSpeed=draggingSpeed
_G._aexecBtn=execBtn
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
_G._alocalState=localState
_G._amodeBtns=modeBtns
_G._amodeFrame=modeFrame
_G._amodeOrder=modeOrder
_G._amodes=modes
_G._amultiBtn=multiBtn
_G._anoclipState=noclipState
_G._anoclipSwitch=noclipSwitch
_G._aplatformLabel=platformLabel
_G._aplatformState=platformState
_G._aresetGravityBtn=resetGravityBtn
_G._aspeedFill=speedFill
_G._aspeedLabel=speedLabel
_G._aspeedSliderTrack=speedSliderTrack
_G._astatusLabel=statusLabel
_G._atimeSwitch=timeSwitch
_G._atoggleClickBtn=toggleClickBtn
_G._awalkResetBtn=walkResetBtn
_G._awalkSlider=walkSlider
_G._awalkSpeedState=walkSpeedState
_G._azeroGSwitch=zeroGSwitch
_G._aP2Done=true
