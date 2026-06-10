local _rs = game:GetService("ReplicatedStorage")
local _remotes = _rs:WaitForChild("SystemRemotes", 15)

if _remotes then

	local _checkFunc = _remotes:WaitForChild("PremiumCheckFunc", 10)

	if _checkFunc then

		local ok, isPremium = pcall(function() return _checkFunc:InvokeServer() end)

		if not ok or not isPremium then

			script:Destroy()

			return

		end

	else

		script:Destroy()

		return

	end

else

	script:Destroy()

	return

end

-- ══ PREMIUM CONFIRMÉ — chargement du ModMenu ══



local Players           = game:GetService("Players")



local UIS               = game:GetService("UserInputService")



local TweenService      = game:GetService("TweenService")



local RS                = game:GetService("ReplicatedStorage")



local RunService        = game:GetService("RunService")



local SoundService      = game:GetService("SoundService")







local player = Players.LocalPlayer



local camera = workspace.CurrentCamera



local gui    = script:FindFirstAncestorOfClass("ScreenGui")



if not gui then return end



gui.ResetOnSpawn = false







-- ── REMOTES ──



local remotes = RS:WaitForChild("SystemRemotes", 30)



if not remotes then return end







local function safeRemote(name, t)



	return remotes:WaitForChild(name, t or 15)



end







local getCmdsFunc       = safeRemote("GetCmdsFunc")



local cmdBarEvent       = safeRemote("CmdBarEvent")



local ticketSubmitEvent = safeRemote("TicketSubmitEvent")



local ticketListFunc    = safeRemote("TicketListFunc")



local ticketClaimEvent  = safeRemote("TicketClaimEvent")



local modCamEvent       = safeRemote("ModCamEvent")



local notifEvent        = safeRemote("NotifEvent")



local ticketAlertEvent  = safeRemote("TicketAlertEvent")

local modTPEvent        = safeRemote("ModTPEvent")







-- ── COULEURS ──



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



	barYellow   = Color3.fromRGB(241, 196, 15),



	barOrange   = Color3.fromRGB(230, 126, 34),



	barDark     = Color3.fromRGB(44, 62, 80),



}







-- ── ROLE SYSTEM ──

local myRole = "Joueurs"

local rolesHierarchy = {}

local playerZoneState = {}  -- [userId]=true si joueur actuellement en zone staff







local function refreshRole()



	local ok, _, role, _, rH = pcall(function() return getCmdsFunc:InvokeServer() end)



	if ok then



		if type(role) == "string" then myRole = role end



		if type(rH) == "table" then rolesHierarchy = rH end



	end



end



local function getMyLevel() return rolesHierarchy[myRole] or 99 end



local function isMod() return getMyLevel() <= 4 end







-- ── HELPERS ──



local function silentCmd(cmd)



	-- [FIX] Marquer l'exemption AC avant d'envoyer la commande (évite faux positifs)

	local char = player.Character

	if char then

		char:SetAttribute("_ACExempt", tick())

	end



	if cmdBarEvent then cmdBarEvent:FireServer(cmd) end



end







local function playSfx(id, vol)



	local s = Instance.new("Sound")



	s.Parent = SoundService



	s.SoundId = "rbxassetid://"..tostring(id)



	s.Volume = vol or 0.5



	s:Play()



	game:GetService("Debris"):AddItem(s, 2)



end







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



	b.ZIndex = zidx or 100



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



	l.ZIndex = zidx or 100



	return l



end







local function makeDraggable(frame, bar)



	local dragging, dragStart, startPos = false, nil, nil



	bar = bar or frame



	bar.InputBegan:Connect(function(input)



		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then



			dragging = true dragStart = input.Position startPos = frame.Position



			input.Changed:Connect(function()



				if input.UserInputState == Enum.UserInputState.End then dragging = false end



			end)



		end



	end)



	UIS.InputChanged:Connect(function(input)



		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then



			local delta = input.Position - dragStart



			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)



		end



	end)



end







-- ═══════════════════════════════════════════



-- STATE



-- ═══════════════════════════════════════════



local isModCam       = false



local isEspOn        = false



local isOnService    = false



local selectedPlayer = nil  -- Player object or nil



local modCamLoop     = nil



local modCamConns    = {}



local espFolder      = nil







-- ═══════════════════════════════════════════



-- TOGGLE BUTTON (gauche, petit)



-- ═══════════════════════════════════════════



local toggleBtn = Instance.new("TextButton")



toggleBtn.Parent = gui



toggleBtn.Name = "StaffToggle"



toggleBtn.Size = UDim2.new(0, 44, 0, 44)



toggleBtn.Position = UDim2.new(1, -56, 0.5, 2)



toggleBtn.BackgroundColor3 = C.tabActive



toggleBtn.BackgroundTransparency = 0.1



toggleBtn.Text = "S"



toggleBtn.TextColor3 = C.text



toggleBtn.Font = Enum.Font.GothamBlack



toggleBtn.TextSize = 18



toggleBtn.BorderSizePixel = 0



toggleBtn.ZIndex = 9000



toggleBtn.Visible = false



corner(toggleBtn, 22)



stroke(toggleBtn, Color3.fromRGB(80, 120, 255), 2, 0.15)







-- ═══════════════════════════════════════════



-- PANEL FRAME



-- ═══════════════════════════════════════════



local PANEL_W = 260

local PANEL_H = 500

local Z = 300 -- base ZIndex



-- Mobile responsive

local isMobile = (UIS.TouchEnabled and not UIS.KeyboardEnabled)



local panel = Instance.new("Frame")

panel.Parent = gui

panel.Name = "PanelStaff"

if isMobile then

	panel.Size = UDim2.new(0.88, 0, 0.75, 0)

	panel.Position = UDim2.new(0.06, 0, 0.12, 0)

else

	panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)

	panel.Position = UDim2.new(0, 15, 0.5, -PANEL_H/2)

end



panel.BackgroundColor3 = C.panelBg



panel.BackgroundTransparency = 0.04



panel.BorderSizePixel = 0



panel.Visible = false



panel.ZIndex = Z



panel.ClipsDescendants = true



corner(panel, 12)



stroke(panel, C.tabActive, 1.5, 0.3)







-- Title bar



local titleBar = Instance.new("Frame")



titleBar.Parent = panel



titleBar.Size = UDim2.new(1, 0, 0, 40)



titleBar.BackgroundColor3 = C.titleBg



titleBar.BackgroundTransparency = 0.3



titleBar.BorderSizePixel = 0



titleBar.ZIndex = Z+1



corner(titleBar, 12)







local titleIcon = makeLabel("PANEL", titleBar, UDim2.new(0, 50, 0, 40), UDim2.new(0, 12, 0, 0), 11, C.textDim, Z+2)



titleIcon.Font = Enum.Font.GothamMedium



local titleText = makeLabel("STAFF", titleBar, UDim2.new(0, 100, 0, 40), UDim2.new(0, 12, 0, 0), 17, C.text, Z+2)



titleText.Font = Enum.Font.GothamBlack



titleText.TextYAlignment = Enum.TextYAlignment.Center



-- Combine: icon above, title below



titleIcon.Size = UDim2.new(0, 60, 0, 16)



titleIcon.Position = UDim2.new(0, 14, 0, 3)



titleIcon.TextSize = 9



titleText.Position = UDim2.new(0, 14, 0, 16)



titleText.Size = UDim2.new(0, 80, 0, 22)







local closeBtn = makeBtn("X", panel, UDim2.new(0, 26, 0, 26), UDim2.new(1, -34, 0, 7), C.close, Z+5)



corner(closeBtn, 13)



closeBtn.TextSize = 14



closeBtn.Font = Enum.Font.GothamBlack



closeBtn.MouseButton1Click:Connect(function()



	panel.Visible = false



	playSfx(6895079853, 0.3)



end)







makeDraggable(panel, titleBar)







-- ── TABS ──



local tabFrame = Instance.new("Frame")



tabFrame.Parent = panel



tabFrame.Size = UDim2.new(1, -20, 0, 30)



tabFrame.Position = UDim2.new(0, 10, 0, 44)



tabFrame.BackgroundTransparency = 1



tabFrame.ZIndex = Z+1







local tabProfil = makeBtn("Profil", tabFrame, UDim2.new(0.23, 0, 1, 0), UDim2.new(0, 0, 0, 0), C.tabActive, Z+3)



tabProfil.TextSize = 10



local tabJoueurs = makeBtn("Joueurs", tabFrame, UDim2.new(0.23, 0, 1, 0), UDim2.new(0.26, 0, 0, 0), C.tabInactive, Z+3)



tabJoueurs.TextSize = 10



local tabTickets = makeBtn("Tickets", tabFrame, UDim2.new(0.23, 0, 1, 0), UDim2.new(0.51, 0, 0, 0), C.tabInactive, Z+3)



tabTickets.TextSize = 10







-- Badge tickets non lus



local ticketBadge = Instance.new("TextLabel")



ticketBadge.Parent = tabTickets



ticketBadge.Size = UDim2.new(0, 16, 0, 16)



ticketBadge.Position = UDim2.new(1, -8, 0, -4)



ticketBadge.BackgroundColor3 = C.btnDanger



ticketBadge.Text = "0"



ticketBadge.TextColor3 = C.text



ticketBadge.Font = Enum.Font.GothamBlack



ticketBadge.TextSize = 9



ticketBadge.ZIndex = Z+5



ticketBadge.Visible = false



corner(ticketBadge, 8)







-- Content frames



local contentSize = UDim2.new(1, -20, 1, -125)



local contentPos = UDim2.new(0, 10, 0, 80)







local contentProfil = Instance.new("ScrollingFrame")



contentProfil.Parent = panel



contentProfil.Size = contentSize



contentProfil.Position = contentPos



contentProfil.BackgroundTransparency = 1



contentProfil.BorderSizePixel = 0



contentProfil.ScrollBarThickness = 3



contentProfil.ScrollBarImageColor3 = C.tabActive



contentProfil.ZIndex = Z+1



contentProfil.AutomaticCanvasSize = Enum.AutomaticSize.Y



contentProfil.Visible = true



local profilLayout = Instance.new("UIListLayout")



profilLayout.Parent = contentProfil



profilLayout.Padding = UDim.new(0, 6)



profilLayout.SortOrder = Enum.SortOrder.LayoutOrder







local contentJoueurs = Instance.new("Frame")



contentJoueurs.Parent = panel



contentJoueurs.Size = contentSize



contentJoueurs.Position = contentPos



contentJoueurs.BackgroundTransparency = 1



contentJoueurs.BorderSizePixel = 0



contentJoueurs.ZIndex = Z+1



contentJoueurs.Visible = false







local contentTickets = Instance.new("ScrollingFrame")



contentTickets.Parent = panel



contentTickets.Size = contentSize



contentTickets.Position = contentPos



contentTickets.BackgroundTransparency = 1



contentTickets.BorderSizePixel = 0



contentTickets.ScrollBarThickness = 3



contentTickets.ScrollBarImageColor3 = C.btnWarn



contentTickets.ZIndex = Z+1



contentTickets.AutomaticCanvasSize = Enum.AutomaticSize.Y



contentTickets.Visible = false



local ticketsLayout = Instance.new("UIListLayout")



ticketsLayout.Parent = contentTickets



ticketsLayout.Padding = UDim.new(0, 6)



ticketsLayout.SortOrder = Enum.SortOrder.LayoutOrder







local currentTab = "profil"



local function switchTab(tab)



	currentTab = tab



	contentProfil.Visible = (tab == "profil")



	contentJoueurs.Visible = (tab == "joueurs")



	contentTickets.Visible = (tab == "tickets")



	tabProfil.BackgroundColor3 = (tab == "profil") and C.tabActive or C.tabInactive



	tabJoueurs.BackgroundColor3 = (tab == "joueurs") and C.tabActive or C.tabInactive



	tabTickets.BackgroundColor3 = (tab == "tickets") and C.tabActive or C.tabInactive



	playSfx(6895079853, 0.2)



end



tabProfil.MouseButton1Click:Connect(function() switchTab("profil") end)



tabJoueurs.MouseButton1Click:Connect(function() switchTab("joueurs") end)



tabTickets.MouseButton1Click:Connect(function() switchTab("tickets") end)







-- ── BOTTOM BAR (couleurs décoratives) ──



local barFrame = Instance.new("Frame")



barFrame.Parent = panel



barFrame.Size = UDim2.new(1, -20, 0, 8)



barFrame.Position = UDim2.new(0, 10, 1, -45)



barFrame.BackgroundTransparency = 1



barFrame.ZIndex = Z+1



barFrame.ClipsDescendants = true



corner(barFrame, 4)







local bar1 = Instance.new("Frame") bar1.Parent = barFrame bar1.Size = UDim2.new(0.33,0,1,0) bar1.Position = UDim2.new(0,0,0,0)



bar1.BackgroundColor3 = C.barYellow bar1.BorderSizePixel = 0 bar1.ZIndex = Z+2



local bar2 = Instance.new("Frame") bar2.Parent = barFrame bar2.Size = UDim2.new(0.33,0,1,0) bar2.Position = UDim2.new(0.33,0,0,0)



bar2.BackgroundColor3 = C.barOrange bar2.BorderSizePixel = 0 bar2.ZIndex = Z+2



local bar3 = Instance.new("Frame") bar3.Parent = barFrame bar3.Size = UDim2.new(0.34,0,1,0) bar3.Position = UDim2.new(0.66,0,0,0)



bar3.BackgroundColor3 = C.barDark bar3.BorderSizePixel = 0 bar3.ZIndex = Z+2







-- ── DISCORD BUTTON (bottom) ──



local discordBtn = makeBtn("D", panel, UDim2.new(0, 34, 0, 28), UDim2.new(0, 10, 1, -32), C.accent, Z+3)



discordBtn.TextSize = 16



discordBtn.Font = Enum.Font.GothamBlack



discordBtn.MouseButton1Click:Connect(function()



	silentCmd("feedback Ouvert depuis le panel staff")



	playSfx(6895079853, 0.3)



end)







-- ═══════════════════════════════════════════



-- TAB: MON PROFIL



-- ═══════════════════════════════════════════



local function addSection(title, order)



	local header = Instance.new("TextLabel")



	header.Parent = contentProfil



	header.Size = UDim2.new(1, 0, 0, 22)



	header.BackgroundTransparency = 1



	header.Text = title



	header.TextColor3 = C.textDim



	header.Font = Enum.Font.GothamBold



	header.TextSize = 11



	header.TextXAlignment = Enum.TextXAlignment.Center



	header.ZIndex = Z+2



	header.LayoutOrder = order



	return header



end







local function addBtnRow(btns, order)



	local row = Instance.new("Frame")



	row.Parent = contentProfil



	row.Size = UDim2.new(1, 0, 0, 34)



	row.BackgroundTransparency = 1



	row.ZIndex = Z+1



	row.LayoutOrder = order







	local count = #btns



	local gap = 6



	for i, info in ipairs(btns) do



		local w = (1 / count) - (gap * (count-1) / count / PANEL_W)



		local x = (i-1) / count



		local b = makeBtn(info.text, row, UDim2.new(w, -2, 1, 0), UDim2.new(x, 1, 0, 0), info.color or C.btn, Z+3)



		b.TextSize = info.textSize or 11



		if info.onClick then b.MouseButton1Click:Connect(info.onClick) end



		if info.ref then info.ref(b) end



	end



	return row



end







-- Section: Moderation



addSection("Moderation", 1)







local modCamBtnRef, serviceBtnRef



addBtnRow({



	{text = "Mod Cam (=)", color = C.btnInfo, onClick = function()



		panel.Visible = false



		if isModCam then exitModCamFn() else enterModCamFn() end



	end},



	{text = "Service", color = C.btn, ref = function(b) serviceBtnRef = b end, onClick = function()



		isOnService = not isOnService



		if serviceBtnRef then



			serviceBtnRef.BackgroundColor3 = isOnService and C.btnSuccess or C.btn



			serviceBtnRef.Text = isOnService and "EN SERVICE" or "Service"



		end



		player:SetAttribute("OnService", isOnService)



	end},



}, 2)







addBtnRow({



	{text = "Zone Staff", color = C.btnPurple, onClick = function()



		if modCamEvent then



			local targetId = selectedPlayer and selectedPlayer.UserId or nil



			modCamEvent:FireServer("ZoneStaff", targetId)



		end



		panel.Visible = false



	end},



}, 3)







-- Section: Utilitaires



addSection("Utilitaires", 10)







-- Annonce row



local announceInput = nil



local announceRow = Instance.new("Frame")



announceRow.Parent = contentProfil



announceRow.Size = UDim2.new(1, 0, 0, 34)



announceRow.BackgroundTransparency = 1



announceRow.ZIndex = Z+1



announceRow.LayoutOrder = 11



announceRow.Visible = false







local aInput = Instance.new("TextBox")



aInput.Parent = announceRow



aInput.Size = UDim2.new(0.65, -4, 1, 0)



aInput.Position = UDim2.new(0, 0, 0, 0)



aInput.BackgroundColor3 = C.searchBg



aInput.TextColor3 = C.text



aInput.PlaceholderText = "Message..."



aInput.PlaceholderColor3 = C.textDim



aInput.Text = ""



aInput.Font = Enum.Font.Gotham



aInput.TextSize = 12



aInput.ZIndex = Z+3



aInput.ClipsDescendants = true



corner(aInput, 6)



stroke(aInput, C.stroke, 1, 0.4)







local aSend = makeBtn("Envoyer", announceRow, UDim2.new(0.33, 0, 1, 0), UDim2.new(0.67, 0, 0, 0), C.btnSuccess, Z+3)



aSend.TextSize = 11



aSend.MouseButton1Click:Connect(function()



	if #aInput.Text > 0 then



		silentCmd("m "..aInput.Text)



		aInput.Text = ""



		announceRow.Visible = false



	end



end)







addBtnRow({



	{text = "Annonce", color = C.btnWarn, onClick = function()



		announceRow.Visible = not announceRow.Visible



	end},



	{text = "Esp (G)", color = C.btn, onClick = function()



		toggleEspFn()



	end},



}, 12)







addBtnRow({



	{text = "Refresh", color = C.btn, onClick = function() silentCmd("refresh") end},



	{text = "Respawn", color = C.btn, onClick = function() silentCmd("respawn") end},



}, 13)







-- Fly(V) supprimé — utiliser ModCam (=) uniquement







-- ═══════════════════════════════════════════



-- TAB: JOUEURS



-- ═══════════════════════════════════════════







-- State: list view vs selected view



local listView = Instance.new("Frame")



listView.Parent = contentJoueurs



listView.Size = UDim2.new(1, 0, 1, 0)



listView.BackgroundTransparency = 1



listView.ZIndex = Z+1







local selectedView = Instance.new("Frame")



selectedView.Parent = contentJoueurs



selectedView.Size = UDim2.new(1, 0, 1, 0)



selectedView.BackgroundTransparency = 1



selectedView.ZIndex = Z+1



selectedView.Visible = false







-- ── LIST VIEW ──



local searchBox = Instance.new("TextBox")



searchBox.Parent = listView



searchBox.Size = UDim2.new(1, 0, 0, 30)



searchBox.Position = UDim2.new(0, 0, 0, 0)



searchBox.BackgroundColor3 = C.searchBg



searchBox.TextColor3 = C.text



searchBox.PlaceholderText = "Nom d'utilisateur..."



searchBox.PlaceholderColor3 = C.textDim



searchBox.Text = ""



searchBox.Font = Enum.Font.Gotham



searchBox.TextSize = 12



searchBox.ZIndex = Z+3



searchBox.ClipsDescendants = true



corner(searchBox, 6)



stroke(searchBox, C.stroke, 1, 0.4)







local playerCountLabel = makeLabel("LISTE DES JOUEURS (0/0)", listView,



	UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 34), 10, C.textDim, Z+2)







local playerScroll = Instance.new("ScrollingFrame")



playerScroll.Parent = listView



playerScroll.Size = UDim2.new(1, 0, 1, -58)



playerScroll.Position = UDim2.new(0, 0, 0, 58)



playerScroll.BackgroundTransparency = 1



playerScroll.BorderSizePixel = 0



playerScroll.ScrollBarThickness = 3



playerScroll.ScrollBarImageColor3 = C.tabActive



playerScroll.ZIndex = Z+2



playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y







local playerLayout = Instance.new("UIListLayout")



playerLayout.Parent = playerScroll



playerLayout.Padding = UDim.new(0, 4)



playerLayout.SortOrder = Enum.SortOrder.LayoutOrder







local function selectPlayer(p)



	selectedPlayer = p



	listView.Visible = false



	selectedView.Visible = true



	-- Clear and rebuild selected view



	for _, child in pairs(selectedView:GetChildren()) do child:Destroy() end







	-- Back button



	local backBtn = makeBtn("< Retour", selectedView, UDim2.new(0.4, 0, 0, 28), UDim2.new(0, 0, 0, 0), C.btn, Z+3)



	backBtn.TextSize = 11



	backBtn.MouseButton1Click:Connect(function()



		selectedPlayer = nil



		selectedView.Visible = false



		listView.Visible = true



	end)







	-- Player name



	local pName = makeLabel(p.Name, selectedView, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 34), 14, C.text, Z+3)



	pName.Font = Enum.Font.GothamBlack



	pName.TextXAlignment = Enum.TextXAlignment.Center







	local pId = makeLabel("ID: "..p.UserId, selectedView, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 56), 10, C.textDim, Z+3)



	pId.TextXAlignment = Enum.TextXAlignment.Center







	-- Role badge



	local pRole = p:GetAttribute("Role") or "Joueurs"



	local pBadge = makeLabel("["..pRole.."]", selectedView, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 72), 10, C.btnInfo, Z+3)



	pBadge.TextXAlignment = Enum.TextXAlignment.Center







	-- Section header



	makeLabel("Moderation", selectedView, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 96), 11, C.textDim, Z+3).TextXAlignment = Enum.TextXAlignment.Center







	-- Frames : actions normales vs saisie raison



	local actionsFrame = Instance.new("Frame")



	actionsFrame.Parent = selectedView



	actionsFrame.Size = UDim2.new(1, 0, 0, 200)



	actionsFrame.Position = UDim2.new(0, 0, 0, 120)



	actionsFrame.BackgroundTransparency = 1



	actionsFrame.ZIndex = Z+1







	local reasonFrame = Instance.new("Frame")



	reasonFrame.Parent = selectedView



	reasonFrame.Size = UDim2.new(1, 0, 0, 220)



	reasonFrame.Position = UDim2.new(0, 0, 0, 96)



	reasonFrame.BackgroundTransparency = 1



	reasonFrame.ZIndex = Z+1



	reasonFrame.Visible = false







	local function showReasonPrompt(cmdType)



		actionsFrame.Visible = false



		reasonFrame.Visible = true



		-- Nettoyer le contenu precedent



		for _, child in pairs(reasonFrame:GetChildren()) do child:Destroy() end







		local titleTxt = (cmdType == "kick") and "KICK" or (cmdType == "ban") and "BAN" or (cmdType == "pban") and "BAN PERMANENT" or "?"



		local titleColor = (cmdType == "kick") and C.btnDanger or C.btnWarn







		makeLabel(titleTxt.." — "..p.Name, reasonFrame, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), 13, titleColor, Z+3).Font = Enum.Font.GothamBlack







		local yOff = 28







		-- Duree (seulement pour ban)



		local durationInput = nil



		if cmdType == "ban" then



			makeLabel("Duree (minutes):", reasonFrame, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, yOff), 10, C.textDim, Z+3)



			yOff = yOff + 18



			durationInput = Instance.new("TextBox")



			durationInput.Parent = reasonFrame



			durationInput.Size = UDim2.new(1, 0, 0, 28)



			durationInput.Position = UDim2.new(0, 0, 0, yOff)



			durationInput.BackgroundColor3 = C.searchBg



			durationInput.TextColor3 = C.text



			durationInput.Text = "60"



			durationInput.PlaceholderText = "60"



			durationInput.PlaceholderColor3 = C.textDim



			durationInput.Font = Enum.Font.Gotham



			durationInput.TextSize = 12



			durationInput.ZIndex = Z+4



			corner(durationInput, 6)



			stroke(durationInput, C.stroke, 1, 0.4)



			yOff = yOff + 34



		end







		-- Raison



		makeLabel("Raison:", reasonFrame, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, yOff), 10, C.textDim, Z+3)



		yOff = yOff + 18



		local reasonInput = Instance.new("TextBox")



		reasonInput.Parent = reasonFrame



		reasonInput.Size = UDim2.new(1, 0, 0, 50)



		reasonInput.Position = UDim2.new(0, 0, 0, yOff)



		reasonInput.BackgroundColor3 = C.searchBg



		reasonInput.TextColor3 = C.text



		reasonInput.Text = ""



		reasonInput.PlaceholderText = "Raison..."



		reasonInput.PlaceholderColor3 = C.textDim



		reasonInput.Font = Enum.Font.Gotham



		reasonInput.TextSize = 12



		reasonInput.TextWrapped = true



		reasonInput.ClearTextOnFocus = false



		reasonInput.ZIndex = Z+4



		corner(reasonInput, 6)



		stroke(reasonInput, C.stroke, 1, 0.4)



		yOff = yOff + 58







		-- Boutons Annuler / Confirmer



		local cancelBtn = makeBtn("Annuler", reasonFrame, UDim2.new(0.47, 0, 0, 32), UDim2.new(0, 0, 0, yOff), C.btn, Z+4)



		cancelBtn.TextSize = 12



		cancelBtn.MouseButton1Click:Connect(function()



			reasonFrame.Visible = false



			actionsFrame.Visible = true



		end)







		local confirmBtn = makeBtn("Confirmer", reasonFrame, UDim2.new(0.47, 0, 0, 32), UDim2.new(0.53, 0, 0, yOff), (cmdType == "kick") and C.btnDanger or C.btnWarn, Z+4)



		confirmBtn.TextSize = 12



		confirmBtn.Font = Enum.Font.GothamBlack



		confirmBtn.MouseButton1Click:Connect(function()



			local reason = reasonInput.Text



			if reason == "" then reason = "Aucune raison" end







			if cmdType == "kick" then



				silentCmd("kick "..p.Name.." "..reason)



			elseif cmdType == "ban" then



				local dur = (durationInput and durationInput.Text) or "60"



				if tonumber(dur) == nil then dur = "60" end



				silentCmd("ban "..p.Name.." "..dur.." "..reason)



			elseif cmdType == "pban" then



				silentCmd("pban "..p.Name.." "..reason)



			end







			playSfx(2865227271, 0.5)



			-- Retour a la liste



			reasonFrame.Visible = false



			actionsFrame.Visible = true



			-- Retour a la liste joueurs apres 0.5s



			task.delay(0.5, function()



				selectedPlayer = nil



				selectedView.Visible = false



				listView.Visible = true



			end)



		end)



	end







	-- Boutons d'action (2 colonnes)



	local actions = {



		{text = "TP",    color = C.btnInfo,    y = 0,  cmd = function() silentCmd("tp "..p.Name) task.delay(0.25, function() silentCmd("bring "..p.Name) end) end},



		{text = "Bring", color = C.btnPurple,  y = 0,  col = 2, cmd = function() silentCmd("bring "..p.Name) end},



		{text = "Kick",  color = C.btnDanger,  y = 38, cmd = function() showReasonPrompt("kick") end},



		{text = "Ban",   color = C.btnWarn,    y = 38, col = 2, cmd = function() showReasonPrompt("ban") end},



		{text = "Warn",  color = C.btn,        y = 76, cmd = function() silentCmd("warn "..p.Name.." Avertissement") end},



		{text = "Jail",  color = C.btn,        y = 76, col = 2, cmd = function() silentCmd("jail "..p.Name) end},



		{text = "Unjail",     color = C.btnSuccess, y = 114, cmd = function() silentCmd("unjail "..p.Name) end},



		{text = "Zone Staff", color = C.btnPurple,  y = 114, col = 2, cmd = nil, zoneToggle = true},



		{text = "Ban Perm", color = C.btnDanger, y = 152, cmd = function() showReasonPrompt("pban") end},



		{text = "Unban",    color = C.btnSuccess, y = 152, col = 2, cmd = function() silentCmd("unban "..p.Name) end},



		-- [FIX] Bouton Ticket modérateur — ouvre un formulaire intégré dans le ModMenu

		{text = "Ticket", color = C.btnInfo, y = 190, cmd = nil, modTicket = true},



	}







	for _, a in ipairs(actions) do



		local xPos = (a.col == 2) and 0.52 or 0



		local w = 0.47



		local b = makeBtn(a.text, actionsFrame, UDim2.new(w, 0, 0, 32), UDim2.new(xPos, 0, 0, a.y), a.color, Z+3)



		b.TextSize = 12







		if a.zoneToggle then



			-- Bouton Zone Staff qui toggle vers "Remettre"



			-- Restaurer affichage si joueur deja en zone

			if playerZoneState[p.UserId] then b.Text = "Remettre" b.BackgroundColor3 = C.btnWarn end

			b.MouseButton1Click:Connect(function()



				if not playerZoneState[p.UserId] then

					-- [FIX] Envoyer uniquement le joueur cible en zone staff (pas le modérateur)

					if modCamEvent then modCamEvent:FireServer("ZoneStaffTarget", p.UserId) end

					playerZoneState[p.UserId] = true

					b.Text = "Remettre"

					b.BackgroundColor3 = C.btnWarn



				else



					-- [FIX] Retour du joueur reporté à sa position d'origine (pas le modérateur)

					if modCamEvent then modCamEvent:FireServer("ZoneStaffReturn", p.UserId) end

					playerZoneState[p.UserId] = nil

					b.Text = "Zone Staff"

					b.BackgroundColor3 = C.btnPurple



				end



				playSfx(6895079853, 0.3)



			end)



		elseif a.modTicket then



			-- [FIX] Bouton Ticket — formulaire intégré dans le panel mod (pas de panel externe)

			b.MouseButton1Click:Connect(function()

				playSfx(6895079853, 0.3)

				-- Cacher actionsFrame, afficher formulaire ticket modérateur

				actionsFrame.Visible = false

				-- Nettoyer et construire le formulaire dans reasonFrame (réutilisé)

				reasonFrame.Visible = true

				reasonFrame.Size = UDim2.new(1, 0, 0, 260)

				for _, child in pairs(reasonFrame:GetChildren()) do child:Destroy() end



				makeLabel("TICKET — "..p.Name, reasonFrame, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), 13, C.btnInfo, Z+3).Font = Enum.Font.GothamBlack



				makeLabel("Description de l'action :", reasonFrame, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 26), 10, C.textDim, Z+3)

				local ticketDescInput = Instance.new("TextBox")

				ticketDescInput.Parent = reasonFrame

				ticketDescInput.Size = UDim2.new(1, 0, 0, 48)

				ticketDescInput.Position = UDim2.new(0, 0, 0, 44)

				ticketDescInput.BackgroundColor3 = C.searchBg

				ticketDescInput.TextColor3 = C.text

				ticketDescInput.Text = ""

				ticketDescInput.PlaceholderText = "Décrivez la situation..."

				ticketDescInput.PlaceholderColor3 = C.textDim

				ticketDescInput.Font = Enum.Font.Gotham

				ticketDescInput.TextSize = 11

				ticketDescInput.TextWrapped = true

				ticketDescInput.ClearTextOnFocus = false

				ticketDescInput.ZIndex = Z+4

				corner(ticketDescInput, 6)

				stroke(ticketDescInput, C.stroke, 1, 0.4)



				-- Boutons d'action ticket

				local ticketActions = {

					{text = "Avertissement", color = C.btn,        cat = "Avertissement", y = 98},

					{text = "Ban Temp",      color = C.btnWarn,    cat = "Ban Temporaire", y = 98, col = 2},

					{text = "Ban Perm",      color = C.btnDanger,  cat = "Ban Permanent",  y = 136},

					{text = "Kick",          color = C.btnDanger,  cat = "Kick",           y = 136, col = 2},

				}

				local catSelected = nil

				local catBtns = {}

				for _, ta in ipairs(ticketActions) do

					local xp = (ta.col == 2) and 0.52 or 0

					local tb = makeBtn(ta.text, reasonFrame, UDim2.new(0.47, 0, 0, 28), UDim2.new(xp, 0, 0, ta.y), ta.color, Z+4)

					tb.TextSize = 10

					table.insert(catBtns, {btn=tb, cat=ta.cat})

					tb.MouseButton1Click:Connect(function()

						catSelected = ta.cat

						for _, cb in ipairs(catBtns) do

							cb.btn.BackgroundTransparency = (cb.cat == catSelected) and 0 or 0.3

						end

					end)

				end



				local yOff = 170

				local cancelBtn = makeBtn("Annuler", reasonFrame, UDim2.new(0.47, 0, 0, 30), UDim2.new(0, 0, 0, yOff), C.btn, Z+4)

				cancelBtn.TextSize = 11

				cancelBtn.MouseButton1Click:Connect(function()

					reasonFrame.Visible = false

					actionsFrame.Visible = true

				end)



				local sendBtn = makeBtn("Envoyer Ticket", reasonFrame, UDim2.new(0.47, 0, 0, 30), UDim2.new(0.53, 0, 0, yOff), C.btnSuccess, Z+4)

				sendBtn.TextSize = 10

				sendBtn.Font = Enum.Font.GothamBlack

				sendBtn.MouseButton1Click:Connect(function()

					local desc = ticketDescInput.Text

					if desc == "" then return end

					local ticketData = {

						Category    = catSelected or "Moderation",

						Description = desc,

						TargetName  = p.Name,

					}

					pcall(function()

						if ticketSubmitEvent then ticketSubmitEvent:FireServer(ticketData) end

					end)

					reasonFrame.Visible = false

					actionsFrame.Visible = true

					playSfx(6895079853, 0.4)

				end)

			end)



		elseif a.cmd then



			b.MouseButton1Click:Connect(function()



				a.cmd()



				playSfx(6895079853, 0.3)



			end)



		end



	end







	-- Color bar



	local roleBar = Instance.new("Frame")



	roleBar.Parent = actionsFrame



	roleBar.Size = UDim2.new(1, 0, 0, 6)



	roleBar.Position = UDim2.new(0, 0, 0, 230)



	roleBar.BackgroundColor3 = C.barYellow



	roleBar.BorderSizePixel = 0



	roleBar.ZIndex = Z+2



	corner(roleBar, 3)



end







local function refreshPlayerList()

	for _, child in pairs(playerScroll:GetChildren()) do

		if child:IsA("Frame") or (child:IsA("TextLabel") and child.Name == "Legend") then child:Destroy() end

	end



	-- Légende des boutons

	local legend = Instance.new("TextLabel")

	legend.Parent = playerScroll legend.Name = "Legend"

	legend.Size = UDim2.new(1, -6, 0, 18) legend.BackgroundTransparency = 1

	legend.Text = "🔒=Protégé"

	legend.TextColor3 = Color3.fromRGB(120, 120, 140) legend.Font = Enum.Font.Gotham

	legend.TextSize = 9 legend.ZIndex = Z + 5 legend.LayoutOrder = 0



	local allPlayers = Players:GetPlayers()



	local search = searchBox.Text:lower()



	local maxPlayers = 50 -- Roblox default



	pcall(function() maxPlayers = Players.MaxPlayers end)



	local count = 0







	for i, p in ipairs(allPlayers) do



		if search ~= "" and not p.Name:lower():find(search, 1, true) and not p.DisplayName:lower():find(search, 1, true) then



			continue



		end



		count = count + 1







		local pf = Instance.new("Frame")



		pf.Parent = playerScroll



		pf.Size = UDim2.new(1, 0, 0, 44)



		pf.BackgroundColor3 = C.playerItem



		pf.BackgroundTransparency = 0.05



		pf.ZIndex = Z+3



		pf.LayoutOrder = i



		corner(pf, 6)







		-- Player role



		local pRole = p:GetAttribute("Role") or "Joueurs"



		local pLevel = rolesHierarchy[pRole] or 99







		-- Display name + username



		local displayTxt = p.DisplayName



		if p.DisplayName ~= p.Name then



			displayTxt = p.DisplayName .. " (" .. p.Name .. ")"



		end



		local nameLabel = Instance.new("TextLabel")



		nameLabel.Parent = pf



		nameLabel.Size = UDim2.new(0.75, 0, 0, 22)



		nameLabel.Position = UDim2.new(0.03, 0, 0, 2)



		nameLabel.BackgroundTransparency = 1



		nameLabel.Text = displayTxt



		nameLabel.TextColor3 = (pLevel <= 1) and Color3.fromRGB(52,152,219) or ((pLevel <= 4) and Color3.fromRGB(135,206,250) or C.text)



		nameLabel.Font = Enum.Font.GothamBold



		nameLabel.TextSize = 11



		nameLabel.TextXAlignment = Enum.TextXAlignment.Left



		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd



		nameLabel.ZIndex = Z+4







		local idLabel = Instance.new("TextLabel")



		idLabel.Parent = pf



		idLabel.Size = UDim2.new(0.75, 0, 0, 16)



		idLabel.Position = UDim2.new(0.03, 0, 0, 24)



		idLabel.BackgroundTransparency = 1



		local roleColor = C.textDim

		if pLevel <= 1 then roleColor = Color3.fromRGB(52,152,219)      -- Fondateur = bleu

		elseif pLevel <= 2 then roleColor = Color3.fromRGB(230,126,34)  -- Gérant = orange

		elseif pLevel <= 3 then roleColor = Color3.fromRGB(155,89,182)  -- Staff = violet

		elseif pLevel <= 4 then roleColor = Color3.fromRGB(135,206,250) -- Modérateur = bleu pâle

		elseif pLevel <= 5 then roleColor = Color3.fromRGB(241,196,15)  -- VIP = doré

		end



		idLabel.Text = pRole

		idLabel.TextColor3 = roleColor

		idLabel.Font = Enum.Font.GothamBold

		idLabel.TextSize = 9



		idLabel.TextXAlignment = Enum.TextXAlignment.Left



		idLabel.ZIndex = Z+4







		-- Arrow button



		local arrowBtn = makeBtn(">", pf, UDim2.new(0, 34, 0, 34), UDim2.new(1, -40, 0.5, -17), C.btn, Z+5)



		arrowBtn.TextSize = 16



		arrowBtn.Font = Enum.Font.GothamBlack



		arrowBtn.MouseButton1Click:Connect(function()



			selectPlayer(p)



			playSfx(6895079853, 0.3)



		end)







		-- Role tag if staff



		if pLevel <= 5 and pLevel >= 1 then



			local tags = {[1]="Fondateur", [2]="Gerant", [3]="Staff", [4]="Moderateur", [5]="VIP"}



			local tag = tags[pLevel] or ""



			if tag ~= "" then



				local roleTag = Instance.new("TextLabel")



				roleTag.Parent = pf



				roleTag.Size = UDim2.new(0, 72, 0, 16)

				roleTag.Position = UDim2.new(1, -116, 0.5, -8)



				roleTag.BackgroundColor3 = C.btnInfo



				roleTag.BackgroundTransparency = 0.3



				roleTag.Text = tag



				roleTag.TextColor3 = C.text



				roleTag.Font = Enum.Font.GothamBold



				roleTag.TextSize = 9



				roleTag.ZIndex = Z+5



				corner(roleTag, 4)



			end



		end







		-- Indicateur "En service" (si le joueur a l'attribut OnService)



		if p:GetAttribute("OnService") then



			local svcTag = Instance.new("TextLabel")



			svcTag.Parent = pf



			svcTag.Size = UDim2.new(0, 50, 0, 12)



			svcTag.Position = UDim2.new(0.03, 0, 0, 30)



			svcTag.BackgroundColor3 = C.btnSuccess



			svcTag.BackgroundTransparency = 0.3



			svcTag.Text = "EN SERVICE"



			svcTag.TextColor3 = C.text



			svcTag.Font = Enum.Font.GothamBold



			svcTag.TextSize = 7



			svcTag.ZIndex = Z+5



			corner(svcTag, 3)



		end



	end







	playerCountLabel.Text = "LISTE DES JOUEURS ("..count.."/"..maxPlayers..")"



end







-- Auto-refresh on search



searchBox:GetPropertyChangedSignal("Text"):Connect(function()



	refreshPlayerList()



end)







tabJoueurs.MouseButton1Click:Connect(function()



	-- Reset to list view



	selectedView.Visible = false



	listView.Visible = true



	selectedPlayer = nil



	refreshPlayerList()



end)







-- ═══════════════════════════════════════════



-- TOGGLE PANEL



-- ═══════════════════════════════════════════



toggleBtn.MouseButton1Click:Connect(function()



	playSfx(6895079853, 0.4)



	refreshRole()



	if not isMod() then return end



	panel.Visible = not panel.Visible



	if panel.Visible then



		if currentTab == "joueurs" then refreshPlayerList() end



	end



end)







-- ═══════════════════════════════════════════



-- SYSTEM: MOD CAM (=) — caméra libre



-- ═══════════════════════════════════════════



local modCamLabel = Instance.new("TextLabel")



modCamLabel.Parent = gui



modCamLabel.Size = UDim2.new(0, 300, 0, 32)



modCamLabel.Position = UDim2.new(0.5, -150, 0, 10)



modCamLabel.BackgroundColor3 = C.btnPurple



modCamLabel.BackgroundTransparency = 0.2



modCamLabel.Text = "MOD CAM — WASD + Souris | = pour quitter"



modCamLabel.TextColor3 = C.text



modCamLabel.Font = Enum.Font.GothamBold



modCamLabel.TextSize = 11



modCamLabel.ZIndex = 99999



modCamLabel.Visible = false



corner(modCamLabel, 8)







local CAM_SPEED = 60



local CAM_SENS = 0.003







function enterModCamFn()



	if isModCam or not isMod() then return end



	-- (ancien fly local supprimé — ModCam uniquement, pas besoin de stopFly)



	isModCam = true



	modCamLabel.Visible = true







	-- [FIX CAM] Capturer position/orientation cam AVANT que le serveur TP sous la map
	local savedInitCF = camera.CFrame
	-- Passer Scriptable IMMÉDIATEMENT pour geler la cam
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = savedInitCF

	if modCamEvent then modCamEvent:FireServer("Enter") end



	task.wait(0.15)







	-- (CameraType déjà mis Scriptable plus haut, avant le wait)



	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter







	local initCF = savedInitCF



	local camAngleX = math.atan2(-initCF.LookVector.X, -initCF.LookVector.Z)



	local camAngleY = math.clamp(math.asin(initCF.LookVector.Y), -math.rad(89), math.rad(89))







	local keysDown = {}



	local conn1 = UIS.InputBegan:Connect(function(input, gpe)



		if gpe then return end



		keysDown[input.KeyCode] = true



	end)



	local conn2 = UIS.InputEnded:Connect(function(input)



		keysDown[input.KeyCode] = nil



	end)



	local conn3 = UIS.InputChanged:Connect(function(input)



		if not isModCam then return end



		if input.UserInputType == Enum.UserInputType.MouseMovement then



			camAngleX = camAngleX - input.Delta.X * CAM_SENS



			camAngleY = math.clamp(camAngleY - input.Delta.Y * CAM_SENS, -math.rad(89), math.rad(89))



		end



	end)







	modCamLoop = RunService.RenderStepped:Connect(function(dt)



		if not isModCam then return end



		local rotation = CFrame.Angles(0, camAngleX, 0) * CFrame.Angles(camAngleY, 0, 0)



		local lookVec  = rotation.LookVector



		local rightVec = rotation.RightVector







		local moveDir = Vector3.zero



		if keysDown[Enum.KeyCode.W] then moveDir = moveDir + lookVec end



		if keysDown[Enum.KeyCode.S] then moveDir = moveDir - lookVec end



		if keysDown[Enum.KeyCode.A] then moveDir = moveDir - rightVec end



		if keysDown[Enum.KeyCode.D] then moveDir = moveDir + rightVec end



		if keysDown[Enum.KeyCode.Space]       then moveDir = moveDir + Vector3.new(0,1,0) end



		if keysDown[Enum.KeyCode.LeftControl] then moveDir = moveDir - Vector3.new(0,1,0) end







		local speed = CAM_SPEED



		if keysDown[Enum.KeyCode.LeftShift] then speed = speed * 2.5 end







		local pos = camera.CFrame.Position



		if moveDir.Magnitude > 0 then pos = pos + moveDir.Unit * speed * dt end



		camera.CFrame = CFrame.new(pos) * rotation



	end)







	modCamConns = {conn1, conn2, conn3}

	-- [DESACTIVE] son d'activation ModCam retire (agacant)



end







function exitModCamFn()



	if not isModCam then return end



	isModCam = false



	modCamLabel.Visible = false







	if modCamLoop then modCamLoop:Disconnect() modCamLoop = nil end



	for _, c in pairs(modCamConns) do if c then c:Disconnect() end end



	modCamConns = {}







	UIS.MouseBehavior = Enum.MouseBehavior.Default







	local camPos = camera.CFrame.Position



	if modCamEvent then modCamEvent:FireServer("Exit", camPos) end







	task.wait(0.2)



	camera.CameraType = Enum.CameraType.Custom



	local char = player.Character



	if char and char:FindFirstChildOfClass("Humanoid") then



		camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")



	end

	-- [DESACTIVE] son de desactivation ModCam retire

end







-- Écouter confirmation serveur









-- ═══════════════════════════════════════════



-- SYSTEM: ESP (G)



-- ═══════════════════════════════════════════



function toggleEspFn()



	if not isMod() then return end



	isEspOn = not isEspOn



	if espFolder then espFolder:Destroy() espFolder = nil end



	if isEspOn then



		local pg = player:FindFirstChild("PlayerGui")



		if pg then



			espFolder = Instance.new("Folder", pg)



			espFolder.Name = "AgoraESP"



			for _, p in pairs(Players:GetPlayers()) do



				if p ~= player and p.Character then



					local hl = Instance.new("Highlight", espFolder)



					hl.Adornee = p.Character



					hl.FillColor = Color3.new(1, 0, 0)



					hl.FillTransparency = 0.5



					hl.OutlineColor = Color3.new(1, 1, 1)



					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop







					local bb = Instance.new("BillboardGui", espFolder)



					bb.Adornee = p.Character:FindFirstChild("Head")



					bb.Size = UDim2.new(0, 100, 0, 30)



					bb.StudsOffset = Vector3.new(0, 3, 0)



					bb.AlwaysOnTop = true



					local txt = Instance.new("TextLabel", bb)



					txt.Size = UDim2.new(1, 0, 1, 0)



					txt.BackgroundTransparency = 1



					txt.Text = p.Name



					txt.TextColor3 = Color3.new(1, 1, 1)



					txt.Font = Enum.Font.GothamBold



					txt.TextSize = 12



					txt.TextStrokeTransparency = 0.3



				end



			end



		end



	end



end







-- ═══════════════════════════════════════════



-- TAB: TICKETS (intégré dans le panel)



-- ═══════════════════════════════════════════



-- Section: Envoyer un ticket



local function buildTicketsTab()



	for _, child in pairs(contentTickets:GetChildren()) do



		if not child:IsA("UIListLayout") then child:Destroy() end



	end







	if not ticketListFunc then



		local err = makeLabel("Remote tickets introuvable", contentTickets, UDim2.new(1,0,0,30), nil, 11, C.textDim, Z+2)



		err.LayoutOrder = 1



		err.TextXAlignment = Enum.TextXAlignment.Center



		return



	end







	local hdr = makeLabel("Tickets joueurs", contentTickets, UDim2.new(1,0,0,22), nil, 12, C.text, Z+2)



	hdr.Font = Enum.Font.GothamBlack



	hdr.TextXAlignment = Enum.TextXAlignment.Center



	hdr.LayoutOrder = 1







	-- Bouton rafraichir



	local refreshBtn = makeBtn("Rafraichir", contentTickets, UDim2.new(1, 0, 0, 28), nil, C.btnInfo, Z+3)



	refreshBtn.TextSize = 11



	refreshBtn.LayoutOrder = 2



	refreshBtn.MouseButton1Click:Connect(function() buildTicketsTab() end)







	local ok, tickets = pcall(function() return ticketListFunc:InvokeServer() end)



	if ok and tickets and #tickets > 0 then



		ticketBadge.Text = tostring(#tickets)



		ticketBadge.Visible = true



		for i, t in ipairs(tickets) do



			local tf = Instance.new("Frame")



			tf.Parent = contentTickets



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

							myRoot.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)

						end

					end

				end

			end)







			-- Bouton Zone Staff (convoquer)



			local zoneBtn = makeBtn("Zone", tf, UDim2.new(0.18, 0, 0, 22), UDim2.new(0.80, 0, 0.08, 0), C.btnPurple, Z+5)



			zoneBtn.TextSize = 10



			zoneBtn.MouseButton1Click:Connect(function()



				if t.ReporterId and modCamEvent then



					modCamEvent:FireServer("ZoneStaffTarget", t.ReporterId)



				end



			end)







			-- Bouton Traiter



			local claimBtn = makeBtn("Traiter", tf, UDim2.new(0.38, 0, 0, 22), UDim2.new(0.60, 0, 0.55, 0), C.btnSuccess, Z+5)



			claimBtn.TextSize = 10



			claimBtn.MouseButton1Click:Connect(function()



				if ticketClaimEvent then ticketClaimEvent:FireServer(t.Id) end



				tf:Destroy()



				playSfx(2865227271, 0.4)



			end)



		end



	else



		local empty = makeLabel("Aucun ticket en attente", contentTickets, UDim2.new(1,0,0,30), nil, 11, C.textDim, Z+2)



		empty.TextXAlignment = Enum.TextXAlignment.Center



		empty.LayoutOrder = 10



		ticketBadge.Visible = false



	end



end







-- Construire au premier switch + refresh



tabTickets.MouseButton1Click:Connect(function()



	switchTab("tickets")



	buildTicketsTab()



end)







-- ═══════════════════════════════════════════



-- BOUTON TICKET (droite, pour TOUT LE MONDE) → ouvre le panel sur l'onglet Tickets



-- ═══════════════════════════════════════════



local hammerBtn = Instance.new("TextButton")



hammerBtn.Parent = gui



hammerBtn.Name = "HammerBtn"



hammerBtn.Size = UDim2.new(0, 44, 0, 44)



hammerBtn.Position = UDim2.new(1, -56, 0.5, -50)



hammerBtn.BackgroundColor3 = C.btnDanger



hammerBtn.BackgroundTransparency = 0.1



hammerBtn.Text = "!"



hammerBtn.TextColor3 = C.text



hammerBtn.Font = Enum.Font.GothamBlack



hammerBtn.TextSize = 22



hammerBtn.BorderSizePixel = 0



hammerBtn.ZIndex = 9000



corner(hammerBtn, 22)



stroke(hammerBtn, Color3.fromRGB(255, 120, 120), 2, 0.2)







-- Panel ticket joueur (Joueurs + VIP seulement - pas le panel staff)

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



local ptfFeedback = nil



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

		task.delay(2, function() ptfTitle.Text = "! Contacter le Staff" ptfTitle.TextColor3 = C.text end)

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

	task.delay(2.5, function() ptfTitle.Text = "! Contacter le Staff" ptfTitle.TextColor3 = C.text end)

	playSfx(6895079853, 0.4)

end)



hammerBtn.MouseButton1Click:Connect(function()

	panel.Visible = false  -- Fermer le panel mod si ouvert

	-- Tout le monde : formulaire ticket seulement

	playerTicketFrame.Visible = not playerTicketFrame.Visible

	playSfx(6895079853, 0.4)

end)







-- ═══════════════════════════════════════════



-- TICKET ALERTS (bleu semi-transparent, mods only)



-- ═══════════════════════════════════════════



-- Container en haut à droite pour les alertes tickets



local ticketAlertContainer = Instance.new("Frame")



ticketAlertContainer.Parent = gui



ticketAlertContainer.Name = "TicketAlerts"



ticketAlertContainer.Size = UDim2.new(0, 340, 0, 140)



ticketAlertContainer.Position = UDim2.new(1, -350, 0, 10)



ticketAlertContainer.BackgroundTransparency = 1



ticketAlertContainer.ZIndex = 99000



ticketAlertContainer.ClipsDescendants = false



local ticketAlertLayout = Instance.new("UIListLayout")



ticketAlertLayout.Parent = ticketAlertContainer



ticketAlertLayout.Padding = UDim.new(0, 6)



ticketAlertLayout.SortOrder = Enum.SortOrder.LayoutOrder



local ticketAlertCount = 0







if ticketAlertEvent then



	ticketAlertEvent.OnClientEvent:Connect(function(data)



		-- Badge sur onglet Tickets



		ticketBadge.Visible = true



		local cur = tonumber(ticketBadge.Text) or 0



		ticketBadge.Text = tostring(cur + 1)







		-- Alerte bleue semi-transparente



		ticketAlertCount = ticketAlertCount + 1



		local alert = Instance.new("TextButton")



		alert.Parent = ticketAlertContainer



		alert.Size = UDim2.new(1, 0, 0, 50)



		alert.BackgroundColor3 = Color3.fromRGB(30, 80, 200)



		alert.BackgroundTransparency = 0.35



		alert.BorderSizePixel = 0



		alert.ZIndex = 99005



		alert.AutoButtonColor = false



		alert.Text = ""



		alert.LayoutOrder = ticketAlertCount + 1000



		corner(alert, 10)







		local txt = Instance.new("TextLabel")



		txt.Parent = alert



		txt.Size = UDim2.new(1, -16, 1, -6)



		txt.Position = UDim2.new(0, 8, 0, 3)



		txt.BackgroundTransparency = 1



		txt.Text = string.format("TICKET: %s\nDe: %s — %s",



			data.Category or "?", data.Reporter or "?",



			string.sub(data.Description or "", 1, 50))



		txt.TextColor3 = Color3.new(1, 1, 1)



		txt.Font = Enum.Font.GothamBold



		txt.TextSize = 11



		txt.TextWrapped = true



		txt.TextXAlignment = Enum.TextXAlignment.Left



		txt.TextYAlignment = Enum.TextYAlignment.Center



		txt.ZIndex = 99010







		-- Clic = ouvre onglet tickets



		alert.MouseButton1Click:Connect(function()



			panel.Visible = true



			switchTab("tickets")



			buildTicketsTab()



			alert:Destroy()



		end)







		-- Slide in



		alert.Position = UDim2.new(1, 50, 0, 0)



		TweenService:Create(alert, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()







		-- Auto-dismiss après 30s



		task.delay(30, function()



			if alert and alert.Parent then



				TweenService:Create(alert, TweenInfo.new(0.4), {Position = UDim2.new(1, 50, 0, 0)}):Play()



				task.wait(0.5)



				if alert and alert.Parent then alert:Destroy() end



			end



		end)



	end)



end







-- ═══════════════════════════════════════════



-- KEYBOARD SHORTCUTS



-- ═══════════════════════════════════════════



UIS.InputBegan:Connect(function(input, gameProcessed)



	if gameProcessed then return end



	if not isMod() then return end







	if input.KeyCode == Enum.KeyCode.Equals then



		if isModCam then exitModCamFn() else enterModCamFn() end



	elseif input.KeyCode == Enum.KeyCode.G then



		toggleEspFn()



	end



end)







-- ═══════════════════════════════════════════

-- BOUTON RETOUR ZONE STAFF (flottant, visible après TP)

-- ═══════════════════════════════════════════

local zoneReturnBtn = Instance.new("TextButton")

zoneReturnBtn.Parent = gui

zoneReturnBtn.Name = "ZoneReturnBtn"

zoneReturnBtn.Size = UDim2.new(0, 180, 0, 38)

zoneReturnBtn.Position = UDim2.new(0.5, -90, 0, 8)

zoneReturnBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)

zoneReturnBtn.BackgroundTransparency = 0.1

zoneReturnBtn.Text = "⬅ RETOUR (avant zone staff)"

zoneReturnBtn.TextColor3 = Color3.new(1,1,1)

zoneReturnBtn.Font = Enum.Font.GothamBlack

zoneReturnBtn.TextSize = 11

zoneReturnBtn.BorderSizePixel = 0

zoneReturnBtn.ZIndex = 99000

zoneReturnBtn.Visible = false

corner(zoneReturnBtn, 10)

stroke(zoneReturnBtn, Color3.fromRGB(46, 204, 113), 2, 0.2)



zoneReturnBtn.MouseButton1Click:Connect(function()

	if modCamEvent then modCamEvent:FireServer("ZoneStaffReturnSelf") end

	playSfx(6895079853, 0.4)

end)



-- Écouter les confirmations du serveur

if modCamEvent then

	modCamEvent.OnClientEvent:Connect(function(action)

		if action == "ZoneStaffEntered" then

			zoneReturnBtn.Visible = true

		elseif action == "ZoneStaffLeft" then

			zoneReturnBtn.Visible = false

		elseif action == "Restored" then

			camera.CameraType = Enum.CameraType.Custom

			local char = player.Character

			if char and char:FindFirstChildOfClass("Humanoid") then

				camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")

			end

		elseif action == "FlyEnded" then

			-- Serveur confirme fin de fly

		end

	end)

end



-- ═══════════════════════════════════════════



-- INIT



-- ═══════════════════════════════════════════



task.spawn(function()



	task.wait(3)



	refreshRole()



	toggleBtn.Visible = isMod()



end)







task.spawn(function()



	while task.wait(8) do



		refreshRole()



		toggleBtn.Visible = isMod()



	end



end)







-- Cleanup si le joueur meurt pendant le fly



player.CharacterAdded:Connect(function()
	if isModCam then exitModCamFn() end
end)



