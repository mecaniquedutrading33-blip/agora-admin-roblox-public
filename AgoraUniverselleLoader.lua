-- Agora Universelle Hub - Loader v11 (RequestAsync + fallback)
local B="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua"
local G="https://raw.githubusercontent.com/mecaniquedutrading33-blip/agora-admin-roblox-public/main/AgoraUniverselleHub.lua"
local C="&_="..math.random(100000,999999)
local function L(u)
	local o,c=pcall(function()
		local r=game.HttpService:RequestAsync({Url=u,Method="GET"})
		if r and r.Success and r.Body and #r.Body>100 then return r.Body end
	end)
	if o and c then return c end
	o,c=pcall(function()return game:HttpGet(u)end)
	if o and c and #c>100 then return c end
	return nil
end
local code=L(B..C)
if not code then code=L(G)end
if code and #code>1000 then
	local f,e=loadstring(code)
	if f then
		local o2,e2=pcall(f)
		if not o2 then warn("[A]"..tostring(e2))end
	else warn("[A]ls:"..tostring(e))end
else warn("[A]code vide")end
