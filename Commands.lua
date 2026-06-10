return {
	-- === MODÉRATION ===
	["m"]          = {Role="Modérateur",  Others=true,  Bio="Annonce globale avec nom et grade."},
	["sm"]         = {Role="Gérant",      Others=true,  Bio="Annonce système anonyme."},
	["warn"]       = {Role="Modérateur",  Others=true,  Bio="Avertissement rouge à l'écran."},
	["kick"]       = {Role="Modérateur",  Others=true,  Bio="Expulse un joueur."},
	["kickall"]    = {Role="Gérant",      Others=true,  Bio="Expulse tous les grades inférieurs."},
	["ban"]        = {Role="Modérateur",  Others=true,  Bio="Ban temporaire (en minutes)."},
	["pban"]       = {Role="Gérant",      Others=true,  Bio="Ban permanent."},
	["mute"]       = {Role="Modérateur",  Others=true,  Bio="Empêche de parler."},
	["unmute"]     = {Role="Modérateur",  Others=true,  Bio="Redonne la parole."},
	["jail"]       = {Role="Modérateur",  Others=true,  Bio="Enferme dans une prison."},
	["unjail"]     = {Role="Modérateur",  Others=true,  Bio="Libère de prison."},
	["freeze"]     = {Role="Modérateur",  Others=true,  Bio="Gèle sur place."},
	["thaw"]       = {Role="Modérateur",  Others=true,  Bio="Dégèle."},
	["freezeall"]  = {Role="Modérateur",  Others=true,  Bio="Gèle tous les joueurs."},
	["thawall"]    = {Role="Modérateur",  Others=true,  Bio="Dégèle tous les joueurs."},
	["shutdown"]   = {Role="Fondateur",   Others=true,  Bio="Ferme le serveur."},
	["loopkill"]   = {Role="Fondateur",   Others=true,  Bio="Tue en boucle."},
	["unloopkill"] = {Role="Fondateur",   Others=true,  Bio="Arrête loopkill."},
	["loopfling"]  = {Role="Fondateur",   Others=true,  Bio="Éjecte en boucle."},
	["unloopfling"]= {Role="Fondateur",   Others=true,  Bio="Arrête loopfling."},

	-- === TÉLÉPORTATION ===
	["tp"]         = {Role="Staffs",      Others=true,  Bio="Téléporte au joueur ciblé."},
	["bring"]      = {Role="Staffs",      Others=true,  Bio="Amène le joueur à toi."},
	["bringall"]   = {Role="Modérateur",  Others=true,  Bio="Amène tous les joueurs."},

	-- === COMBAT ===
	["kill"]       = {Role="VIP",         Others=false, Bio="Tue le joueur."},
	["slap"]       = {Role="Modérateur",  Others=true,  Bio="Gifle avec éjection."},
	["explode"]    = {Role="Staffs",      Others=true,  Bio="Fait exploser."},
	["freecandy"]  = {Role="Staffs",      Others=true,  Bio="Camion blanc qui kidnap le joueur et l'emmène loin (mort)."},
	["zap"]        = {Role="Staffs",      Others=true,  Bio="Éclair mortel depuis le ciel."},
	["fling"]      = {Role="Modérateur",  Others=true,  Bio="Éjecte violemment."},

	-- === EFFETS VISUELS ===
	["fire"]       = {Role="Modérateur",  Others=true,  Bio="Allume un feu."},
	["unfire"]     = {Role="Modérateur",  Others=true,  Bio="Éteint le feu."},
	["smoke"]      = {Role="Staffs",      Others=true,  Bio="Ajoute de la fumée."},
	["unsmoke"]    = {Role="Staffs",      Others=true,  Bio="Retire la fumée."},
	["sparkles"]   = {Role="Staffs",      Others=true,  Bio="Ajoute des étincelles."},
	["unsparkles"] = {Role="Staffs",      Others=true,  Bio="Retire les étincelles."},
	["blind"]      = {Role="Modérateur",  Others=true,  Bio="Écran noir."},
	["unblind"]    = {Role="Modérateur",  Others=true,  Bio="Redonne la vue."},
	["noob"]       = {Role="Modérateur",  Others=true,  Bio="Transforme en Noob."},
	["invisible"]  = {Role="Staffs",      Others=true,  Bio="Rend invisible."},
	["uninvisible"]= {Role="Staffs",      Others=true,  Bio="Rend visible (alias visible)."},
	["visible"]    = {Role="Staffs",      Others=true,  Bio="Rend visible."},
	["nv"]         = {Role="Staffs",      Others=false, Bio="ESP / Nightvision."},
	["unnv"]       = {Role="Staffs",      Others=false, Bio="Désactive ESP."},

	-- === CAPACITÉS ===
	["fly"]        = {Role="VIP",         Others=false, Bio="Active le vol."},
	["unfly"]      = {Role="VIP",         Others=false, Bio="Désactive le vol."},
	["noclip"]     = {Role="VIP",         Others=false, Bio="Active le noclip."},
	["unnoclip"]   = {Role="VIP",         Others=false, Bio="Désactive le noclip."},
	["speed"]      = {Role="VIP",         Others=false, Bio="Change la vitesse (défaut 16)."},
	["ws"]         = {Role="VIP",         Others=false, Bio="Alias speed."},
	["jump"]       = {Role="VIP",         Others=false, Bio="Change la hauteur de saut."},
	["jp"]         = {Role="VIP",         Others=false, Bio="Alias jump."},
	["jumppower"]  = {Role="VIP",         Others=false, Bio="Définit le JumpPower."},
	["heal"]       = {Role="VIP",         Others=false, Bio="Soigne complètement."},
	["healall"]    = {Role="Modérateur",  Others=true,  Bio="Soigne tous les joueurs."},
	["god"]        = {Role="VIP",         Others=false, Bio="Invincible (sans contour bleu)."},
	["ungod"]      = {Role="VIP",         Others=false, Bio="Retire l'invincibilité."},
	["godall"]     = {Role="Modérateur",  Others=true,  Bio="Invincible pour tous."},
	["ungodall"]   = {Role="Modérateur",  Others=true,  Bio="Retire pour tous."},
	["ff"]         = {Role="VIP",         Others=false, Bio="ForceField protecteur (anneau bleu)."},
	["unff"]       = {Role="VIP",         Others=false, Bio="Retire le ForceField."},
	["sit"]        = {Role="Modérateur",  Others=true,  Bio="Force à s'asseoir."},
	["unsit"]      = {Role="Modérateur",  Others=true,  Bio="Se relève."},
	["platform"]   = {Role="Staffs",      Others=true,  Bio="PlatformStand ON."},
	["unplatform"] = {Role="Staffs",      Others=true,  Bio="PlatformStand OFF."},
	["spin"]       = {Role="VIP",         Others=true,  Bio="Fait tourner."},
	["unspin"]     = {Role="VIP",         Others=true,  Bio="Arrête de tourner."},
	["trip"]       = {Role="Modérateur",  Others=true,  Bio="Fait trébucher le joueur."},

	-- === APPARENCE ===
	["size"]       = {Role="VIP",         Others=false, Bio="Change la taille."},
	["char"]       = {Role="VIP",         Others=false, Bio="Prend l'apparence d'un joueur."},
	["hat"]        = {Role="VIP",         Others=true,  Bio="Donne un chapeau via ID."},
	["unhat"]      = {Role="VIP",         Others=true,  Bio="Retire tous les chapeaux."},
	["anim"]       = {Role="VIP",         Others=true,  Bio="Joue une animation via ID."},
	["animation"]  = {Role="VIP",         Others=true,  Bio="Joue une animation via ID."},

	-- === OUTILS ===
	["sword"]      = {Role="VIP",         Others=true,  Bio="Épée classique Roblox."},
	["gear"]       = {Role="VIP",         Others=true,  Bio="Item via ID catalogue."},
	["btools"]     = {Role="Staffs",      Others=false, Bio="Outils de construction."},

	-- === TITRES ===
	["title"]      = {Role="VIP",         Others=true,  Bio="Titre blanc."},
	["titleb"]     = {Role="VIP",         Others=true,  Bio="Titre bleu."},
	["titler"]     = {Role="VIP",         Others=true,  Bio="Titre rouge."},
	["titleg"]     = {Role="VIP",         Others=true,  Bio="Titre vert."},
	["titley"]     = {Role="VIP",         Others=true,  Bio="Titre jaune."},
	["untitle"]    = {Role="VIP",         Others=true,  Bio="Enlève le titre."},

	-- === MONDE ===
	["time"]       = {Role="Staffs",      Others=true,  Bio="Change l'heure (0–24)."},
	["fog"]        = {Role="Staffs",      Others=true,  Bio="Change le brouillard."},
	["music"]      = {Role="Gérant",      Others=true,  Bio="Musique globale via ID."},
	["stopmusic"]  = {Role="Gérant",      Others=true,  Bio="Arrête la musique."},
	["gravity"]    = {Role="Gérant",      Others=true,  Bio="Change la gravité."},
	["ungravity"]  = {Role="Gérant",      Others=true,  Bio="Remet la gravité normale."},
	["ambient"]    = {Role="Staffs",      Others=true,  Bio="Change la couleur ambiante."},
	["clear"]      = {Role="Gérant",      Others=false, Bio="Nettoie la map."},
	["clr"]        = {Role="Gérant",      Others=false, Bio="Alias clear."},

	-- === SANTÉ ===
	["health"]     = {Role="Staffs",      Others=true,  Bio="Définit la vie exacte."},
	["maxhealth"]  = {Role="Staffs",      Others=true,  Bio="Définit la vie max."},

	-- === BANS ===
	["unban"]      = {Role="Modérateur",  Others=true,  Bio="Retire le ban d'un joueur."},

	-- === GRADES ===
	["permrank"]   = {Role="Fondateur",   Others=true,  Bio="Grade permanent."},
	["temprank"]   = {Role="Fondateur",   Others=true,  Bio="Grade temporaire (session)."},

	-- === EFFETS RIGOLOS (HD Admin like) ===
	["paint"]      = {Role="Modérateur",  Others=true,  Bio="Repeint tout le corps (ex: ;paint Bleu ou ;paint 255,0,0)."},
	["unpaint"]    = {Role="Modérateur",  Others=true,  Bio="Restaure la couleur originale du corps."},
	["aura"]       = {Role="Staffs",      Others=true,  Bio="Ajoute une aura de particules (ex: ;aura Rouge)."},
	["unaura"]     = {Role="Staffs",      Others=true,  Bio="Retire l'aura."},
	["disco"]      = {Role="Staffs",      Others=true,  Bio="Lumière disco multicolore qui tourne autour du joueur."},
	["undisco"]    = {Role="Staffs",      Others=true,  Bio="Arrête le disco."},
	["hh"]         = {Role="VIP",         Others=false, Bio="HipHeight: fait flotter (ex: ;hh 5)."},
	["hipheight"]  = {Role="VIP",         Others=false, Bio="Alias de hh."},
	["tools"]      = {Role="Modérateur",  Others=true,  Bio="Donne tous les outils du jeu (ServerStorage.Tools)."},
	["respawnall"] = {Role="Modérateur",  Others=true,  Bio="Respawn instantané de tous les joueurs."},
	["nuke"]       = {Role="Fondateur",   Others=true,  Bio="Explosion massive sur le joueur (rayon 80)."},
	["spook"]      = {Role="Staffs",      Others=true,  Bio="Jumpscare audio + flash rouge à l'écran."},
	["emotes"]     = {Role="VIP",         Others=false, Bio="Ouvre le panneau avec TOUS les émotes regroupés."},
	["zombify"]    = {Role="Staffs",      Others=true,  Bio="Transforme en zombie vert, propagation par toucher (mort/refresh = guérison)."},
	["unzombify"]  = {Role="Staffs",      Others=true,  Bio="Guérit le zombie."},

	-- === ÉQUIPES (Teams) ===
	["team"]       = {Role="Modérateur",  Others=true,  Bio="Met le joueur dans une équipe (ex: ;team Noob Rouge)."},
	["newteam"]    = {Role="Gérant",      Others=true,  Bio="Crée une équipe (ex: ;newteam Bleu 0,100,255)."},
	["removeteam"] = {Role="Gérant",      Others=true,  Bio="Supprime une équipe par son nom."},

	-- === CONTROL (prendre la place d'un joueur) ===
	["control"]    = {Role="Staffs",      Others=true,  Bio="Prend le contrôle du personnage du joueur."},
	["uncontrol"]  = {Role="Staffs",      Others=false, Bio="Libère le contrôle et revient à ton corps."},


	-- === UTILITAIRES ===
	["refresh"]    = {Role="Joueurs",     Others=false, Bio="Recharge le personnage."},
	["reset"]      = {Role="Joueurs",     Others=false, Bio="Alias refresh."},
	["re"]         = {Role="Joueurs",     Others=false, Bio="Alias refresh rapide."},
	["respawn"]    = {Role="Joueurs",     Others=false, Bio="Respawn immédiat."},
	["logs"]       = {Role="Modérateur",  Others=false, Bio="Historique des commandes."},
	["history"]    = {Role="Modérateur",  Others=false, Bio="Affiche l'historique détaillé des actions admin."},
	["undo"]       = {Role="Modérateur",  Others=false, Bio="Annule la dernière action (ban, rank...)."},
	["bubblechat"] = {Role="Modérateur",  Others=false, Bio="Panel force-chat."},
	["cmdbar2"]    = {Role="Modérateur",  Others=false, Bio="Barre de commandes rapide."},
	-- === ÉMOTES (VIP = soi-même, Modérateur+ = sur les autres) ===
	["wave"]       = {Role="VIP",         Others=true,  Bio="Signe de la main."},
	["dance"]      = {Role="VIP",         Others=true,  Bio="Danse basique."},
	["dance2"]     = {Role="VIP",         Others=true,  Bio="Danse style 2."},
	["dance3"]     = {Role="VIP",         Others=true,  Bio="Danse style 3."},
	["laugh"]      = {Role="VIP",         Others=true,  Bio="Rire."},
	["cheer"]      = {Role="VIP",         Others=true,  Bio="Acclamation."},
	["point"]      = {Role="VIP",         Others=true,  Bio="Pointe du doigt."},
	["salute"]     = {Role="VIP",         Others=true,  Bio="Salut militaire."},
	["shrug"]      = {Role="VIP",         Others=true,  Bio="Haussement d'épaules."},
	["hype"]       = {Role="VIP",         Others=true,  Bio="Hype dance."},
	["floss"]      = {Role="VIP",         Others=true,  Bio="Floss dance."},
	["shuffle"]    = {Role="VIP",         Others=true,  Bio="Shuffle dance."},
	["toprock"]    = {Role="VIP",         Others=true,  Bio="Top rock breakdance."},
	["shy"]        = {Role="VIP",         Others=true,  Bio="Timide."},
	["celebrate"]  = {Role="VIP",         Others=true,  Bio="Célébration."},
	["superhero"]  = {Role="VIP",         Others=true,  Bio="Pose super-héros."},
}
