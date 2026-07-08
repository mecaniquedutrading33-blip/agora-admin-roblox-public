
-- ============= EXTRA =============
local fullbrightState = { enabled = false, old = {} }
local clickTPState = { enabled = false }
local hitboxState = { enabled = false }

-- FIX: _G._aextraPage overflow (17+ items Y=10..730 > panel height 520px). Wrap in ScrollingFrame.
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
	_G._acreateCorner(statsCard, 8)
	_G._acreateStroke(statsCard, Color3.fromRGB(80, 80, 120), 1)

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
		_G._acreateCorner(cell, 6)

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
		_G._aRunService.RenderStepped:Connect(function()
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
				stat_G._aPlayers.Text = tostring(#_G._aPlayers:Get_G._aPlayers()) .. "/" .. tostring(_G._aPlayers.MaxPlayers)
				statFPS.Text = tostring(math.floor(_fps))
				local ping = _G._aLocalPlayer:GetNetworkPing() * 1000
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
	_G._acreateCorner(serverInfoCard, 8)
	_G._acreateStroke(serverInfoCard, Color3.fromRGB(80, 80, 120), 1)

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
	_G._acreateCorner(aimbotCard, 8)
	_G._acreateStroke(aimbotCard, Color3.fromRGB(180, 80, 80), 1)

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
	local mainSwitch = _G._acreateSwitch(mainSwitchRow, "", 0, function(on)
		aimbotEnabled = on
		_G._agoraAimbotEnabled = on
	end)
	mainSwitch.Size = UDim2.new(0.3, -4, 0.85, 0)
	mainSwitch.Position = UDim2.new(0.7, 4, 0.075, 0)
	mainSwitch.set(_G._agoraAimbotEnabled)

	-- Toggle auto-clic
	_G._agoraAimbotAutoClick = _G._agoraAimbotAutoClick or false
	local clickSwitch = _G._acreateSwitch(clickSwitchRow, "", 0, function(on)
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
	_G._acreateCorner(distSlider, 4)
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
	local localPlayer = _G._aPlayers.LocalPlayer
	local lastClickTick = 0
	local renderConn = _G._aRunService.RenderStepped:Connect(function()
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
		for _, plr in ipairs(_G._aPlayers:Get_G._aPlayers()) do
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

local fullbrightSwitch = _G._acreateSwitch(extraScroll, "Fullbright", 0, function(on)
	fullbrightState.enabled = on
	if on then
		fullbrightState.old.ambient = _G._aLighting.Ambient
		fullbrightState.old.outdoor = _G._aLighting.OutdoorAmbient
		fullbrightState.old.brightness = _G._aLighting.Brightness
		fullbrightState.old.time = _G._aLighting.ClockTime
		_G._aLighting.Ambient = Color3.new(1, 1, 1)
		_G._aLighting.OutdoorAmbient = Color3.new(1, 1, 1)
		_G._aLighting.Brightness = 2
		_G._aLighting.ClockTime = 14
	else
		_G._aLighting.Ambient = fullbrightState.old.ambient or _G._aLighting.Ambient
		_G._aLighting.OutdoorAmbient = fullbrightState.old.outdoor or _G._aLighting.OutdoorAmbient
		_G._aLighting.Brightness = fullbrightState.old.brightness or _G._aLighting.Brightness
		_G._aLighting.ClockTime = fullbrightState.old.time or _G._aLighting.ClockTime
	end
end)

local clickTPSwitch = _G._acreateSwitch(extraScroll, "Click TP (Ctrl+clic)", 0, function(on)
	clickTPState.enabled = on
end)

local hitboxSwitch = _G._acreateSwitch(extraScroll, "Hitbox expander", 0, function(on)
	hitboxState.enabled = on
	if not on then
		for _, plr in ipairs(_G._aPlayers:Get_G._aPlayers()) do
			if plr ~= _G._aLocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = plr.Character.HumanoidRootPart
				hrp.Size = Vector3.new(2, 2, 1)
				hrp.Transparency = 1
				hrp.Color = Color3.fromRGB(255, 255, 255)
				hrp.CanCollide = false
			end
		end
	end
end)

_G._acreateButton(extraScroll, "Obtenir Ghost V4", 0, Color3.fromRGB(110, 60, 160), function()
	giveGhostTool()
end)
_G._acreateButton(extraScroll, "Obtenir Eleven Master", 0, Color3.fromRGB(60, 120, 160), function()
	giveElevenTool()
end)
_G._acreateButton(extraScroll, "Obtenir Spider Tool", 0, Color3.fromRGB(60, 160, 90), function()
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
_G._acreateSwitch(extraScroll, "FPS Boost (qualité↓)", 0, function(on)
	fpsBoostState.enabled = on
	if on then
		fpsBoostState.saved = {
			quality = UserSettings().GameSettings.SavedQualityLevel,
			meshDetail = _G._aWorkspace.StreamingMinRadius,
			partCap = _G._aWorkspace.PartMaterialOptions and 0 or 0,
		}
		pcall(function() UserSettings().GameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		pcall(function() _G._aLighting.GlobalShadows = false end)
		pcall(function() _G._aLighting.FogEnd = 9e9 end)
		pcall(function() _G._aLighting.Technology = Enum.Technology.Compatibility end)
	else
		pcall(function() UserSettings().GameSettings.SavedQualityLevel = fpsBoostState.saved.quality or Enum.SavedQualitySetting.Automatic end)
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
		pcall(function() _G._aLighting.GlobalShadows = true end)
	end
end)

local antiVoidState = { enabled = false }
_G._acreateSwitch(extraScroll, "Anti-Void (y<-2000)", 0, function(on)
	antiVoidState.enabled = on
end)

-- Rejoin le même serveur (universel)
_G._acreateButton(extraScroll, "Rejoindre ce serveur", 0, Color3.fromRGB(70, 130, 200), function()
	pcall(function()
		local TeleportService = game:GetService("TeleportService")
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end)

-- Bouton panique : ferme tout d'un coup (Shift+P)
local panicEnabled = false
_G._acreateSwitch(extraScroll, "Bouton panique (Shift+P)", 0, function(on)
	panicEnabled = on
end)

_G._aUserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	-- Bouton panique : Shift+P = fermeture instantanée et indétectable
	if panicEnabled and input.KeyCode == Enum.KeyCode.P
		and (_G._aUserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		pcall(_G._ashutdownPanel)
		if _G._ascreenGui then _G._ascreenGui:Destroy() end
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and clickTPState.enabled then
		if _G._aUserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or _G._aUserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			_G._aupdateCharacter()
			if _G._aMouse.Hit and rootPart then
				rootPart.CFrame = _G._aMouse.Hit + Vector3.new(0, 3, 0)
			end
		end
	end

	-- Go to Walk : click sol = calcul d'itinéraire et marche auto
	if input.UserInputType == Enum.UserInputType.MouseButton1 and _G._agotoWalkState.enabled then
		local now = tick()
		if now - _G._agotoWalkState.lastClick < 0.25 then return end
		_G._agotoWalkState.lastClick = now

		if _G._agotoWalkState.busy then return end
		_G._agotoWalkState.busy = true
		task.spawn(function()
			local ok, err = pcall(function()
				_G._aupdateCharacter()
				if not _G._aMouse or not _G._aMouse.Hit then return end
				local targetPos = _G._aMouse.Hit.Position + Vector3.new(0, 3, 0)
				_G._agotoWalkState.target = targetPos
				local waypoints = _G._acomputePathTo(targetPos)
				_G._agotoWalkState.path = waypoints
				_G._agotoWalkState.active = #waypoints > 0
				if #waypoints > 0 and humanoid then
					humanoid:MoveTo(waypoints[1])
					_G._agotoWalkState.lastMoveTo = tick()
				end
				_G._avisualizeWaypoints(waypoints)
			end)
			if not ok and err then
				warn("[GoToWalk] " .. tostring(err))
			end
			_G._agotoWalkState.busy = false
		end)
	end
end)

task.spawn(function()
	while task.wait(0.4) do
		if hitboxState.enabled then
			for _, plr in ipairs(_G._aPlayers:Get_G._aPlayers()) do
				if plr ~= _G._aLocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
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

_G._aLocalPlayer.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		if not protectionsState.antiKill then return end
		_G._aupdateCharacter()
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
end

local function restoreSeat(seat)
	if not seat then return end
	if (seat:IsA("Seat") or seat:IsA("VehicleSeat")) and seat:GetAttribute("Neutralized") then
		seat.Disabled = false
		seat.CanTouch = true
		seat:SetAttribute("Neutralized", nil)
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
		char.AncestryChanged:Connect(function()
			if con then con:Disconnect() end
		end)
	end
	if _G._aLocalPlayer.Character then
		task.spawn(onCharacter, _G._aLocalPlayer.Character)
	end
	return _G._aLocalPlayer.CharacterAdded:Connect(onCharacter)
end

local function createProtectionSwitch(name, label, y)
	return _G._acreateSwitch(_G._aprotectionsScroll, label, y, function(on)
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
				for _, obj in ipairs(_G._aWorkspace:GetDescendants()) do
					neutralizeSeat(obj)
				end
				protectionsState.antiSeatWatcher = _G._aWorkspace.DescendantAdded:Connect(function(obj)
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
				for _, obj in ipairs(_G._aWorkspace:GetDescendants()) do
					restoreSeat(obj)
				end
			end
		end
		if name == "antiTeleport" and on then
			_G._aupdateCharacter()
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

_G._aRunService.Heartbeat:Connect(function()
	_G._aupdateCharacter()
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
		return _G._aflyState.flying or _G._anoclipState.enabled
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
				_G._aupdateCharacter()
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

_G._aLighting:GetPropertyChangedSignal("Ambient"):Connect(function()
	if fullbrightState.enabled then
		_G._aLighting.Ambient = Color3.new(1, 1, 1)
		_G._aLighting.OutdoorAmbient = Color3.new(1, 1, 1)
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
_G._acreateCorner(serverScroll, 4)

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
	_G._acreateCorner(remoteWarn, 6)
	_G._acreateStroke(remoteWarn, Color3.fromRGB(220, 80, 80), 1.5)

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
			end
		end
		pcall(function()
			for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do addRemote(obj) end
		end)
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do addRemote(obj) end
		end)
		pcall(function()
			for _, obj in ipairs(game._G._aPlayers._G._aLocalPlayer:GetDescendants()) do addRemote(obj) end
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
	_G._acreateCorner(remoteHeader, 4)

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
	_G._acreateCorner(refreshRemotesBtn, 4)

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
	_G._acreateCorner(remotesSearchBox, 6)
	_G._acreateStroke(remotesSearchBox, Color3.fromRGB(60, 60, 80), 1)

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
	_G._acreateCorner(card, 6)
	_G._acreateStroke(card, isFunction and Color3.fromRGB(255, 180, 80) or Color3.fromRGB(80, 180, 255), 1)
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
	_G._acreateCorner(argsBox, 4)

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
	_G._acreateCorner(fireBtn, 4)

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

-- ============= REGISTRE DES COMPTES ROBLOX =============
-- Recherche un joueur Roblox hors-jeu par username/displayname, affiche tout : profil, blurb, ban, groupes, jeux.
-- Wrapper function pour isoler les locals du scope global (evite "exceeded 200 local registers" sur les gros panels)
local function buildRegistrySection(parentPage)
	-- Refonte v38.14 : PAS de wrapper registryCard.
	-- Tous les enfants (titre, subtitle, status, resultScroll) sont dans _G._aregistryScroll DIRECTEMENT.
	-- Chaque enfant a un LayoutOrder pour empiler verticalement via _G._aregistryLayout (UIListLayout parent).
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
_G._acreateCorner(resultScroll, 6)
_G._acreateStroke(resultScroll, Color3.fromRGB(60, 60, 80), 1)

local resultLayout = Instance.new("UIListLayout")
resultLayout.Padding = UDim.new(0, 6)
resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultLayout.Parent = resultScroll

-- Helper: join a list into a string with separator, or "Indisponible" if empty
local function joinOrIndi(list, sep, max)
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
		_G._acreateCorner(card, 10)
		_G._acreateStroke(card, Color3.fromRGB(120, 80, 255), 2)
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
		_G._acreateCorner(tagInput, 6)
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
		_G._acreateCorner(addBtn, 6)
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
		_G._acreateCorner(removeBtn, 6)
		removeBtn.MouseButton1Click:Connect(function()
			local tags = getUserTags(userId)
			if #tags > 0 then removeTagFromUser(userId, tags[#tags]) ; refreshList() end
		end)
		tagInput.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				if addTagToUser(userId, tagInput.Text) then tagInput.Text = "" ; refreshList() end
			end
		end)
		local _G._acloseBtn = Instance.new("TextButton")
		_G._acloseBtn.Size = UDim2.new(0, 30, 0, 30)
		_G._acloseBtn.Position = UDim2.new(1, -36, 0, 6)
		_G._acloseBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		_G._acloseBtn.Text = "X"
		_G._acloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		_G._acloseBtn.Font = Enum.Font.GothamBold
		_G._acloseBtn.TextSize = 14
		_G._acloseBtn.BorderSizePixel = 0
		_G._acloseBtn.ZIndex = 52
		_G._acloseBtn.Parent = card
		_G._acreateCorner(_G._acloseBtn, 15)
		_G._acloseBtn.MouseButton1Click:Connect(function() closeTagPopup() end)
		_tagPopup = overlay
	end

	-- === DÉTECTION APPAREIL (seulement pour le local player) ===
	function detectLocalDevice()
		local ok, result = pcall(function()
			local touchOn = _G._aUserInputService.TouchEnabled
			local kbOn = _G._aUserInputService.KeyboardEnabled
			local mouseOn = _G._aUserInputService.MouseEnabled
			local gamepadOn = _G._aUserInputService.GamepadEnabled
			local vrOn = _G._aUserInputService.VREnabled
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
	_G._acreateCorner(card, 8)
	_G._acreateStroke(card, Color3.fromRGB(60, 60, 90), 1)

	-- Badges VERIFIED / PREMIUM / BANNED en haut à droite de la carte
	;(function()
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
			_G._acreateCorner(v, 4)
		end
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
			_G._acreateCorner(p, 4)
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
			_G._acreateCorner(b, 4)
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
		_G._acreateCorner(warnBar, 6)
		_G._acreateStroke(warnBar, Color3.fromRGB(255, 150, 50), 1.2)
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
	_G._acreateCorner(avatarHolder, 8)
	_G._acreateStroke(avatarHolder, Color3.fromRGB(120, 80, 255), 1.5)

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
	_G._acreateCorner(avatarImg, 6)

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
	if data.userId and _G._aPlayers then
		local liveFound = false
		pcall(function()
			local target = _G._aPlayers:GetPlayerByUserId(data.userId)
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
				local _isFriend = (target.IsFriendsWith and _G._aLocalPlayer and target:IsFriendsWith(_G._aLocalPlayer.UserId)) and "Oui" or "Non"
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
	-- Approche : URL Roblox directe (marche même quand _G._aPlayers:GetUserThumbnailAsync bloque)
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
			_G._acreateCorner(btn, 6)
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
		-- 1) Résoudre username -> userId via _G._aPlayers:GetUserIdFromNameAsync (NATUREL Roblox, pas d'API externe)
		local userId, displayName, username
		local ok, uid = pcall(function()
			return _G._aPlayers:GetUserIdFromNameAsync(query)
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
			local r = _G._ahttpGet("https://users.roblox.com/v1/users/" .. userId)
			if r and r ~= "" then
				local d2 = _G._aHttpService:JSONDecode(r)
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

		-- 3) Avatar (via _G._aPlayers:GetUserThumbnailAsync, NATIF Roblox, pas besoin de HttpGet)
		pcall(function()
			data.avatarUrl = _G._aPlayers:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		
		-- 3b) Native Roblox data (no HTTP needed - works on ALL executors)
		pcall(function()
			-- Get display name via native API
			local name = _G._aPlayers:GetNameFromUserIdAsync(userId)
			if name and name ~= "" then data.displayName = name end
		end)
		pcall(function()
			-- Check if user is online on THIS server
			local player = _G._aPlayers:GetPlayerByUserId(userId)
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
			local player = _G._aPlayers:GetPlayerByUserId(userId)
			if player then
				data.accountAgeDays = player.AccountAge
			end
		end)

		-- 4) Friends count
		pcall(function()
			local r = _G._ahttpGet("https://friends.roblox.com/v1/users/" .. userId .. "/friends/count")
			if r and r ~= "" then
				local d2 = _G._aHttpService:JSONDecode(r)
				if d2 and d2.count then data.friendCount = d2.count end
			end
		end)

		-- 5) Groupes
		pcall(function()
			local r = _G._ahttpGet("https://users.roblox.com/v1/users/" .. userId .. "/groups")
			if r and r ~= "" then
				local d2 = _G._aHttpService:JSONDecode(r)
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
				local r = _G._ahttpGet("https://games.roblox.com/v2/users/" .. userId .. "/games?sortOrder=Desc&limit=5")
				if r and r ~= "" then
					local d2 = _G._aHttpService:JSONDecode(r)
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
				local r = _G._ahttpGet("https://games.roblox.com/v1/users/" .. userId .. "/favorite/games?sortOrder=Desc&limit=5")
				if r and r ~= "" then
					local d2 = _G._aHttpService:JSONDecode(r)
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
				local r = _G._ahttpGet("https://premiumfeatures.roblox.com/v1/users/" .. userId .. "/validate-membership")
				if r and r ~= "" then
					local isPremium = (r == "true")
					data.isPremium = isPremium
				end
			end)

			-- 6d) Badges count
			pcall(function()
				local r = _G._ahttpGet("https://badges.roblox.com/v1/users/" .. userId .. "/badges?limit=1&sortOrder=Desc")
				if r and r ~= "" then
					local d2 = _G._aHttpService:JSONDecode(r)
					if d2 and d2.data then data.badgeCount = #d2.data end
				end
			end)

			-- 6e) Followers / Following count
			pcall(function()
				local r = _G._ahttpGet("https://friends.roblox.com/v1/users/" .. userId .. "/followings/count")
				if r and r ~= "" then
					local d2 = _G._aHttpService:JSONDecode(r)
					if d2 and d2.count then data.followingCount = d2.count end
				end
			end)
			pcall(function()
				local r = _G._ahttpGet("https://friends.roblox.com/v1/users/" .. userId .. "/followers/count")
				if r and r ~= "" then
					local d2 = _G._aHttpService:JSONDecode(r)
					if d2 and d2.count then data.followerCount = d2.count end
				end
			end)

			-- 6f) Présence en temps réel (en ligne / en jeu / au studio)
			pcall(function()
				local body = _G._aHttpService:JSONEncode({userIds = {userId}})
				local r = _G._ahttpGet("https://presence.roblox.com/v1/presence/users?userIds=" .. tostring(userId))
				if r and r ~= "" then
					local d = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/avatar")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 then
							data.avatarHatCount = d2.numHats or 0
							data.avatarBody = d2.bodyColors and "Personnalisé" or "Classique"
						end
					end
				end)

				-- 6h) Currently wearing (accessoires actuellement équipés)
				pcall(function()
					local r = _G._ahttpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/currently-wearing")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 and d2.assetIds then
							data.wearingCount = #d2.assetIds
						end
					end
				end)

				-- 6i) Tenues (outfits)
				pcall(function()
					local r = _G._ahttpGet("https://avatar.roblox.com/v1/users/" .. userId .. "/outfits?page=1&itemsPerPage=10&isEditable=false")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://users.roblox.com/v1/users/" .. userId .. "/username-history?limit=10&sortOrder=Desc")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://groups.roblox.com/v2/users/" .. userId .. "/groups/roles?includeLocked=true")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://friends.roblox.com/v1/users/" .. userId .. "/friends?page=1&itemsPerPage=5")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
							return _G._ahttpGet("https://inventory.roblox.com/v2/users/" .. userId .. "/inventory/" .. atype .. "?page=1&itemsPerPage=1&sortOrder=Desc")
						end)
						if ok and r and r ~= "" then
							local d2 = _G._aHttpService:JSONDecode(r)
							if d2 and d2.totalCount then
								data.inventory[atype] = d2.totalCount
							end
						end
					end
				end)

				-- 6n) Last online timestamp
				pcall(function()
					local r = _G._ahttpGet("https://presence.roblox.com/v1/presence/last-online?userId=" .. tostring(userId))
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://accountinformation.roblox.com/v1/users/" .. userId .. "/email")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 then
							data.hasEmail = d2.emailAddress and d2.emailAddress ~= "" or false
							data.emailVerified = d2.verified or false
						end
					end
				end)

				-- 6p) Premium subscription details (date d'expiration)
				pcall(function()
					local r = _G._ahttpGet("https://billing.roblox.com/v1/users/" .. userId .. "/subscription")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trade-privacy")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 then
							data.tradePrivacy = d2.tradePrivacy
						end
					end
				end)
				pcall(function()
					local r = _G._ahttpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trades/inbound/count")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 and d2.count then data.tradesInbound = d2.count end
					end
				end)
				pcall(function()
					local r = _G._ahttpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trades/outbound/count")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 and d2.count then data.tradesOutbound = d2.count end
					end
				end)
				-- 6s) Robux (economy)
				pcall(function()
					local r = _G._ahttpGet("https://economy.roblox.com/v1/users/" .. userId .. "/currency")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 and d2.robux then data.robux = d2.robux end
					end
				end)
				-- 6t) Badges list (names)
				pcall(function()
					local r = _G._ahttpGet("https://badges.roblox.com/v1/users/" .. userId .. "/badges?limit=20&sortOrder=Desc")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
					local r = _G._ahttpGet("https://accountinformation.roblox.com/v1/description/" .. userId)
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
						if d2 and d2.description then data.blurb = d2.description end
					end
				end)
				pcall(function()
					local r = _G._ahttpGet("https://trades.roblox.com/v1/users/" .. userId .. "/trades/active/count")
					if r and r ~= "" then
						local d2 = _G._aHttpService:JSONDecode(r)
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
				if userId and _G._aPlayers.LocalPlayer and userId == _G._aPlayers._G._aLocalPlayer.UserId then
					data.deviceHint = detectLocalDevice()
				end

				renderResult(data, resultScroll)

			end)
		end

end
-- Construit la section Registry dans l'onglet Registry (parentPage = registryPage)
-- Tout le contenu (searchBox, searchBtn, registryCard) est reparenté vers _G._aregistryScroll à la fin
buildRegistrySection(_G._aregistryPage)

-- Reparent: tous les enfants directs de _G._aregistryPage (sauf registryScroll) vont dans registryScroll
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
end)(_G._aregistryPage, _G._aregistryScroll, registryLayout)
task.defer(function()
	_G._aregistryScroll.CanvasSize = UDim2.new(0, 0, 0, _G._aregistryLayout.AbsoluteContentSize.Y + 10)
end)

-- (L'update des stats FPS/ping est maintenant dans la page Joueurs)

function giveGhostTool()
	if _G._aLocalPlayer.Backpack:FindFirstChild("Invisible_V4") or (character and character:FindFirstChild("Invisible_V4")) then return end
	for _, v in ipairs(_G._aLocalPlayer.PlayerGui:GetChildren()) do
		if v:IsA("ScreenGui") and (v.Name:find("Chronos") or v.Name:find("Ghost")) then v:Destroy() end
	end

	local tool = Instance.new("Tool")
	tool.Name = "Invisible_V4"
	tool.RequiresHandle = false
	tool.Parent = _G._aLocalPlayer:WaitForChild("Backpack")

	local isInvisible = false
	local ghostChar = nil
	local ghostConn = nil
	local ghostMouse = _G._aLocalPlayer:Get_G._aMouse()
	local OFFSET_UNDER = -30

	local function remoteClick()
		local target = ghost_G._aMouse.Target
		if target then
			local detector = target:FindFirstChildOfClass("ClickDetector") or (target.Parent and target.Parent:FindFirstChildOfClass("ClickDetector"))
			if detector then pcall(function() fireclickdetector(detector) end) end
		end
	end

	tool.Activated:Connect(function()
		local char = _G._aLocalPlayer.Character
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
				_G._aRunService.Heartbeat:Wait()
			end
			if char.PrimaryPart then char.PrimaryPart.Anchored = true end
			for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
			_G._aCamera.CameraSubject = gh
			ghostConn = _G._aRunService.RenderStepped:Connect(function()
				if isInvisible and ghostChar and _G._aLocalPlayer.Character then
					local realHum = _G._aLocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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
				_G._aCamera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
				ghostChar:Destroy()
				ghostChar = nil
			end
		end
	end)

	_G._aUserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and isInvisible and input.UserInputType == Enum.UserInputType.MouseButton1 then
			remoteClick()
		end
	end)
end

function giveElevenTool()
	if _G._aLocalPlayer.Backpack:FindFirstChild("Eleven_Master_PZ70") or (character and character:FindFirstChild("Eleven_Master_PZ70")) then return end
	local tool = Instance.new("Tool")
	tool.Name = "Eleven_Master_PZ70"
	tool.RequiresHandle = true
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(0.1, 0.1, 0.1)
	h.Transparency = 1
	h.CanCollide = false
	h.Parent = tool
	tool.Parent = _G._aLocalPlayer:WaitForChild("Backpack")

	local targetPart = nil
	local bp, bg = nil, nil
	local distance = 25
	local active = false
	local rotationMode = false
	local lockedZoom = 10
	local ghostActive = false
	local ghostChar = nil
	local ghostConn = nil
	local eMouse = _G._aLocalPlayer:Get_G._aMouse()
	local heldConn = nil

	local function isPlayerPart(part)
		if not part then return false end
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			for _, plr in ipairs(_G._aPlayers:Get_G._aPlayers()) do
				if plr.Character == model then return true end
			end
		end
		return false
	end

	local function findTarget()
		local tgt = e_G._aMouse.Target
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
		_G._aLocalPlayer.CameraMaxZoomDistance = 100
		_G._aLocalPlayer.CameraMinZoomDistance = 0.5
	end

	_G._aRunService.RenderStepped:Connect(function()
		if active and targetPart and bp then
			if not targetPart.Parent then cleanupHolding() return end
			_G._aLocalPlayer.CameraMaxZoomDistance = lockedZoom
			_G._aLocalPlayer.CameraMinZoomDistance = lockedZoom
			if not rotationMode then
				local ray = e_G._aMouse.UnitRay
				bp.Position = ray.Origin + ray.Direction * distance
				bp.P = 20000
				bp.MaxForce = Vector3.one * math.huge
			end
		elseif active then
			_G._aLocalPlayer.CameraMaxZoomDistance = 100
			_G._aLocalPlayer.CameraMinZoomDistance = 0.5
		end
	end)

	e_G._aMouse.Button1Down:Connect(function()
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
				local r = _G._aLocalPlayer.Character and _G._aLocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if r then lockedZoom = (_G._aCamera.CFrame.Position - r.Position).Magnitude end
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
					pcall(function() targetPart:SetNetworkOwner(_G._aLocalPlayer) end)
				end
				-- reset collisions si le part est détruit/reparenté
				heldConn = targetPart.AncestryChanged:Connect(function(_, newParent)
					if not newParent then cleanupHolding() end
				end)
			end
		end
	end)

	e_G._aMouse.Button1Up:Connect(function()
		cleanupHolding()
	end)

	_G._aUserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Nine then
			ghostActive = not ghostActive
			local char = _G._aLocalPlayer.Character
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
				ghostConn = _G._aRunService.RenderStepped:Connect(function()
					if ghostChar and char:FindFirstChildOfClass("Humanoid") then
						local gcHum = ghostChar:FindFirstChildOfClass("Humanoid")
						if gcHum then
							gcHum:Move(char.Humanoid.MoveDirection, false)
							if char.Humanoid.Jump then gcHum.Jump = true end
							_G._aCamera.CameraSubject = gcHum
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
					_G._aCamera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
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

	e_G._aMouse.WheelForward:Connect(function()
		if active and targetPart then
			if rotationMode and bg then bg.CFrame = bg.CFrame * CFrame.Angles(math.rad(15), 0, 0)
			else distance = math.clamp(distance + 5, 5, 300) end
		end
	end)
	e_G._aMouse.WheelBackward:Connect(function()
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
	if _G._aLocalPlayer.Backpack:FindFirstChild("SpiderTool") or (character and character:FindFirstChild("SpiderTool")) then return end

	local tool = Instance.new("Tool")
	tool.Name = "SpiderTool"
	tool.RequiresHandle = false
	tool.Parent = _G._aLocalPlayer:WaitForChild("Backpack")

	local connection = nil
	local jumpConnection = nil
	local isClimbing = false
	local currentHitNormal = Vector3.new(0, 1, 0)
	local smoothedNormal = Vector3.new(0, 1, 0)
	local jumpCooldown = false
	local bodyVelocity, bodyGyro, attachment = nil, nil, nil

	tool.Equipped:Connect(function()
		local char = _G._aLocalPlayer.Character
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

		jumpConnection = _G._aUserInputService.JumpRequest:Connect(function()
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

		connection = _G._aRunService.RenderStepped:Connect(function(deltaTime)
			if jumpCooldown then
				hum.AutoRotate = true
				return
			end

			local pos = root.Position
			local look = root.CFrame.LookVector
			local up = root.CFrame.UpVector
			local right = root.CFrame.RightVector

			local rayForward = _G._aWorkspace:Raycast(pos, look * 4.5, params)
			local rayBackward = _G._aWorkspace:Raycast(pos, -look * 4.5, params)
			local rayDown = _G._aWorkspace:Raycast(pos, -up * 8, params)
			local rayOuterFwd = _G._aWorkspace:Raycast(pos + look * 3.5, (-up * 3 - look * 2).Unit * 12, params)
			local rayOuterBack = _G._aWorkspace:Raycast(pos - look * 3.5, (-up * 3 + look * 2).Unit * 12, params)
			local rayOuterRight = _G._aWorkspace:Raycast(pos + right * 3.5, (-up * 3 - right * 2).Unit * 12, params)
			local rayOuterLeft = _G._aWorkspace:Raycast(pos - right * 3.5, (-up * 3 + right * 2).Unit * 12, params)

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
		local char = _G._aLocalPlayer.Character
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
-- Wrap dans IIFE avec paramètres pour éviter la limite d'upvalues (200)
;(function(_fly, _noclip, _esp, _fullbright, _zeroG, _localPlayer)
	_localPlayer.Chatted:Connect(function(msg)
		local m = msg:lower()
		if m == ";fly" then _fly.set(true)
		elseif m == ";unfly" then _fly.set(false)
		elseif m == ";noclip" then _noclip.set(true)
		elseif m == ";unnoclip" then _noclip.set(false)
		elseif m == ";esp" then _esp.enabled = true _G._arefreshESP()
		elseif m == ";unesp" then _esp.enabled = false _G._aclearESP()
		elseif m == ";fullbright" then _fullbright.set(true)
		elseif m == ";unfullbright" then _fullbright.set(false)
		elseif m == ";zerog" then _zeroG.set(true)
		elseif m == ";unzerog" then _zeroG.set(false)
		end
	end)
end)(_G._aflySwitch, _G._anoclipSwitch, _G._aespState, fullbrightSwitch, _G._azeroGSwitch, LocalPlayer)

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
end)(_G._amainFrame)

-- BOOT SAFE 3 LAYERS:
-- Layer 1: reveal immédiat à 0.5s (filet de sécurité absolu)
-- Layer 2: reveal à 3s si pas encore visible (fallback)
-- Layer 3: _G._aswitchTab après reveal (parse-time IIFE) + _G._abootSequence call explicite
;(function(__G._apages, _switchTab)
	-- LAYER 1: reveal immédiat à 0.5s
	task.delay(0.5, function()
		pcall(function()
			if _G._amainFrame and not _G._amainFrame.Visible then
				_G._amainFrame.Visible = true
			end
		end)
	end)
	-- LAYER 2: _G._aswitchTab Joueurs
	pcall(function() __G._aswitchTab("Home") end)
		-- LAYER 3: fallback à 3s (au cas où)
		task.delay(3, function()
			pcall(function()
				if _G._amainFrame and not _G._amainFrame.Visible then
					_G._amainFrame.Visible = true
				end
				if _pages and _pages["Home"] and not _pages["Home"].Visible then
					pcall(function() __G._aswitchTab("Home") end)
			end
		end)
	end)
end)(_G._apages, switchTab)

-- FALLBACK absolu: si l'intro n'a jamais révélé le panel, le forcer visible + onglet Joueurs après 5s
task.delay(5, function()
	pcall(function()
		if _G._amainFrame and not _G._amainFrame.Visible then
			warn("[AGORA] Fallback reveal: panel forcé visible")
			_G._amainFrame.Visible = true
		end
		if _G._apages and pages["Home"] and not pages["Home"].Visible then
				_G._aswitchTab("Home")
		end
	end)
end)

-- Lancer l'intro cinéma si on veut (désactivée par défaut car elle bloque le fallback)
-- pcall(function() _G._abootSequence(function()
-- 	pcall(function() _G._amainFrame.Visible = true end)
-- 	_G._aswitchTab("Joueurs")
-- end) end)

end
_G._a_buildPanel()
