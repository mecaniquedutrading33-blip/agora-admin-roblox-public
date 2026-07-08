-- Agora Universelle Hub - Loader v24 (2-chunk fetch)
local B="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua"
local R="&_="..math.random(100000,999999)
local function fetch(u)
	local ok,res=pcall(function()return game:HttpGet(u)end)
	if ok and res and #res>50 then return res end
	return nil
end
-- Fetch 2 halves (each ~165KB, under Solara 200KB limit)
local p1=fetch(B.."&start=0&end=165000"..R)
local p2=fetch(B.."&start=165001&end=400000"..R)
if not p1 or not p2 then
	warn("[A]Fetch fail")
	return
end
local code=p1..p2
local fn,err=loadstring(code)
if fn then
	local ok,e2=pcall(fn)
	if not ok then warn("[A]"..tostring(e2)) end
else
	warn("[A]ls:"..tostring(err))
end
