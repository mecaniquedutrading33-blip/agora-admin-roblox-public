--[[
	VEHICLE MENU — SERVER (Script)
	Amélioré : gestion robuste, sans bug
	Place dans ServerScriptService
]]

local CONFIG = {
	FreeVIP = {
		["Vzlom_Emk"] = true,
	},
	FreeAdmin = {
		["Vzlom_Emk"] = true,
		["roichristo_christo"] = true,
		["Goupildwayne"] = true,
		["roi_christo"] = true,
		["Quev123_Tm"] = true,
		["King_drago2348"] = true,
	},
	GamepassId = 0,
	GroupConfig = {
		GroupId = 0,
		MinModRank = 100,
		MinAdminRank = 200,
		MinFondaRank = 255
	}
}

-- Véhicules réservés au staff (doivent matcher les noms dans VEHICLE_DATA client)
local STAFF_VEHICLES = {
	["Bus de low City"] = true,
	["2019 Dodge Charger"] = true,
}

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PriceStore = DataStoreService:GetDataStore("VehiclePrices_v101")
local AdminStore = DataStoreService:GetDataStore("VehicleAdmins_v101")

-- Crée le RemoteEvent AVANT tout WaitForChild pour ne jamais bloquer le client
local VehicleSystem = ReplicatedStorage:FindFirstChild("VehicleSystem")
if not VehicleSystem then
	VehicleSystem = Instance.new("Folder")
	VehicleSystem.Name = "VehicleSystem"
	VehicleSystem.Parent = ReplicatedStorage
end

local VehicleEvent = VehicleSystem:FindFirstChild("VehicleEvent")
if not VehicleEvent then
	VehicleEvent = Instance.new("RemoteEvent")
	VehicleEvent.Name = "VehicleEvent"
	VehicleEvent.Parent = VehicleSystem
end

-- Dossier véhicules : ne bloque PAS le script s'il manque (timeout 10s)
local VehiclesFolder = ServerStorage:FindFirstChild("Voiture dans le menu")
if not VehiclesFolder then
	VehiclesFolder = ServerStorage:WaitForChild("Voiture dans le menu", 10)
end
if not VehiclesFolder then
	warn("[VehicleMenu] Dossier 'Voiture dans le menu' introuvable dans ServerStorage !")
	VehiclesFolder = Instance.new("Folder")
	VehiclesFolder.Name = "Voiture dans le menu"
	VehiclesFolder.Parent = ServerStorage
end

local activeVehicles = {}
local savedPrices = {}
local SavedAdmins = {}

local successAdmin, adminList = pcall(function()
	return AdminStore:GetAsync("AdminList")
end)
if successAdmin and type(adminList) == "table" then
	SavedAdmins = adminList
end

for _, vehicle in ipairs(VehiclesFolder:GetChildren()) do
	local success, price = pcall(function()
		return PriceStore:GetAsync(vehicle.Name)
	end)
	if success and price then
		savedPrices[vehicle.Name] = price
	else
		savedPrices[vehicle.Name] = 0
	end
end

local function sendNotification(player, title, text, color)
	VehicleEvent:FireClient(player, "Notification", {Title = title, Text = text, Color = color})
end

local function checkPermission(player)
	if CONFIG.FreeAdmin[player.Name] or SavedAdmins[player.Name] then
		return "Admin"
	end

	local success, rank = pcall(function()
		return player:GetRankInGroup(CONFIG.GroupConfig.GroupId)
	end)

	if success and rank > 0 then
		if rank >= CONFIG.GroupConfig.MinFondaRank then return "Fonda" end
		if rank >= CONFIG.GroupConfig.MinAdminRank then return "Admin" end
		if rank >= CONFIG.GroupConfig.MinModRank then return "Mod" end
	end

	local serverScriptService = game:GetService("ServerScriptService")
	local agoraFolder = serverScriptService:FindFirstChild("AgoraAdmin") or serverScriptService:FindFirstChild("Agora")
	if agoraFolder then
		local api = agoraFolder:FindFirstChild("API") or agoraFolder:FindFirstChild("Functions")
		if api and api:IsA("ModuleScript") then
			local agora = require(api)
			if agora.GetPlayerRank then
				local rankName = agora.GetPlayerRank(player)
				if rankName == "Fonda" or rankName == "Founder" then return "Fonda" end
				if rankName == "Admin" then return "Admin" end
				if rankName == "Mod" or rankName == "Moderator" then return "Mod" end
			end
		end
	end

	return "Player"
end

local function isVIP(player)
	if CONFIG.FreeVIP[player.Name] then return true end

	local rank = checkPermission(player)
	if rank == "Mod" or rank == "Admin" or rank == "Fonda" then return true end

	if CONFIG.GamepassId > 0 then
		local marketplace = game:GetService("MarketplaceService")
		local hasPass = false
		pcall(function()
			hasPass = marketplace:UserOwnsGamePassAsync(player.UserId, CONFIG.GamepassId)
		end)
		return hasPass
	end

	return false
end

local function cleanAllPlayerVehicles(player)
	if activeVehicles[player.UserId] then
		for _, vehicle in ipairs(activeVehicles[player.UserId]) do
			if vehicle and vehicle.Parent then
				vehicle:Destroy()
			end
		end
		activeVehicles[player.UserId] = {}
	end
end

VehicleEvent.OnServerEvent:Connect(function(player, action, data)
	if action == "Spawn" then
		local vehicleName = data
		local targetModel = VehiclesFolder:FindFirstChild(vehicleName)
		if not targetModel then
			sendNotification(player, "ERREUR", "Modèle introuvable dans le serveur.", Color3.fromRGB(200, 50, 50))
			return
		end

		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local rank = checkPermission(player)
		local vipStatus = isVIP(player)

		if STAFF_VEHICLES[vehicleName] and rank == "Player" then
			sendNotification(player, "ERREUR", "Ce véhicule est strictement réservé au personnel.", Color3.fromRGB(200, 50, 50))
			return
		end

		local spawnPart = workspace:FindFirstChild("generer voiture ici")
		if not spawnPart then
			sendNotification(player, "ERREUR", "Le point de spawn 'generer voiture ici' est introuvable !", Color3.fromRGB(200, 50, 50))
			return
		end

		local clone = targetModel:Clone()
		local _, extentsSize = clone:GetBoundingBox()

		local partCFrame = spawnPart.CFrame
		local partSize = spawnPart.Size
		local partRotation = partCFrame.Rotation

		local longestAxis = (partSize.X > partSize.Z) and "X" or "Z"
		local length = partSize[longestAxis]

		local safeBoxSize = extentsSize + Vector3.new(3, 4, 3)
		local steps = math.floor(length / safeBoxSize[longestAxis])

		local finalSpawnCFrame = nil

		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		overlapParams.FilterDescendantsInstances = {spawnPart, clone, character}

		for i = 0, steps do
			local offsetMagnitude = (i * safeBoxSize[longestAxis]) - (length / 2) + (safeBoxSize[longestAxis] / 2)
			if offsetMagnitude + (safeBoxSize[longestAxis] / 2) > length / 2 then break end

			local offsetVector = (longestAxis == "X") and Vector3.new(offsetMagnitude, 0, 0) or Vector3.new(0, 0, offsetMagnitude)

			local testCFrame = partCFrame * CFrame.new(offsetVector) * CFrame.new(0, (partSize.Y / 2) + (extentsSize.Y / 2) + 1, 0)

			local alignedCFrame = CFrame.new(testCFrame.Position) * partRotation

			local partsInBox = workspace:GetPartBoundsInBox(alignedCFrame, safeBoxSize, overlapParams)
			local slotTaken = false

			for _, p in ipairs(partsInBox) do
				if p.Parent:FindFirstChild("Humanoid") or p.Name:find("Wheel") or p.Name:find("Body") or p.Name:find("Seat") then
					slotTaken = true
					break
				end
			end

			if not slotTaken then
				finalSpawnCFrame = alignedCFrame
				break
			end
		end

		if not finalSpawnCFrame then
			clone:Destroy()
			sendNotification(player, "ESPACE INSUFFISANT", "Il n'y a plus de place sur la zone pour spawner !", Color3.fromRGB(200, 50, 50))
			return
		end

		if not activeVehicles[player.UserId] then
			activeVehicles[player.UserId] = {}
		end

		local maxVehicles = 1
		if rank == "Admin" or rank == "Fonda" or vipStatus then
			maxVehicles = 2
		end

		while #activeVehicles[player.UserId] >= maxVehicles do
			local oldVehicle = activeVehicles[player.UserId][1]
			if oldVehicle and oldVehicle.Parent then
				oldVehicle:Destroy()
			end
			table.remove(activeVehicles[player.UserId], 1)
		end

		clone:PivotTo(finalSpawnCFrame)
		clone.Parent = workspace

		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				desc.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end

		table.insert(activeVehicles[player.UserId], clone)
		sendNotification(player, "SUCCÈS", vehicleName .. " généré avec succès !", Color3.fromRGB(50, 200, 50))

		task.wait(0.1)
		local tpOffset = finalSpawnCFrame * CFrame.new(0, 0, -(extentsSize.Z / 2 + 6))
		local faceVehicleCFrame = CFrame.new(tpOffset.Position, finalSpawnCFrame.Position)

		character:PivotTo(faceVehicleCFrame)

	elseif action == "Despawn" then
		cleanAllPlayerVehicles(player)
		sendNotification(player, "INFO", "Tes véhicules ont été retirés.", Color3.fromRGB(70, 150, 255))

	elseif action == "ToggleLock" then
		local locked = data and data.Locked
		if activeVehicles[player.UserId] then
			local count = 0
			for _, vehicle in ipairs(activeVehicles[player.UserId]) do
				if vehicle and vehicle.Parent then
					for _, desc in ipairs(vehicle:GetDescendants()) do
						if desc:IsA("VehicleSeat") then
							desc.Locked = locked
							count = count + 1
						end
					end
				end
			end
			if count > 0 then
				sendNotification(player, locked and "🔒 VÉROUILLÉ" or "🔓 DÉVERROUILLÉ",
					"Portes " .. (locked and "verrouillées" or "déverrouillées") .. " (" .. count .. " siège(s)).",
					locked and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(50, 200, 100))
			else
				sendNotification(player, "INFO", "Aucun siège trouvé sur ton véhicule.", Color3.fromRGB(70, 150, 255))
			end
		end

	elseif action == "SetPrice" then
		local rank = checkPermission(player)
		if rank == "Fonda" or rank == "Admin" then
			local vehicleName = data.Name
			local newPrice = tonumber(data.Price)
			if vehicleName and newPrice then
				savedPrices[vehicleName] = newPrice
				pcall(function()
					PriceStore:SetAsync(vehicleName, newPrice)
				end)
				sendNotification(player, "SYSTEME", "Prix de " .. vehicleName .. " mis à " .. newPrice .. "$", Color3.fromRGB(50, 200, 100))
				VehicleEvent:FireAllClients("UpdatePrices", savedPrices)
			end
		end

	elseif action == "AddAdmin" then
		local rank = checkPermission(player)
		if rank == "Fonda" or rank == "Admin" then
			local newAdmin = tostring(data)
			if newAdmin and newAdmin ~= "" then
				SavedAdmins[newAdmin] = true
				pcall(function()
					AdminStore:SetAsync("AdminList", SavedAdmins)
				end)
				sendNotification(player, "SYSTÈME", newAdmin .. " a été ajouté comme Admin.", Color3.fromRGB(50, 200, 100))
			end
		end

	elseif action == "RequestData" then
		local rank = checkPermission(player)
		VehicleEvent:FireClient(player, "SyncData", {Prices = savedPrices, Rank = rank})
	end
end)

local function setupPlayerTracking(player)
	player.CharacterAdded:Connect(function()
		if not activeVehicles[player.UserId] then
			activeVehicles[player.UserId] = {}
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayerTracking)
for _, player in ipairs(Players:GetPlayers()) do
	if not activeVehicles[player.UserId] then
		activeVehicles[player.UserId] = {}
	end
	setupPlayerTracking(player)
end

Players.PlayerRemoving:Connect(function(player)
	cleanAllPlayerVehicles(player)
	activeVehicles[player.UserId] = nil
end)
