-- Agora Universelle Hub - Loader v7 (RequestAsync)
local B="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file="
local C="&_="..math.random(100000,999999)
local function L(u)
	-- Method 1: RequestAsync (works on Solara)
	local o,c=pcall(function()
		local r=game.HttpService:RequestAsync({Url=u,Method="GET"})
		if r and r.Success and r.Body and #r.Body>100 then return r.Body end
	end)
	if o and c then return c end
	-- Method 2: game:HttpGet fallback
	o,c=pcall(function()return game:HttpGet(u)end)
	if o and c and #c>100 then return c end
	return nil
end
local function X(u)
	local c=L(u)
	if c then
		local f,e=loadstring(c)
		if f then
			local o2,e2=pcall(f)
			if not o2 then warn("[A]"..tostring(e2))end
			return o2
		else warn("[A]ls:"..tostring(e))end
	end
	return false
end
local o1=X(B.."AgoraPart1.lua"..C)
if not o1 then warn("[A]P1 fail");return end
local o2=X(B.."AgoraPart2.lua"..C)
if not o2 then warn("[A]P2 fail");return end
local o3=X(B.."AgoraPart3.lua"..C)
if not o3 then warn("[A]P3 fail")end
