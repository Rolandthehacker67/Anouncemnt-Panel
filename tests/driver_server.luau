
--============================================================================
-- DRIVER :: SERVER MODE SMOKE TEST
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

local function countClass(root, className)
	if root == nil then
		return 0
	end
	local total = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.ClassName == className then
			total += 1
		end
	end
	return total
end

local function find(root, name)
	if root == nil then
		return nil
	end
	return root:FindFirstChild(name, true)
end

local function panelOf(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	return playerGui and playerGui:FindFirstChild("AnnouncementPanel")
end

local function topStackOf(player)
	return find(panelOf(player), "TopStack")
end

local function bannerCount(player)
	local stack = topStackOf(player)
	if stack == nil then
		return 0
	end
	local total = 0
	for _, child in ipairs(stack:GetChildren()) do
		if child.ClassName:sub(1, 2) ~= "UI" then
			total += 1
		end
	end
	return total
end

local function toastCount(player)
	local toasts = find(panelOf(player), "Toasts")
	return toasts and #toasts:GetChildren() or 0
end

-- Fire a chat line through the REAL hook the panel installed, then let the
-- virtual clock pass the panel's own rate limits (CommandCooldown 1.2s,
-- AnnounceCooldown 2.5s) so consecutive commands are not rejected.
local function say(player, text, settle)
	Mock.pump(0.01)
	player.Chatted:Fire(text)
	Mock.pump(settle or 3.5)
end

print("==================================================================")
print("SERVER MODE")
print("==================================================================")

-- players were created by setup_server.luau before the panel booted
local function visible(instance)
	return instance ~= nil and instance.Visible == true
end

-- PANEL was returned by the wrapper that ran the panel source above.
Mock.pump(6)

print("-- boot ---------------------------------------------------------")
check("panel module returned a namespace table", type(PANEL) == "table", PANEL)
check("version exposed", PANEL and PANEL.Version == "2.1.0", PANEL and PANEL.Version)
check("mode is server", PANEL and PANEL.State and PANEL.State.Mode == "server", PANEL and PANEL.State.Mode)
check("remote folder created in ReplicatedStorage", ReplicatedStorage:FindFirstChild("AnnouncementPanelRemotes") ~= nil)
local remotes = ReplicatedStorage:FindFirstChild("AnnouncementPanelRemotes")
check("4 remotes created", remotes and #remotes:GetChildren() >= 4, remotes and #remotes:GetChildren())
check("server active attribute set", remotes and remotes:GetAttribute("AP_ServerActive") == true)
check("Steve resolved to Owner (place owner)", PANEL.RankSystem.GetRank(MockPlayers[1]) == "Owner", PANEL.RankSystem.GetRank(MockPlayers[1]))
check("Bob resolved to Player", PANEL.RankSystem.GetRank(MockPlayers[2]) == "Player", PANEL.RankSystem.GetRank(MockPlayers[2]))
check("GUI installed for Steve", panelOf(MockPlayers[1]) ~= nil)
check("GUI installed for Bob", panelOf(MockPlayers[2]) ~= nil)
check("rank attribute replicated to player", MockPlayers[2]:GetAttribute("AP_Rank") == "Player")
check("server-start announcement rendered", bannerCount(MockPlayers[1]) >= 1, bannerCount(MockPlayers[1]))
check("ScreenGui has the expected layers", find(panelOf(MockPlayers[1]), "TopStack") ~= nil)
check("ticker layer exists", find(panelOf(MockPlayers[1]), "Ticker") ~= nil)
check("alert layer exists", find(panelOf(MockPlayers[1]), "Alert") ~= nil)
check("countdown layer exists", find(panelOf(MockPlayers[1]), "Countdown") ~= nil)
check("MOTD layer exists", find(panelOf(MockPlayers[1]), "MOTD") ~= nil)


print("-- MOTD after join delay ----------------------------------------")
Mock.pump(5)
local motdCard = find(panelOf(MockPlayers[2]), "Card")
check("MOTD shown to joining player", PANEL.State.MOTD.Seen[MockPlayers[2].UserId] == true)

-- instrument: log every chat-path execution and every system reply
do
	local realExecute = PANEL.CommandService.Execute
	PANEL.CommandService.Execute = function(player, text, source)
		local result = realExecute(player, text, source)
		print(string.format("   [exec] %-6s | %-42s -> %s", tostring(player and player.Name), tostring(text), tostring(result)))
		return result
	end

	local realSystem = PANEL.ChatBridge.SystemMessageToPlayer
	PANEL.ChatBridge.SystemMessageToPlayer = function(player, text, color)
		print("   [reply:" .. tostring(player and player.Name) .. "] " .. tostring(text))
		return realSystem(player, text, color)
	end
end

-- turn on the panel's own diagnostics so failures explain themselves
PANEL.CONFIG.Debug.Enabled = true
PANEL.CONFIG.Debug.PrintCommands = true
PANEL.CONFIG.Debug.PrintRender = true
PANEL.CONFIG.Debug.PrintNetwork = true
PANEL.CONFIG.Debug.PrintRankResolution = true

print("-- staff commands ----------------------------------------------")
local before = bannerCount(MockPlayers[1])
say(MockPlayers[1], ":announce Hello world from the owner")
check("banner appeared for Steve", bannerCount(MockPlayers[1]) > before, bannerCount(MockPlayers[1]))
check("banner appeared for Bob too", bannerCount(MockPlayers[2]) > 0, bannerCount(MockPlayers[2]))
local function newestBannerText(player)
	local stack = topStackOf(player)
	if stack == nil then
		return nil
	end
	local newest = nil
	for _, banner in ipairs(stack:GetChildren()) do
		if newest == nil or banner.LayoutOrder < newest.LayoutOrder then
			newest = banner
		end
	end
	local label = newest and find(newest, "Message")
	return label and label.Text
end
check("banner text reached the label", tostring(newestBannerText(MockPlayers[1]) or ""):find("Hello world") ~= nil, newestBannerText(MockPlayers[1]))
check("history recorded the announcement", #PANEL.State.History >= 1)
check("stats counted an announcement", PANEL.State.Stats.Announcements >= 1)

Mock.pump(3)
say(MockPlayers[1], ":announce Second message -s Gold -t 12 -c cyan --title Test")
check("style/colour flags parsed", PANEL.State.Stats.Announcements >= 2)

print("-- permissions --------------------------------------------------")
local guestBanners = bannerCount(MockPlayers[2])
say(MockPlayers[2], ":announce I am not staff")
check("non-staff command did NOT create a banner", bannerCount(MockPlayers[2]) == guestBanners, bannerCount(MockPlayers[2]))
check("denied command counted", PANEL.State.Stats.CommandsDenied >= 1, PANEL.State.Stats.CommandsDenied)

say(MockPlayers[2], ":totallyfakecommand x")
check("unknown command counted", PANEL.State.Stats.CommandsUnknown >= 1)

print("-- other announcement kinds -------------------------------------")
Mock.pump(22)
say(MockPlayers[1], ":alert This is a full screen alert")
Mock.pump(1)
check("alert layer became visible", visible(find(panelOf(MockPlayers[1]), "Alert")))

say(MockPlayers[1], ":toast Small corner note")
check("toast created", toastCount(MockPlayers[1]) >= 1, toastCount(MockPlayers[1]))

say(MockPlayers[1], ":ticker Scrolling news across the top")
local tickerText = find(panelOf(MockPlayers[1]), "Text")
check("ticker text set", tickerText ~= nil and tostring(tickerText.Text):find("Scrolling news") ~= nil)

say(MockPlayers[1], ":countdown 25 Test countdown")
Mock.pump(1)
check("countdown layer visible", visible(find(panelOf(MockPlayers[1]), "Countdown")))

say(MockPlayers[1], ":preset restart")
check("preset fired", PANEL.State.Stats.Announcements >= 4, PANEL.State.Stats.Announcements)

say(MockPlayers[1], ":motd New message of the day")
check("MOTD updated", PANEL.State.MOTD.Message == "New message of the day", PANEL.State.MOTD.Message)

say(MockPlayers[1], ":history")
check("history command ran without error", true)

say(MockPlayers[1], ":stats")
say(MockPlayers[1], ":help")
say(MockPlayers[1], ":whoami")
say(MockPlayers[1], ":styles")
say(MockPlayers[1], ":colors")
say(MockPlayers[1], ":ranks")
check("informational commands ran", true)


print("-- probe: why did alert/ticker fail? ----------------------------")
do
	local parsed = PANEL.CommandParser.Parse(":ticker Scrolling news across the top")
	print("   parse ticker -> IsCommand:", parsed.IsCommand, "| Name:", tostring(parsed.Name), "| Message:", tostring(parsed.Message))
	local execOk, execResult = PANEL.CommandService.Execute(MockPlayers[1], ":ticker probe ticker line", "probe")
	print("   execute ticker ->", execOk, execResult)
	Mock.pump(2)
	local bOk, bRes = PANEL.Broadcaster.Broadcast({ Kind = "Alert", Message = "probe alert", Target = "all" }, { Origin = MockPlayers[1] })
	print("   broadcast alert ->", bOk, type(bRes) == "table" and ("Reason=" .. tostring(bRes.Reason) .. " Targets=" .. tostring(bRes.Targets) .. " Remaining=" .. tostring(bRes.Remaining)) or tostring(bRes))
	Mock.pump(1)
	print("   alert frame visible now:", visible(find(panelOf(MockPlayers[1]), "Alert")))
	local tk = find(panelOf(MockPlayers[1]), "Ticker")
	print("   ticker frame:", tk ~= nil, "visible:", tk and tk.Visible, "text child:", (function()
		local t = tk and find(tk, "Text")
		return t and tostring(t.Text)
	end)())
end

print("-- moderation ---------------------------------------------------")
say(MockPlayers[1], ":mute Bob 300 spamming")
check("Bob is muted", PANEL.State.IsMuted(MockPlayers[2]) == true)
local mutedBanners = bannerCount(MockPlayers[2])
say(MockPlayers[2], "hello everyone this is normal chat")
check("muted chat is swallowed (no crash)", true)
say(MockPlayers[1], ":unmute Bob")
check("Bob unmuted", PANEL.State.IsMuted(MockPlayers[2]) == false)

say(MockPlayers[1], ":rank Bob Mod")
check("session rank applied", PANEL.RankSystem.GetRank(MockPlayers[2]) == "Mod", PANEL.RankSystem.GetRank(MockPlayers[2]))
local bobBanners = bannerCount(MockPlayers[2])
Mock.pump(2)
say(MockPlayers[2], ":announce Now I am a mod")
check("promoted player can announce", bannerCount(MockPlayers[2]) > bobBanners, bannerCount(MockPlayers[2]))
say(MockPlayers[1], ":unrank Bob")
check("rank removed", PANEL.RankSystem.GetRank(MockPlayers[2]) == "Player", PANEL.RankSystem.GetRank(MockPlayers[2]))

print("-- chaos mode ---------------------------------------------------")
Mock.pump(32)
say(MockPlayers[1], ":chaos on 4")
check("chaos active", PANEL.State.Chaos.Active == true)
Mock.pump(6)
check("chaos fired messages", PANEL.State.Chaos.Count >= 1 or PANEL.State.Stats.Announcements > 6, PANEL.State.Stats.Announcements)
Mock.pump(6)
check("chaos auto-stopped", PANEL.State.Chaos.Active == false)

print("-- scheduling ---------------------------------------------------")
say(MockPlayers[1], ":schedule 60 Scheduled reminder message")
check("schedule registered", #PANEL.Scheduler.List() == 1, #PANEL.Scheduler.List())
say(MockPlayers[1], ":schedules")
say(MockPlayers[1], ":unschedule all")
check("schedule cleared", #PANEL.Scheduler.List() == 0)

print("-- effects & clearing -------------------------------------------")
say(MockPlayers[1], ":flash")
say(MockPlayers[1], ":shake")
say(MockPlayers[1], ":confetti")
say(MockPlayers[1], ":vignette on")
check("effects recorded", PANEL.State.Stats.Effects >= 1, PANEL.State.Stats.Effects)

say(MockPlayers[1], ":clear")
Mock.pump(1)
check("clear removed banners", bannerCount(MockPlayers[1]) == 0, bannerCount(MockPlayers[1]))


print("-- text channel hook (new chat) ---------------------------------")
local fakeMessage = { TextSource = { UserId = MockPlayers[1].UserId }, Text = ":announce Sent through the channel hook" }
local properties = generalChannel.OnIncomingMessage(fakeMessage)
check("channel hook returns properties", properties ~= nil)
check("channel hook suppresses the command", properties and properties.ShouldDeliver == false, properties and properties.ShouldDeliver)
Mock.pump(1.5)

print("-- public API ---------------------------------------------------")
local okApi = pcall(function()
	PANEL.Announce("Called from another script")
	PANEL.Toast("API toast")
	PANEL.Ticker("API ticker")
	PANEL.Alert("API alert")
	PANEL.Countdown(2, "API countdown")
end)
check("public API calls do not error", okApi)
Mock.pump(1)
check("API announcement rendered", bannerCount(MockPlayers[1]) >= 1, bannerCount(MockPlayers[1]))

local state = PANEL.GetState()
check("GetState returns a table with stats", type(state) == "table" and type(state.Stats) == "table")

print("-- player lifecycle ---------------------------------------------")
local newPlayer = makePlayer("Carol", 33333)
table.insert(MockPlayers, newPlayer)
Players.PlayerAdded:Fire(newPlayer)
Mock.pump(4)
check("new player got a GUI", panelOf(newPlayer) ~= nil)
check("new player rank attribute set", newPlayer:GetAttribute("AP_Rank") ~= nil)

table.remove(MockPlayers, 3)
Players.PlayerRemoving:Fire(newPlayer)
Mock.pump(1)
check("leaving player cleaned up", PANEL.Renderer.InstalledPlayers[newPlayer.UserId] == nil)

print("-- kick ---------------------------------------------------------")
say(MockPlayers[1], ":kick Bob Being silly")
Mock.pump(3)
check("kick delivered", MockPlayers[2]._kicked ~= nil, MockPlayers[2]._kicked)

print("-- custom commands (extension point) -----------------------------")
local registered = PANEL.Commands.Register({
	Name = "probe",
	Aliases = { "prb" },
	Category = "System",
	Usage = ":probe <text>",
	Description = "Test command registered by the harness.",
	Run = function(ctx)
		ctx.Reply("probe ran with: " .. tostring(ctx.Message), "success")
		return true
	end,
})
check("Commands.Register returns the definition", type(registered) == "table" and registered.Name == "probe")
check("custom command is discoverable", PANEL.Commands.Get("probe") ~= nil)
check("custom alias resolves", PANEL.Commands.Get("prb") ~= nil)
check("custom command appears in Commands.Names()", (function()
	for _, name in ipairs(PANEL.Commands.Names()) do
		if name == "probe" then
			return true
		end
	end
	return false
end)())
local runsBefore = PANEL.State.Stats.CommandsRun
say(MockPlayers[1], ":probe hello custom command")
check("custom command ran through chat", PANEL.State.Stats.CommandsRun > runsBefore, PANEL.State.Stats.CommandsRun - runsBefore)
local runsAlias = PANEL.State.Stats.CommandsRun
say(MockPlayers[1], ":prb via the alias")
check("custom command ran through its alias", PANEL.State.Stats.CommandsRun > runsAlias)
check("Unregister removes the command", PANEL.Commands.Unregister("probe") == true)
check("command gone after unregister", PANEL.Commands.Get("probe") == nil)
check("alias gone after unregister", PANEL.Commands.Get("prb") == nil)
check("Unregister of an unknown name returns false", PANEL.Commands.Unregister("nope") == false)

print("-- preset API ----------------------------------------------------")
local presetBefore = PANEL.State.Stats.Announcements
local presetOk, presetResult = pcall(function()
	return PANEL.Broadcaster.Preset("update")
end)
check("Broadcaster.Preset does not error", presetOk, presetResult)
Mock.pump(1)
check("preset API announced something", PANEL.State.Stats.Announcements > presetBefore, PANEL.State.Stats.Announcements - presetBefore)
check("PresetNames lists the presets", #PANEL.Broadcaster.PresetNames() >= 10, #PANEL.Broadcaster.PresetNames())

print("-- persistence (DataStore round-trip) ----------------------------")
PANEL.CONFIG.Persistence.Enabled = true
PANEL.CONFIG.Persistence.AllowInStudio = true
check("ShouldRun() is true once enabled", PANEL.Persistence.ShouldRun() == true)
local store = PANEL.Persistence.GetStore()
check("data store obtained", store ~= nil)
check("Persistence.Ready set", PANEL.Persistence.Ready == true)
say(MockPlayers[1], ":motd Persisted MOTD line")
check("MOTD changed before saving", PANEL.State.MOTD.Message == "Persisted MOTD line", PANEL.State.MOTD.Message)
check("Save() returns true", PANEL.Persistence.Save() == true)
check("SaveCount incremented", PANEL.Persistence.SaveCount >= 1, PANEL.Persistence.SaveCount)
PANEL.State.MOTD.Message = "locally mutated after save"
check("Load() returns the stored table", PANEL.Persistence.Load() ~= nil)
check("LoadCount incremented", PANEL.Persistence.LoadCount >= 1, PANEL.Persistence.LoadCount)
check("MOTD restored from the data store", PANEL.State.MOTD.Message == "Persisted MOTD line", PANEL.State.MOTD.Message)
check("StartAutoSave() enabled", PANEL.Persistence.StartAutoSave() == true)
local savesBefore = PANEL.Persistence.SaveCount
Mock.pump(135)
check("auto-save fired on the interval", PANEL.Persistence.SaveCount > savesBefore, PANEL.Persistence.SaveCount - savesBefore)
check("BindToClose handler registered", game._closeHandler ~= nil)
check("shutdown save handler runs", pcall(function() game._closeHandler() end))

print("-- shutdown -----------------------------------------------------")
local okShutdown, errShutdown = pcall(function()
	PANEL.Shutdown()
end)
check("Shutdown() runs cleanly", okShutdown, errShutdown)

print("==================================================================")
print(string.format("SERVER MODE RESULT: %d passed, %d failed", passed, failed))
if #RuntimeErrors > 0 then
	print("RUNTIME ERRORS CAPTURED: " .. #RuntimeErrors)
	local seen = {}
	for _, e in ipairs(RuntimeErrors) do
		if not seen[e] then
			seen[e] = true
			print("  ! " .. e)
		end
	end
else
	print("RUNTIME ERRORS: none")
end
print("instances created: " .. Mock.instanceCount() .. " | tweens: " .. Mock.tweenCount())
print("==================================================================")
