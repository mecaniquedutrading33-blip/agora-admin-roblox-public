--[[
   ╔══════════════════════════════════════════════════════════════╗
   ║          AGORA ADMIN — Settings (à modifier par toi)         ║
   ║                                                                ║
   ║   Configure ton panel admin ici. Sauvegarde après chaque      ║
   ║   modification, puis lance ton jeu pour tester.               ║
   ║                                                                ║
   ║   Made by Vzlom_Emk (Emrk_GL)                                ║
   ╚══════════════════════════════════════════════════════════════╝
]]--

return {

	-- ════════════════════════════════════════════════════════════
	-- 🎮 PRÉFIXE DES COMMANDES CHAT
	-- ════════════════════════════════════════════════════════════
	-- La touche que tu dois taper avant chaque commande dans le chat.
	-- Par défaut: ";" (ex: ";kick joueur" pour kick).
	-- Tu peux mettre "/" ou "!" ou autre si tu préfères.

	["Prefix"] = ";",


	-- ════════════════════════════════════════════════════════════
	-- 👑 FONDATEURS (Owners du jeu — toi et tes co-fondateurs)
	-- ════════════════════════════════════════════════════════════
	-- Mets les UserIDs Roblox des fondateurs ici.
	-- Pour trouver ton UserID: va sur ton profil Roblox, le numéro
	-- dans l'URL c'est ton UserID.
	-- Exemple: https://www.roblox.com/users/123456789/profile → 123456789

	["Founders"] = {
		-- 123456789,                    -- Ton UserID Roblox
		-- 987654321,                    -- UserID de ton co-fondateur
	},

	["FounderNames"] = {
		-- "TonPseudoRoblox",            -- Mets le même pseudo que ci-dessus
		-- "PseudoCoFondateur",
	},


	-- ════════════════════════════════════════════════════════════
	-- 💎 GAMEPASS VIP (optionnel)
	-- ════════════════════════════════════════════════════════════
	-- Si tu as un Gamepass VIP qui donne accès à certaines commandes,
	-- mets son ID ici. Laisse 0 si tu n'en as pas.

	["VIP_Pass_ID"] = 0,                 -- ID de ton Gamepass VIP
	["VIP_Role_Name"] = "VIP",           -- Nom du grade VIP


	-- ════════════════════════════════════════════════════════════
	-- 🛡️ ANTI-CHEAT (contrôlé via Settings.lua)
	-- ════════════════════════════════════════════════════════════
	-- true  = AntiCheat actif (speed, fly, teleport...)
	-- false = AntiCheat complètement désactivé

	["AntiCheatEnabled"] = true,


	-- ════════════════════════════════════════════════════════════
	-- 🔔 WEBHOOK DISCORD (optionnel)
	-- ════════════════════════════════════════════════════════════
	-- Si tu veux recevoir les bug reports/feedback dans ton serveur
	-- Discord, crée un webhook dans un salon et colle l'URL ici.
	-- Sinon laisse vide ("").

	["WebhookURL"] = "",


	-- ════════════════════════════════════════════════════════════
	-- 👥 GRADES PERSONNALISÉS (Level 1 = le plus fort)
	-- ════════════════════════════════════════════════════════════
	-- Modifie les noms et couleurs si tu veux. Garde les 6 niveaux.

	["CustomRoles"] = {
		{Name = "Fondateur",  Level = 1, Color = Color3.fromRGB(52, 152, 219)},
		{Name = "Gérant",     Level = 2, Color = Color3.fromRGB(230, 126, 34)},
		{Name = "Staff",      Level = 3, Color = Color3.fromRGB(155, 89, 182)},
		{Name = "Modérateur", Level = 4, Color = Color3.fromRGB(135, 206, 250)},
		{Name = "VIP",        Level = 5, Color = Color3.fromRGB(241, 196, 15)},
		{Name = "Joueur",     Level = 6, Color = Color3.fromRGB(149, 165, 166)},
	}

}

--[[
   ╔══════════════════════════════════════════════════════════════╗
   ║   Une fois Settings configuré:                                ║
   ║   1. Sauvegarde dans Roblox Studio (Ctrl+S)                  ║
   ║   2. Lance ton jeu (Play / F5)                               ║
   ║   3. Tape ";cmds" dans le chat                               ║
   ║   4. Le panel Agora Admin s'ouvre = ça marche! 🎉            ║
   ╚══════════════════════════════════════════════════════════════╝
]]--
