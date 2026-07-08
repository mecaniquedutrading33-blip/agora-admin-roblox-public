-- Agora Universelle Hub - Loader v8 (modulaire)
local B="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file="
local C="&_="..math.random(100000,999999)
local function L(u)
	local o,c=pcall(function()return game:HttpGet(u)end)
	if o and c and #c>100 then
		local f,e=loadstring(c)
		if f then
			local o2,e2=pcall(f)
			if not o2 then warn("[A]"..tostring(e2))end
			return o2
		else warn("[A]ls:"..tostring(e))end
	end
	return false
end

local o1=L(B.."AgoraPart1.lua"..C)
if not o1 then warn("[A]P1 fail");return end
local o2=L(B.."AgoraPart2.lua"..C)
if not o2 then warn("[A]P2 fail");return end
local o3=L(B.."AgoraPart3.lua"..C)
if not o3 then warn("[A]P3 fail");return end
local o4=L(B.."AgoraPart4.lua"..C)
if not o4 then warn("[A]P4 fail");return end

-- All parts loaded, call _buildPanel
if _G._buildPanel then
	local o,e=pcall(_G._buildPanel)
	if not o then warn("[A]build:"..tostring(e))end
else
	warn("[A]_buildPanel not found")
end