-- Agora Admin Loader v18.0 - Fixed Commands loading + MainModule factory
-- Place ce Script dans ServerScriptService/TON_DOSSIER/
-- Place Settings.lua + ScreenGui (avec LocalScript DEDANS) + Commands + MainModule dans le MEME dossier

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local isStudio = RunService:IsStudio()

-- 1) Trouver Settings.lua dans le dossier actuel
local scriptFolder = script.Parent
print("[AGORA v18.0] Chargement depuis dossier : " .. scriptFolder.Name)

local settingsFile = scriptFolder:FindFirstChild("Settings")
if not settingsFile then
    for _, child in ipairs(scriptFolder:GetDescendants()) do
        if child.Name == "Settings" and child:IsA("ModuleScript") then
            settingsFile = child
            break
        end
    end
end

if not settingsFile then
    error("[AGORA] Settings.lua introuvable dans " .. scriptFolder.Name)
    return
end

local SETTINGS
local ok, err = pcall(function()
    SETTINGS = require(settingsFile)
end)
if not ok then
    error("[AGORA] Erreur require Settings.lua : " .. tostring(err))
    return
end

print("[AGORA] Settings charges : theme=" .. tostring(SETTINGS.Theme) .. " prefix=" .. tostring(SETTINGS.Prefix))

-- 2) ====== CHARGER COMMANDS ======
local commandsModule = scriptFolder:FindFirstChild("Commands")
if not commandsModule then
    for _, child in ipairs(scriptFolder:GetDescendants()) do
        if child.Name == "Commands" and child:IsA("ModuleScript") then
            commandsModule = child
            break
        end
    end
end

local Commands = {}
if commandsModule then
    local okCmd, resCmd = pcall(function()
        return require(commandsModule)
    end)
    if okCmd then
        Commands = resCmd or {}
        print("[AGORA] Commands charges : " .. tostring(#Commands) .. " commandes")
    else
        warn("[AGORA] Erreur require Commands : " .. tostring(resCmd))
    end
else
    warn("[AGORA] Commands.lua introuvable — MainModule recevra une table vide")
end

-- 3) CREER SystemRemotes
local SystemRemotes = ReplicatedStorage:FindFirstChild("SystemRemotes")
if not SystemRemotes then
    SystemRemotes = Instance.new("Folder")
    SystemRemotes.Name = "SystemRemotes"
    SystemRemotes.Parent = ReplicatedStorage
end

local function ensureRemote(name, class)
    local r = SystemRemotes:FindFirstChild(name)
    if not r then
        r = Instance.new(class)
        r.Name = name
        r.Parent = SystemRemotes
    end
    return r
end

ensureRemote("GetCmdsFunc", "RemoteFunction")
ensureRemote("RefreshEvent", "RemoteEvent")
ensureRemote("NotifEvent", "RemoteEvent")
ensureRemote("FlyEvent", "RemoteEvent")
ensureRemote("SettingsEvent", "RemoteEvent")
ensureRemote("CmdBarEvent", "RemoteEvent")

-- 4) ====== AUTO-CLONE DU SCREENGUI ======
local originalGui = scriptFolder:FindFirstChild("AgoraAdmin")
if not originalGui or not originalGui:IsA("ScreenGui") then
    for _, child in ipairs(scriptFolder:GetChildren()) do
        if child:IsA("ScreenGui") then originalGui = child; break end
    end
    if not originalGui then
        for _, child in ipairs(scriptFolder:GetDescendants()) do
            if child:IsA("ScreenGui") then originalGui = child; break end
        end
    end
end

if originalGui then
    print("[AGORA] ScreenGui trouve : " .. originalGui.Name)
    
    -- Supprime anciens clones dans StarterGui
    for _, child in ipairs(StarterGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == originalGui.Name then
            child:Destroy()
        end
    end
    
    -- Clone dans StarterGui pour les futurs joueurs
    local cloneGui = originalGui:Clone()
    cloneGui.ResetOnSpawn = false
    cloneGui.Parent = StarterGui
    print("[AGORA] ScreenGui clone dans StarterGui")
    
    -- Clone dans PlayerGui pour les joueurs DEJA presents (Play Solo)
    for _, plr in ipairs(Players:GetPlayers()) do
        local pg = plr:FindFirstChild("PlayerGui")
        if pg and not pg:FindFirstChild(cloneGui.Name) then
            local playClone = originalGui:Clone()
            playClone.ResetOnSpawn = false
            playClone.Parent = pg
            print("[AGORA] ScreenGui clone dans PlayerGui de " .. plr.Name)
        end
    end
else
    warn("[AGORA] ScreenGui NON TROUVE dans " .. scriptFolder.Name)
end

-- 5) ====== CHARGER MAINMODULE (local ou distant) ======
local function loadMainModule()
    -- === CAS 1: MainModule LOCAL ===
    local module = scriptFolder:FindFirstChild("MainModule")
    if module then
        print("[AGORA] MainModule LOCAL trouve")
        local mainMod = require(module)
        if type(mainMod) == "function" then
            -- Factory function : l'appeler avec SETTINGS + Commands + loaderScript
            local ok, result = pcall(function()
                return mainMod(SETTINGS, Commands, script)
            end)
            if ok and result then
                print("[AGORA] MainModule factory OK")
                return result
            else
                warn("[AGORA] Erreur factory MainModule : " .. tostring(result))
            end
        elseif type(mainMod) == "table" then
            -- Table directe (avec ou sans Init)
            if mainMod.Init then
                local ok, err = pcall(function() return mainMod.Init(SystemRemotes, SETTINGS, Commands) end)
                if not ok then warn("[AGORA] Init erreur : " .. tostring(err)) end
            end
            return mainMod
        end
    end

    -- === CAS 2: MainModule HTTP (fallback) ===
    print("[AGORA] MainModule local absent. Tentative HTTP...")
    local url = "https://raw.githubusercontent.com/mecaniquedutrading33-blip/agora-admin-roblox-public/main/MainModule.lua?nocache=" .. tick()
    
    local ok, source = pcall(function()
        return HttpService:GetAsync(url, true)
    end)
    
    if ok and source and #source > 1000 then
        local ok2, loaderFn = pcall(function() return loadstring(source) end)
        if ok2 and loaderFn then
            local ok3, maybeFunc = pcall(function() return loaderFn() end)
            if ok3 and type(maybeFunc) == "function" then
                local ok4, result = pcall(function()
                    return maybeFunc(SETTINGS, Commands, script)  -- ← Commands passé ici
                end)
                if ok4 and result then
                    print("[AGORA] MainModule HTTP OK")
                    return result
                else
                    warn("[AGORA] Erreur exec MainModule HTTP : " .. tostring(result))
                end
            elseif ok3 and type(maybeFunc) == "table" then
                return maybeFunc
            end
        end
    end

    -- Fallback minimal
    warn("[AGORA] MainModule introuvable — serveur minimal actif")
    return {
        Init = function() end,
        GetCommands = function() return Commands end,
        ExecCommand = function() return nil, "MainModule absent" end
    }
end

local MainModule = loadMainModule()

-- 6) Setup GetCmdsFunc
local GetCmdsFunc = SystemRemotes:FindFirstChild("GetCmdsFunc")
if GetCmdsFunc then
    GetCmdsFunc.OnServerInvoke = function(player)
        local cmds = Commands
        if MainModule and MainModule.GetCommands then
            local ok, res = pcall(MainModule.GetCommands)
            if ok then cmds = res or Commands end
        end
        print("[AGORA] GetCmdsFunc -> " .. tostring(#cmds) .. " commandes pour " .. player.Name)
        return cmds
    end
end

-- 7) Log joueurs
Players.PlayerAdded:Connect(function(plr)
    print("[AGORA] Joueur connecte : " .. plr.Name)
end)

print("=========================================")
print("[AGORA v18.0] SERVEUR PRET")
print("[AGORA v18.0] Commands=" .. tostring(#Commands) .. " | ScreenGui auto-clone actif")
print("=========================================")
