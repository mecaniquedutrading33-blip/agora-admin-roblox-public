-- Agora Hub [UNIVERSELLE] - aiguilleur v40.68
-- Ce fichier n'embarque plus le hub : il charge la PARTIE 1 (AgoraUniverselleHub_p1.lua),
-- qui charge elle-meme la PARTIE 2. Le decoupage existe parce que Solara refuse les gros
-- fichiers (limite ~200 Ko par loadstring). L'ancien hub monolithique (v40.67) est retire :
-- il n'avait pas le bouton AUTO-TEST de l'onglet Remotes.
--
-- Compatibilite : l'ancien loader (AgoraUniverselleLoader.lua, v26) et tous les loadstrings
-- qui pointaient encore sur AgoraUniverselleHub.lua continuent de fonctionner et recoivent
-- desormais la v40.68 complete.
--
-- Marqueurs lus par le loader v26 (ne pas supprimer) :
--   entete : la ligne 1 de ce fichier
--   fin de fichier valide : end)(movePage, createSwitch,
--
-- Hote unique : la S. La liste est conservee (fallback si un jour un 2e hote revient).
-- ---------------------------------------------------------------------------------------
-- Historique de ce fichier :
--   v40.66 : derniere version monolithique connue avec bouton AUTO-TEST
--   v40.67 : decoupage p1 + p2
--   v40.68 : aiguilleur (ce fichier) + partie 2 servie par l'hote principal avec secours
-- ---------------------------------------------------------------------------------------

local HOSTS = {
	"https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-universelle",
}

local code
for _, base in ipairs(HOSTS) do
	for essai = 1, 2 do
		local url = base .. "?file=AgoraUniverselleHub_p1.lua&nocache=" .. tostring(tick())
			.. "&r=" .. tostring(math.random(100000, 999999))
		local ok, res = pcall(function() return game:HttpGet(url, true) end)
		if ok and type(res) == "string" and #res > 5000 then code = res break end
		task.wait(0.5)
	end
	if code then break end
end

if not code then
	warn("[AGORA] Aiguilleur : partie 1 injoignable sur les deux hotes")
	return
end

local fn, err = loadstring(code, "@AgoraUniverselleHub_p1")
if not fn then
	warn("[AGORA] Aiguilleur : partie 1 illisible - " .. tostring(err))
	return
end

local runOk, runErr = pcall(fn)
if not runOk then
	warn("[AGORA] Aiguilleur : erreur partie 1 - " .. tostring(runErr))
end
