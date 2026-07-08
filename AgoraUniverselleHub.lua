-- Agora Hub [UNIVERSELLE] - Bootstrap Loader
-- Charge Part 1 qui auto-charge Part 2 (split pour limite Solara 200KB)

local url = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle?file=AgoraUniverselleHub_p1.lua&nocache=" .. tick()
local ok, code = pcall(function()
    return game:HttpGet(url, true)
end)
if ok and code and #code > 100 then
    local fn, err = loadstring(code)
    if fn then
        fn()
    else
        warn("[AGORA] Bootstrap error: " .. tostring(err))
    end
else
    warn("[AGORA] Bootstrap fetch failed")
end
