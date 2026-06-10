-- DO NOT TOUCH - AGORA ADMIN CLIENT SYSTEM
-- Version: clean (no logs, no comments)

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local SoundService        = game:GetService("SoundService")
local RunService          = game:GetService("RunService")
local StarterGui          = game:GetService("StarterGui")
local TextChatService     = game:GetService("TextChatService")
local LocalizationService = game:GetService("LocalizationService")
local GuiService          = game:GetService("GuiService")
local Debris              = game:GetService("Debris")

local AGORA_VERSION = "6.4.0"
local AGORA_CODENAME = "FORTRESS EDITION"
local AGORA_AUTHOR   = "Vzlom_Emk"

local PALETTE = {
	bgDeep        = Color3.fromRGB(10, 0, 20),    
	bgPanel       = Color3.fromRGB(18, 8, 32),    
	bgCard        = Color3.fromRGB(25, 12, 45),   
	cyan          = Color3.fromRGB(0, 240, 255),  
	violet        = Color3.fromRGB(189, 0, 255),  
	magenta       = Color3.fromRGB(255, 0, 128),  
	yellow        = Color3.fromRGB(255, 234, 0),  
	green         = Color3.fromRGB(0, 255, 140),  
	red           = Color3.fromRGB(255, 40, 80),  
	white         = Color3.fromRGB(240, 240, 255),
	dim           = Color3.fromRGB(130, 110, 160),
}

local currentLocale = "fr"

local translations = {
	["en"] = {
		["AGORA ADMIN V"] = "AGORA ADMIN V",
		["[CMD] CMDS"] = "[CMD] CMDS",
		["[BAN] BANS"] = "[BAN] BANS",
		["[RANK] RANKS"] = "[RANK] RANKS",
		["[SET] OPTS"] = "[SET] OPTS",
		["[AC] AC LOGS"] = "[AC] AC LOGS",
		["[AC] MODÉRATION"] = "[AC] MODERATION",
		["MODÉRATION"] = "MODERATION",
		["BANS"] = "BANS",
		["AC LOGS"] = "AC LOGS",
		["[?] AIDE"] = "[?] HELP",
		["PREFIXE DES COMMANDES T'CHAT"] = "CHAT COMMAND PREFIX",
		["Nouveau Préfixe"] = "New Prefix",
		["APPLIQUER LE PRÉFIXE"] = "APPLY PREFIX",
		["ENVOYER UN FEEDBACK / BUG AU FONDATEUR"] = "SEND BUG / FEEDBACK TO FOUNDER",
		["Décrivez votre bug..."] = "Describe your bug...",
		["ENVOYER VIA DISCORD WEBHOOK"] = "SEND VIA DISCORD WEBHOOK",
		["[!] AVERTISSEMENT [!]\n\n"] = "[!] WARNING [!]\n\n",
		["[MSG] MESSAGE SYSTÈME"] = "[MSG] SYSTEM MESSAGE",
		["   > NIVEAU REQUIS : "] = "   > REQUIRED RANK : ",
		["CONFIGURER"] = "CONFIGURE",
		["MODIFICATION : "] = "EDITING : ",
		["GRADE ACTUEL : "] = "CURRENT RANK : ",
		["NOUVEAU GRADE : "] = "NEW RANK : ",
		["CIBLER LES AUTRES : OUI"] = "TARGET OTHERS : YES",
		["CIBLER LES AUTRES : NON"] = "TARGET OTHERS : NO",
		["SAUVEGARDER LA MODIFICATION"] = "SAVE CHANGES",
		["JOUEUR : "] = "PLAYER : ",
		["RAISON : "] = "REASON : ",
		["DURÉE : "] = "DURATION : ",
		["PERMANENT"] = "PERMANENT",
		["EXPIRÉ"] = "EXPIRED",
		["DÉBANNIR"] = "UNBAN",
		["Rechercher un joueur..."] = "Search a player...",
		["RÉVOQUER LE GRADE ?"] = "REVOKE RANK?",
		["OUI"] = "YES",
		["ANNULER"] = "CANCEL",
		["REVOKE"] = "REVOKE",
		["CONTRÔLE VOL"] = "FLIGHT CONTROL",
		["Vitesse :"] = "Speed :",
		["CONTRÔLE NOCLIP"] = "NOCLIP CONTROL",
		["COMMAND BAR"] = "COMMAND BAR",
		["BUBBLECHAT"] = "BUBBLECHAT",
		["LOGS DES COMMANDES"] = "COMMAND LOGS",
		["[EMO] ÉMOTES"] = "[EMO] EMOTES",
		["THÈME"] = "THEME",
		["Appuyez sur le bouton [AC] en bas à gauche pour commencer"] = "Press the [AC] button in the bottom-left to begin",
	}
}

local function tr(str)
	if translations[currentLocale] and translations[currentLocale][str] then
		return translations[currentLocale][str]
	end
	return str
end

-- _G guard removed: causes silent failure on Studio replay because _G persists between Play/Stop

local _GUARD = "_AgoraAdminLS_Running"
if _G[_GUARD] then
	script:Destroy()
	return
end
_G[_GUARD] = true
script.AncestryChanged:Connect(function()
	if not script.Parent then _G[_GUARD] = nil end
end)
local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui")

-- Attente avec retry pour Play Solo / replication
local gui = playerGui:WaitForChild("AgoraAdmin", 8)
if not gui then
	for i = 1, 20 do
		task.wait(0.3)
		gui = playerGui:FindFirstChild("AgoraAdmin")
		if gui then break end
	end
end

-- Fallback: chercher par contenu (bouton AdminLogoBtn ou OpenButton)
if not gui then
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and (child:FindFirstChild("AdminLogoBtn") or child:FindFirstChild("OpenButton")) then
			gui = child
			break
		end
	end
end

if not gui then
	-- ERREUR VISIBLE à l'ecran (pas juste print)
	local errGui = Instance.new("ScreenGui")
	errGui.Name = "AgoraError"
	errGui.ResetOnSpawn = false
	errGui.Parent = playerGui
	local lbl = Instance.new("TextLabel")
	lbl.Parent = errGui
	lbl.Size = UDim2.new(0, 500, 0, 120)
	lbl.Position = UDim2.new(0.5, -250, 0, 20)
	lbl.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
	lbl.BackgroundTransparency = 0.1
	lbl.Text = "[AGORA ERROR]\nScreenGui introuvable dans PlayerGui.\nVerifiez que le Loader est bien dans ServerScriptService et que le ScreenGui est dans le meme dossier que le Loader."
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 16
	lbl.TextWrapped = true
	lbl.ZIndex = 99999
	warn("[AGORA] ScreenGui introuvable dans PlayerGui apres 20 retries")
	return
end

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local BTN_SIZE = IS_MOBILE and 44 or 36
local IS_CONSOLE = GuiService:IsTenFootInterface()
local IS_PC = not IS_MOBILE and not IS_CONSOLE

gui.DisplayOrder = 99999

local adminBtn = gui:WaitForChild("AdminLogoBtn", 5)
if not adminBtn then
	-- Fallback: chercher OpenButton
	adminBtn = gui:FindFirstChild("OpenButton")
	if not adminBtn then
		warn("[AGORA] AdminLogoBtn et OpenButton introuvables dans le ScreenGui")
		return
	end
end

local corner = adminBtn:FindFirstChildOfClass("UICorner")
if not corner then
	corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = adminBtn
end
local stroke = adminBtn:FindFirstChildOfClass("UIStroke")
if not stroke then
	stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 60)
	stroke.Thickness = 1
	stroke.Transparency = 0.6
	stroke.Parent = adminBtn
end

adminBtn.MouseEnter:Connect(function()
	TweenService:Create(adminBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, BTN_SIZE + 4, 0, BTN_SIZE + 4)
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2), {
		Color = Color3.fromRGB(200, 200, 200),
		Thickness = 3,
		Transparency = 0
	}):Play()
end)
adminBtn.MouseLeave:Connect(function()
	TweenService:Create(adminBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.25), {
		Color = Color3.fromRGB(60, 60, 60),
		Thickness = 1,
		Transparency = 0.6
	}):Play()
end)

local THEMES = {
	["Cyberpunk"] = {
		bg         = PALETTE.bgDeep,
		bgTrans    = 0.15,
		card       = PALETTE.bgCard,
		cardTrans  = 0.1,
		stroke     = PALETTE.cyan,
		strokeAlt  = PALETTE.violet,
		text       = PALETTE.white,
		accent     = PALETTE.magenta,
	},
	["Sombre"] = {
		bg         = Color3.fromRGB(15, 15, 20),
		bgTrans    = 0.3,
		card       = Color3.fromRGB(30, 30, 40),
		cardTrans  = 0.1,
		stroke     = Color3.fromRGB(200, 200, 200),
		strokeAlt  = Color3.fromRGB(150, 150, 150),
		text       = Color3.new(1, 1, 1),
		accent     = Color3.fromRGB(41, 128, 185),
	},
	["Clair"] = {
		bg         = Color3.fromRGB(240, 240, 245),
		bgTrans    = 0.05,
		card       = Color3.fromRGB(210, 210, 220),
		cardTrans  = 0.05,
		stroke     = Color3.fromRGB(80, 80, 100),
		strokeAlt  = Color3.fromRGB(120, 120, 140),
		text       = Color3.fromRGB(20, 20, 30),
		accent     = Color3.fromRGB(41, 128, 185),
	},
	["Glass"] = {
		bg         = Color3.fromRGB(220, 230, 245),
		bgTrans    = 0.72,
		card       = Color3.fromRGB(240, 245, 255),
		cardTrans  = 0.78,
		stroke     = Color3.fromRGB(255, 255, 255),
		strokeAlt  = Color3.fromRGB(220, 230, 255),
		text       = Color3.fromRGB(245, 250, 255),
		accent     = Color3.fromRGB(180, 200, 255),
	},
}
local currentTheme = "Sombre"

local rolesOrder     = {"Fondateur","Gérant","Staffs","Modérateur","VIP","Joueurs"}
local rolesHierarchy = {["Fondateur"]=1,["Gérant"]=2,["Staffs"]=3,["Modérateur"]=4,["VIP"]=5,["Joueurs"]=6}
local roleColors     = {
	["Fondateur"]  = PALETTE.yellow,
	["Gérant"]     = Color3.fromRGB(255, 140, 0),
	["Staffs"]     = PALETTE.cyan,
	["Modérateur"] = PALETTE.green,
	["VIP"]        = PALETTE.violet,
	["Joueurs"]    = PALETTE.dim,
}

local currentPrefix = ";"
local myRole        = "Joueurs"
local cmdRegistry   = {}
local isFlying      = false
local isNoclip      = false
local fSpd          = 50  

local remotes, flyEvent, notifEvent, announceEvent, refreshEvent = nil,nil,nil,nil,nil
local settingsEvent, feedbackEvent, warnEvent, noclipEvent       = nil,nil,nil,nil
local getBansFunc, unbanEvent, getCmdsFunc, updateCmdEvent       = nil,nil,nil,nil
local logsEvent, bubbleChatEvent, cmdBarEvent, forceChatEvent    = nil,nil,nil,nil
local getRanksFunc, revokeEvent                                  = nil,nil
local acAlertEvent, suspectAddEvent, suspectRemEvent             = nil,nil,nil
local suspectListFunc, ticketAlertEvent                          = nil,nil
local themePrefFunc                                                = nil
local acLogsFunc, clientACReport                                  = nil,nil
_muteAC      = false
_muteTickets = false

local updatePhys
local updateModToolsVisibility
local cmdBarPnl 

local PANEL_W, PANEL_H
local main, closeBtn, minBtn, isMinimized
local setMinimized
local sidebar, contentContainer
local pnlCmds, pnlMod, pnlRanks, pnlOpt, pnlHelp
local pnlBans, pnlAC
local allPanels
local btnTabCmd, btnTabOpt, btnTabHelp, btnTabMod, btnTabRanks

local feedIn, btnFeed

local modSubIndex, modTitle, modDotFill

local addACLog, renderACLogs
local showNotif
local spawnACAlert
local triggerWarn
local triggerAnn

local cmdScroll, cmdLay, editFrame, etit, ecat
local refreshCmdUI

local banScroll, banLay
local updateBanLand

local rankSearch, confirmFrame, confMsg

local flyPnl, noclipPnl, bubblePnl, logsPnl
local btnFly, btnNc, cIn, fSpdIn, nSpdIn
local logsScroll, logsLay

local mobileTouchContainer, btnFlyMobile
local btnUpHeld, btnDownHeld
btnUpHeld = false
btnDownHeld = false

local function playSfx(id, vol)
	local s = Instance.new("Sound")
	s.Parent = SoundService
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = vol or 0.5
	s:Play()
	Debris:AddItem(s, 3)
end

local function createCorner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
	return c
end

local function addStroke(obj, color, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or PALETTE.cyan
	s.Thickness = thick or 1.5
	s.Transparency = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local function addGradient(obj, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(1, c2),
	})
	g.Rotation = rot or 45
	g.Parent = obj
	return g
end

local function addNeonGlow(obj, color)
	local stroke = addStroke(obj, color or PALETTE.cyan, 2.5, 0.1)
	
	task.spawn(function()
		while obj and obj.Parent do
			pcall(function()
				TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Thickness = 3.5,
					Transparency = 0.4,
				}):Play()
			end)
			task.wait(1.2)
			if not obj or not obj.Parent then break end
			pcall(function()
				TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Thickness = 2.5,
					Transparency = 0.1,
				}):Play()
			end)
			task.wait(1.2)
		end
	end)
	return stroke
end

local function applyHoverEffect(btn, dt, ht)
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = ht}):Play()
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.15), {Thickness = stroke.Thickness + 1}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = dt}):Play()
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.2), {Thickness = math.max(1, stroke.Thickness - 1)}):Play()
		end
	end)
end

local function createBtn(txt, pos, size, clr, p, zidx)
	local b = Instance.new("TextButton")
	b.Parent = p
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = clr or PALETTE.bgCard
	b.Text = txt
	b.TextColor3 = PALETTE.white
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.AutoButtonColor = false
	b.BackgroundTransparency = 0.15
	b.BorderSizePixel = 0
	b.ZIndex = zidx or 1005
	createCorner(b, 10)
	addStroke(b, PALETTE.cyan, 1.5, 0.3)
	applyHoverEffect(b, 0.15, 0)

	
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = b

	b.MouseButton1Click:Connect(function()
		playSfx(6895079853, 0.35)
		
		TweenService:Create(uiScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.95,
		}):Play()
		task.delay(0.07, function()
			if uiScale and uiScale.Parent then
				TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
			end
		end)
	end)
	return b
end

local function makeDraggable(frame, titleBar)
	local dragging, dragStart, startPos = false, nil, nil
	titleBar = titleBar or frame
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local newOffsetX = startPos.X.Offset + delta.X
			local newOffsetY = startPos.Y.Offset + delta.Y
			local cam = workspace.CurrentCamera
			local viewport = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
			local frameAbsSize = frame.AbsoluteSize
			local anchor = frame.AnchorPoint
			local scaleX, scaleY = startPos.X.Scale, startPos.Y.Scale
			local baseX = scaleX * viewport.X - anchor.X * frameAbsSize.X
			local baseY = scaleY * viewport.Y - anchor.Y * frameAbsSize.Y
			local minTop = 0 - baseY
			local maxTop = (viewport.Y - frameAbsSize.Y) - baseY
			local minLeft = 0 - baseX
			local maxLeft = (viewport.X - frameAbsSize.X) - baseX
			if maxTop < minTop then maxTop = minTop end
			if maxLeft < minLeft then maxLeft = minLeft end
			newOffsetX = math.clamp(newOffsetX, minLeft, maxLeft)
			newOffsetY = math.clamp(newOffsetY, minTop, maxTop)
			frame.Position = UDim2.new(scaleX, newOffsetX, scaleY, newOffsetY)
		end
	end)
end

local tooltipFrame = nil
local function showTooltip(text, targetBtn)
	if not tooltipFrame then
		tooltipFrame = Instance.new("Frame")
		tooltipFrame.Parent = gui
		tooltipFrame.Name = "AgoraTooltip"
		tooltipFrame.Size = UDim2.new(0, 220, 0, 50)
		tooltipFrame.BackgroundColor3 = PALETTE.bgDeep
		tooltipFrame.BackgroundTransparency = 0.05
		tooltipFrame.BorderSizePixel = 0
		tooltipFrame.ZIndex = 50000
		tooltipFrame.Visible = false
		createCorner(tooltipFrame, 6)
		addStroke(tooltipFrame, PALETTE.magenta, 1.5, 0.2)
		local lbl = Instance.new("TextLabel")
		lbl.Parent = tooltipFrame
		lbl.Name = "Lbl"
		lbl.Size = UDim2.new(1, -12, 1, -8)
		lbl.Position = UDim2.new(0, 6, 0, 4)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = PALETTE.cyan
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = 12
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.ZIndex = 50001
	end
	tooltipFrame.Lbl.Text = text
	local mp = UserInputService:GetMouseLocation()
	tooltipFrame.Position = UDim2.new(0, mp.X + 15, 0, mp.Y + 15)
	tooltipFrame.Visible = true
end

local function hideTooltip()
	if tooltipFrame then tooltipFrame.Visible = false end
end

local themedRoots = {}
local function registerThemedRoot(frame)
	if frame and not table.find(themedRoots, frame) then
		table.insert(themedRoots, frame)
	end
end

local THEME_EXCLUDE = {
	["WarningOverlay"] = true,
	["BlindFold"]      = true,
	["AgoraIntroRoot"] = true,
	["NotificationPanel"] = true,
	["ACAlertContainer"]  = true,
}

local function applyTheme(themeName)
	local t = THEMES[themeName] or THEMES["Cyberpunk"]
	currentTheme = themeName
	
	if themePrefFunc then
		pcall(function() themePrefFunc:InvokeServer("save", themeName) end)
	end

	local isGlass = (themeName == "Glass")

	local function setFrame(f)
		if f:IsA("Frame") and not THEME_EXCLUDE[f.Name] then
			if f.Name == "MainPanel" or f.Name == "EditPanel" or f.Name == "ConfirmPanel"
				or string.find(f.Name or "", "Panel$") then
				f.BackgroundColor3 = t.bg
				f.BackgroundTransparency = t.bgTrans
				local s = f:FindFirstChildOfClass("UIStroke")
				if s then
					s.Color = t.stroke
					if isGlass then s.Transparency = 0.3 end
				end
			elseif f:FindFirstChildOfClass("UICorner") then
				f.BackgroundColor3 = t.card
				f.BackgroundTransparency = t.cardTrans
				local s = f:FindFirstChildOfClass("UIStroke")
				if s and isGlass then
					s.Color = t.stroke
					s.Transparency = 0.55
				end
			end
		end
		for _, c in pairs(f:GetChildren()) do
			if c:IsA("Frame") then setFrame(c) end
			if c:IsA("TextLabel") and c.Name ~= "AnnounceTitle" and c.Name ~= "IntroTitle" and c.Name ~= "IntroSubtitle" then
				pcall(function() c.TextColor3 = t.text end)
			end
			if c:IsA("TextButton") then
				
				
				pcall(function()
					if c:FindFirstChildOfClass("UICorner") and not THEME_EXCLUDE[c.Name] then
						
					end
				end)
			end
		end
	end

	
	pcall(function() setFrame(gui:FindFirstChild("MainPanel") or gui) end)
	
	for _, root in ipairs(themedRoots) do
		if root and root.Parent then
			pcall(function() setFrame(root) end)
		end
	end
end

local function shouldPlayIntro()
	
	if _G.AgoraIntroPlayed then return false end
	
	local lastTs = tonumber(_G.AgoraLastIntro or 0) or 0
	local now = os.time()
	if (now - lastTs) > (24 * 60 * 60) then
		return true
	end
	
	return math.random(1, 5) == 1
end

local function playIntro()
	local okRun = pcall(function()
		if not shouldPlayIntro() then return end
		_G.AgoraIntroPlayed = true
		_G.AgoraLastIntro = os.time()

		task.wait(1.2) 

		local root = Instance.new("Frame")
		root.Name = "AgoraIntroRoot"
		root.Parent = gui
		root.Size = UDim2.new(0, 400, 0, 250)
		root.AnchorPoint = Vector2.new(1, 1)
		
		root.Position = UDim2.new(1, 420, 1, -30)
		root.BackgroundColor3 = PALETTE.bgDeep
		root.BackgroundTransparency = 0.08
		root.BorderSizePixel = 0
		root.ZIndex = 60000
		root.ClipsDescendants = true
		createCorner(root, 16)
		addGradient(root, PALETTE.bgDeep, PALETTE.bgPanel, 135)
		addNeonGlow(root, PALETTE.cyan)

		
		local hBar = Instance.new("Frame")
		hBar.Parent = root
		hBar.Size = UDim2.new(1, 0, 0, 54)
		hBar.Position = UDim2.new(0, 0, 0, 0)
		hBar.BackgroundColor3 = PALETTE.bgPanel
		hBar.BackgroundTransparency = 0.25
		hBar.BorderSizePixel = 0
		hBar.ZIndex = 60001
		createCorner(hBar, 16)
		addGradient(hBar, PALETTE.violet, PALETTE.bgPanel, 90)

		local logo = Instance.new("TextLabel")
		logo.Parent = hBar
		logo.Size = UDim2.new(0, 44, 0, 44)
		logo.Position = UDim2.new(0, 10, 0, 5)
		logo.BackgroundTransparency = 1
		logo.Text = "[AC]"
		logo.TextSize = 30
		logo.TextColor3 = PALETTE.cyan
		logo.Font = Enum.Font.GothamBlack
		logo.ZIndex = 60002

		local title = Instance.new("TextLabel")
		title.Name = "IntroTitle"
		title.Parent = hBar
		title.Size = UDim2.new(1, -120, 0, 26)
		title.Position = UDim2.new(0, 60, 0, 5)
		title.BackgroundTransparency = 1
		title.Text = "AGORA ADMIN"
		title.TextColor3 = PALETTE.cyan
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextStrokeTransparency = 0.4
		title.TextStrokeColor3 = PALETTE.magenta
		title.ZIndex = 60002

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "IntroSubtitle"
		subtitle.Parent = hBar
		subtitle.Size = UDim2.new(1, -120, 0, 18)
		subtitle.Position = UDim2.new(0, 60, 0, 30)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = "v" .. AGORA_VERSION .. " - " .. AGORA_CODENAME
		subtitle.TextColor3 = PALETTE.magenta
		subtitle.Font = Enum.Font.Code
		subtitle.TextSize = 12
		subtitle.TextXAlignment = Enum.TextXAlignment.Left
		subtitle.ZIndex = 60002

		
		local xBtn = Instance.new("TextButton")
		xBtn.Parent = hBar
		xBtn.Size = UDim2.new(0, 26, 0, 26)
		xBtn.Position = UDim2.new(1, -34, 0, 14)
		xBtn.BackgroundColor3 = PALETTE.red
		xBtn.BackgroundTransparency = 0.2
		xBtn.Text = "X"
		xBtn.TextColor3 = Color3.new(1, 1, 1)
		xBtn.Font = Enum.Font.GothamBold
		xBtn.TextSize = 13
		xBtn.BorderSizePixel = 0
		xBtn.ZIndex = 60003
		createCorner(xBtn, 13)

		
		local scan = Instance.new("Frame")
		scan.Parent = root
		scan.Size = UDim2.new(1, 0, 0, 1)
		scan.Position = UDim2.new(0, 0, 0, 56)
		scan.BackgroundColor3 = PALETTE.cyan
		scan.BackgroundTransparency = 0.4
		scan.BorderSizePixel = 0
		scan.ZIndex = 60005

		
		local featContainer = Instance.new("Frame")
		featContainer.Parent = root
		featContainer.Size = UDim2.new(1, -24, 0, 180)
		featContainer.Position = UDim2.new(0, 12, 0, 64)
		featContainer.BackgroundTransparency = 1
		featContainer.ZIndex = 60001

		local fLayout = Instance.new("UIListLayout")
		fLayout.Parent = featContainer
		fLayout.Padding = UDim.new(0, 6)
		fLayout.SortOrder = Enum.SortOrder.LayoutOrder
		fLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

		local features = {
			{icon = "[GAME]", text = "160+ Commandes"},
			{icon = "[AC]", text = "Anti-Cheat Premium"},
			{icon = "[STAR]", text = "Mod Menu staff in-game"},
			{icon = "[PHONE]", text = "Mobile Compatible"},
		}

		local featLabels = {}
		for i, feat in ipairs(features) do
			local l = Instance.new("TextLabel")
			l.Parent = featContainer
			l.Size = UDim2.new(1, 0, 0, 26)
			l.LayoutOrder = i
			l.BackgroundTransparency = 1
			l.Text = feat.icon .. "  " .. feat.text
			l.TextColor3 = PALETTE.cyan
			l.Font = Enum.Font.GothamBold
			l.TextSize = 14
			l.TextTransparency = 1
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.ZIndex = 60002
			table.insert(featLabels, l)
		end

		
		TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -20, 1, -30),
		}):Play()
		pcall(function() playSfx(6895079853, 0.35) end)

		task.wait(0.5)

		
		for i, lbl in ipairs(featLabels) do
			task.delay((i - 1) * 0.18, function()
				if lbl and lbl.Parent then
					TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 0,
					}):Play()
					
				end
			end)
		end

		
		local dismissed = false
		local function dismiss()
			if dismissed then return end
			dismissed = true
			if not root or not root.Parent then return end
			local tOut = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(root, tOut, {Position = UDim2.new(1, 420, 1, -30)}):Play()
			task.wait(0.45)
			if root and root.Parent then root:Destroy() end
		end

		xBtn.MouseButton1Click:Connect(dismiss)

		
		local clickOverlay = Instance.new("TextButton")
		clickOverlay.Parent = root
		clickOverlay.Size = UDim2.new(1, 0, 1, 0)
		clickOverlay.BackgroundTransparency = 1
		clickOverlay.Text = ""
		clickOverlay.ZIndex = 60000
		clickOverlay.MouseButton1Click:Connect(dismiss)

		
		task.delay(5, dismiss)
	end)
	if not okRun then
		
	end
end

task.spawn(function()
	pcall(playIntro)
end)

local screenSize = workspace.CurrentCamera.ViewportSize
local screenW = screenSize.X
local screenH = screenSize.Y
if IS_MOBILE then
	
	PANEL_W = math.clamp(math.floor(screenW * 0.9), 320, 640)
	PANEL_H = math.clamp(math.floor(screenH * 0.80), 360, 520)
else
	PANEL_W = 620
	PANEL_H = 440
end

main = Instance.new("Frame")
main.Parent = gui
main.Name = "MainPanel"
main.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
main.Position = UDim2.new(0.5, 0, 0.5, -PANEL_H/2)
main.AnchorPoint = Vector2.new(0.5, 0)
local function clampMainOnScreen()
	if not main then return end
	local cam = workspace.CurrentCamera
	local viewport = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
	local frameAbsSize = main.AbsoluteSize
	if frameAbsSize.X < 1 or frameAbsSize.Y < 1 then return end
	local anchor = main.AnchorPoint
	local scaleX, scaleY = main.Position.X.Scale, main.Position.Y.Scale
	local offsetX, offsetY = main.Position.X.Offset, main.Position.Y.Offset
	local baseX = scaleX * viewport.X - anchor.X * frameAbsSize.X
	local baseY = scaleY * viewport.Y - anchor.Y * frameAbsSize.Y
	local minLeft = -baseX
	local maxLeft = (viewport.X - frameAbsSize.X) - baseX
	local minTop = -baseY
	local maxTop = (viewport.Y - frameAbsSize.Y) - baseY
	if maxLeft < minLeft then maxLeft = minLeft end
	if maxTop < minTop then maxTop = minTop end
	offsetX = math.clamp(offsetX, minLeft, maxLeft)
	offsetY = math.clamp(offsetY, minTop, maxTop)
	main.Position = UDim2.new(scaleX, offsetX, scaleY, offsetY)
end
main:GetPropertyChangedSignal("Visible"):Connect(function()
	if main.Visible then
		task.defer(clampMainOnScreen)
	end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if main.Visible then clampMainOnScreen() end
	end)
end
main.BackgroundColor3 = PALETTE.bgDeep
main.BackgroundTransparency = 0.05
main.BorderSizePixel = 0
main.Visible = false
main.ZIndex = 1000
createCorner(main, 18)
addGradient(main, PALETTE.bgDeep, PALETTE.bgPanel, 90)
addNeonGlow(main, PALETTE.cyan)

isMinimized = false

do

local MODAL_FRAME_NAMES = {
	["EditPanel"]    = true,
	["ConfirmPanel"] = true,
}

local header = Instance.new("Frame")
header.Name = "Header"
header.Parent = main
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = PALETTE.bgPanel
header.BackgroundTransparency = 0.2
header.BorderSizePixel = 0
header.ZIndex = 1002
createCorner(header, 14)
addGradient(header, PALETTE.violet, PALETTE.bgPanel, 180)
makeDraggable(main, header)

local headerLogo = Instance.new("ImageLabel")
headerLogo.Name = "HeaderLogo"
headerLogo.Parent = header
headerLogo.Size = UDim2.new(0, 38, 0, 38)
headerLogo.Position = UDim2.new(0, 10, 0.5, -19)
headerLogo.BackgroundTransparency = 1
headerLogo.Image = "rbxassetid://73314612607499"
headerLogo.ScaleType = Enum.ScaleType.Fit
headerLogo.ZIndex = 1006
local title = Instance.new("TextLabel")
title.Parent = header
title.Size = UDim2.new(1, -160, 1, 0)
title.Position = UDim2.new(0, 56, 0, 0)
title.BackgroundTransparency = 1
title.Text = tr("AGORA ADMIN V") .. AGORA_VERSION
title.TextColor3 = PALETTE.cyan
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.TextStrokeTransparency = 0.7
title.TextStrokeColor3 = PALETTE.magenta
title.ZIndex = 1005

closeBtn = Instance.new("TextButton")
closeBtn.Parent = header
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -42, 0, 9)
closeBtn.BackgroundColor3 = PALETTE.red
closeBtn.BackgroundTransparency = 0.15
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 1005
createCorner(closeBtn, 16)
addStroke(closeBtn, PALETTE.red, 2, 0.2)
applyHoverEffect(closeBtn, 0.15, 0)
closeBtn.MouseButton1Click:Connect(function()
	playSfx(6895079853, 0.5)
	TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, PANEL_W, 0, 0),
	}):Play()
	task.delay(0.2, function()
		main.Visible = false
		main.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
		
		pcall(function()
			if isMinimized then
				
				for _, child in ipairs(main:GetChildren()) do
					if child:IsA("GuiObject") and child.Name ~= "Header" then
						local prev = child:GetAttribute("AgoraPrevVisible")
						if prev ~= nil then
							if not MODAL_FRAME_NAMES[child.Name] then
								child.Visible = prev
							end
							child:SetAttribute("AgoraPrevVisible", nil)
						end
					end
				end
				isMinimized = false
				minBtn.Text = "-"
			end
		end)
	end)
end)

minBtn = Instance.new("TextButton")
minBtn.Parent = header
minBtn.Size = UDim2.new(0, 32, 0, 32)
minBtn.Position = UDim2.new(1, -78, 0, 9)
minBtn.BackgroundColor3 = PALETTE.yellow
minBtn.BackgroundTransparency = 0.2
minBtn.Text = "-"
minBtn.TextColor3 = PALETTE.bgDeep
minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 18
minBtn.BorderSizePixel = 0
minBtn.ZIndex = 1005
createCorner(minBtn, 16)
addStroke(minBtn, PALETTE.yellow, 2, 0.2)
applyHoverEffect(minBtn, 0.2, 0)

setMinimized = function(state)
	isMinimized = state
	local target = state and UDim2.new(0, PANEL_W, 0, 50) or UDim2.new(0, PANEL_W, 0, PANEL_H)

	
	pcall(function()
		for _, child in ipairs(main:GetChildren()) do
			if child:IsA("GuiObject") and child.Name ~= "Header" then
				if state then
					
					if child:GetAttribute("AgoraPrevVisible") == nil then
						child:SetAttribute("AgoraPrevVisible", child.Visible)
					end
					child.Visible = false
				else
					
					local prev = child:GetAttribute("AgoraPrevVisible")
					if prev ~= nil then
						
						if MODAL_FRAME_NAMES[child.Name] then
							child.Visible = false
						else
							child.Visible = prev
						end
						child:SetAttribute("AgoraPrevVisible", nil)
					end
				end
			end
		end
	end)

	local tw = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = target,
	})
	tw:Play()
	tw.Completed:Connect(function()
		local cam = workspace.CurrentCamera
		local viewport = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
		local frameAbsSize = main.AbsoluteSize
		local anchor = main.AnchorPoint
		local scaleX, scaleY = main.Position.X.Scale, main.Position.Y.Scale
		local offsetX, offsetY = main.Position.X.Offset, main.Position.Y.Offset
		local baseX = scaleX * viewport.X - anchor.X * frameAbsSize.X
		local baseY = scaleY * viewport.Y - anchor.Y * frameAbsSize.Y
		local minLeft = -baseX
		local maxLeft = (viewport.X - frameAbsSize.X) - baseX
		local minTop = -baseY
		local maxTop = (viewport.Y - frameAbsSize.Y) - baseY
		if maxLeft < minLeft then maxLeft = minLeft end
		if maxTop < minTop then maxTop = minTop end
		offsetX = math.clamp(offsetX, minLeft, maxLeft)
		offsetY = math.clamp(offsetY, minTop, maxTop)
		main.Position = UDim2.new(scaleX, offsetX, scaleY, offsetY)
	end)

	
	pcall(function()
		minBtn.Text = state and "[]" or "-"
	end)
end

minBtn.MouseButton1Click:Connect(function()
	playSfx(6895079853, 0.4)
	setMinimized(not isMinimized)
end)
end 

do
local SIDE_W = 110
sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Parent = main
sidebar.Size = UDim2.new(0, SIDE_W, 1, -60)
sidebar.Position = UDim2.new(0, 8, 0, 55)
sidebar.BackgroundColor3 = PALETTE.bgPanel
sidebar.BackgroundTransparency = 0.2
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 1002
createCorner(sidebar, 10)
addStroke(sidebar, PALETTE.violet, 1.5, 0.4)

local sideLayout = Instance.new("UIListLayout")
sideLayout.Parent = sidebar
sideLayout.Padding = UDim.new(0, 6)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local sidePad = Instance.new("UIPadding")
sidePad.Parent = sidebar
sidePad.PaddingTop = UDim.new(0, 10)
sidePad.PaddingBottom = UDim.new(0, 10)

contentContainer = Instance.new("Frame")
contentContainer.Parent = main
contentContainer.Size = UDim2.new(1, -SIDE_W - 24, 1, -65)
contentContainer.Position = UDim2.new(0, SIDE_W + 16, 0, 58)
contentContainer.BackgroundColor3 = PALETTE.bgCard
contentContainer.BackgroundTransparency = 0.35
contentContainer.BorderSizePixel = 0
contentContainer.ZIndex = 1001
createCorner(contentContainer, 10)
addStroke(contentContainer, PALETTE.cyan, 1, 0.5)

local function makePanel()
	local f = Instance.new("Frame")
	f.Parent = contentContainer
	f.Size = UDim2.new(1, -16, 1, -16)
	f.Position = UDim2.new(0, 8, 0, 8)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 1004
	f.Visible = false
	return f
end

pnlCmds  = makePanel() pnlCmds.Visible = true
pnlMod   = makePanel() 
pnlMod.ClipsDescendants = true
pnlRanks = makePanel()
pnlOpt   = makePanel()
pnlHelp  = makePanel() 

pnlBans = Instance.new("Frame")
pnlBans.Parent = pnlMod
pnlBans.Size = UDim2.new(1, 0, 1, -46)
pnlBans.Position = UDim2.new(0, 0, 0, 46)
pnlBans.BackgroundTransparency = 1
pnlBans.BorderSizePixel = 0
pnlBans.ZIndex = 1004
pnlBans.Visible = true
pnlBans.ClipsDescendants = true

pnlAC = Instance.new("Frame")
pnlAC.Parent = pnlMod
pnlAC.Size = UDim2.new(1, 0, 1, -46)
pnlAC.Position = UDim2.new(0, 0, 0, 46)
pnlAC.BackgroundTransparency = 1
pnlAC.BorderSizePixel = 0
pnlAC.ZIndex = 1004
pnlAC.Visible = false
pnlAC.ClipsDescendants = true

allPanels = {pnlCmds, pnlMod, pnlRanks, pnlOpt, pnlHelp}

local function makeSideTab(icon, label, panel, color, order)
	local b = Instance.new("TextButton")
	b.Parent = sidebar
	b.Size = UDim2.new(1, -10, 0, 48)
	b.LayoutOrder = order
	b.BackgroundColor3 = PALETTE.bgCard
	b.BackgroundTransparency = 0.2
	b.Text = icon .. "\n" .. label
	b.TextColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.ZIndex = 1005
	createCorner(b, 8)
	addStroke(b, color, 1.5, 0.4)
	applyHoverEffect(b, 0.2, 0)
	b.MouseButton1Click:Connect(function()
		playSfx(6895079853, 0.3)
		for _, p in ipairs(allPanels) do p.Visible = false end
		panel.Visible = true
		
		for _, c in ipairs(sidebar:GetChildren()) do
			if c:IsA("TextButton") then
				c.BackgroundTransparency = 0.2
				local st = c:FindFirstChildOfClass("UIStroke")
				if st then st.Thickness = 1.5 end
			end
		end
		b.BackgroundTransparency = 0
		local st = b:FindFirstChildOfClass("UIStroke")
		if st then st.Thickness = 3 end
	end)
	return b
end

btnTabCmd   = makeSideTab("CMD", "CMDS",       pnlCmds,  PALETTE.cyan,    1)
btnTabOpt   = makeSideTab("SET", "OPTS",       pnlOpt,   PALETTE.green,   2)
btnTabHelp  = makeSideTab("?", "AIDE",       pnlHelp,  PALETTE.yellow,  3)
btnTabMod   = makeSideTab("AC", "MODÉR.",     pnlMod,   PALETTE.red,     4)
btnTabRanks = makeSideTab("RANK", "RANKS",      pnlRanks, PALETTE.violet,  5)

btnTabCmd.BackgroundTransparency = 0
do
	local st = btnTabCmd:FindFirstChildOfClass("UIStroke")
	if st then st.Thickness = 3 end
end
end 

local function updateTabVisibility()
	local lvl = rolesHierarchy[myRole] or 6
	
	btnTabCmd.Visible = true
	btnTabOpt.Visible = true
	btnTabHelp.Visible = true
	
	btnTabMod.Visible = (lvl <= 4)
	
	btnTabRanks.Visible = (lvl <= 2)

	
	pcall(function()
		if updateModToolsVisibility then updateModToolsVisibility() end
	end)

	
	if (pnlMod.Visible and not btnTabMod.Visible) or (pnlRanks.Visible and not btnTabRanks.Visible) then
		for _, p in ipairs(allPanels) do p.Visible = false end
		pnlCmds.Visible = true
		for _, c in ipairs(sidebar:GetChildren()) do
			if c:IsA("TextButton") then
				c.BackgroundTransparency = 0.2
				local st = c:FindFirstChildOfClass("UIStroke")
				if st then st.Thickness = 1.5 end
			end
		end
		btnTabCmd.BackgroundTransparency = 0
		local st = btnTabCmd:FindFirstChildOfClass("UIStroke")
		if st then st.Thickness = 3 end
	end
end

updateTabVisibility()

do
local optScroll = Instance.new("ScrollingFrame")
optScroll.Parent = pnlOpt
optScroll.Size = UDim2.new(1, 0, 1, 0)
optScroll.BackgroundTransparency = 1
optScroll.BorderSizePixel = 0
optScroll.ScrollBarThickness = 6
optScroll.ScrollBarImageColor3 = PALETTE.cyan
optScroll.ZIndex = 1005

local optLay = Instance.new("UIListLayout")
optLay.Parent = optScroll
optLay.Padding = UDim.new(0, 10)
optLay.SortOrder = Enum.SortOrder.LayoutOrder
optLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	optScroll.CanvasSize = UDim2.new(0, 0, 0, optLay.AbsoluteContentSize.Y + 20)
end)

local function makeOptLabel(txt)
	local l = Instance.new("TextLabel")
	l.Parent = optScroll
	l.Size = UDim2.new(1, 0, 0, 22)
	l.Text = "> " .. txt
	l.TextColor3 = PALETTE.yellow
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 14
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 1006
	return l
end

makeOptLabel(tr("PREFIXE DES COMMANDES T'CHAT"))

local prefIn = Instance.new("TextBox")
prefIn.Parent = optScroll
prefIn.Size = UDim2.new(0.95, 0, 0, 42)
prefIn.BackgroundColor3 = PALETTE.bgCard
prefIn.BackgroundTransparency = 0.1
prefIn.BorderSizePixel = 0
prefIn.Text = currentPrefix
prefIn.PlaceholderText = tr("Nouveau Préfixe")
prefIn.PlaceholderColor3 = PALETTE.dim
prefIn.TextColor3 = PALETTE.cyan
prefIn.Font = Enum.Font.Code
prefIn.TextSize = 18
prefIn.ClipsDescendants = true
prefIn.ZIndex = 1006
createCorner(prefIn, 8)
addStroke(prefIn, PALETTE.cyan, 1.5, 0.4)

local btnSetPref = createBtn(tr("APPLIQUER LE PRÉFIXE"), UDim2.new(0, 0, 0, 0), UDim2.new(0.95, 0, 0, 38), PALETTE.green, optScroll, 1006)
btnSetPref.MouseButton1Click:Connect(function()
	if settingsEvent then
		pcall(function() settingsEvent:FireServer("SetPrefix", prefIn.Text) end)
	end
end)

makeOptLabel(tr("THÈME"))
local themeContainer = Instance.new("Frame")
themeContainer.Parent = optScroll
themeContainer.Size = UDim2.new(0.95, 0, 0, 42)
themeContainer.BackgroundTransparency = 1
themeContainer.ZIndex = 1006
local themeLayout = Instance.new("UIListLayout")
themeLayout.Parent = themeContainer
themeLayout.FillDirection = Enum.FillDirection.Horizontal
themeLayout.Padding = UDim.new(0, 6)
themeLayout.SortOrder = Enum.SortOrder.LayoutOrder

local themeColors = {
	["Cyberpunk"] = PALETTE.magenta,
	["Sombre"]    = Color3.fromRGB(70, 70, 80),
	["Clair"]     = Color3.fromRGB(220, 220, 230),
	["Glass"]     = Color3.fromRGB(100, 140, 200),
}

for _, themeName in ipairs({"Cyberpunk", "Sombre", "Clair", "Glass"}) do
	local tb = createBtn(themeName, UDim2.new(0, 0, 0, 0), UDim2.new(0, 100, 0, 38), themeColors[themeName] or PALETTE.bgCard, themeContainer, 1006)
	tb.MouseButton1Click:Connect(function()
		applyTheme(themeName)
	end)
end

makeOptLabel(tr("ENVOYER UN FEEDBACK / BUG AU FONDATEUR"))
feedIn = Instance.new("TextBox")
feedIn.Parent = optScroll
feedIn.Size = UDim2.new(0.95, 0, 0, 95)
feedIn.BackgroundColor3 = PALETTE.bgCard
feedIn.BackgroundTransparency = 0.1
feedIn.BorderSizePixel = 0
feedIn.Text = ""
feedIn.PlaceholderText = tr("Décrivez votre bug...")
feedIn.PlaceholderColor3 = PALETTE.dim
feedIn.TextColor3 = PALETTE.white
feedIn.Font = Enum.Font.Gotham
feedIn.TextSize = 13
feedIn.TextWrapped = true
feedIn.ClipsDescendants = true
feedIn.TextXAlignment = Enum.TextXAlignment.Left
feedIn.TextYAlignment = Enum.TextYAlignment.Top
feedIn.ClearTextOnFocus = false
feedIn.ZIndex = 1006
createCorner(feedIn, 8)
addStroke(feedIn, PALETTE.violet, 1.5, 0.4)

btnFeed = createBtn(tr("ENVOYER VIA DISCORD WEBHOOK"), UDim2.new(0, 0, 0, 0), UDim2.new(0.95, 0, 0, 38), PALETTE.cyan, optScroll, 1006)
btnFeed.MouseButton1Click:Connect(function()
	if #feedIn.Text < 5 then return end
	if feedbackEvent then
		pcall(function() feedbackEvent:FireServer(feedIn.Text) end)
	end
	feedIn.Text = ""
	playSfx(2865227271, 0.6)
end)

local lblModTools = makeOptLabel("OUTILS MODÉRATION")
lblModTools.Visible = false

local btnCmdBar2 = createBtn("⌨ OUVRIR CMD BAR 2", UDim2.new(0, 0, 0, 0), UDim2.new(0.95, 0, 0, 42), PALETTE.violet, optScroll, 1006)
btnCmdBar2.Visible = false
btnCmdBar2.MouseButton1Click:Connect(function()
	
	pcall(function()
		if cmdBarPnl then
			cmdBarPnl.Visible = not cmdBarPnl.Visible
			if cmdBarPnl.Visible then
				
				local box = cmdBarPnl:FindFirstChildOfClass("TextBox")
				if box then box:CaptureFocus() end
			end
		end
	end)
end)

_muteAC      = false  
_muteTickets = false
local btnMuteAC = createBtn("MUTE NOTIFS ANTI-CHEAT : OFF", UDim2.new(0, 0, 0, 0), UDim2.new(0.95, 0, 0, 38), PALETTE.violet, optScroll, 1006)
btnMuteAC.Visible = false
btnMuteAC.MouseButton1Click:Connect(function()
	_muteAC = not _muteAC
	btnMuteAC.Text = _muteAC and "MUTE NOTIFS ANTI-CHEAT : ON" or "MUTE NOTIFS ANTI-CHEAT : OFF"
	btnMuteAC.BackgroundColor3 = _muteAC and PALETTE.red or PALETTE.violet
end)
local btnMuteTickets = createBtn("MUTE NOTIFS TICKETS : OFF", UDim2.new(0, 0, 0, 0), UDim2.new(0.95, 0, 0, 38), PALETTE.violet, optScroll, 1006)
btnMuteTickets.Visible = false
btnMuteTickets.MouseButton1Click:Connect(function()
	_muteTickets = not _muteTickets
	btnMuteTickets.Text = _muteTickets and "MUTE NOTIFS TICKETS : ON" or "MUTE NOTIFS TICKETS : OFF"
	btnMuteTickets.BackgroundColor3 = _muteTickets and PALETTE.red or PALETTE.violet
end)

updateModToolsVisibility = function()
	local lvl = rolesHierarchy[myRole] or 6
	local canSee = (lvl <= 4)
	pcall(function()
		lblModTools.Visible = canSee
		btnCmdBar2.Visible  = canSee
		
		local canMute = (lvl <= 3)
		btnMuteAC.Visible = canMute
		btnMuteTickets.Visible = canMute
	end)
end

local copyrightContainer = Instance.new("Frame")
copyrightContainer.Parent = optScroll
copyrightContainer.Size = UDim2.new(1, 0, 0, 60)
copyrightContainer.BackgroundTransparency = 1
copyrightContainer.LayoutOrder = 9999
copyrightContainer.ZIndex = 1006

local footerLogo = Instance.new("ImageLabel")
footerLogo.Name = "FooterLogo"
footerLogo.Parent = copyrightContainer
footerLogo.Size = UDim2.new(0, 32, 0, 32)
footerLogo.Position = UDim2.new(0.5, -16, 0, 0)
footerLogo.BackgroundTransparency = 1
footerLogo.Image = "rbxassetid://73314612607499"
footerLogo.ScaleType = Enum.ScaleType.Fit
footerLogo.ImageTransparency = 0.15
footerLogo.ZIndex = 1007
local copyrightLbl = Instance.new("TextLabel")
copyrightLbl.Parent = copyrightContainer
copyrightLbl.Size = UDim2.new(1, 0, 0, 22)
copyrightLbl.Position = UDim2.new(0, 0, 0, 36)
copyrightLbl.BackgroundTransparency = 1
copyrightLbl.Text = "(c) Agora Admin v" .. AGORA_VERSION .. " - fait par " .. AGORA_AUTHOR
copyrightLbl.TextColor3 = PALETTE.dim
copyrightLbl.Font = Enum.Font.Code
copyrightLbl.TextSize = 11
copyrightLbl.TextXAlignment = Enum.TextXAlignment.Center
copyrightLbl.ZIndex = 1006
end 

do
local helpScroll = Instance.new("ScrollingFrame")
helpScroll.Parent = pnlHelp
helpScroll.Size = UDim2.new(1, 0, 1, 0)
helpScroll.BackgroundTransparency = 1
helpScroll.BorderSizePixel = 0
helpScroll.ScrollBarThickness = 6
helpScroll.ScrollBarImageColor3 = PALETTE.yellow
helpScroll.ZIndex = 1005

local helpLay = Instance.new("UIListLayout")
helpLay.Parent = helpScroll
helpLay.Padding = UDim.new(0, 10)
helpLay.SortOrder = Enum.SortOrder.LayoutOrder
helpLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	helpScroll.CanvasSize = UDim2.new(0, 0, 0, helpLay.AbsoluteContentSize.Y + 20)
end)

local helpSections = {}
local config = _G.AgoraConfig
if config and config.helpText then
	for _, sec in ipairs(config.helpText) do
		table.insert(helpSections, {
			t = sec.title:gsub("{version}", AGORA_VERSION):gsub("{author}", AGORA_AUTHOR),
			d = sec.desc:gsub("{version}", AGORA_VERSION):gsub("{author}", AGORA_AUTHOR)
		})
	end
else
	helpSections = {
		{t = "[GAME] BIENVENUE DANS AGORA ADMIN v" .. AGORA_VERSION, d = "Panneau d'administration complet pour Roblox."},
		{t = "[SUPPORT] SUPPORT & DISCORD", d = "Rejoins discord.gg/agora-admin pour obtenir ta clé et du support."},
	}
end

for i, sec in ipairs(helpSections) do
	local card = Instance.new("Frame")
	card.Parent = helpScroll
	card.Size = UDim2.new(1, -10, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = PALETTE.bgCard
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.LayoutOrder = i
	card.ZIndex = 1006
	createCorner(card, 8)
	addStroke(card, PALETTE.yellow, 1, 0.5)

	local tLbl = Instance.new("TextLabel")
	tLbl.Parent = card
	tLbl.Size = UDim2.new(1, -20, 0, 26)
	tLbl.Position = UDim2.new(0, 10, 0, 8)
	tLbl.BackgroundTransparency = 1
	tLbl.Text = sec.t
	tLbl.TextColor3 = PALETTE.cyan
	tLbl.Font = Enum.Font.GothamBlack
	tLbl.TextSize = 14
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.ZIndex = 1007

	local dLbl = Instance.new("TextLabel")
	dLbl.Parent = card
	dLbl.Size = UDim2.new(1, -20, 0, 0)
	dLbl.Position = UDim2.new(0, 10, 0, 34)
	dLbl.AutomaticSize = Enum.AutomaticSize.Y
	dLbl.BackgroundTransparency = 1
	dLbl.Text = sec.d
	dLbl.TextColor3 = PALETTE.white
	dLbl.Font = Enum.Font.Gotham
	dLbl.TextSize = 13
	dLbl.TextWrapped = true
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.TextYAlignment = Enum.TextYAlignment.Top
	dLbl.ZIndex = 1007

	local pad = Instance.new("UIPadding")
	pad.Parent = card
	pad.PaddingBottom = UDim.new(0, 12)
end
end 

do
local acLogs = {} 
local modNavBar = Instance.new("Frame")
modNavBar.Parent = pnlMod
modNavBar.Size = UDim2.new(1, 0, 0, 42)
modNavBar.Position = UDim2.new(0, 0, 0, 0)
modNavBar.BackgroundColor3 = PALETTE.bgCard
modNavBar.BackgroundTransparency = 0.2
modNavBar.BorderSizePixel = 0
modNavBar.ZIndex = 1006
createCorner(modNavBar, 8)
addStroke(modNavBar, PALETTE.red, 1.5, 0.4)

local modPrev = Instance.new("TextButton")
modPrev.Parent = modNavBar
modPrev.Size = UDim2.new(0, 34, 0, 30)
modPrev.Position = UDim2.new(0, 6, 0, 6)
modPrev.BackgroundColor3 = PALETTE.bgDeep
modPrev.BackgroundTransparency = 0.1
modPrev.Text = "<"
modPrev.TextColor3 = PALETTE.cyan
modPrev.Font = Enum.Font.GothamBlack
modPrev.TextSize = 18
modPrev.BorderSizePixel = 0
modPrev.AutoButtonColor = false
modPrev.ZIndex = 1008
createCorner(modPrev, 6)
addStroke(modPrev, PALETTE.cyan, 1.5, 0.3)

local modNext = Instance.new("TextButton")
modNext.Parent = modNavBar
modNext.Size = UDim2.new(0, 34, 0, 30)
modNext.Position = UDim2.new(1, -40, 0, 6)
modNext.BackgroundColor3 = PALETTE.bgDeep
modNext.BackgroundTransparency = 0.1
modNext.Text = ">"
modNext.TextColor3 = PALETTE.cyan
modNext.Font = Enum.Font.GothamBlack
modNext.TextSize = 18
modNext.BorderSizePixel = 0
modNext.AutoButtonColor = false
modNext.ZIndex = 1008
createCorner(modNext, 6)
addStroke(modNext, PALETTE.cyan, 1.5, 0.3)

modTitle = Instance.new("TextLabel")
modTitle.Parent = modNavBar
modTitle.Size = UDim2.new(1, -88, 0, 22)
modTitle.Position = UDim2.new(0, 44, 0, 4)
modTitle.BackgroundTransparency = 1
modTitle.Text = "[BAN] BANS"
modTitle.TextColor3 = PALETTE.red
modTitle.Font = Enum.Font.GothamBlack
modTitle.TextSize = 15
modTitle.TextXAlignment = Enum.TextXAlignment.Center
modTitle.ZIndex = 1008

local modDotBar = Instance.new("Frame")
modDotBar.Parent = modNavBar
modDotBar.Size = UDim2.new(1, -88, 0, 4)
modDotBar.Position = UDim2.new(0, 44, 0, 32)
modDotBar.BackgroundColor3 = PALETTE.bgDeep
modDotBar.BackgroundTransparency = 0.4
modDotBar.BorderSizePixel = 0
modDotBar.ZIndex = 1008
createCorner(modDotBar, 2)

modDotFill = Instance.new("Frame")
modDotFill.Parent = modDotBar
modDotFill.Size = UDim2.new(0.5, 0, 1, 0)
modDotFill.Position = UDim2.new(0, 0, 0, 0)
modDotFill.BackgroundColor3 = PALETTE.cyan
modDotFill.BorderSizePixel = 0
modDotFill.ZIndex = 1009
createCorner(modDotFill, 2)

modSubIndex = 1
local modSubCount = 2

local function setModSub(idx, direction)
	direction = direction or 0
	if idx < 1 then idx = modSubCount end
	if idx > modSubCount then idx = 1 end
	modSubIndex = idx

	
	if idx == 1 then
		modTitle.Text = "[BAN] BANS"
		modTitle.TextColor3 = PALETTE.red
	else
		modTitle.Text = "[AC] AC LOGS"
		modTitle.TextColor3 = PALETTE.magenta
	end

	
	TweenService:Create(modDotFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new((idx - 1) / modSubCount, 0, 0, 0),
		Size = UDim2.new(1 / modSubCount, 0, 1, 0),
	}):Play()

	
	local from = (direction >= 0) and UDim2.new(1.1, 0, 0, 46) or UDim2.new(-1.1, 0, 0, 46)
	local target = (idx == 1) and pnlBans or pnlAC
	local other = (idx == 1) and pnlAC or pnlBans

	other.Visible = false
	target.Position = from
	target.Visible = true
	TweenService:Create(target, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 46),
	}):Play()

	playSfx(6895079853, 0.3)
end

modPrev.MouseButton1Click:Connect(function() setModSub(modSubIndex - 1, -1) end)
modNext.MouseButton1Click:Connect(function() setModSub(modSubIndex + 1,  1) end)

local acScroll = Instance.new("ScrollingFrame")
acScroll.Parent = pnlAC
acScroll.Size = UDim2.new(1, 0, 1, -30)
acScroll.Position = UDim2.new(0, 0, 0, 30)
acScroll.BackgroundTransparency = 1
acScroll.BorderSizePixel = 0
acScroll.ScrollBarThickness = 6
acScroll.ScrollBarImageColor3 = PALETTE.magenta
acScroll.ZIndex = 1005

local acLay = Instance.new("UIListLayout")
acLay.Parent = acScroll
acLay.Padding = UDim.new(0, 6)
acLay.SortOrder = Enum.SortOrder.LayoutOrder
acLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	acScroll.CanvasSize = UDim2.new(0, 0, 0, acLay.AbsoluteContentSize.Y + 12)
end)

local acHeader = Instance.new("TextLabel")
acHeader.Parent = pnlAC
acHeader.Size = UDim2.new(1, 0, 0, 24)
acHeader.BackgroundTransparency = 1
acHeader.Text = "[AC] ALERTES ANTI-CHEAT (0)"
acHeader.TextColor3 = PALETTE.magenta
acHeader.Font = Enum.Font.GothamBlack
acHeader.TextSize = 14
acHeader.TextXAlignment = Enum.TextXAlignment.Left
acHeader.ZIndex = 1006

renderACLogs = function()
	for _, v in pairs(acScroll:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end
	acHeader.Text = "[AC] ALERTES ANTI-CHEAT (" .. #acLogs .. ")"
	for i, logEntry in ipairs(acLogs) do
		local f = Instance.new("Frame")
		f.Parent = acScroll
		f.Size = UDim2.new(1, -10, 0, 76)  
		f.BackgroundColor3 = PALETTE.bgCard
		f.BackgroundTransparency = 0.15
		f.BorderSizePixel = 0
		f.LayoutOrder = i
		f.ZIndex = 1007
		createCorner(f, 6)
		addStroke(f, PALETTE.magenta, 1, 0.5)

		local tStamp = Instance.new("TextLabel")
		tStamp.Parent = f
		tStamp.Size = UDim2.new(0.3, 0, 0, 18)
		tStamp.Position = UDim2.new(0, 8, 0, 4)
		tStamp.BackgroundTransparency = 1
		tStamp.Text = "[" .. (logEntry.time or "??") .. "]"
		tStamp.TextColor3 = PALETTE.yellow
		tStamp.Font = Enum.Font.Code
		tStamp.TextSize = 11
		tStamp.TextXAlignment = Enum.TextXAlignment.Left
		tStamp.ZIndex = 1008

		local tType = Instance.new("TextLabel")
		tType.Parent = f
		tType.Size = UDim2.new(0.65, 0, 0, 18)
		tType.Position = UDim2.new(0.32, 0, 0, 4)
		tType.BackgroundTransparency = 1
		tType.Text = tostring(logEntry.type or "UNKNOWN")
		tType.TextColor3 = PALETTE.magenta
		tType.Font = Enum.Font.GothamBold
		tType.TextSize = 12
		tType.TextXAlignment = Enum.TextXAlignment.Left
		tType.ZIndex = 1008
		
		local tSuspect = Instance.new("TextLabel")
		tSuspect.Parent = f
		tSuspect.Size = UDim2.new(1, -16, 0, 18)
		tSuspect.Position = UDim2.new(0, 8, 0, 22)
		tSuspect.BackgroundTransparency = 1
		tSuspect.Text = "👤 " .. tostring(logEntry.suspect or "?")
		tSuspect.TextColor3 = PALETTE.cyan
		tSuspect.Font = Enum.Font.GothamBold
		tSuspect.TextSize = 13
		tSuspect.TextXAlignment = Enum.TextXAlignment.Left
		tSuspect.ZIndex = 1008

		local tDesc = Instance.new("TextLabel")
		tDesc.Parent = f
		tDesc.Size = UDim2.new(1, -16, 0, 30)
		tDesc.Position = UDim2.new(0, 8, 0, 42)
		tDesc.BackgroundTransparency = 1
		tDesc.Text = tostring(logEntry.desc or "")
		tDesc.TextColor3 = PALETTE.white
		tDesc.Font = Enum.Font.Gotham
		tDesc.TextSize = 12
		tDesc.TextWrapped = true
		tDesc.TextXAlignment = Enum.TextXAlignment.Left
		tDesc.TextYAlignment = Enum.TextYAlignment.Top
		tDesc.ZIndex = 1008
	end
end

addACLog = function(entry)
	entry.time = os.date("%H:%M:%S")
	table.insert(acLogs, 1, entry)
	while #acLogs > 100 do
		table.remove(acLogs)
	end
	if pnlAC.Visible then
		renderACLogs()
	end
end
end 

do
local notifFrame = Instance.new("Frame")
notifFrame.Parent = gui
notifFrame.Name = "NotificationPanel"
notifFrame.Size = UDim2.new(0, 360, 0, 92)
notifFrame.AnchorPoint = Vector2.new(1, 1)
notifFrame.Position = UDim2.new(1.5, 0, 1, -20)
notifFrame.BackgroundColor3 = PALETTE.bgDeep
notifFrame.BackgroundTransparency = 0.1
notifFrame.BorderSizePixel = 0
notifFrame.ZIndex = 9999
createCorner(notifFrame, 12)
addGradient(notifFrame, PALETTE.bgDeep, PALETTE.bgPanel, 135)
addNeonGlow(notifFrame, PALETTE.cyan)

local nIcon = Instance.new("TextLabel")
nIcon.Parent = notifFrame
nIcon.Size = UDim2.new(0, 36, 0, 36)
nIcon.Position = UDim2.new(0, 10, 0, 10)
nIcon.BackgroundTransparency = 1
nIcon.Text = "!"
nIcon.TextSize = 26
nIcon.ZIndex = 10000

local nText = Instance.new("TextLabel")
nText.Parent = notifFrame
nText.Size = UDim2.new(1, -90, 1, -18)
nText.Position = UDim2.new(0, 52, 0, 5)
nText.BackgroundTransparency = 1
nText.TextColor3 = PALETTE.cyan
nText.Font = Enum.Font.GothamBold
nText.TextSize = 14
nText.TextWrapped = true
nText.TextXAlignment = Enum.TextXAlignment.Left
nText.TextYAlignment = Enum.TextYAlignment.Center
nText.ZIndex = 10000

local nClose = Instance.new("TextButton")
nClose.Parent = notifFrame
nClose.Size = UDim2.new(0, 24, 0, 24)
nClose.Position = UDim2.new(1, -30, 0, 6)
nClose.BackgroundColor3 = PALETTE.red
nClose.BackgroundTransparency = 0.2
nClose.Text = "X"
nClose.TextColor3 = Color3.new(1, 1, 1)
nClose.Font = Enum.Font.GothamBold
nClose.TextSize = 13
nClose.BorderSizePixel = 0
nClose.ZIndex = 10001
createCorner(nClose, 12)
nClose.MouseButton1Click:Connect(function()
	TweenService:Create(notifFrame, TweenInfo.new(0.3), {Position = UDim2.new(1.5, 0, 1, -20)}):Play()
end)

local nBar = Instance.new("Frame")
nBar.Parent = notifFrame
nBar.Size = UDim2.new(1, 0, 0, 4)
nBar.Position = UDim2.new(0, 0, 1, -4)
nBar.BackgroundColor3 = PALETTE.magenta
nBar.BorderSizePixel = 0
nBar.ZIndex = 10001
createCorner(nBar, 2)

local notifCancelTween = nil
local notifDuration    = 5

showNotif = function(msg)
	playSfx(2865227271, 0.6)
	nText.Text = tostring(msg)
	nBar.Size = UDim2.new(1, 0, 0, 4)

	if notifCancelTween then notifCancelTween:Cancel() end

	TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -20, 1, -20),
	}):Play()

	TweenService:Create(nBar, TweenInfo.new(notifDuration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 0, 4),
	}):Play()

	task.delay(notifDuration, function()
		TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(1.5, 0, 1, -20),
		}):Play()
	end)
end
end 

do
local acAlertContainer = Instance.new("Frame")
acAlertContainer.Name = "ACAlertContainer"
acAlertContainer.Parent = gui
acAlertContainer.Size = UDim2.new(0, 340, 1, -20)
acAlertContainer.Position = UDim2.new(1, -360, 0, 10)
acAlertContainer.BackgroundTransparency = 1
acAlertContainer.BorderSizePixel = 0
acAlertContainer.ZIndex = 9998

local acAlertLay = Instance.new("UIListLayout")
acAlertLay.Parent = acAlertContainer
acAlertLay.Padding = UDim.new(0, 8)
acAlertLay.SortOrder = Enum.SortOrder.LayoutOrder
acAlertLay.VerticalAlignment = Enum.VerticalAlignment.Top

spawnACAlert = function(typ, desc, suspect)
	
	local visible = {}
	for _, c in ipairs(acAlertContainer:GetChildren()) do
		if c:IsA("Frame") then table.insert(visible, c) end
	end
	while #visible >= 2 do
		local oldest = visible[1]
		table.remove(visible, 1)
		if oldest then oldest:Destroy() end
	end

	local alert = Instance.new("Frame")
	alert.Parent = acAlertContainer
	alert.Size = UDim2.new(1, 0, 0, 78)
	alert.BackgroundColor3 = PALETTE.bgDeep
	alert.BackgroundTransparency = 0.05
	alert.BorderSizePixel = 0
	alert.LayoutOrder = tick() * 1000
	alert.ZIndex = 9999
	createCorner(alert, 10)
	addGradient(alert, Color3.fromRGB(80, 0, 0), PALETTE.bgDeep, 135)
	addNeonGlow(alert, PALETTE.red)

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Parent = alert
	iconLbl.Size = UDim2.new(0, 42, 1, 0)
	iconLbl.Position = UDim2.new(0, 6, 0, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = "[AC]"
	iconLbl.TextSize = 30
	iconLbl.ZIndex = 10000

	local tLbl = Instance.new("TextLabel")
	tLbl.Parent = alert
	tLbl.Size = UDim2.new(1, -60, 0, 22)
	tLbl.Position = UDim2.new(0, 50, 0, 6)
	tLbl.BackgroundTransparency = 1
	tLbl.Text = "ANTI-CHEAT: " .. tostring(typ)
	tLbl.TextColor3 = PALETTE.red
	tLbl.Font = Enum.Font.GothamBlack
	tLbl.TextSize = 13
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.ZIndex = 10000

	local dLbl = Instance.new("TextLabel")
	dLbl.Parent = alert
	dLbl.Size = UDim2.new(1, -60, 0, 42)
	dLbl.Position = UDim2.new(0, 50, 0, 28)
	dLbl.BackgroundTransparency = 1
	dLbl.Text = (suspect and (suspect .. " - ") or "") .. tostring(desc)
	dLbl.TextColor3 = PALETTE.white
	dLbl.Font = Enum.Font.GothamMedium
	dLbl.TextSize = 11
	dLbl.TextWrapped = true
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.TextYAlignment = Enum.TextYAlignment.Top
	dLbl.ZIndex = 10000

	
	local clickBtn = Instance.new("TextButton")
	clickBtn.Parent = alert
	clickBtn.Size = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 10001
	clickBtn.MouseButton1Click:Connect(function()
		if main then
			main.Visible = true
			for _, p in ipairs(allPanels) do p.Visible = false end
			pnlMod.Visible = true
			
			pnlBans.Visible = false
			pnlAC.Visible = true
			pnlAC.Position = UDim2.new(0, 0, 0, 46)
			modSubIndex = 2
			modTitle.Text = "[AC] AC LOGS"
			modTitle.TextColor3 = PALETTE.magenta
			modDotFill.Position = UDim2.new(0.5, 0, 0, 0)
			modDotFill.Size = UDim2.new(0.5, 0, 1, 0)
			
			for _, c in ipairs(sidebar:GetChildren()) do
				if c:IsA("TextButton") then
					c.BackgroundTransparency = 0.2
					local st = c:FindFirstChildOfClass("UIStroke")
					if st then st.Thickness = 1.5 end
				end
			end
			btnTabMod.BackgroundTransparency = 0
			local st = btnTabMod:FindFirstChildOfClass("UIStroke")
			if st then st.Thickness = 3 end
			renderACLogs()
		end
		alert:Destroy()
	end)

	playSfx(2865227271, 0.7)

	
	task.delay(30, function()
		if alert and alert.Parent then
			TweenService:Create(alert, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
			task.wait(0.4)
			if alert and alert.Parent then alert:Destroy() end
		end
	end)
end
end 

do
local warnFrame = Instance.new("Frame")
warnFrame.Parent = gui
warnFrame.Name = "WarningOverlay"
warnFrame.Size = UDim2.new(1, 0, 1, 0)
warnFrame.Position = UDim2.new(0, 0, 0, 0)
warnFrame.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
warnFrame.BackgroundTransparency = 1
warnFrame.BorderSizePixel = 0
warnFrame.ZIndex = 10005

local warnTxt = Instance.new("TextLabel")
warnTxt.Parent = warnFrame
warnTxt.Size = UDim2.new(1, -40, 0, 300)
warnTxt.Position = UDim2.new(0, 20, 0.5, -150)
warnTxt.BackgroundTransparency = 1
warnTxt.TextColor3 = Color3.new(1, 1, 1)
warnTxt.Font = Enum.Font.GothamBlack
warnTxt.TextSize = 45
warnTxt.TextWrapped = true
warnTxt.TextTransparency = 1
warnTxt.TextXAlignment = Enum.TextXAlignment.Center
warnTxt.TextYAlignment = Enum.TextYAlignment.Center
warnTxt.TextStrokeTransparency = 1
warnTxt.TextStrokeColor3 = PALETTE.magenta
warnTxt.ZIndex = 10006

triggerWarn = function(msg)
	playSfx(2865227271, 1)
	warnTxt.Text = tr("[!] AVERTISSEMENT [!]\n\n") .. msg
	local tIn = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(warnFrame, tIn, {BackgroundTransparency = 0.4}):Play()
	TweenService:Create(warnTxt, tIn, {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
	task.delay(6, function()
		local tOut = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		TweenService:Create(warnFrame, tOut, {BackgroundTransparency = 1}):Play()
		TweenService:Create(warnTxt, tOut, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end)
end
end 

do
local topAnn = Instance.new("Frame")
topAnn.Parent = gui
topAnn.Size = UDim2.new(0.45, 0, 0, 135)
topAnn.Position = UDim2.new(0.275, 0, -0.5, 0)
topAnn.BackgroundColor3 = PALETTE.bgDeep
topAnn.BackgroundTransparency = 0.15
topAnn.BorderSizePixel = 0
topAnn.ZIndex = 10000
createCorner(topAnn, 16)
addGradient(topAnn, PALETTE.bgDeep, PALETTE.bgPanel, 90)
addNeonGlow(topAnn, PALETTE.yellow)

local aT = Instance.new("TextLabel")
aT.Name = "AnnounceTitle"
aT.Parent = topAnn
aT.Size = UDim2.new(1, 0, 0, 45)
aT.BackgroundTransparency = 1
aT.TextColor3 = PALETTE.yellow
aT.Font = Enum.Font.GothamBlack
aT.TextSize = 22
aT.TextXAlignment = Enum.TextXAlignment.Center
aT.TextYAlignment = Enum.TextYAlignment.Center
aT.ZIndex = 10001

local aM = Instance.new("TextLabel")
aM.Parent = topAnn
aM.Size = UDim2.new(0.9, 0, 0, 80)
aM.Position = UDim2.new(0.05, 0, 0, 45)
aM.BackgroundTransparency = 1
aM.TextColor3 = PALETTE.white
aM.Font = Enum.Font.GothamBold
aM.TextSize = 18
aM.TextWrapped = true
aM.TextXAlignment = Enum.TextXAlignment.Center
aM.TextYAlignment = Enum.TextYAlignment.Top
aM.ZIndex = 10001

triggerAnn = function(role, name, msg)
	playSfx(2865227271, 0.9)
	
	local _t = THEMES[currentTheme] or THEMES["Cyberpunk"]
	topAnn.BackgroundColor3 = _t.bg
	topAnn.BackgroundTransparency = _t.bgTrans
	aT.TextColor3 = _t.accent or PALETTE.yellow
	aM.TextColor3 = _t.text or PALETTE.white
	local _stroke = topAnn:FindFirstChildOfClass("UIStroke")
	if _stroke then _stroke.Color = _t.stroke end
	aT.Text = (role == "SERVEUR") and tr("[SYSTEME]") or ("[" .. string.upper(role) .. "] " .. name)
	aM.Text = msg
	TweenService:Create(topAnn, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.275, 0, 0.05, 0),
	}):Play()
	task.delay(8, function()
		TweenService:Create(topAnn, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.275, 0, -0.5, 0),
		}):Play()
	end)
end
end 

do

local cmdsHeader = Instance.new("Frame")
cmdsHeader.Parent = pnlCmds
cmdsHeader.Size = UDim2.new(1, 0, 0, 44)
cmdsHeader.Position = UDim2.new(0, 0, 0, 0)
cmdsHeader.BackgroundTransparency = 1
cmdsHeader.BorderSizePixel = 0
cmdsHeader.ZIndex = 1006
local searchBox = Instance.new("TextBox", cmdsHeader)
searchBox.Name = "CmdSearchBox"
searchBox.Size = UDim2.new(1, -8, 0, 36)
searchBox.Position = UDim2.new(0, 4, 0, 4)
searchBox.PlaceholderText = "[FIND] Recherche commande..."
searchBox.Text = ""
searchBox.BackgroundColor3 = PALETTE.bgCard
searchBox.TextColor3 = PALETTE.white
searchBox.PlaceholderColor3 = PALETTE.dim
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 1007
createCorner(searchBox, 8)
addStroke(searchBox, PALETTE.cyan, 1, 0.4)
cmdScroll = Instance.new("ScrollingFrame")
cmdScroll.Parent = pnlCmds
cmdScroll.Size = UDim2.new(1, 0, 1, -44)
cmdScroll.Position = UDim2.new(0, 0, 0, 44)
cmdScroll.BackgroundTransparency = 1
cmdScroll.BorderSizePixel = 0
cmdScroll.ScrollBarThickness = 6
cmdScroll.ScrollBarImageColor3 = PALETTE.cyan
cmdScroll.ZIndex = 1005

cmdLay = Instance.new("UIListLayout")
cmdLay.Parent = cmdScroll
cmdLay.Padding = UDim.new(0, 10)
cmdLay.SortOrder = Enum.SortOrder.LayoutOrder
cmdLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	cmdScroll.CanvasSize = UDim2.new(0, 0, 0, cmdLay.AbsoluteContentSize.Y + 20)
end)

local _searchText = ""
local EMOTE_NAMES = {
	wave=true, dance=true, dance2=true, dance3=true, laugh=true,
	cheer=true, point=true, salute=true, shrug=true, hype=true,
	floss=true, shuffle=true, toprock=true, shy=true, celebrate=true, superhero=true,
}
local function _isEmoteCmd(cmdName)
	return EMOTE_NAMES[cmdName] == true
end

local function applyCmdsFilter()
	local search = _searchText:lower()
	for _, child in ipairs(cmdScroll:GetChildren()) do
		if child:IsA("Frame") then
			local cmdName = child:GetAttribute("CmdName") or ""
			local isEmote = child:GetAttribute("IsEmote") == true
			local isEmoteSubGrid = child:GetAttribute("IsEmoteSubGrid") == true
			if isEmoteSubGrid then
			elseif isEmote then
				child.Visible = (search ~= "") and (cmdName:lower():find(search, 1, true) ~= nil)
			else
				local matchSearch = (search == "")
					or (cmdName:lower():find(search, 1, true) ~= nil)
				child.Visible = matchSearch
			end
		end
	end
end
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	_searchText = searchBox.Text
	applyCmdsFilter()
end)

_G._AgoraApplyCmdsFilter = applyCmdsFilter
_G._AgoraIsEmoteCmd = _isEmoteCmd
_G._AgoraEmoteNames = EMOTE_NAMES

editFrame = Instance.new("Frame")
editFrame.Parent = main
editFrame.Name = "EditPanel"
editFrame.Size = UDim2.new(0, 400, 0, 360)
editFrame.Position = UDim2.new(0.5, -200, 0.5, -180)
editFrame.BackgroundColor3 = PALETTE.bgDeep
editFrame.BackgroundTransparency = 0.05
editFrame.BorderSizePixel = 0
editFrame.Visible = false
editFrame.ZIndex = 2000
createCorner(editFrame, 12)
addNeonGlow(editFrame, PALETTE.violet)

etit = Instance.new("TextLabel")
etit.Parent = editFrame
etit.Size = UDim2.new(1, 0, 0, 45)
etit.BackgroundTransparency = 1
etit.TextColor3 = PALETTE.cyan
etit.Font = Enum.Font.GothamBlack
etit.TextSize = 18
etit.TextXAlignment = Enum.TextXAlignment.Center
etit.TextYAlignment = Enum.TextYAlignment.Center
etit.ZIndex = 2005

ecat = Instance.new("TextLabel")
ecat.Parent = editFrame
ecat.Size = UDim2.new(1, 0, 0, 30)
ecat.Position = UDim2.new(0, 0, 0, 40)
ecat.BackgroundTransparency = 1
ecat.TextColor3 = PALETTE.magenta
ecat.Font = Enum.Font.GothamBold
ecat.TextSize = 14
ecat.TextXAlignment = Enum.TextXAlignment.Center
ecat.TextYAlignment = Enum.TextYAlignment.Center
ecat.ZIndex = 2005

local exBtn = createBtn("X", UDim2.new(1, -38, 0, 8), UDim2.new(0, 30, 0, 30), PALETTE.red, editFrame, 2005)
createCorner(exBtn, 15)
exBtn.MouseButton1Click:Connect(function() editFrame.Visible = false end)

local function execCommandFromUI(cmdName)
	local cmdText = currentPrefix .. cmdName .. " me"
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local tc = TextChatService:FindFirstChild("TextChannels")
			if tc and tc:FindFirstChild("RBXGeneral") then
				tc.RBXGeneral:SendAsync(cmdText)
			end
		else
			local dc = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			if dc and dc:FindFirstChild("SayMessageRequest") then
				dc.SayMessageRequest:FireServer(cmdText, "All")
			end
		end
	end)
	
end

refreshCmdUI = function()
	for _, v in pairs(cmdScroll:GetChildren()) do
		if v:IsA("Frame") or v:IsA("TextLabel") then v:Destroy() end
	end
	
	
	local _roleAliases = {
		["Staff"] = "Staffs", ["Staffs"] = "Staff",
		["Joueur"] = "Joueurs", ["Joueurs"] = "Joueur",
	}
	local sortIndex = 0
	for _, role in ipairs(rolesOrder) do
		local sortedCmds = {}
		for cmd, data in pairs(cmdRegistry) do
			if data.Role == role or _roleAliases[data.Role] == role then
				table.insert(sortedCmds, {Cmd = cmd, Data = data})
			end
		end
		table.sort(sortedCmds, function(a, b) return a.Cmd < b.Cmd end)

		if #sortedCmds > 0 then
			local catLab = Instance.new("TextLabel")
			catLab.Parent = cmdScroll
			catLab.Size = UDim2.new(1, -5, 0, 36)
			catLab.BackgroundColor3 = PALETTE.bgPanel
			catLab.BackgroundTransparency = 0.1
			catLab.BorderSizePixel = 0
			catLab.Text = "  " .. tr("   > NIVEAU REQUIS : ") .. string.upper(role)
			catLab.TextColor3 = roleColors[role] or PALETTE.yellow
			catLab.Font = Enum.Font.GothamBlack
			catLab.TextSize = 14
			catLab.TextXAlignment = Enum.TextXAlignment.Left
			catLab.ZIndex = 1006
			sortIndex += 1
			catLab.LayoutOrder = sortIndex
			createCorner(catLab, 6)
			addStroke(catLab, roleColors[role] or PALETTE.cyan, 1.5, 0.4)

			for _, item in ipairs(sortedCmds) do
				local cmd = item.Cmd
				local data = item.Data
				local myLevel = rolesHierarchy[myRole] or 6
				local reqLevel = rolesHierarchy[data.Role] or 99
				local hasPermission = (myLevel <= reqLevel)

				local cf = Instance.new("Frame")
				cf.Parent = cmdScroll
				cf.Size = UDim2.new(1, -15, 0, 68)
				cf.BackgroundColor3 = hasPermission and PALETTE.bgCard or Color3.fromRGB(18, 10, 28)
				cf.BackgroundTransparency = hasPermission and 0.1 or 0.5
				cf.BorderSizePixel = 0
				cf.ZIndex = 1006
				sortIndex += 1
				cf.LayoutOrder = sortIndex
				createCorner(cf, 8)
				addStroke(cf, hasPermission and PALETTE.cyan or PALETTE.dim, 1, hasPermission and 0.4 or 0.7)

				local t1 = Instance.new("TextLabel")
				t1.Parent = cf
				t1.Size = UDim2.new(0.30, 0, 0.5, 0)
				t1.Position = UDim2.new(0.03, 0, 0.1, 0)
				t1.Font = Enum.Font.Code
				t1.TextSize = 19
				t1.TextXAlignment = Enum.TextXAlignment.Left
				t1.BackgroundTransparency = 1
				t1.ZIndex = 1007
				if not hasPermission then
					t1.Text = "[L] " .. currentPrefix .. cmd
					t1.TextColor3 = PALETTE.dim
				elseif cmd == "titleb" then
					t1.Text = currentPrefix .. cmd
					t1.TextColor3 = PALETTE.cyan
				elseif cmd == "titler" then
					t1.Text = currentPrefix .. cmd
					t1.TextColor3 = PALETTE.red
				elseif cmd == "titleg" then
					t1.Text = currentPrefix .. cmd
					t1.TextColor3 = PALETTE.green
				elseif cmd == "titley" then
					t1.Text = currentPrefix .. cmd
					t1.TextColor3 = PALETTE.yellow
				else
					t1.Text = currentPrefix .. cmd
					t1.TextColor3 = PALETTE.cyan
				end

				local t2 = Instance.new("TextLabel")
				t2.Parent = cf
				t2.Size = UDim2.new(0.55, 0, 0.4, 0)
				t2.Position = UDim2.new(0.03, 0, 0.55, 0)
				t2.Text = data.Bio or ""
				t2.TextColor3 = hasPermission and PALETTE.white or PALETTE.dim
				t2.Font = Enum.Font.Gotham
				t2.TextSize = 12
				t2.TextXAlignment = Enum.TextXAlignment.Left
				t2.BackgroundTransparency = 1
				t2.ZIndex = 1007

				
				if not IS_MOBILE then
					cf.MouseEnter:Connect(function()
						showTooltip((data.Bio or cmd) .. "\n\nGrade requis: " .. data.Role, cf)
					end)
					cf.MouseLeave:Connect(function()
						hideTooltip()
					end)
					cf.MouseMoved:Connect(function(x, y)
						if tooltipFrame and tooltipFrame.Visible then
							tooltipFrame.Position = UDim2.new(0, x + 15, 0, y + 15)
						end
					end)
				end

				
				if hasPermission then
					local TOGGLE_INVERSE = {
						fly="unfly", noclip="unnoclip", jail="unjail", freeze="thaw",
						freezeall="thawall", mute="unmute", spin="unspin", trip="untrip",
						gravity="ungravity", god="ungod", platform="unplatform",
						visible="invisible", invisible="visible", nv="unnv",
					}
					local execBtn = createBtn(">", UDim2.new(0.62, 0, 0.15, 0), UDim2.new(0.10, 0, 0.7, 0), PALETTE.green, cf, 1007)
					execBtn.TextSize = 18
					local _isActive = false  
					execBtn.MouseButton1Click:Connect(function()
						if _isActive and TOGGLE_INVERSE[cmd] then
							execCommandFromUI(TOGGLE_INVERSE[cmd])
							_isActive = false
							execBtn.Text = ">"
							execBtn.BackgroundColor3 = PALETTE.green
						else
							execCommandFromUI(cmd)
							if TOGGLE_INVERSE[cmd] then
								_isActive = true
								execBtn.Text = "X"
								execBtn.BackgroundColor3 = PALETTE.red
							end
						end
					end)
				end

				
				if rolesHierarchy[myRole] == 1 then
					local eb = createBtn(tr("CONFIGURER"), UDim2.new(0.75, 0, 0.2, 0), UDim2.new(0.23, 0, 0.6, 0), PALETTE.violet, cf, 1007)
					eb.TextSize = 11
					eb.MouseButton1Click:Connect(function()
						local activeCmd = cmd
						local tempRole = data.Role
						local tempOthers = data.Others
						etit.Text = tr("MODIFICATION : ") .. string.upper(cmd)
						ecat.Text = tr("GRADE ACTUEL : ") .. string.upper(tempRole)
						editFrame.Visible = true

						local editList = editFrame:FindFirstChild("RoleList")
						if not editList then
							editList = Instance.new("ScrollingFrame")
							editList.Parent = editFrame
							editList.Name = "RoleList"
							editList.Size = UDim2.new(0.9, 0, 0.35, 0)
							editList.Position = UDim2.new(0.05, 0, 0.25, 0)
							editList.BackgroundTransparency = 1
							editList.BorderSizePixel = 0
							editList.ScrollBarThickness = 4
							editList.ScrollBarImageColor3 = PALETTE.cyan
							editList.ZIndex = 2005
						end

						for _, x in pairs(editList:GetChildren()) do
							if x:IsA("TextButton") or x:IsA("UIGridLayout") then x:Destroy() end
						end
						local gl = Instance.new("UIGridLayout")
						gl.Parent = editList
						gl.CellSize = UDim2.new(0.48, 0, 0, 40)
						gl.CellPadding = UDim2.new(0.02, 0, 0, 10)

						for _, r in ipairs(rolesOrder) do
							local rb = createBtn(r, UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0), PALETTE.bgCard, editList, 2010)
							rb.BackgroundTransparency = (r == tempRole) and 0.1 or 0.6
							if r == tempRole then
								local oldStr = rb:FindFirstChildOfClass("UIStroke")
								if oldStr then oldStr:Destroy() end
								addStroke(rb, PALETTE.green, 2.5, 0)
							end
							rb.MouseButton1Click:Connect(function()
								tempRole = r
								ecat.Text = tr("NOUVEAU GRADE : ") .. string.upper(tempRole)
								for _, b in pairs(editList:GetChildren()) do
									if b:IsA("TextButton") then
										b.BackgroundTransparency = (b.Text == tempRole) and 0.1 or 0.6
										local os2 = b:FindFirstChildOfClass("UIStroke")
										if os2 then os2:Destroy() end
										addStroke(
											b,
											(b.Text == tempRole) and PALETTE.green or PALETTE.cyan,
											(b.Text == tempRole) and 2.5 or 1,
											(b.Text == tempRole) and 0 or 0.5
										)
									end
								end
							end)
						end

						local othersBtn = editFrame:FindFirstChild("OthersBtn")
						if othersBtn then othersBtn:Destroy() end
						othersBtn = createBtn(
							tempOthers and tr("CIBLER LES AUTRES : OUI") or tr("CIBLER LES AUTRES : NON"),
							UDim2.new(0.05, 0, 0.65, 0),
							UDim2.new(0.9, 0, 0, 35),
							tempOthers and PALETTE.green or PALETTE.red,
							editFrame,
							2010
						)
						othersBtn.Name = "OthersBtn"
						othersBtn.MouseButton1Click:Connect(function()
							tempOthers = not tempOthers
							othersBtn.Text = tempOthers and tr("CIBLER LES AUTRES : OUI") or tr("CIBLER LES AUTRES : NON")
							othersBtn.BackgroundColor3 = tempOthers and PALETTE.green or PALETTE.red
						end)

						local saveBtn = editFrame:FindFirstChild("SaveBtn")
						if saveBtn then saveBtn:Destroy() end
						saveBtn = createBtn(
							tr("SAUVEGARDER LA MODIFICATION"),
							UDim2.new(0.05, 0, 0.82, 0),
							UDim2.new(0.9, 0, 0, 42),
							PALETTE.green,
							editFrame,
							2010
						)
						saveBtn.Name = "SaveBtn"
						saveBtn.MouseButton1Click:Connect(function()
							if updateCmdEvent then
								pcall(function() updateCmdEvent:FireServer(activeCmd, tempRole, tempOthers) end)
							end
							editFrame.Visible = false
							playSfx(2865227271, 0.6)
						end)
					end)
				end
			end
		end
	end
	task.delay(0.1, function()
		if cmdScroll and cmdLay then
			cmdScroll.CanvasSize = UDim2.new(0, 0, 0, cmdLay.AbsoluteContentSize.Y + 20)
		end
	end)
	
	for _, child in ipairs(cmdScroll:GetChildren()) do
		if child:IsA("Frame") then
			local t1 = child:FindFirstChildOfClass("TextLabel")
			if t1 then
				local txt = t1.Text or ""
				txt = txt:gsub("^[L] ", "")
				if currentPrefix and #currentPrefix > 0 and txt:sub(1, #currentPrefix) == currentPrefix then
					txt = txt:sub(#currentPrefix + 1)
				end
				txt = txt:gsub("%s.*$", "")
				child:SetAttribute("CmdName", txt)
				child:SetAttribute("IsEmote", _G._AgoraIsEmoteCmd and _G._AgoraIsEmoteCmd(txt) or false)
			end
		end
	end
	
	
	local emotesFrame = nil
	for _, child in ipairs(cmdScroll:GetChildren()) do
		if child:IsA("Frame") and child:GetAttribute("CmdName") == "emotes" then
			emotesFrame = child
			break
		end
	end
	if emotesFrame then
		local oldExp = emotesFrame:FindFirstChild("EmoteExpandBtn")
		if oldExp then oldExp:Destroy() end
		local expBtn = Instance.new("TextButton")
		expBtn.Name = "EmoteExpandBtn"
		expBtn.Parent = emotesFrame
		expBtn.Size = UDim2.new(0, 130, 0, 32)
		expBtn.Position = UDim2.new(1, -140, 0.5, -16)
		expBtn.Text = _G._AgoraEmoteExpanded and "DN MASQUER" or "> DÉPLIER"
		expBtn.BackgroundColor3 = _G._AgoraEmoteExpanded and PALETTE.green or PALETTE.violet
		expBtn.TextColor3 = PALETTE.white
		expBtn.Font = Enum.Font.GothamBold
		expBtn.TextSize = 12
		expBtn.AutoButtonColor = true
		expBtn.ZIndex = 1010
		createCorner(expBtn, 6)
		expBtn.MouseButton1Click:Connect(function()
			_G._AgoraEmoteExpanded = not _G._AgoraEmoteExpanded
			if refreshCmdUI then refreshCmdUI() end
		end)
		
		if _G._AgoraEmoteExpanded then
			local NAME_EMOJI = {
				wave="[WAVE]", dance="[DANCE]", dance2="[DANC2]", dance3="[DANC3]", laugh="[LAUGH]",
				cheer="[CHEER]", point="[POINT]", salute="[SALUTE]", shrug="[SHRUG]", hype="[HYPE]",
				floss="[FLOSS]", shuffle="[SHUFFLE]", toprock="[MUSIC]", shy="[SHY]", celebrate="[CELEB]",
				superhero="[HERO]",
			}
			local grid = Instance.new("Frame")
			grid.Name = "EmoteSubGrid"
			grid.Parent = cmdScroll
			grid:SetAttribute("IsEmoteSubGrid", true)
			grid.Size = UDim2.new(1, -15, 0, 200)
			grid.LayoutOrder = (emotesFrame.LayoutOrder or 0) + 1
			grid.BackgroundColor3 = PALETTE.bgPanel
			grid.BackgroundTransparency = 0.2
			grid.BorderSizePixel = 0
			grid.ZIndex = 1006
			createCorner(grid, 8)
			addStroke(grid, PALETTE.violet, 1.5, 0.4)
			local gridLay = Instance.new("UIGridLayout", grid)
			gridLay.CellSize = UDim2.new(0, 120, 0, 38)
			gridLay.CellPadding = UDim2.new(0, 6, 0, 6)
			gridLay.SortOrder = Enum.SortOrder.LayoutOrder
			gridLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
			local pad = Instance.new("UIPadding", grid)
			pad.PaddingTop = UDim.new(0, 8)
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingRight = UDim.new(0, 8)
			pad.PaddingBottom = UDim.new(0, 8)
			local sortedEmotes = {}
			for n in pairs(_G._AgoraEmoteNames or {}) do
				table.insert(sortedEmotes, n)
			end
			table.sort(sortedEmotes)
			for i, en in ipairs(sortedEmotes) do
				local btn = Instance.new("TextButton", grid)
				btn.LayoutOrder = i
				btn.BackgroundColor3 = PALETTE.bgCard
				btn.BorderSizePixel = 0
				btn.Text = (NAME_EMOJI[en] or "[EMO]") .. " " .. en
				btn.TextColor3 = PALETTE.white
				btn.Font = Enum.Font.GothamMedium
				btn.TextSize = 12
				btn.AutoButtonColor = true
				btn.ZIndex = 1008
				createCorner(btn, 6)
				addStroke(btn, PALETTE.violet, 1, 0.6)
				btn.MouseButton1Click:Connect(function()
					if execCommandFromUI then execCommandFromUI(en) end
					btn.BackgroundColor3 = PALETTE.violet
					task.delay(0.2, function()
						if btn.Parent then btn.BackgroundColor3 = PALETTE.bgCard end
					end)
				end)
			end
			
			task.delay(0.05, function()
				if grid.Parent and gridLay then
					grid.Size = UDim2.new(1, -15, 0, gridLay.AbsoluteContentSize.Y + 16)
				end
			end)
		end
	end
	if _G._AgoraApplyCmdsFilter then _G._AgoraApplyCmdsFilter() end
end
end 

do
banScroll = Instance.new("ScrollingFrame")
banScroll.Parent = pnlBans
banScroll.Size = UDim2.new(1, 0, 1, 0)
banScroll.BackgroundTransparency = 1
banScroll.BorderSizePixel = 0
banScroll.ScrollBarThickness = 6
banScroll.ScrollBarImageColor3 = PALETTE.red
banScroll.ZIndex = 1005
banLay = Instance.new("UIListLayout")
banLay.Parent = banScroll
banLay.Padding = UDim.new(0, 10)
banLay.SortOrder = Enum.SortOrder.LayoutOrder
banLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	banScroll.CanvasSize = UDim2.new(0, 0, 0, banLay.AbsoluteContentSize.Y + 20)
end)

updateBanLand = function()
	for _, v in pairs(banScroll:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end
	if not getBansFunc then return end
	local s, bans = pcall(function() return getBansFunc:InvokeServer() end)
	if not s or not bans then return end
	for i, d in pairs(bans) do
		local f = Instance.new("Frame")
		f.Parent = banScroll
		f.Size = UDim2.new(1, -15, 0, 80)
		f.BackgroundColor3 = PALETTE.bgCard
		f.BackgroundTransparency = 0.1
		f.BorderSizePixel = 0
		f.LayoutOrder = i
		f.ZIndex = 1006
		createCorner(f, 8)
		addStroke(f, PALETTE.red, 1.5, 0.4)

		local t = Instance.new("TextLabel")
		t.Parent = f
		t.Size = UDim2.new(0.7, 0, 1, 0)
		t.Position = UDim2.new(0.03, 0, 0, 0)
		t.BackgroundTransparency = 1
		t.TextColor3 = PALETTE.white
		t.Font = Enum.Font.GothamSemibold
		t.TextSize = 13
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Center
		t.ZIndex = 1007
		local expStr = tr("PERMANENT")
		if d.Type == "Temp" and d.Expire then
			local tl = d.Expire - os.time()
			expStr = (tl > 0) and (math.ceil(tl / 60) .. " min") or tr("EXPIRÉ")
		end
		t.Text = tr("JOUEUR : ") .. d.Name .. "\n" .. tr("RAISON : ") .. (d.Reason or "N/A") .. "\n" .. tr("DURÉE : ") .. expStr

		local ub = createBtn(tr("DÉBANNIR"), UDim2.new(0.75, 0, 0.25, 0), UDim2.new(0.22, 0, 0.5, 0), PALETTE.red, f, 1007)
		ub.MouseButton1Click:Connect(function()
			if unbanEvent then
				pcall(function() unbanEvent:FireServer(d.UserId) end)
			end
			task.wait(0.5)
			updateBanLand()
		end)
	end
	task.delay(0.1, function()
		if banScroll and banLay then
			banScroll.CanvasSize = UDim2.new(0, 0, 0, banLay.AbsoluteContentSize.Y + 20)
		end
	end)
end
end 

do
local cachedRanks = {}
rankSearch = Instance.new("TextBox")
rankSearch.Parent = pnlRanks
rankSearch.Size = UDim2.new(1, 0, 0, 36)
rankSearch.Text = ""
rankSearch.PlaceholderText = tr("Rechercher un joueur...")
rankSearch.PlaceholderColor3 = PALETTE.dim
rankSearch.BackgroundColor3 = PALETTE.bgCard
rankSearch.TextColor3 = PALETTE.cyan
rankSearch.Font = Enum.Font.GothamMedium
rankSearch.TextSize = 14
rankSearch.ClipsDescendants = true
rankSearch.ZIndex = 1006
createCorner(rankSearch, 8)
addStroke(rankSearch, PALETTE.violet, 1.5, 0.3)

local rankScroll = Instance.new("ScrollingFrame")
rankScroll.Parent = pnlRanks
rankScroll.Size = UDim2.new(1, 0, 1, -46)
rankScroll.Position = UDim2.new(0, 0, 0, 46)
rankScroll.BackgroundTransparency = 1
rankScroll.BorderSizePixel = 0
rankScroll.ScrollBarThickness = 6
rankScroll.ScrollBarImageColor3 = PALETTE.violet
rankScroll.ZIndex = 1005
local rankLay = Instance.new("UIListLayout")
rankLay.Parent = rankScroll
rankLay.Padding = UDim.new(0, 8)
rankLay.SortOrder = Enum.SortOrder.LayoutOrder
rankLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	rankScroll.CanvasSize = UDim2.new(0, 0, 0, rankLay.AbsoluteContentSize.Y + 10)
end)

confirmFrame = Instance.new("Frame")
confirmFrame.Parent = main
confirmFrame.Name = "ConfirmPanel"
confirmFrame.Size = UDim2.new(0, 320, 0, 170)
confirmFrame.Position = UDim2.new(0.5, -160, 0.5, -85)
confirmFrame.BackgroundColor3 = PALETTE.bgDeep
confirmFrame.BackgroundTransparency = 0.05
confirmFrame.BorderSizePixel = 0
confirmFrame.Visible = false
confirmFrame.ZIndex = 3000
createCorner(confirmFrame, 12)
addNeonGlow(confirmFrame, PALETTE.red)

local confTitle = Instance.new("TextLabel", confirmFrame)
confTitle.Size = UDim2.new(1, 0, 0, 40)
confTitle.BackgroundTransparency = 1
confTitle.Text = tr("RÉVOQUER LE GRADE ?")
confTitle.TextColor3 = PALETTE.red
confTitle.Font = Enum.Font.GothamBlack
confTitle.TextSize = 16
confTitle.ZIndex = 3005

confMsg = Instance.new("TextLabel", confirmFrame)
confMsg.Size = UDim2.new(1, -20, 0, 50)
confMsg.Position = UDim2.new(0, 10, 0, 42)
confMsg.BackgroundTransparency = 1
confMsg.TextColor3 = PALETTE.white
confMsg.Font = Enum.Font.GothamMedium
confMsg.TextSize = 13
confMsg.TextWrapped = true
confMsg.ZIndex = 3005

local btnConfYes = createBtn(tr("OUI"), UDim2.new(0.1, 0, 0.68, 0), UDim2.new(0.35, 0, 0, 38), PALETTE.red, confirmFrame, 3005)
local btnConfNo  = createBtn(tr("ANNULER"), UDim2.new(0.55, 0, 0.68, 0), UDim2.new(0.35, 0, 0, 38), PALETTE.bgCard, confirmFrame, 3005)
btnConfNo.MouseButton1Click:Connect(function() confirmFrame.Visible = false end)

local pendingRevokeId = nil
btnConfYes.MouseButton1Click:Connect(function()
	if pendingRevokeId and revokeEvent then
		pcall(function() revokeEvent:FireServer(pendingRevokeId) end)
		playSfx(2865227271, 0.6)
		confirmFrame.Visible = false
		task.wait(0.5)
		if pnlRanks.Visible and _G.fetchRanks then _G.fetchRanks() end
	end
end)

_G.renderRanks = function()
	for _, v in pairs(rankScroll:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end
	local filter = string.lower(rankSearch.Text)
	local order = 0
	for _, data in ipairs(cachedRanks) do
		
		
		local _isDefault = (data.Role == "Joueurs" or data.Role == "Joueur" or data.Role == "Player")
		if not _isDefault and (filter == "" or string.find(string.lower(data.Name), filter, 1, true)) then
			local f = Instance.new("Frame")
			f.Parent = rankScroll
			f.Size = UDim2.new(1, -10, 0, 46)
			f.BackgroundColor3 = PALETTE.bgCard
			f.BackgroundTransparency = 0.12
			f.BorderSizePixel = 0
			f.ZIndex = 1006
			f.LayoutOrder = order
			order += 1
			createCorner(f, 8)
			addStroke(f, roleColors[data.Role] or PALETTE.cyan, 1.5, 0.4)

			local onlineDot = Instance.new("Frame")
			onlineDot.Parent = f
			onlineDot.Size = UDim2.new(0, 10, 0, 10)
			onlineDot.Position = UDim2.new(0, 6, 0.5, -5)
			onlineDot.BackgroundColor3 = data.Online and PALETTE.green or PALETTE.dim
			onlineDot.BorderSizePixel = 0
			onlineDot.ZIndex = 1007
			createCorner(onlineDot, 5)
			if data.Online then
				addStroke(onlineDot, PALETTE.green, 1.5, 0.2)
			end

			local tName = Instance.new("TextLabel")
			tName.Parent = f
			tName.Size = UDim2.new(0.28, 0, 1, 0)
			tName.Position = UDim2.new(0.04, 0, 0, 0)
			tName.BackgroundTransparency = 1
			tName.Text = data.Name
			tName.TextColor3 = PALETTE.white
			tName.Font = Enum.Font.GothamBold
			tName.TextSize = 13
			tName.TextXAlignment = Enum.TextXAlignment.Left
			tName.ZIndex = 1007

			local roleDisp = data.Role
			if data.IsTempRank then roleDisp = roleDisp .. " [T]" end
			local tRole = Instance.new("TextLabel")
			tRole.Parent = f
			tRole.Size = UDim2.new(0.28, 0, 1, 0)
			tRole.Position = UDim2.new(0.32, 0, 0, 0)
			tRole.BackgroundTransparency = 1
			tRole.Text = roleDisp
			tRole.TextColor3 = roleColors[data.Role] or PALETTE.dim
			tRole.Font = Enum.Font.GothamBlack
			tRole.TextSize = 12
			tRole.TextXAlignment = Enum.TextXAlignment.Left
			tRole.ZIndex = 1007

			if data.Age then
				local tAge = Instance.new("TextLabel")
				tAge.Parent = f
				tAge.Size = UDim2.new(0.14, 0, 1, 0)
				tAge.Position = UDim2.new(0.60, 0, 0, 0)
				tAge.BackgroundTransparency = 1
				tAge.Text = data.Age
				tAge.TextColor3 = PALETTE.yellow
				tAge.Font = Enum.Font.Code
				tAge.TextSize = 12
				tAge.TextXAlignment = Enum.TextXAlignment.Center
				tAge.ZIndex = 1007
			end

			if rolesHierarchy[myRole] == 1 and data.CanRevoke then
				local btnRevoke = createBtn(tr("REVOKE"), UDim2.new(0.78, 0, 0.15, 0), UDim2.new(0.20, 0, 0.7, 0), PALETTE.red, f, 1007)
				btnRevoke.MouseButton1Click:Connect(function()
					pendingRevokeId = data.UserId
					confMsg.Text = "Révoquer le grade de " .. data.Name .. " pour le remettre Joueur ?"
					confirmFrame.Visible = true
				end)
			end
		end
	end
	task.delay(0.1, function()
		if rankScroll and rankLay then
			rankScroll.CanvasSize = UDim2.new(0, 0, 0, rankLay.AbsoluteContentSize.Y + 20)
		end
	end)
end

_G.fetchRanks = function()
	if getRanksFunc then
		task.spawn(function()
			local s, d = pcall(function() return getRanksFunc:InvokeServer() end)
			if s and d then
				cachedRanks = d
				if _G.renderRanks then _G.renderRanks() end
			end
		end)
	end
end

rankSearch:GetPropertyChangedSignal("Text"):Connect(function()
	if _G.renderRanks then _G.renderRanks() end
end)

btnTabRanks.MouseButton1Click:Connect(function()
	if _G.fetchRanks then _G.fetchRanks() end
end)

btnTabMod.MouseButton1Click:Connect(function()
	
	updateBanLand()
	renderACLogs()
	
	if modSubIndex == 1 then
		pnlBans.Visible = true
		pnlBans.Position = UDim2.new(0, 0, 0, 46)
		pnlAC.Visible = false
	else
		pnlAC.Visible = true
		pnlAC.Position = UDim2.new(0, 0, 0, 46)
		pnlBans.Visible = false
	end
end)
end 

do
local function createPanel(titleText, posY, sz)
	local existing = gui:FindFirstChild(titleText .. "Panel")
	if existing then return existing end
	local pnl = Instance.new("Frame")
	pnl.Parent = gui
	pnl.Name = titleText .. "Panel"
	pnl.Size = sz or UDim2.new(0, 260, 0, 180)
	pnl.Position = UDim2.new(1, -280, 1, posY)
	pnl.BackgroundColor3 = PALETTE.bgDeep
	pnl.BackgroundTransparency = 0.1
	pnl.BorderSizePixel = 0
	pnl.Visible = false
	pnl.ZIndex = 3000
	createCorner(pnl, 12)
	addGradient(pnl, PALETTE.bgDeep, PALETTE.bgPanel, 135)
	addNeonGlow(pnl, PALETTE.cyan)
	makeDraggable(pnl)

	local ftit = Instance.new("TextLabel")
	ftit.Parent = pnl
	ftit.Size = UDim2.new(1, -40, 0, 36)
	ftit.Position = UDim2.new(0, 12, 0, 2)
	ftit.Text = tr(titleText)
	ftit.TextColor3 = PALETTE.cyan
	ftit.Font = Enum.Font.GothamBlack
	ftit.TextSize = 15
	ftit.BackgroundTransparency = 1
	ftit.TextXAlignment = Enum.TextXAlignment.Left
	ftit.TextStrokeTransparency = 0.7
	ftit.TextStrokeColor3 = PALETTE.magenta
	ftit.ZIndex = 3005

	local fX = createBtn("X", UDim2.new(1, -34, 0, 6), UDim2.new(0, 28, 0, 28), PALETTE.red, pnl, 3005)
	createCorner(fX, 14)
	fX.MouseButton1Click:Connect(function()
		pnl.Visible = false
		playSfx(6895079853, 0.5)
	end)
	return pnl
end

flyPnl     = createPanel("CONTRÔLE VOL",    -200, UDim2.new(0, 260, 0, 180))
noclipPnl  = createPanel("CONTRÔLE NOCLIP", -400, UDim2.new(0, 260, 0, 180))
cmdBarPnl  = createPanel("COMMAND BAR",     -200, UDim2.new(0, 320, 0, 110))
bubblePnl  = createPanel("BUBBLECHAT",      -340, UDim2.new(0, 320, 0, 180))
logsPnl    = createPanel("LOGS DES COMMANDES", -540, UDim2.new(0, 470, 0, 320))
logsPnl.Position = UDim2.new(0.5, -235, 0.5, -160)

pcall(function()
	registerThemedRoot(flyPnl)
	registerThemedRoot(noclipPnl)
	registerThemedRoot(cmdBarPnl)
	registerThemedRoot(bubblePnl)
	registerThemedRoot(logsPnl)
end)

btnFly = createBtn("FLY : OFF [E]", UDim2.new(0.05, 0, 0.3, 0), UDim2.new(0.9, 0, 0, 42), PALETTE.red, flyPnl, 3005)

local fSpdLab = Instance.new("TextLabel")
fSpdLab.Parent = flyPnl
fSpdLab.Size = UDim2.new(0.35, 0, 0, 28)
fSpdLab.Position = UDim2.new(0.05, 0, 0.65, 0)
fSpdLab.BackgroundTransparency = 1
fSpdLab.Text = tr("Vitesse :")
fSpdLab.TextColor3 = PALETTE.yellow
fSpdLab.Font = Enum.Font.GothamBold
fSpdLab.TextSize = 13
fSpdLab.TextXAlignment = Enum.TextXAlignment.Left
fSpdLab.ZIndex = 3005

local fSpdMinus = createBtn("-", UDim2.new(0.42, 0, 0.65, 0), UDim2.new(0, 26, 0, 28), PALETTE.bgCard, flyPnl, 3005)
fSpdMinus.TextSize = 16
fSpdMinus.Font = Enum.Font.GothamBlack
addStroke(fSpdMinus, PALETTE.cyan, 1, 0.4)

fSpdIn = Instance.new("TextBox")
fSpdIn.Parent = flyPnl
fSpdIn.Size = UDim2.new(0.22, 0, 0, 28)
fSpdIn.Position = UDim2.new(0.56, 0, 0.65, 0)
fSpdIn.Text = "50"
fSpdIn.TextColor3 = PALETTE.cyan
fSpdIn.Font = Enum.Font.Code
fSpdIn.TextSize = 14
fSpdIn.BackgroundColor3 = PALETTE.bgCard
fSpdIn.BackgroundTransparency = 0.1
fSpdIn.ClipsDescendants = true
fSpdIn.BorderSizePixel = 0
fSpdIn.ZIndex = 3005
createCorner(fSpdIn, 6)
addStroke(fSpdIn, PALETTE.cyan, 1, 0.4)

local fSpdPlus = createBtn("+", UDim2.new(0.80, 0, 0.65, 0), UDim2.new(0, 26, 0, 28), PALETTE.bgCard, flyPnl, 3005)
fSpdPlus.TextSize = 16
fSpdPlus.Font = Enum.Font.GothamBlack
addStroke(fSpdPlus, PALETTE.cyan, 1, 0.4)

local fQBtn = createBtn("Q", UDim2.new(0.05, 0, 0.85, 0), UDim2.new(0.4, 0, 0, 24), PALETTE.red, flyPnl, 3005)
fQBtn.TextSize = 12
fQBtn.Font = Enum.Font.GothamBold
addStroke(fQBtn, PALETTE.red, 1, 0.4)
fQBtn.MouseButton1Click:Connect(function()
	if isFlying then
		isFlying = false
		btnFly.Text = "FLY : OFF [E]"
		btnFly.BackgroundColor3 = PALETTE.red
		if IS_MOBILE and btnFlyMobile then
			btnFlyMobile.Text = "FLY\nFLY"
			btnFlyMobile.TextColor3 = PALETTE.cyan
		end
		updatePhys()
	end
	flyPnl.Visible = false
end)

fSpdMinus.MouseButton1Click:Connect(function()
	fSpd = math.clamp((tonumber(fSpdIn.Text) or fSpd) - 5, 1, 100)
	fSpdIn.Text = tostring(fSpd)
	nSpdIn.Text = tostring(fSpd)
end)
fSpdPlus.MouseButton1Click:Connect(function()
	fSpd = math.clamp((tonumber(fSpdIn.Text) or fSpd) + 5, 1, 100)
	fSpdIn.Text = tostring(fSpd)
	nSpdIn.Text = tostring(fSpd)
end)

btnNc = createBtn("NOCLIP : OFF [E]", UDim2.new(0.05, 0, 0.3, 0), UDim2.new(0.9, 0, 0, 42), PALETTE.red, noclipPnl, 3005)
local nSpdLab = fSpdLab:Clone() nSpdLab.Parent = noclipPnl
nSpdIn = fSpdIn:Clone() nSpdIn.Parent = noclipPnl

cIn = Instance.new("TextBox")
cIn.Parent = cmdBarPnl
cIn.Size = UDim2.new(0.65, 0, 0, 38)
cIn.Position = UDim2.new(0.05, 0, 0.45, 0)
cIn.Text = ""
cIn.PlaceholderText = "Entrez une commande..."
cIn.PlaceholderColor3 = PALETTE.dim
cIn.BackgroundColor3 = PALETTE.bgCard
cIn.TextColor3 = PALETTE.cyan
cIn.Font = Enum.Font.Code
cIn.TextSize = 14
cIn.ClipsDescendants = true
cIn.TextWrapped = true
cIn.ZIndex = 3005
createCorner(cIn, 6)
addStroke(cIn, PALETTE.cyan, 1, 0.4)

local cExec = createBtn("EXEC", UDim2.new(0.73, 0, 0.45, 0), UDim2.new(0.22, 0, 0, 38), PALETTE.green, cmdBarPnl, 3005)
cExec.MouseButton1Click:Connect(function()
	if cmdBarEvent and cIn.Text ~= "" then
		pcall(function() cmdBarEvent:FireServer(cIn.Text) end)
		playSfx(2865227271, 0.5)
	end
end)

local bTarg = Instance.new("TextBox")
bTarg.Parent = bubblePnl
bTarg.Size = UDim2.new(0.9, 0, 0, 32)
bTarg.Position = UDim2.new(0.05, 0, 0.22, 0)
bTarg.Text = ""
bTarg.PlaceholderText = "Joueur (Vide = Anonyme)"
bTarg.PlaceholderColor3 = PALETTE.dim
bTarg.BackgroundColor3 = PALETTE.bgCard
bTarg.TextColor3 = PALETTE.cyan
bTarg.Font = Enum.Font.GothamMedium
bTarg.TextSize = 13
bTarg.ClipsDescendants = true
bTarg.ZIndex = 3005
createCorner(bTarg, 6)
addStroke(bTarg, PALETTE.violet, 1, 0.4)

local bMsg = Instance.new("TextBox")
bMsg.Parent = bubblePnl
bMsg.Size = UDim2.new(0.9, 0, 0, 32)
bMsg.Position = UDim2.new(0.05, 0, 0.47, 0)
bMsg.Text = ""
bMsg.PlaceholderText = "Message ou commande..."
bMsg.PlaceholderColor3 = PALETTE.dim
bMsg.BackgroundColor3 = PALETTE.bgCard
bMsg.TextColor3 = PALETTE.cyan
bMsg.Font = Enum.Font.GothamMedium
bMsg.TextSize = 13
bMsg.ClipsDescendants = true
bMsg.ZIndex = 3005
createCorner(bMsg, 6)
addStroke(bMsg, PALETTE.violet, 1, 0.4)

local bExec = createBtn("EXECUTER", UDim2.new(0.05, 0, 0.73, 0), UDim2.new(0.9, 0, 0, 35), PALETTE.violet, bubblePnl, 3005)
local bcLastSent = 0
bExec.MouseButton1Click:Connect(function()
	if not bubbleChatEvent or #bMsg.Text == 0 then return end
	local now = tick()
	if now - bcLastSent < 0.3 then return end
	bcLastSent = now
	pcall(function() bubbleChatEvent:FireServer(bTarg.Text, bMsg.Text) end)
	playSfx(2865227271, 0.5)
end)

logsScroll = Instance.new("ScrollingFrame")
logsScroll.Parent = logsPnl
logsScroll.Size = UDim2.new(1, -20, 1, -50)
logsScroll.Position = UDim2.new(0, 10, 0, 42)
logsScroll.BackgroundTransparency = 1
logsScroll.BorderSizePixel = 0
logsScroll.ScrollBarThickness = 6
logsScroll.ScrollBarImageColor3 = PALETTE.cyan
logsScroll.ZIndex = 3005
logsLay = Instance.new("UIListLayout")
logsLay.Parent = logsScroll
logsLay.Padding = UDim.new(0, 5)
logsLay.SortOrder = Enum.SortOrder.LayoutOrder
logsLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	logsScroll.CanvasSize = UDim2.new(0, 0, 0, logsLay.AbsoluteContentSize.Y + 10)
end)
end 

do
local btnUp = nil
local btnDown = nil

local function buildMobileTouchControls()
	if mobileTouchContainer then return end

	mobileTouchContainer = Instance.new("Frame")
	mobileTouchContainer.Parent = gui
	mobileTouchContainer.Name = "AgoraMobileTouch"
	mobileTouchContainer.Size = UDim2.new(0, 90, 0, 240)
	mobileTouchContainer.AnchorPoint = Vector2.new(1, 1)
	mobileTouchContainer.Position = UDim2.new(1, -20, 1, -100)
	mobileTouchContainer.BackgroundTransparency = 1
	mobileTouchContainer.BorderSizePixel = 0
	mobileTouchContainer.Visible = false
	mobileTouchContainer.ZIndex = 9990

	
	btnFlyMobile = Instance.new("TextButton")
	btnFlyMobile.Parent = mobileTouchContainer
	btnFlyMobile.Size = UDim2.new(0, 80, 0, 58)
	btnFlyMobile.Position = UDim2.new(0, 5, 0, 5)
	btnFlyMobile.BackgroundColor3 = PALETTE.bgDeep
	btnFlyMobile.Text = "FLY\nFLY"
	btnFlyMobile.TextColor3 = PALETTE.cyan
	btnFlyMobile.Font = Enum.Font.GothamBlack
	btnFlyMobile.TextSize = 13
	btnFlyMobile.BorderSizePixel = 0
	btnFlyMobile.AutoButtonColor = false
	btnFlyMobile.ZIndex = 9991
	createCorner(btnFlyMobile, 10)
	addStroke(btnFlyMobile, PALETTE.cyan, 2, 0.2)

	
	btnUp = Instance.new("TextButton")
	btnUp.Parent = mobileTouchContainer
	btnUp.Size = UDim2.new(0, 80, 0, 80)
	btnUp.Position = UDim2.new(0, 5, 0, 75)
	btnUp.BackgroundColor3 = PALETTE.bgDeep
	btnUp.Text = "UP\nUP"
	btnUp.TextColor3 = PALETTE.green
	btnUp.Font = Enum.Font.GothamBlack
	btnUp.TextSize = 14
	btnUp.BorderSizePixel = 0
	btnUp.AutoButtonColor = false
	btnUp.ZIndex = 9991
	createCorner(btnUp, 12)
	addStroke(btnUp, PALETTE.green, 2, 0.2)

	
	btnDown = Instance.new("TextButton")
	btnDown.Parent = mobileTouchContainer
	btnDown.Size = UDim2.new(0, 80, 0, 80)
	btnDown.Position = UDim2.new(0, 5, 0, 160)
	btnDown.BackgroundColor3 = PALETTE.bgDeep
	btnDown.Text = "DN\nDOWN"
	btnDown.TextColor3 = PALETTE.yellow
	btnDown.Font = Enum.Font.GothamBlack
	btnDown.TextSize = 14
	btnDown.BorderSizePixel = 0
	btnDown.AutoButtonColor = false
	btnDown.ZIndex = 9991
	createCorner(btnDown, 12)
	addStroke(btnDown, PALETTE.yellow, 2, 0.2)

	
	btnUp.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
			btnUpHeld = true
			btnUp.BackgroundColor3 = PALETTE.green
		end
	end)
	btnUp.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
			btnUpHeld = false
			btnUp.BackgroundColor3 = PALETTE.bgDeep
		end
	end)

	btnDown.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
			btnDownHeld = true
			btnDown.BackgroundColor3 = PALETTE.yellow
		end
	end)
	btnDown.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
			btnDownHeld = false
			btnDown.BackgroundColor3 = PALETTE.bgDeep
		end
	end)

	
	btnFlyMobile.MouseButton1Click:Connect(function()
		isFlying = not isFlying
		btnFly.Text = isFlying and "FLY : ACTIVÉ [E]" or "FLY : OFF [E]"
		btnFly.BackgroundColor3 = isFlying and PALETTE.green or PALETTE.red
		btnFlyMobile.Text = isFlying and "FLY\nON" or "FLY\nFLY"
		btnFlyMobile.TextColor3 = isFlying and PALETTE.green or PALETTE.cyan
		playSfx(6895079853, 0.4)
		updatePhys()
	end)
end

if IS_MOBILE then
	buildMobileTouchControls()
end
end 

do
local bv, bg = nil, nil
local flyLoop, ncLoop = nil, nil

local flySoundData = {
	flightSound        = nil, 
	originalRunVolume  = nil, 
	wasFlyingLast      = false,
}

local function applyFlyAudio(hrp, flyingNow)
	pcall(function()
		if not hrp then return end
		local running = hrp:FindFirstChild("Running")

		if flyingNow then
			
			if running and running:IsA("Sound") then
				if flySoundData.originalRunVolume == nil then
					flySoundData.originalRunVolume = running.Volume
				end
				running.Volume = 0
			end
			
			if not flySoundData.flightSound or not flySoundData.flightSound.Parent then
				local s = Instance.new("Sound")
				s.Name = "AgoraFlySound"
				s.SoundId = "rbxassetid://9112854842" 
				s.Looped = true
				s.Volume = 0.4
				s.PlaybackSpeed = 1
				s.Parent = hrp
				s:Play()
				flySoundData.flightSound = s
			end
		else
			
			if running and running:IsA("Sound") and flySoundData.originalRunVolume ~= nil then
				running.Volume = flySoundData.originalRunVolume
				flySoundData.originalRunVolume = nil
			end
			
			if flySoundData.flightSound then
				pcall(function()
					flySoundData.flightSound:Stop()
					flySoundData.flightSound:Destroy()
				end)
				flySoundData.flightSound = nil
			end
		end
	end)
end

updatePhys = function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	if flyLoop then flyLoop:Disconnect() flyLoop = nil end
	if ncLoop  then ncLoop:Disconnect()  ncLoop = nil  end

	
	

	if isFlying and not flySoundData.wasFlyingLast then
		
		applyFlyAudio(hrp, true)
		flySoundData.liftStart = tick()
	elseif (not isFlying) and flySoundData.wasFlyingLast then
		
		applyFlyAudio(hrp, false)
	end
	flySoundData.wasFlyingLast = isFlying

	if isFlying or isNoclip then
		hum.PlatformStand = true

		
		for _, v in pairs(hrp:GetChildren()) do
			if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
		end
		hrp.AssemblyLinearVelocity  = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero

		if not bv or not bv.Parent then
			bv = Instance.new("BodyVelocity", hrp)
			bv:SetAttribute("AgoraAdmin", true)
		end
		if not bg or not bg.Parent then
			bg = Instance.new("BodyGyro", hrp)
			bg:SetAttribute("AgoraAdmin", true)
		end

		bv.MaxForce  = Vector3.new(1e9, 1e9, 1e9)
		bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		bg.P = 20000
		bg.D = 1000

		flyLoop = RunService.RenderStepped:Connect(function()
			
			if not hrp or not hrp.Parent then return end
			if not hum or not hum.Parent then return end
			if not bv or not bv.Parent then return end
			if not bg or not bg.Parent then return end
			local cam = workspace.CurrentCamera
			if not cam then return end
			local lookVec  = cam.CFrame.LookVector
			local rightVec = cam.CFrame.RightVector

			bg.CFrame = CFrame.new(hrp.Position, hrp.Position + lookVec)

			local dir = Vector3.zero

			if IS_MOBILE then
				

				local mv = hum.MoveDirection
				if mv.Magnitude > 0 then
					dir = dir + mv
				end
				
				local camPitch = cam.CFrame.LookVector.Y
				if math.abs(camPitch) > 0.25 then
					dir = dir + Vector3.new(0, camPitch * 1.5, 0)
				end
			else
				
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + lookVec end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - lookVec end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - rightVec end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + rightVec end
				if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0, 1, 0) end
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

				
				if IS_CONSOLE then
					local gpMove = Vector3.zero
					pcall(function()
						local state = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
						for _, inp in ipairs(state) do
							if inp.KeyCode == Enum.KeyCode.Thumbstick1 then
								gpMove = Vector3.new(inp.Position.X, 0, -inp.Position.Y)
							end
						end
					end)
					if gpMove.Magnitude > 0.1 then
						dir = dir + (lookVec * -gpMove.Z) + (rightVec * gpMove.X)
					end
				end
			end

			
			local liftBonus = 0
			if flySoundData.liftStart then
				local nearGround = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0)) ~= nil
				if nearGround then
					local te = tick() - flySoundData.liftStart
					if te < 1.2 then
						local t = te / 1.2
						liftBonus = (1 - t * t) * 8
					else
						flySoundData.liftStart = nil
					end
				else
					flySoundData.liftStart = nil
				end
			end
			if dir.Magnitude > 0 then
				bv.Velocity = dir.Unit * fSpd + Vector3.new(0, liftBonus, 0)
			else
				bv.Velocity = Vector3.new(0, liftBonus, 0)
			end

			
			if isFlying and flySoundData.flightSound then
				pcall(function()
					local speedFactor = math.clamp(bv.Velocity.Magnitude / 50, 0.6, 1.6)
					flySoundData.flightSound.PlaybackSpeed = speedFactor
				end)
			end
		end)
	else
		hum.PlatformStand = false
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		if hrp then
			hrp.AssemblyLinearVelocity  = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if isNoclip then
		ncLoop = RunService.Stepped:Connect(function()
			if not char or not char.Parent then return end
			for _, v in pairs(char:GetDescendants()) do
				if v:IsA("BasePart") then v.CanCollide = false end
			end
		end)
	else
		if char then
			for _, v in pairs(char:GetDescendants()) do
				if v:IsA("BasePart") then v.CanCollide = true end
			end
		end
	end
end

player.CharacterAdded:Connect(function(char)
	bv = nil bg = nil flyLoop = nil ncLoop = nil
	
	flySoundData.flightSound = nil
	flySoundData.originalRunVolume = nil
	flySoundData.wasFlyingLast = false
	if isFlying or isNoclip then
		task.wait(0.5)
		updatePhys()
	end
end)
end 

btnFly.MouseButton1Click:Connect(function()
	isFlying = not isFlying
	btnFly.Text = isFlying and "FLY : ACTIVÉ [E]" or "FLY : OFF [E]"
	btnFly.BackgroundColor3 = isFlying and PALETTE.green or PALETTE.red
	
	if isFlying and isNoclip then
		isNoclip = false
		btnNc.Text = "NOCLIP : OFF [E]"
		btnNc.BackgroundColor3 = PALETTE.red
		noclipPnl.Visible = false
	end
	updatePhys()
end)

btnNc.MouseButton1Click:Connect(function()
	isNoclip = not isNoclip
	btnNc.Text = isNoclip and "NOCLIP : ACTIVÉ [E]" or "NOCLIP : OFF [E]"
	btnNc.BackgroundColor3 = isNoclip and PALETTE.green or PALETTE.red
	
	if isNoclip and isFlying then
		isFlying = false
		btnFly.Text = "FLY : OFF [E]"
		btnFly.BackgroundColor3 = PALETTE.red
		flyPnl.Visible = false
	end
	updatePhys()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E then
		if flyPnl.Visible then
			isFlying = not isFlying
			btnFly.Text = isFlying and "FLY : ACTIVÉ [E]" or "FLY : OFF [E]"
			btnFly.BackgroundColor3 = isFlying and PALETTE.green or PALETTE.red
			if isFlying and isNoclip then
				isNoclip = false
				btnNc.Text = "NOCLIP : OFF [E]"
				btnNc.BackgroundColor3 = PALETTE.red
				noclipPnl.Visible = false
			end
			updatePhys()
		elseif noclipPnl.Visible then
			isNoclip = not isNoclip
			btnNc.Text = isNoclip and "NOCLIP : ACTIVÉ [E]" or "NOCLIP : OFF [E]"
			btnNc.BackgroundColor3 = isNoclip and PALETTE.green or PALETTE.red
			if isNoclip and isFlying then
				isFlying = false
				btnFly.Text = "FLY : OFF [E]"
				btnFly.BackgroundColor3 = PALETTE.red
				flyPnl.Visible = false
			end
			updatePhys()
		end
	elseif input.KeyCode == Enum.KeyCode.Backquote then
		cmdBarPnl.Visible = not cmdBarPnl.Visible
		if cmdBarPnl.Visible then cIn:CaptureFocus() end
	end
end)

fSpdIn.FocusLost:Connect(function()
	fSpd = math.clamp(tonumber(fSpdIn.Text) or 50, 1, 100)
	fSpdIn.Text = tostring(fSpd)
	nSpdIn.Text = tostring(fSpd)
end)
nSpdIn.FocusLost:Connect(function()
	fSpd = math.clamp(tonumber(nSpdIn.Text) or 16, 1, 100)
	nSpdIn.Text = tostring(fSpd)
	fSpdIn.Text = tostring(fSpd)
end)

adminBtn.MouseButton1Click:Connect(function()
	playSfx(6895079853, 0.5)
	
	local c, m, hw, s_rH, s_rO, s_rC = {}, "Joueur", true, nil, nil, nil
	
	if getCmdsFunc then
		local s, c2, m2, hw2, rH, rO, rC = pcall(function() return getCmdsFunc:InvokeServer() end)
		if s then
			c, m, hw, s_rH, s_rO, s_rC = c2, m2, hw2, rH, rO, rC
		end
	end
	
	cmdRegistry = c
	myRole = m
	if s_rH and s_rO and s_rC then
		rolesHierarchy = s_rH
		rolesOrder = s_rO
		roleColors = s_rC
	end
	if hw == false then
		feedIn.Visible = false
		btnFeed.Visible = false
	else
		feedIn.Visible = true
		btnFeed.Visible = true
	end
	
	updateTabVisibility()
	main.Visible = not main.Visible
	if main.Visible then
		pcall(function()
			if isMinimized then setMinimized(false) end
		end)
		main.Size = UDim2.new(0, PANEL_W, 0, 0)
		TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
		}):Play()
		refreshCmdUI()
		updateBanLand()
		if pnlRanks.Visible and _G.fetchRanks then _G.fetchRanks() end
	end
end)

applyTheme("Sombre")

task.spawn(function()
	remotes = ReplicatedStorage:WaitForChild("SystemRemotes", 15)
	if not remotes then return end

	
	flyEvent        = remotes:WaitForChild("FlyEvent")
	notifEvent      = remotes:WaitForChild("NotifEvent")
	announceEvent   = remotes:WaitForChild("AnnounceEvent")
	refreshEvent    = remotes:WaitForChild("RefreshEvent")
	settingsEvent   = remotes:WaitForChild("SettingsEvent")
	feedbackEvent   = remotes:WaitForChild("FeedbackEvent")
	warnEvent       = remotes:WaitForChild("WarnEvent")
	noclipEvent     = remotes:WaitForChild("NoclipEvent")
	getBansFunc     = remotes:WaitForChild("GetBansFunc")
	unbanEvent      = remotes:WaitForChild("UnbanEvent")
	getCmdsFunc     = remotes:WaitForChild("GetCmdsFunc")
	updateCmdEvent  = remotes:WaitForChild("UpdateCmdEvent")
	logsEvent       = remotes:WaitForChild("LogsEvent")
	bubbleChatEvent = remotes:WaitForChild("BubbleChatEvent")
	cmdBarEvent     = remotes:WaitForChild("CmdBarEvent")
	forceChatEvent  = remotes:WaitForChild("ForceChatEvent")
	getRanksFunc    = remotes:WaitForChild("GetRanksFunc")
	revokeEvent     = remotes:WaitForChild("RevokeRoleEvent")

	
	task.spawn(function()
		local okAC = pcall(function()
			acAlertEvent    = remotes:WaitForChild("ACAlertEvent", 5)
			suspectAddEvent = remotes:WaitForChild("SuspectAddEvent", 5)
			suspectRemEvent = remotes:WaitForChild("SuspectRemEvent", 5)
			suspectListFunc = remotes:WaitForChild("SuspectListFunc", 5)
			ticketAlertEvent = remotes:WaitForChild("TicketAlertEvent", 5)
		end)
		
		pcall(function() clientACReport = remotes:WaitForChild("ClientACReport", 5) end)
		task.spawn(function()
			local Players = game:GetService("Players")
			local LocalPlayer = Players.LocalPlayer
			local lastReport = {}
			
			while task.wait(0.3) do
				if not clientACReport then continue end
				local cam = workspace.CurrentCamera
				if not cam then continue end
				local subj = cam.CameraSubject
				local ctype = cam.CameraType
				local now = os.clock()
				local _myLvl = rolesHierarchy[myRole] or 6
				local _isStaff = _myLvl <= 4
				local _camGuardOff = (_G.AgoraDisableCamGuard == true)
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				
				if ctype == Enum.CameraType.Scriptable then
					if not lastReport.freecam or (now - lastReport.freecam) > 8 then
						lastReport.freecam = now
						pcall(function() clientACReport:FireServer("FREECAM", "CameraType=Scriptable") end)
					end
					if not _isStaff and not _camGuardOff and hum then
						pcall(function()
							cam.CameraType = Enum.CameraType.Custom
							cam.CameraSubject = hum
						end)
					end
				end
				
				if ctype ~= Enum.CameraType.Custom
					and ctype ~= Enum.CameraType.Scriptable
					and ctype ~= Enum.CameraType.Follow then
					if not lastReport.override or (now - lastReport.override) > 12 then
						lastReport.override = now
						pcall(function() clientACReport:FireServer("FREECAM", "CameraType="..tostring(ctype)) end)
					end
				end
				
				if subj and subj:IsA("Humanoid") then
					local subjPlr = Players:GetPlayerFromCharacter(subj.Parent)
					if subjPlr and subjPlr ~= LocalPlayer then
						if not lastReport.view or (now - lastReport.view) > 8 then
							lastReport.view = now
							pcall(function() clientACReport:FireServer("VIEW_OTHER", "Subject="..subjPlr.Name) end)
						end
						if not _isStaff and not _camGuardOff and hum then
							pcall(function() cam.CameraSubject = hum end)
						end
					end
				end
				
				if hrp and ctype == Enum.CameraType.Custom then
					local dist = (cam.CFrame.Position - hrp.Position).Magnitude
					if dist > 60 then
						if not lastReport.detached or (now - lastReport.detached) > 8 then
							lastReport.detached = now
							pcall(function() clientACReport:FireServer("CAMERA_DETACHED", "dist="..math.floor(dist)) end)
						end
					end
				end
			end
		end)
		
		
		task.spawn(function()
			local Players = game:GetService("Players")
			local LocalPlayer = Players.LocalPlayer
			local cam = workspace.CurrentCamera
			local lastLook = cam and cam.CFrame.LookVector or Vector3.new(0,0,1)
			local snapEvents = {}
			local lastReport = 0
			while task.wait(0.05) do
				cam = workspace.CurrentCamera
				if not cam then continue end
				if not clientACReport then continue end
				local newLook = cam.CFrame.LookVector
				local dot = math.clamp(lastLook:Dot(newLook), -1, 1)
				local angleDeg = math.deg(math.acos(dot))
				if angleDeg > 30 then
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Exclude
					rp.FilterDescendantsInstances = LocalPlayer.Character and {LocalPlayer.Character} or {}
					local result = workspace:Raycast(cam.CFrame.Position, newLook * 300, rp)
					if result then
						local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
						if hitChar then
							local hitPlr = Players:GetPlayerFromCharacter(hitChar)
							if hitPlr and hitPlr ~= LocalPlayer then
								table.insert(snapEvents, os.clock())
							end
						end
					end
				end
				for i = #snapEvents, 1, -1 do
					if (os.clock() - snapEvents[i]) > 5 then table.remove(snapEvents, i) end
				end
				if #snapEvents >= 3 then
					local now = os.clock()
					if (now - lastReport) > 30 then
						lastReport = now
						pcall(function() clientACReport:FireServer("AIMBOT", #snapEvents .. " snaps caméra rapides en 5s") end)
					end
					snapEvents = {}
				end
				lastLook = newLook
			end
		end)
		
		
		task.spawn(function()
			local Players = game:GetService("Players")
			local CoreGui = game:GetService("CoreGui")
			local LocalPlayer = Players.LocalPlayer
			local lastESPReport = 0
			local function _looksLikeESP()
				for _, otherPlr in ipairs(Players:GetPlayers()) do
					if otherPlr == LocalPlayer or not otherPlr.Character then continue end
					local h = otherPlr.Character:FindFirstChild("Head") or otherPlr.Character.PrimaryPart
					if not h then continue end
					for _, c in ipairs(otherPlr.Character:GetDescendants()) do
						
						if c:IsA("Highlight") or c:IsA("SelectionBox") or c:IsA("SelectionSphere")
							or c:IsA("SelectionPartLasso") or c:IsA("BoxHandleAdornment")
							or c:IsA("SphereHandleAdornment") or c:IsA("LineHandleAdornment") then
							local _ok = false
							pcall(function() _ok = c:GetAttribute("AgoraIgnore") == true end)
							if not _ok then
								return true, "Highlight " .. c.ClassName .. " sur " .. otherPlr.Name
							end
						end
					end
				end
				local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
				local guiContainers = {pg, CoreGui}
				for _, container in ipairs(guiContainers) do
					if not container then continue end
					for _, gui in ipairs(container:GetDescendants()) do
						if gui:IsA("BillboardGui") and gui.Adornee then
							local adornee = gui.Adornee
							if adornee:IsDescendantOf(workspace) then
								local pCharacter = adornee:FindFirstAncestorOfClass("Model")
								if pCharacter and pCharacter ~= LocalPlayer.Character then
									local pPlr = Players:GetPlayerFromCharacter(pCharacter)
									if pPlr and pPlr ~= LocalPlayer then
										local _ok = false
										pcall(function() _ok = gui:GetAttribute("AgoraIgnore") == true end)
										if not _ok then
											return true, "BillboardGui sur " .. pPlr.Name
										end
									end
								end
							end
						end
					end
				end
				return false
			end
			while task.wait(3) do
				if not clientACReport then continue end
				local now = os.clock()
				if (now - lastESPReport) < 30 then continue end
				local detected, details = _looksLikeESP()
				if detected then
					lastESPReport = now
					pcall(function() clientACReport:FireServer("ESP", details) end)
				end
			end
		end)
		
		pcall(function()
			themePrefFunc = remotes:WaitForChild("ThemePrefFunc", 5)
			if themePrefFunc then
				local ok, v = pcall(function() return themePrefFunc:InvokeServer("load") end)
				if ok and type(v) == "string" and THEMES[v] then
					applyTheme(v)
				end
			end
		end)
		
		pcall(function()
			local clientConfigFunc = remotes:WaitForChild("ClientConfigFunc", 5)
			if clientConfigFunc then
				local ok, cfg = pcall(function() return clientConfigFunc:InvokeServer() end)
				if ok and type(cfg) == "table" then
					_G.AgoraClientConfig = cfg
					if cfg.ui and cfg.ui.default_theme and not (currentTheme and currentTheme ~= "Cyberpunk") then
						if THEMES[cfg.ui.default_theme] then
							applyTheme(cfg.ui.default_theme)
						end
					end
					if cfg.update_message and cfg.update_message ~= "" then
						task.delay(2, function()
							pcall(function()
								local dur = cfg.update_message_duration or 6
								if showNotif then
									showNotif(tostring(cfg.update_message))
								end
							end)
						end)
					end
				end
			end
		end)
		if okAC and acAlertEvent then
			acAlertEvent.OnClientEvent:Connect(function(typ, desc, suspect)
				
				if not _muteAC then
					spawnACAlert(typ or "ALERT", desc or "", suspect)
				end
				addACLog({type = typ or "ALERT", desc = desc or "", suspect = suspect})
			end)
		end
		if ticketAlertEvent then
			ticketAlertEvent.OnClientEvent:Connect(function(msg)
				
				if _muteTickets then return end
				showNotif("TICKET : " .. tostring(msg))
			end)
		end
	end)

	
	task.spawn(function()
		task.wait(4)
		if not _G.AgoraGradeNotified then
			_G.AgoraGradeNotified = true
			local ok, _, role = pcall(function() return getCmdsFunc:InvokeServer() end)
			if ok and type(role) == "string" then
				if string.lower(role) ~= "joueurs" then
					showNotif("GRADE ACTUEL : " .. string.upper(role))
				end
			end
		end
	end)

	notifEvent.OnClientEvent:Connect(function(m, s)
		if m == "BLIND" then
			local b = gui:FindFirstChild("BlindFold")
			if not b then
				b = Instance.new("Frame")
				b.Parent = gui
				b.Name = "BlindFold"
				b.Size = UDim2.new(1, 0, 1, 0)
				b.BackgroundColor3 = Color3.new(0, 0, 0)
				b.ZIndex = 10001
			end
			b.Visible = s
		else
			showNotif(tostring(m))
		end
	end)

	warnEvent.OnClientEvent:Connect(function(msg) triggerWarn(msg) end)
	announceEvent.OnClientEvent:Connect(function(role, name, msg) triggerAnn(role, name, msg) end)

	settingsEvent.OnClientEvent:Connect(function(act, val)
		if act == "UpdatePrefix" then currentPrefix = val end
		if act == "UpdateConfig" then
			_G.AgoraConfig = val
		end
	end)

	refreshEvent.OnClientEvent:Connect(function(newReg)
		if newReg then cmdRegistry = newReg end
		if main.Visible then refreshCmdUI() end
	end)

	flyEvent.OnClientEvent:Connect(function(act, s)
		if act == "OpenPanel" then
			flyPnl.Visible = s
			if s then noclipPnl.Visible = false end
		elseif act == "Toggle" then
			isFlying = s
			btnFly.Text = isFlying and "FLY : ACTIVÉ [E]" or "FLY : OFF [E]"
			btnFly.BackgroundColor3 = isFlying and PALETTE.green or PALETTE.red
			
			if isFlying and isNoclip then
				isNoclip = false
				btnNc.Text = "NOCLIP : OFF [E]"
				btnNc.BackgroundColor3 = PALETTE.red
			end
			updatePhys()
		end
	end)

	noclipEvent.OnClientEvent:Connect(function(act, s)
		if act == "OpenPanel" then
			noclipPnl.Visible = s
			if s then flyPnl.Visible = false end
		elseif act == "Toggle" then
			isNoclip = s
			btnNc.Text = isNoclip and "NOCLIP : ACTIVÉ [E]" or "NOCLIP : OFF [E]"
			btnNc.BackgroundColor3 = isNoclip and PALETTE.green or PALETTE.red
			
			if isNoclip and isFlying then
				isFlying = false
				btnFly.Text = "FLY : OFF [E]"
				btnFly.BackgroundColor3 = PALETTE.red
			end
			updatePhys()
		end
	end)

	bubbleChatEvent.OnClientEvent:Connect(function(act, s)
		if act == "OpenPanel" then bubblePnl.Visible = s end
	end)

	cmdBarEvent.OnClientEvent:Connect(function(act, s)
		if act == "OpenPanel" then cmdBarPnl.Visible = s end
	end)

	logsEvent.OnClientEvent:Connect(function(logs)
		logsPnl.Visible = true
		for _, v in pairs(logsScroll:GetChildren()) do
			if v:IsA("TextLabel") then v:Destroy() end
		end
		for i, l in ipairs(logs) do
			local t = Instance.new("TextLabel")
			t.Parent = logsScroll
			t.Size = UDim2.new(1, -10, 0, 25)
			t.BackgroundTransparency = 1
			t.Text = "[" .. l.Time .. "] " .. l.User .. " : " .. l.Cmd
			t.TextColor3 = PALETTE.cyan
			t.Font = Enum.Font.Code
			t.TextSize = 13
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.ZIndex = 3006
			t.LayoutOrder = i
		end
		task.delay(0.1, function()
			logsScroll.CanvasSize = UDim2.new(0, 0, 0, logsLay.AbsoluteContentSize.Y + 10)
		end)
	end)

	forceChatEvent.OnClientEvent:Connect(function(msg)
		pcall(function()
			if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
				local tc = TextChatService:FindFirstChild("TextChannels")
				if tc and tc:FindFirstChild("RBXGeneral") then
					tc.RBXGeneral:SendAsync(msg)
				end
			else
				local rs = game:GetService("ReplicatedStorage")
				local dc = rs:FindFirstChild("DefaultChatSystemChatEvents")
				if dc and dc:FindFirstChild("SayMessageRequest") then
					dc.SayMessageRequest:FireServer(msg, "All")
				end
			end
		end)
	end)
end)

task.spawn(function()
	local RS = game:GetService("ReplicatedStorage")
	local r = RS:WaitForChild("SystemRemotes", 30)
	if not r then return end
	local clientStateReport = r:WaitForChild("ClientStateReport", 15)
	if not clientStateReport then return end
	local lastSent = nil
	while true do
		task.wait(1.5)
		
		
		local panelOpen = false
		pcall(function() panelOpen = (main and main.Visible) == true end)
		local state = {
			fly    = isFlying or false,
			noclip = isNoclip or false,
			panel  = panelOpen,
		}
		
		local hasOn = state.fly or state.noclip or state.panel
		local changed = (lastSent == nil)
			or (lastSent.fly ~= state.fly)
			or (lastSent.noclip ~= state.noclip)
			or (lastSent.panel ~= state.panel)
		if hasOn or changed then
			pcall(function() clientStateReport:FireServer(state) end)
			lastSent = state
		end
	end
end)

task.spawn(function()
	local RS = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local r = RS:WaitForChild("SystemRemotes", 30)
	if not r then return end
	local emotePanelEvent = r:WaitForChild("EmotePanelEvent", 15)
	local getEmotesFunc   = r:WaitForChild("GetEmotesFunc", 15)
	local playEmoteEvent  = r:WaitForChild("PlayEmoteEvent", 15)
	if not (emotePanelEvent and getEmotesFunc and playEmoteEvent) then return end
	local plr = Players.LocalPlayer
	local pg = plr:WaitForChild("PlayerGui")
	
	local old = pg:FindFirstChild("AgoraEmotesPanel")
	if old then old:Destroy() end
	local emotesGui = Instance.new("ScreenGui")
	emotesGui.Name = "AgoraEmotesPanel"
	emotesGui.ResetOnSpawn = false
	emotesGui.IgnoreGuiInset = true
	emotesGui.DisplayOrder = 99998
	emotesGui.Enabled = false
	emotesGui.Parent = pg
	local back = Instance.new("Frame", emotesGui)
	back.Size = UDim2.new(1, 0, 1, 0)
	back.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.BorderSizePixel = 0
	back.ZIndex = 99998
	local card = Instance.new("Frame", emotesGui)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 480, 0, 540)
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	card.BorderSizePixel = 0
	card.ZIndex = 99999
	local cc = Instance.new("UICorner", card) cc.CornerRadius = UDim.new(0, 14)
	local cs = Instance.new("UIStroke", card) cs.Color = Color3.fromRGB(120, 80, 200) cs.Thickness = 2
	local header = Instance.new("Frame", card)
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
	header.BorderSizePixel = 0
	header.ZIndex = 99999
	local hc = Instance.new("UICorner", header) hc.CornerRadius = UDim.new(0, 14)
	local hMask = Instance.new("Frame", header)
	hMask.Size = UDim2.new(1, 0, 0, 14)
	hMask.Position = UDim2.new(0, 0, 1, -14)
	hMask.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
	hMask.BorderSizePixel = 0
	hMask.ZIndex = 99999
	local title = Instance.new("TextLabel", header)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 14, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "[EMO] ÉMOTES"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 100000
	local closeBtn = Instance.new("TextButton", header)
	closeBtn.Size = UDim2.new(0, 38, 0, 38)
	closeBtn.Position = UDim2.new(1, -46, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.AutoButtonColor = true
	closeBtn.ZIndex = 100000
	local cbc = Instance.new("UICorner", closeBtn) cbc.CornerRadius = UDim.new(0, 8)
	local subtitle = Instance.new("TextLabel", card)
	subtitle.Size = UDim2.new(1, -28, 0, 26)
	subtitle.Position = UDim2.new(0, 14, 0, 56)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Clique sur un émote pour le jouer"
	subtitle.TextColor3 = Color3.fromRGB(180, 180, 200)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 12
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.ZIndex = 99999
	local scroll = Instance.new("ScrollingFrame", card)
	scroll.Size = UDim2.new(1, -20, 1, -100)
	scroll.Position = UDim2.new(0, 10, 0, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 200)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 99999
	local grid = Instance.new("UIGridLayout", scroll)
	grid.CellSize = UDim2.new(0, 138, 0, 60)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local pad = Instance.new("UIPadding", scroll)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	local NAME_EMOJI = {
		wave="[WAVE]", dance="[DANCE]", dance2="[DANC2]", dance3="[DANC3]", laugh="[LAUGH]",
		cheer="[CHEER]", point="[POINT]", salute="[SALUTE]", shrug="[SHRUG]", hype="[HYPE]",
		floss="[FLOSS]", shuffle="[SHUFFLE]", toprock="[MUSIC]", shy="[SHY]", celebrate="[CELEB]",
		superhero="[HERO]",
	}
	local built = false
	local function buildGrid()
		if built then return end
		built = true
		local ok, EMOTES = pcall(function() return getEmotesFunc:InvokeServer() end)
		if not ok or type(EMOTES) ~= "table" then
			local err = Instance.new("TextLabel", scroll)
			err.Size = UDim2.new(1, 0, 0, 40)
			err.BackgroundTransparency = 1
			err.Text = "Impossible de charger les émotes."
			err.TextColor3 = Color3.fromRGB(255, 120, 120)
			err.Font = Enum.Font.Gotham
			err.TextSize = 13
			err.ZIndex = 100000
			return
		end
		for i, em in ipairs(EMOTES) do
			local nameLow = em.Name:lower()
			local btn = Instance.new("TextButton", scroll)
			btn.LayoutOrder = i
			btn.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
			btn.BorderSizePixel = 0
			btn.Text = (NAME_EMOJI[nameLow] or "[EMO]") .. "  " .. em.Name
			btn.TextColor3 = Color3.fromRGB(240, 240, 240)
			btn.Font = Enum.Font.GothamMedium
			btn.TextSize = 13
			btn.AutoButtonColor = true
			btn.ZIndex = 100000
			local c = Instance.new("UICorner", btn) c.CornerRadius = UDim.new(0, 8)
			local s = Instance.new("UIStroke", btn) s.Color = Color3.fromRGB(120, 80, 200) s.Thickness = 1 s.Transparency = 0.5
			btn.MouseButton1Click:Connect(function()
				pcall(function() playEmoteEvent:FireServer(em.Id) end)
				btn.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
				task.delay(0.2, function()
					if btn.Parent then btn.BackgroundColor3 = Color3.fromRGB(35, 38, 48) end
				end)
			end)
		end
	end
	local function open() buildGrid() emotesGui.Enabled = true end
	local function close() emotesGui.Enabled = false end
	closeBtn.MouseButton1Click:Connect(close)
	back.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			close()
		end
	end)
	emotePanelEvent.OnClientEvent:Connect(function(action)
		if action == "OPEN" then open()
		elseif action == "CLOSE" then close()
		else open() end
	end)
end)

task.spawn(function()
	local RS = game:GetService("ReplicatedStorage")
	local r = RS:WaitForChild("SystemRemotes", 30)
	if not r then return end
	local acToggleEvent = r:WaitForChild("AcToggleEvent", 15)
	if not acToggleEvent then return end
	
	while not pnlAC do task.wait(0.2) end
	local btn = Instance.new("TextButton")
	btn.Name = "ToggleACBtn"
	btn.Size = UDim2.new(0, 130, 0, 22)
	btn.Position = UDim2.new(1, -135, 0, 1)
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)  
	btn.BorderSizePixel = 0
	btn.Text = "[AC] AC : ACTIF"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.AutoButtonColor = true
	btn.ZIndex = 1010
	btn.Visible = false  
	btn.Parent = pnlAC
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 6)
	local acDisabled = false
	local function refreshBtn()
		if acDisabled then
			btn.Text = "[!] AC : DESACTIVE"
			btn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		else
			btn.Text = "[AC] AC : ACTIF"
			btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
		end
	end
	
	local function refreshVis()
		local lvl = rolesHierarchy[myRole] or 6
		local plrLocal = game:GetService("Players").LocalPlayer
		local isOwner = (game.CreatorType == Enum.CreatorType.User and plrLocal and plrLocal.UserId == game.CreatorId)
		btn.Visible = (lvl <= 2) or isOwner
	end
	refreshVis()
	task.spawn(function()
		local lastRole = myRole
		while true do
			task.wait(2)
			if myRole ~= lastRole then
				lastRole = myRole
				refreshVis()
			end
		end
	end)
	
	
	btn.MouseButton1Click:Connect(function()
		local newState = not acDisabled
		btn.Text = "[WAIT] EN COURS..."
		btn.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
		pcall(function() acToggleEvent:FireServer({disabled = newState}) end)
		task.delay(3, function()
			if btn.Text == "[WAIT] EN COURS..." then
				refreshBtn()
			end
		end)
	end)
	acToggleEvent.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			acDisabled = payload.disabled == true
			refreshBtn()
			if payload.refused then
				btn.Text = "[X] REFUSE (role)"
				btn.BackgroundColor3 = Color3.fromRGB(120, 80, 80)
				task.delay(2, function() refreshBtn() end)
			end
		end
	end)
end)