-- ============================================================
-- AGORA ANTI-CHEAT -- Module serveur
-- Detection (0.2s) + Enforcement Heartbeat (freeze tout le character).
-- Re-check pendant le bloc : prolonge si encore en train de tricher.
-- Kick apres MAX_OFFENSES blocs consecutifs.
-- ============================================================
return function(deps)
	local Players    = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local workspace  = game:GetService("Workspace")

	local getPlayerRole  = deps.getPlayerRole
	local rolesHierarchy = deps.rolesHierarchy
	local acAlertEvent   = deps.acAlertEvent

	-- CONFIG
	local SCAN_INTERVAL    = 0.2
	local FLY_MAX_AIRTIME  = 1.5
	local FLY_RAYCAST_DIST = 22
	local TP_MAX_DISTANCE  = 75
	local SPEED_TOLERANCE  = 1.35
	local ALERT_COOLDOWN   = 30
	local BLOCK_DURATION   = 5     -- duree initiale du bloc (teleport seulement)
	local RECHECK_INTERVAL = 0.8   -- recheck pendant le bloc

	-- STATE
	local playerData  = {}
	local blockData   = {} -- [uid] = {frozenPos, reason, lastCheck, offenses}
	local whitelisted = {}

	local AC = {}

	-- WHITELIST
	function AC.whitelist(plr, t, v)
		local u = plr.UserId
		if not whitelisted[u] then whitelisted[u] = {} end
		whitelisted[u][t] = v or true
	end
	function AC.unwhitelist(plr, t)
		if whitelisted[plr.UserId] then whitelisted[plr.UserId][t] = nil end
	end
	function AC.unwhitelistAll(plr) whitelisted[plr.UserId] = nil end
	function AC.isWhitelisted(plr, t)
		local u = whitelisted[plr.UserId]
		return u and u[t]
	end

	-- HELPERS
	local function isStaff(plr)
		return (rolesHierarchy[getPlayerRole(plr)] or 99) <= 4
	end

	local function sendAlert(targetPlr, reason, details)
		local data = playerData[targetPlr.UserId]
		if not data then return end
		local now = os.clock()
		if data.lastAlert and (now - data.lastAlert) < ALERT_COOLDOWN then return end
		data.lastAlert = now
		-- Prefixer heure + nom joueur si pas deja present
		local msg = string.format("[%s] %s | %s", os.date("%H:%M:%S"), targetPlr.Name, details)
		for _, p in pairs(Players:GetPlayers()) do
			if isStaff(p) then
				acAlertEvent:FireClient(p, reason, msg, targetPlr.Name)
			end
		end
	end

	local function makeRayParams(char)
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		local f = {char}
		for _, pl in pairs(Players:GetPlayers()) do
			if pl.Character then table.insert(f, pl.Character) end
		end
		p.FilterDescendantsInstances = f
		return p
	end

	local function makeOverlapParams(char)
		local p = OverlapParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		local f = {char}
		for _, pl in pairs(Players:GetPlayers()) do
			if pl.Character then table.insert(f, pl.Character) end
		end
		p.FilterDescendantsInstances = f
		return p
	end

	local function isSolid(part)
		return part.CanCollide and part.Transparency < 0.8 and not part:IsA("Terrain")
	end

	local function findGround(hrp, char)
		local p   = makeRayParams(char)
		local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -200, 0), p)
		if hit then
			return Vector3.new(hrp.Position.X, hit.Position.Y + 3, hrp.Position.Z)
		end
		return nil
	end

	-- Freeze total : Anchored + zero velocite sur tout le character.
	-- hrp.Anchored = true cote serveur = indepassable par n'importe quel script client.
	local function freezeCharacter(char, frozenPos, hrp)
		hrp.Anchored = true
		if frozenPos then
			hrp.CFrame = CFrame.new(frozenPos) * (hrp.CFrame - hrp.CFrame.Position)
		end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				p.AssemblyLinearVelocity  = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end

	local function releaseBlock(uid, hrp)
		blockData[uid] = nil
		if hrp and hrp.Parent then
			hrp.Anchored = false
			pcall(function() hrp:SetNetworkOwnershipAuto() end)
		end
	end

	local function activateBlock(plr, hrp, char, frozenPos, reason)
		local uid = plr.UserId
		local now = os.clock()
		local bd  = blockData[uid]

		if bd then
			-- Deja bloque: prolonger + mettre a jour la position
			bd.lastCheck = now
			if frozenPos then bd.frozenPos = frozenPos end
			return
		end

		-- Compter les offenses (pour info dans l'alerte seulement, pas de kick)
		local data     = playerData[uid]
		local offenses = (data and data.offenses or 0) + 1
		if data then data.offenses = offenses end

		pcall(function() hrp:SetNetworkOwner(nil) end)
		freezeCharacter(char, frozenPos, hrp)

		blockData[uid] = {
			frozenPos = frozenPos or hrp.Position,
			reason    = reason,
			lastCheck = now,
		}

		local fp = frozenPos or hrp.Position
		sendAlert(plr, reason:upper() .. " DETECTE",
			string.format("[%s] %s — Tentative #%d | pos=(%.0f,%.0f,%.0f)",
				os.date("%H:%M:%S"), plr.Name, offenses, fp.X, fp.Y, fp.Z))
	end

	-- ================================================================
	-- ENFORCEMENT + RE-CHECK (Heartbeat)
	-- Freeze chaque frame + verifie toutes les RECHECK_INTERVAL secondes
	-- si le joueur triche encore. Prolonge si oui, libere si non.
	-- ================================================================
	RunService.Heartbeat:Connect(function()
		local now = os.clock()

		for uid, bd in pairs(blockData) do
			local plr = Players:GetPlayerByUserId(uid)
			if not plr then blockData[uid] = nil continue end

			local char = plr.Character
			if not char then blockData[uid] = nil continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum then continue end

			-- Freeze tout le character chaque frame
			freezeCharacter(char, bd.frozenPos, hrp)

			-- Re-check periodique
			if (now - bd.lastCheck) < RECHECK_INTERVAL then continue end
			bd.lastCheck = now

			local stillCheating = false

			if bd.reason == "fly" then
				local params    = makeRayParams(char)
				local groundRay = workspace:Raycast(hrp.Position, Vector3.new(0, -FLY_RAYCAST_DIST, 0), params)
				local hmState   = hum and hum:GetState()
				local isGrounded = false
				if groundRay then
					local dist = (hrp.Position - groundRay.Position).Magnitude
					isGrounded = dist <= 5
						or hmState == Enum.HumanoidStateType.Running
						or hmState == Enum.HumanoidStateType.RunningNoPhysics
						or hmState == Enum.HumanoidStateType.Landed
						or hmState == Enum.HumanoidStateType.Seated
				end
				if isGrounded then
					local data = playerData[uid]
					if data then data.airTime = 0 data.flyStrikes = 0 end
					releaseBlock(uid, hrp)
				else
					stillCheating = true
					local gpos = findGround(hrp, char)
					if gpos then bd.frozenPos = gpos end
				end

			elseif bd.reason == "noclip" then
				local op      = makeOverlapParams(char)
				local ok, pts = pcall(workspace.GetPartsInPart, workspace, hrp, op)
				local inWall  = false
				if ok and pts then
					for _, p in ipairs(pts) do
						if isSolid(p) then inWall = true break end
					end
				end
				if inWall then
					stillCheating = true
				else
					local data = playerData[uid]
					if data then
						data.noclipStrikes = 0
						data.lastValidPos  = hrp.Position
					end
					releaseBlock(uid, hrp)
				end

			elseif bd.reason == "teleport" then
				-- Teleport: liberer apres BLOCK_DURATION (pas de condition physique)
				if (now - bd.lastCheck + RECHECK_INTERVAL) >= BLOCK_DURATION then
					releaseBlock(uid, hrp)
				else
					stillCheating = true
				end

			elseif bd.reason == "speed" then
				releaseBlock(uid, hrp)
			end

			-- Si encore en train de tricher: on reste bloque, pas de liberation
			if stillCheating then
				-- (le freeze continue au prochain Heartbeat automatiquement)
			end
		end
	end)

	-- ================================================================
	-- DETECTION (0.2s)
	-- ================================================================
	local scanTimer = 0

	local function checkFly(plr, data, hrp, hum, char)
		if AC.isWhitelisted(plr, "fly") then data.airTime = 0 return end

		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Jumping then data.airTime = 0 return end
		if state == Enum.HumanoidStateType.Ragdoll
			or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.GettingUp then return end

		local params  = makeRayParams(char)
		local groundRay = workspace:Raycast(hrp.Position, Vector3.new(0, -FLY_RAYCAST_DIST, 0), params)

		-- Sol confirme seulement si TRES proche (<= 5 studs) OU etat humanoid confirme.
		-- Evite le faux positif fly+noclip dans un batiment (sol 10 studs en dessous).
		local isGrounded = false
		if groundRay then
			local dist = (hrp.Position - groundRay.Position).Magnitude
			isGrounded = dist <= 5
				or state == Enum.HumanoidStateType.Running
				or state == Enum.HumanoidStateType.RunningNoPhysics
				or state == Enum.HumanoidStateType.Landed
				or state == Enum.HumanoidStateType.Seated
		end

		if isGrounded then
			data.airTime    = 0
			data.flyStrikes = math.max(0, (data.flyStrikes or 0) - 0.5)
			return
		end

		local vel   = hrp.AssemblyLinearVelocity
		local velY  = vel.Y
		local horzV = Vector3.new(vel.X, 0, vel.Z).Magnitude

		if state == Enum.HumanoidStateType.Freefall and velY < -8 then
			data.airTime = math.max(0, (data.airTime or 0) - SCAN_INTERVAL * 0.5)
			return
		end

		local rate = SCAN_INTERVAL
		if math.abs(velY) < 3 then
			rate = SCAN_INTERVAL * (horzV > 8 and 2.5 or 1.5)
		else
			rate = SCAN_INTERVAL * 0.2
		end
		-- Recidiviste = seuil reduit de moitie
		local threshold = FLY_MAX_AIRTIME * (data.offenses and data.offenses > 0 and 0.5 or 1.0)
		data.airTime = (data.airTime or 0) + rate

		if data.airTime >= threshold then
			local groundPos = findGround(hrp, char)
			activateBlock(plr, hrp, char, groundPos, "fly")
			data.airTime    = 0
			data.flyStrikes = 0
		end
	end

	local function checkNoclip(plr, data, hrp, char)
		if AC.isWhitelisted(plr, "noclip") then return end
		if AC.isWhitelisted(plr, "fly") then return end

		local currentPos = hrp.Position
		if not data.lastPos then return end

		local move = currentPos - data.lastPos
		if move.Magnitude < 0.4 then return end

		local insideWall = false
		local wallName   = "?"

		-- Methode 1 : overlap
		local ok, parts = pcall(workspace.GetPartsInPart, workspace, hrp, makeOverlapParams(char))
		if ok and parts then
			for _, p in ipairs(parts) do
				if isSolid(p) then insideWall = true wallName = p.Name break end
			end
		end

		-- Methode 2 : traversee par normale
		if not insideWall then
			local rp  = makeRayParams(char)
			local hit = workspace:Raycast(data.lastPos, move, rp)
			if hit and isSolid(hit.Instance) then
				local n = hit.Normal
				if (data.lastPos - hit.Position):Dot(n) * (currentPos - hit.Position):Dot(n) < 0 then
					insideWall = true
					wallName   = hit.Instance.Name
				end
			end
		end

		if insideWall then
			data.noclipStrikes = (data.noclipStrikes or 0) + 1
			if data.noclipStrikes >= 2 then
				activateBlock(plr, hrp, char, data.lastValidPos, "noclip")
				data.noclipStrikes = 0
			end
		else
			data.lastValidPos  = currentPos
			data.noclipStrikes = math.max(0, (data.noclipStrikes or 0) - 0.3)
		end
	end

	local function checkTeleport(plr, data, hrp, char)
		if AC.isWhitelisted(plr, "teleport") then return end
		if AC.isWhitelisted(plr, "fly") then return end
		if not data.lastPos then return end

		local dist = (hrp.Position - data.lastPos).Magnitude
		if dist > TP_MAX_DISTANCE then
			activateBlock(plr, hrp, char, data.lastValidPos or data.lastPos, "teleport")
		end
	end

	local function checkSpeed(plr, data, hrp, hum)
		if AC.isWhitelisted(plr, "speed") or AC.isWhitelisted(plr, "fly")
			or AC.isWhitelisted(plr, "teleport") then return end
		if not data.lastPos then return end

		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.Ragdoll
			or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Swimming then return end

		local cur  = hrp.Position
		local last = data.lastPos
		local dist = Vector3.new(cur.X-last.X, 0, cur.Z-last.Z).Magnitude
		local maxOk = hum.WalkSpeed * SCAN_INTERVAL * SPEED_TOLERANCE

		if dist > maxOk and dist > 5 then
			data.speedStrikes = (data.speedStrikes or 0) + 1
			if data.speedStrikes >= 4 then
				sendAlert(plr, "SPEED HACK",
					string.format("%.1f studs/%.2fs (max %.1f)", dist, SCAN_INTERVAL, maxOk))
				data.speedStrikes = 0
			end
		else
			data.speedStrikes = math.max(0, (data.speedStrikes or 0) - 0.3)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		scanTimer = scanTimer + dt
		if scanTimer < SCAN_INTERVAL then return end
		scanTimer = 0

		for _, plr in pairs(Players:GetPlayers()) do
			if isStaff(plr) then continue end

			local char = plr.Character
			if not char then continue end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then continue end

			local uid = plr.UserId
			if blockData[uid] then continue end -- pas de detection pendant un bloc

			if not playerData[uid] then
				playerData[uid] = {
					lastPos       = hrp.Position,
					lastValidPos  = hrp.Position,
					airTime       = 0,
					flyStrikes    = 0,
					noclipStrikes = 0,
					speedStrikes  = 0,
					offenses      = 0,
					lastAlert     = nil,
				}
				continue
			end

			local data = playerData[uid]
			checkFly(plr, data, hrp, hum, char)
			checkNoclip(plr, data, hrp, char)
			checkTeleport(plr, data, hrp, char)
			checkSpeed(plr, data, hrp, hum)
			data.lastPos = hrp.Position
		end
	end)

	-- CLEANUP
	Players.PlayerRemoving:Connect(function(plr)
		local uid = plr.UserId
		playerData[uid] = nil
		whitelisted[uid] = nil
		blockData[uid]   = nil
	end)

	local function resetData(plr)
		local uid  = plr.UserId
		blockData[uid] = nil
		local data = playerData[uid]
		if data then
			data.lastPos       = nil
			data.lastValidPos  = nil
			data.airTime       = 0
			data.flyStrikes    = 0
			data.noclipStrikes = 0
			data.speedStrikes  = 0
			-- Ne pas reset offenses (info seulement, pour les moderateurs)
		end
		local char = plr.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then pcall(function() hrp:SetNetworkOwnershipAuto() end) end
		end
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function() resetData(plr) end)
	end)
	for _, plr in pairs(Players:GetPlayers()) do
		plr.CharacterAdded:Connect(function() resetData(plr) end)
	end

	return AC
end
