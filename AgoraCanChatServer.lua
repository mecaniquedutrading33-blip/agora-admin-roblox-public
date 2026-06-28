-- AgoraCanChatServer.lua
-- Place ce Script dans ServerScriptService.
-- Il expose une RemoteFunction "AgoraCanChatRF" dans ReplicatedStorage
-- pour que le panel client sache VRAIMENT si deux joueurs peuvent parler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local rf = Instance.new("RemoteFunction")
rf.Name = "AgoraCanChatRF"
rf.Parent = ReplicatedStorage

rf.OnServerInvoke = function(player, targetUserId)
	local uid = tonumber(targetUserId)
	if not uid then return nil, "userId invalide" end
	if player.UserId == uid then return true, "self" end

	local ok, canTalk = pcall(function()
		return TextChatService:CanUsersChatAsync(player.UserId, uid)
	end)

	if ok then
		return canTalk, "server"
	else
		-- Fallback : si l'API échoue, on suppose true (chat activé) mais on signale le doute
		return nil, "erreur API"
	end
end
