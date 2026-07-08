-- Agora Universelle Hub - Loader (v39.15)
-- Ce loader charge le panel en 2 parties pour eviter les limites de taille des executeurs

local function loadPart(url)
	local ok, code = pcall(function() return game:HttpGet(url) end)
	if ok and code and #code > 100 then return code end
	-- Fallback
	ok, code = pcall(function() return HttpService:GetAsync(url) end)
	if ok and code and #code > 100 then return code end
	return nil
end

local BASE = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file="
local nocache = "&_=" .. math.random(100000, 999999)

local part1 = loadPart(BASE .. "AgoraPart1.lua" .. nocache)
if not part1 then
	warn("[AGORA] Erreur: impossible de charger la partie 1")
	return
end

local part2 = loadPart(BASE .. "AgoraPart2.lua" .. nocache)
if not part2 then
	warn("[AGORA] Erreur: impossible de charger la partie 2")
	return
end

local fullCode = part1 .. "\n" .. part2
local ok, err = pcall(loadstring, fullCode)
if ok then
	err() -- execute
else
	warn("[AGORA] Erreur loadstring: " .. tostring(err))
end
