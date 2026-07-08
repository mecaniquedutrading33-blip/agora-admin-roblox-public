-- Agora Universelle Hub - Loader v22 (chunked fetch + concat)
local B="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua"
local C="&_="..math.random(100000,999999)
local function fetch(u)
	local ok,res=pcall(function()return game:HttpGet(u)end)
	if ok and res and #res>100 then return res end
	return nil
end
-- Get file size via small range request
local sz=fetch(B.."&start=0&end=1"..C)
local total=0
if sz then
	local s=tostring(sz):match("(%d+)")
	if s then total=tonumber(s) or 0 end
end
if total==0 then total=331220 end
-- Fetch in 2 chunks
local mid=math.floor(total/2)
local p1=fetch(B.."&start=0&end="..mid..C)
local p2=fetch(B.."&start="..(mid+1).."&end="..total..C)
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
