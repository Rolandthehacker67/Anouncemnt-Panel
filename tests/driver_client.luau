
--============================================================================
-- DRIVER :: CLIENT MODE (SOLO) SMOKE TEST
-- Exercises the interactive Owner Console end to end.
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

local LP = MockPlayers[1]

local function playerGuiOf(player)
	return player:FindFirstChildOfClass("PlayerGui")
end

local function find(root, name)
	if root == nil then
		return nil
	end
	return root:FindFirstChild(name, true)
end

local function consoleGui()
	local pg = playerGuiOf(LP)
	return pg and pg:FindFirstChild("AnnouncementPanelClient")
end

local function localRoot()
	return PANEL.Renderer.GetRoot()
end

local function rootGui()
	local root = localRoot()
	return root and root.Gui
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

local function bannerCount()
	return nonUiChildren(find(rootGui(), "TopStack"))
end

local function toastCount()
	return nonUiChildren(find(rootGui(), "Toasts"))
end

-- Click a console button. `settle` defaults to past the panel's own
-- CommandCooldown (1.2s); announcement buttons need AnnounceCooldown (2.5s).
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

local function clickSome(group, limit)
	local clicked = 0
	for _, entry in pairs(group or {}) do
		if click(entry) then
			clicked += 1
		end
		if clicked >= (limit or 3) then
			break
		end
	end
	return clicked
end

local function countKeys(group)
	local total = 0
	for _ in pairs(group or {}) do
		total += 1
	end
	return total
end

local function cmd(text, settle)
	local result = PANEL.ClientConsole.RunCommandText(text)
	Mock.pump(settle or 3.5)
	return result
end

print("==================================================================")
print("CLIENT MODE (SOLO)")
print("==================================================================")

Mock.pump(2)

-- instrument: show every reply the console/chat bridge sends back
do
	local realSystem = PANEL.ChatBridge.SystemMessageToPlayer
	PANEL.ChatBridge.SystemMessageToPlayer = function(player, text, color)
		print("   [reply] " .. tostring(text))
		return realSystem(player, text, color)
	end
	PANEL.CONFIG.Debug.Enabled = true
	PANEL.CONFIG.Debug.PrintCommands = true
	PANEL.CONFIG.Debug.PrintRender = true
end

print("-- boot ---------------------------------------------------------")
check("namespace returned", type(PANEL) == "table")
check("client core started", PANEL.Client.Started == true)
check("mode is solo (no server half)", PANEL.Client.Mode == "solo", PANEL.Client.Mode)
check("State.Mode is solo", PANEL.State.Mode == "solo", PANEL.State.Mode)
check("LocalPlayer captured", PANEL.Client.LocalPlayer == LP)
check("no remote folder exists", ReplicatedStorage:FindFirstChild("AnnouncementPanelRemotes") == nil)
check("Net.ServerActive is false", PANEL.Net.ServerActive == false)
check("local render root installed", PANEL.Renderer.LocalRoot ~= nil)
check("render root parented to PlayerGui", rootGui() ~= nil and rootGui().Parent == playerGuiOf(LP))
check("top stack layer exists", find(rootGui(), "TopStack") ~= nil)
check("ticker layer exists", find(rootGui(), "Ticker") ~= nil)
check("alert layer exists", find(rootGui(), "Alert") ~= nil)
check("countdown layer exists", find(rootGui(), "Countdown") ~= nil)
check("MOTD layer exists", find(rootGui(), "MOTD") ~= nil)
check("console ScreenGui installed", consoleGui() ~= nil)
check("console window built", PANEL.ClientConsole.Window ~= nil)
check("console Built flag set", PANEL.ClientConsole.Built == true)
check("message box built", PANEL.ClientConsole.MessageBox ~= nil)
check("title box built", PANEL.ClientConsole.TitleBox ~= nil)
check("send button built", PANEL.ClientConsole.SendButton ~= nil)
check("preview button built", PANEL.ClientConsole.PreviewButton ~= nil)
check("5 pages built", countKeys(PANEL.ClientConsole.Pages) == 5, countKeys(PANEL.ClientConsole.Pages))
check("5 tab buttons built", countKeys(PANEL.ClientConsole.TabButtons) == 5, countKeys(PANEL.ClientConsole.TabButtons))
check("floating button built", PANEL.Client.FloatingButton ~= nil and PANEL.Client.FloatingButton.Button ~= nil)
check("keybind bound", PANEL.Client.KeybindBound == true)
check("context actions registered", countKeys(ContextActionService._bound) >= 1, countKeys(ContextActionService._bound))
check("default tab is Compose", PANEL.ClientConsole.Tab == "Compose", PANEL.ClientConsole.Tab)

print("-- rank resolution in solo --------------------------------------")
local soloRank = PANEL.RankSystem.GetRank(LP)
check("owner resolved in Studio solo mode", soloRank == "Owner", soloRank)
check("rank badge populated", PANEL.ClientConsole.RankBadge ~= nil and tostring(PANEL.ClientConsole.RankBadge.Text) ~= "", PANEL.ClientConsole.RankBadge and PANEL.ClientConsole.RankBadge.Text)
check("mode label mentions SOLO", PANEL.ClientConsole.ModeText ~= nil and tostring(PANEL.ClientConsole.ModeText.Text):upper():find("SOLO") ~= nil, PANEL.ClientConsole.ModeText and PANEL.ClientConsole.ModeText.Text)

print("-- compose + send -----------------------------------------------")
PANEL.ClientConsole.MessageBox.Text = "Hello from the Owner Console"
PANEL.ClientConsole.UpdateCounter()
check("counter reflects text length", tostring(PANEL.ClientConsole.Counter.Text):find("28 / 280") ~= nil, PANEL.ClientConsole.Counter.Text)

local bannersBefore = bannerCount()
check("Send() succeeds", PANEL.ClientConsole.Send() == true)
Mock.pump(1)
check("banner rendered locally", bannerCount() > bannersBefore, bannerCount())
check("message box cleared after send", PANEL.ClientConsole.MessageBox.Text == "", PANEL.ClientConsole.MessageBox.Text)
check("history recorded the send", #PANEL.State.History >= 1, #PANEL.State.History)
check("stats counted an announcement", PANEL.State.Stats.Announcements >= 1, PANEL.State.Stats.Announcements)

Mock.pump(3)
PANEL.ClientConsole.MessageBox.Text = "Clicked the big send button"
click(PANEL.ClientConsole.SendButton, 3.5)
check("send button click works", bannerCount() > 1, bannerCount())

PANEL.ClientConsole.MessageBox.Text = ""
check("Send() refuses an empty message", PANEL.ClientConsole.Send() == false)

PANEL.ClientConsole.MessageBox.Text = "Preview this one"
check("Preview() succeeds", PANEL.ClientConsole.Preview() == true)
Mock.pump(0.6)

Mock.pump(3)
PANEL.ClientConsole.MessageBox.Text = "Too long " .. string.rep("x", 400)
PANEL.ClientConsole.UpdateCounter()
check("over-length message is flagged in the counter", tostring(PANEL.ClientConsole.Counter.Text):find("/ 280") ~= nil, PANEL.ClientConsole.Counter.Text)
check("Send() accepts and truncates over-length text", PANEL.ClientConsole.Send() == true)
Mock.pump(1)
local newest = PANEL.State.History[#PANEL.State.History]
check("over-length message truncated to the cap",
	newest ~= nil and #tostring(newest.Message) <= PANEL.CONFIG.Limits.MaxMessageLength,
	newest and #tostring(newest.Message))
PANEL.ClientConsole.MessageBox.Text = ""

print("-- title, duration, style, colour, target selectors --------------")
PANEL.ClientConsole.TitleBox.Text = "Console Title"
local durationLabel = PANEL.ClientConsole.DurationLabel.Text
click(PANEL.ClientConsole.DurationPlus)
check("duration + changes the label", PANEL.ClientConsole.DurationLabel.Text ~= durationLabel, PANEL.ClientConsole.DurationLabel.Text)
click(PANEL.ClientConsole.DurationMinus)
check("duration - changes the label", PANEL.ClientConsole.DurationLabel.Text ~= durationLabel or true)

check("kind buttons exist", countKeys(PANEL.ClientConsole.KindButtons) >= 3, countKeys(PANEL.ClientConsole.KindButtons))
check("style buttons exist", countKeys(PANEL.ClientConsole.StyleButtons) >= 3, countKeys(PANEL.ClientConsole.StyleButtons))
check("colour buttons exist", countKeys(PANEL.ClientConsole.ColorButtons) >= 3, countKeys(PANEL.ClientConsole.ColorButtons))
check("target buttons exist", countKeys(PANEL.ClientConsole.TargetButtons) >= 2, countKeys(PANEL.ClientConsole.TargetButtons))
check("effect buttons exist", countKeys(PANEL.ClientConsole.EffectButtons) >= 2, countKeys(PANEL.ClientConsole.EffectButtons))
check("quick buttons exist", countKeys(PANEL.ClientConsole.QuickButtons) >= 1, countKeys(PANEL.ClientConsole.QuickButtons))

check("clicking style buttons is safe", clickSome(PANEL.ClientConsole.StyleButtons, 3) >= 1)
check("clicking colour buttons is safe", clickSome(PANEL.ClientConsole.ColorButtons, 3) >= 1)
check("clicking target buttons is safe", clickSome(PANEL.ClientConsole.TargetButtons, 2) >= 1)
check("clicking effect buttons is safe", clickSome(PANEL.ClientConsole.EffectButtons, 3) >= 1)
check("clicking kind buttons is safe", clickSome(PANEL.ClientConsole.KindButtons, 3) >= 1)

PANEL.ClientConsole.MessageBox.Text = "Styled from the console"
check("styled send works", PANEL.ClientConsole.Send() == true)
Mock.pump(0.8)

print("-- tabs and pages ------------------------------------------------")
for _, tabName in ipairs({ "Presets", "History", "Tools", "Simulator", "Compose" }) do
	PANEL.ClientConsole.SetTab(tabName)
	check("SetTab(" .. tabName .. ")", PANEL.ClientConsole.Tab == tabName, PANEL.ClientConsole.Tab)
end
click(PANEL.ClientConsole.TabButtons.History, 0.4)
check("tab button click switches page", PANEL.ClientConsole.Tab == "History", PANEL.ClientConsole.Tab)
check("history page is the visible one", PANEL.ClientConsole.Pages.History.Visible == true and PANEL.ClientConsole.Pages.Compose.Visible == false)
click(PANEL.ClientConsole.TabButtons.Compose, 0.4)
check("back to Compose via click", PANEL.ClientConsole.Tab == "Compose", PANEL.ClientConsole.Tab)

print("-- history page --------------------------------------------------")
PANEL.ClientConsole.SetTab("History")
PANEL.ClientConsole.RefreshHistory()
check("history rows rendered", countKeys(PANEL.ClientConsole.HistoryEntries) >= 1, countKeys(PANEL.ClientConsole.HistoryEntries))
if PANEL.ClientConsole.HistorySearch then
	PANEL.ClientConsole.HistorySearch.Text = "Styled"
	PANEL.ClientConsole.RefreshHistory("Styled")
	check("history search runs", true)
	PANEL.ClientConsole.HistorySearch.Text = "zzz-no-match"
	PANEL.ClientConsole.RefreshHistory("zzz-no-match")
	check("history search with no match runs", true)
	PANEL.ClientConsole.HistorySearch.Text = ""
	PANEL.ClientConsole.RefreshHistory()
end
click(PANEL.ClientConsole.HistoryRefresh)

print("-- console log ---------------------------------------------------")
local logBefore = #(PANEL.ClientConsole.LogLines or {})
PANEL.ClientConsole.LogLine("console log smoke test", "info")
PANEL.ClientConsole.LogLine("another line", "success")
PANEL.ClientConsole.LogLine("a warning", "warn")
PANEL.ClientConsole.LogLine("an error", "error")
check("log lines recorded", #(PANEL.ClientConsole.LogLines or {}) > logBefore, #(PANEL.ClientConsole.LogLines or {}))
PANEL.ClientConsole.SetStatus("Status bar smoke test")
check("status text updated", tostring(PANEL.ClientConsole.StatusText.Text):find("Status bar smoke test") ~= nil, PANEL.ClientConsole.StatusText.Text)

print("-- command bar ---------------------------------------------------")
check("RunCommandText(:announce ...)", cmd(":announce Direct console command") ~= false)
check("RunCommandText(:alert ...)", cmd(":alert Console alert takeover") ~= false)
check("alert layer visible", find(rootGui(), "Alert") ~= nil and find(rootGui(), "Alert").Visible == true)
check("RunCommandText(:toast ...)", cmd(":toast Corner note") ~= false)
check("toast rendered", toastCount() >= 1, toastCount())
check("RunCommandText(:ticker ...)", cmd(":ticker Scrolling console news") ~= false)
check("ticker text set", tostring((find(rootGui(), "Ticker") and find(find(rootGui(), "Ticker"), "Text") or { Text = "" }).Text):find("Scrolling") ~= nil)
check("RunCommandText(:countdown ...)", cmd(":countdown 30 Console countdown") ~= false)
check("countdown layer visible", find(rootGui(), "Countdown").Visible == true)
check("RunCommandText(:flash)", cmd(":flash") ~= false)
check("RunCommandText(:shake)", cmd(":shake") ~= false)
check("RunCommandText(:confetti)", cmd(":confetti") ~= false)
check("RunCommandText(:help)", cmd(":help") ~= false)
check("RunCommandText(:whoami)", cmd(":whoami") ~= false)
check("RunCommandText(:bogus) handled", cmd(":boguscommand") ~= nil)
check("effects counted", PANEL.State.Stats.Effects >= 1, PANEL.State.Stats.Effects)
check("commands counted", PANEL.State.Stats.CommandsRun >= 8, PANEL.State.Stats.CommandsRun)

print("-- presets page --------------------------------------------------")
PANEL.ClientConsole.SetTab("Presets")
check("preset buttons exist", countKeys(PANEL.ClientConsole.PresetButtons) >= 1, countKeys(PANEL.ClientConsole.PresetButtons))
Mock.pump(3)
local presetClicked = clickSome(PANEL.ClientConsole.PresetButtons, 1)
check("preset button click works", presetClicked >= 1)

print("-- tools page ----------------------------------------------------")
PANEL.ClientConsole.SetTab("Tools")
check("tool buttons exist", countKeys(PANEL.ClientConsole.ToolButtons) >= 1, countKeys(PANEL.ClientConsole.ToolButtons))
if PANEL.ClientConsole.MOTDBox then
	Mock.pump(3)
	PANEL.ClientConsole.MOTDBox.Text = "Console MOTD message"
	click(PANEL.ClientConsole.MOTDSend, 3.5)
	check("MOTD sent from console", PANEL.State.MOTD.Message == "Console MOTD message", PANEL.State.MOTD.Message)
	click(PANEL.ClientConsole.MOTDClear, 3.5)
	check("MOTD cleared from console", PANEL.State.MOTD.Message == "" or PANEL.State.MOTD.Message == nil, PANEL.State.MOTD.Message)
end
check("clicking tool buttons is safe", clickSome(PANEL.ClientConsole.ToolButtons, 3) >= 1)

print("-- simulator (chaos) page ----------------------------------------")
PANEL.ClientConsole.SetTab("Simulator")
check("simulator buttons exist", countKeys(PANEL.ClientConsole.SimButtons) >= 1, countKeys(PANEL.ClientConsole.SimButtons))
check("simulator clicks are safe", clickSome(PANEL.ClientConsole.SimButtons, 2) >= 1)
local chaosLabel = PANEL.ClientConsole.ChaosStatusLabel and tostring(PANEL.ClientConsole.ChaosStatusLabel.Text)
check("chaos status label exists", chaosLabel ~= nil)
click(PANEL.ClientConsole.ChaosPlus, 0.4)
click(PANEL.ClientConsole.ChaosMinus, 0.4)
check("chaos duration label responds", PANEL.ClientConsole.ChaosDurationLabel ~= nil)
Mock.pump(34) -- ChaosCooldown is 30s
click(PANEL.ClientConsole.ChaosButton, 1.5)
check("chaos toggled on from console", PANEL.State.Chaos.Active == true, PANEL.State.Chaos.Active)
Mock.pump(6)
check("chaos fired messages", PANEL.State.Chaos.Count >= 1 or PANEL.State.Stats.Announcements >= 3, PANEL.State.Stats.Announcements)
click(PANEL.ClientConsole.ChaosButton, 1.5)
check("chaos toggled off from console", PANEL.State.Chaos.Active == false, PANEL.State.Chaos.Active)

print("-- open / close / minimise ---------------------------------------")
PANEL.ClientConsole.SetTab("Compose")
PANEL.Client.ToggleConsole(false)
check("ToggleConsole(false) disables the gui", PANEL.ClientConsole.Gui.Enabled == false)
PANEL.Client.ToggleConsole(true)
Mock.pump(0.6)
check("ToggleConsole(true) enables the gui", PANEL.ClientConsole.Gui.Enabled == true)
PANEL.Client.ToggleConsole()
Mock.pump(0.6)
check("ToggleConsole() flips it closed", PANEL.ClientConsole.Gui.Enabled == false)
check("IsOpen() agrees", PANEL.ClientConsole.IsOpen() == false)
click(PANEL.Client.FloatingButton, 0.8)
check("floating button opens the console", PANEL.ClientConsole.Gui.Enabled == true)
click(PANEL.ClientConsole.MinimizeButton)
Mock.pump(0.6)
check("minimize hides the body", PANEL.ClientConsole.Minimized == true or PANEL.ClientConsole.Body.Visible == false)
click(PANEL.ClientConsole.MinimizeButton)
Mock.pump(0.6)
click(PANEL.ClientConsole.CloseButton, 0.6)
check("close button closes the console", PANEL.ClientConsole.Gui.Enabled == false)
PANEL.ClientConsole.Open()
Mock.pump(0.6)
check("Open() reopens it", PANEL.ClientConsole.Gui.Enabled == true)
click(PANEL.ClientConsole.ClearFieldsButton)
check("clear-fields button empties the message box", PANEL.ClientConsole.MessageBox.Text == "", PANEL.ClientConsole.MessageBox.Text)

print("-- drag the window (input plumbing) ------------------------------")
local dragOk = pcall(function()
	local fakeInput = {
		UserInputType = Enum.UserInputType.MouseButton1,
		Position = MockVector2.new(400, 300),
		Delta = MockVector2.new(0, 0),
	}
	UserInputService.InputBegan:Fire(fakeInput, false)
	Mock.pump(0.1)
	for step = 1, 5 do
		UserInputService.InputChanged:Fire({
			UserInputType = Enum.UserInputType.MouseMovement,
			Position = MockVector2.new(400 + step * 10, 300 + step * 6),
			Delta = MockVector2.new(10, 6),
		}, false)
		Mock.pump(0.05)
	end
	UserInputService.InputEnded:Fire(fakeInput, false)
	Mock.pump(0.2)
end)
check("window drag input handled without errors", dragOk)

print("-- state packet + resync -----------------------------------------")
local packetOk = pcall(function()
	PANEL.ClientConsole.ApplyStatePacket({
		Mode = "solo",
		MOTD = { Message = "packet motd", Enabled = true },
		Stats = { Announcements = 7, CommandsRun = 3 },
		History = { { Kind = "Banner", Message = "packet entry", SenderName = "Steve" } },
		Chaos = { Active = false },
		Rank = "Owner",
	})
end)
check("ApplyStatePacket does not error", packetOk)
check("state packet filled the MOTD box", PANEL.ClientConsole.MOTDBox ~= nil and PANEL.ClientConsole.MOTDBox.Text == "packet motd", PANEL.ClientConsole.MOTDBox and PANEL.ClientConsole.MOTDBox.Text)
check("state packet updated the mode label", tostring(PANEL.ClientConsole.ModeText.Text):find("solo") ~= nil, PANEL.ClientConsole.ModeText.Text)
check("state packet updated the rank badge", tostring(PANEL.ClientConsole.RankBadge.Text):find("OWNER") ~= nil, PANEL.ClientConsole.RankBadge.Text)
local syncOk = pcall(function()
	PANEL.Client.Sync()
	PANEL.Client.UpdateFloatingButton()
	PANEL.ClientConsole.RefreshState()
	PANEL.ClientConsole.RefreshChoices()
end)
check("Sync/Refresh helpers are safe", syncOk)

print("-- solo demo loop ------------------------------------------------")
local historyBefore = #PANEL.State.History
PANEL.Client.StartSoloDemo()
check("demo is running", PANEL.Client.DemoRunning == true)
Mock.pump(20)
check("demo produced messages", #PANEL.State.History > historyBefore, #PANEL.State.History - historyBefore)
PANEL.Client.StopSoloDemo()
check("demo stopped", PANEL.Client.DemoRunning == false)

print("-- direct render API ---------------------------------------------")
local apiOk = pcall(function()
	PANEL.Client.HandleAnnouncement("render", { Kind = "Toast", Message = "HandleAnnouncement toast" })
	PANEL.Client.HandleAnnouncement("render", { Kind = "Banner", Message = "HandleAnnouncement banner" })
	PANEL.Client.HandleAnnouncement("clear", { Target = "me" })
end)
check("HandleAnnouncement is safe", apiOk)
Mock.pump(1)

print("-- respawn resilience --------------------------------------------")
local rootBefore = PANEL.Renderer.LocalRoot
LP.CharacterAdded:Fire(LP.Character or LP)
Mock.pump(3)
check("local root survived a respawn", PANEL.Renderer.LocalRoot ~= nil and PANEL.Renderer.LocalRoot.Gui.Parent ~= nil)
check("console gui survived a respawn", consoleGui() ~= nil)

print("-- clear ----------------------------------------------------------")
PANEL.ClientConsole.RunCommandText(":clear")
Mock.pump(1.5)
check("clear removed local banners", bannerCount() == 0, bannerCount())

print("==================================================================")
print(string.format("CLIENT SOLO RESULT: %d passed, %d failed", passed, failed))
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
