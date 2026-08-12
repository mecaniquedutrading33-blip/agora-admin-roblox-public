--[[
	VEHICLE MENU — CLIENT (LocalScript)
	Amélioré : design premium, recherche, sans musique, sans bug
	Place dans StarterPlayerScripts ou StarterGui
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local VehicleSystem = ReplicatedStorage:WaitForChild("VehicleSystem")
local VehicleEvent = VehicleSystem:WaitForChild("VehicleEvent")

-- ============================================================
-- DONNÉES DES VÉHICULES
-- ============================================================
local VEHICLE_DATA = {
	-- STAFF
	["2019 Dodge Charger"] = {
		Image = "rbxassetid://130672366329744",
		Desc = "Voiture de modération (QC6)",
		StaffOnly = true,
		Category = "Staff"
	},
	["Bus de low City"] = {
		Image = "rbxassetid://89123440856111",
		Desc = "Bus d'école massif de la ville.",
		StaffOnly = true,
		Category = "Staff"
	},
	-- LUXE
	["2020 Mercedes-Benz G63 AMG1"] = {
		Image = "rbxassetid://101330374613353",
		Desc = "Modèle de luxe puissant.",
		StaffOnly = false,
		Category = "Luxe"
	},
	-- NOUVELLES VOITURES
	["1982 Pontiac Firebird S/E"] = {
		Image = "rbxassetid://71392961318033",
		Desc = "Muscle car classique des années 80.",
		StaffOnly = false,
		Category = "Classique"
	},
	["2020 Dodge Charger PPV"] = {
		Image = "rbxassetid://122711410371904",
		Desc = "Berline policière moderne et rapide.",
		StaffOnly = false,
		Category = "Police"
	},
	["2005 Ford F-150"] = {
		Image = "rbxassetid://81551437470407",
		Desc = "Pickup américain robuste et fiable.",
		StaffOnly = false,
		Category = "Pickup"
	},
	["2018 Ford Explorer Police Interceptor Utility"] = {
		Image = "rbxassetid://76302967906830",
		Desc = "SUV policier d'intervention.",
		StaffOnly = false,
		Category = "Police"
	},
	["2014 Chevrolet Tahoe PPV"] = {
		Image = "rbxassetid://83195740795179",
		Desc = "SUV policier imposant et puissant.",
		StaffOnly = false,
		Category = "Police"
	},
	["2010 Nissan March"] = {
		Image = "rbxassetid://110247864833656",
		Desc = "Petite citadine économique.",
		StaffOnly = false,
		Category = "Citadine"
	},
	["2011 Ford Crown Victoria"] = {
		Image = "rbxassetid://127572609003904",
		Desc = "Légendaire berline policière.",
		StaffOnly = false,
		Category = "Police"
	},
	["2021 Chevrolet Tahoe PPV"] = {
		Image = "rbxassetid://74440174435683",
		Desc = "SUV policier dernière génération.",
		StaffOnly = false,
		Category = "Police"
	},
	["1990 Mazda Miata NA"] = {
		Image = "rbxassetid://113905256300073",
		Desc = "Roadster japonais léger et agile.",
		StaffOnly = false,
		Category = "Sport"
	},
	["2020 Ford Explorer Interceptors"] = {
		Image = "rbxassetid://111334900044835",
		Desc = "SUV policier d'élite.",
		StaffOnly = false,
		Category = "Police"
	},
	["2019 Chevrolet Tahoe PPV"] = {
		Image = "rbxassetid://122303662128852",
		Desc = "SUV policier polyvalent.",
		StaffOnly = false,
		Category = "Police"
	},
	["2007 Dodge Grand Caravan"] = {
		Image = "rbxassetid://128064983648289",
		Desc = "Monospace familial spacieux.",
		StaffOnly = false,
		Category = "Familial"
	},
	["2012 Ford F150 SVT Raptor"] = {
		Image = "rbxassetid://96752584655165",
		Desc = "Pickup tout-terrain haute performance.",
		StaffOnly = false,
		Category = "Pickup"
	},
	["2021 Dodge Durango"] = {
		Image = "rbxassetid://135061590706437",
		Desc = "SUV américain musclé et spacieux.",
		StaffOnly = false,
		Category = "SUV"
	}
}

local currentPrices = {}
local myRank = "Player"
local selectedVehicle = nil
local menuOpen = false
local menuCooldown = false
local searchQuery = ""

local isMobile = UserInputService.TouchEnabled or workspace.CurrentCamera.ViewportSize.X < 800

-- ============================================================
-- UI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VehicleSystemUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Blur = Instance.new("BlurEffect")
Blur.Size = 0
Blur.Enabled = true
Blur.Parent = Lighting

local ClickSound = Instance.new("Sound")
ClickSound.Name = "VehicleClick"
ClickSound.SoundId = "rbxassetid://6895079853"
ClickSound.Volume = 0.3
ClickSound.Parent = ScreenGui

local HoverSound = Instance.new("Sound")
HoverSound.Name = "VehicleHover"
HoverSound.SoundId = "rbxassetid://6895079853"
HoverSound.Volume = 0.1
HoverSound.PlaybackSpeed = 1.5
HoverSound.Parent = ScreenGui

-- Couleurs du thème
local COLORS = {
	Bg = Color3.fromRGB(12, 12, 16),
	Panel = Color3.fromRGB(20, 20, 27),
	Card = Color3.fromRGB(24, 24, 32),
	CardHover = Color3.fromRGB(32, 34, 44),
	CardSelected = Color3.fromRGB(38, 44, 70),
	Accent = Color3.fromRGB(80, 130, 255),
	AccentDark = Color3.fromRGB(50, 90, 200),
	Green = Color3.fromRGB(50, 200, 110),
	Red = Color3.fromRGB(210, 60, 60),
	Text = Color3.fromRGB(240, 240, 255),
	SubText = Color3.fromRGB(170, 170, 190),
	Stroke = Color3.fromRGB(45, 45, 60)
}

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = isMobile and UDim2.new(0, 520, 0, 300) or UDim2.new(0, 820, 0, 500)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = COLORS.Bg
MainFrame.BackgroundTransparency = 1
MainFrame.ClipsDescendants = true
MainFrame.Visible = false

local mainCorner = Instance.new("UICorner", MainFrame)
mainCorner.CornerRadius = UDim.new(0, 18)
local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = COLORS.Stroke
mainStroke.Thickness = 1.5
mainStroke.Transparency = 1
MainFrame.Parent = ScreenGui

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 55)
Header.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0.5, 0, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GESTION VÉHICULES"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = isMobile and 16 or 20
Title.TextColor3 = COLORS.Text
Title.TextXAlignment = Enum.TextXAlignment.Left

local SubTitle = Instance.new("TextLabel", Header)
SubTitle.Size = UDim2.new(0.5, 0, 0, 16)
SubTitle.Position = UDim2.new(0, 20, 0, 34)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "Sélectionne ton véhicule"
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = isMobile and 10 or 12
SubTitle.TextColor3 = COLORS.SubText
SubTitle.TextXAlignment = Enum.TextXAlignment.Left

local ExitBtn = Instance.new("TextButton", MainFrame)
ExitBtn.Size = isMobile and UDim2.new(0, 100, 0, 35) or UDim2.new(0, 120, 0, 42)
ExitBtn.Position = UDim2.new(1, -15, 0, 15)
ExitBtn.AnchorPoint = Vector2.new(1, 0)
ExitBtn.BackgroundColor3 = COLORS.Red
ExitBtn.Text = "🚪 SORTIR"
ExitBtn.Font = Enum.Font.GothamBlack
ExitBtn.TextSize = isMobile and 12 or 14
ExitBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ExitBtn).CornerRadius = UDim.new(0, 8)
ExitBtn.ZIndex = 5

-- Barre de recherche
local SearchBox = Instance.new("TextBox", MainFrame)
SearchBox.Size = isMobile and UDim2.new(0.4, -20, 0, 32) or UDim2.new(0.35, -20, 0, 34)
SearchBox.Position = isMobile and UDim2.new(0, 15, 0, 60) or UDim2.new(0, 20, 0, 62)
SearchBox.BackgroundColor3 = COLORS.Panel
SearchBox.Text = ""
SearchBox.PlaceholderText = "🔍 Rechercher un véhicule..."
SearchBox.PlaceholderColor3 = COLORS.SubText
SearchBox.TextColor3 = COLORS.Text
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = isMobile and 11 or 13
SearchBox.ClearTextOnFocus = false
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)
local searchStroke = Instance.new("UIStroke", SearchBox)
searchStroke.Color = COLORS.Stroke
searchStroke.Thickness = 1

-- Panneau gauche (liste)
local LeftPanel = Instance.new("ScrollingFrame", MainFrame)
LeftPanel.Size = isMobile and UDim2.new(0.4, 0, 1, -150) or UDim2.new(0.35, 0, 1, -175)
LeftPanel.Position = isMobile and UDim2.new(0, 15, 0, 100) or UDim2.new(0, 20, 0, 105)
LeftPanel.BackgroundTransparency = 1
LeftPanel.ScrollBarThickness = 3
LeftPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
LeftPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y

local listLayout = Instance.new("UIListLayout", LeftPanel)
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Panneau droit (aperçu)
local RightPanel = Instance.new("Frame", MainFrame)
RightPanel.Size = isMobile and UDim2.new(0.6, -25, 1, -70) or UDim2.new(0.65, -35, 1, -80)
RightPanel.Position = isMobile and UDim2.new(0.4, 10, 0, 55) or UDim2.new(0.35, 15, 0, 60)
RightPanel.BackgroundColor3 = COLORS.Panel
Instance.new("UICorner", RightPanel).CornerRadius = UDim.new(0, 14)

local PreviewImage = Instance.new("ImageLabel", RightPanel)
PreviewImage.Size = UDim2.new(1, -20, 0.55, 0)
PreviewImage.Position = UDim2.new(0, 10, 0, 10)
PreviewImage.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
PreviewImage.ScaleType = Enum.ScaleType.Fit
PreviewImage.Image = ""
Instance.new("UICorner", PreviewImage).CornerRadius = UDim.new(0, 10)

local CategoryLabel = Instance.new("TextLabel", RightPanel)
CategoryLabel.Size = UDim2.new(1, -20, 0, 20)
CategoryLabel.Position = UDim2.new(0, 10, 0.55, 8)
CategoryLabel.BackgroundTransparency = 1
CategoryLabel.Text = ""
CategoryLabel.Font = Enum.Font.GothamBold
CategoryLabel.TextSize = isMobile and 10 or 12
CategoryLabel.TextColor3 = COLORS.Accent
CategoryLabel.TextXAlignment = Enum.TextXAlignment.Left

local DescriptionLabel = Instance.new("TextLabel", RightPanel)
DescriptionLabel.Size = UDim2.new(1, -20, 0.18, 0)
DescriptionLabel.Position = UDim2.new(0, 10, 0.55, 30)
DescriptionLabel.BackgroundTransparency = 1
DescriptionLabel.Text = "Sélectionne un modèle pour afficher les options."
DescriptionLabel.Font = Enum.Font.Gotham
DescriptionLabel.TextSize = isMobile and 11 or 13
DescriptionLabel.TextColor3 = COLORS.SubText
DescriptionLabel.TextWrapped = true
DescriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
DescriptionLabel.TextXAlignment = Enum.TextXAlignment.Left

local ControlFrame = Instance.new("Frame", RightPanel)
ControlFrame.Size = UDim2.new(1, -20, 0.22, 0)
ControlFrame.Position = UDim2.new(0, 10, 1, -45)
ControlFrame.BackgroundTransparency = 1

local ActionBtn = Instance.new("TextButton", ControlFrame)
ActionBtn.Size = UDim2.new(1, 0, 1, 0)
ActionBtn.Position = UDim2.new(0, 0, 0, 0)
ActionBtn.BackgroundColor3 = COLORS.Green
ActionBtn.Text = "GÉNÉRER LA VOITURE"
ActionBtn.Font = Enum.Font.GothamBlack
ActionBtn.TextSize = isMobile and 12 or 16
ActionBtn.TextColor3 = Color3.new(1, 1, 1)
ActionBtn.Visible = false
Instance.new("UICorner", ActionBtn).CornerRadius = UDim.new(0, 8)

-- Boutons admin (bas gauche)
local AdminConfigBtn = Instance.new("TextButton", MainFrame)
AdminConfigBtn.Size = isMobile and UDim2.new(0.4, 0, 0, 32) or UDim2.new(0.35, 0, 0, 35)
AdminConfigBtn.Position = isMobile and UDim2.new(0, 15, 1, -47) or UDim2.new(0, 20, 1, -65)
AdminConfigBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AdminConfigBtn.Text = "👑 AJOUTER ADMIN"
AdminConfigBtn.Font = Enum.Font.GothamBold
AdminConfigBtn.TextSize = isMobile and 10 or 11
AdminConfigBtn.TextColor3 = Color3.fromRGB(240, 200, 50)
AdminConfigBtn.Visible = false
Instance.new("UICorner", AdminConfigBtn).CornerRadius = UDim.new(0, 8)

local PriceConfigBtn = Instance.new("TextButton", MainFrame)
PriceConfigBtn.Size = isMobile and UDim2.new(0.4, 0, 0, 32) or UDim2.new(0.35, 0, 0, 35)
PriceConfigBtn.Position = isMobile and UDim2.new(0, 15, 1, -84) or UDim2.new(0, 20, 1, -105)
PriceConfigBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
PriceConfigBtn.Text = "🔧 AJUSTER PRIX"
PriceConfigBtn.Font = Enum.Font.GothamBold
PriceConfigBtn.TextSize = isMobile and 10 or 11
PriceConfigBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
PriceConfigBtn.Visible = false
Instance.new("UICorner", PriceConfigBtn).CornerRadius = UDim.new(0, 8)

local GlobalDespawnBtn = Instance.new("TextButton", MainFrame)
GlobalDespawnBtn.Size = isMobile and UDim2.new(0.4, 0, 0, 32) or UDim2.new(0.35, 0, 0, 35)
GlobalDespawnBtn.Position = isMobile and UDim2.new(0, 15, 1, -121) or UDim2.new(0, 20, 1, -145)
GlobalDespawnBtn.BackgroundColor3 = COLORS.Red
GlobalDespawnBtn.Text = "❌ RETIRER TOUT"
GlobalDespawnBtn.Font = Enum.Font.GothamBold
GlobalDespawnBtn.TextSize = isMobile and 10 or 11
GlobalDespawnBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", GlobalDespawnBtn).CornerRadius = UDim.new(0, 8)

-- ============================================================
-- POPUP PRIX
-- ============================================================
local PriceEditFrame = Instance.new("Frame", MainFrame)
PriceEditFrame.Size = UDim2.new(0, 300, 0, 180)
PriceEditFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
PriceEditFrame.AnchorPoint = Vector2.new(0.5, 0.5)
PriceEditFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
PriceEditFrame.Visible = false
PriceEditFrame.ZIndex = 50
Instance.new("UICorner", PriceEditFrame).CornerRadius = UDim.new(0, 12)
local priceStrk = Instance.new("UIStroke", PriceEditFrame)
priceStrk.Color = Color3.fromRGB(90, 90, 110)
priceStrk.Thickness = 2

local PriceTitle = Instance.new("TextLabel", PriceEditFrame)
PriceTitle.Size = UDim2.new(1, 0, 0, 30)
PriceTitle.Position = UDim2.new(0, 0, 0, 10)
PriceTitle.BackgroundTransparency = 1
PriceTitle.Text = "🔧 MODIFIER LE PRIX"
PriceTitle.Font = Enum.Font.GothamBlack
PriceTitle.TextSize = 16
PriceTitle.TextColor3 = Color3.new(1, 1, 1)
PriceTitle.ZIndex = 51

local PriceInput = Instance.new("TextBox", PriceEditFrame)
PriceInput.Size = UDim2.new(0.8, 0, 0, 40)
PriceInput.Position = UDim2.new(0.1, 0, 0, 50)
PriceInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
PriceInput.Text = ""
PriceInput.PlaceholderText = "Entrer le nouveau prix ($)..."
PriceInput.TextColor3 = Color3.new(1, 1, 1)
PriceInput.Font = Enum.Font.Gotham
PriceInput.ZIndex = 51
Instance.new("UICorner", PriceInput).CornerRadius = UDim.new(0, 6)

local SavePriceBtn = Instance.new("TextButton", PriceEditFrame)
SavePriceBtn.Size = UDim2.new(0.35, 0, 0, 40)
SavePriceBtn.Position = UDim2.new(0.1, 0, 0, 110)
SavePriceBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
SavePriceBtn.Text = "VALIDER"
SavePriceBtn.Font = Enum.Font.GothamBold
SavePriceBtn.TextColor3 = Color3.new(1, 1, 1)
SavePriceBtn.ZIndex = 51
Instance.new("UICorner", SavePriceBtn).CornerRadius = UDim.new(0, 6)

local CancelPriceBtn = Instance.new("TextButton", PriceEditFrame)
CancelPriceBtn.Size = UDim2.new(0.35, 0, 0, 40)
CancelPriceBtn.Position = UDim2.new(0.55, 0, 0, 110)
CancelPriceBtn.BackgroundColor3 = COLORS.Red
CancelPriceBtn.Text = "RETOUR"
CancelPriceBtn.Font = Enum.Font.GothamBold
CancelPriceBtn.TextColor3 = Color3.new(1, 1, 1)
CancelPriceBtn.ZIndex = 51
Instance.new("UICorner", CancelPriceBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- POPUP ADMIN
-- ============================================================
local AdminEditFrame = Instance.new("Frame", MainFrame)
AdminEditFrame.Size = UDim2.new(0, 300, 0, 180)
AdminEditFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
AdminEditFrame.AnchorPoint = Vector2.new(0.5, 0.5)
AdminEditFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
AdminEditFrame.Visible = false
AdminEditFrame.ZIndex = 50
Instance.new("UICorner", AdminEditFrame).CornerRadius = UDim.new(0, 12)
local adminStrk = Instance.new("UIStroke", AdminEditFrame)
adminStrk.Color = Color3.fromRGB(240, 200, 50)
adminStrk.Thickness = 2

local AdminTitle = Instance.new("TextLabel", AdminEditFrame)
AdminTitle.Size = UDim2.new(1, 0, 0, 30)
AdminTitle.Position = UDim2.new(0, 0, 0, 10)
AdminTitle.BackgroundTransparency = 1
AdminTitle.Text = "👑 AJOUTER UN ADMIN"
AdminTitle.Font = Enum.Font.GothamBlack
AdminTitle.TextSize = 16
AdminTitle.TextColor3 = Color3.fromRGB(240, 200, 50)
AdminTitle.ZIndex = 51

local AdminInput = Instance.new("TextBox", AdminEditFrame)
AdminInput.Size = UDim2.new(0.8, 0, 0, 40)
AdminInput.Position = UDim2.new(0.1, 0, 0, 50)
AdminInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
AdminInput.Text = ""
AdminInput.PlaceholderText = "Nom complet du joueur..."
AdminInput.TextColor3 = Color3.new(1, 1, 1)
AdminInput.Font = Enum.Font.Gotham
AdminInput.ZIndex = 51
Instance.new("UICorner", AdminInput).CornerRadius = UDim.new(0, 6)

local SaveAdminBtn = Instance.new("TextButton", AdminEditFrame)
SaveAdminBtn.Size = UDim2.new(0.35, 0, 0, 40)
SaveAdminBtn.Position = UDim2.new(0.1, 0, 0, 110)
SaveAdminBtn.BackgroundColor3 = COLORS.Green
SaveAdminBtn.Text = "VALIDER"
SaveAdminBtn.Font = Enum.Font.GothamBold
SaveAdminBtn.TextColor3 = Color3.new(1, 1, 1)
SaveAdminBtn.ZIndex = 51
Instance.new("UICorner", SaveAdminBtn).CornerRadius = UDim.new(0, 6)

local CancelAdminBtn = Instance.new("TextButton", AdminEditFrame)
CancelAdminBtn.Size = UDim2.new(0.35, 0, 0, 40)
CancelAdminBtn.Position = UDim2.new(0.55, 0, 0, 110)
CancelAdminBtn.BackgroundColor3 = COLORS.Red
CancelAdminBtn.Text = "RETOUR"
CancelAdminBtn.Font = Enum.Font.GothamBold
CancelAdminBtn.TextColor3 = Color3.new(1, 1, 1)
CancelAdminBtn.ZIndex = 51
Instance.new("UICorner", CancelAdminBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- ANIMATIONS BOUTONS
-- ============================================================
local function applyButtonAnimations(btn, hoverColor, clickColor, originalColor)
	btn.MouseEnter:Connect(function()
		HoverSound:Play()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = clickColor}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = hoverColor}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		ClickSound:Play()
	end)
end

applyButtonAnimations(ActionBtn, Color3.fromRGB(60, 220, 120), Color3.fromRGB(35, 160, 85), COLORS.Green)
applyButtonAnimations(ExitBtn, Color3.fromRGB(230, 80, 80), Color3.fromRGB(180, 45, 45), COLORS.Red)
applyButtonAnimations(GlobalDespawnBtn, Color3.fromRGB(220, 80, 80), Color3.fromRGB(160, 45, 45), COLORS.Red)
applyButtonAnimations(PriceConfigBtn, Color3.fromRGB(45, 45, 55), Color3.fromRGB(25, 25, 35), Color3.fromRGB(35, 35, 45))
applyButtonAnimations(AdminConfigBtn, Color3.fromRGB(45, 45, 55), Color3.fromRGB(25, 25, 35), Color3.fromRGB(35, 35, 45))
applyButtonAnimations(SavePriceBtn, Color3.fromRGB(60, 140, 240), Color3.fromRGB(30, 100, 200), Color3.fromRGB(40, 120, 220))
applyButtonAnimations(CancelPriceBtn, Color3.fromRGB(230, 80, 80), Color3.fromRGB(180, 45, 45), COLORS.Red)
applyButtonAnimations(SaveAdminBtn, Color3.fromRGB(60, 220, 120), Color3.fromRGB(35, 160, 85), COLORS.Green)
applyButtonAnimations(CancelAdminBtn, Color3.fromRGB(230, 80, 80), Color3.fromRGB(180, 45, 45), COLORS.Red)

-- ============================================================
-- LOGIQUE
-- ============================================================
local function updateMenuLayout()
	for _, item in ipairs(LeftPanel:GetChildren()) do
		if item:IsA("TextButton") then
			local price = currentPrices[item.Name] or 0
			local priceLabel = item:FindFirstChild("PriceLabel")
			if priceLabel then
				priceLabel.Text = (price == 0) and "GRATUIT" or price .. "$"
			end
		end
	end
end

local function refreshVehicleList()
	-- Vide la liste
	for _, child in ipairs(LeftPanel:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local query = string.lower(searchQuery or "")

	for name, info in pairs(VEHICLE_DATA) do
		-- Filtre staff
		if info.StaffOnly and myRank == "Player" then
			continue
		end
		-- Filtre recherche
		if query ~= "" and not string.find(string.lower(name), query, 1, true) then
			continue
		end

		local ItemBtn = Instance.new("TextButton")
		ItemBtn.Name = name
		ItemBtn.Size = UDim2.new(1, -5, 0, isMobile and 45 or 55)
		ItemBtn.BackgroundColor3 = COLORS.Card
		ItemBtn.Text = "  " .. name
		ItemBtn.Font = Enum.Font.GothamBold
		ItemBtn.TextSize = isMobile and 11 or 13
		ItemBtn.TextColor3 = info.StaffOnly and Color3.fromRGB(255, 120, 120) or COLORS.Text
		ItemBtn.TextXAlignment = Enum.TextXAlignment.Left
		ItemBtn.ClipsDescendants = true
		ItemBtn.LayoutOrder = 1
		Instance.new("UICorner", ItemBtn).CornerRadius = UDim.new(0, 8)
		local strk = Instance.new("UIStroke", ItemBtn)
		strk.Color = COLORS.Stroke

		local PriceLabel = Instance.new("TextLabel", ItemBtn)
		PriceLabel.Name = "PriceLabel"
		PriceLabel.Size = UDim2.new(0.3, 0, 1, 0)
		PriceLabel.Position = UDim2.new(0.7, -10, 0, 0)
		PriceLabel.BackgroundTransparency = 1
		PriceLabel.Text = "..."
		PriceLabel.Font = Enum.Font.GothamBlack
		PriceLabel.TextSize = isMobile and 11 or 13
		PriceLabel.TextColor3 = info.StaffOnly and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 200, 120)
		PriceLabel.TextXAlignment = Enum.TextXAlignment.Right

		ItemBtn.MouseEnter:Connect(function()
			HoverSound:Play()
			if selectedVehicle ~= name then
				TweenService:Create(ItemBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.CardHover}):Play()
			end
		end)

		ItemBtn.MouseLeave:Connect(function()
			if selectedVehicle ~= name then
				TweenService:Create(ItemBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Card}):Play()
			end
		end)

		ItemBtn.MouseButton1Click:Connect(function()
			ClickSound:Play()
			for _, sibling in ipairs(LeftPanel:GetChildren()) do
				if sibling:IsA("TextButton") then
					TweenService:Create(sibling, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Card}):Play()
					local s = sibling:FindFirstChildOfClass("UIStroke")
					if s then s.Color = COLORS.Stroke end
				end
			end
			TweenService:Create(ItemBtn, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.CardSelected}):Play()
			local s = ItemBtn:FindFirstChildOfClass("UIStroke")
			if s then s.Color = COLORS.Accent end
			selectCar(name)
		end)
		ItemBtn.Parent = LeftPanel
	end
end

local function selectCar(name)
	selectedVehicle = name
	local info = VEHICLE_DATA[name]
	if not info then return end

	local rawId = string.match(info.Image, "%d+")
	if rawId then
		PreviewImage.Image = "http://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=" .. rawId
	else
		PreviewImage.Image = info.Image
	end

	local p = currentPrices[name] or 0
	local costStr = (p == 0) and "Gratuit" or p .. "$"

	local staffText = info.StaffOnly and "\n\n⚠️ [VÉHICULE RÉSERVÉ AU STAFF]" or ""
	DescriptionLabel.Text = info.Desc .. staffText .. "\n\nPrix actuel : " .. costStr
	CategoryLabel.Text = "📁 " .. (info.Category or "Véhicule")

	ActionBtn.Visible = true
	ActionBtn.Size = UDim2.new(1, 0, 0, 0)
	TweenService:Create(ActionBtn, TweenInfo.new(0.4, Enum.EasingStyle.Bounce), {Size = UDim2.new(1, 0, 1, 0)}):Play()
end

local function toggleMenu(state)
	if state ~= nil then
		menuOpen = state
	else
		menuOpen = not menuOpen
	end

	if menuOpen then
		MainFrame.Visible = true
		MainFrame.Size = UDim2.new(0, 0, 0, 0)
		MainFrame.BackgroundTransparency = 1
		mainStroke.Transparency = 1

		local targetSize = isMobile and UDim2.new(0, 520, 0, 300) or UDim2.new(0, 820, 0, 500)

		TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = targetSize,
			BackgroundTransparency = 0
		}):Play()
		TweenService:Create(mainStroke, TweenInfo.new(0.5), {Transparency = 0}):Play()
		TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Size = 20}):Play()

		VehicleEvent:FireServer("RequestData")
	else
		PriceEditFrame.Visible = false
		AdminEditFrame.Visible = false

		local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1
		})
		closeTween:Play()
		TweenService:Create(mainStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		TweenService:Create(Blur, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Size = 0}):Play()

		closeTween.Completed:Connect(function()
			if not menuOpen then MainFrame.Visible = false end
		end)
	end
end

-- Recherche en direct
SearchBox.FocusLost:Connect(function(enterPressed)
	searchQuery = SearchBox.Text
	refreshVehicleList()
end)
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchQuery = SearchBox.Text
	refreshVehicleList()
end)

-- ============================================================
-- DÉTECTION ZONE
-- ============================================================
task.spawn(function()
	while task.wait(0.3) do
		local char = Player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local zone = workspace:FindFirstChild("Zone menu voiture")
				if zone then
					local localPos = zone.CFrame:PointToObjectSpace(hrp.Position)
					local size = zone.Size

					local inZone = math.abs(localPos.X) <= (size.X / 2) and math.abs(localPos.Z) <= (size.Z / 2)

					if inZone then
						if not menuOpen and not menuCooldown then
							toggleMenu(true)
						end
					else
						if menuCooldown then
							menuCooldown = false
						end
						if menuOpen then
							toggleMenu(false)
						end
					end
				end
			end
		end
	end
end)

-- ============================================================
-- ÉVÉNEMENTS BOUTONS
-- ============================================================
ExitBtn.MouseButton1Click:Connect(function()
	menuCooldown = true
	toggleMenu(false)
end)

ActionBtn.MouseButton1Click:Connect(function()
	if selectedVehicle then
		VehicleEvent:FireServer("Spawn", selectedVehicle)
		menuCooldown = true
		toggleMenu(false)
	end
end)

GlobalDespawnBtn.MouseButton1Click:Connect(function()
	VehicleEvent:FireServer("Despawn")
	menuCooldown = true
	toggleMenu(false)
end)

PriceConfigBtn.MouseButton1Click:Connect(function()
	if selectedVehicle then
		AdminEditFrame.Visible = false
		PriceInput.Text = tostring(currentPrices[selectedVehicle] or 0)
		PriceEditFrame.Visible = true
		PriceEditFrame.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(PriceEditFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 300, 0, 180)}):Play()
	end
end)

CancelPriceBtn.MouseButton1Click:Connect(function()
	ClickSound:Play()
	local t = TweenService:Create(PriceEditFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
	t:Play()
	t.Completed:Connect(function() PriceEditFrame.Visible = false end)
end)

SavePriceBtn.MouseButton1Click:Connect(function()
	local amt = tonumber(PriceInput.Text)
	if selectedVehicle and amt then
		VehicleEvent:FireServer("SetPrice", {Name = selectedVehicle, Price = amt})
		local t = TweenService:Create(PriceEditFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
		t:Play()
		t.Completed:Connect(function() PriceEditFrame.Visible = false end)
	end
end)

AdminConfigBtn.MouseButton1Click:Connect(function()
	PriceEditFrame.Visible = false
	AdminInput.Text = ""
	AdminEditFrame.Visible = true
	AdminEditFrame.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(AdminEditFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 300, 0, 180)}):Play()
end)

CancelAdminBtn.MouseButton1Click:Connect(function()
	ClickSound:Play()
	local t = TweenService:Create(AdminEditFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
	t:Play()
	t.Completed:Connect(function() AdminEditFrame.Visible = false end)
end)

SaveAdminBtn.MouseButton1Click:Connect(function()
	local name = AdminInput.Text
	if name and name ~= "" then
		VehicleEvent:FireServer("AddAdmin", name)
		local t = TweenService:Create(AdminEditFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
		t:Play()
		t.Completed:Connect(function() AdminEditFrame.Visible = false end)
	end
end)

-- ============================================================
-- ALERTES
-- ============================================================
local function displayAlert(data)
	local AlertFrame = Instance.new("Frame")
	AlertFrame.Size = isMobile and UDim2.new(0, 260, 0, 50) or UDim2.new(0, 320, 0, 60)
	AlertFrame.Position = UDim2.new(0.5, 0, 0, -80)
	AlertFrame.AnchorPoint = Vector2.new(0.5, 0)
	AlertFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	Instance.new("UICorner", AlertFrame).CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke", AlertFrame)
	stroke.Color = data.Color or Color3.fromRGB(100, 100, 120)
	stroke.Thickness = 2

	local lbl = Instance.new("TextLabel", AlertFrame)
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = data.Title .. "\n" .. data.Text
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = isMobile and 10 or 12
	lbl.TextColor3 = Color3.new(1, 1, 1)

	AlertFrame.Parent = ScreenGui

	TweenService:Create(AlertFrame, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 25)}):Play()
	task.delay(3.5, function()
		local out = TweenService:Create(AlertFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -80)})
		out:Play()
		out.Completed:Connect(function() AlertFrame:Destroy() end)
	end)
end

-- ============================================================
-- TÉLÉCOMMANDE DE VÉRROUILLAGE (suit la voiture)
-- ============================================================
local RemoteBtn = Instance.new("Frame", ScreenGui)
RemoteBtn.Name = "VehicleRemote"
RemoteBtn.Size = UDim2.new(0, 200, 0, 60)
RemoteBtn.Position = UDim2.new(0, 15, 0.5, 0)
RemoteBtn.AnchorPoint = Vector2.new(0, 0.5)
RemoteBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
RemoteBtn.BackgroundTransparency = 0.15
RemoteBtn.Visible = false
RemoteBtn.ZIndex = 20
Instance.new("UICorner", RemoteBtn).CornerRadius = UDim.new(0, 10)
local remoteStroke = Instance.new("UIStroke", RemoteBtn)
remoteStroke.Color = Color3.fromRGB(60, 60, 80)
remoteStroke.Thickness = 1.5

local RemoteImg = Instance.new("ImageLabel", RemoteBtn)
RemoteImg.Size = UDim2.new(0, 50, 0, 50)
RemoteImg.Position = UDim2.new(0, 5, 0.5, 0)
RemoteImg.AnchorPoint = Vector2.new(0, 0.5)
RemoteImg.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
RemoteImg.ScaleType = Enum.ScaleType.Fit
RemoteImg.Image = ""
Instance.new("UICorner", RemoteImg).CornerRadius = UDim.new(0, 6)

local RemoteName = Instance.new("TextLabel", RemoteBtn)
RemoteName.Size = UDim2.new(1, -70, 0, 20)
RemoteName.Position = UDim2.new(0, 60, 0, 8)
RemoteName.BackgroundTransparency = 1
RemoteName.Text = "Véhicule"
RemoteName.Font = Enum.Font.GothamBold
RemoteName.TextSize = 12
RemoteName.TextColor3 = Color3.fromRGB(240, 240, 255)
RemoteName.TextXAlignment = Enum.TextXAlignment.Left
RemoteName.TextTruncate = Enum.TextTruncate.AtEnd

local RemoteStatus = Instance.new("TextLabel", RemoteBtn)
RemoteStatus.Size = UDim2.new(1, -70, 0, 16)
RemoteStatus.Position = UDim2.new(0, 60, 0, 30)
RemoteStatus.BackgroundTransparency = 1
RemoteStatus.Text = "🔓 Déverrouillé"
RemoteStatus.Font = Enum.Font.Gotham
RemoteStatus.TextSize = 11
RemoteStatus.TextColor3 = Color3.fromRGB(100, 200, 120)
RemoteStatus.TextXAlignment = Enum.TextXAlignment.Left

local RemoteLockBtn = Instance.new("TextButton", RemoteBtn)
RemoteLockBtn.Size = UDim2.new(0, 40, 0, 40)
RemoteLockBtn.Position = UDim2.new(1, -45, 0.5, 0)
RemoteLockBtn.AnchorPoint = Vector2.new(0, 0.5)
RemoteLockBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
RemoteLockBtn.Text = "🔒"
RemoteLockBtn.Font = Enum.Font.GothamBlack
RemoteLockBtn.TextSize = 18
RemoteLockBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", RemoteLockBtn).CornerRadius = UDim.new(0, 8)

local remoteLocked = false

local function updateRemote()
	if not selectedVehicle then return end
	local info = VEHICLE_DATA[selectedVehicle]
	if not info then return end

	local rawId = string.match(info.Image, "%d+")
	if rawId then
		RemoteImg.Image = "http://www.roblox.com/Thumbs/Asset.ashx?width=150&height=150&assetId=" .. rawId
	else
		RemoteImg.Image = info.Image
	end
	RemoteName.Text = selectedVehicle
	RemoteStatus.Text = remoteLocked and "🔒 Verrouillé" or "🔓 Déverrouillé"
	RemoteStatus.TextColor3 = remoteLocked and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(100, 200, 120)
	RemoteLockBtn.BackgroundColor3 = remoteLocked and Color3.fromRGB(220, 160, 40) or Color3.fromRGB(40, 120, 220)
end

RemoteLockBtn.MouseButton1Click:Connect(function()
	ClickSound:Play()
	remoteLocked = not remoteLocked
	VehicleEvent:FireServer("ToggleLock", {Locked = remoteLocked})
	updateRemote()
end)

-- Suit la voiture du joueur
task.spawn(function()
	while task.wait(0.1) do
		local char = Player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Cherche la voiture la plus proche appartenant au joueur (via le menu)
			local nearest = nil
			local nearestDist = 30
			for _, v in ipairs(workspace:GetChildren()) do
				if v:IsA("Model") and v:FindFirstChildOfClass("VehicleSeat") then
					local vhrp = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
					if vhrp then
						local dist = (vhrp.Position - hrp.Position).Magnitude
						if dist < nearestDist then
							nearest = v
							nearestDist = dist
						end
					end
				end
			end
			if nearest then
				RemoteBtn.Visible = true
				-- Position à gauche de la voiture
				local cam = workspace.CurrentCamera
				local screenPos, onScreen = cam:WorldToScreenPoint(nearest:GetPivot().Position + Vector3.new(0, 2, 0))
				if onScreen then
					RemoteBtn.Position = UDim2.new(0, math.clamp(screenPos.X - 220, 10, 100000), 0, math.clamp(screenPos.Y, 10, 100000))
				end
			else
				RemoteBtn.Visible = false
			end
		else
			RemoteBtn.Visible = false
		end
	end
end)

-- ============================================================
-- RÉCEPTION SERVEUR
-- ============================================================
VehicleEvent.OnClientEvent:Connect(function(action, data)
	if action == "SyncData" then
		currentPrices = data.Prices
		myRank = data.Rank

		local isAdmin = (myRank == "Admin" or myRank == "Fonda" or Player.Name == "Vzlom_Emk")
		PriceConfigBtn.Visible = isAdmin
		AdminConfigBtn.Visible = isAdmin

		refreshVehicleList()
		updateMenuLayout()
		if selectedVehicle then selectCar(selectedVehicle) end
	elseif action == "UpdatePrices" then
		currentPrices = data
		updateMenuLayout()
		if selectedVehicle then selectCar(selectedVehicle) end
	elseif action == "Notification" then
		displayAlert(data)
	end
end)

-- Initialisation
refreshVehicleList()
