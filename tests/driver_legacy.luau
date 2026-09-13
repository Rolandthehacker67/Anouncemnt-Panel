
--============================================================================
-- DRIVER :: LEGACY CHAT (no TextChatService) RESILIENCE TEST
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

local function displayGui(player)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	return pg and pg:FindFirstChild("AnnouncementPanel")
end

local function find(root, name)
	return root and root:FindFirstChild(name, true)
end

local function banners(player)
	local stack = find(displayGui(player), "TopStack")
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

local function toasts(player)
	local holder = find(displayGui(player), "Toasts")
	if holder == nil then
		return 0
	end
	local total = 0
	for _, child in ipairs(holder:GetChildren()) do
		if child.ClassName:sub(1, 2) ~= "UI" then
			total += 1
		end
	end
	return total
end

print("==================================================================")
print("LEGACY CHAT MODE (TextChatService unavailable)")
print("==================================================================")

Mock.pump(6)

check("panel still booted", type(PANEL) == "table" and PANEL.State.Mode == "server")
check("no TextChannel was adopted", PANEL.ChatBridge.TextChannel == nil)
check("GUI installed for Steve", displayGui(Steve) ~= nil)
check("server-start announcement rendered", banners(Steve) >= 1, banners(Steve))

-- Player.Chatted path
local before = banners(Steve)
Steve.Chatted:Fire(":announce Legacy chat works")
Mock.pump(4)
check("Player.Chatted command executed", banners(Steve) > before, banners(Steve))

-- Players.PlayerChatted path (the other hook the panel installs)
Players.PlayerChatted:Fire(Steve, ":toast Legacy toast via PlayerChatted")
Mock.pump(4)
check("Players.PlayerChatted command executed", toasts(Steve) >= 1, toasts(Steve))

-- permissions still apply
-- banners expire over time, so the invariant is "no NEW banner for Bob"
local bobBefore = banners(Bob)
local deniedBefore = PANEL.State.Stats.CommandsDenied
Bob.Chatted:Fire(":announce I am not staff")
Mock.pump(3)
check("non-staff still denied", banners(Bob) <= bobBefore, banners(Bob))
check("denial counted", PANEL.State.Stats.CommandsDenied > deniedBefore, PANEL.State.Stats.CommandsDenied)
check("denied command produced no history entry", (function()
	for _, entry in ipairs(PANEL.State.History) do
		if tostring(entry.Message):find("I am not staff") then
			return false
		end
	end
	return true
end)())

-- replies go somewhere harmless (StarterGui / print), never an error
check("informational command runs", (function()
	Steve.Chatted:Fire(":help")
	Mock.pump(3)
	return PANEL.State.Stats.CommandsRun >= 3
end)(), PANEL.State.Stats.CommandsRun)

print("==================================================================")
print(string.format("LEGACY CHAT RESULT: %d passed, %d failed", passed, failed))
if #failures > 0 then
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
print("==================================================================")
