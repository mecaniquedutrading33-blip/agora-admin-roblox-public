-- AgoraTicketLS.lua — Script de tickets in-game (séparé du ModMenu)
-- LocalScript — placer dans AgoraAdminGui (même parent que ModMenu.lua)
-- Fonctionnel pour TOUS les joueurs (formulaire) et STAFF (alertes + panel de gestion)

-- ════════════════════════════════════════════════════════════
-- SERVICES
-- ════════════════════════════════════════════════════════════

local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local RS              = game:GetService("ReplicatedStorage")
local UIS             = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local gui     = script:FindFirstAncestorOfClass("ScreenGui")
if not gui then return end

-- ════════════════════════════════════════════════════════════
-- REMOTES
-- ════════════════════════════════════════════════════════════

local remotes = RS:WaitForChild("SystemRemotes", 30)
if not remotes then return end

local function safeRemote(name, t)
	return remotes:WaitForChild(name, t or 15)
end

local ticketSubmitEvent = safeRemote("TicketSubmitEvent")
local ticketListFunc    = safeRemote("TicketListFunc")
local ticketClaimEvent  = safeRemote("TicketClaimEvent")
local ticketAlertEvent  = safeRemote("TicketAlertEvent")
local getCmdsFunc       = safeRemote("GetCmdsFunc")
local modCamEvent       = safeRemote("ModCamEvent")
local modTPEvent        = safeRemote("ModTPEvent")
local cmdBarEvent       = safeRemote("CmdBarEvent")

-- ════════════════════════════════════════════════════════════
-- COULEURS (reprises de ModMenu)
-- ════════════════════════════════════════════════════════════

local C = {
	panelBg     = Color3.fromRGB(18, 18, 28),
	titleBg     = Color3.fromRGB(24, 24, 36),
	tabActive   = Color3.fromRGB(88, 101, 242),
	tabInactive = Color3.fromRGB(35, 35, 50),
	btn         = Color3.fromRGB(45, 45, 60),
	btnDanger   = Color3.fromRGB(192, 57, 43),
	btnSuccess  = Color3.fromRGB(39, 174, 96),
	btnWarn     = Color3.fromRGB(230, 126, 34),
	btnInfo     = Color3.fromRGB(41, 128, 185),
	btnPurple   = Color3.fromRGB(142, 68, 173),
	text        = Color3.new(1, 1, 1),
	textDim     = Color3.fromRGB(140, 140, 160),
	playerItem  = Color3.fromRGB(28, 28, 42),
	searchBg    = Color3.fromRGB(30, 30, 42),
	stroke      = Color3.fromRGB(55, 55, 75),
	close       = Color3.fromRGB(220, 50, 50),
	accent      = Color3.fromRGB(230, 126, 34),
}

local Z = 9400 -- ZIndex de base pour ce script

-- ════════════════════════════════════════════════════════════
-- RÔLE DU JOUEUR
-- ════════════════════════════════════════════════════════════

local myRole        = "Joueurs"
local rolesHierarchy = {}

local function refreshRole()
	if not getCmdsFunc then return end
	local ok, _, role, _, rH = pcall(function() return getCmdsFunc:InvokeServer() end)
	if ok then
		if type(role) == "string" then myRole = role end
		if type(rH) == "table" then rolesHierarchy = rH end
	end
end

local function getMyLevel() return rolesHierarchy[myRole] or 99 end
local function isMod() return getMyLevel() <= 4 end

-- Charger le rôle au démarrage
task.spawn(refreshRole)

-- ════════════════════════════════════════════════════════════
-- HELPERS UI
-- ════════════════════════════════════════════════════════════

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

local function stroke(p, col, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = col or C.stroke
	s.Thickness = thick or 1
	s.Transparency = trans or 0.4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end

local function makeBtn(txt, parent, size, pos, color, zidx)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Size = size or UDim2.new(0, 100, 0, 32)
	b.Position = pos or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = color or C.btn
	b.BackgroundTransparency = 0.1
	b.Text = txt
	b.TextColor3 = C.text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.ZIndex = zidx or Z
	corner(b, 6)
	stroke(b, Color3.new(0,0,0), 1, 0.5)
	return b
end

local function makeLabel(txt, parent, size, pos, fontSize, col, zidx)
	local l = Instance.new("TextLabel")
	l.Parent = parent
	l.Size = size or UDim2.new(1, 0, 0, 20)
	l.Position = pos or UDim2.new(0, 0, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = txt
	l.TextColor3 = col or C.textDim
	l.Font = Enum.Font.GothamBold
	l.TextSize = fontSize or 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = zidx or Z
	return l
end

local function makeDraggable(frame, bar)
	local dragging, dragStart, startPos = false, nil, nil
	bar = bar or frame
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local isMobile = (UIS.TouchEnabled and not UIS.KeyboardEnabled)

-- ════════════════════════════════════════════════════════════
-- BOUTON FLOTTANT (pour ouvrir le formulaire)
-- ════════════════════════════════════════════════════════════

local floatBtn = Instance.new("TextButton")
floatBtn.Parent = gui
floatBtn.Name = "TicketFloatBtn"
floatBtn.Size = UDim2.new(0, 44, 0, 44)
floatBtn.Position = UDim2.new(1, -56, 0.5, -50)
floatBtn.BackgroundColor3 = C.btnDanger
floatBtn.BackgroundTransparency = 0.1
floatBtn.Text = "!"
floatBtn.TextColor3 = C.text
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 22
floatBtn.BorderSizePixel = 0
floatBtn.ZIndex = 9000
floatBtn.Visible = false
corner(floatBtn, 22)
stroke(floatBtn, Color3.fromRGB(255, 120, 120), 2, 0.2)

-- ════════════════════════════════════════════════════════════
-- PANEL DE GESTION TICKETS (côté STAFF)
-- ════════════════════════════════════════════════════════════

local PANEL_W = 270
local PANEL_H = 460

local staffPanel = Instance.new("Frame")
staffPanel.Parent = gui
staffPanel.Name = "TicketStaffPanel"
if isMobile then
	staffPanel.Size = UDim2.new(0.88, 0, 0.75, 0)
	staffPanel.Position = UDim2.new(0.06, 0, 0.12, 0)
else
	staffPanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	staffPanel.Position = UDim2.new(0, 15, 0.5, -PANEL_H/2)
end
staffPanel.BackgroundColor3 = C.panelBg
staffPanel.BackgroundTransparency = 0.04
staffPanel.BorderSizePixel = 0
staffPanel.Visible = false
staffPanel.ZIndex = Z
staffPanel.ClipsDescendants = true
corner(staffPanel, 12)
stroke(staffPanel, C.tabActive, 1.5, 0.3)

-- Title bar
local staffTitleBar = Instance.new("Frame")
staffTitleBar.Parent = staffPanel
staffTitleBar.Size = UDim2.new(1, 0, 0, 40)
staffTitleBar.BackgroundColor3 = C.titleBg
staffTitleBar.BackgroundTransparency = 0.3
staffTitleBar.BorderSizePixel = 0
staffTitleBar.ZIndex = Z+1
corner(staffTitleBar, 12)

local titleIcon = makeLabel("TICKETS", staffTitleBar, UDim2.new(0, 80, 0, 16), UDim2.new(0, 14, 0, 3), 9, C.textDim, Z+2)
titleIcon.Font = Enum.Font.GothamMedium
local titleText = makeLabel("STAFF", staffTitleBar, UDim2.new(0, 80, 0, 22), UDim2.new(0, 14, 0, 16), 17, C.text, Z+2)
titleText.Font = Enum.Font.GothamBlack
titleText.TextYAlignment = Enum.TextYAlignment.Center

-- Bouton fermer
local closeBtn = makeBtn("X", staffPanel, UDim2.new(0, 26, 0, 26), UDim2.new(1, -34, 0, 7), C.close, Z+5)
corner(closeBtn, 13)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.MouseButton1Click:Connect(function()
	staffPanel.Visible = false
end)

makeDraggable(staffPanel, staffTitleBar)

-- ScrollingFrame pour les tickets
local ticketScroll = Instance.new("ScrollingFrame")
ticketScroll.Parent = staffPanel
ticketScroll.Size = UDim2.new(1, -20, 1, -55)
ticketScroll.Position = UDim2.new(0, 10, 0, 48)
ticketScroll.BackgroundTransparency = 1
ticketScroll.BorderSizePixel = 0
ticketScroll.ScrollBarThickness = 3
ticketScroll.ScrollBarImageColor3 = C.btnWarn
ticketScroll.ZIndex = Z+1
ticketScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ticketScroll.Visible = true

local ticketLayout = Instance.new("UIListLayout")
ticketLayout.Parent = ticketScroll
ticketLayout.Padding = UDim.new(0, 6)
ticketLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Badge non lus (affiché sur le floatBtn)
local badgeLabel = Instance.new("TextLabel")
badgeLabel.Parent = floatBtn
badgeLabel.Size = UDim2.new(0, 16, 0, 16)
badgeLabel.Position = UDim2.new(1, -8, 0, -4)
badgeLabel.BackgroundColor3 = C.tabActive
badgeLabel.Text = "0"
badgeLabel.TextColor3 = C.text
badgeLabel.Font = Enum.Font.GothamBlack
badgeLabel.TextSize = 9
badgeLabel.ZIndex = Z+5
badgeLabel.Visible = false
badgeLabel.BorderSizePixel = 0
corner(badgeLabel, 8)

local unreadCount = 0

-- ════════════════════════════════════════════════════════════
-- FUNCTION: buildTicketsTab — charge et affiche les tickets
-- ════════════════════════════════════════════════════════════

local function buildTicketsTab()
	-- Nettoyer
	for _, child in pairs(ticketScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	if not ticketListFunc then
		local err = makeLabel("Remote tickets introuvable", ticketScroll, UDim2.new(1,0,0,30), nil, 11, C.textDim, Z+2)
		err.LayoutOrder = 1
		err.TextXAlignment = Enum.TextXAlignment.Center
		return
	end

	local hdr = makeLabel("Tickets joueurs", ticketScroll, UDim2.new(1,0,0,22), nil, 12, C.text, Z+2)
	hdr.Font = Enum.Font.GothamBlack
	hdr.TextXAlignment = Enum.TextXAlignment.Center
	hdr.LayoutOrder = 1

	local refreshBtn = makeBtn("Rafraichir", ticketScroll, UDim2.new(1, 0, 0, 28), nil, C.btnInfo, Z+3)
	refreshBtn.TextSize = 11
	refreshBtn.LayoutOrder = 2
	refreshBtn.MouseButton1Click:Connect(function() buildTicketsTab() end)

	local ok, tickets = pcall(function() return ticketListFunc:InvokeServer() end)

	if ok and tickets and #tickets > 0 then
		-- Mise à jour badge
		unreadCount = #tickets
		badgeLabel.Text = tostring(unreadCount)
		badgeLabel.Visible = true

		for i, t in ipairs(tickets) do
			local tf = Instance.new("Frame")
			tf.Parent = ticketScroll
			tf.Size = UDim2.new(1, 0, 0, 80)
			tf.BackgroundColor3 = C.playerItem
			tf.BackgroundTransparency = 0.05
			tf.ZIndex = Z+3
			tf.LayoutOrder = 10 + i
			corner(tf, 6)
			stroke(tf, C.btnWarn, 1, 0.4)

			local info = Instance.new("TextLabel")
			info.Parent = tf
			info.Size = UDim2.new(0.58, 0, 1, -6)
			info.Position = UDim2.new(0.02, 0, 0, 3)
			info.BackgroundTransparency = 1
			info.Text = string.format("[%s] %s\nDe: %s  Cible: %s\n%s",
				t.Category or "?", t.Time or "?", t.Reporter or "?",
				(t.TargetName and t.TargetName ~= "") and t.TargetName or "-",
				string.sub(t.Description or "", 1, 80))
			info.TextColor3 = C.text
			info.Font = Enum.Font.Gotham
			info.TextSize = 9
			info.TextWrapped = true
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.TextYAlignment = Enum.TextYAlignment.Top
			info.ZIndex = Z+4

			-- Bouton TP au reporter
			local tpBtn = makeBtn("TP", tf, UDim2.new(0.18, 0, 0, 22), UDim2.new(0.60, 0, 0.08, 0), C.btnInfo, Z+5)
			tpBtn.TextSize = 10
			tpBtn.MouseButton1Click:Connect(function()
				if t.ReporterId then
					local target = Players:GetPlayerByUserId(t.ReporterId)
					if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
						local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if myRoot then
							if modTPEvent then modTPEvent:FireServer() end
							task.wait(0.05)
							myRoot.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
						end
					end
				end
			end)

			-- Bouton Zone Staff (convoquer)
			local zoneBtn = makeBtn("Zone", tf, UDim2.new(0.18, 0, 0, 22), UDim2.new(0.80, 0, 0.08, 0), C.btnPurple, Z+5)
			zoneBtn.TextSize = 10
			zoneBtn.MouseButton1Click:Connect(function()
				if t.ReporterId and modCamEvent then
					modCamEvent:FireServer("ZoneStaff", t.ReporterId)
				end
			end)

			-- Bouton Traiter (claim)
			local claimBtn = makeBtn("Traiter", tf, UDim2.new(0.38, 0, 0, 22), UDim2.new(0.60, 0, 0.55, 0), C.btnSuccess, Z+5)
			claimBtn.TextSize = 10
			claimBtn.MouseButton1Click:Connect(function()
				if ticketClaimEvent then ticketClaimEvent:FireServer(t.Id) end
				tf:Destroy()
			end)
		end
	else
		local empty = makeLabel("Aucun ticket en attente", ticketScroll, UDim2.new(1,0,0,30), nil, 11, C.textDim, Z+2)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.LayoutOrder = 10
		badgeLabel.Visible = false
	end
end

-- ════════════════════════════════════════════════════════════
-- FORMULAIRE TICKET JOUEUR (côté joueur)
-- ════════════════════════════════════════════════════════════

local playerTicketFrame = Instance.new("Frame")
playerTicketFrame.Parent = gui
playerTicketFrame.Name = "PlayerTicketFrame"
playerTicketFrame.Size = isMobile and UDim2.new(0.88, 0, 0, 0) or UDim2.new(0, 310, 0, 0)
playerTicketFrame.Position = isMobile and UDim2.new(0.06, 0, 0.15, 0) or UDim2.new(1, -375, 0.5, -170)
playerTicketFrame.BackgroundColor3 = C.panelBg
playerTicketFrame.BackgroundTransparency = 0.05
playerTicketFrame.BorderSizePixel = 0
playerTicketFrame.ZIndex = 9500
playerTicketFrame.Visible = false
playerTicketFrame.AutomaticSize = Enum.AutomaticSize.Y
corner(playerTicketFrame, 10)
stroke(playerTicketFrame, Color3.fromRGB(255, 120, 120), 2, 0.3)

local ptfLayout = Instance.new("UIListLayout")
ptfLayout.Parent = playerTicketFrame
ptfLayout.FillDirection = Enum.FillDirection.Vertical
ptfLayout.SortOrder = Enum.SortOrder.LayoutOrder
ptfLayout.Padding = UDim.new(0, 6)

local ptfPad = Instance.new("UIPadding")
ptfPad.Parent = playerTicketFrame
ptfPad.PaddingTop = UDim.new(0, 10)
ptfPad.PaddingBottom = UDim.new(0, 10)
ptfPad.PaddingLeft = UDim.new(0, 10)
ptfPad.PaddingRight = UDim.new(0, 10)

local function ptfMakeLabel(txt, h, col, lo)
	local l = Instance.new("TextLabel")
	l.Parent = playerTicketFrame
	l.Size = UDim2.new(1, 0, 0, h)
	l.BackgroundTransparency = 1
	l.Text = txt
	l.TextColor3 = col or C.text
	l.Font = Enum.Font.GothamBold
	l.TextSize = 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 9501
	l.LayoutOrder = lo
	return l
end

local ptfTitle = ptfMakeLabel("! Contacter le Staff", 22, C.text, 1)
ptfTitle.Font = Enum.Font.GothamBlack
ptfTitle.TextSize = 14
ptfTitle.TextXAlignment = Enum.TextXAlignment.Center

ptfMakeLabel("Un probleme ? Un joueur triche ou se comporte mal ?", 16, C.textDim, 2).TextSize = 10

ptfMakeLabel("Categorie :", 14, C.textDim, 3).TextSize = 10

local ptfCatBox = Instance.new("TextBox")
ptfCatBox.Parent = playerTicketFrame
ptfCatBox.Size = UDim2.new(1, 0, 0, 28)
ptfCatBox.BackgroundColor3 = C.searchBg
ptfCatBox.TextColor3 = C.text
ptfCatBox.PlaceholderText = "ex: Probleme, Question, Signalement..."
ptfCatBox.PlaceholderColor3 = C.textDim
ptfCatBox.Text = ""
ptfCatBox.Font = Enum.Font.Gotham
ptfCatBox.TextSize = 11
ptfCatBox.ZIndex = 9502
ptfCatBox.LayoutOrder = 4
ptfCatBox.ClearTextOnFocus = false
corner(ptfCatBox, 6)
stroke(ptfCatBox, C.stroke, 1, 0.4)

ptfMakeLabel("Joueur a signaler (facultatif) :", 14, C.textDim, 5).TextSize = 10

local ptfTargetBox = Instance.new("TextBox")
ptfTargetBox.Parent = playerTicketFrame
ptfTargetBox.Size = UDim2.new(1, 0, 0, 28)
ptfTargetBox.BackgroundColor3 = C.searchBg
ptfTargetBox.TextColor3 = C.text
ptfTargetBox.PlaceholderText = "Nom exact du joueur (laisser vide si aucun)"
ptfTargetBox.PlaceholderColor3 = C.textDim
ptfTargetBox.Text = ""
ptfTargetBox.Font = Enum.Font.Gotham
ptfTargetBox.TextSize = 11
ptfTargetBox.ZIndex = 9502
ptfTargetBox.LayoutOrder = 6
ptfTargetBox.ClearTextOnFocus = false
corner(ptfTargetBox, 6)
stroke(ptfTargetBox, C.stroke, 1, 0.4)

ptfMakeLabel("Description :", 14, C.textDim, 7).TextSize = 10

local ptfDescBox = Instance.new("TextBox")
ptfDescBox.Parent = playerTicketFrame
ptfDescBox.Size = UDim2.new(1, 0, 0, 56)
ptfDescBox.BackgroundColor3 = C.searchBg
ptfDescBox.TextColor3 = C.text
ptfDescBox.PlaceholderText = "Decrivez votre probleme ou le comportement signale..."
ptfDescBox.PlaceholderColor3 = C.textDim
ptfDescBox.Text = ""
ptfDescBox.Font = Enum.Font.Gotham
ptfDescBox.TextSize = 11
ptfDescBox.TextWrapped = true
ptfDescBox.MultiLine = true
ptfDescBox.ZIndex = 9502
ptfDescBox.LayoutOrder = 8
ptfDescBox.ClearTextOnFocus = false
corner(ptfDescBox, 6)
stroke(ptfDescBox, C.stroke, 1, 0.4)

local ptfBtnRow = Instance.new("Frame")
ptfBtnRow.Parent = playerTicketFrame
ptfBtnRow.Size = UDim2.new(1, 0, 0, 32)
ptfBtnRow.BackgroundTransparency = 1
ptfBtnRow.ZIndex = 9501
ptfBtnRow.LayoutOrder = 9

local ptfCancel = makeBtn("Annuler", ptfBtnRow, UDim2.new(0.47, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.btn, 9502)
ptfCancel.TextSize = 11
ptfCancel.MouseButton1Click:Connect(function()
	playerTicketFrame.Visible = false
	ptfCatBox.Text = "" ptfTargetBox.Text = "" ptfDescBox.Text = ""
end)

local ptfSend = makeBtn("Envoyer au Staff", ptfBtnRow, UDim2.new(0.47, 0, 1, 0), UDim2.new(0.53, 0, 0, 0), C.btnSuccess, 9502)
ptfSend.TextSize = 10
ptfSend.Font = Enum.Font.GothamBlack
ptfSend.MouseButton1Click:Connect(function()
	local cat  = ptfCatBox.Text
	local desc = ptfDescBox.Text
	if cat == "" or desc == "" then
		ptfTitle.Text = "Remplis tous les champs !"
		ptfTitle.TextColor3 = C.btnDanger
		task.delay(2, function()
			ptfTitle.Text = "! Contacter le Staff"
			ptfTitle.TextColor3 = C.text
		end)
		return
	end
	local ticketData = {
		Category    = cat,
		Description = desc,
		TargetName  = (ptfTargetBox.Text ~= "") and ptfTargetBox.Text or nil,
	}
	pcall(function()
		if ticketSubmitEvent then ticketSubmitEvent:FireServer(ticketData) end
	end)
	playerTicketFrame.Visible = false
	ptfCatBox.Text = "" ptfTargetBox.Text = "" ptfDescBox.Text = ""
	ptfTitle.Text = "Ticket envoye au staff !"
	ptfTitle.TextColor3 = C.btnSuccess
	task.delay(2.5, function()
		ptfTitle.Text = "! Contacter le Staff"
		ptfTitle.TextColor3 = C.text
	end)
end)

-- ════════════════════════════════════════════════════════════
-- FLOATBTN CLICK — ouvre formulaire (joueurs) ou panel staff
-- ════════════════════════════════════════════════════════════

floatBtn.MouseButton1Click:Connect(function()
	if isMod() then
		-- Staff: ouvre le panel de gestion
		staffPanel.Visible = not staffPanel.Visible
		if staffPanel.Visible then
			buildTicketsTab()
		end
	else
		-- Joueur: ouvre le formulaire
		playerTicketFrame.Visible = not playerTicketFrame.Visible
	end
end)

-- ════════════════════════════════════════════════════════════
-- ALERTES TICKETS (côté staff uniquement — bleu semi-transparent)
-- ════════════════════════════════════════════════════════════

-- Conteneur partagé avec les alertes AC (s'il existe déjà) ou propre
local alertContainer = gui:FindFirstChild("ACAlerts")
if not alertContainer then
	alertContainer = Instance.new("Frame")
	alertContainer.Parent = gui
	alertContainer.Name = "ACAlerts"
	alertContainer.Size = UDim2.new(0, 340, 0, 140)
	alertContainer.Position = UDim2.new(1, -350, 0, 10)
	alertContainer.BackgroundTransparency = 1
	alertContainer.ZIndex = 99000
	alertContainer.ClipsDescendants = false

	local alertLayout = Instance.new("UIListLayout")
	alertLayout.Parent = alertContainer
	alertLayout.Padding = UDim.new(0, 6)
	alertLayout.SortOrder = Enum.SortOrder.LayoutOrder
	alertLayout.FillDirection = Enum.FillDirection.Vertical
	alertLayout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local alertCount = 0

if ticketAlertEvent then
	ticketAlertEvent.OnClientEvent:Connect(function(data)
		-- Mettre à jour le badge sur le floatBtn (staff)
		unreadCount = unreadCount + 1
		badgeLabel.Text = tostring(unreadCount)
		badgeLabel.Visible = true

		-- Alerte bleue semi-transparente
		alertCount = alertCount + 1
		local alert = Instance.new("TextButton")
		alert.Parent = alertContainer
		alert.Size = UDim2.new(1, 0, 0, 50)
		alert.BackgroundColor3 = Color3.fromRGB(30, 80, 200)
		alert.BackgroundTransparency = 0.35
		alert.BorderSizePixel = 0
		alert.ZIndex = 99005
		alert.AutoButtonColor = false
		alert.Text = ""
		alert.LayoutOrder = alertCount + 1000

		corner(alert, 10)

		local txt = Instance.new("TextLabel")
		txt.Parent = alert
		txt.Size = UDim2.new(1, -16, 1, -6)
		txt.Position = UDim2.new(0, 8, 0, 3)
		txt.BackgroundTransparency = 1
		txt.Text = string.format("TICKET: %s\nDe: %s — %s",
			data.Category or "?",
			data.Reporter or "?",
			string.sub(data.Description or "", 1, 50))
		txt.TextColor3 = Color3.new(1, 1, 1)
		txt.Font = Enum.Font.GothamBold
		txt.TextSize = 11
		txt.TextWrapped = true
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.TextYAlignment = Enum.TextYAlignment.Center
		txt.ZIndex = 99010

		-- Clic = ouvre le panel staff
		alert.MouseButton1Click:Connect(function()
			staffPanel.Visible = true
			buildTicketsTab()
			alert:Destroy()
		end)

		-- Slide in
		alert.Position = UDim2.new(1, 50, 0, 0)
		TweenService:Create(alert, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Position = UDim2.new(0, 0, 0, 0)}):Play()

		-- Auto-dismiss après 30s
		task.delay(30, function()
			if alert and alert.Parent then
				TweenService:Create(alert, TweenInfo.new(0.4),
					{Position = UDim2.new(1, 50, 0, 0)}):Play()
				task.wait(0.5)
				if alert and alert.Parent then alert:Destroy() end
			end
		end)
	end)
end

-- ════════════════════════════════════════════════════════════
-- INIT — afficher le bouton flottant après chargement du rôle
-- ════════════════════════════════════════════════════════════

task.spawn(function()
	task.wait(2) -- attendre que getCmdsFunc soit prêt
	refreshRole()
	-- Afficher le bouton pour tout le monde
	floatBtn.Visible = true
end)
