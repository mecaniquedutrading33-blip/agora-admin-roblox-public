-- Agora Universelle Hub - Loader v21 (single file, chunked fetch)
local B="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua"
local C="&_="..math.random(100000,999999)
local function fetch(u)
	local ok,res=pcall(function()
		local hs=game:GetService("HttpService")
		if hs then
			local r=hs:RequestAsync({Url=u,Method="GET"})
			if r.Success then return r.Body end
		end
		return game:HttpGet(u)
	end)
	if ok and res and #res>100 then return res end
	return nil
end
-- Fetch full file (331KB, one shot - most executors handle it fine)
local code=fetch(B..C)
if not code then
	warn("[A]Fetch fail")
	return
end
-- Load and run
local fn,err=loadstring(code)
if fn then
	local ok,e2=pcall(fn)
	if not ok then warn("[A]"..tostring(e2)) end
else
	warn("[A]ls:"..tostring(err))
end
