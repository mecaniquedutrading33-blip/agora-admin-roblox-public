-- Agora Universelle Hub - Loader v26
-- 1 telechargement complet + garde anti-doublon + controle de fin de fichier + secours.
local H1="https://hlxbqtayotwdtspkrlol.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua"
local H2="https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub.lua"
local R="&_="..math.random(100000,999999)
local HEAD="-- Agora Hub [UNIVERSELLE]"
local TAIL="end)(movePage, createSwitch,"
local function fetch(u)
	local ok,res=pcall(function() return game:HttpGet(u) end)
	if ok and type(res)=="string" and #res>1000 then return res end
	return nil
end
local function clean(c)
	if not c then return nil end
	-- Si le serveur colle deux copies du fichier, on garde la premiere seulement.
	local second=string.find(c,HEAD,2,true)
	if second then c=string.sub(c,1,second-1) end
	if string.find(c,TAIL,1,true) then return c end
	return nil
end
local code
for _,h in ipairs({H1,H2}) do
	code=clean(fetch(h..R))
	if not code then
		-- Telechargement tronque : on reprend en 2 morceaux bornes.
		local p1=fetch(h.."&start=0&end=165000"..R)
		local p2=p1 and fetch(h.."&start=165001&end=400000"..R)
		if p1 and p2 then
			if string.find(p2,HEAD,1,true)==1 then p2=string.sub(p2,#p1+1) end
			code=clean(p1..p2)
		end
	end
	if code then break end
end
if not code then warn("[A]Fichier incomplet ou serveur injoignable") return end
local fn,err=loadstring(code)
if fn then
	local ok,e2=pcall(fn)
	if not ok then warn("[A]"..tostring(e2)) end
else
	warn("[A]ls:"..tostring(err))
end
