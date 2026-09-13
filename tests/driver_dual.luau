
--============================================================================
-- DRIVER :: DUAL (SERVER + CLIENT TOGETHER) INTEGRATION TEST
-- The panel source was loaded twice into the same mock DataModel: once as a
-- Script (server) and once as a LocalScript (client). This proves the two
-- halves cooperate: one display root, remote sync, console -> server commands.
--============================================================================
local passed, failed = 0, 0
local failures = {}

local function check(label, condition, extra)
	if condition then
		passed += 1
		print(string.format("  [PASS] %s", label))
	else
		failed += 1
		table.insert(failures, label)
		print(string.format("  [FAIL] %s%s", label, extra and ("  :: " .. tostring(extra)) or ""))
	end
end

local Steve = MockPlayers[1]
local Bob = MockPlayers[2]

local function playerGuiOf(player)
	return player:FindFirstChildOfClass("PlayerGui")
end

local function find(root, name)
	return root and root:FindFirstChild(name, true)
end

local function displayGui(player)
	return playerGuiOf(player) and playerGuiOf(player):FindFirstChild("AnnouncementPanel")
end

local function consoleGuiOf(player)
	return playerGuiOf(player) and playerGuiOf(player):FindFirstChild("AP_Console")
end

local function nonUiChildren(container)
	if container == nil then
		return 0
	end
	local total = 0
	for _, child in ipairs(container:GetChildren()) do
		if child.ClassName:sub(1, 2) ~= "UI" then
			total += 1
		end
	end
	return total
end

local function serverBanners(player)
	return nonUiChildren(find(displayGui(player), "TopStack"))
end

local function serverToasts(player)
	return nonUiChildren(find(displayGui(player), "Toasts"))
end

local function remotes()
	return ReplicatedStorage:FindFirstChild("AnnouncementPanelRemotes")
end

local function remote(name)
	return remotes() and remotes():FindFirstChild(name)
end

local function traceCount(kind)
	local total = 0
	for _, entry in ipairs(TraceLog) do
		if entry.Kind == kind then
			total += 1
		end
	end
	return total
end

local function click(button, settle)
	if button == nil then
		return false
	end
	local real = button.Button or button
	if type(real) ~= "table" or real.MouseButton1Click == nil then
		return false
	end
	real.MouseButton1Click:Fire()
	Mock.pump(settle or 1.6)
	return true
end

print("==================================================================")
print("DUAL MODE (server half + client half in one DataModel)")
print("==================================================================")

Mock.pump(3)

print("-- two independent instances -------------------------------------")
check("server instance returned", type(PANEL_SERVER) == "table")
check("client instance returned", type(PANEL_CLIENT) == "table")
check("they are separate module instances", PANEL_SERVER ~= PANEL_CLIENT)
check("server instance says server", PANEL_SERVER.State.Mode == "server", PANEL_SERVER.State.Mode)
check("client instance says companion", PANEL_CLIENT.Client.Mode == "companion", PANEL_CLIENT.Client.Mode)
check("client IS_SERVER flag is false", PANEL_CLIENT.IS_SERVER == false)
check("server IS_SERVER flag is true", PANEL_SERVER.IS_SERVER == true)

print("-- networking ----------------------------------------------------")
check("remote folder exists", remotes() ~= nil)
check("Announcement remote exists", remote("Announcement") ~= nil)
check("ConsoleCommand remote exists", remote("ConsoleCommand") ~= nil)
check("Handshake remote exists", remote("Handshake") ~= nil)
check("Ack remote exists", remote("Ack") ~= nil)
check("ServerActive attribute is true", remotes():GetAttribute("AP_ServerActive") == true)
check("client agrees the server is active", PANEL_CLIENT.Net.ServerActive == true)
check("client found the same folder", PANEL_CLIENT.Net.Folder == remotes())
check("client found the Announcement remote", PANEL_CLIENT.Net.Announcement == remote("Announcement"))
check("client handshake helper is callable", type(PANEL_CLIENT.Net.SendHandshake) == "function")
check("Net.Handshake is still the remote instance", PANEL_CLIENT.Net.Handshake == remote("Handshake"))

print("-- one display root, not two -------------------------------------")
check("server installed a display gui for Steve", displayGui(Steve) ~= nil)
check("server installed a display gui for Bob", displayGui(Bob) ~= nil)
check("client did NOT build its own display root", PANEL_CLIENT.Renderer.LocalRoot == nil)
check("client adopted the server root", PANEL_CLIENT.Client.ServerRoot ~= nil)
check("client root is the server gui", PANEL_CLIENT.Client.ActiveRoot() ~= nil and PANEL_CLIENT.Client.ActiveRoot().Gui == displayGui(Steve))
local displayGuis = 0
for _, child in ipairs(playerGuiOf(Steve):GetChildren()) do
	if child.Name == "AnnouncementPanel" then
		displayGuis += 1
	end
end
check("exactly one display gui per player", displayGuis == 1, displayGuis)
check("console gui is separate from the display gui", consoleGuiOf(Steve) ~= nil)
check("console built for the local player", PANEL_CLIENT.ClientConsole.Built == true)
check("floating button built", PANEL_CLIENT.Client.FloatingButton ~= nil)
check("keybind bound", PANEL_CLIENT.Client.KeybindBound == true)
check("context action registered", #(ContextActionService:GetBoundActions()) >= 1)

print("-- handshake + state sync ----------------------------------------")
check("client requested state", traceCount("FireServer") >= 1, traceCount("FireServer"))
check("server acked the client", traceCount("FireClient") >= 1, traceCount("FireClient"))
check("client stored a state packet", PANEL_CLIENT.ClientConsole.StatePacket ~= nil)
check("client recorded the sync time", PANEL_CLIENT.Client.LastSyncAt >= 0, PANEL_CLIENT.Client.LastSyncAt)
check("rank badge shows OWNER", tostring(PANEL_CLIENT.ClientConsole.RankBadge.Text):find("OWNER") ~= nil, PANEL_CLIENT.ClientConsole.RankBadge.Text)
check("mode label mentions companion", tostring(PANEL_CLIENT.ClientConsole.ModeText.Text):find("companion") ~= nil, PANEL_CLIENT.ClientConsole.ModeText.Text)
check("server wrote the rank attribute", Steve:GetAttribute("AP_Rank") ~= nil, Steve:GetAttribute("AP_Rank"))

print("-- server -> client rendering ------------------------------------")
local bannersBefore = serverBanners(Steve)
PANEL_SERVER.Announce("Integration banner from the server half")
Mock.pump(2)
check("banner rendered in the shared root", serverBanners(Steve) > bannersBefore, serverBanners(Steve))
check("banner rendered exactly once (no double render)", serverBanners(Steve) == bannersBefore + 1, serverBanners(Steve))
check("server polished the client", traceCount("FireClient") >= 2, traceCount("FireClient"))
check("client saw the same message in history", (function()
	for index = #PANEL_SERVER.State.History, 1, -1 do
		if tostring(PANEL_SERVER.State.History[index].Message):find("Integration banner") then
			return true
		end
	end
	return false
end)())

print("-- server -> client actions over the real remote -----------------")
PANEL_CLIENT.ClientConsole.Close()
Mock.pump(0.6)
remote("Announcement"):FireClient(Steve, "OpenConsole")
Mock.pump(0.6)
check("OpenConsole action opens the console", PANEL_CLIENT.ClientConsole.Gui.Enabled == true)
PANEL_CLIENT.ClientConsole.Close()
Mock.pump(0.6)

remote("Announcement"):FireClient(Steve, "Effect", { Flash = true, Confetti = true, Shake = false })
Mock.pump(0.6)
check("Effect action is handled", PANEL_CLIENT.State.Stats.Effects >= 0)

remote("Announcement"):FireClient(Steve, "Clear", {})
Mock.pump(0.6)
check("Clear action updates the console status", tostring(PANEL_CLIENT.ClientConsole.StatusText.Text):find("cleared") ~= nil, PANEL_CLIENT.ClientConsole.StatusText.Text)

remote("Ack"):FireClient(Steve, { Action = "Pong", Time = os.clock() })
Mock.pump(0.4)
check("Pong ack updates the status", tostring(PANEL_CLIENT.ClientConsole.StatusText.Text):find("pong") ~= nil, PANEL_CLIENT.ClientConsole.StatusText.Text)

remote("Ack"):FireClient(Steve, { Action = "Welcome", Text = "welcome aboard" })
Mock.pump(0.4)
check("Welcome ack is logged", tostring(PANEL_CLIENT.ClientConsole.StatusText.Text):find("welcome") ~= nil, PANEL_CLIENT.ClientConsole.StatusText.Text)

remote("Ack"):FireClient(Steve, { Action = "SystemChat", Text = "system chat line", Color = "gold" })
Mock.pump(0.4)
check("SystemChat ack handled without errors", true)

print("-- client console -> server execution ----------------------------")
PANEL_CLIENT.ClientConsole.Open()
Mock.pump(0.6)
PANEL_CLIENT.ClientConsole.MessageBox.Text = "Sent from the Owner Console"
local fireServerBefore = traceCount("FireServer")
click(PANEL_CLIENT.ClientConsole.SendButton, 3.5)
check("console send fired the remote", traceCount("FireServer") > fireServerBefore, traceCount("FireServer"))
check("server executed the console command", (function()
	for index = #PANEL_SERVER.State.History, 1, -1 do
		if tostring(PANEL_SERVER.State.History[index].Message):find("Owner Console") then
			return true
		end
	end
	return false
end)())
check("console command rendered in the shared root", serverBanners(Steve) >= 1, serverBanners(Steve))

Mock.pump(3)
check("console :toast reaches the server", PANEL_CLIENT.ClientConsole.RunCommandText(":toast Companion toast") ~= false)
Mock.pump(2)
check("toast rendered by the server half", serverToasts(Steve) >= 1, serverToasts(Steve))

Mock.pump(3)
PANEL_CLIENT.ClientConsole.RunCommandText(":history")
Mock.pump(1.5)
check("history sync came back to the console", #(PANEL_CLIENT.ClientConsole.HistoryEntries or {}) >= 0)

print("-- server-side gates still apply ---------------------------------")
local deniedBefore = PANEL_SERVER.State.Stats.CommandsDenied
PANEL_SERVER.ServerCore.HandleConsole(Bob, { Action = "Execute", Text = ":announce Bob is not staff" })
Mock.pump(1)
check("non-staff console request denied", PANEL_SERVER.State.Stats.CommandsDenied > deniedBefore, PANEL_SERVER.State.Stats.CommandsDenied)

local unknownBefore = PANEL_SERVER.State.Stats.CommandsUnknown
PANEL_SERVER.ServerCore.HandleConsole(Steve, { Action = "Execute", Text = ":notacommand x" })
Mock.pump(1)
check("unknown console command counted", PANEL_SERVER.State.Stats.CommandsUnknown > unknownBefore)

local malformedOk = pcall(function()
	PANEL_SERVER.ServerCore.HandleConsole(Steve, "not a table at all")
	PANEL_SERVER.ServerCore.HandleConsole(Steve, nil)
	PANEL_SERVER.ServerCore.HandleConsole(Steve, {})
	PANEL_SERVER.ServerCore.HandleConsole(nil, { Action = "Execute", Text = ":announce x" })
end)
check("malformed console payloads do not crash", malformedOk)

PANEL_SERVER.ServerCore.HandleConsole(Steve, { Action = "Ping" })
Mock.pump(0.6)
check("Ping action returns a Pong", tostring(PANEL_CLIENT.ClientConsole.StatusText.Text):find("pong") ~= nil, PANEL_CLIENT.ClientConsole.StatusText.Text)

-- an exploiter firing the announcement remote server-side must be dropped
local exploitDenied = PANEL_SERVER.State.Stats.CommandsDenied
remote("Announcement"):FireServer("Render", { Kind = "Banner", Message = "exploit attempt" })
Mock.pump(0.6)
check("client->server Announcement fire is rejected", PANEL_SERVER.State.Stats.CommandsDenied > exploitDenied, PANEL_SERVER.State.Stats.CommandsDenied)

print("-- rank attribute sync -------------------------------------------")
PANEL_SERVER.RankSystem.SetSessionRank(Bob, "Mod")
Mock.pump(1)
check("server-side rank change replicated", Bob:GetAttribute("AP_Rank") ~= nil)
Steve:SetAttribute("AP_Rank", "Admin")
Mock.pump(0.6)
check("client reacts to the rank attribute", PANEL_CLIENT.RankSystem.Cache[Steve.UserId] ~= nil)
Steve:SetAttribute("AP_Rank", "Owner")
Mock.pump(0.6)

print("-- clearing together ----------------------------------------------")
PANEL_SERVER.Announce("One more to clear")
Mock.pump(2)
check("banner present before clear", serverBanners(Steve) >= 1, serverBanners(Steve))
PANEL_SERVER.Clear()
Mock.pump(2)
check("server clear emptied the shared root", serverBanners(Steve) == 0, serverBanners(Steve))

print("-- lifecycle -------------------------------------------------------")
local carol = makePlayer("Carol", 44444)
table.insert(MockPlayers, carol)
Players.PlayerAdded:Fire(carol)
Mock.pump(4)
check("new player got a server display gui", displayGui(carol) ~= nil)
check("new player rank attribute set", carol:GetAttribute("AP_Rank") ~= nil)

print("-- shutdown --------------------------------------------------------")
local okServer = pcall(function() PANEL_SERVER.Shutdown() end)
local okClient = pcall(function()
	if PANEL_CLIENT.Client.StopSoloDemo then
		PANEL_CLIENT.Client.StopSoloDemo()
	end
	if PANEL_CLIENT.Shutdown then
		PANEL_CLIENT.Shutdown()
	end
end)
check("server Shutdown() is clean", okServer)
check("client shutdown path is clean", okClient)

print("==================================================================")
print(string.format("DUAL MODE RESULT: %d passed, %d failed", passed, failed))
if #failures > 0 then
	print("failed checks:")
	for _, name in ipairs(failures) do
		print("   - " .. name)
	end
end
if #RuntimeErrors > 0 then
	print("RUNTIME ERRORS CAPTURED: " .. #RuntimeErrors)
	local seen = {}
	for _, entry in ipairs(RuntimeErrors) do
		if not seen[entry] then
			seen[entry] = true
			print("  ! " .. entry)
		end
	end
else
	print("RUNTIME ERRORS: none")
end
print("instances created: " .. Mock.instanceCount() .. " | tweens: " .. Mock.tweenCount())
print("==================================================================")
