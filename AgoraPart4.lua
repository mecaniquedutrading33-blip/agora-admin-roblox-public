-- ============= CHAT COMMANDS =============
function _G.AgoraBuild_CHAT_COMMANDS()
-- ============= CHAT COMMANDS =============
-- Wrap dans IIFE avec paramètres pour éviter la limite d'upvalues (200)
do (function(_fly, _noclip, _esp, _fullbright, _zeroG, _localPlayer)
	_localPlayer.Chatted:Connect(function(msg)
		local m = msg:lower()
		if m == ";fly" then _fly.set(true)
		elseif m == ";unfly" then _fly.set(false)
		elseif m == ";noclip" then _noclip.set(true)
		elseif m == ";unnoclip" then _noclip.set(false)
		elseif m == ";esp" then _esp.enabled = true refreshESP()
		elseif m == ";unesp" then _esp.enabled = false clearESP()
		elseif m == ";fullbright" then _fullbright.set(true)
		elseif m == ";unfullbright" then _fullbright.set(false)
		elseif m == ";zerog" then _zeroG.set(true)
		elseif m == ";unzerog" then _zeroG.set(false)
		end
	end)
end)(flySwitch, noclipSwitch, espState, fullbrightSwitch, zeroGSwitch, LocalPlayer) end

updateLoad(0.95, "Finalisation...")
task.wait(0.05)
end

-- ============= CRÉDITS =============
function _G.AgoraBuild_CREDITS()
-- ============= CRÉDITS =============
do (function(_mainFrame)
	local credits = Instance.new("TextLabel")
	credits.Size = UDim2.new(1, 0, 0, 18)
	credits.Position = UDim2.new(0, 0, 1, -20)
	credits.BackgroundTransparency = 1
	credits.Text = "Agora Universelle"
	credits.Font = Enum.Font.GothamBold
	credits.TextSize = 11
	credits.TextColor3 = Color3.fromRGB(140, 140, 180)
	credits.Parent = _mainFrame
end)(mainFrame) end

-- BOOT SAFE 3 LAYERS:
-- Layer 1: reveal immédiat à 0.5s (filet de sécurité absolu)
-- Layer 2: reveal à 3s si pas encore visible (fallback)
-- Layer 3: switchTab après reveal (parse-time IIFE) + bootSequence call explicite
do (function(_pages, _switchTab)
	-- LAYER 1: reveal immédiat à 0.5s
	task.delay(0.5, function()
		pcall(function()
			if mainFrame and not mainFrame.Visible then
				mainFrame.Visible = true
			end
		end)
	end)
	-- LAYER 2: switchTab Joueurs
	pcall(function() _switchTab("Home") end)
		-- LAYER 3: fallback à 3s (au cas où)
		task.delay(3, function()
			pcall(function()
				if mainFrame and not mainFrame.Visible then
					mainFrame.Visible = true
				end
				if _pages and _pages["Home"] and not _pages["Home"].Visible then
					pcall(function() _switchTab("Home") end)
			end
		end)
	end)
end)(pages, switchTab) end

-- FALLBACK absolu: si l'intro n'a jamais révélé le panel, le forcer visible + onglet Joueurs après 5s
task.delay(5, function()
	pcall(function()
		if mainFrame and not mainFrame.Visible then
			warn("[AGORA] Fallback reveal: panel forcé visible")
			mainFrame.Visible = true
		end
		if pages and pages["Home"] and not pages["Home"].Visible then
				switchTab("Home")
		end
	end)
end)

-- Lancer l'intro cinéma si on veut (désactivée par défaut car elle bloque le fallback)
-- pcall(function() bootSequence(function()
-- 	pcall(function() mainFrame.Visible = true end)
-- 	switchTab("Joueurs")
-- end) end)

end
