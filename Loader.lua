-- Agora Diagnostic Loader v25 — affiche TOUT ce qui se passe
-- Place comme Script dans ServerScriptService (PAS ailleurs)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- ═══════ Message visible à l'écran pour prouver que le serveur tourne ═══════
local function showServerMsg(text, color)
	for _, plr in ipairs(Players:GetPlayers()) do
		local pg = plr:FindFirstChild("PlayerGui")
		if pg then
			local sg = pg:FindFirstChild("AgoraDiag")
			if not sg then
				sg = Instance.new("ScreenGui")
				sg.Name = "AgoraDiag"
				sg.ResetOnSpawn = false
				sg.Parent = pg
				local lbl = Instance.new("TextLabel")
				lbl.Name = "Msg"
				lbl.Size = UDim2.new(0, 600, 0, 200)
				lbl.Position = UDim2.new(0.5, -300, 0, 10)
				lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
				lbl.BackgroundTransparency = 0.2
				lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
				lbl.Font = Enum.Font.GothamBold
				lbl.TextSize = 14
				lbl.TextWrapped = true
				lbl.ZIndex = 99999
				lbl.Parent = sg
			end
			local lbl = sg:FindFirstChild("Msg")
			if lbl then
				lbl.Text = lbl.Text .. "\n" .. text
				if color then lbl.TextColor3 = color end
			end
		end
	end
	print(text)
end

showServerMsg("[AGORA DIAG] Loader v25 démarré")

-- ═══════ Créer SystemRemotes ═══════
local sr = ReplicatedStorage:FindFirstChild("SystemRemotes")
if not sr then
	sr = Instance.new("Folder")
	sr.Name = "SystemRemotes"
	sr.Parent = ReplicatedStorage
end
local gcf = sr:FindFirstChild("GetCmdsFunc") or Instance.new("RemoteFunction")
gcf.Name = "GetCmdsFunc"; gcf.Parent = sr
local cbe = sr:FindFirstChild("CmdBarEvent") or Instance.new("RemoteEvent")
cbe.Name = "CmdBarEvent"; cbe.Parent = sr
showServerMsg("[AGORA DIAG] SystemRemotes OK")

-- ═══════ Chercher Settings / Commands / MainModule ═══════
local function findAny(name, class)
	for _, svc in ipairs({"ServerScriptService","ReplicatedStorage","ServerStorage","Workspace"}) do
		local s = game:GetService(svc)
		local f = s:FindFirstChild(name, true)
		if f and (not class or f:IsA(class)) then return f end
		for _, c in ipairs(s:GetDescendants()) do
			if c.Name == name and (not class or c:IsA(class)) then return c end
		end
	end
	return nil
end

local st = findAny("Settings", "ModuleScript")
local cm = findAny("Commands", "ModuleScript")
local mm = findAny("MainModule", "ModuleScript")
local gui = findAny("AgoraAdmin", "ScreenGui")

if not gui then
	-- Cherche par contenu (bouton)
	for _, svc in ipairs({"StarterGui","ServerScriptService"}) do
		for _, c in ipairs(game:GetService(svc):GetDescendants()) do
			if c:IsA("ScreenGui") and (c:FindFirstChild("AdminLogoBtn") or c:FindFirstChild("OpenButton")) then
				gui = c; break
			end
		end
		if gui then break end
	end
end

showServerMsg("Settings: " .. (st and st:GetFullName() or "❌ MANQUANT"), st and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0))
showServerMsg("Commands: " .. (cm and cm:GetFullName() or "❌ MANQUANT"), cm and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0))
showServerMsg("MainModule: " .. (mm and mm:GetFullName() or "❌ MANQUANT"), mm and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0))
showServerMsg("ScreenGui: " .. (gui and gui:GetFullName() or "❌ MANQUANT"), gui and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0))

-- Si ScreenGui manquant, créer un bouton test minimal
if not gui then
	showServerMsg("[AGORA DIAG] ScreenGui introuvable → bouton test créé", Color3.fromRGB(255, 200, 0))
	
	local testGui = Instance.new("ScreenGui")
	testGui.Name = "AgoraTestGui"
	testGui.ResetOnSpawn = false
	
	local btn = Instance.new("TextButton")
	btn.Name = "TestBtn"
	btn.Size = UDim2.new(0, 120, 0, 40)
	btn.Position = UDim2.new(0, 10, 0, 10)
	btn.Text = "AGORA TEST"
	btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = testGui
	
	-- Quand un joueur rejoint, lui donner le GUI
	Players.PlayerAdded:Connect(function(plr)
		local pg = plr:WaitForChild("PlayerGui", 10)
		if pg then
			testGui:Clone().Parent = pg
		end
	end)
	-- Pour les joueurs déjà là
	for _, plr in ipairs(Players:GetPlayers()) do
		local pg = plr:FindFirstChild("PlayerGui")
		if pg then testGui:Clone().Parent = pg end
	end
	
	return
end

-- ═══════ Charger Settings ═══════
if not st then
	showServerMsg("[AGORA DIAG] Settings introuvable — arrêt", Color3.fromRGB(255,0,0))
	return
end
local ok, SETTINGS = pcall(require, st)
if not ok then
	showServerMsg("[AGORA DIAG] Settings erreur: " .. tostring(SETTINGS), Color3.fromRGB(255,0,0))
	return
end
showServerMsg("[AGORA DIAG] Settings chargé")

-- ═══════ Charger Commands ═══════
if not cm then
	showServerMsg("[AGORA DIAG] Commands introuvable — arrêt", Color3.fromRGB(255,0,0))
	return
end
local ok2, commandsObj = pcall(require, cm)
if not ok2 then
	showServerMsg("[AGORA DIAG] Commands erreur: " .. tostring(commandsObj), Color3.fromRGB(255,0,0))
	return
end
local cmdCount = 0
for _ in pairs(commandsObj) do cmdCount += 1 end
showServerMsg("[AGORA DIAG] Commands chargé (" .. cmdCount .. " cmds)")

-- ═══════ Charger MainModule ═══════
if not mm then
	showServerMsg("[AGORA DIAG] MainModule introuvable — arrêt", Color3.fromRGB(255,0,0))
	return
end
local ok3, mainFactory = pcall(require, mm)
if not ok3 then
	showServerMsg("[AGORA DIAG] MainModule erreur: " .. tostring(mainFactory), Color3.fromRGB(255,0,0))
	return
end
showServerMsg("[AGORA DIAG] MainModule factory OK")

-- ═══════ Lancer MainModule ═══════
local scriptRef = script
local ok4, system = pcall(mainFactory, SETTINGS, commandsObj, scriptRef)
if not ok4 then
	showServerMsg("[AGORA DIAG] MainModule CRASH: " .. tostring(system), Color3.fromRGB(255,0,0))
	return
end
showServerMsg("[AGORA DIAG] MainModule initialisé")

-- Connecter GetCmdsFunc
if system and system.GetCommands then
	gcf.OnServerInvoke = function(player)
		return system:GetCommands()
	end
	showServerMsg("[AGORA DIAG] GetCmdsFunc connecté")
else
	showServerMsg("[AGORA DIAG] ⚠ system.GetCommands absent", Color3.fromRGB(255,200,0))
end

showServerMsg("[AGORA DIAG] ✅ SYSTEM READY", Color3.fromRGB(0,255,100))
