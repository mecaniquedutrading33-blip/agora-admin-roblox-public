-- Agora Universelle Hub - Loader v19 (2 parts, clean split)
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
if not o2 then warn("[A]P2 fail")end
