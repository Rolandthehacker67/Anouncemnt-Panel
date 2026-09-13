--!nocheck
--[[
	================================================================================
	  ANNOUNCEMENT PANEL  ::  v2.1.0  ::  ALL-IN-ONE ROBLOX STAFF BROADCAST SYSTEM
	================================================================================

	  "When the owners talk, the whole server looks up."

	  This is a single, self-contained script that builds a full announcement
	  system: glowing rank banners pinned to the top of the screen, full-screen
	  alerts, scrolling news tickers, corner toasts, countdowns, a message of
	  the day, chat-driven staff commands, ranks/permissions, filtering,
	  scheduling, persistence and an interactive Owner Console.

	--------------------------------------------------------------------------------
	  INSTALLATION  (pick ONE, or do both for the full experience)
	--------------------------------------------------------------------------------

	  [A] SERVER INSTALL  -- RECOMMENDED, works for every player in the server

			ServerScriptService
				|
				+-- AnnouncementPanel   (Script)  <-- paste this whole file inside

			* Every player gets the top-of-screen banners automatically.
			* Staff talk by typing chat commands, e.g.  :announce Server restarts in 5m
			* Nothing else to install. No RemoteEvents to build, no GUI to make.

	  [B] CLIENT INSTALL  -- the interactive Owner Console + local demo mode

			StarterPlayer
				|
				+-- StarterPlayerScripts
						|
						+-- AnnouncementPanel   (LocalScript)  <-- same file, again

			* Adds a draggable Owner Console (buttons, text boxes, colour picker,
			  effect toggles, presets, history, and the Chaos/Abuse simulator).
			* If install [A] is missing, this copy runs in SOLO mode: everything
			  still works and renders, but only for the local player.

	  [A + B] BOTH TOGETHER is the intended setup. The two halves detect each
			  other through ReplicatedStorage and never double-render:
			  the server owns the display layer, the client owns the controls.

	--------------------------------------------------------------------------------
	  HOW THE SCRIPT KNOWS WHAT TO DO
	--------------------------------------------------------------------------------

	  It asks RunService. Server context -> ServerCore starts. Client context ->
	  ClientCore starts. The same source file is valid as a Script and as a
	  LocalScript, so you can literally paste it twice and be done.

	--------------------------------------------------------------------------------
	  QUICK START
	--------------------------------------------------------------------------------

	  1. Put your UserId(s) into CONFIG.Owners.UserIds below.
	  2. Drop the script into ServerScriptService.
	  3. Press Play. Type in chat:   :help
	  4. Type:                        :announce Welcome to my game!
	  5. Watch the top of your screen light up.

	--------------------------------------------------------------------------------
	  CHAT COMMAND CHEAT SHEET  (staff only, see docs/COMMANDS.md for everything)
	--------------------------------------------------------------------------------

	  :announce <message>        pinned banner at the top of the screen
	  :alert <message>           full-screen takeover
	  :ticker <message>          scrolling news bar
	  :toast <message>           small corner notification
	  :countdown <sec> <label>   big 3..2..1 style overlay
	  :motd <message>            message shown to everyone who joins
	  :chaos on                  the "admin abuse" show (flashes, spam, confetti)
	  :history                   last announcements
	  :help                      command list for your rank

	--------------------------------------------------------------------------------
	  SAFETY NOTES
	--------------------------------------------------------------------------------

	  * All messages are run through TextService:FilterStringAsync before they are
	    broadcast (server install). Never remove that.
	  * Commands are rank-gated, rate-limited and length-capped in CONFIG.Limits.
	  * DataStore usage is wrapped in pcall and disabled in Studio by default.
	  * No remote is ever trusted blindly: every remote call re-validates the
	    sender's rank on the server. A exploiter firing your RemoteEvent gets
	    nothing but a warning in the server log.

	  MIT licensed. Credit is nice, not required. Have fun.
	================================================================================
--]]

--// ==========================================================================
--// SECTION 0  ::  SERVICES, CONTEXT DETECTION
--// ==========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

-- These two only exist / are only usable on one side, so grab them politely.
local TextChatService = nil
local UserInputService = nil
local ContextActionService = nil
local GuiService = nil
local DataStoreService = nil
local MarketplaceService = nil

local function safeGetService(name)
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	if ok then
		return service
	end
	return nil
end

TextChatService = safeGetService("TextChatService")
UserInputService = safeGetService("UserInputService")
ContextActionService = safeGetService("ContextActionService")
GuiService = safeGetService("GuiService")
DataStoreService = safeGetService("DataStoreService")
MarketplaceService = safeGetService("MarketplaceService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()
local IS_STUDIO = RunService:IsStudio()
local IS_EDIT = RunService:IsRunning() == false

-- Everything hangs off one namespace so nothing leaks into _G.
local AnnouncementPanel = {}
AnnouncementPanel.Version = "2.1.0"
AnnouncementPanel.BuildStamp = "all-in-one"

local SYSTEM_TAG = "AnnouncementPanel"

--// ==========================================================================
--// SECTION 1  ::  CONFIGURATION
--// Everything you will ever want to tweak lives here. Nothing below this
--// table needs to be touched for a normal install.
--// ==========================================================================

local CONFIG = {}

--[[--------------------------------------------------------------------------
	IDENTITY
	The name printed on banners, in the console title bar and in logs.
--------------------------------------------------------------------------]]
CONFIG.SystemName = "Announcement Panel"
CONFIG.ShortName = "AP"
CONFIG.Version = AnnouncementPanel.Version
CONFIG.CommandPrefix = ":" -- staff commands start with this
CONFIG.AltPrefixes = { ";", "!" } -- extra accepted prefixes
CONFIG.WhisperPrefix = "." -- ":announce" = everyone, ".announce" = staff chat only

--[[--------------------------------------------------------------------------
	SERVER / PLACE INFO
	Used in the MOTD, in the footer watermark and by :stats.
--------------------------------------------------------------------------]]
CONFIG.ServerInfo = {
	GameName = "", -- leave blank to auto-detect from MarketplaceService
	FooterText = "Announcement Panel v" .. AnnouncementPanel.Version,
	ShowFooterWatermark = true,
	ShowJoinMessages = true,
	AnnounceServerStart = true,
	ServerStartMessage = "This server is now live. Type :help if you are staff.",
}

--[[--------------------------------------------------------------------------
	RANKS
	Ranks are checked top-down by Order. A player keeps the highest rank they
	match. "Permissions" is a list of command names; "*" means everything.
--------------------------------------------------------------------------]]
CONFIG.Ranks = {
	Owner = {
		Order = 100,
		DisplayName = "OWNER",
		ChatTag = "[OWNER]",
		Badge = "\u{1F451}", -- crown
		Color = Color3.fromRGB(255, 196, 61),
		AccentColor = Color3.fromRGB(255, 236, 170),
		DarkColor = Color3.fromRGB(74, 47, 6),
		Permissions = { "*" },
		MaxDuration = 600,
		CanUseChaos = true,
	},

	Admin = {
		Order = 75,
		DisplayName = "ADMIN",
		ChatTag = "[ADMIN]",
		Badge = "\u{1F6E1}", -- shield
		Color = Color3.fromRGB(255, 92, 92),
		AccentColor = Color3.fromRGB(255, 190, 190),
		DarkColor = Color3.fromRGB(72, 16, 16),
		Permissions = {
			"announce", "alert", "ticker", "toast", "countdown", "motd",
			"clear", "history", "help", "flash", "shake", "confetti",
			"preset", "schedule", "unschedule", "stats", "test", "mute",
			"unmute", "rank", "unrank", "panel", "ping", "broadcast",
			"chaos", "vignette",
		},
		MaxDuration = 300,
		CanUseChaos = true,
	},

	Mod = {
		Order = 50,
		DisplayName = "MODERATOR",
		ChatTag = "[MOD]",
		Badge = "\u{1F528}", -- hammer
		Color = Color3.fromRGB(88, 176, 255),
		AccentColor = Color3.fromRGB(196, 232, 255),
		DarkColor = Color3.fromRGB(14, 40, 68),
		Permissions = {
			"announce", "toast", "ticker", "clear", "history", "help",
			"stats", "test", "mute", "unmute", "ping", "panel",
		},
		MaxDuration = 120,
		CanUseChaos = false,
	},

	Helper = {
		Order = 30,
		DisplayName = "HELPER",
		ChatTag = "[HELPER]",
		Badge = "\u{2728}", -- sparkles
		Color = Color3.fromRGB(140, 255, 170),
		AccentColor = Color3.fromRGB(214, 255, 226),
		DarkColor = Color3.fromRGB(16, 62, 34),
		Permissions = { "announce", "toast", "history", "help", "ping", "test" },
		MaxDuration = 60,
		CanUseChaos = false,
	},

	VIP = {
		Order = 15,
		DisplayName = "VIP",
		ChatTag = "[VIP]",
		Badge = "\u{1F48E}", -- gem
		Color = Color3.fromRGB(205, 130, 255),
		AccentColor = Color3.fromRGB(238, 208, 255),
		DarkColor = Color3.fromRGB(48, 18, 74),
		Permissions = {}, -- cosmetic only, no commands
		MaxDuration = 0,
		CanUseChaos = false,
	},

	Player = {
		Order = 0,
		DisplayName = "PLAYER",
		ChatTag = "",
		Badge = "",
		Color = Color3.fromRGB(200, 200, 200),
		AccentColor = Color3.fromRGB(235, 235, 235),
		DarkColor = Color3.fromRGB(30, 30, 30),
		Permissions = {},
		MaxDuration = 0,
		CanUseChaos = false,
	},
}

--[[--------------------------------------------------------------------------
	WHO IS STAFF
	Fill in at least one of these. Every list is OR'd together, so a UserId in
	Admins.UserIds and a matching group rank in Owners.GroupRanks both work.

	  * GameOwnerIsOwner  -> the place owner is always an Owner (recommended)
	  * UserIds           -> most reliable, survives name changes
	  * Usernames         -> convenient, breaks if they change their name
	  * GroupRanks        -> { GroupId = 12345678, MinRank = 250, MaxRank = 255 }
	  * Teams             -> { "Administrators", "Mods" } (Roblox Teams)
	  * Attributes        -> player:SetAttribute("AP_Rank", "Owner") at runtime
	  * Gamepasses        -> { [123456789] = "VIP" }
--------------------------------------------------------------------------]]
CONFIG.Owners = {
	UserIds = {
		-- 15645312,   -- <-- your UserId here
	},
	Usernames = {
		-- "Builderman",
	},
	GroupRanks = {
		-- { GroupId = 0, MinRank = 250, MaxRank = 255 },
	},
	Teams = {},
	Gamepasses = {},
}

CONFIG.Admins = {
	UserIds = {},
	Usernames = {},
	GroupRanks = {},
	Teams = {},
	Gamepasses = {},
}

CONFIG.Mods = {
	UserIds = {},
	Usernames = {},
	GroupRanks = {},
	Teams = {},
	Gamepasses = {},
}

CONFIG.Helpers = {
	UserIds = {},
	Usernames = {},
	GroupRanks = {},
	Teams = {},
	Gamepasses = {},
}

CONFIG.VIPs = {
	UserIds = {},
	Usernames = {},
	GroupRanks = {},
	Teams = {},
	Gamepasses = {
		-- [000000000] = true,
	},
}

CONFIG.RankRules = {
	GameOwnerIsOwner = true, -- place owner always becomes Owner
	StudioEveryoneIsOwner = true, -- in Studio every player is Owner (fast testing)
	AllowAttributeOverride = true, -- player attribute "AP_Rank" wins over lists
	AttributeName = "AP_Rank",
	CacheForSeconds = 20, -- rank lookups (group/gamepass) are cached
	DenyListUserIds = {}, -- these users are forced to Player rank
	DenyListUsernames = {},
}

--[[--------------------------------------------------------------------------
	LIMITS & RATE LIMITING
--------------------------------------------------------------------------]]
CONFIG.Limits = {
	MaxMessageLength = 280,
	MaxTitleLength = 48,
	MinDuration = 2,
	MaxDuration = 600,
	DefaultDuration = 9,
	MaxVisibleBanners = 3, -- older banners collapse when exceeded
	MaxToastsOnScreen = 4,
	MaxHistoryEntries = 40,
	CommandCooldown = 1.2, -- seconds between any two commands (per player)
	AnnounceCooldown = 2.5, -- seconds between announcements (per player)
	AlertCooldown = 20, -- full-screen alerts are rare on purpose
	ChaosCooldown = 30,
	MaxScheduledEvents = 12,
	MaxConcurrentEffects = 8,
}

--[[--------------------------------------------------------------------------
	APPEARANCE
--------------------------------------------------------------------------]]
CONFIG.Appearance = {
	TopbarOffset = 58, -- pixels reserved for the Roblox topbar
	BannerWidth = 560, -- pixels at scale 1
	BannerMinWidth = 300,
	BannerHeight = 76,
	BannerGap = 8,
	BannerCornerRadius = 14,
	BackgroundTransparency = 0.08,
	BorderThickness = 2,
	GlowTransparency = 0.55,
	TextSize = 17,
	TitleTextSize = 15,
	RankTagTextSize = 12,
	FontFamily = "rbxasset://fonts/families/GothamSSm.json",
	FallbackFont = Enum.Font.GothamMedium,
	BoldFont = Enum.Font.GothamBold,
	HeavyFont = Enum.Font.GothamBlack,
	BaseColor = Color3.fromRGB(18, 18, 24), -- banner backdrop
	BaseColor2 = Color3.fromRGB(30, 30, 40), -- gradient partner
	BackdropDim = 0.45, -- alert overlay darkness
	ShadowOpacity = 0.45,
	UseRichText = true,
	ScaleWithScreen = true,
	MinUIScale = 0.72,
	MaxUIScale = 1.25,
	ScaleReferenceWidth = 1440,
	RespectSafeArea = true,
}

--[[--------------------------------------------------------------------------
	ANIMATION
--------------------------------------------------------------------------]]
CONFIG.Animation = {
	BannerInTime = 0.42,
	BannerOutTime = 0.32,
	BannerInStyle = Enum.EasingStyle.Back,
	BannerInDirection = Enum.EasingDirection.Out,
	BannerOutStyle = Enum.EasingStyle.Quad,
	BannerOutDirection = Enum.EasingDirection.In,
	AlertInTime = 0.3,
	AlertOutTime = 0.45,
	ToastInTime = 0.28,
	PulseTime = 1.1,
	ProgressUpdateRate = 0.05,
	TickerSpeed = 190, -- pixels per second
	TickerMinTime = 9,
	ServerSideAnimations = true, -- server install still animates (replicated)
	JitterFrames = 14, -- used by the server-side shake
}

--[[--------------------------------------------------------------------------
	EFFECTS
	Each effect can be globally disabled here regardless of what staff request.
--------------------------------------------------------------------------]]
CONFIG.Effects = {
	EnableSound = true,
	EnableFlash = true,
	EnableShake = true,
	EnableConfetti = true,
	EnableVignette = true,
	EnableLighting = true, -- ColorCorrection / Blur pulses in Lighting
	FlashTime = 0.32,
	FlashColor = Color3.fromRGB(255, 255, 255),
	FlashMaxTransparency = 0.62,
	ShakeIntensity = 1.4,
	ShakeTime = 0.55,
	CameraShakeIntensity = 0.9, -- client install only
	ConfettiPieces = 46,
	ConfettiLifetime = 2.6,
	ConfettiColors = {
		Color3.fromRGB(255, 196, 61),
		Color3.fromRGB(255, 92, 92),
		Color3.fromRGB(88, 176, 255),
		Color3.fromRGB(140, 255, 170),
		Color3.fromRGB(205, 130, 255),
		Color3.fromRGB(255, 255, 255),
	},
	BlurAmount = 10,
	LightingPulseTime = 0.9,
}

--[[--------------------------------------------------------------------------
	SOUNDS
	Leave an entry as "" to disable that sound. Put any rbxassetid:// you own
	or that is free to use here - the system never assumes an ID exists.
--------------------------------------------------------------------------]]
CONFIG.Sounds = {
	Enabled = true,
	Volume = 0.6,
	Banner = "", -- e.g. "rbxassetid://0000000000"
	Alert = "",
	Toast = "",
	Ticker = "",
	Countdown = "",
	CountdownEnd = "",
	ConsoleOpen = "",
	ConsoleClose = "",
	ConsoleClick = "",
	Chaos = "",
	Deny = "",
	Join = "",
	-- Named library so staff can request ":announce hi --sound Alert"
	Library = {},
}

--[[--------------------------------------------------------------------------
	STYLES
	A style is a bundle of visuals. ":announce hi --style gold"
--------------------------------------------------------------------------]]
CONFIG.Styles = {
	Default = {
		GradientTop = Color3.fromRGB(255, 255, 255),
		GradientBottom = Color3.fromRGB(214, 214, 214),
		Stroke = nil, -- nil means "use the rank colour"
		Glow = true,
		Flash = true,
		Shake = false,
		Confetti = false,
		Sound = "Banner",
	},

	Gold = {
		GradientTop = Color3.fromRGB(255, 231, 150),
		GradientBottom = Color3.fromRGB(255, 176, 32),
		Stroke = Color3.fromRGB(255, 244, 200),
		Glow = true,
		Flash = true,
		Shake = true,
		Confetti = true,
		Sound = "Banner",
	},

	Fire = {
		GradientTop = Color3.fromRGB(255, 176, 84),
		GradientBottom = Color3.fromRGB(214, 40, 20),
		Stroke = Color3.fromRGB(255, 220, 150),
		Glow = true,
		Flash = true,
		Shake = true,
		Confetti = false,
		Sound = "Alert",
	},

	Ice = {
		GradientTop = Color3.fromRGB(196, 240, 255),
		GradientBottom = Color3.fromRGB(70, 150, 220),
		Stroke = Color3.fromRGB(230, 250, 255),
		Glow = true,
		Flash = false,
		Shake = false,
		Confetti = false,
		Sound = "Banner",
	},

	Neon = {
		GradientTop = Color3.fromRGB(120, 255, 210),
		GradientBottom = Color3.fromRGB(140, 60, 255),
		Stroke = Color3.fromRGB(210, 255, 240),
		Glow = true,
		Flash = true,
		Shake = false,
		Confetti = true,
		Sound = "Banner",
	},

	Shadow = {
		GradientTop = Color3.fromRGB(70, 70, 84),
		GradientBottom = Color3.fromRGB(16, 16, 22),
		Stroke = Color3.fromRGB(140, 140, 160),
		Glow = false,
		Flash = false,
		Shake = false,
		Confetti = false,
		Sound = "Banner",
	},

	Rainbow = {
		GradientTop = Color3.fromRGB(255, 120, 120),
		GradientBottom = Color3.fromRGB(120, 160, 255),
		Stroke = Color3.fromRGB(255, 255, 255),
		Glow = true,
		Flash = false,
		Shake = false,
		Confetti = true,
		Sound = "Banner",
		Rainbow = true, -- cycles hue while alive
	},

	Emergency = {
		GradientTop = Color3.fromRGB(255, 60, 60),
		GradientBottom = Color3.fromRGB(120, 0, 0),
		Stroke = Color3.fromRGB(255, 200, 200),
		Glow = true,
		Flash = true,
		Shake = true,
		Confetti = false,
		Sound = "Alert",
		Pulse = true,
	},
}

CONFIG.DefaultStyle = "Default"

--[[--------------------------------------------------------------------------
	PRESET MESSAGES
	":preset restart" fires the whole bundle (title, text, style, effects).
--------------------------------------------------------------------------]]
CONFIG.Presets = {
	restart = {
		Title = "SERVER RESTART",
		Message = "This server is restarting shortly. Please save your progress!",
		Style = "Emergency",
		Duration = 20,
		Effects = { Flash = true, Shake = true },
	},
	update = {
		Title = "UPDATE LIVE",
		Message = "A new update has just been released. Rejoin to get it!",
		Style = "Neon",
		Duration = 14,
		Effects = { Confetti = true },
	},
	event = {
		Title = "EVENT STARTING",
		Message = "A limited time event is starting right now. Don't miss it!",
		Style = "Gold",
		Duration = 15,
		Effects = { Confetti = true, Flash = true },
	},
	rules = {
		Title = "SERVER RULES",
		Message = "No exploiting, no harassment, no spam. Be excellent to each other.",
		Style = "Ice",
		Duration = 18,
	},
	welcome = {
		Title = "WELCOME",
		Message = "Welcome to the server! Have fun and play fair.",
		Style = "Default",
		Duration = 10,
	},
	doublexp = {
		Title = "DOUBLE XP",
		Message = "Double XP is active for the whole server right now!",
		Style = "Gold",
		Duration = 12,
		Effects = { Confetti = true },
	},
	maintenance = {
		Title = "MAINTENANCE",
		Message = "The game is going down for maintenance. Thank you for your patience.",
		Style = "Shadow",
		Duration = 25,
	},
	giveaway = {
		Title = "GIVEAWAY",
		Message = "A giveaway is running in the community server. Check the group!",
		Style = "Rainbow",
		Duration = 15,
		Effects = { Confetti = true },
	},
	lag = {
		Title = "PERFORMANCE",
		Message = "We are aware of the lag and are looking into it. Thanks for waiting.",
		Style = "Fire",
		Duration = 12,
	},
	shutdown = {
		Title = "SHUTTING DOWN",
		Message = "This server is closing in a few moments. Thanks for playing!",
		Style = "Emergency",
		Duration = 20,
		Effects = { Flash = true, Shake = true },
	},
}

--[[--------------------------------------------------------------------------
	MESSAGE OF THE DAY
	Shown to each player shortly after they spawn. Persisted if
	CONFIG.Persistence.Enabled is on.
--------------------------------------------------------------------------]]
CONFIG.MOTD = {
	Enabled = true,
	DelayAfterJoin = 3,
	Duration = 16,
	Title = "MESSAGE OF THE DAY",
	Message = "Welcome! Read the rules in the description. Staff can be reached with the report command.",
	Style = "Ice",
	ShowOnEverySpawn = false,
}

--[[--------------------------------------------------------------------------
	JOIN / LEAVE MESSAGES
	Broadcast when players enter or leave. Keep them short and kind.
--------------------------------------------------------------------------]]
CONFIG.JoinMessages = {
	Enabled = false,
	Style = "Toast", -- Banner | Toast | Ticker
	Duration = 5,
	Template = "{player} joined the server.",
	StaffTemplate = "{badge} {rank} {player} joined the server.",
	AnnounceStaffOnly = true, -- only announce when a staff member joins
	AnnounceFirstPlayer = true,
}

CONFIG.LeaveMessages = {
	Enabled = false,
	Style = "Toast",
	Duration = 4,
	Template = "{player} left the server.",
	StaffTemplate = "{badge} {rank} {player} left the server.",
	AnnounceStaffOnly = true,
}

--[[--------------------------------------------------------------------------
	SCHEDULED / RECURRING ANNOUNCEMENTS
	Fired automatically by the server. Interval is in seconds.
--------------------------------------------------------------------------]]
CONFIG.Schedule = {
	Enabled = true,
	TickRate = 1,
	Items = {
		-- { Every = 600, Title = "TIP", Message = "Follow the group for updates!", Style = "Ice", Duration = 8 },
		-- { Every = 1800, Message = "Server rules: be kind, play fair, no exploits." },
	},
	FirstTickDelay = 60, -- don't greet people 1 second after they join
	UptimeAnnouncements = {
		-- { AtMinutes = 30, Message = "This server has been up for 30 minutes." },
	},
}

--[[--------------------------------------------------------------------------
	CHAOS MODE  (the "admin abuse" show)
	:chaos on  ->  the server starts firing dramatic owner messages, flashes,
	shakes and confetti on a loop. Great for videos, terrible for real servers.
--------------------------------------------------------------------------]]
CONFIG.Chaos = {
	Enabled = true,
	MaxDurationSeconds = 180, -- auto-stops, nobody leaves it on forever
	DefaultDurationSeconds = 45,
	IntervalMin = 2.2,
	IntervalMax = 5.5,
	FlashChance = 0.5,
	ShakeChance = 0.5,
	ConfettiChance = 0.35,
	AlertChance = 0.12,
	TickerChance = 0.2,
	FakeOwnerNames = {
		"xX_Owner_Xx", "TheRealOwner", "OwnerOfEverything", "HeadAdmin",
		"ChiefAdmin", "SirAbuseALot", "OwnerAlt", "TheFounder",
		"BigBoss", "AdminOnTop", "ModSquad", "OwnerPrime",
	},
	FakeRanks = { "Owner", "Admin", "Mod" },
	Lines = {
		"EVERYONE STOP MOVING. THIS IS AN OWNER MESSAGE.",
		"I am testing the announcement system. Please ignore me.",
		"Whoever keeps respawning at spawn, stop it.",
		"FREE ROBUX. Just kidding. Or am I?",
		"The admin abuse has begun. Good luck to you all.",
		"This server is now under owner supervision.",
		"Someone is about to get kicked and it might be you.",
		"DO NOT TOUCH THE BUTTON. I MEAN IT.",
		"We are watching the leaderboard. Behave.",
		"Double XP activated by an owner. You're welcome.",
		"This is a drill. This is only a drill. Probably.",
		"If you can read this, the panel works. Amazing.",
		"Stop exploiting or the ban hammer swings.",
		"Owner has entered the building. Act natural.",
		"I pressed a button and now everything is gold.",
		"Server restart in ten minutes. Or ten seconds.",
		"Anyone who says 'first' gets muted.",
		"The chaos has been enabled. Blame the owner.",
		"Announcement system stress test in progress.",
		"I can see your messages. All of them.",
	},
}

--[[--------------------------------------------------------------------------
	CLIENT CONSOLE  (install B)
--------------------------------------------------------------------------]]
CONFIG.Console = {
	Enabled = true,
	ToggleKeyCode = Enum.KeyCode.RightControl,
	SecondaryToggleKey = Enum.KeyCode.F1,
	ShowFloatingButton = true, -- on-screen button for mobile / console players
	FloatingButtonPosition = UDim2.new(1, -78, 1, -78),
	Size = UDim2.fromOffset(560, 420),
	MinSize = UDim2.fromOffset(420, 320),
	OpenOnStart = false,
	RememberPosition = true,
	Draggable = true,
	Resizable = true,
	BlurBehind = true,
	CloseOnEscape = true,
	QuickMessages = {
		"Welcome to the server!",
		"Server restart in 5 minutes.",
		"Double XP is now active!",
		"Read the rules, everyone.",
		"Event starting now!",
		"Thanks for playing!",
	},
	DefaultStyle = "Gold",
	DefaultDuration = 9,
}

--[[--------------------------------------------------------------------------
	SOLO / DEMO MODE  (client install without the server install)
--------------------------------------------------------------------------]]
CONFIG.Solo = {
	Enabled = true,
	WaitForServerSeconds = 6, -- how long to look for the server half
	AutoDemo = false, -- fire the demo show automatically on join
	DemoDelay = 5,
	DemoInterval = 6,
	SimulatedPlayers = {
		{Name = "You", Rank = "Owner"},
	},
}

--[[--------------------------------------------------------------------------
	FILTERING & MODERATION
--------------------------------------------------------------------------]]
CONFIG.Moderation = {
	FilterBroadcastMessages = true, -- TextService, never disable this
	FallbackCensor = true, -- word list below, used if TextService fails
	StripRichText = true, -- stop people injecting <font> tags
	MaxLengthBeforeReject = 400,
	BlockedCommandsForNonStaff = true, -- log attempts, don't run them
	LogNonStaffAttempts = true,
	LogAllCommands = true,
	WarnInChat = true,
	CensoredReplacement = "####",
	BlockedWords = {
		"free robux generator", "getrobuxnow", "hackscript", "exploit download",
	},
}

--[[--------------------------------------------------------------------------
	PERSISTENCE  (DataStore)
	Saves the MOTD, scheduled items and stats between servers.
--------------------------------------------------------------------------]]
CONFIG.Persistence = {
	Enabled = false, -- set true once your game has API access enabled
	DataStoreName = "AnnouncementPanel_v2",
	KeyPrefix = "Global",
	AllowInStudio = false,
	SaveInterval = 120,
	SaveOnShutdown = true,
	SaveMOTD = true,
	SaveSchedule = true,
	SaveStats = true,
}

--[[--------------------------------------------------------------------------
	NETWORKING
--------------------------------------------------------------------------]]
CONFIG.Net = {
	FolderName = "AnnouncementPanelRemotes",
	AnnouncementEvent = "Announcement",
	ConsoleEvent = "ConsoleCommand",
	HandshakeEvent = "Handshake",
	AckEvent = "Ack",
	RankAttribute = "AP_Rank",
	RankNameAttribute = "AP_RankName",
	ServerActiveAttribute = "AP_ServerActive",
	RetryWait = 0.5,
	MaxRetries = 12,
}

--[[--------------------------------------------------------------------------
	DEBUG
--------------------------------------------------------------------------]]
CONFIG.Debug = {
	Enabled = false,
	PrintRankResolution = false,
	PrintCommands = true,
	PrintNetwork = false,
	PrintRender = false,
	WarnOnMissingSound = true,
	BannerOnBoot = true, -- the ASCII banner in the output window
	StrictMode = false, -- error() instead of warn() on internal failures
}

-- Handy aliases used all over the file.
local LIMITS = CONFIG.Limits
local APPEAR = CONFIG.Appearance
local ANIM = CONFIG.Animation
local FX = CONFIG.Effects
local RANKS = CONFIG.Ranks

--// ==========================================================================
--// SECTION 2  ::  UTILITIES
--// Small, boring, absolutely necessary helpers.
--// ==========================================================================

local Util = {}

--// ---------- logging -------------------------------------------------------

local LOG_COLORS = {
	info = Color3.fromRGB(120, 200, 255),
	warn = Color3.fromRGB(255, 205, 90),
	error = Color3.fromRGB(255, 110, 110),
	debug = Color3.fromRGB(180, 180, 190),
	success = Color3.fromRGB(140, 255, 170),
}

local function buildLogPrefix(level)
	local side = IS_SERVER and "server" or "client"
	return string.format("[%s|%s|%s]", SYSTEM_TAG, side, level)
end

function Util.Log(level, ...)
	level = string.lower(tostring(level or "info"))
	if level == "debug" and not CONFIG.Debug.Enabled then
		return
	end
	local prefix = buildLogPrefix(level)
	if level == "error" then
		warn(prefix, ...)
	elseif level == "warn" then
		warn(prefix, ...)
	else
		print(prefix, ...)
	end
end

function Util.Info(...)
	Util.Log("info", ...)
end

function Util.Warn(...)
	Util.Log("warn", ...)
end

function Util.Debug(...)
	Util.Log("debug", ...)
end

function Util.Error(...)
	Util.Log("error", ...)
end

function Util.Assert(condition, message)
	if not condition then
		local text = message or "assertion failed"
		if CONFIG.Debug.StrictMode then
			error(text, 2)
		else
			Util.Warn(text)
		end
		return false
	end
	return true
end

--// ---------- numbers & strings ---------------------------------------------

function Util.Clamp(value, min, max)
	if type(value) ~= "number" then
		return min
	end
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

function Util.Round(value, places)
	places = places or 0
	local mult = 10 ^ places
	return math.floor(value * mult + 0.5) / mult
end

function Util.RandomBetween(min, max)
	if min == max then
		return min
	end
	return min + (math.random() * (max - min))
end

function Util.RandomInt(min, max)
	return math.random(math.floor(min), math.floor(max))
end

function Util.RandomFromList(list, default)
	if type(list) ~= "table" or #list == 0 then
		return default
	end
	return list[math.random(1, #list)]
end

function Util.ShallowCopy(source)
	local copy = {}
	if type(source) ~= "table" then
		return copy
	end
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

function Util.DeepCopy(source, seen)
	if type(source) ~= "table" then
		return source
	end
	seen = seen or {}
	if seen[source] then
		return seen[source]
	end
	local copy = {}
	seen[source] = copy
	for key, value in pairs(source) do
		copy[Util.DeepCopy(key, seen)] = Util.DeepCopy(value, seen)
	end
	return copy
end

function Util.Merge(base, override)
	local result = Util.DeepCopy(base or {})
	if type(override) ~= "table" then
		return result
	end
	for key, value in pairs(override) do
		if type(value) == "table" and type(result[key]) == "table" then
			result[key] = Util.Merge(result[key], value)
		else
			result[key] = value
		end
	end
	return result
end

function Util.CountKeys(list)
	local count = 0
	for _ in pairs(list or {}) do
		count += 1
	end
	return count
end

function Util.TableContains(list, value)
	if type(list) ~= "table" then
		return false
	end
	for _, item in pairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

function Util.TableIndexOf(list, value)
	if type(list) ~= "table" then
		return -1
	end
	for index, item in ipairs(list) do
		if item == value then
			return index
		end
	end
	return -1
end

function Util.SortedKeys(list)
	local keys = {}
	for key in pairs(list or {}) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

function Util.Shuffle(list)
	local copy = Util.ShallowCopy(list)
	for index = #copy, 2, -1 do
		local swap = math.random(1, index)
		copy[index], copy[swap] = copy[swap], copy[index]
	end
	return copy
end

function Util.Trim(text)
	if type(text) ~= "string" then
		return ""
	end
	return text:match("^%s*(.-)%s*$") or ""
end

function Util.StartsWith(text, prefix)
	if type(text) ~= "string" or type(prefix) ~= "string" then
		return false
	end
	return text:sub(1, #prefix) == prefix
end

function Util.EndsWith(text, suffix)
	if type(text) ~= "string" or type(suffix) ~= "string" then
		return false
	end
	return suffix == "" or text:sub(-#suffix) == suffix
end

function Util.Split(text, separator)
	separator = separator or ","
	local parts = {}
	if type(text) ~= "string" then
		return parts
	end
	local source = tostring(text)
	if separator == "" then
		for index = 1, #source do
			table.insert(parts, source:sub(index, index))
		end
		return parts
	end
	local pattern = "([^" .. tostring(separator) .. "]+)"
	for chunk in string.gmatch(source, pattern) do
		table.insert(parts, chunk)
	end
	return parts
end

function Util.SplitWords(text)
	local words = {}
	if type(text) ~= "string" then
		return words
	end
	for word in string.gmatch(text, "%S+") do
		table.insert(words, word)
	end
	return words
end

-- Escapes every magic pattern character so a literal string can be matched.
function Util.EscapePattern(text)
	if type(text) ~= "string" then
		return ""
	end
	local escaped = text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	return escaped
end

function Util.TitleCase(text)
	if type(text) ~= "string" then
		return ""
	end
	return (text:gsub("(%a)([%w_']*)", function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end))
end

function Util.Truncate(text, maxLength, suffix)
	if type(text) ~= "string" then
		return ""
	end
	suffix = suffix or "..."
	maxLength = maxLength or 120
	if #text <= maxLength then
		return text
	end
	local cut = math.max(1, maxLength - #suffix)
	return text:sub(1, cut) .. suffix
end

-- Strips rich-text tags so a player can never inject <font> or <br/> markup
-- into somebody else's banner.
function Util.SanitizeRichText(text)
	if type(text) ~= "string" then
		return ""
	end
	local clean = text:gsub("<%s*/?%s*[A-Za-z]+[^>]*>", "")
	clean = clean:gsub("</?%s*>", "")
	return clean
end

-- Escapes a value so it is safe to drop into a rich-text label.
function Util.EscapeRichText(text)
	if type(text) ~= "string" then
		return ""
	end
	local escaped = text:gsub("&", "&amp;")
	escaped = escaped:gsub("<", "&lt;")
	escaped = escaped:gsub(">", "&gt;")
	return escaped
end

function Util.ApplyRichText(text)
	if type(text) ~= "string" then
		return ""
	end
	if APPEAR.UseRichText then
		return text
	end
	return Util.SanitizeRichText(text)
end

-- Replaces {token} placeholders, e.g. {player}, {rank}, {badge}, {count}.
function Util.Template(template, values)
	if type(template) ~= "string" then
		return ""
	end
	values = values or {}
	local result = template
	for token, replacement in pairs(values) do
		local pattern = "{" .. tostring(token) .. "}"
		result = result:gsub(pattern, tostring(replacement))
	end
	-- Clean up any leftovers so we never show "{player}" in a banner.
	result = result:gsub("{[A-Za-z_][A-Za-z0-9_]*}", "")
	return result
end

function Util.FormatNumber(value)
	if type(value) ~= "number" then
		return "0"
	end
	local formatted = tostring(math.floor(value))
	local negative = formatted:sub(1, 1) == "-"
	if negative then
		formatted = formatted:sub(2)
	end
	local withSeparators = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withSeparators = withSeparators:gsub("^,", "")
	return (negative and "-" or "") .. withSeparators
end

function Util.FormatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds < 60 then
		return seconds .. "s"
	end
	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	if minutes < 60 then
		if rest == 0 then
			return minutes .. "m"
		end
		return string.format("%dm %ds", minutes, rest)
	end
	local hours = math.floor(minutes / 60)
	minutes = minutes % 60
	if hours < 24 then
		return string.format("%dh %dm", hours, minutes)
	end
	local days = math.floor(hours / 24)
	hours = hours % 24
	return string.format("%dd %dh", days, hours)
end

function Util.FormatClock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local rest = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, rest)
end

function Util.FormatCountdown(seconds)
	seconds = math.max(0, seconds or 0)
	if seconds >= 60 then
		local minutes = math.floor(seconds / 60)
		local rest = seconds % 60
		return string.format("%d:%02d", minutes, rest)
	end
	if seconds >= 10 then
		return tostring(math.ceil(seconds))
	end
	return tostring(Util.Round(seconds, 1))
end

function Util.TimestampString(osTime)
	osTime = osTime or os.time()
	return os.date("!%Y-%m-%d %H:%M:%S", osTime)
end

function Util.ShortId(length)
	length = length or 6
	local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	local result = ""
	for _ = 1, length do
		local index = math.random(1, #alphabet)
		result ..= alphabet:sub(index, index)
	end
	return result
end

function Util.NewGuid()
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and guid then
		return guid
	end
	return "id-" .. tostring(os.time()) .. "-" .. Util.ShortId(8)
end

--// ---------- instance helpers ----------------------------------------------

-- Instance.new with a property table and optional children, all in one call.
-- Any property that fails to set is reported once and skipped instead of
-- blowing up the whole panel.
local warnedProperties = {}

function Util.New(className, properties, children)
	local instance = Instance.new(className)
	if type(properties) == "table" then
		for name, value in pairs(properties) do
			if name ~= "Parent" then
				local ok, err = pcall(function()
					instance[name] = value
				end)
				if not ok then
					local key = className .. "." .. name
					if not warnedProperties[key] then
						warnedProperties[key] = true
						Util.Debug("property set failed:", key, err)
					end
				end
			end
		end
	end
	if type(children) == "table" then
		for _, child in pairs(children) do
			if typeof(child) == "Instance" then
				child.Parent = instance
			end
		end
	end
	if type(properties) == "table" and properties.Parent ~= nil then
		instance.Parent = properties.Parent
	end
	return instance
end

function Util.SetProps(instance, properties)
	if typeof(instance) ~= "Instance" or type(properties) ~= "table" then
		return instance
	end
	for name, value in pairs(properties) do
		if name ~= "Parent" then
			pcall(function()
				instance[name] = value
			end)
		end
	end
	if properties.Parent ~= nil then
		instance.Parent = properties.Parent
	end
	return instance
end

function Util.SetParent(instance, parent)
	if typeof(instance) == "Instance" then
		instance.Parent = parent
	end
	return instance
end

function Util.Destroy(instance)
	if typeof(instance) == "Instance" then
		pcall(function()
			instance:Destroy()
		end)
	end
end

function Util.ClearChildren(instance)
	if typeof(instance) ~= "Instance" then
		return
	end
	for _, child in ipairs(instance:GetChildren()) do
		Util.Destroy(child)
	end
end

function Util.RemoveChildrenMatching(instance, className)
	if typeof(instance) ~= "Instance" then
		return
	end
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA(className) then
			Util.Destroy(child)
		end
	end
end

function Util.WaitForChild(parent, name, timeout)
	if parent == nil then
		return nil
	end
	timeout = timeout or 8
	local direct = parent:FindFirstChild(name)
	if direct then
		return direct
	end
	local found = nil
	local deadline = os.clock() + timeout
	local connection
	connection = parent.ChildAdded:Connect(function(child)
		if child.Name == name then
			found = child
		end
	end)
	while os.clock() < deadline and not found do
		found = parent:FindFirstChild(name)
		if found then
			break
		end
		task.wait(0.05)
	end
	if connection then
		connection:Disconnect()
	end
	return found
end

function Util.WaitForChildren(parent, names, timeout)
	local found = {}
	for _, name in ipairs(names or {}) do
		found[name] = Util.WaitForChild(parent, name, timeout)
	end
	return found
end

-- There is no Instance:FindFirstDescendantOfClass in the Roblox API, so walk
-- the descendants ourselves (FindFirstChildOfClass only looks one level deep).
function Util.FindFirstDescendantOfClass(parent, className)
	if typeof(parent) ~= "Instance" then
		return nil
	end
	local direct = parent:FindFirstChildOfClass(className)
	if direct then
		return direct
	end
	local ok, result = pcall(function()
		for _, descendant in ipairs(parent:GetDescendants()) do
			if descendant:IsA(className) then
				return descendant
			end
		end
		return nil
	end)
	if ok then
		return result
	end
	return nil
end

function Util.GetDescendantsByName(parent, name)
	local results = {}
	if typeof(parent) ~= "Instance" then
		return results
	end
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant.Name == name then
			table.insert(results, descendant)
		end
	end
	return results
end

function Util.EnsureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		Util.Destroy(existing)
	end
	return Util.New("Folder", {
		Name = name,
		Parent = parent,
	})
end

--// ---------- fonts ---------------------------------------------------------

local fontCache = {}

-- Modern Font objects with a graceful fallback for old baseplates.
function Util.Font(weight, size)
	local key = tostring(weight) .. "|" .. tostring(size or 0)
	if fontCache[key] then
		return fontCache[key]
	end
	local enumWeight = Enum.FontWeight.Regular
	if type(weight) == "string" then
		local weightName = weight:lower()
		if weightName == "black" or weightName == "heavy" then
			-- NOTE: Enum.FontWeight has no "Black" item; Heavy is the heaviest.
			enumWeight = Enum.FontWeight.Heavy
		elseif weightName == "bold" then
			enumWeight = Enum.FontWeight.Bold
		elseif weightName == "semibold" then
			enumWeight = Enum.FontWeight.SemiBold
		elseif weightName == "medium" then
			enumWeight = Enum.FontWeight.Medium
		elseif weightName == "light" then
			enumWeight = Enum.FontWeight.Light
		elseif weightName == "thin" then
			enumWeight = Enum.FontWeight.Thin
		end
	elseif typeof(weight) == "EnumItem" then
		enumWeight = weight
	end
	local fontObject = nil
	local ok = pcall(function()
		fontObject = Font.new(APPEAR.FontFamily, enumWeight)
	end)
	if not ok or fontObject == nil then
		ok = pcall(function()
			fontObject = Font.fromEnum(APPEAR.FallbackFont)
		end)
	end
	if fontObject == nil then
		fontObject = Font.new("rbxasset://fonts/families/GothamSSm.json")
	end
	fontCache[key] = fontObject
	return fontObject
end

function Util.ApplyFont(textObject, weight, size)
	if typeof(textObject) ~= "Instance" or not textObject:IsA("TextLabel")
		and not textObject:IsA("TextButton") and not textObject:IsA("TextBox") then
		return textObject
	end
	if size then
		textObject.TextSize = size
	end
	local ok = pcall(function()
		textObject.FontFace = Util.Font(weight)
	end)
	if not ok then
		pcall(function()
			if weight == "bold" or weight == Enum.FontWeight.Bold then
				textObject.Font = APPEAR.BoldFont
			elseif weight == "black" or weight == Enum.FontWeight.Heavy then
				textObject.Font = APPEAR.HeavyFont
			else
				textObject.Font = APPEAR.FallbackFont
			end
		end)
	end
	return textObject
end

--// ---------- tweening ------------------------------------------------------

local activeTweens = {}

function Util.Tween(instance, time, properties, style, direction, repeatCount, reverses, delay)
	if typeof(instance) ~= "Instance" or type(properties) ~= "table" then
		return nil
	end
	time = time or 0.3
	style = style or Enum.EasingStyle.Quad
	direction = direction or Enum.EasingDirection.Out
	repeatCount = repeatCount or 0
	reverses = (reverses == true)
	delay = delay or 0

	local info = TweenInfo.new(
		time,
		style,
		direction,
		repeatCount,
		reverses,
		delay
	)

	-- Cancel anything already tweening this instance so we never fight ourselves.
	local existing = activeTweens[instance]
	if existing then
		pcall(function()
			existing:Cancel()
		end)
	end

	local ok, tween = pcall(function()
		return TweenService:Create(instance, info, properties)
	end)
	if not ok or tween == nil then
		Util.Debug("tween creation failed for", instance:GetFullName())
		-- Best-effort fallback: apply the final values instantly.
		Util.SetProps(instance, properties)
		return nil
	end
	activeTweens[instance] = tween
	tween.Completed:Connect(function()
		if activeTweens[instance] == tween then
			activeTweens[instance] = nil
		end
	end)
	tween:Play()
	return tween
end

function Util.CancelTween(instance)
	local existing = activeTweens[instance]
	if existing then
		pcall(function()
			existing:Cancel()
		end)
		activeTweens[instance] = nil
	end
end

function Util.CancelTweensFor(parent)
	if typeof(parent) ~= "Instance" then
		return
	end
	for instance, tween in pairs(activeTweens) do
		if typeof(instance) == "Instance" and instance:IsDescendantOf(parent) then
			pcall(function()
				tween:Cancel()
			end)
			activeTweens[instance] = nil
		end
	end
end

-- Waits for a tween to finish (or for a timeout) without yielding forever.
function Util.TweenWait(tween, timeout)
	if tween == nil then
		return false
	end
	timeout = timeout or 10
	local finished = false
	local connection
	connection = tween.Completed:Connect(function()
		finished = true
	end)
	local deadline = os.clock() + timeout
	while not finished and os.clock() < deadline do
		task.wait()
	end
	if connection then
		connection:Disconnect()
	end
	return finished
end

-- A manual interpolation loop. Used on the client for buttery tickers, because
-- replicated tweens can look choppy when the server drives them.
function Util.Animate(duration, callback, onComplete)
	duration = math.max(0.01, duration or 0.3)
	local started = os.clock()
	local done = false
	task.spawn(function()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if done then
				if connection then
					connection:Disconnect()
				end
				return
			end
			local elapsed = os.clock() - started
			local alpha = Util.Clamp(elapsed / duration, 0, 1)
			local ok, err = pcall(callback, alpha, elapsed)
			if not ok then
				Util.Debug("animate callback error:", err)
				done = true
				if connection then
					connection:Disconnect()
				end
				return
			end
			if alpha >= 1 then
				done = true
				if connection then
					connection:Disconnect()
				end
				if onComplete then
					pcall(onComplete)
				end
			end
		end)
		task.wait(duration + 0.25)
		if not done then
			done = true
			if connection then
				connection:Disconnect()
			end
			if onComplete then
				pcall(onComplete)
			end
		end
	end)
	return {
		Cancel = function()
			done = true
		end,
		IsRunning = function()
			return not done
		end,
	}
end

--// ---------- colour helpers ------------------------------------------------

local COLOR_NAMES = {
	red = Color3.fromRGB(255, 70, 70),
	crimson = Color3.fromRGB(220, 20, 60),
	orange = Color3.fromRGB(255, 150, 50),
	gold = Color3.fromRGB(255, 196, 61),
	yellow = Color3.fromRGB(255, 230, 90),
	lime = Color3.fromRGB(170, 255, 90),
	green = Color3.fromRGB(90, 220, 120),
	emerald = Color3.fromRGB(46, 204, 113),
	teal = Color3.fromRGB(60, 210, 200),
	cyan = Color3.fromRGB(90, 220, 255),
	sky = Color3.fromRGB(140, 200, 255),
	blue = Color3.fromRGB(80, 140, 255),
	navy = Color3.fromRGB(40, 70, 160),
	purple = Color3.fromRGB(170, 100, 255),
	violet = Color3.fromRGB(205, 130, 255),
	pink = Color3.fromRGB(255, 130, 200),
	magenta = Color3.fromRGB(255, 80, 200),
	white = Color3.fromRGB(245, 245, 245),
	silver = Color3.fromRGB(200, 205, 215),
	grey = Color3.fromRGB(140, 140, 150),
	gray = Color3.fromRGB(140, 140, 150),
	black = Color3.fromRGB(20, 20, 24),
	brown = Color3.fromRGB(150, 100, 60),
}

function Util.ColorFromName(name, fallback)
	fallback = fallback or Color3.fromRGB(245, 245, 245)
	if typeof(name) == "Color3" then
		return name
	end
	if type(name) ~= "string" then
		return fallback
	end
	local key = name:lower()
	if COLOR_NAMES[key] then
		return COLOR_NAMES[key]
	end
	-- #RRGGBB support
	local hex = key:match("^#?(%x%x%x%x%x%x)$")
	if hex then
		local r = tonumber(hex:sub(1, 2), 16)
		local g = tonumber(hex:sub(3, 4), 16)
		local b = tonumber(hex:sub(5, 6), 16)
		if r and g and b then
			return Color3.fromRGB(r, g, b)
		end
	end
	-- "255,120,60" support
	local csv = key:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
	if csv then
		local r, g, b = csv:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if r and g and b then
			return Color3.fromRGB(
				Util.Clamp(r, 0, 255),
				Util.Clamp(g, 0, 255),
				Util.Clamp(b, 0, 255)
			)
		end
	end
	return fallback
end

function Util.ColorNames()
	local names = {}
	for name in pairs(COLOR_NAMES) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Util.ColorLerp(a, b, alpha)
	alpha = Util.Clamp(alpha, 0, 1)
	return Color3.new(
		Util.Lerp(a.R, b.R, alpha),
		Util.Lerp(a.G, b.G, alpha),
		Util.Lerp(a.B, b.B, alpha)
	)
end

function Util.ColorBrighten(color, amount)
	amount = amount or 0.2
	return Color3.new(
		Util.Clamp(color.R + amount, 0, 1),
		Util.Clamp(color.G + amount, 0, 1),
		Util.Clamp(color.B + amount, 0, 1)
	)
end

function Util.ColorDarken(color, amount)
	amount = amount or 0.2
	return Color3.new(
		Util.Clamp(color.R - amount, 0, 1),
		Util.Clamp(color.G - amount, 0, 1),
		Util.Clamp(color.B - amount, 0, 1)
	)
end

-- Rotates hue - used by the Rainbow style.
function Util.ColorFromHue(hue, saturation, value)
	saturation = saturation or 1
	value = value or 1
	hue = (hue % 1 + 1) % 1
	local h = hue * 6
	local sector = math.floor(h)
	local fraction = h - sector
	local p = value * (1 - saturation)
	local q = value * (1 - saturation * fraction)
	local t = value * (1 - saturation * (1 - fraction))
	if sector == 0 then
		return Color3.new(value, t, p)
	elseif sector == 1 then
		return Color3.new(q, value, p)
	elseif sector == 2 then
		return Color3.new(p, value, t)
	elseif sector == 3 then
		return Color3.new(p, q, value)
	elseif sector == 4 then
		return Color3.new(t, p, value)
	end
	return Color3.new(value, p, q)
end

function Util.ColorToHex(color)
	if typeof(color) ~= "Color3" then
		return "#FFFFFF"
	end
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5))
end

--// ---------- misc ----------------------------------------------------------

function Util.Try(fn, label)
	local ok, err = pcall(fn)
	if not ok then
		Util.Warn((label or "task") .. " failed: " .. tostring(err))
	end
	return ok, err
end

function Util.Spawn(fn, label)
	local ok, err = pcall(function()
		task.spawn(function()
			local success, failure = pcall(fn)
			if not success then
				Util.Warn((label or "spawned task") .. " error: " .. tostring(failure))
			end
		end)
	end)
	if not ok then
		Util.Warn("could not spawn " .. tostring(label) .. ": " .. tostring(err))
	end
end

function Util.Delay(seconds, fn, label)
	seconds = math.max(0, seconds or 0)
	task.delay(seconds, function()
		local ok, err = pcall(fn)
		if not ok then
			Util.Warn((label or "delayed task") .. " error: " .. tostring(err))
		end
	end)
end

-- Debounce: returns a wrapper that ignores repeat calls inside `seconds`.
function Util.Debounce(seconds, fn)
	local last = 0
	seconds = seconds or 1
	return function(...)
		local now = os.clock()
		if now - last < seconds then
			return false
		end
		last = now
		return fn(...)
	end
end

-- Throttle with trailing call, used for resize/scroll style events.
function Util.Throttle(seconds, fn)
	local last = 0
	local pending = nil
	seconds = seconds or 0.2
	return function(...)
		local now = os.clock()
		if now - last >= seconds then
			last = now
			fn(...)
			return
		end
		pending = { ... }
		local waitTime = seconds - (now - last)
		task.delay(math.max(0, waitTime), function()
			if pending then
				last = os.clock()
				local args = pending
				pending = nil
				fn(table.unpack(args))
			end
		end)
	end
end

-- Simple signal so modules can talk without Instance events.
function Util.CreateSignal()
	local listeners = {}
	local signal = {}
	signal.IsSignal = true

	function signal:Connect(callback)
		if type(callback) ~= "function" then
			return { Disconnect = function() end }
		end
		local entry = { Callback = callback, Connected = true }
		table.insert(listeners, entry)
		return {
			Disconnect = function()
				entry.Connected = false
				for index, item in ipairs(listeners) do
					if item == entry then
						table.remove(listeners, index)
						break
					end
				end
			end,
		}
	end

	function signal:Fire(...)
		for _, entry in ipairs(Util.ShallowCopy(listeners)) do
			if entry.Connected then
				local ok, err = pcall(entry.Callback, ...)
				if not ok then
					Util.Warn("signal listener error:", err)
				end
			end
		end
	end

	function signal:Wait(timeout)
		timeout = timeout or 30
		local result = nil
		local fired = false
		local connection
		connection = signal:Connect(function(...)
			result = { ... }
			fired = true
		end)
		local deadline = os.clock() + timeout
		while not fired and os.clock() < deadline do
			task.wait(0.05)
		end
		if connection then
			connection.Disconnect()
		end
		return fired, result
	end

	function signal:DisconnectAll()
		for _, entry in ipairs(listeners) do
			entry.Connected = false
		end
		table.clear(listeners)
	end

	return signal
end

-- Tracks cleanup so nothing leaks when the script reloads.
local connections = {}

function Util.Track(connection, label)
	if connection == nil then
		return nil
	end
	table.insert(connections, { Connection = connection, Label = label })
	return connection
end

function Util.Cleanup()
	for _, entry in ipairs(connections) do
		pcall(function()
			if entry.Connection and typeof(entry.Connection) == "RBXScriptConnection" then
				entry.Connection:Disconnect()
			elseif type(entry.Connection) == "table" and entry.Connection.Disconnect then
				entry.Connection.Disconnect()
			end
		end)
	end
	table.clear(connections)
end

function Util.ConnectionCount()
	return #connections
end

AnnouncementPanel.Util = Util

--// ==========================================================================
--// SECTION 3  ::  THEME
--// Turns CONFIG.Ranks + CONFIG.Styles into concrete visual values.
--// ==========================================================================

local Theme = {}

local FALLBACK_RANK = {
	Order = 0,
	DisplayName = "PLAYER",
	ChatTag = "",
	Badge = "",
	Color = Color3.fromRGB(200, 200, 200),
	AccentColor = Color3.fromRGB(235, 235, 235),
	DarkColor = Color3.fromRGB(28, 28, 34),
	Permissions = {},
	MaxDuration = 0,
	CanUseChaos = false,
}

function Theme.GetRank(rankName)
	if type(rankName) ~= "string" then
		return FALLBACK_RANK
	end
	local exact = CONFIG.Ranks[rankName]
	if exact then
		return exact
	end
	-- Case-insensitive lookup so ":rank bob admin" works.
	local lowered = rankName:lower()
	for name, data in pairs(CONFIG.Ranks) do
		if name:lower() == lowered then
			return data
		end
	end
	return FALLBACK_RANK
end

function Theme.GetRankName(rankName)
	if type(rankName) ~= "string" then
		return "Player"
	end
	for name in pairs(CONFIG.Ranks) do
		if name:lower() == rankName:lower() then
			return name
		end
	end
	return rankName
end

function Theme.GetStyle(styleName)
	if type(styleName) ~= "string" then
		return CONFIG.Styles[CONFIG.DefaultStyle] or CONFIG.Styles.Default
	end
	local exact = CONFIG.Styles[styleName]
	if exact then
		return exact
	end
	local lowered = styleName:lower()
	for name, data in pairs(CONFIG.Styles) do
		if name:lower() == lowered then
			return data
		end
	end
	return CONFIG.Styles[CONFIG.DefaultStyle] or CONFIG.Styles.Default
end

function Theme.StyleNames()
	local names = Util.SortedKeys(CONFIG.Styles)
	return names
end

function Theme.RankNames()
	local names = {}
	for name in pairs(CONFIG.Ranks) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		return (CONFIG.Ranks[a].Order or 0) > (CONFIG.Ranks[b].Order or 0)
	end)
	return names
end

-- Builds the palette a single banner will be painted with.
function Theme.PaletteFor(rankName, styleName)
	local rank = Theme.GetRank(rankName)
	local style = Theme.GetStyle(styleName)

	local strokeColor = style.Stroke or rank.Color or Color3.fromRGB(255, 255, 255)
	local gradientTop = style.GradientTop or Color3.fromRGB(255, 255, 255)
	local gradientBottom = style.GradientBottom or Color3.fromRGB(200, 200, 200)

	return {
		Rank = rank,
		Style = style,
		RankName = rankName or "Player",
		StyleName = styleName or CONFIG.DefaultStyle,
		RankColor = rank.Color or Color3.fromRGB(255, 255, 255),
		RankAccent = rank.AccentColor or Color3.fromRGB(240, 240, 240),
		RankDark = rank.DarkColor or Color3.fromRGB(20, 20, 26),
		Stroke = strokeColor,
		GradientTop = gradientTop,
		GradientBottom = gradientBottom,
		Background = APPEAR.BaseColor,
		Background2 = APPEAR.BaseColor2,
		TitleColor = rank.AccentColor or Color3.fromRGB(240, 240, 240),
		MessageColor = Color3.fromRGB(242, 242, 248),
		MetaColor = Color3.fromRGB(180, 182, 196),
		ProgressBar = rank.Color or Color3.fromRGB(255, 255, 255),
		ProgressBarTrack = Color3.fromRGB(46, 46, 58),
		Glow = rank.Color or Color3.fromRGB(255, 255, 255),
		Flash = style.Flash and FX.EnableFlash,
		Shake = style.Shake and FX.EnableShake,
		Confetti = style.Confetti and FX.EnableConfetti,
		GlowEnabled = style.Glow ~= false,
		Pulse = style.Pulse == true,
		Rainbow = style.Rainbow == true,
		SoundName = style.Sound or "Banner",
	}
end

-- Text colour that stays readable on top of a given background.
function Theme.ReadableTextOn(color)
	if typeof(color) ~= "Color3" then
		return Color3.fromRGB(245, 245, 245)
	end
	local luminance = (color.R * 0.299) + (color.G * 0.587) + (color.B * 0.114)
	if luminance > 0.62 then
		return Color3.fromRGB(24, 24, 30)
	end
	return Color3.fromRGB(248, 248, 252)
end

-- A gradient object factory, cached because we build a lot of them.
local gradientCache = {}

function Theme.Gradient(topColor, bottomColor, rotation)
	rotation = rotation or 90
	local key = Util.ColorToHex(topColor) .. "|" .. Util.ColorToHex(bottomColor) .. "|" .. tostring(rotation)
	if gradientCache[key] and gradientCache[key].Parent == nil then
		-- Cached instance was consumed by a parent, build a fresh one.
		gradientCache[key] = nil
	end
	if gradientCache[key] then
		return gradientCache[key]
	end
	local gradient = Util.New("UIGradient", {
		Color = ColorSequence.new(topColor, bottomColor),
		Rotation = rotation,
		Transparency = NumberSequence.new(0),
	})
	gradientCache[key] = gradient
	return gradient
end

function Theme.FreshGradient(topColor, bottomColor, rotation)
	return Util.New("UIGradient", {
		Color = ColorSequence.new(topColor or Color3.fromRGB(255, 255, 255), bottomColor or Color3.fromRGB(200, 200, 200)),
		Rotation = rotation or 90,
	})
end

-- Three-stop gradient used on the console chrome.
function Theme.ChromeGradient()
	return Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 50)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(24, 24, 32)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 16, 22)),
		}),
		Rotation = 90,
	})
end

AnnouncementPanel.Theme = Theme

--// ==========================================================================
--// SECTION 4  ::  AUDIO
--// Sounds are optional. An empty ID means "stay silent" - never guess an asset.
--// ==========================================================================

local Audio = {}

local soundCache = {}
local lastPlayed = {}

function Audio.ResolveId(name)
	if type(name) ~= "string" or name == "" then
		return ""
	end
	-- Direct asset id.
	if Util.StartsWith(name, "rbxasset") or tonumber(name) then
		return name
	end
	if CONFIG.Sounds.Library and CONFIG.Sounds.Library[name] then
		return tostring(CONFIG.Sounds.Library[name])
	end
	if CONFIG.Sounds[name] and type(CONFIG.Sounds[name]) == "string" then
		return CONFIG.Sounds[name]
	end
	return ""
end

function Audio.IsEnabled()
	return CONFIG.Sounds.Enabled == true
end

-- Debounce so a spam of banners cannot machine-gun the same sound.
function Audio.Allowed(name, minGap)
	minGap = minGap or 0.35
	local now = os.clock()
	local previous = lastPlayed[name] or 0
	if now - previous < minGap then
		return false
	end
	lastPlayed[name] = now
	return true
end

-- Client-side local playback: only the local player hears it, no replication.
function Audio.PlayLocal(name, options)
	if not Audio.IsEnabled() then
		return false
	end
	options = options or {}
	local id = Audio.ResolveId(name)
	if id == "" then
		if CONFIG.Debug.WarnOnMissingSound and name ~= "" then
			Util.Debug("no sound id configured for", name)
		end
		return false
	end
	if not Audio.Allowed(name, options.MinGap) then
		return false
	end
	local ok, err = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = Util.Clamp(options.Volume or CONFIG.Sounds.Volume, 0, 4)
		sound.PlaybackSpeed = options.PlaybackSpeed or 1
		sound.Name = "AP_Sound_" .. tostring(name)
		SoundService:PlayLocalSound(sound)
		sound:Destroy()
	end)
	if not ok then
		Util.Debug("local sound failed:", id, err)
		return false
	end
	return true
end

-- Server-side playback: creates a real Sound in SoundService so every client
-- hears it through normal replication.
function Audio.PlayReplicated(name, options)
	if not Audio.IsEnabled() then
		return false
	end
	options = options or {}
	local id = Audio.ResolveId(name)
	if id == "" then
		return false
	end
	if not Audio.Allowed(name, options.MinGap) then
		return false
	end
	local ok, err = pcall(function()
		local sound = Instance.new("Sound")
		sound.Name = "AP_ReplicatedSound_" .. tostring(name)
		sound.SoundId = id
		sound.Volume = Util.Clamp(options.Volume or CONFIG.Sounds.Volume, 0, 4)
		sound.PlaybackSpeed = options.PlaybackSpeed or 1
		sound.Looped = false
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, (options.Lifetime or 8) + 2)
	end)
	if not ok then
		Util.Debug("replicated sound failed:", id, err)
		return false
	end
	return true
end

function Audio.Play(name, options)
	if IS_SERVER then
		return Audio.PlayReplicated(name, options)
	end
	return Audio.PlayLocal(name, options)
end

-- Pre-warms the sound cache so the first announcement is not silent.
function Audio.Preload()
	local ids = {}
	for key, value in pairs(CONFIG.Sounds) do
		if type(value) == "string" and value ~= "" then
			table.insert(ids, value)
		end
		if key == "Library" and type(value) == "table" then
			for _, libraryValue in pairs(value) do
				if type(libraryValue) == "string" and libraryValue ~= "" then
					table.insert(ids, libraryValue)
				end
			end
		end
	end
	for _, id in ipairs(ids) do
		if not soundCache[id] then
			local ok = pcall(function()
				local sound = Instance.new("Sound")
				sound.SoundId = id
				sound.Name = "AP_Preload"
				sound.Parent = SoundService
				soundCache[id] = sound
			end)
			if not ok then
				Util.Debug("preload failed for", id)
			end
		end
	end
	return #ids
end

function Audio.UnloadPreloaded()
	for id, sound in pairs(soundCache) do
		Util.Destroy(sound)
		soundCache[id] = nil
	end
end

function Audio.AvailableSoundNames()
	local names = {}
	for key, value in pairs(CONFIG.Sounds) do
		if type(value) == "string" and value ~= "" then
			table.insert(names, key)
		end
	end
	if CONFIG.Sounds.Library then
		for key, value in pairs(CONFIG.Sounds.Library) do
			if type(value) == "string" and value ~= "" then
				table.insert(names, key)
			end
		end
	end
	table.sort(names)
	return names
end

AnnouncementPanel.Audio = Audio

--// ==========================================================================
--// SECTION 5  ::  RANKS & PERMISSIONS
--// Resolves a Player to a rank, caches expensive lookups, answers permission
--// questions. Works identically on the server and on the client.
--// ==========================================================================

local RankSystem = {}

RankSystem.Cache = {} -- [userId] = { Rank = string, At = number, Source = string }
RankSystem.SessionRanks = {} -- [userId] = rankName (set by :rank, cleared on leave)
RankSystem.GroupCache = {} -- [userId..groupId] = { Rank = n, At = clock }
RankSystem.GamepassCache = {} -- [userId..passId] = { Owns = bool, At = clock }

local RANK_LISTS = {
	{ Key = "Owner", List = "Owners" },
	{ Key = "Admin", List = "Admins" },
	{ Key = "Mod", List = "Mods" },
	{ Key = "Helper", List = "Helpers" },
	{ Key = "VIP", List = "VIPs" },
}

function RankSystem.GetCacheSeconds()
	return CONFIG.RankRules.CacheForSeconds or 20
end

function RankSystem.ClearCache()
	table.clear(RankSystem.Cache)
	table.clear(RankSystem.GroupCache)
	table.clear(RankSystem.GamepassCache)
end

function RankSystem.IsDenied(player)
	if not player then
		return true
	end
	local rules = CONFIG.RankRules
	if rules.DenyListUserIds and Util.TableContains(rules.DenyListUserIds, player.UserId) then
		return true
	end
	if rules.DenyListUsernames and Util.TableContains(rules.DenyListUsernames, player.Name) then
		return true
	end
	return false
end

function RankSystem.MatchesList(player, list)
	if type(list) ~= "table" or player == nil then
		return false
	end

	if list.UserIds and Util.TableContains(list.UserIds, player.UserId) then
		return true
	end

	if list.Usernames then
		for _, name in ipairs(list.Usernames) do
			if type(name) == "string" and name:lower() == player.Name:lower() then
				return true
			end
		end
	end

	if list.Teams and player.Team then
		local teamName = player.Team.Name
		for _, wanted in ipairs(list.Teams) do
			if type(wanted) == "string" and wanted:lower() == teamName:lower() then
				return true
			end
		end
	end

	if list.GroupRanks and #list.GroupRanks > 0 and IS_SERVER then
		for _, entry in ipairs(list.GroupRanks) do
			local groupId = tonumber(entry.GroupId)
			if groupId and groupId > 0 then
				local cacheKey = player.UserId .. "|" .. groupId
				local cached = RankSystem.GroupCache[cacheKey]
				local groupRank = nil
				if cached and (os.clock() - cached.At) < 300 then
					groupRank = cached.Rank
				else
					local ok, result = pcall(function()
						return player:GetRankInGroup(groupId)
					end)
					if ok and type(result) == "number" then
						groupRank = result
					else
						Util.Debug("GetRankInGroup failed for", groupId, result)
					end
					RankSystem.GroupCache[cacheKey] = { Rank = groupRank or 0, At = os.clock() }
				end
				local minRank = tonumber(entry.MinRank) or 1
				local maxRank = tonumber(entry.MaxRank) or 255
				if groupRank and groupRank >= minRank and groupRank <= maxRank then
					return true
				end
			end
		end
	end

	if list.Gamepasses and Util.CountKeys(list.Gamepasses) > 0 and MarketplaceService then
		for passId in pairs(list.Gamepasses) do
			local numericId = tonumber(passId)
			if numericId and numericId > 0 then
				local cacheKey = player.UserId .. "|" .. numericId
				local cached = RankSystem.GamepassCache[cacheKey]
				local owns = nil
				if cached and (os.clock() - cached.At) < 600 then
					owns = cached.Owns
				else
					local ok, result = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(player.UserId, numericId)
					end)
					owns = (ok and result == true)
					RankSystem.GamepassCache[cacheKey] = { Owns = owns, At = os.clock() }
					if not ok then
						Util.Debug("gamepass check failed:", result)
					end
				end
				if owns then
					return true
				end
			end
		end
	end

	return false
end

-- Attribute override lets other scripts (or your own game logic) promote a
-- player at runtime: player:SetAttribute("AP_Rank", "Admin")
function RankSystem.GetAttributeRank(player)
	if not CONFIG.RankRules.AllowAttributeOverride or player == nil then
		return nil
	end
	local attributeName = CONFIG.RankRules.AttributeName or "AP_Rank"
	local ok, value = pcall(function()
		return player:GetAttribute(attributeName)
	end)
	if ok and type(value) == "string" and value ~= "" then
		local resolved = Theme.GetRankName(value)
		if CONFIG.Ranks[resolved] then
			return resolved
		end
	end
	return nil
end

function RankSystem.SetSessionRank(player, rankName)
	if player == nil then
		return false
	end
	if rankName == nil or rankName == "" then
		RankSystem.SessionRanks[player.UserId] = nil
		RankSystem.Cache[player.UserId] = nil
		pcall(function()
			player:SetAttribute(CONFIG.Net.RankAttribute, nil)
			player:SetAttribute(CONFIG.Net.RankNameAttribute, nil)
		end)
		return true
	end
	local resolved = Theme.GetRankName(rankName)
	if not CONFIG.Ranks[resolved] then
		return false, "unknown rank: " .. tostring(rankName)
	end
	RankSystem.SessionRanks[player.UserId] = resolved
	RankSystem.Cache[player.UserId] = {
		Rank = resolved,
		At = os.clock(),
		Source = "session",
	}
	pcall(function()
		player:SetAttribute(CONFIG.Net.RankAttribute, resolved)
		local meta = Theme.GetRank(resolved)
		player:SetAttribute(CONFIG.Net.RankNameAttribute, meta.DisplayName or resolved)
	end)
	return true
end

function RankSystem.GetSessionRank(player)
	if player == nil then
		return nil
	end
	return RankSystem.SessionRanks[player.UserId]
end

-- The main entry point: what rank is this player?
function RankSystem.GetRank(player, forceRefresh)
	if player == nil then
		return "Player"
	end

	local cached = RankSystem.Cache[player.UserId]
	if cached and not forceRefresh then
		local ttl = RankSystem.GetCacheSeconds()
		if ttl <= 0 or (os.clock() - cached.At) < ttl then
			return cached.Rank
		end
	end

	local resolved = "Player"
	local source = "default"

	if RankSystem.IsDenied(player) then
		resolved = "Player"
		source = "denylist"
	else
		-- 1. Studio convenience: everyone is Owner while testing.
		if IS_STUDIO and CONFIG.RankRules.StudioEveryoneIsOwner then
			resolved = "Owner"
			source = "studio"
		end

		-- 2. The place owner is always an Owner unless that is disabled.
		if resolved == "Player" and CONFIG.RankRules.GameOwnerIsOwner then
			local ok, creatorId = pcall(function()
				return game.CreatorId
			end)
			if ok and creatorId and creatorId == player.UserId and game.CreatorType == Enum.CreatorType.User then
				resolved = "Owner"
				source = "creator"
			end
		end

		-- 3. Session rank set by :rank
		if resolved == "Player" then
			local session = RankSystem.SessionRanks[player.UserId]
			if session and CONFIG.Ranks[session] then
				resolved = session
				source = "session"
			end
		end

		-- 4. Configured lists, highest rank first.
		if resolved == "Player" then
			for _, entry in ipairs(RANK_LISTS) do
				local list = CONFIG[entry.List]
				if list and RankSystem.MatchesList(player, list) then
					resolved = entry.Key
					source = "list:" .. entry.List
					break
				end
			end
		end

		-- 5. Attribute override beats everything (except the deny list).
		local attributeRank = RankSystem.GetAttributeRank(player)
		if attributeRank then
			resolved = attributeRank
			source = "attribute"
		end
	end

	RankSystem.Cache[player.UserId] = {
		Rank = resolved,
		At = os.clock(),
		Source = source,
	}

	if CONFIG.Debug.PrintRankResolution then
		Util.Debug("rank", player.Name, "=>", resolved, "(" .. source .. ")")
	end

	-- Replicate the rank to the client half so its console knows what to show.
	if IS_SERVER then
		pcall(function()
			player:SetAttribute(CONFIG.Net.RankAttribute, resolved)
			player:SetAttribute(CONFIG.Net.RankNameAttribute, Theme.GetRank(resolved).DisplayName or resolved)
		end)
	end

	return resolved
end

function RankSystem.GetMeta(player)
	local rankName = RankSystem.GetRank(player)
	return rankName, Theme.GetRank(rankName)
end

function RankSystem.IsStaff(player)
	local rankName = RankSystem.GetRank(player)
	local order = Theme.GetRank(rankName).Order or 0
	return order >= (Theme.GetRank("Helper").Order or 30)
end

function RankSystem.IsAtLeast(player, rankName)
	local target = Theme.GetRank(rankName)
	local actual = Theme.GetRank(RankSystem.GetRank(player))
	return (actual.Order or 0) >= (target.Order or 0)
end

function RankSystem.GetOrder(rankName)
	return Theme.GetRank(rankName).Order or 0
end

-- Permission check: rank.Permissions contains the command name or "*".
function RankSystem.Can(player, commandName)
	local rankName = RankSystem.GetRank(player)
	local meta = Theme.GetRank(rankName)
	local permissions = meta.Permissions or {}
	for _, permission in ipairs(permissions) do
		if permission == "*" or permission == commandName then
			return true
		end
	end
	return false
end

function RankSystem.CanUseChaos(player)
	local meta = Theme.GetRank(RankSystem.GetRank(player))
	return meta.CanUseChaos == true
end

function RankSystem.MaxDuration(player)
	local meta = Theme.GetRank(RankSystem.GetRank(player))
	return meta.MaxDuration or LIMITS.DefaultDuration
end

function RankSystem.AllowedCommands(player)
	local rankName = RankSystem.GetRank(player)
	local meta = Theme.GetRank(rankName)
	local permissions = meta.Permissions or {}
	local result = {}
	for _, permission in ipairs(permissions) do
		table.insert(result, permission)
	end
	return result
end

function RankSystem.GetPlayersWithRank(rankName, includeHigher)
	local results = {}
	local targetOrder = RankSystem.GetOrder(rankName)
	for _, player in ipairs(Players:GetPlayers()) do
		local order = RankSystem.GetOrder(RankSystem.GetRank(player))
		if includeHigher then
			if order >= targetOrder and targetOrder > 0 then
				table.insert(results, player)
			end
		elseif order == targetOrder then
			table.insert(results, player)
		end
	end
	return results
end

function RankSystem.GetStaffPlayers()
	local results = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if RankSystem.IsStaff(player) then
			table.insert(results, player)
		end
	end
	return results
end

function RankSystem.CountByRank()
	local counts = {}
	for name in pairs(CONFIG.Ranks) do
		counts[name] = 0
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local rankName = RankSystem.GetRank(player)
		counts[rankName] = (counts[rankName] or 0) + 1
	end
	return counts
end

function RankSystem.OnPlayerAdded(player)
	if player == nil then
		return
	end
	RankSystem.Cache[player.UserId] = nil
	local rankName = RankSystem.GetRank(player, true)
	local meta = Theme.GetRank(rankName)
	Util.Debug("player joined:", player.Name, "rank:", rankName)
	return rankName, meta
end

function RankSystem.OnPlayerRemoving(player)
	if player == nil then
		return
	end
	RankSystem.Cache[player.UserId] = nil
	RankSystem.SessionRanks[player.UserId] = nil
end

function RankSystem.BadgeFor(player)
	local meta = Theme.GetRank(RankSystem.GetRank(player))
	return meta.Badge or ""
end

function RankSystem.Describe(player)
	local rankName = RankSystem.GetRank(player)
	local meta = Theme.GetRank(rankName)
	return {
		Name = player and player.Name or "?",
		DisplayName = player and player.DisplayName or "?",
		UserId = player and player.UserId or 0,
		Rank = rankName,
		RankDisplay = meta.DisplayName or rankName,
		Badge = meta.Badge or "",
		Tag = meta.ChatTag or "",
		Order = meta.Order or 0,
	}
end

AnnouncementPanel.RankSystem = RankSystem

--// ==========================================================================
--// SECTION 6  ::  MESSAGE FILTERING
--// Anything that reaches a screen goes through here first.
--// ==========================================================================

local MessageFilter = {}

function MessageFilter.Normalize(text)
	if type(text) ~= "string" then
		return ""
	end
	local result = text
	if CONFIG.Moderation.StripRichText then
		result = Util.SanitizeRichText(result)
	end
	-- Collapse runs of whitespace and drop control characters.
	result = result:gsub("[%c]", " ")
	result = result:gsub("%s+", " ")
	result = Util.Trim(result)
	return result
end

function MessageFilter.EnforceLength(text, maxLength)
	maxLength = maxLength or LIMITS.MaxMessageLength
	local source = tostring(text or "")
	if #source <= maxLength then
		return source, false
	end
	return Util.Truncate(source, maxLength, "..."), true
end

-- Cheap local word filter. Only used when TextService is unavailable or fails.
function MessageFilter.FallbackCensor(text)
	if not CONFIG.Moderation.FallbackCensor then
		return text
	end
	local result = tostring(text)
	local replacement = CONFIG.Moderation.CensoredReplacement or "####"
	local maskChar = replacement:sub(1, 1)
	if maskChar == "" then
		maskChar = "#"
	end
	for _, word in ipairs(CONFIG.Moderation.BlockedWords or {}) do
		if type(word) == "string" and word ~= "" then
			-- Build a case-insensitive literal pattern: each letter matches
			-- both its lower and upper form, everything else is escaped.
			local pattern = ""
			for index = 1, #word do
				local char = word:sub(index, index)
				local upper = char:upper()
				local lower = char:lower()
				if upper ~= lower then
					pattern ..= "[" .. Util.EscapePattern(lower) .. Util.EscapePattern(upper) .. "]"
				else
					pattern ..= Util.EscapePattern(char)
				end
			end
			local ok, replaced = pcall(function()
				return (result:gsub(pattern, function(match)
					return string.rep(maskChar, #match)
				end))
			end)
			if ok and type(replaced) == "string" then
				result = replaced
			end
		end
	end
	return result
end

function MessageFilter.IsBlocked(text)
	if type(text) ~= "string" then
		return false, nil
	end
	local lowered = text:lower()
	for _, word in ipairs(CONFIG.Moderation.BlockedWords or {}) do
		if type(word) == "string" and word ~= "" and lowered:find(word:lower(), 1, true) then
			return true, word
		end
	end
	return false, nil
end

-- The real filter. Server only: TextService requires server security.
function MessageFilter.FilterBroadcast(fromPlayer, text)
	local normalized = MessageFilter.Normalize(text)
	if normalized == "" then
		return ""
	end
	if not CONFIG.Moderation.FilterBroadcastMessages or not IS_SERVER then
		return MessageFilter.FallbackCensor(normalized)
	end
	local userId = fromPlayer and fromPlayer.UserId or 0
	local ok, result = pcall(function()
		local filterObject = TextService:FilterStringAsync(
			normalized,
			userId,
			Enum.TextFilterContext.PublicChat
		)
		if filterObject == nil then
			return nil
		end
		local broadcast = filterObject:GetNonChatStringForBroadcastAsync()
		return broadcast
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	if not ok then
		Util.Debug("TextService filter failed, using fallback:", result)
	end
	return MessageFilter.FallbackCensor(normalized)
end

-- Per-audience filtering (used when an announcement targets one player).
function MessageFilter.FilterForPlayer(fromPlayer, text, targetPlayer)
	local normalized = MessageFilter.Normalize(text)
	if normalized == "" then
		return ""
	end
	if not CONFIG.Moderation.FilterBroadcastMessages or not IS_SERVER or targetPlayer == nil then
		return MessageFilter.FallbackCensor(normalized)
	end
	local ok, result = pcall(function()
		local filterObject = TextService:FilterStringAsync(
			normalized,
			fromPlayer and fromPlayer.UserId or 0,
			Enum.TextFilterContext.PublicChat
		)
		if filterObject == nil then
			return nil
		end
		return filterObject:GetNonChatStringForUserAsync(targetPlayer.UserId)
	end)
	if ok and type(result) == "string" and result ~= "" then
		return result
	end
	return MessageFilter.FallbackCensor(normalized)
end

function MessageFilter.Prepare(text, maxLength)
	local normalized = MessageFilter.Normalize(text)
	local truncated, wasTruncated = MessageFilter.EnforceLength(normalized, maxLength)
	return truncated, wasTruncated
end

AnnouncementPanel.MessageFilter = MessageFilter

--// ==========================================================================
--// SECTION 7  ::  CHAT BRIDGE
--// Sends messages into Roblox chat (system lines) on either side.
--// ==========================================================================

local ChatBridge = {}

ChatBridge.LegacyChannelReady = false
ChatBridge.TextChannel = nil
ChatBridge.RemoteBridge = nil -- set by Net when the client half is present

local function getTextChannel()
	if ChatBridge.TextChannel and ChatBridge.TextChannel.Parent then
		return ChatBridge.TextChannel
	end
	if TextChatService == nil then
		return nil
	end
	local ok, channel = pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		if channels == nil then
			return nil
		end
		return channels:FindFirstChild("RBXGeneral")
	end)
	if ok and channel then
		ChatBridge.TextChannel = channel
		return channel
	end
	return nil
end

-- Prints a system line into chat for everyone in the server.
function ChatBridge.SystemMessageAll(text, prefix)
	if type(text) ~= "string" or text == "" then
		return false
	end
	local line = text
	if prefix and prefix ~= "" then
		line = prefix .. " " .. text
	end

	if IS_SERVER then
		local channel = getTextChannel()
		if channel then
			-- Modern API name first, older "Async" spelling as a fallback.
			local ok = pcall(function()
				channel:DisplaySystemMessage(line)
			end)
			if not ok then
				ok = pcall(function()
					channel:DisplaySystemMessageAsync(line)
				end)
			end
			if ok then
				ChatBridge.LegacyChannelReady = true
				return true
			end
			Util.Debug("DisplaySystemMessage failed for", channel:GetFullName())
		end
		-- Legacy chat / no channel: ask connected client halves to print it.
		if ChatBridge.RemoteBridge then
			pcall(function()
				ChatBridge.RemoteBridge:FireAllClients("SystemChat", { Text = line, Color = "#FFFFFF" })
			end)
			return true
		end
		return false
	end

	-- Client side: legacy chat system message.
	local ok = pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = line,
			Color = Color3.fromRGB(255, 220, 120),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
		})
	end)
	return ok
end

-- A system line for one player only.
function ChatBridge.SystemMessageToPlayer(player, text, color)
	if player == nil or type(text) ~= "string" or text == "" then
		return false
	end
	if IS_SERVER then
		if ChatBridge.RemoteBridge then
			local ok = pcall(function()
				ChatBridge.RemoteBridge:FireClient(player, "SystemChat", {
					Text = text,
					Color = Util.ColorToHex(color or Color3.fromRGB(255, 220, 120)),
				})
			end)
			if ok then
				return true
			end
		end
		-- No client half installed: fall back to an in-world toast.
		if AnnouncementPanel.Renderer and AnnouncementPanel.Renderer.PushToast then
			AnnouncementPanel.Renderer.PushToast(player, {
				Message = text,
				Title = CONFIG.SystemName,
				Rank = "System",
				Duration = 5,
				Color = Util.ColorToHex(color or Color3.fromRGB(180, 200, 255)),
			})
		end
		return false
	end

	local ok = pcall(function()
		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text = text,
			Color = color or Color3.fromRGB(255, 220, 120),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
		})
	end)
	return ok
end

-- Sets up the server-side hook that swallows chat commands before they are
-- displayed. Falls back to Player.Chatted when the new chat API is missing.
function ChatBridge.InstallServerCommandHook(handler)
	if type(handler) ~= "function" then
		return false
	end

	local installed = false

	-- New chat: TextChannel.OnIncomingMessage runs on the server and lets us
	-- suppress the message so ":announce hi" never appears in the chat window.
	if TextChatService then
		local ok = pcall(function()
			local channels = TextChatService:WaitForChild("TextChannels", 6)
			if channels == nil then
				return
			end
			local general = channels:FindFirstChild("RBXGeneral")
			if general == nil then
				general = channels.ChildAdded:Wait()
			end
			if general and general:IsA("TextChannel") then
				ChatBridge.TextChannel = general
				general.OnIncomingMessage = function(message)
					local properties = Instance.new("TextChatMessageProperties")
					if message and message.TextSource then
						local player = Players:GetPlayerByUserId(message.TextSource.UserId)
						if player then
							local handled = handler(player, message.Text, "channel")
							if handled then
								properties.ShouldDeliver = false
								return properties
							end
						end
					end
					return properties
				end
				installed = true
			end
		end)
		if not ok then
			Util.Debug("OnIncomingMessage hook unavailable, using Player.Chatted only")
		end
	end

	-- Legacy chat (and a safety net): Player.Chatted still fires on the server.
	Util.Track(Players.PlayerChatted:Connect(function(player, message)
		handler(player, message, "chatted")
	end), "ChatBridge.PlayerChatted")

	-- Also hook PlayerChatted-style Chatted per player for extra safety on
	-- experiences that swap chat systems at runtime.
	for _, player in ipairs(Players:GetPlayers()) do
		Util.Track(player.Chatted:Connect(function(message)
			handler(player, message, "chatted")
		end), "ChatBridge.Player." .. player.Name)
	end

	Util.Track(Players.PlayerAdded:Connect(function(player)
		Util.Track(player.Chatted:Connect(function(message)
			handler(player, message, "chatted")
		end), "ChatBridge.Player." .. player.Name)
	end), "ChatBridge.PlayerAdded")

	return installed
end

AnnouncementPanel.ChatBridge = ChatBridge

--// ==========================================================================
--// SECTION 8  ::  NETWORKING
--// The server builds the remotes, the client finds them. If the client cannot
--// find them within CONFIG.Solo.WaitForServerSeconds it goes into SOLO mode.
--// ==========================================================================

local Net = {}

Net.Folder = nil
Net.Announcement = nil -- server -> client(s): "render this"
Net.Console = nil -- client -> server: "staff pressed a button"
Net.Handshake = nil -- client -> server: "I exist, what is my rank?"
Net.Ack = nil -- server -> client: chat/system messages, small replies
Net.ServerActive = false

local REMOTE_NAMES = {
	Announcement = CONFIG.Net.AnnouncementEvent,
	Console = CONFIG.Net.ConsoleEvent,
	Handshake = CONFIG.Net.HandshakeEvent,
	Ack = CONFIG.Net.AckEvent,
}

local function createRemote(kind, name, parent)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(kind) then
		return existing
	end
	if existing then
		Util.Destroy(existing)
	end
	return Util.New(kind, {
		Name = name,
		Parent = parent,
	})
end

-- Server: build the whole networking folder from scratch.
function Net.SetupServer()
	local folder = ReplicatedStorage:FindFirstChild(CONFIG.Net.FolderName)
	if folder == nil then
		folder = Util.New("Folder", {
			Name = CONFIG.Net.FolderName,
			Parent = ReplicatedStorage,
		})
	end
	Net.Folder = folder

	Net.Announcement = createRemote("RemoteEvent", REMOTE_NAMES.Announcement, folder)
	Net.Console = createRemote("RemoteEvent", REMOTE_NAMES.Console, folder)
	Net.Handshake = createRemote("RemoteEvent", REMOTE_NAMES.Handshake, folder)
	Net.Ack = createRemote("RemoteEvent", REMOTE_NAMES.Ack, folder)

	-- Marker attribute the client half looks for to decide SOLO vs COMPANION.
	pcall(function()
		folder:SetAttribute(CONFIG.Net.ServerActiveAttribute, true)
		folder:SetAttribute("AP_Version", CONFIG.Version)
		folder:SetAttribute("AP_JobId", game.JobId or "")
		folder:SetAttribute("AP_PlaceId", game.PlaceId or 0)
	end)

	Net.ServerActive = true
	ChatBridge.RemoteBridge = Net.Ack
	Util.Debug("server remotes ready in", folder:GetFullName())
	return folder
end

-- Client: wait for the server half to show up.
function Net.SetupClient(timeout)
	timeout = timeout or CONFIG.Solo.WaitForServerSeconds or 6
	local folder = ReplicatedStorage:FindFirstChild(CONFIG.Net.FolderName)
	if folder == nil then
		local deadline = os.clock() + timeout
		while os.clock() < deadline do
			folder = ReplicatedStorage:FindFirstChild(CONFIG.Net.FolderName)
			if folder then
				break
			end
			task.wait(CONFIG.Net.RetryWait or 0.5)
		end
	end
	if folder == nil then
		Net.ServerActive = false
		Net.Folder = nil
		return false
	end
	Net.Folder = folder
	Net.Announcement = folder:FindFirstChild(REMOTE_NAMES.Announcement)
	Net.Console = folder:FindFirstChild(REMOTE_NAMES.Console)
	Net.Handshake = folder:FindFirstChild(REMOTE_NAMES.Handshake)
	Net.Ack = folder:FindFirstChild(REMOTE_NAMES.Ack)

	local active = false
	pcall(function()
		active = folder:GetAttribute(CONFIG.Net.ServerActiveAttribute) == true
	end)
	Net.ServerActive = active and Net.Announcement ~= nil
	return Net.ServerActive
end

function Net.IsServerActive()
	return Net.ServerActive == true
end

-- Safe fire helpers. Every one of them is pcall'd because remotes disappear
-- when a server shuts down mid-call.
function Net.FireClient(player, action, payload)
	if not IS_SERVER or Net.Announcement == nil or player == nil then
		return false
	end
	local ok, err = pcall(function()
		Net.Announcement:FireClient(player, action, payload)
	end)
	if not ok then
		Util.Debug("FireClient failed:", err)
	end
	return ok
end

function Net.FireAllClients(action, payload)
	if not IS_SERVER or Net.Announcement == nil then
		return false
	end
	local ok, err = pcall(function()
		Net.Announcement:FireAllClients(action, payload)
	end)
	if not ok then
		Util.Debug("FireAllClients failed:", err)
	end
	return ok
end

function Net.FirePlayers(players, action, payload)
	if type(players) ~= "table" then
		return 0
	end
	local sent = 0
	for _, player in ipairs(players) do
		if Net.FireClient(player, action, payload) then
			sent += 1
		end
	end
	return sent
end

function Net.FireServer(action, payload)
	if IS_SERVER or Net.Console == nil then
		return false
	end
	local ok, err = pcall(function()
		Net.Console:FireServer(action, payload)
	end)
	if not ok then
		Util.Debug("FireServer failed:", err)
	end
	return ok
end

function Net.AckClient(player, payload)
	if not IS_SERVER or Net.Ack == nil or player == nil then
		return false
	end
	local ok = pcall(function()
		Net.Ack:FireClient(player, payload)
	end)
	return ok
end

-- Client -> server: "I exist, here is my version, what is my rank?"
-- NOTE: this is deliberately *not* called Net.Handshake - that field holds the
-- RemoteEvent instance itself, and SetupClient/SetupServer overwrite it.
function Net.SendHandshake(payload)
	if IS_SERVER or Net.Handshake == nil then
		return false
	end
	local ok = pcall(function()
		Net.Handshake:FireServer(payload or {})
	end)
	return ok
end

AnnouncementPanel.Net = Net

--// ==========================================================================
--// SECTION 9  ::  RUNTIME STATE
--// One table that holds everything the system knows right now.
--// ==========================================================================

local State = {}

State.StartedAt = os.clock()
State.StartedUnix = os.time()
State.ServerId = Util.ShortId(6)
State.Mode = "unknown" -- "server" | "companion" | "solo"

State.Active = {} -- [id] = announcement payload
State.Order = {} -- ordered list of ids, newest last
State.History = {} -- newest first
State.Roots = {} -- [player] = ScreenGui (server) or the single client root
State.Toasts = {} -- [player] = { ids }
State.Countdowns = {}
State.Ticker = { Text = "", Active = false }

State.Muted = {} -- [userId] = { By = name, Reason = string, Until = number }
State.SessionRanks = {}
State.Scheduled = {} -- [id] = { Every, NextRun, Payload }

State.Chaos = {
	Active = false,
	StartedAt = 0,
	ExpiresAt = 0,
	StartedBy = "",
	Count = 0,
}

State.Stats = {
	Announcements = 0,
	Alerts = 0,
	Toasts = 0,
	Tickers = 0,
	Countdowns = 0,
	CommandsRun = 0,
	CommandsDenied = 0,
	CommandsUnknown = 0,
	ChaosActivations = 0,
	MOTDUpdates = 0,
	Mutes = 0,
	Kicks = 0,
	Effects = 0,
	Errors = 0,
}

State.MOTD = {
	Enabled = CONFIG.MOTD.Enabled,
	Title = CONFIG.MOTD.Title,
	Message = CONFIG.MOTD.Message,
	Style = CONFIG.MOTD.Style,
	Duration = CONFIG.MOTD.Duration,
	UpdatedBy = "",
	UpdatedAt = 0,
	Seen = {}, -- [userId] = true
}

State.Metrics = {
	RenderCalls = 0,
	AverageRenderTime = 0,
	PeakBanners = 0,
	LastRenderAt = 0,
}

function State.Uptime()
	return os.clock() - State.StartedAt
end

function State.UptimeText()
	return Util.FormatClock(State.Uptime())
end

function State.Bump(key, amount)
	amount = amount or 1
	State.Stats[key] = (State.Stats[key] or 0) + amount
end

function State.AddActive(id, payload)
	if id == nil then
		return
	end
	State.Active[id] = payload
	if not Util.TableContains(State.Order, id) then
		table.insert(State.Order, id)
	end
	local count = #State.Order
	if count > State.Metrics.PeakBanners then
		State.Metrics.PeakBanners = count
	end
end

function State.RemoveActive(id)
	if id == nil then
		return
	end
	State.Active[id] = nil
	local index = Util.TableIndexOf(State.Order, id)
	if index > 0 then
		table.remove(State.Order, index)
	end
end

function State.ActiveCount()
	return #State.Order
end

function State.ClearActive()
	local ids = Util.ShallowCopy(State.Order)
	for _, id in ipairs(ids) do
		State.RemoveActive(id)
	end
	table.clear(State.Order)
	table.clear(State.Active)
end

function State.AddHistory(entry)
	if type(entry) ~= "table" then
		return
	end
	entry.Index = #State.History + 1
	table.insert(State.History, 1, entry)
	while #State.History > LIMITS.MaxHistoryEntries do
		table.remove(State.History)
	end
end

function State.GetHistory(limit)
	limit = limit or 10
	local result = {}
	for index = 1, math.min(limit, #State.History) do
		table.insert(result, State.History[index])
	end
	return result
end

function State.IsMuted(player)
	if player == nil then
		return false
	end
	local entry = State.Muted[player.UserId]
	if entry == nil then
		return false
	end
	if entry.Until and entry.Until > 0 and os.time() > entry.Until then
		State.Muted[player.UserId] = nil
		return false
	end
	return true
end

function State.Mute(player, byName, reason, duration)
	if player == nil then
		return false
	end
	State.Muted[player.UserId] = {
		By = byName or "system",
		Reason = reason or "",
		Until = (duration and duration > 0) and (os.time() + duration) or 0,
		At = os.time(),
	}
	State.Bump("Mutes")
	return true
end

function State.Unmute(player)
	if player == nil then
		return false
	end
	local existed = State.Muted[player.UserId] ~= nil
	State.Muted[player.UserId] = nil
	return existed
end

function State.MutedList()
	local result = {}
	for userId, entry in pairs(State.Muted) do
		local player = Players:GetPlayerByUserId(userId)
		table.insert(result, {
			UserId = userId,
			Name = player and player.Name or "(left)",
			By = entry.By,
			Reason = entry.Reason,
			Until = entry.Until,
		})
	end
	return result
end

function State.Serialize()
	return {
		MOTD = {
			Enabled = State.MOTD.Enabled,
			Title = State.MOTD.Title,
			Message = State.MOTD.Message,
			Style = State.MOTD.Style,
			Duration = State.MOTD.Duration,
			UpdatedBy = State.MOTD.UpdatedBy,
		},
		Stats = Util.DeepCopy(State.Stats),
		Ticker = { Text = State.Ticker.Text },
		Version = CONFIG.Version,
		SavedAt = os.time(),
	}
end

function State.Deserialize(data)
	if type(data) ~= "table" then
		return false
	end
	if type(data.MOTD) == "table" then
		State.MOTD.Enabled = data.MOTD.Enabled ~= false
		State.MOTD.Title = data.MOTD.Title or CONFIG.MOTD.Title
		State.MOTD.Message = data.MOTD.Message or CONFIG.MOTD.Message
		State.MOTD.Style = data.MOTD.Style or CONFIG.MOTD.Style
		State.MOTD.Duration = tonumber(data.MOTD.Duration) or CONFIG.MOTD.Duration
		State.MOTD.UpdatedBy = data.MOTD.UpdatedBy or ""
	end
	if type(data.Stats) == "table" then
		for key, value in pairs(data.Stats) do
			if type(value) == "number" then
				State.Stats[key] = (State.Stats[key] or 0) + value
			end
		end
	end
	if type(data.Ticker) == "table" and type(data.Ticker.Text) == "string" and data.Ticker.Text ~= "" then
		State.Ticker.Text = data.Ticker.Text
	end
	return true
end

AnnouncementPanel.State = State

--// ==========================================================================
--// SECTION 10  ::  HISTORY
--// ==========================================================================

local History = {}

function History.Record(payload, extra)
	if type(payload) ~= "table" then
		return nil
	end
	local entry = {
		Id = payload.Id or Util.NewGuid(),
		Kind = payload.Kind or "Banner",
		Title = payload.Title or "",
		Message = payload.Message or "",
		Rank = payload.Rank or "Player",
		SenderName = payload.SenderName or "System",
		SenderId = payload.SenderId or 0,
		Style = payload.Style or CONFIG.DefaultStyle,
		Duration = tonumber(payload.Duration) or LIMITS.DefaultDuration,
		Color = payload.Color or nil,
		Timestamp = os.time(),
		Clock = os.clock(),
		Audience = payload.Audience or "all",
		AudienceCount = tonumber(payload.AudienceCount) or 0,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			entry[key] = value
		end
	end
	State.AddHistory(entry)
	Util.Debug("history +", entry.Kind, entry.Id, entry.Message)
	return entry
end

function History.FormatLine(entry)
	if type(entry) ~= "table" then
		return ""
	end
	local meta = Theme.GetRank(entry.Rank or "Player")
	local time = os.date("%H:%M:%S", entry.Timestamp or os.time())
	local badge = meta.Badge or ""
	local sender = entry.SenderName or "?"
	local kind = entry.Kind or "Banner"
	local message = Util.Truncate(entry.Message or "", 90)
	return string.format("[%s] %s %s (%s) %s: %s",
		time, badge, tostring(sender), tostring(kind), tostring(meta.DisplayName or entry.Rank), message)
end

function History.FormatList(limit)
	limit = limit or 8
	local lines = {}
	local entries = State.GetHistory(limit)
	if #entries == 0 then
		table.insert(lines, "No announcements yet.")
		return lines
	end
	for index, entry in ipairs(entries) do
		table.insert(lines, string.format("%d. %s", index, History.FormatLine(entry)))
	end
	return lines
end

function History.Clear()
	table.clear(State.History)
	return true
end

function History.Search(query, limit)
	limit = limit or 10
	local results = {}
	if type(query) ~= "string" or query == "" then
		return State.GetHistory(limit)
	end
	local lowered = query:lower()
	for _, entry in ipairs(State.History) do
		local haystack = string.lower((entry.Message or "") .. " " .. (entry.Title or "") .. " " .. (entry.SenderName or ""))
		if haystack:find(lowered, 1, true) then
			table.insert(results, entry)
			if #results >= limit then
				break
			end
		end
	end
	return results
end

function History.BySender(name, limit)
	limit = limit or 10
	local results = {}
	if type(name) ~= "string" then
		return results
	end
	local lowered = name:lower()
	for _, entry in ipairs(State.History) do
		if tostring(entry.SenderName or ""):lower() == lowered then
			table.insert(results, entry)
			if #results >= limit then
				break
			end
		end
	end
	return results
end

function History.ToPayloadList(limit)
	limit = limit or LIMITS.MaxHistoryEntries
	local result = {}
	for index = 1, math.min(limit, #State.History) do
		local entry = State.History[index]
		table.insert(result, {
			Id = entry.Id,
			Kind = entry.Kind,
			Title = entry.Title,
			Message = entry.Message,
			Rank = entry.Rank,
			SenderName = entry.SenderName,
			Style = entry.Style,
			Timestamp = entry.Timestamp,
		})
	end
	return result
end

AnnouncementPanel.History = History

--// ==========================================================================
--// SECTION 11  ::  PERSISTENCE  (DataStore, fully optional)
--// ==========================================================================

local Persistence = {}

Persistence.Store = nil
Persistence.Ready = false
Persistence.LastSave = 0
Persistence.SaveCount = 0
Persistence.LoadCount = 0

function Persistence.ShouldRun()
	if not CONFIG.Persistence.Enabled then
		return false
	end
	if IS_STUDIO and not CONFIG.Persistence.AllowInStudio then
		return false
	end
	if DataStoreService == nil then
		return false
	end
	return true
end

function Persistence.GetStore()
	if Persistence.Store then
		return Persistence.Store
	end
	if not Persistence.ShouldRun() then
		return nil
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(CONFIG.Persistence.DataStoreName)
	end)
	if ok and store then
		Persistence.Store = store
		Persistence.Ready = true
		Util.Debug("datastore ready:", CONFIG.Persistence.DataStoreName)
		return store
	end
	Util.Warn("DataStore unavailable:", store)
	return nil
end

function Persistence.Key(suffix)
	return tostring(CONFIG.Persistence.KeyPrefix or "Global") .. "_" .. tostring(suffix or "main")
end

function Persistence.Load()
	local store = Persistence.GetStore()
	if store == nil then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(Persistence.Key("state"))
	end)
	if ok and data ~= nil then
		Persistence.LoadCount += 1
		State.Deserialize(data)
		Util.Info("loaded saved announcement state")
		return data
	elseif not ok then
		Util.Warn("load failed:", data)
	end
	return nil
end

function Persistence.Save()
	local store = Persistence.GetStore()
	if store == nil then
		return false
	end
	local payload = State.Serialize()
	local ok, err = pcall(function()
		store:SetAsync(Persistence.Key("state"), payload)
	end)
	if ok then
		Persistence.SaveCount += 1
		Persistence.LastSave = os.clock()
		Util.Debug("state saved")
		return true
	end
	Util.Warn("save failed:", err)
	return false
end

function Persistence.StartAutoSave()
	if not Persistence.ShouldRun() then
		return false
	end
	local interval = math.max(30, CONFIG.Persistence.SaveInterval or 120)
	Util.Spawn(function()
		while true do
			task.wait(interval)
			Persistence.Save()
		end
	end, "Persistence.AutoSave")

	if CONFIG.Persistence.SaveOnShutdown then
		local ok = pcall(function()
			game:BindToClose(function()
				Persistence.Save()
				task.wait(1)
			end)
		end)
		if not ok then
			Util.Debug("BindToClose unavailable")
		end
	end
	return true
end

AnnouncementPanel.Persistence = Persistence

--// ==========================================================================
--// SECTION 12  ::  SCHEDULER
--// Recurring announcements, uptime pings and staff-queued events.
--// ==========================================================================

local Scheduler = {}

Scheduler.Running = false
Scheduler.Connection = nil

function Scheduler.Add(payload, everySeconds, startDelay)
	if type(payload) ~= "table" then
		return nil, "invalid payload"
	end
	everySeconds = tonumber(everySeconds)
	if everySeconds == nil or everySeconds < 15 then
		return nil, "interval must be at least 15 seconds"
	end
	if Util.CountKeys(State.Scheduled) >= LIMITS.MaxScheduledEvents then
		return nil, "too many scheduled events (max " .. LIMITS.MaxScheduledEvents .. ")"
	end
	local id = payload.Id or ("sched_" .. Util.ShortId(6))
	payload.Id = id
	State.Scheduled[id] = {
		Id = id,
		Every = everySeconds,
		NextRun = os.clock() + (startDelay or everySeconds),
		Payload = payload,
		CreatedAt = os.time(),
		Runs = 0,
		Enabled = true,
	}
	Util.Debug("scheduled", id, "every", everySeconds, "s")
	return id
end

function Scheduler.Remove(id)
	if State.Scheduled[id] then
		State.Scheduled[id] = nil
		return true
	end
	-- Allow removing by index for ":unschedule 2"
	local numeric = tonumber(id)
	if numeric then
		local index = 1
		for key in pairs(State.Scheduled) do
			if index == numeric then
				State.Scheduled[key] = nil
				return true
			end
			index += 1
		end
	end
	return false
end

function Scheduler.List()
	local result = {}
	for id, item in pairs(State.Scheduled) do
		table.insert(result, {
			Id = id,
			Every = item.Every,
			NextRunIn = math.max(0, item.NextRun - os.clock()),
			Runs = item.Runs,
			Message = item.Payload and item.Payload.Message or "",
			Title = item.Payload and item.Payload.Title or "",
			Style = item.Payload and item.Payload.Style or CONFIG.DefaultStyle,
		})
	end
	table.sort(result, function(a, b)
		return a.NextRunIn < b.NextRunIn
	end)
	return result
end

function Scheduler.Clear()
	table.clear(State.Scheduled)
end

function Scheduler.LoadFromConfig()
	if not CONFIG.Schedule.Enabled then
		return 0
	end
	local added = 0
	for _, item in ipairs(CONFIG.Schedule.Items or {}) do
		local every = tonumber(item.Every)
		if every and every >= 15 then
			local payload = {
				Kind = item.Kind or "Banner",
				Title = item.Title,
				Message = item.Message,
				Style = item.Style or CONFIG.DefaultStyle,
				Duration = tonumber(item.Duration) or LIMITS.DefaultDuration,
				Rank = item.Rank or "Owner",
				SenderName = item.SenderName or "Auto",
				Scheduled = true,
			}
			local id, err = Scheduler.Add(payload, every, CONFIG.Schedule.FirstTickDelay or 30)
			if id then
				added += 1
			else
				Util.Warn("schedule item rejected:", err)
			end
		end
	end
	return added
end

function Scheduler.Tick()
	local now = os.clock()
	for id, item in pairs(State.Scheduled) do
		if item.Enabled and now >= item.NextRun then
			item.NextRun = now + item.Every
			item.Runs += 1
			if AnnouncementPanel.Broadcaster then
				AnnouncementPanel.Broadcaster.Broadcast(item.Payload, {
					SilentHistory = false,
					Source = "scheduler",
				})
			end
			Util.Debug("scheduler fired", id)
		end
	end
end

function Scheduler.CheckUptimeAnnouncements()
	if not CONFIG.Schedule.Enabled then
		return
	end
	local minutesUp = math.floor(State.Uptime() / 60)
	for _, entry in ipairs(CONFIG.Schedule.UptimeAnnouncements or {}) do
		local at = tonumber(entry.AtMinutes)
		if at and minutesUp == at and not entry.__fired then
			entry.__fired = true
			if AnnouncementPanel.Broadcaster then
				AnnouncementPanel.Broadcaster.Broadcast({
					Kind = entry.Kind or "Banner",
					Title = entry.Title,
					Message = entry.Message,
					Style = entry.Style or CONFIG.DefaultStyle,
					Duration = tonumber(entry.Duration) or LIMITS.DefaultDuration,
					Rank = "Owner",
					SenderName = "System",
				}, { Source = "uptime" })
			end
		end
	end
end

function Scheduler.Start()
	if Scheduler.Running then
		return false
	end
	Scheduler.Running = true
	Util.Spawn(function()
		local tickRate = math.max(0.5, CONFIG.Schedule.TickRate or 1)
		local uptimeCheck = 0
		while Scheduler.Running do
			task.wait(tickRate)
			local ok, err = pcall(function()
				Scheduler.Tick()
			end)
			if not ok then
				Util.Warn("scheduler tick failed:", err)
				State.Bump("Errors")
			end
			uptimeCheck += tickRate
			if uptimeCheck >= 30 then
				uptimeCheck = 0
				pcall(Scheduler.CheckUptimeAnnouncements)
			end
		end
	end, "Scheduler.Loop")
	Util.Debug("scheduler started")
	return true
end

function Scheduler.Stop()
	Scheduler.Running = false
end

AnnouncementPanel.Scheduler = Scheduler

--// ==========================================================================
--// SECTION 13  ::  UI BUILDER
--// Pure construction. Every function returns instances; none of them animate
--// or make decisions. The Renderer drives what gets built and when.
--//
--// The same builder is used by the server (writing into each PlayerGui) and
--// by the client (writing into LocalPlayer.PlayerGui), which is why nothing
--// in here is allowed to touch LocalPlayer or the server-only APIs.
--// ==========================================================================

local UIBuilder = {}

UIBuilder.ROOT_NAME = "AnnouncementPanel"
UIBuilder.CLIENT_ROOT_NAME = "AnnouncementPanelClient"

local LAYER_ORDER = {
	Backdrop = 1,
	Vignette = 2,
	Confetti = 3,
	Alert = 4,
	Countdown = 5,
	TopStack = 6,
	Ticker = 7,
	Toasts = 8,
	MOTD = 9,
	Console = 20,
	FloatingButton = 30,
	Flash = 40,
}

--// ---------- primitives ----------------------------------------------------

function UIBuilder.Corner(radius, parent)
	return Util.New("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent,
	})
end

function UIBuilder.Stroke(color, thickness, transparency, parent)
	return Util.New("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIBuilder.Padding(top, bottom, left, right, parent)
	return Util.New("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		Parent = parent,
	})
end

-- Keys my builders understand but Instances do not. They configure helper
-- behaviour (corner radius, font weight, strokes) and must never be assigned
-- onto the instance itself, or Studio logs "X is not a valid property".
local NON_PROPERTIES = {
	FontWeight = true,
	CornerRadius = true,
	StrokeColor = true,
	StrokeThickness = true,
	StrokeTransparency = true,
	Children = true,
}

local function copyProps(props, base)
	base = base or {}
	for key, value in pairs(props or {}) do
		if not NON_PROPERTIES[key] then
			base[key] = value
		end
	end
	return base
end

function UIBuilder.Label(props)
	local base = {
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(245, 245, 250),
		TextSize = APPEAR.TextSize,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = APPEAR.UseRichText,
		Font = APPEAR.FallbackFont,
		ZIndex = 5,
	}
	copyProps(props, base)
	local label = Util.New("TextLabel", base)
	if props and props.FontWeight then
		Util.ApplyFont(label, props.FontWeight, props.TextSize)
	else
		Util.ApplyFont(label, "medium", base.TextSize)
	end
	return label
end

function UIBuilder.Button(props)
	local base = {
		BackgroundColor3 = Color3.fromRGB(46, 46, 60),
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "",
		TextColor3 = Color3.fromRGB(245, 245, 250),
		TextSize = 14,
		Font = APPEAR.FallbackFont,
		ZIndex = 22,
	}
	copyProps(props, base)
	local button = Util.New("TextButton", base)
	UIBuilder.Corner(props and props.CornerRadius or 8, button)
	if props and props.FontWeight then
		Util.ApplyFont(button, props.FontWeight, props.TextSize)
	end
	return button
end

function UIBuilder.Box(props)
	local base = {
		BackgroundColor3 = Color3.fromRGB(24, 24, 32),
		BorderSizePixel = 0,
		PlaceholderText = "",
		PlaceholderColor3 = Color3.fromRGB(140, 140, 155),
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 245),
		TextSize = 14,
		ClearTextOnFocus = false,
		Font = APPEAR.FallbackFont,
		ZIndex = 22,
	}
	copyProps(props, base)
	local box = Util.New("TextBox", base)
	UIBuilder.Corner(props and props.CornerRadius or 8, box)
	UIBuilder.Stroke(Color3.fromRGB(70, 70, 90), 1, 0.2, box)
	if props and props.FontWeight then
		Util.ApplyFont(box, props.FontWeight, props.TextSize)
	end
	return box
end

function UIBuilder.Frame(props)
	local base = {
		BackgroundColor3 = APPEAR.BaseColor,
		BorderSizePixel = 0,
		BackgroundTransparency = 0,
		ZIndex = 5,
	}
	copyProps(props, base)
	local frame = Util.New("Frame", base)
	if props and props.CornerRadius then
		UIBuilder.Corner(props.CornerRadius, frame)
	end
	if props and props.StrokeColor then
		UIBuilder.Stroke(props.StrokeColor, props.StrokeThickness or 1, props.StrokeTransparency or 0, frame)
	end
	return frame
end

--// ---------- responsive root -----------------------------------------------

-- The ScreenGui that everything lives inside. Built once per player (server)
-- or once per client (client install).
function UIBuilder.CreateRoot(options)
	options = options or {}
	local role = options.Role or (IS_SERVER and "server" or "client")
	local parent = options.Parent
	local guiName = (role == "client") and UIBuilder.CLIENT_ROOT_NAME or UIBuilder.ROOT_NAME

	local gui = Util.New("ScreenGui", {
		Name = guiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = options.DisplayOrder or 200,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = true,
		ClipToDeviceSafeArea = APPEAR.RespectSafeArea,
	})

	pcall(function()
		gui:SetAttribute("AP_Role", role)
		gui:SetAttribute("AP_Version", CONFIG.Version)
		gui:SetAttribute("AP_JobId", game.JobId or "")
	end)

	local scale = Util.New("UIScale", {
		Scale = options.Scale or 1,
		Name = "ResponsiveScale",
		Parent = gui,
	})

	local layers = Util.New("Frame", {
		Name = "Layers",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = gui,
	})

	local root = {
		Gui = gui,
		Layers = layers,
		Scale = scale,
		Role = role,
		Children = {},
		CreatedAt = os.clock(),
	}

	-- Backdrop: dims the whole screen behind alerts.
	root.Backdrop = UIBuilder.Frame({
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 6, 10),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = LAYER_ORDER.Backdrop,
		Parent = layers,
	})

	-- Flash: instant white / coloured hit used by alert effects.
	root.Flash = UIBuilder.Frame({
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = FX.FlashColor,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = LAYER_ORDER.Flash,
		Parent = layers,
	})

	-- Vignette: four gradient frames, no image assets required.
	root.Vignette = UIBuilder.BuildVignette(layers)

	-- Confetti layer: clipped so pieces never escape the screen.
	root.Confetti = UIBuilder.Frame({
		Name = "Confetti",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = true,
		ZIndex = LAYER_ORDER.Confetti,
		Parent = layers,
	})

	-- Top stack: the signature "message pinned to the top of the screen".
	root.TopStack = UIBuilder.Frame({
		Name = "TopStack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, APPEAR.TopbarOffset),
		Size = UDim2.new(0.62, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = LAYER_ORDER.TopStack,
		Parent = layers,
	})

	root.TopStackLayout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, APPEAR.BannerGap),
		Parent = root.TopStack,
	})

	-- A size constraint keeps banners sane on ultra-wide and phone screens.
	root.TopStackConstraint = Util.New("UISizeConstraint", {
		MinSize = Vector2.new(APPEAR.BannerMinWidth, 0),
		MaxSize = Vector2.new(APPEAR.BannerWidth + 120, math.huge),
		Parent = root.TopStack,
	})

	-- Ticker bar.
	root.Ticker = UIBuilder.BuildTicker(layers)

	-- Alert overlay.
	root.Alert = UIBuilder.BuildAlert(layers)

	-- Countdown overlay.
	root.Countdown = UIBuilder.BuildCountdown(layers)

	-- Toast stack (bottom-right).
	root.Toasts = UIBuilder.Frame({
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = LAYER_ORDER.Toasts,
		Parent = layers,
	})

	root.ToastLayout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = root.Toasts,
	})

	-- Message of the day panel.
	root.MOTD = UIBuilder.BuildMOTD(layers)

	-- Footer watermark.
	if CONFIG.ServerInfo.ShowFooterWatermark then
		root.Watermark = UIBuilder.Label({
			Name = "Watermark",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -6),
			Size = UDim2.fromOffset(420, 16),
			Text = CONFIG.ServerInfo.FooterText,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(190, 190, 205),
			TextTransparency = 0.45,
			ZIndex = LAYER_ORDER.MOTD,
			Parent = layers,
		})
	end

	gui.Parent = parent
	return root
end

--// ---------- vignette ------------------------------------------------------

function UIBuilder.BuildVignette(parent)
	local container = UIBuilder.Frame({
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = LAYER_ORDER.Vignette,
		Parent = parent,
	})

	local depth = 190
	local baseColor = Color3.fromRGB(8, 6, 14)

	local function makeEdge(name, size, position, rotation, sequence)
		local edge = UIBuilder.Frame({
			Name = name,
			Size = size,
			Position = position,
			BackgroundColor3 = baseColor,
			BackgroundTransparency = 1,
			ZIndex = LAYER_ORDER.Vignette,
			Parent = container,
		})
		Util.New("UIGradient", {
			Color = ColorSequence.new(baseColor),
			Transparency = sequence,
			Rotation = rotation,
			Parent = edge,
		})
		return edge
	end

	local softTop = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})

	local edges = {
		Top = makeEdge("Top", UDim2.new(1, 0, 0, depth), UDim2.new(0, 0, 0, 0), 90, softTop),
		Bottom = makeEdge("Bottom", UDim2.new(1, 0, 0, depth), UDim2.new(0, 0, 1, -depth), -90, softTop),
		Left = makeEdge("Left", UDim2.new(0, depth, 1, 0), UDim2.new(0, 0, 0, 0), 0, softTop),
		Right = makeEdge("Right", UDim2.new(0, depth, 1, 0), UDim2.new(1, -depth, 0, 0), 180, softTop),
	}

	return { Container = container, Edges = edges }
end

--// ---------- ticker --------------------------------------------------------

function UIBuilder.BuildTicker(parent)
	local bar = UIBuilder.Frame({
		Name = "Ticker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(12, 12, 18),
		BackgroundTransparency = 0.12,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = LAYER_ORDER.Ticker,
		Parent = parent,
	})

	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 30)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(32, 32, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30)),
		}),
		Rotation = 0,
		Parent = bar,
	})

	UIBuilder.Stroke(Color3.fromRGB(255, 196, 61), 1, 0.35, bar)

	local tag = UIBuilder.Frame({
		Name = "Tag",
		Size = UDim2.fromOffset(96, 30),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 196, 61),
		ZIndex = LAYER_ORDER.Ticker + 1,
		Parent = bar,
	})

	local tagLabel = UIBuilder.Label({
		Name = "TagLabel",
		Size = UDim2.fromScale(1, 1),
		Text = "LIVE",
		TextSize = APPEAR.RankTagTextSize,
		TextColor3 = Color3.fromRGB(28, 20, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontWeight = "black",
		ZIndex = LAYER_ORDER.Ticker + 2,
		Parent = tag,
	})

	local track = UIBuilder.Frame({
		Name = "Track",
		Size = UDim2.new(1, -96, 1, 0),
		Position = UDim2.new(0, 96, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = LAYER_ORDER.Ticker + 1,
		Parent = bar,
	})

	local text = UIBuilder.Label({
		Name = "Text",
		Size = UDim2.new(0, 800, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Text = "",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(245, 240, 225),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontWeight = "semibold",
		ZIndex = LAYER_ORDER.Ticker + 2,
		Parent = track,
	})

	return {
		Bar = bar,
		Tag = tag,
		TagLabel = tagLabel,
		Track = track,
		Text = text,
		Active = false,
	}
end

--// ---------- alert ---------------------------------------------------------

function UIBuilder.BuildAlert(parent)
	local container = UIBuilder.Frame({
		Name = "Alert",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = LAYER_ORDER.Alert,
		Parent = parent,
	})

	local card = UIBuilder.Frame({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(0.46, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(20, 14, 16),
		CornerRadius = 18,
		StrokeColor = Color3.fromRGB(255, 70, 70),
		StrokeThickness = 3,
		ZIndex = LAYER_ORDER.Alert + 1,
		Parent = container,
	})

	Util.New("UISizeConstraint", {
		MinSize = Vector2.new(300, 120),
		MaxSize = Vector2.new(760, 520),
		Parent = card,
	})

	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 18, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 10, 14)),
		}),
		Rotation = 90,
		Parent = card,
	})

	UIBuilder.Padding(22, 22, 26, 26, card)

	local layout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = card,
	})

	local badge = UIBuilder.Label({
		Name = "Badge",
		Size = UDim2.fromOffset(52, 52),
		Text = "\u{1F6A8}",
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		ZIndex = LAYER_ORDER.Alert + 2,
		Parent = card,
	})

	local rankTag = UIBuilder.Label({
		Name = "RankTag",
		Size = UDim2.new(1, 0, 0, 18),
		Text = "OWNER ALERT",
		TextSize = APPEAR.RankTagTextSize,
		TextColor3 = Color3.fromRGB(255, 150, 150),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontWeight = "black",
		LayoutOrder = 2,
		ZIndex = LAYER_ORDER.Alert + 2,
		Parent = card,
	})

	local title = UIBuilder.Label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
		Text = "ATTENTION",
		TextSize = 32,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontWeight = "black",
		LayoutOrder = 3,
		ZIndex = LAYER_ORDER.Alert + 2,
		Parent = card,
	})

	local message = UIBuilder.Label({
		Name = "Message",
		Size = UDim2.new(1, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "",
		TextSize = 18,
		TextColor3 = Color3.fromRGB(236, 232, 236),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		LayoutOrder = 4,
		ZIndex = LAYER_ORDER.Alert + 2,
		Parent = card,
	})

	local sender = UIBuilder.Label({
		Name = "Sender",
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		TextSize = 12,
		TextColor3 = Color3.fromRGB(190, 176, 182),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 5,
		ZIndex = LAYER_ORDER.Alert + 2,
		Parent = card,
	})

	local progressTrack = UIBuilder.Frame({
		Name = "ProgressTrack",
		Size = UDim2.new(0.7, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(60, 34, 36),
		CornerRadius = 4,
		LayoutOrder = 6,
		ZIndex = LAYER_ORDER.Alert + 2,
		Parent = card,
	})

	local progressFill = UIBuilder.Frame({
		Name = "ProgressFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 120, 120),
		CornerRadius = 4,
		ZIndex = LAYER_ORDER.Alert + 3,
		Parent = progressTrack,
	})

	local glow = UIBuilder.Frame({
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 60, 1, 60),
		BackgroundColor3 = Color3.fromRGB(255, 60, 60),
		BackgroundTransparency = 0.86,
		CornerRadius = 30,
		ZIndex = LAYER_ORDER.Alert,
		Parent = card,
	})

	return {
		Container = container,
		Card = card,
		Badge = badge,
		RankTag = rankTag,
		Title = title,
		Message = message,
		Sender = sender,
		ProgressTrack = progressTrack,
		ProgressFill = progressFill,
		Glow = glow,
		Layout = layout,
		Active = false,
	}
end

--// ---------- countdown -----------------------------------------------------

function UIBuilder.BuildCountdown(parent)
	local container = UIBuilder.Frame({
		Name = "Countdown",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = LAYER_ORDER.Countdown,
		Parent = parent,
	})

	local wrapper = UIBuilder.Frame({
		Name = "Wrapper",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromOffset(420, 200),
		BackgroundTransparency = 1,
		ZIndex = LAYER_ORDER.Countdown + 1,
		Parent = container,
	})

	local layout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = wrapper,
	})

	local label = UIBuilder.Label({
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 22),
		Text = "STARTING IN",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontWeight = "bold",
		TextTransparency = 0.1,
		LayoutOrder = 1,
		ZIndex = LAYER_ORDER.Countdown + 2,
		Parent = wrapper,
	})

	local number = UIBuilder.Label({
		Name = "Number",
		Size = UDim2.new(1, 0, 0, 120),
		Text = "10",
		TextSize = 104,
		TextColor3 = Color3.fromRGB(255, 214, 90),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontWeight = "black",
		LayoutOrder = 2,
		ZIndex = LAYER_ORDER.Countdown + 2,
		Parent = wrapper,
	})

	Util.New("UIStroke", {
		Color = Color3.fromRGB(20, 14, 4),
		Thickness = 3,
		Transparency = 0.35,
		Parent = number,
	})

	local caption = UIBuilder.Label({
		Name = "Caption",
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(228, 228, 240),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		ZIndex = LAYER_ORDER.Countdown + 2,
		Parent = wrapper,
	})

	return {
		Container = container,
		Wrapper = wrapper,
		Label = label,
		Number = number,
		Caption = caption,
		Layout = layout,
		Active = false,
	}
end

--// ---------- message of the day --------------------------------------------

function UIBuilder.BuildMOTD(parent)
	local container = UIBuilder.Frame({
		Name = "MOTD",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = LAYER_ORDER.MOTD,
		Parent = parent,
	})

	local card = UIBuilder.Frame({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, APPEAR.TopbarOffset + 8),
		Size = UDim2.new(0.34, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(20, 26, 34),
		CornerRadius = 16,
		StrokeColor = Color3.fromRGB(120, 190, 255),
		StrokeThickness = 2,
		ZIndex = LAYER_ORDER.MOTD + 1,
		Parent = container,
	})

	Util.New("UISizeConstraint", {
		MinSize = Vector2.new(280, 90),
		MaxSize = Vector2.new(560, 380),
		Parent = card,
	})

	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 42, 58)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 22, 30)),
		}),
		Rotation = 90,
		Parent = card,
	})

	UIBuilder.Padding(16, 16, 20, 20, card)

	Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = card,
	})

	local header = UIBuilder.Frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = LAYER_ORDER.MOTD + 2,
		Parent = card,
	})

	local title = UIBuilder.Label({
		Name = "Title",
		Size = UDim2.new(1, -30, 1, 0),
		Text = "MESSAGE OF THE DAY",
		TextSize = 14,
		TextColor3 = Color3.fromRGB(150, 210, 255),
		FontWeight = "black",
		ZIndex = LAYER_ORDER.MOTD + 3,
		Parent = header,
	})

	local close = UIBuilder.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		Text = "\u{2715}",
		TextSize = 12,
		BackgroundColor3 = Color3.fromRGB(60, 74, 92),
		TextColor3 = Color3.fromRGB(220, 230, 240),
		CornerRadius = 6,
		ZIndex = LAYER_ORDER.MOTD + 3,
		Parent = header,
	})

	local message = UIBuilder.Label({
		Name = "Message",
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(232, 238, 245),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		ZIndex = LAYER_ORDER.MOTD + 2,
		Parent = card,
	})

	local footer = UIBuilder.Label({
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = Color3.fromRGB(150, 162, 178),
		LayoutOrder = 3,
		ZIndex = LAYER_ORDER.MOTD + 2,
		Parent = card,
	})

	return {
		Container = container,
		Card = card,
		Title = title,
		Message = message,
		Footer = footer,
		Close = close,
		Active = false,
	}
end

AnnouncementPanel.UIBuilder = UIBuilder

--// ==========================================================================
--// SECTION 14  ::  BANNERS, TOASTS, CONFETTI
--// ==========================================================================

-- Rough but reliable height estimate so a long message never gets clipped and
-- we never depend on AutomaticSize (which behaves differently when the server
-- drives the GUI).
function UIBuilder.EstimateHeight(message, width, textSize)
	message = tostring(message or "")
	width = width or APPEAR.BannerWidth
	textSize = textSize or APPEAR.TextSize
	local usableWidth = math.max(120, width - 120)
	local averageCharWidth = textSize * 0.52
	local charsPerLine = math.max(12, math.floor(usableWidth / averageCharWidth))
	local explicitLines = 0
	local longest = 0
	for line in string.gmatch(message .. "\n", "(.-)\n") do
		explicitLines += 1
		longest = math.max(longest, #line)
	end
	if explicitLines == 0 then
		explicitLines = 1
	end
	local wrappedLines = math.ceil(#message / charsPerLine)
	local lines = math.max(explicitLines, wrappedLines)
	if longest > charsPerLine then
		lines = math.max(lines, math.ceil(longest / charsPerLine))
	end
	lines = Util.Clamp(lines, 1, 5)
	return math.floor(46 + (lines * (textSize + 7)))
end

-- The pinned banner. This is the thing players actually see.
function UIBuilder.BuildBanner(data, palette, options)
	options = options or {}
	local width = options.Width or APPEAR.BannerWidth
	local textSize = options.TextSize or APPEAR.TextSize
	local message = tostring(data.Message or "")
	local title = tostring(data.Title or "")
	local height = UIBuilder.EstimateHeight(message, width, textSize)
	local rank = palette.Rank or FALLBACK_RANK

	local banner = UIBuilder.Frame({
		Name = "Banner_" .. tostring(data.Id or Util.ShortId(4)),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = options.LayoutOrder or 1,
		ZIndex = LAYER_ORDER.TopStack,
	})

	local card = UIBuilder.Frame({
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Background or APPEAR.BaseColor,
		CornerRadius = APPEAR.BannerCornerRadius,
		ClipsDescendants = true,
		ZIndex = LAYER_ORDER.TopStack + 1,
		Parent = banner,
	})

	-- Two-tone background gradient.
	local cardGradient = Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, palette.Background2 or APPEAR.BaseColor2),
			ColorSequenceKeypoint.new(1, palette.Background or APPEAR.BaseColor),
		}),
		Rotation = 115,
		Parent = card,
	})

	local stroke = UIBuilder.Stroke(palette.Stroke, APPEAR.BorderThickness, 0.05, card)

	-- Outer glow halo.
	local glow = nil
	if palette.GlowEnabled then
		glow = UIBuilder.Frame({
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 26, 1, 26),
			BackgroundColor3 = palette.Glow,
			BackgroundTransparency = APPEAR.GlowTransparency + 0.28,
			CornerRadius = APPEAR.BannerCornerRadius + 8,
			ZIndex = LAYER_ORDER.TopStack,
			Parent = banner,
		})
	end

	-- Left accent bar in the rank colour.
	local accent = UIBuilder.Frame({
		Name = "Accent",
		Size = UDim2.new(0, 5, 1, -12),
		Position = UDim2.new(0, 7, 0, 6),
		BackgroundColor3 = palette.RankColor,
		CornerRadius = 3,
		ZIndex = LAYER_ORDER.TopStack + 3,
		Parent = card,
	})

	-- Crest: the rank medallion with its badge glyph.
	local crest = UIBuilder.Frame({
		Name = "Crest",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = palette.RankDark,
		CornerRadius = 21,
		ZIndex = LAYER_ORDER.TopStack + 3,
		Parent = card,
	})

	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Util.ColorBrighten(palette.RankColor, 0.08)),
			ColorSequenceKeypoint.new(1, Util.ColorDarken(palette.RankColor, 0.22)),
		}),
		Rotation = 90,
		Parent = crest,
	})

	UIBuilder.Stroke(palette.RankAccent, 1, 0.35, crest)

	local crestLabel = UIBuilder.Label({
		Name = "Badge",
		Size = UDim2.fromScale(1, 1),
		Text = rank.Badge or "",
		TextSize = 21,
		TextColor3 = Theme.ReadableTextOn(palette.RankColor),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = LAYER_ORDER.TopStack + 4,
		Parent = crest,
	})

	-- Text column.
	local body = UIBuilder.Frame({
		Name = "Body",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 74, 0.5, 0),
		Size = UDim2.new(1, -120, 1, -14),
		BackgroundTransparency = 1,
		ZIndex = LAYER_ORDER.TopStack + 3,
		Parent = card,
	})

	local bodyLayout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = body,
	})

	local hasTitle = title ~= ""
	local metaLine = UIBuilder.Label({
		Name = "Meta",
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = APPEAR.RankTagTextSize,
		TextColor3 = palette.MetaColor,
		FontWeight = "bold",
		LayoutOrder = 1,
		ZIndex = LAYER_ORDER.TopStack + 4,
		Parent = body,
	})

	local titleLabel = nil
	if hasTitle then
		titleLabel = UIBuilder.Label({
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 18),
			Text = title,
			TextSize = APPEAR.TitleTextSize,
			TextColor3 = palette.TitleColor,
			FontWeight = "black",
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 2,
			ZIndex = LAYER_ORDER.TopStack + 4,
			Parent = body,
		})
	end

	local messageLabel = UIBuilder.Label({
		Name = "Message",
		Size = UDim2.new(1, 0, 0, (hasTitle and height - 56 or height - 44)),
		Text = message,
		TextSize = textSize,
		TextColor3 = palette.MessageColor,
		FontWeight = "semibold",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 3,
		ZIndex = LAYER_ORDER.TopStack + 4,
		Parent = body,
	})

	-- Close button (client install makes it clickable; server install still
	-- renders it so the layout looks right).
	local close = UIBuilder.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(22, 22),
		Text = "\u{2715}",
		TextSize = 11,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.88,
		TextColor3 = palette.MetaColor,
		CornerRadius = 11,
		ZIndex = LAYER_ORDER.TopStack + 5,
		Parent = card,
	})

	-- Progress bar along the bottom edge.
	local progressTrack = UIBuilder.Frame({
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = palette.ProgressBarTrack,
		BackgroundTransparency = 0.4,
		ZIndex = LAYER_ORDER.TopStack + 4,
		Parent = card,
	})

	local progressFill = UIBuilder.Frame({
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.ProgressBar,
		ZIndex = LAYER_ORDER.TopStack + 5,
		Parent = progressTrack,
	})

	-- Shine sweep on entry: a soft highlight that slides across once.
	local shine = UIBuilder.Frame({
		Name = "Shine",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = LAYER_ORDER.TopStack + 6,
		Parent = card,
	})

	local shineGradient = Util.New("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 0.72),
			NumberSequenceKeypoint.new(0.58, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 20,
		Offset = Vector2.new(-1.2, 0),
		Parent = shine,
	})

	return {
		Frame = banner,
		Card = card,
		CardGradient = cardGradient,
		Stroke = stroke,
		Glow = glow,
		Accent = accent,
		Crest = crest,
		CrestLabel = crestLabel,
		Body = body,
		BodyLayout = bodyLayout,
		Meta = metaLine,
		Title = titleLabel,
		Message = messageLabel,
		Close = close,
		ProgressTrack = progressTrack,
		ProgressFill = progressFill,
		Shine = shine,
		ShineGradient = shineGradient,
		Height = height,
		Width = width,
		Data = data,
		Palette = palette,
	}
end

-- Small corner notification.
function UIBuilder.BuildToast(data, palette, options)
	options = options or {}
	local width = options.Width or 288
	local message = tostring(data.Message or "")
	local title = tostring(data.Title or "")
	local charsPerLine = math.max(12, math.floor((width - 62) / 6.6))
	local height = 44 + (title ~= "" and 14 or 0) + (math.ceil(#message / charsPerLine) * 15)
	height = Util.Clamp(height, 44, 150)

	local toast = UIBuilder.Frame({
		Name = "Toast_" .. tostring(data.Id or Util.ShortId(4)),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = options.LayoutOrder or 1,
		ZIndex = LAYER_ORDER.Toasts,
	})

	local card = UIBuilder.Frame({
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(22, 22, 30),
		CornerRadius = 12,
		ClipsDescendants = true,
		ZIndex = LAYER_ORDER.Toasts + 1,
		Parent = toast,
	})

	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 34, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 24)),
		}),
		Rotation = 100,
		Parent = card,
	})

	local stroke = UIBuilder.Stroke(palette.RankColor, 1, 0.45, card)

	local accent = UIBuilder.Frame({
		Name = "Accent",
		Size = UDim2.new(0, 4, 1, -10),
		Position = UDim2.new(0, 5, 0, 5),
		BackgroundColor3 = palette.RankColor,
		CornerRadius = 2,
		ZIndex = LAYER_ORDER.Toasts + 3,
		Parent = card,
	})

	local badge = UIBuilder.Label({
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.fromOffset(20, 20),
		Text = palette.Rank.Badge or "\u{1F514}",
		TextSize = 14,
		ZIndex = LAYER_ORDER.Toasts + 3,
		Parent = card,
	})

	local meta = UIBuilder.Label({
		Name = "Meta",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 42, 0, 11),
		Size = UDim2.new(1, -70, 0, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = palette.MetaColor,
		FontWeight = "bold",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = LAYER_ORDER.Toasts + 3,
		Parent = card,
	})

	local messageLabel = UIBuilder.Label({
		Name = "Message",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 42, 0, title ~= "" and 28 or 12),
		Size = UDim2.new(1, -58, 0, height - (title ~= "" and 40 or 22)),
		Text = message,
		TextSize = 13,
		TextColor3 = palette.MessageColor,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = LAYER_ORDER.Toasts + 3,
		Parent = card,
	})

	local titleLabel = nil
	if title ~= "" then
		titleLabel = UIBuilder.Label({
			Name = "Title",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 42, 0, 26),
			Size = UDim2.new(1, -58, 0, 16),
			Text = title,
			TextSize = 13,
			TextColor3 = palette.TitleColor,
			FontWeight = "black",
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = LAYER_ORDER.Toasts + 3,
			Parent = card,
		})
		-- With a title the message sits under it.
		messageLabel.Position = UDim2.new(0, 42, 0, 44)
		messageLabel.Size = UDim2.new(1, -58, 0, math.max(14, height - 54))
		badge.Position = UDim2.new(0, 16, 0, 24)
		meta.Position = UDim2.new(0, 42, 0, 8)
	end

	local progress = UIBuilder.Frame({
		Name = "Progress",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(40, 40, 52),
		ZIndex = LAYER_ORDER.Toasts + 3,
		Parent = card,
	})

	local progressFill = UIBuilder.Frame({
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.RankColor,
		ZIndex = LAYER_ORDER.Toasts + 4,
		Parent = progress,
	})

	return {
		Frame = toast,
		Card = card,
		Stroke = stroke,
		Accent = accent,
		Badge = badge,
		Meta = meta,
		Title = titleLabel,
		Message = messageLabel,
		Progress = progress,
		ProgressFill = progressFill,
		Height = height,
		Data = data,
		Palette = palette,
	}
end

-- One confetti shard. Cheap: a tiny rotated frame that falls and fades.
function UIBuilder.BuildConfettiPiece(color)
	local size = Util.RandomInt(5, 11)
	local piece = UIBuilder.Frame({
		Name = "Confetti",
		Size = UDim2.fromOffset(size, math.floor(size * Util.RandomBetween(0.5, 1.6))),
		Position = UDim2.fromScale(math.random(), -0.05),
		BackgroundColor3 = color or Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.05,
		Rotation = Util.RandomBetween(-40, 40),
		ZIndex = LAYER_ORDER.Confetti + 1,
	})
	UIBuilder.Corner(2, piece)
	return piece
end

-- Floating "+1" style ping used by the client console feedback.
function UIBuilder.BuildPing(text, color)
	local ping = UIBuilder.Label({
		Name = "Ping",
		Size = UDim2.fromOffset(220, 22),
		Text = text or "",
		TextSize = 14,
		TextColor3 = color or Color3.fromRGB(140, 255, 170),
		FontWeight = "bold",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 0,
		ZIndex = LAYER_ORDER.Flash,
	})
	return ping
end

AnnouncementPanel.UIBuilder = UIBuilder

--// ==========================================================================
--// SECTION 15  ::  EFFECTS
--// Flash, shake, confetti, vignette, lighting pulses, camera shake.
--// Every effect is defensive: if an effect is disabled or unsupported in the
--// current context it quietly does nothing.
--// ==========================================================================

local Effects = {}

Effects.ActiveCount = 0
Effects.LightingInstances = {}

function Effects.BudgetAvailable()
	return Effects.ActiveCount < (LIMITS.MaxConcurrentEffects or 8)
end

function Effects.Begin()
	Effects.ActiveCount += 1
	State.Bump("Effects")
end

function Effects.End()
	Effects.ActiveCount = math.max(0, Effects.ActiveCount - 1)
end

--// ---------- flash ---------------------------------------------------------

function Effects.Flash(root, color, duration, intensity)
	if not root or not root.Flash or not FX.EnableFlash then
		return false
	end
	color = color or FX.FlashColor
	duration = duration or FX.FlashTime
	intensity = intensity or FX.FlashMaxTransparency
	Effects.Begin()

	local flash = root.Flash
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1
	flash.Visible = true

	Util.Tween(flash, duration * 0.28, {
		BackgroundTransparency = 1 - intensity,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	Util.Delay(duration * 0.3, function()
		Util.Tween(flash, duration, {
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Util.Delay(duration + 0.05, function()
			flash.Visible = false
			Effects.End()
		end)
	end)
	return true
end

--// ---------- backdrop dim --------------------------------------------------

function Effects.Dim(root, targetTransparency, duration)
	if not root or not root.Backdrop then
		return false
	end
	targetTransparency = targetTransparency == nil and APPEAR.BackdropDim or targetTransparency
	duration = duration or 0.3
	root.Backdrop.Visible = true
	Util.Tween(root.Backdrop, duration, {
		BackgroundTransparency = targetTransparency,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	return true
end

function Effects.UnDim(root, duration)
	if not root or not root.Backdrop then
		return false
	end
	duration = duration or 0.4
	Util.Tween(root.Backdrop, duration, {
		BackgroundTransparency = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Util.Delay(duration + 0.1, function()
		if root.Backdrop and root.Backdrop.Parent then
			root.Backdrop.Visible = false
		end
	end)
	return true
end

--// ---------- vignette ------------------------------------------------------

function Effects.Vignette(root, enabled, duration)
	if not root or not root.Vignette or not FX.EnableVignette then
		return false
	end
	local container = root.Vignette.Container
	duration = duration or 0.5
	if enabled == false then
		for _, edge in pairs(root.Vignette.Edges or {}) do
			Util.Tween(edge, duration, { BackgroundTransparency = 1 })
		end
		Util.Delay(duration + 0.1, function()
			container.Visible = false
		end)
		return true
	end
	container.Visible = true
	for _, edge in pairs(root.Vignette.Edges or {}) do
		Util.Tween(edge, duration, { BackgroundTransparency = 0 })
	end
	return true
end

--// ---------- shake ---------------------------------------------------------

-- GUI shake: works even when the server owns the GUI, because it only moves
-- frames inside the ScreenGui (no camera access needed).
function Effects.ShakeGUI(root, intensity, duration)
	if not root or not root.Layers or not FX.EnableShake then
		return false
	end
	intensity = intensity or FX.ShakeIntensity
	duration = duration or FX.ShakeTime
	local layers = root.Layers
	local basePosition = layers.Position
	local frames = math.max(2, math.floor(ANIM.JitterFrames or 12))
	local stepTime = duration / frames
	Effects.Begin()

	Util.Spawn(function()
		for index = 1, frames do
			local decay = 1 - ((index - 1) / frames)
			local offsetX = Util.RandomBetween(-intensity, intensity) * decay * 6
			local offsetY = Util.RandomBetween(-intensity, intensity) * decay * 6
			layers.Position = UDim2.new(
				basePosition.X.Scale,
				basePosition.X.Offset + offsetX,
				basePosition.Y.Scale,
				basePosition.Y.Offset + offsetY
			)
			task.wait(stepTime)
		end
		layers.Position = basePosition
		Effects.End()
	end, "Effects.ShakeGUI")

	return true
end

-- Real camera shake. Client only, obviously.
function Effects.ShakeCamera(intensity, duration)
	if not IS_CLIENT or not FX.EnableShake then
		return false
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return false
	end
	intensity = (intensity or FX.CameraShakeIntensity) * 0.4
	duration = duration or FX.ShakeTime
	Effects.Begin()

	local startTime = os.clock()
	local originType = camera.CameraType
	Util.Spawn(function()
		while os.clock() - startTime < duration do
			local decay = 1 - ((os.clock() - startTime) / duration)
			if decay <= 0 then
				break
			end
			local offset = CFrame.new(
				Util.RandomBetween(-intensity, intensity) * decay,
				Util.RandomBetween(-intensity, intensity) * decay,
				Util.RandomBetween(-intensity, intensity) * decay * 0.4
			) * CFrame.Angles(
				math.rad(Util.RandomBetween(-intensity, intensity) * decay * 1.6),
				math.rad(Util.RandomBetween(-intensity, intensity) * decay * 1.6),
				math.rad(Util.RandomBetween(-intensity, intensity) * decay * 1.2)
			)
			pcall(function()
				camera.CFrame = camera.CFrame * offset
			end)
			task.wait()
		end
		pcall(function()
			camera.CameraType = originType
		end)
		Effects.End()
	end, "Effects.ShakeCamera")
	return true
end

--// ---------- confetti ------------------------------------------------------

function Effects.Confetti(root, count, colors)
	if not root or not root.Confetti or not FX.EnableConfetti then
		return false
	end
	count = Util.Clamp(count or FX.ConfettiPieces, 4, 140)
	colors = colors or FX.ConfettiColors
	if not Effects.BudgetAvailable() then
		count = math.max(4, math.floor(count / 3))
	end
	Effects.Begin()

	Util.Spawn(function()
		local layer = root.Confetti
		for index = 1, count do
			if layer.Parent == nil then
				break
			end
			local color = Util.RandomFromList(colors, Color3.fromRGB(255, 255, 255))
			local piece = UIBuilder.BuildConfettiPiece(color)
			piece.Parent = layer
			local lifetime = FX.ConfettiLifetime * Util.RandomBetween(0.7, 1.35)
			local drift = Util.RandomBetween(-0.25, 0.25)
			local startX = piece.Position.X.Scale
			Util.Tween(piece, lifetime, {
				Position = UDim2.fromScale(Util.Clamp(startX + drift, -0.1, 1.1), 1.08),
				Rotation = piece.Rotation + Util.RandomBetween(-540, 540),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(piece, lifetime + 0.4)
			if index % 6 == 0 then
				task.wait(0.03)
			end
		end
		Util.Delay(FX.ConfettiLifetime + 1.4, function()
			Effects.End()
		end)
	end, "Effects.Confetti")

	return true
end

--// ---------- lighting ------------------------------------------------------
-- Server-side Lighting effects replicate to everyone, which makes them a cheap
-- way to make an alert feel huge without touching a single player's GUI.

function Effects.GetLightingChild(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	if existing then
		Util.Destroy(existing)
	end
	local created = Util.New(className, {
		Name = name,
		Parent = Lighting,
	})
	Effects.LightingInstances[name] = created
	return created
end

function Effects.LightingFlash(color, duration, brightness)
	if not IS_SERVER or not FX.EnableLighting then
		return false
	end
	color = color or Color3.fromRGB(255, 240, 200)
	duration = duration or FX.LightingPulseTime
	brightness = brightness or 2
	Effects.Begin()

	local ok = pcall(function()
		local correction = Effects.GetLightingChild("ColorCorrectionEffect", "AP_ColorCorrection")
		correction.Brightness = 0
		correction.Contrast = 0
		correction.Saturation = 0
		correction.TintColor = color
		correction.Enabled = true

		Util.Tween(correction, duration * 0.3, {
			Brightness = brightness * 0.14,
			Contrast = brightness * 0.12,
			Saturation = brightness * 0.2,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		Util.Delay(duration * 0.35, function()
			Util.Tween(correction, duration, {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Util.Delay(duration + 0.1, function()
				correction.Enabled = false
				Effects.End()
			end)
		end)
	end)
	if not ok then
		Effects.End()
	end
	return ok
end

function Effects.LightingBlur(amount, duration)
	if not IS_SERVER or not FX.EnableLighting then
		return false
	end
	amount = amount or FX.BlurAmount
	duration = duration or 1.2
	Effects.Begin()
	local ok = pcall(function()
		local blur = Effects.GetLightingChild("BlurEffect", "AP_Blur")
		blur.Size = 0
		blur.Enabled = true
		Util.Tween(blur, duration * 0.25, { Size = amount }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Util.Delay(duration * 0.5, function()
			Util.Tween(blur, duration, { Size = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Util.Delay(duration + 0.1, function()
				blur.Enabled = false
				Effects.End()
			end)
		end)
	end)
	if not ok then
		Effects.End()
	end
	return ok
end

function Effects.LightingStrobe(times, interval, color)
	if not IS_SERVER or not FX.EnableLighting then
		return false
	end
	times = Util.Clamp(times or 3, 1, 10)
	interval = interval or 0.22
	Util.Spawn(function()
		for _ = 1, times do
			Effects.LightingFlash(color or Color3.fromRGB(255, 255, 255), interval * 1.6, 3)
			task.wait(interval)
		end
	end, "Effects.Strobe")
	return true
end

function Effects.CleanupLighting()
	for name, instance in pairs(Effects.LightingInstances) do
		Util.Destroy(instance)
		Effects.LightingInstances[name] = nil
	end
end

--// ---------- combined ------------------------------------------------------

-- Runs whatever the payload asked for. `scope` is "server" or "client".
function Effects.Apply(root, payload, scope)
	if type(payload) ~= "table" then
		return
	end
	local requested = payload.Effects or {}

	if requested.Flash or payload.Flash then
		Effects.Flash(root, payload.FlashColor and Util.ColorFromName(payload.FlashColor) or nil)
	end

	if requested.Shake or payload.Shake then
		if scope == "client" then
			Effects.ShakeCamera(FX.CameraShakeIntensity)
		end
		Effects.ShakeGUI(root, FX.ShakeIntensity)
	end

	if requested.Confetti or payload.Confetti then
		Effects.Confetti(root, payload.ConfettiCount or FX.ConfettiPieces)
	end

	if requested.Vignette then
		Effects.Vignette(root, true, 0.4)
		Util.Delay(payload.Duration or 6, function()
			Effects.Vignette(root, false, 0.6)
		end)
	end

	if requested.Lighting and IS_SERVER then
		Effects.LightingFlash(payload.FlashColor and Util.ColorFromName(payload.FlashColor) or nil)
	end

	if requested.Blur and IS_SERVER then
		Effects.LightingBlur(FX.BlurAmount)
	end

	if requested.Dim then
		Effects.Dim(root, payload.DimAmount)
	end
end

AnnouncementPanel.Effects = Effects

--// ==========================================================================
--// SECTION 16  ::  RENDERER
--// Owns the lifecycle of every visual: create -> animate in -> tick ->
--// animate out -> destroy. Works identically whether the root lives in a
--// player's PlayerGui (server install) or in LocalPlayer (client install).
--// ==========================================================================

local Renderer = {}

Renderer.Roots = {} -- [key] = root table ; key is the Player (server) or "local" (client)
Renderer.Active = {} -- [key] = { banner handles }
Renderer.Sequence = 0
Renderer.LocalRoot = nil
Renderer.InstalledPlayers = {}

local function rootKey(player)
	if IS_SERVER then
		return player or "server"
	end
	return "local"
end

function Renderer.NextSequence()
	Renderer.Sequence += 1
	return Renderer.Sequence
end

--// ---------- root management -----------------------------------------------

function Renderer.InstallForPlayer(player)
	if not IS_SERVER or player == nil then
		return nil
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		playerGui = player:WaitForChild("PlayerGui", 15)
	end
	if playerGui == nil then
		Util.Warn("could not find PlayerGui for", player.Name)
		return nil
	end

	-- Remove a stale copy (happens on script reload in Studio).
	local existing = playerGui:FindFirstChild(UIBuilder.ROOT_NAME)
	if existing then
		Util.Destroy(existing)
	end

	local root = UIBuilder.CreateRoot({
		Role = "server",
		Parent = playerGui,
		DisplayOrder = 200,
	})
	Renderer.Roots[player] = root
	Renderer.Active[player] = {}
	Renderer.InstalledPlayers[player.UserId] = true

	-- If the client half is installed it may want to enhance this root.
	pcall(function()
		root.Gui:SetAttribute("AP_Ready", true)
	end)

	Util.Debug("installed panel for", player.Name)
	return root
end

function Renderer.UninstallForPlayer(player)
	if player == nil then
		return
	end
	local root = Renderer.Roots[player]
	if root then
		Renderer.KillAllFor(player)
		Util.Destroy(root.Gui)
		Renderer.Roots[player] = nil
		Renderer.Active[player] = nil
	end
	Renderer.InstalledPlayers[player.UserId] = nil
end

function Renderer.InstallLocal(options)
	if not IS_CLIENT then
		return nil
	end
	options = options or {}
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end
	local playerGui = localPlayer:WaitForChild("PlayerGui", 20)
	if playerGui == nil then
		Util.Warn("no PlayerGui on the client")
		return nil
	end

	local existing = playerGui:FindFirstChild(UIBuilder.CLIENT_ROOT_NAME)
	if existing then
		Util.Destroy(existing)
	end

	local root = UIBuilder.CreateRoot({
		Role = options.Role or "client",
		Parent = playerGui,
		DisplayOrder = options.DisplayOrder or 250,
		Scale = options.Scale,
	})
	Renderer.Roots["local"] = root
	Renderer.Active["local"] = {}
	Renderer.LocalRoot = root
	Renderer.HookResponsive(root)
	return root
end

function Renderer.GetRoot(player)
	if IS_SERVER then
		if player == nil then
			return nil
		end
		local root = Renderer.Roots[player]
		if root == nil or root.Gui.Parent == nil then
			root = Renderer.InstallForPlayer(player)
		end
		return root
	end
	return Renderer.LocalRoot or Renderer.InstallLocal()
end

function Renderer.GetAllRoots()
	local roots = {}
	for _, root in pairs(Renderer.Roots) do
		if root and root.Gui and root.Gui.Parent then
			table.insert(roots, root)
		end
	end
	return roots
end

-- Client-side responsive scaling: shrink the panel on phones, cap it on 4K.
function Renderer.HookResponsive(root)
	if not IS_CLIENT or root == nil or not APPEAR.ScaleWithScreen then
		return false
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return false
	end
	local function applyScale()
		local viewport = camera.ViewportSize
		if viewport.X <= 0 then
			return
		end
		local raw = viewport.X / (APPEAR.ScaleReferenceWidth or 1440)
		local scale = Util.Clamp(raw, APPEAR.MinUIScale, APPEAR.MaxUIScale)
		if root.Scale and math.abs(root.Scale.Scale - scale) > 0.01 then
			root.Scale.Scale = scale
		end
	end
	applyScale()
	Util.Track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		applyScale()
	end), "Renderer.Responsive")
	return true
end

-- The client half can find and polish the server-built GUI (companion mode).
function Renderer.FindServerRoot()
	if not IS_CLIENT then
		return nil
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local gui = playerGui:FindFirstChild(UIBuilder.ROOT_NAME)
	if gui == nil then
		return nil
	end
	-- Wrap the existing GUI in a lightweight root table so effects can use it.
	local layers = gui:FindFirstChild("Layers")
	if layers == nil then
		return nil
	end
	local wrapped = {
		Gui = gui,
		Layers = layers,
		Role = "server",
		Scale = gui:FindFirstChild("ResponsiveScale"),
		Backdrop = layers:FindFirstChild("Backdrop"),
		Flash = layers:FindFirstChild("Flash"),
		Confetti = layers:FindFirstChild("Confetti"),
		TopStack = layers:FindFirstChild("TopStack"),
		Toasts = layers:FindFirstChild("Toasts"),
		Ticker = nil,
		Alert = nil,
		Countdown = nil,
		MOTD = nil,
		Vignette = nil,
		External = true,
	}
	local tickerBar = layers:FindFirstChild("Ticker")
	if tickerBar then
		-- Explicit locals: never rely on Instance's implicit child-name lookup.
		local tagFrame = tickerBar:FindFirstChild("Tag")
		local trackFrame = tickerBar:FindFirstChild("Track")
		wrapped.Ticker = {
			Bar = tickerBar,
			Tag = tagFrame,
			TagLabel = tagFrame and tagFrame:FindFirstChild("TagLabel"),
			Track = trackFrame,
			Text = trackFrame and trackFrame:FindFirstChild("Text"),
		}
	end
	local vignette = layers:FindFirstChild("Vignette")
	if vignette then
		wrapped.Vignette = {
			Container = vignette,
			Edges = {
				Top = vignette:FindFirstChild("Top"),
				Bottom = vignette:FindFirstChild("Bottom"),
				Left = vignette:FindFirstChild("Left"),
				Right = vignette:FindFirstChild("Right"),
			},
		}
	end
	return wrapped
end

--// ---------- text helpers --------------------------------------------------

function Renderer.MetaText(data, palette)
	local meta = Theme.GetRank(data.Rank or "Player")
	local rankColor = Util.ColorToHex(palette.RankColor)
	local metaColor = Util.ColorToHex(palette.MetaColor)
	local displayName = data.RankDisplay or meta.DisplayName or data.Rank or "PLAYER"
	local sender = data.SenderName or "System"
	local stamp = data.TimeText or os.date("%H:%M:%S", data.Timestamp or os.time())
	local parts = {}
	table.insert(parts, string.format('<font color="%s"><b>%s</b></font>', rankColor, displayName:upper()))
	if sender ~= "" then
		table.insert(parts, string.format('<font color="%s">%s</font>', metaColor, Util.EscapeRichText(sender)))
	end
	table.insert(parts, string.format('<font color="%s">%s</font>', metaColor, stamp))
	return table.concat(parts, string.format('  <font color="%s">\u{2022}</font>  ', metaColor))
end

--// ---------- banners -------------------------------------------------------

local function getActiveList(key)
	if Renderer.Active[key] == nil then
		Renderer.Active[key] = {}
	end
	return Renderer.Active[key]
end

function Renderer.ExpireHandle(handle, immediate)
	if handle == nil or handle.Expired then
		return
	end
	handle.Expired = true
	if handle.Timer then
		handle.Timer = nil
	end

	local banner = handle.View
	if banner == nil or banner.Frame.Parent == nil then
		handle.Cleanup()
		return
	end

	local list = getActiveList(handle.Key)
	for index, item in ipairs(list) do
		if item == handle then
			table.remove(list, index)
			break
		end
	end

	if immediate then
		handle.Cleanup()
		return
	end

	-- Exit animation: slide up, shrink, fade.
	local card = banner.Card
	local frame = banner.Frame
	Util.Tween(card, ANIM.BannerOutTime, {
		BackgroundTransparency = 1,
	}, ANIM.BannerOutStyle, ANIM.BannerOutDirection)

	for _, textObject in ipairs({ banner.Meta, banner.Title, banner.Message }) do
		if textObject then
			Util.Tween(textObject, ANIM.BannerOutTime * 0.8, { TextTransparency = 1 })
		end
	end
	if banner.Crest then
		Util.Tween(banner.Crest, ANIM.BannerOutTime, { BackgroundTransparency = 1 })
		if banner.CrestLabel then
			Util.Tween(banner.CrestLabel, ANIM.BannerOutTime, { TextTransparency = 1 })
		end
	end
	if banner.Accent then
		Util.Tween(banner.Accent, ANIM.BannerOutTime, { BackgroundTransparency = 1 })
	end
	if banner.Stroke then
		Util.Tween(banner.Stroke, ANIM.BannerOutTime, { Transparency = 1 })
	end
	if banner.Glow then
		Util.Tween(banner.Glow, ANIM.BannerOutTime, { BackgroundTransparency = 1 })
	end
	if banner.Close then
		Util.Tween(banner.Close, ANIM.BannerOutTime * 0.6, { BackgroundTransparency = 1, TextTransparency = 1 })
	end
	if banner.ProgressTrack then
		Util.Tween(banner.ProgressTrack, ANIM.BannerOutTime, { BackgroundTransparency = 1 })
	end

	Util.Tween(frame, ANIM.BannerOutTime, {
		Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 0),
		Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, 0, frame.Position.Y.Offset - 14),
	}, ANIM.BannerOutStyle, ANIM.BannerOutDirection)

	Util.Delay(ANIM.BannerOutTime + 0.06, function()
		handle.Cleanup()
	end)
end

function Renderer.ShowBanner(player, data)
	local key = rootKey(player)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
	if root == nil then
		return nil
	end
	if root.TopStack == nil or root.TopStack.Parent == nil then
		Util.Debug("root has no TopStack, skipping banner")
		return nil
	end

	data.Id = data.Id or Util.NewGuid()
	data.Timestamp = data.Timestamp or os.time()
	data.TimeText = data.TimeText or os.date("%H:%M:%S", data.Timestamp)

	local palette = Theme.PaletteFor(data.Rank or "Player", data.Style or CONFIG.DefaultStyle)
	if data.Color then
		local custom = Util.ColorFromName(data.Color, palette.RankColor)
		palette.RankColor = custom
		palette.Stroke = custom
		palette.Glow = custom
		palette.ProgressBar = custom
	end

	local sequence = Renderer.NextSequence()
	local view = UIBuilder.BuildBanner(data, palette, {
		Width = APPEAR.BannerWidth,
		TextSize = APPEAR.TextSize,
		LayoutOrder = -sequence,
	})

	view.Meta.Text = Renderer.MetaText(data, palette)
	view.Message.Text = Util.ApplyRichText(data.Message or "")
	view.Frame.Parent = root.TopStack

	local handle = {
		Id = data.Id,
		Key = key,
		View = view,
		Data = data,
		CreatedAt = os.clock(),
		Expired = false,
	}

	handle.Cleanup = function()
		Util.Destroy(view.Frame)
		if handle.RainbowHandle then
			handle.RainbowHandle = nil
		end
	end

	local active = getActiveList(key)
	table.insert(active, handle)

	-- Entry animation.
	view.Card.BackgroundTransparency = 1
	view.Frame.Position = UDim2.new(0, 0, 0, -30)
	view.Frame.Size = UDim2.new(1, 0, 0, 0)
	Util.Tween(view.Frame, ANIM.BannerInTime, {
		Size = UDim2.new(1, 0, 0, view.Height),
		Position = UDim2.new(0, 0, 0, 0),
	}, ANIM.BannerInStyle, ANIM.BannerInDirection)
	Util.Tween(view.Card, ANIM.BannerInTime * 0.7, {
		BackgroundTransparency = APPEAR.BackgroundTransparency,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Shine sweep.
	if view.ShineGradient then
		Util.Tween(view.ShineGradient, 0.85, {
			Offset = Vector2.new(1.2, 0),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		Util.Delay(1.1, function()
			if view.Shine and view.Shine.Parent then
				view.Shine.BackgroundTransparency = 1
			end
		end)
	end

	-- Glow breathing.
	if view.Glow and palette.GlowEnabled then
		Util.Tween(view.Glow, ANIM.PulseTime, {
			BackgroundTransparency = APPEAR.GlowTransparency,
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end

	-- Rainbow style cycles the stroke + glow hue.
	if palette.Rainbow then
		Util.Spawn(function()
			local hue = 0
			while not handle.Expired and view.Frame.Parent ~= nil do
				hue = (hue + 0.012) % 1
				local color = Util.ColorFromHue(hue, 0.75, 1)
				if view.Stroke then
					view.Stroke.Color = color
				end
				if view.Glow then
					view.Glow.BackgroundColor3 = color
				end
				if view.Accent then
					view.Accent.BackgroundColor3 = color
				end
				if view.ProgressFill then
					view.ProgressFill.BackgroundColor3 = color
				end
				task.wait(0.06)
			end
		end, "Renderer.Rainbow")
	end

	-- Pulse style (Emergency) flashes the stroke.
	if palette.Pulse and view.Stroke then
		Util.Tween(view.Stroke, 0.55, {
			Transparency = 0.55,
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end

	-- Progress bar.
	Renderer.RunProgress(view.ProgressFill, data.Duration, key)

	-- Enforce the visible-banner cap by expiring the oldest.
	local maxVisible = LIMITS.MaxVisibleBanners or 3
	while #getActiveList(key) > maxVisible do
		local oldest = getActiveList(key)[1]
		if oldest == nil or oldest == handle then
			break
		end
		Renderer.ExpireHandle(oldest, false)
	end

	-- Lifetime.
	local duration = Util.Clamp(tonumber(data.Duration) or LIMITS.DefaultDuration, LIMITS.MinDuration, LIMITS.MaxDuration)
	task.delay(duration, function()
		if not handle.Expired then
			Renderer.ExpireHandle(handle, false)
		end
	end)

	State.AddActive(data.Id, data)
	State.Metrics.RenderCalls += 1
	State.Metrics.LastRenderAt = os.clock()

	-- Sound + effects for this viewer.
	if data.Sound ~= "none" then
		Audio.Play(data.SoundName or palette.SoundName or "Banner", { Volume = CONFIG.Sounds.Volume })
	end
	if data.Effects and (data.Effects.Flash or data.Effects.Shake or data.Effects.Confetti) then
		Effects.Apply(root, data, root.Role)
	end

	Util.Debug("banner rendered for", key, ":", data.Message)
	return handle
end

-- Drives a progress fill. Client roots use Heartbeat (perfectly smooth);
-- server roots use a linear tween (replicated, good enough).
function Renderer.RunProgress(fill, duration, key)
	if fill == nil then
		return
	end
	duration = math.max(0.2, duration or LIMITS.DefaultDuration)

	if not IS_SERVER then
		local started = os.clock()
		Util.Spawn(function()
			while fill.Parent ~= nil do
				local elapsed = os.clock() - started
				local alpha = 1 - Util.Clamp(elapsed / duration, 0, 1)
				fill.Size = UDim2.fromScale(alpha, 1)
				if alpha <= 0 then
					break
				end
				task.wait(ANIM.ProgressUpdateRate)
			end
		end, "Renderer.Progress")
		return
	end

	Util.Tween(fill, duration, {
		Size = UDim2.fromScale(0.001, 1),
	}, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
end

--// ---------- alerts --------------------------------------------------------

function Renderer.ShowAlert(player, data)
	local key = rootKey(player)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
	if root == nil or root.Alert == nil or root.Alert.Container.Parent == nil then
		-- Degrade gracefully: no alert layer means we just show a banner.
		return Renderer.ShowBanner(player, data)
	end

	data.Id = data.Id or Util.NewGuid()
	data.Timestamp = data.Timestamp or os.time()
	local palette = Theme.PaletteFor(data.Rank or "Owner", data.Style or "Emergency")
	local alert = root.Alert

	alert.Container.Visible = true
	alert.Card.Visible = true
	alert.Badge.Text = palette.Rank.Badge or "\u{1F6A8}"
	alert.RankTag.Text = string.upper(palette.Rank.DisplayName or "ALERT") .. " ALERT"
	alert.RankTag.TextColor3 = palette.RankColor
	alert.Title.Text = (data.Title and data.Title ~= "") and data.Title or "ATTENTION"
	alert.Message.Text = data.Message or ""
	alert.Sender.Text = string.format("from %s  \u{2022}  %s",
		tostring(data.SenderName or "System"),
		os.date("%H:%M:%S", data.Timestamp))
	alert.ProgressFill.Size = UDim2.fromScale(1, 1)

	if alert.Card then
		for _, stroke in ipairs(alert.Card:GetChildren()) do
			if stroke:IsA("UIStroke") then
				stroke.Color = palette.RankColor
			end
		end
	end
	if alert.Glow then
		alert.Glow.BackgroundColor3 = palette.RankColor
	end
	if alert.ProgressFill then
		alert.ProgressFill.BackgroundColor3 = palette.RankColor
	end

	Effects.Dim(root, APPEAR.BackdropDim, 0.3)

	-- Entry pop.
	alert.Card.Size = UDim2.new(0.46, 0, 0, 0)
	alert.Card.Position = UDim2.fromScale(0.5, 0.46)
	Util.Tween(alert.Card, ANIM.AlertInTime, {
		Position = UDim2.fromScale(0.5, 0.48),
	}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if alert.Glow then
		Util.Tween(alert.Glow, 0.9, {
			BackgroundTransparency = 0.72,
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end

	local duration = Util.Clamp(tonumber(data.Duration) or 8, LIMITS.MinDuration, LIMITS.MaxDuration)
	Renderer.RunProgress(alert.ProgressFill, duration, key)

	if data.Sound ~= "none" then
		Audio.Play(data.SoundName or "Alert", { Volume = CONFIG.Sounds.Volume })
	end
	Effects.Apply(root, data, root.Role)

	local token = data.Id
	root.Alert.Token = token
	root.Alert.Active = true

	task.delay(duration, function()
		if root.Alert.Token ~= token then
			return -- a newer alert took over
		end
		root.Alert.Active = false
		Util.CancelTween(alert.Glow)
		Util.Tween(alert.Card, ANIM.AlertOutTime, {
			Position = UDim2.fromScale(0.5, 0.4),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, textObject in ipairs({ alert.Title, alert.Message, alert.Sender, alert.RankTag, alert.Badge }) do
			if textObject then
				Util.Tween(textObject, ANIM.AlertOutTime * 0.85, { TextTransparency = 1 })
			end
		end
		if alert.Card then
			Util.Tween(alert.Card, ANIM.AlertOutTime, { BackgroundTransparency = 1 })
			for _, stroke in ipairs(alert.Card:GetChildren()) do
				if stroke:IsA("UIStroke") then
					Util.Tween(stroke, ANIM.AlertOutTime, { Transparency = 1 })
				end
			end
		end
		Effects.UnDim(root, ANIM.AlertOutTime)
		Util.Delay(ANIM.AlertOutTime + 0.1, function()
			if root.Alert.Token == token then
				alert.Container.Visible = false
				-- Restore text transparency for the next alert.
				for _, textObject in ipairs({ alert.Title, alert.Message, alert.Sender, alert.RankTag, alert.Badge }) do
					if textObject then
						textObject.TextTransparency = 0
					end
				end
				if alert.Card then
					alert.Card.BackgroundTransparency = 0
					for _, stroke in ipairs(alert.Card:GetChildren()) do
						if stroke:IsA("UIStroke") then
							stroke.Transparency = 0
						end
					end
				end
				root.Alert.Token = nil
			end
		end)
	end)

	State.AddActive(data.Id, data)
	return true
end

--// ---------- toasts --------------------------------------------------------

function Renderer.ShowToast(player, data)
	local key = rootKey(player)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
	if root == nil or root.Toasts == nil then
		return nil
	end

	data.Id = data.Id or Util.NewGuid()
	data.Timestamp = data.Timestamp or os.time()
	local palette = Theme.PaletteFor(data.Rank or "Player", data.Style or CONFIG.DefaultStyle)
	if data.Color then
		palette.RankColor = Util.ColorFromName(data.Color, palette.RankColor)
		palette.Stroke = palette.RankColor
	end

	local sequence = Renderer.NextSequence()
	local view = UIBuilder.BuildToast(data, palette, { LayoutOrder = -sequence })
	view.Meta.Text = Renderer.MetaText(data, palette)
	view.Message.Text = Util.ApplyRichText(data.Message or "")
	view.Frame.Parent = root.Toasts

	if not Renderer.Active[key] then
		Renderer.Active[key] = {}
	end
	if Renderer.Toasts == nil then
		Renderer.Toasts = {}
	end
	if Renderer.Toasts[key] == nil then
		Renderer.Toasts[key] = {}
	end
	table.insert(Renderer.Toasts[key], view)

	-- Cap the toast stack.
	local maxToasts = LIMITS.MaxToastsOnScreen or 4
	while #Renderer.Toasts[key] > maxToasts do
		local oldest = table.remove(Renderer.Toasts[key], 1)
		Util.Destroy(oldest.Frame)
	end

	-- Slide in from the right.
	view.Frame.Position = UDim2.new(0, 60, 0, 0)
	view.Card.BackgroundTransparency = 1
	Util.Tween(view.Frame, ANIM.ToastInTime, {
		Position = UDim2.new(0, 0, 0, 0),
	}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Util.Tween(view.Card, ANIM.ToastInTime, {
		BackgroundTransparency = 0.04,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local duration = Util.Clamp(tonumber(data.Duration) or 5, 1.5, 60)
	Renderer.RunProgress(view.ProgressFill, duration, key)

	if data.Sound ~= "none" then
		Audio.Play(data.SoundName or "Toast", { Volume = CONFIG.Sounds.Volume * 0.85 })
	end

	task.delay(duration, function()
		if view.Frame.Parent == nil then
			return
		end
		Util.Tween(view.Frame, 0.26, {
			Position = UDim2.new(0, 70, 0, 0),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Util.Tween(view.Card, 0.26, {
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, textObject in ipairs({ view.Meta, view.Title, view.Message, view.Badge }) do
			if textObject then
				Util.Tween(textObject, 0.22, { TextTransparency = 1 })
			end
		end
		Util.Delay(0.3, function()
			Util.Destroy(view.Frame)
			if Renderer.Toasts[key] then
				for index, item in ipairs(Renderer.Toasts[key]) do
					if item == view then
						table.remove(Renderer.Toasts[key], index)
						break
					end
				end
			end
		end)
	end)

	return view
end

AnnouncementPanel.Renderer = Renderer

--// ==========================================================================
--// SECTION 17  ::  RENDERER (ticker, countdown, MOTD, clearing, dispatch)
--// ==========================================================================

local function measureText(text, textSize)
	local width = #tostring(text or "") * (textSize or 15) * 0.55
	local ok, result = pcall(function()
		local size = TextService:GetTextSize(
			tostring(text or ""),
			textSize or 15,
			Enum.Font.GothamBold,
			Vector2.new(10000, 40)
		)
		return size.X
	end)
	if ok and type(result) == "number" and result > 0 then
		return result
	end
	return width
end

function Renderer.StopTicker(root, fadeTime)
	if root == nil or root.Ticker == nil then
		return false
	end
	fadeTime = fadeTime or 0.4
	local ticker = root.Ticker
	ticker.Active = false
	ticker.Token = nil
	Util.CancelTween(ticker.Text)
	Util.Tween(ticker.Bar, fadeTime, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, child in ipairs(ticker.Bar:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			Util.Tween(child, fadeTime, { TextTransparency = 1 })
		end
	end
	for _, child in ipairs(ticker.Bar:GetChildren()) do
		if child:IsA("UIStroke") then
			Util.Tween(child, fadeTime, { Transparency = 1 })
		end
	end
	if ticker.Tag then
		Util.Tween(ticker.Tag, fadeTime, { BackgroundTransparency = 1 })
	end
	Util.Delay(fadeTime + 0.05, function()
		if ticker.Bar and ticker.Bar.Parent then
			ticker.Bar.Visible = false
			ticker.Bar.BackgroundTransparency = 0.12
			if ticker.Text then
				ticker.Text.TextTransparency = 0
				ticker.Text.Text = ""
			end
			if ticker.Tag then
				ticker.Tag.BackgroundTransparency = 0
			end
			if ticker.TagLabel then
				ticker.TagLabel.TextTransparency = 0
			end
			for _, child in ipairs(ticker.Bar:GetChildren()) do
				if child:IsA("UIStroke") then
					child.Transparency = 0.35
				end
			end
		end
	end)
	return true
end

function Renderer.ShowTicker(player, data)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
	if root == nil or root.Ticker == nil or root.Ticker.Bar == nil then
		return false
	end

	local message = tostring(data.Message or "")
	if message == "" then
		return Renderer.StopTicker(root)
	end

	local duration = tonumber(data.Duration)
	if duration == nil or duration <= 0 then
		-- Long enough for the text to cross the screen at TickerSpeed.
		local width = measureText(message, 15)
		duration = math.max(ANIM.TickerMinTime or 9, (width + 1200) / (ANIM.TickerSpeed or 190))
	end
	duration = Util.Clamp(duration, 4, 240)

	local ticker = root.Ticker
	local token = Util.NewGuid()
	ticker.Token = token
	ticker.Active = true

	ticker.Bar.Visible = true
	ticker.Bar.BackgroundTransparency = 1
	ticker.Text.Text = message
	ticker.Text.TextTransparency = 0
	if ticker.TagLabel then
		ticker.TagLabel.Text = data.Tag or "LIVE"
	end
	if ticker.Tag then
		local tagColor = Util.ColorFromName(data.Color, Color3.fromRGB(255, 196, 61))
		ticker.Tag.BackgroundColor3 = tagColor
		if ticker.TagLabel then
			ticker.TagLabel.TextColor3 = Theme.ReadableTextOn(tagColor)
		end
	end

	local textWidth = measureText(message, 15)
	ticker.Text.Size = UDim2.fromOffset(math.ceil(textWidth) + 40, 30)

	-- Fade the bar in, then scroll.
	Util.Tween(ticker.Bar, 0.25, { BackgroundTransparency = 0.12 })
	ticker.Text.Position = UDim2.new(1, 0, 0, 0)

	-- Slide from just off the right edge to fully off the left edge. The
	-- server does not know the track width, so scale 1 -> 0 covers "one
	-- screen" and the extra offset covers the text itself.
	Util.Tween(ticker.Text, duration, {
		Position = UDim2.new(0, -(math.ceil(textWidth) + 40), 0, 0),
	}, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

	if data.Sound ~= "none" then
		Audio.Play(data.SoundName or "Ticker", { Volume = CONFIG.Sounds.Volume * 0.7 })
	end

	task.delay(duration + 0.15, function()
		if ticker.Token ~= token then
			return
		end
		Renderer.StopTicker(root)
	end)

	State.Ticker = { Text = message, Active = true }
	return true
end

function Renderer.ShowCountdown(player, data)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
	if root == nil or root.Countdown == nil or root.Countdown.Container.Parent == nil then
		return false
	end

	local seconds = Util.Clamp(tonumber(data.Seconds) or 5, 1, 300)
	local label = tostring(data.Label or "")
	local caption = tostring(data.Message or "")
	local countdown = root.Countdown
	local token = Util.NewGuid()
	countdown.Token = token
	countdown.Active = true

	countdown.Container.Visible = true
	countdown.Label.Text = label ~= "" and label:upper() or "STARTING IN"
	countdown.Caption.Text = caption
	countdown.Number.TextTransparency = 0
	countdown.Label.TextTransparency = 0.1
	countdown.Caption.TextTransparency = 0

	Util.Spawn(function()
		local remaining = seconds
		while remaining > 0 and countdown.Token == token do
			countdown.Number.Text = Util.FormatCountdown(remaining)
			local popColor = remaining <= 3 and Color3.fromRGB(255, 110, 110) or Color3.fromRGB(255, 214, 90)
			countdown.Number.TextColor3 = popColor

			-- Pop animation on each tick.
			countdown.Number.Size = UDim2.new(1, 0, 0, 120)
			Util.Tween(countdown.Number, 0.18, {
				Size = UDim2.new(1, 0, 0, 132),
			}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			Util.Delay(0.2, function()
				if countdown.Token == token then
					Util.Tween(countdown.Number, 0.5, {
						Size = UDim2.new(1, 0, 0, 120),
					}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
				end
			end)

			if remaining <= 5 and data.Sound ~= "none" then
				Audio.Play("Countdown", { Volume = CONFIG.Sounds.Volume, MinGap = 0.2 })
			end

			local step = remaining >= 60 and 5 or 1
			remaining -= step
			if remaining < 0 then
				remaining = 0
			end
			task.wait(step)
		end

		if countdown.Token ~= token then
			return
		end

		countdown.Number.Text = data.FinishText or "GO!"
		countdown.Number.TextColor3 = Color3.fromRGB(140, 255, 170)
		countdown.Number.Size = UDim2.new(1, 0, 0, 120)
		Util.Tween(countdown.Number, 0.22, {
			Size = UDim2.new(1, 0, 0, 170),
		}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Effects.Flash(root, Color3.fromRGB(255, 255, 255), 0.4, 0.5)
		Effects.Confetti(root, 30)
		if data.Sound ~= "none" then
			Audio.Play("CountdownEnd", { Volume = CONFIG.Sounds.Volume })
		end

		Util.Delay(1.2, function()
			if countdown.Token ~= token then
				return
			end
			countdown.Active = false
			countdown.Token = nil
			for _, textObject in ipairs({ countdown.Number, countdown.Label, countdown.Caption }) do
				if textObject then
					Util.Tween(textObject, 0.35, { TextTransparency = 1 })
				end
			end
			Util.Delay(0.4, function()
				if countdown.Token == nil then
					countdown.Container.Visible = false
					for _, textObject in ipairs({ countdown.Number, countdown.Label, countdown.Caption }) do
						if textObject then
							textObject.TextTransparency = 0
						end
					end
				end
			end)
		end)
	end)

	return true
end

function Renderer.ShowMOTD(player, entry)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
	if root == nil or root.MOTD == nil or root.MOTD.Container.Parent == nil then
		return false
	end
	entry = entry or State.MOTD
	if entry.Enabled == false then
		return false
	end

	local palette = Theme.PaletteFor(entry.Rank or "Owner", entry.Style or "Ice")
	local motd = root.MOTD
	motd.Container.Visible = true
	motd.Card.BackgroundTransparency = 0
	motd.Title.Text = tostring(entry.Title or CONFIG.MOTD.Title):upper()
	motd.Title.TextColor3 = palette.RankColor
	motd.Message.Text = tostring(entry.Message or "")
	motd.Message.TextTransparency = 0
	motd.Footer.Text = entry.UpdatedBy ~= "" and ("set by " .. entry.UpdatedBy) or CONFIG.ServerInfo.FooterText
	motd.Footer.TextTransparency = 0

	for _, stroke in ipairs(motd.Card:GetChildren()) do
		if stroke:IsA("UIStroke") then
			stroke.Color = palette.RankColor
			stroke.Transparency = 0
		end
	end

	motd.Card.Position = UDim2.new(0.5, 0, 0, APPEAR.TopbarOffset - 60)
	Util.Tween(motd.Card, 0.5, {
		Position = UDim2.new(0.5, 0, 0, APPEAR.TopbarOffset + 8),
	}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local duration = Util.Clamp(tonumber(entry.Duration) or CONFIG.MOTD.Duration, 3, 180)
	local token = Util.NewGuid()
	motd.Token = token
	motd.Active = true

	task.delay(duration, function()
		if motd.Token ~= token then
			return
		end
		Renderer.HideMOTD(player, root)
	end)

	return true
end

function Renderer.HideMOTD(player, root)
	root = root or (IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot())
	if root == nil or root.MOTD == nil then
		return false
	end
	local motd = root.MOTD
	motd.Active = false
	motd.Token = nil
	Util.Tween(motd.Card, 0.32, {
		Position = UDim2.new(0.5, 0, 0, APPEAR.TopbarOffset - 70),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, textObject in ipairs({ motd.Title, motd.Message, motd.Footer }) do
		if textObject then
			Util.Tween(textObject, 0.28, { TextTransparency = 1 })
		end
	end
	Util.Delay(0.36, function()
		motd.Container.Visible = false
		for _, textObject in ipairs({ motd.Title, motd.Message, motd.Footer }) do
			if textObject then
				textObject.TextTransparency = 0
			end
		end
		motd.Card.Position = UDim2.new(0.5, 0, 0, APPEAR.TopbarOffset + 8)
	end)
	return true
end

function Renderer.KillAllFor(player)
	local key = rootKey(player)
	local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()

	local active = getActiveList(key)
	for index = #active, 1, -1 do
		Renderer.ExpireHandle(active[index], true)
	end
	table.clear(active)

	if Renderer.Toasts and Renderer.Toasts[key] then
		for _, view in ipairs(Renderer.Toasts[key]) do
			Util.Destroy(view.Frame)
		end
		table.clear(Renderer.Toasts[key])
	end

	if root then
		if root.Ticker then
			Renderer.StopTicker(root, 0.2)
		end
		if root.Alert then
			root.Alert.Container.Visible = false
			root.Alert.Token = nil
			root.Alert.Active = false
		end
		if root.Countdown then
			root.Countdown.Container.Visible = false
			root.Countdown.Token = nil
			root.Countdown.Active = false
		end
		if root.MOTD then
			root.MOTD.Container.Visible = false
			root.MOTD.Token = nil
		end
		if root.Backdrop then
			root.Backdrop.BackgroundTransparency = 1
			root.Backdrop.Visible = false
		end
		Effects.Vignette(root, false, 0.2)
	end

	State.ClearActive()
	return true
end

function Renderer.KillAll()
	if IS_SERVER then
		for _, player in ipairs(Players:GetPlayers()) do
			Renderer.KillAllFor(player)
		end
	else
		Renderer.KillAllFor(nil)
	end
	return true
end

function Renderer.BannerCount(player)
	local key = rootKey(player)
	return #getActiveList(key)
end

--// ---------- dispatch ------------------------------------------------------

-- Single entry point: "render this payload for this viewer".
function Renderer.Render(player, payload)
	if type(payload) ~= "table" then
		return false
	end
	local kind = tostring(payload.Kind or "Banner")
	Renderer.LastKind = kind

	if kind == "Clear" then
		if payload.Target == "all" then
			Renderer.KillAll()
		else
			Renderer.KillAllFor(player)
		end
		return true
	elseif kind == "Alert" then
		return Renderer.ShowAlert(player, payload) ~= nil
	elseif kind == "Toast" then
		return Renderer.ShowToast(player, payload) ~= nil
	elseif kind == "Ticker" then
		return Renderer.ShowTicker(player, payload)
	elseif kind == "Countdown" then
		return Renderer.ShowCountdown(player, payload)
	elseif kind == "MOTD" then
		return Renderer.ShowMOTD(player, payload)
	elseif kind == "Effect" then
		local root = IS_SERVER and Renderer.GetRoot(player) or Renderer.GetRoot()
		Effects.Apply(root, payload, root and root.Role or "server")
		return true
	elseif kind == "Banner" then
		return Renderer.ShowBanner(player, payload) ~= nil
	end

	Util.Debug("unknown render kind:", kind)
	return false
end

AnnouncementPanel.Renderer = Renderer

--// ==========================================================================
--// SECTION 18  ::  BROADCASTER
--// The only public "make something appear" API. Commands, the scheduler, chaos
--// mode and the client console all go through here so filtering, history,
--// rate limiting and stats can never be bypassed.
--// ==========================================================================

local Broadcaster = {}

Broadcaster.LastBroadcastAt = {} -- [userId] = clock
Broadcaster.LastAlertAt = {} -- [userId] = clock
Broadcaster.LastChaosAt = {} -- [userId] = clock

local TARGET_ALIASES = {
	all = "all",
	everyone = "all",
	server = "all",
	global = "all",
	admins = "admins",
	admin = "admins",
	owners = "owners",
	owner = "owners",
	mods = "mods",
	mod = "mods",
	moderators = "mods",
	staff = "staff",
	team = "staff",
	helpers = "helpers",
	helper = "helpers",
	vips = "vips",
	vip = "vips",
	nonstaff = "nonstaff",
	guests = "nonstaff",
	players = "nonstaff",
	random = "random",
	me = "me",
	self = "me",
}

--// ---------- targets -------------------------------------------------------

function Broadcaster.ResolveTargets(selector, originPlayer)
	local players = Players:GetPlayers()
	if selector == nil or selector == "" then
		return players, "all"
	end

	local raw = tostring(selector):lower():gsub("^@", "")
	local alias = TARGET_ALIASES[raw]

	if alias == "all" then
		return players, "all"
	end

	if alias == "me" then
		if originPlayer then
			return { originPlayer }, originPlayer.Name
		end
		return {}, "me"
	end

	if alias == "random" then
		if #players == 0 then
			return {}, "random"
		end
		return { players[math.random(1, #players)] }, "random"
	end

	if alias == "staff" then
		local result = {}
		for _, player in ipairs(players) do
			if RankSystem.IsStaff(player) then
				table.insert(result, player)
			end
		end
		return result, "staff"
	end

	if alias == "nonstaff" then
		local result = {}
		for _, player in ipairs(players) do
			if not RankSystem.IsStaff(player) then
				table.insert(result, player)
			end
		end
		return result, "nonstaff"
	end

	if alias == "owners" or alias == "admins" or alias == "mods" or alias == "helpers" or alias == "vips" then
		local rankName = Theme.GetRankName(alias:sub(1, #alias - 1))
		return RankSystem.GetPlayersWithRank(rankName, true), alias
	end

	-- Explicit username, display name or UserId.
	local byId = tonumber(raw)
	if byId then
		local found = Players:GetPlayerByUserId(byId)
		if found then
			return { found }, found.Name
		end
		return {}, "userid:" .. raw
	end

	local result = {}
	for _, player in ipairs(players) do
		if player.Name:lower() == raw
			or player.DisplayName:lower() == raw
			or player.Name:lower():sub(1, #raw) == raw then
			table.insert(result, player)
		end
	end
	return result, raw
end

function Broadcaster.FindPlayer(query)
	local targets = Broadcaster.ResolveTargets(query, nil)
	if #targets == 0 then
		return nil
	end
	return targets[1]
end

--// ---------- payload building ----------------------------------------------

function Broadcaster.DefaultEffects(styleName)
	local style = Theme.GetStyle(styleName)
	return {
		Flash = style.Flash == true,
		Shake = style.Shake == true,
		Confetti = style.Confetti == true,
		Vignette = false,
		Lighting = false,
		Blur = false,
		Dim = false,
	}
end

-- input: { Kind, Title, Message, Style, Duration, Rank, SenderName, Effects,
--          Color, Sound, Target, Seconds, Label }
-- context: { Origin = player, Rank = "Owner", Source = "command" }
function Broadcaster.BuildPayload(input, context)
	input = input or {}
	context = context or {}

	local rankName = input.Rank or context.Rank or "Owner"
	rankName = Theme.GetRankName(rankName)
	local rankMeta = Theme.GetRank(rankName)

	local styleName = Theme.GetStyle(input.Style or CONFIG.DefaultStyle) and (input.Style or CONFIG.DefaultStyle) or CONFIG.DefaultStyle
	if not CONFIG.Styles[styleName] then
		for name in pairs(CONFIG.Styles) do
			if name:lower() == tostring(input.Style or ""):lower() then
				styleName = name
				break
			end
		end
	end

	local kind = tostring(input.Kind or "Banner")
	local senderName = tostring(input.SenderName or (context.Origin and context.Origin.Name) or "System")
	local senderId = tonumber(input.SenderId or (context.Origin and context.Origin.UserId) or 0)

	-- Duration clamping, respecting the sender's rank ceiling.
	local maxByRank = tonumber(rankMeta.MaxDuration or LIMITS.MaxDuration)
	local duration = tonumber(input.Duration) or LIMITS.DefaultDuration
	duration = Util.Clamp(duration, LIMITS.MinDuration, math.min(LIMITS.MaxDuration, math.max(LIMITS.MinDuration, maxByRank)))

	local message = tostring(input.Message or "")
	local title = tostring(input.Title or "")

	local payload = {
		Id = input.Id or Util.NewGuid(),
		Kind = kind,
		Title = title,
		Message = message,
		Rank = rankName,
		RankDisplay = rankMeta.DisplayName,
		Badge = rankMeta.Badge,
		SenderName = senderName,
		SenderId = senderId,
		Style = styleName,
		Duration = duration,
		Color = input.Color,
		Sound = input.Sound,
		SoundName = input.SoundName,
		Effects = type(input.Effects) == "table" and input.Effects or Broadcaster.DefaultEffects(styleName),
		Target = input.Target or "all",
		Seconds = tonumber(input.Seconds),
		Label = input.Label,
		FinishText = input.FinishText,
		Tag = input.Tag,
		Timestamp = os.time(),
		Source = context.Source or "command",
		Whisper = input.Whisper == true,
	}

	-- Merge any per-style sound choice when the caller did not pick one.
	if payload.Sound == nil then
		local style = Theme.GetStyle(styleName)
		payload.SoundName = style.Sound or "Banner"
	end

	return payload
end

-- Runs the text filter and length caps. Returns payload, warnings.
function Broadcaster.SanitizePayload(payload, context)
	local warnings = {}
	if type(payload) ~= "table" then
		return nil, { "invalid payload" }
	end

	local maxLength = LIMITS.MaxMessageLength
	local titleLength = LIMITS.MaxTitleLength

	local rawMessage = tostring(payload.Message or "")
	if #rawMessage > CONFIG.Moderation.MaxLengthBeforeReject then
		table.insert(warnings, "message too long")
		rawMessage = Util.Truncate(rawMessage, CONFIG.Moderation.MaxLengthBeforeReject)
	end

	local message, truncated = MessageFilter.Prepare(rawMessage, maxLength)
	if truncated then
		table.insert(warnings, "message truncated")
	end

	local title, titleTruncated = MessageFilter.Prepare(tostring(payload.Title or ""), titleLength)
	if titleTruncated then
		table.insert(warnings, "title truncated")
	end

	local blocked, word = MessageFilter.IsBlocked(message)
	if blocked then
		table.insert(warnings, "blocked word: " .. tostring(word))
	end

	if IS_SERVER and context and context.Origin then
		message = MessageFilter.FilterBroadcast(context.Origin, message)
		title = MessageFilter.FilterBroadcast(context.Origin, title)
	elseif not IS_SERVER then
		message = MessageFilter.FallbackCensor(message)
		title = MessageFilter.FallbackCensor(title)
	end

	payload.Message = message
	payload.Title = title
	return payload, warnings
end

--// ---------- rate limiting -------------------------------------------------

function Broadcaster.CheckCooldown(origin, kind)
	if origin == nil then
		return true, 0
	end
	local key = origin.UserId
	local now = os.clock()
	local tableRef = nil
	local gap = LIMITS.AnnounceCooldown

	if kind == "Alert" then
		tableRef = Broadcaster.LastAlertAt
		gap = LIMITS.AlertCooldown
	elseif kind == "Chaos" then
		tableRef = Broadcaster.LastChaosAt
		gap = LIMITS.ChaosCooldown
	else
		tableRef = Broadcaster.LastBroadcastAt
		gap = LIMITS.AnnounceCooldown
	end

	local last = tableRef[key] or 0
	local remaining = gap - (now - last)
	if remaining > 0 then
		return false, Util.Round(remaining, 1)
	end
	tableRef[key] = now
	return true, 0
end

--// ---------- the main broadcast --------------------------------------------

-- options: { Origin = player, Rank = string, Source = string, SkipHistory = bool,
--            SkipCooldown = bool, Silent = bool }
function Broadcaster.Broadcast(input, options)
	options = options or {}
	local context = {
		Origin = options.Origin,
		Rank = options.Rank or (options.Origin and RankSystem.GetRank(options.Origin)) or "Owner",
		Source = options.Source or "api",
	}

	local payload = Broadcaster.BuildPayload(input, context)
	local warnings
	payload, warnings = Broadcaster.SanitizePayload(payload, context)
	if payload == nil then
		return false, { Ok = false, Reason = "sanitize failed", Warnings = warnings }
	end

	-- Cooldowns only apply to real senders (not the scheduler / chaos loop).
	if context.Origin and not options.SkipCooldown then
		local allowed, remaining = Broadcaster.CheckCooldown(context.Origin, payload.Kind)
		if not allowed then
			State.Bump("CommandsDenied")
			return false, {
				Ok = false,
				Reason = "cooldown",
				Remaining = remaining,
				Payload = payload,
			}
		end
	end

	-- Resolve the audience.
	local targets, description
	if IS_SERVER then
		if payload.Whisper then
			targets = RankSystem.GetStaffPlayers()
			description = "staff"
		else
			targets, description = Broadcaster.ResolveTargets(payload.Target, context.Origin)
		end
	else
		targets = { Players.LocalPlayer }
		description = "local"
	end

	payload.Audience = description
	payload.AudienceCount = #targets

	if #targets == 0 then
		return false, { Ok = false, Reason = "no targets", Payload = payload }
	end

	-- Render for every viewer.
	local rendered = 0
	for _, target in ipairs(targets) do
		local ok, err = pcall(function()
			Renderer.Render(target, payload)
		end)
		if ok then
			rendered += 1
		else
			Util.Warn("render failed for", target.Name, err)
			State.Bump("Errors")
		end
	end

	-- Companion clients get a tiny "polish" packet: real camera shake and
	-- local sound, since the server cannot touch a client's camera.
	if IS_SERVER and Net.IsServerActive() then
		local polish = {
			Kind = "Effect",
			Effects = {
				Shake = payload.Effects and payload.Effects.Shake == true,
			},
			Sound = payload.Sound,
			SoundName = payload.SoundName,
			Style = payload.Style,
			Id = payload.Id,
		}
		if polish.Effects.Shake or payload.SoundName then
			Net.FirePlayers(targets, "Polish", polish)
		end
	end

	-- Stats + history.
	local statKey = ({
		Banner = "Announcements",
		Alert = "Alerts",
		Toast = "Toasts",
		Ticker = "Tickers",
		Countdown = "Countdowns",
	})[payload.Kind] or "Announcements"
	State.Bump(statKey)

	if not options.SkipHistory then
		History.Record(payload, { AudienceCount = #targets, Warnings = warnings })
	end

	if CONFIG.Debug.PrintRender then
		Util.Debug("broadcast", payload.Kind, "to", #targets, "targets:", payload.Message)
	end

	return true, {
		Ok = true,
		Payload = payload,
		Targets = #targets,
		Audience = description,
		Warnings = warnings,
		Rendered = rendered,
	}
end

-- Convenience wrappers used all over the command list.
function Broadcaster.Announce(message, options)
	options = options or {}
	return Broadcaster.Broadcast({
		Kind = "Banner",
		Message = message,
		Title = options.Title,
		Style = options.Style or CONFIG.DefaultStyle,
		Duration = options.Duration,
		Rank = options.Rank,
		SenderName = options.SenderName,
		Target = options.Target,
		Color = options.Color,
		Effects = options.Effects,
	}, options)
end

function Broadcaster.Alert(message, options)
	options = options or {}
	options.Rank = options.Rank or "Owner"
	return Broadcaster.Broadcast({
		Kind = "Alert",
		Message = message,
		Title = options.Title or "ATTENTION",
		Style = options.Style or "Emergency",
		Duration = options.Duration or 8,
		Rank = options.Rank,
		SenderName = options.SenderName,
		Target = options.Target,
		Effects = options.Effects or { Flash = true, Shake = true, Dim = true, Lighting = true },
	}, options)
end

function Broadcaster.Toast(message, options)
	options = options or {}
	return Broadcaster.Broadcast({
		Kind = "Toast",
		Message = message,
		Title = options.Title,
		Style = options.Style or CONFIG.DefaultStyle,
		Duration = options.Duration or 5,
		Rank = options.Rank,
		SenderName = options.SenderName,
		Target = options.Target,
	}, options)
end

function Broadcaster.Ticker(message, options)
	options = options or {}
	return Broadcaster.Broadcast({
		Kind = "Ticker",
		Message = message,
		Style = options.Style or "Gold",
		Duration = options.Duration,
		Rank = options.Rank or "Owner",
		SenderName = options.SenderName,
		Target = options.Target,
		Tag = options.Tag or "LIVE",
		Color = options.Color,
	}, options)
end

function Broadcaster.Countdown(seconds, label, options)
	options = options or {}
	return Broadcaster.Broadcast({
		Kind = "Countdown",
		Seconds = seconds,
		Label = label,
		Message = options.Caption,
		FinishText = options.FinishText,
		Duration = math.max(3, (seconds or 5) + 2),
		Rank = options.Rank or "Owner",
		SenderName = options.SenderName,
		Target = options.Target,
		Style = options.Style or "Gold",
	}, options)
end

function Broadcaster.Preset(name, options)
	options = options or {}
	local preset = CONFIG.Presets[tostring(name):lower()]
	if preset == nil then
		for key, value in pairs(CONFIG.Presets) do
			if key:lower() == tostring(name):lower() then
				preset = value
				break
			end
		end
	end
	if preset == nil then
		return false, { Ok = false, Reason = "unknown preset: " .. tostring(name) }
	end
	return Broadcaster.Broadcast({
		Kind = preset.Kind or "Banner",
		Title = preset.Title,
		Message = preset.Message,
		Style = preset.Style or CONFIG.DefaultStyle,
		Duration = preset.Duration,
		Effects = preset.Effects,
		Target = preset.Target or options.Target,
	}, options)
end

function Broadcaster.PresetNames()
	return Util.SortedKeys(CONFIG.Presets)
end

AnnouncementPanel.Broadcaster = Broadcaster

--// ==========================================================================
--// SECTION 19  ::  COMMANDS
--// Every staff command is one table entry. Add your own by copying a block.
--// ==========================================================================

local Commands = {}
Commands.Registry = {}
Commands.ByAlias = {}
Commands.Categories = {
	"Announcements", "Effects", "Moderation", "Information", "System",
}

local function registerCommand(definition)
	if type(definition) ~= "table" or type(definition.Name) ~= "string" then
		Util.Warn("invalid command definition")
		return nil
	end
	definition.Aliases = definition.Aliases or {}
	definition.Category = definition.Category or "Announcements"
	definition.Permission = definition.Permission or definition.Name
	definition.Usage = definition.Usage or (":" .. definition.Name)
	definition.Description = definition.Description or ""
	definition.Examples = definition.Examples or {}
	definition.Order = definition.Order or 100
	Commands.Registry[definition.Name] = definition
	Commands.ByAlias[definition.Name:lower()] = definition.Name
	for _, alias in ipairs(definition.Aliases) do
		Commands.ByAlias[tostring(alias):lower()] = definition.Name
	end
	return definition
end

function Commands.Get(name)
	if type(name) ~= "string" then
		return nil
	end
	local canonical = Commands.ByAlias[name:lower()]
	if canonical then
		return Commands.Registry[canonical]
	end
	return nil
end

function Commands.List()
	local result = {}
	for _, definition in pairs(Commands.Registry) do
		table.insert(result, definition)
	end
	table.sort(result, function(a, b)
		if (a.Order or 100) == (b.Order or 100) then
			return a.Name < b.Name
		end
		return (a.Order or 100) < (b.Order or 100)
	end)
	return result
end

function Commands.ForPlayer(player)
	local result = {}
	for _, definition in ipairs(Commands.List()) do
		if RankSystem.Can(player, definition.Permission) then
			table.insert(result, definition)
		end
	end
	return result
end

function Commands.Names()
	local names = {}
	for name in pairs(Commands.Registry) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- Public extension point. Other scripts (or your own code at the bottom of this
-- file) can add commands that behave exactly like the built-ins: same parser,
-- same permission gates, same cooldowns, same history log, same console.
--
--   AnnouncementPanel.Commands.Register({
--       Name = "boss",
--       Aliases = { "spawnboss" },
--       Category = "Announcements",      -- Announcements | Effects | Moderation | System | Information
--       Usage = ":boss <name>",
--       Description = "Announce a boss spawn.",
--       Examples = { ":boss Voragos" },
--       Order = 120,                     -- sort position inside :help
--       Permission = "boss",             -- key checked against rank Permissions ("*" = always allowed)
--       ServerOnly = false,              -- true = reply with a warning on a client-only install
--       NeedsMessage = false,            -- true = reject when no message text was given
--       Run = function(ctx)
--           -- ctx: Player, Rank, Meta, Args, Flags, Message, Raw, Source,
--           --      Reply(text, kind), ReplyAll(text), RequireServer(), RequireClient()
--           ctx.Reply("Boss announced.", "success")
--           return true
--       end,
--   })
function Commands.Register(definition)
	return registerCommand(definition)
end

-- Removes a command (and its aliases) again. Returns true if it existed.
function Commands.Unregister(name)
	local definition = Commands.Get(name)
	if definition == nil then
		return false
	end
	Commands.Registry[definition.Name] = nil
	for alias in pairs(Commands.ByAlias) do
		if Commands.ByAlias[alias] == definition.Name then
			Commands.ByAlias[alias] = nil
		end
	end
	return true
end

--// ---------- helpers shared by commands ------------------------------------

local function effectTableFromFlags(flags, base)
	local effects = Util.ShallowCopy(base or {})
	if flags["no-effects"] or flags["nofx"] then
		return { Flash = false, Shake = false, Confetti = false, Vignette = false, Lighting = false, Dim = false }
	end
	if flags.flash then
		effects.Flash = true
	end
	if flags.shake then
		effects.Shake = true
	end
	if flags.confetti then
		effects.Confetti = true
	end
	if flags.vignette then
		effects.Vignette = true
	end
	if flags.lighting then
		effects.Lighting = true
	end
	if flags.blur then
		effects.Blur = true
	end
	if flags.dim then
		effects.Dim = true
	end
	return effects
end

local function durationFromFlags(flags, ctx, fallback)
	local value = flags.time or flags.duration or flags.t or flags.d
	local numeric = tonumber(value)
	if numeric == nil then
		return fallback
	end
	local cap = RankSystem.MaxDuration(ctx.Player)
	if cap and cap > 0 then
		numeric = math.min(numeric, cap)
	end
	return Util.Clamp(numeric, LIMITS.MinDuration, LIMITS.MaxDuration)
end

--// ---------- announcements -------------------------------------------------

registerCommand({
	Name = "announce",
	Aliases = { "a", "say", "msg", "message" },
	Category = "Announcements",
	Order = 1,
	Usage = ":announce <message> [-t seconds] [-s style] [-c color] [--to target] [--title text] [--sound name]",
	Description = "Pins a glowing banner to the top of everyone's screen.",
	Examples = {
		":announce Server restart in 5 minutes",
		":announce Double XP is live! -s Gold -t 15",
		":a Hello admins --to admins -c cyan",
	},
	NeedsMessage = true,
	Run = function(ctx)
		local options = {
			Origin = ctx.Player,
			Source = ctx.Source,
		}
		local ok, result = Broadcaster.Broadcast({
			Kind = "Banner",
			Message = ctx.Message,
			Title = ctx.Flags.title,
			Style = ctx.Flags.style or ctx.Flags.s or CONFIG.DefaultStyle,
			Color = ctx.Flags.color or ctx.Flags.c,
			Duration = durationFromFlags(ctx.Flags, ctx, LIMITS.DefaultDuration),
			Target = ctx.Flags.to or ctx.Flags.target or "all",
			Sound = ctx.Flags.sound,
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
			Effects = effectTableFromFlags(ctx.Flags),
		}, options)
		if not ok then
			ctx.Reply("Announcement failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		if result.Warnings and #result.Warnings > 0 then
			ctx.Reply("note: " .. table.concat(result.Warnings, ", "), "warn")
		end
		ctx.Reply(string.format("Announced to %d player(s).", result.Targets or 0), "success")
		return true
	end,
})

registerCommand({
	Name = "alert",
	Aliases = { "alarm", "emergency", "urgent" },
	Category = "Announcements",
	Order = 2,
	Usage = ":alert <message> [-t seconds] [--title text]",
	Description = "Full-screen takeover with a dimmed backdrop. Use sparingly.",
	Examples = { ":alert The server is restarting NOW", ":alarm Intruder in the base --title SECURITY" },
	NeedsMessage = true,
	Run = function(ctx)
		local ok, result = Broadcaster.Broadcast({
			Kind = "Alert",
			Message = ctx.Message,
			Title = ctx.Flags.title or "ATTENTION",
			Style = ctx.Flags.style or "Emergency",
			Duration = durationFromFlags(ctx.Flags, ctx, 8),
			Target = ctx.Flags.to or ctx.Flags.target or "all",
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
			Effects = effectTableFromFlags(ctx.Flags, {
				Flash = true, Shake = true, Dim = true, Lighting = FX.EnableLighting,
			}),
		}, { Origin = ctx.Player, Source = ctx.Source })
		if not ok then
			ctx.Reply("Alert failed: " .. tostring(result and result.Reason or "unknown")
				.. (result and result.Remaining and (" (wait " .. result.Remaining .. "s)") or ""), "error")
			return false
		end
		ctx.Reply(string.format("Alert sent to %d player(s).", result.Targets or 0), "success")
		return true
	end,
})

registerCommand({
	Name = "ticker",
	Aliases = { "news", "marquee", "scroll" },
	Category = "Announcements",
	Order = 3,
	Usage = ":ticker <message> [-t seconds] [-c color] [--tag LIVE]",
	Description = "Scrolling news bar across the very top of the screen.",
	Examples = { ":ticker Weekend event is live all weekend long", ":news Update 2.1 released -c neon" },
	NeedsMessage = true,
	Run = function(ctx)
		local ok, result = Broadcaster.Broadcast({
			Kind = "Ticker",
			Message = ctx.Message,
			Duration = tonumber(ctx.Flags.time or ctx.Flags.t) or nil,
			Color = ctx.Flags.color or ctx.Flags.c,
			Tag = ctx.Flags.tag or "LIVE",
			Target = ctx.Flags.to or ctx.Flags.target or "all",
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
		}, { Origin = ctx.Player, Source = ctx.Source })
		if not ok then
			ctx.Reply("Ticker failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		ctx.Reply("Ticker running.", "success")
		return true
	end,
})

registerCommand({
	Name = "toast",
	Aliases = { "notify", "n", "note" },
	Category = "Announcements",
	Order = 4,
	Usage = ":toast <message> [-t seconds] [--to target] [--title text]",
	Description = "Small notification in the bottom-right corner.",
	Examples = { ":toast Report commands are open", ":n Welcome back! --to @Steve" },
	NeedsMessage = true,
	Run = function(ctx)
		local ok, result = Broadcaster.Broadcast({
			Kind = "Toast",
			Message = ctx.Message,
			Title = ctx.Flags.title,
			Duration = durationFromFlags(ctx.Flags, ctx, 5),
			Target = ctx.Flags.to or ctx.Flags.target or "all",
			Style = ctx.Flags.style or CONFIG.DefaultStyle,
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
		}, { Origin = ctx.Player, Source = ctx.Source })
		if not ok then
			ctx.Reply("Toast failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		ctx.Reply(string.format("Toast sent to %d player(s).", result.Targets or 0), "success")
		return true
	end,
})

registerCommand({
	Name = "countdown",
	Aliases = { "timer", "cd", "count" },
	Category = "Announcements",
	Order = 5,
	Usage = ":countdown <seconds> [label] [--finish GO!]",
	Description = "Big centred countdown that pops on every tick.",
	Examples = { ":countdown 10", ":cd 30 Restarting server", ":timer 5 Race starts --finish RACE!" },
	Run = function(ctx)
		local seconds = tonumber(ctx.Args[1])
		local label = nil
		if seconds == nil then
			-- Maybe the whole thing is "30 Restarting server" without quotes.
			seconds = tonumber(ctx.Message:match("^(%d+)"))
			label = ctx.Message:match("^%d+%s+(.+)$")
		else
			label = table.concat(Util.ShallowCopy(ctx.Args), " ", 2)
			if label == "" then
				label = nil
			end
		end
		if seconds == nil then
			ctx.Reply("Usage: " .. ":countdown <seconds> [label]", "error")
			return false
		end
		seconds = Util.Clamp(seconds, 1, 600)
		local ok, result = Broadcaster.Broadcast({
			Kind = "Countdown",
			Seconds = seconds,
			Label = label,
			FinishText = ctx.Flags.finish or "GO!",
			Duration = seconds + 2,
			Target = ctx.Flags.to or ctx.Flags.target or "all",
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
		}, { Origin = ctx.Player, Source = ctx.Source })
		if not ok then
			ctx.Reply("Countdown failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		ctx.Reply("Countdown started: " .. seconds .. "s", "success")
		return true
	end,
})

registerCommand({
	Name = "broadcast",
	Aliases = { "bc" },
	Category = "Announcements",
	Order = 6,
	Usage = ":broadcast <message>",
	Description = "Golden banner forced to every player, ignoring --to.",
	NeedsMessage = true,
	Run = function(ctx)
		local ok, result = Broadcaster.Broadcast({
			Kind = "Banner",
			Message = ctx.Message,
			Title = ctx.Flags.title or "BROADCAST",
			Style = "Gold",
			Duration = durationFromFlags(ctx.Flags, ctx, 12),
			Target = "all",
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
			Effects = effectTableFromFlags(ctx.Flags, { Flash = true, Confetti = true }),
		}, { Origin = ctx.Player, Source = ctx.Source })
		if not ok then
			ctx.Reply("Broadcast failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		ctx.Reply(string.format("Broadcast to %d player(s).", result.Targets or 0), "success")
		return true
	end,
})

registerCommand({
	Name = "preset",
	Aliases = { "quick", "p" },
	Category = "Announcements",
	Order = 7,
	Usage = ":preset <name>",
	Description = "Fires a pre-configured bundle from CONFIG.Presets.",
	Examples = { ":preset restart", ":quick doublexp" },
	Run = function(ctx)
		local name = ctx.Args[1]
		if name == nil then
			ctx.Reply("Presets: " .. table.concat(Broadcaster.PresetNames(), ", "), "info")
			return false
		end
		local ok, result = Broadcaster.Preset(name, {
			Origin = ctx.Player,
			Source = ctx.Source,
			Target = ctx.Flags.to or ctx.Flags.target,
		})
		if not ok then
			ctx.Reply(tostring(result and result.Reason or "preset failed"), "error")
			return false
		end
		ctx.Reply("Preset '" .. tostring(name) .. "' fired.", "success")
		return true
	end,
})

registerCommand({
	Name = "whisper",
	Aliases = { "w", "staff", "sc" },
	Category = "Announcements",
	Order = 8,
	Usage = ":whisper <message>",
	Description = "Banner visible to staff only. Players never see it.",
	NeedsMessage = true,
	Run = function(ctx)
		local ok, result = Broadcaster.Broadcast({
			Kind = ctx.Flags.toast and "Toast" or "Banner",
			Message = ctx.Message,
			Title = ctx.Flags.title or "STAFF CHANNEL",
			Style = "Shadow",
			Duration = durationFromFlags(ctx.Flags, ctx, 8),
			Whisper = true,
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
		}, { Origin = ctx.Player, Source = ctx.Source, SkipCooldown = true })
		if not ok then
			ctx.Reply("Whisper failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		ctx.Reply(string.format("Whispered to %d staff member(s).", result.Targets or 0), "success")
		return true
	end,
})

registerCommand({
	Name = "test",
	Aliases = { "preview", "demo" },
	Category = "Announcements",
	Order = 9,
	Usage = ":test [message]",
	Description = "Sends an announcement to you only. Nobody else sees it.",
	Run = function(ctx)
		local message = ctx.Message
		if message == "" then
			message = "This is a test announcement. Only you can see it."
		end
		local ok, result = Broadcaster.Broadcast({
			Kind = ctx.Flags.kind or "Banner",
			Message = message,
			Title = ctx.Flags.title or "TEST",
			Style = ctx.Flags.style or "Neon",
			Duration = durationFromFlags(ctx.Flags, ctx, 6),
			Target = "me",
			SenderName = ctx.Player and ctx.Player.Name or "System",
			Rank = ctx.Rank,
			Effects = effectTableFromFlags(ctx.Flags, { Flash = false, Shake = false, Confetti = true }),
		}, { Origin = ctx.Player, Source = ctx.Source, SkipCooldown = true })
		if not ok then
			ctx.Reply("Test failed: " .. tostring(result and result.Reason or "unknown"), "error")
			return false
		end
		ctx.Reply("Test sent to you only.", "success")
		return true
	end,
})

registerCommand({
	Name = "motd",
	Aliases = { "messageoftheday", "welcome" },
	Category = "Announcements",
	Order = 10,
	Usage = ":motd <message> | :motd --clear | :motd --show",
	Description = "Sets the message shown to everyone who joins from now on.",
	Examples = { ":motd Weekend event is live!", ":motd --clear", ":motd --show" },
	Run = function(ctx)
		if ctx.Flags.clear then
			State.MOTD.Enabled = false
			State.MOTD.Message = ""
			State.Bump("MOTDUpdates")
			if IS_SERVER and AnnouncementPanel.Persistence and CONFIG.Persistence.SaveMOTD then
				Persistence.Save()
			end
			ctx.Reply("MOTD cleared.", "success")
			return true
		end

		if ctx.Flags.show or ctx.Message == "" then
			ctx.Reply(string.format("MOTD (%s): [%s] %s",
				State.MOTD.Enabled and "enabled" or "disabled",
				tostring(State.MOTD.Title),
				tostring(State.MOTD.Message)), "info")
			return true
		end

		State.MOTD.Enabled = true
		State.MOTD.Message = ctx.Message
		State.MOTD.Title = ctx.Flags.title or CONFIG.MOTD.Title
		State.MOTD.Style = ctx.Flags.style or CONFIG.MOTD.Style
		State.MOTD.Duration = durationFromFlags(ctx.Flags, ctx, CONFIG.MOTD.Duration)
		State.MOTD.UpdatedBy = ctx.Player and ctx.Player.Name or "System"
		State.MOTD.UpdatedAt = os.time()
		table.clear(State.MOTD.Seen)
		State.Bump("MOTDUpdates")

		if ctx.Flags.now then
			if IS_SERVER then
				for _, player in ipairs(Players:GetPlayers()) do
					Renderer.ShowMOTD(player, State.MOTD)
				end
			else
				Renderer.ShowMOTD(nil, State.MOTD)
			end
		end

		if IS_SERVER and CONFIG.Persistence.SaveMOTD then
			Persistence.Save()
		end

		ctx.Reply("MOTD updated and will show on join.", "success")
		return true
	end,
})

registerCommand({
	Name = "clear",
	Aliases = { "clean", "stop", "reset", "hide" },
	Category = "Announcements",
	Order = 11,
	Usage = ":clear [--to target]",
	Description = "Removes every banner, toast, ticker, alert and countdown.",
	Run = function(ctx)
		if IS_SERVER then
			local targets, description = Broadcaster.ResolveTargets(ctx.Flags.to or "all", ctx.Player)
			if description == "all" then
				Renderer.KillAll()
			else
				for _, player in ipairs(targets) do
					Renderer.KillAllFor(player)
				end
			end
			Net.FireAllClients("Clear", { Scope = description })
			ctx.Reply("Cleared the screen for " .. tostring(#targets) .. " player(s).", "success")
		else
			Renderer.KillAllFor(nil)
			ctx.Reply("Cleared your screen.", "success")
		end
		return true
	end,
})

registerCommand({
	Name = "history",
	Aliases = { "h", "log", "recent" },
	Category = "Information",
	Order = 12,
	Usage = ":history [count] [search]",
	Description = "Shows the most recent announcements.",
	Examples = { ":history", ":history 15", ":history 5 restart" },
	Run = function(ctx)
		local count = tonumber(ctx.Args[1]) or 6
		local query = nil
		if tonumber(ctx.Args[1]) and ctx.Args[2] then
			query = table.concat(ctx.Args, " ", 2)
		elseif not tonumber(ctx.Args[1]) and ctx.Message ~= "" then
			query = ctx.Message
		end
		count = Util.Clamp(count, 1, LIMITS.MaxHistoryEntries)
		local entries = query and History.Search(query, count) or State.GetHistory(count)
		if #entries == 0 then
			ctx.Reply("Nothing in the history" .. (query and (" for '" .. query .. "'") or "") .. ".", "info")
			return true
		end
		ctx.Reply("Recent announcements (" .. #entries .. "):", "info")
		for _, entry in ipairs(entries) do
			ctx.Reply(History.FormatLine(entry), "info")
		end
		return true
	end,
})

registerCommand({
	Name = "clearhistory",
	Aliases = { "ch" },
	Category = "System",
	Order = 13,
	Usage = ":clearhistory",
	Description = "Empties the announcement history log.",
	Run = function(ctx)
		History.Clear()
		ctx.Reply("History cleared.", "success")
		return true
	end,
})

--// ---------- effects -------------------------------------------------------

registerCommand({
	Name = "flash",
	Aliases = { "strobe", "blink" },
	Category = "Effects",
	Order = 20,
	Usage = ":flash [-c color] [--times 3]",
	Description = "Flashes the screen for everyone.",
	Run = function(ctx)
		local color = Util.ColorFromName(ctx.Flags.color or ctx.Flags.c, FX.FlashColor)
		local times = Util.Clamp(tonumber(ctx.Flags.times) or 1, 1, 8)
		if IS_SERVER then
			if times > 1 then
				Effects.LightingStrobe(times, 0.22, color)
			else
				Effects.LightingFlash(color, FX.LightingPulseTime, 2)
			end
			Net.FireAllClients("Effect", { Kind = "Effect", Effects = { Flash = true }, FlashColor = Util.ColorToHex(color) })
			for _, player in ipairs(Players:GetPlayers()) do
				local root = Renderer.GetRoot(player)
				Effects.Flash(root, color)
			end
		else
			local root = Renderer.GetRoot()
			for _ = 1, times do
				Effects.Flash(root, color)
				task.wait(0.25)
			end
		end
		ctx.Reply("Flash fired.", "success")
		return true
	end,
})

registerCommand({
	Name = "shake",
	Aliases = { "quake", "earthquake", "rumble" },
	Category = "Effects",
	Order = 21,
	Usage = ":shake [-i intensity]",
	Description = "Shakes every camera and the whole panel.",
	Run = function(ctx)
		local intensity = Util.Clamp(tonumber(ctx.Flags.intensity or ctx.Flags.i) or FX.CameraShakeIntensity, 0.1, 6)
		if IS_SERVER then
			Net.FireAllClients("Effect", { Kind = "Effect", Effects = { Shake = true }, Intensity = intensity })
			for _, player in ipairs(Players:GetPlayers()) do
				Effects.ShakeGUI(Renderer.GetRoot(player), intensity)
			end
		end
		Effects.ShakeCamera(intensity)
		Effects.ShakeGUI(Renderer.GetRoot(IS_SERVER and ctx.Player or nil), intensity)
		ctx.Reply("Shake fired.", "success")
		return true
	end,
})

registerCommand({
	Name = "confetti",
	Aliases = { "party", "celebrate", "rain" },
	Category = "Effects",
	Order = 22,
	Usage = ":confetti [-n count]",
	Description = "Rains confetti down everyone's screen.",
	Run = function(ctx)
		local count = Util.Clamp(tonumber(ctx.Flags.count or ctx.Flags.n) or FX.ConfettiPieces, 5, 140)
		if IS_SERVER then
			for _, player in ipairs(Players:GetPlayers()) do
				Effects.Confetti(Renderer.GetRoot(player), count)
			end
		else
			Effects.Confetti(Renderer.GetRoot(), count)
		end
		ctx.Reply("Confetti!", "success")
		return true
	end,
})

registerCommand({
	Name = "vignette",
	Aliases = { "dark", "focus" },
	Category = "Effects",
	Order = 23,
	Usage = ":vignette on|off",
	Description = "Darkens the screen edges for a dramatic look.",
	Run = function(ctx)
		local mode = tostring(ctx.Args[1] or "on"):lower()
		local enabled = not (mode == "off" or mode == "false" or mode == "0")
		if IS_SERVER then
			for _, player in ipairs(Players:GetPlayers()) do
				Effects.Vignette(Renderer.GetRoot(player), enabled, 0.5)
			end
		else
			Effects.Vignette(Renderer.GetRoot(), enabled, 0.5)
		end
		ctx.Reply("Vignette " .. (enabled and "on" or "off") .. ".", "success")
		return true
	end,
})

registerCommand({
	Name = "blur",
	Aliases = { "focusblur" },
	Category = "Effects",
	Order = 24,
	Usage = ":blur [-a amount]",
	Description = "Brief blur pulse on the whole server (needs the server install).",
	ServerOnly = true,
	Run = function(ctx)
		if not ctx.RequireServer() then
			return false
		end
		local amount = Util.Clamp(tonumber(ctx.Flags.amount or ctx.Flags.a) or FX.BlurAmount, 0, 56)
		Effects.LightingBlur(amount, 1.4)
		ctx.Reply("Blur pulse fired.", "success")
		return true
	end,
})

--// ---------- chaos mode ----------------------------------------------------

registerCommand({
	Name = "chaos",
	Aliases = { "abuse", "adminabuse", "show", "party-mode" },
	Category = "Effects",
	Order = 25,
	Usage = ":chaos on|off [seconds]",
	Description = "The admin-abuse show: fake owners spam dramatic messages.",
	Examples = { ":chaos on", ":chaos on 60", ":abuse off" },
	Run = function(ctx)
		local chaos = AnnouncementPanel.Chaos
		if chaos == nil then
			ctx.Reply("Chaos module is not loaded.", "error")
			return false
		end
		local mode = tostring(ctx.Args[1] or ""):lower()
		local seconds = tonumber(ctx.Args[2]) or tonumber(ctx.Flags.time) or tonumber(ctx.Flags.t)

		if mode == "" then
			mode = chaos.IsActive() and "off" or "on"
		end

		if mode == "off" or mode == "stop" or mode == "false" or mode == "0" then
			chaos.Stop(ctx.Player)
			ctx.Reply("Chaos mode stopped.", "success")
			return true
		end

		if not RankSystem.CanUseChaos(ctx.Player) then
			ctx.Reply("Your rank cannot start chaos mode (owners/admins only).", "error")
			State.Bump("CommandsDenied")
			return false
		end

		local allowed, remaining = Broadcaster.CheckCooldown(ctx.Player, "Chaos")
		if not allowed and not chaos.IsActive() then
			ctx.Reply("Chaos cooldown: " .. tostring(remaining) .. "s left.", "error")
			return false
		end

		chaos.Start(ctx.Player, seconds or CONFIG.Chaos.DefaultDurationSeconds)
		ctx.Reply("CHAOS MODE ENGAGED. God help us all.", "success")
		return true
	end,
})

--// ---------- moderation ----------------------------------------------------

registerCommand({
	Name = "mute",
	Aliases = { "silence", "shush" },
	Category = "Moderation",
	Order = 30,
	Usage = ":mute <player> [seconds] [reason]",
	Description = "Stops a player's chat messages from being delivered.",
	ServerOnly = true,
	Examples = { ":mute Steve", ":mute Steve 300 spamming", ":mute @Steve 60" },
	Run = function(ctx)
		if not ctx.RequireServer() then
			return false
		end
		local query = ctx.Args[1]
		if query == nil then
			ctx.Reply("Usage: :mute <player> [seconds] [reason]", "error")
			return false
		end
		local target = Broadcaster.FindPlayer(query)
		if target == nil then
			ctx.Reply("No player found matching '" .. tostring(query) .. "'.", "error")
			return false
		end
		if RankSystem.IsStaff(target) and not RankSystem.IsAtLeast(ctx.Player, "Owner") then
			ctx.Reply("Only owners can mute staff.", "error")
			return false
		end
		if RankSystem.GetOrder(ctx.Rank) <= RankSystem.GetOrder(RankSystem.GetRank(target)) then
			ctx.Reply("You cannot mute someone of equal or higher rank.", "error")
			return false
		end
		local seconds = tonumber(ctx.Args[2])
		local reason = seconds and table.concat(ctx.Args, " ", 3) or table.concat(ctx.Args, " ", 2)
		if reason == "" then
			reason = nil
		end
		State.Mute(target, ctx.Player.Name, reason, seconds)
		Broadcaster.Toast("You have been muted" .. (seconds and (" for " .. Util.FormatDuration(seconds)) or "") .. ".", {
			Target = target.Name,
			Rank = ctx.Rank,
			SenderName = ctx.Player.Name,
			Title = "MUTED",
			Style = "Shadow",
			Duration = 6,
		}, { Origin = ctx.Player, Source = ctx.Source, SkipCooldown = true })
		ctx.Reply("Muted " .. target.Name .. (seconds and (" for " .. seconds .. "s") or " indefinitely") .. ".", "success")
		return true
	end,
})

registerCommand({
	Name = "unmute",
	Aliases = { "unsilence" },
	Category = "Moderation",
	Order = 31,
	Usage = ":unmute <player>",
	ServerOnly = true,
	Run = function(ctx)
		if not ctx.RequireServer() then
			return false
		end
		local target = Broadcaster.FindPlayer(ctx.Args[1] or "")
		if target == nil then
			ctx.Reply("No player found.", "error")
			return false
		end
		local existed = State.Unmute(target)
		ctx.Reply(existed and ("Unmuted " .. target.Name .. ".") or (target.Name .. " was not muted."), "success")
		return true
	end,
})

registerCommand({
	Name = "mutes",
	Aliases = { "mutelist", "silenced" },
	Category = "Moderation",
	Order = 32,
	Usage = ":mutes",
	Run = function(ctx)
		local list = State.MutedList()
		if #list == 0 then
			ctx.Reply("Nobody is muted.", "info")
			return true
		end
		ctx.Reply("Muted players (" .. #list .. "):", "info")
		for _, entry in ipairs(list) do
			local untilText = (entry.Until and entry.Until > 0)
				and ("until " .. os.date("%H:%M:%S", entry.Until))
				or "indefinite"
			ctx.Reply(string.format("%s - by %s (%s) %s", entry.Name, tostring(entry.By), untilText,
				entry.Reason and entry.Reason ~= "" and ("- reason: " .. entry.Reason) or ""), "info")
		end
		return true
	end,
})

registerCommand({
	Name = "rank",
	Aliases = { "promote", "setrank" },
	Category = "Moderation",
	Order = 33,
	Usage = ":rank <player> <rank>",
	Description = "Gives a player a session rank (lasts until they leave).",
	Examples = { ":rank Steve Mod", ":promote @Alex Admin" },
	ServerOnly = true,
	Run = function(ctx)
		if not ctx.RequireServer() then
			return false
		end
		local target = Broadcaster.FindPlayer(ctx.Args[1] or "")
		local rankName = ctx.Args[2]
		if target == nil or rankName == nil then
			ctx.Reply("Usage: :rank <player> <rank>. Ranks: " .. table.concat(Theme.RankNames(), ", "), "error")
			return false
		end
		local resolved = Theme.GetRankName(rankName)
		if CONFIG.Ranks[resolved] == nil then
			ctx.Reply("Unknown rank '" .. tostring(rankName) .. "'. Try: " .. table.concat(Theme.RankNames(), ", "), "error")
			return false
		end
		if RankSystem.GetOrder(resolved) >= RankSystem.GetOrder(ctx.Rank) and resolved ~= "Player" then
			ctx.Reply("You cannot grant a rank equal to or above your own.", "error")
			return false
		end
		local ok, err = RankSystem.SetSessionRank(target, resolved)
		if not ok then
			ctx.Reply("Could not set rank: " .. tostring(err), "error")
			return false
		end
		RankSystem.Cache[target.UserId] = nil
		local finalRank = RankSystem.GetRank(target, true)
		Broadcaster.Toast("You are now a " .. Theme.GetRank(finalRank).DisplayName .. " for this server.", {
			Target = target.Name,
			Rank = ctx.Rank,
			SenderName = ctx.Player.Name,
			Title = "RANK UPDATED",
			Style = "Gold",
			Duration = 8,
		}, { Origin = ctx.Player, Source = ctx.Source, SkipCooldown = true })
		ctx.Reply(target.Name .. " is now " .. finalRank .. ".", "success")
		return true
	end,
})

registerCommand({
	Name = "unrank",
	Aliases = { "demote", "striprank" },
	Category = "Moderation",
	Order = 34,
	Usage = ":unrank <player>",
	ServerOnly = true,
	Run = function(ctx)
		if not ctx.RequireServer() then
			return false
		end
		local target = Broadcaster.FindPlayer(ctx.Args[1] or "")
		if target == nil then
			ctx.Reply("No player found.", "error")
			return false
		end
		RankSystem.SetSessionRank(target, nil)
		RankSystem.Cache[target.UserId] = nil
		local finalRank = RankSystem.GetRank(target, true)
		ctx.Reply(target.Name .. " is back to " .. finalRank .. ".", "success")
		return true
	end,
})

registerCommand({
	Name = "kick",
	Aliases = { "remove", "boot" },
	Category = "Moderation",
	Order = 35,
	Usage = ":kick <player> [reason]",
	Description = "Announces the kick, then kicks. Owner only.",
	MinRank = "Owner",
	ServerOnly = true,
	Run = function(ctx)
		if not ctx.RequireServer() then
			return false
		end
		local target = Broadcaster.FindPlayer(ctx.Args[1] or "")
		if target == nil then
			ctx.Reply("No player found.", "error")
			return false
		end
		if target.UserId == game.CreatorId and CONFIG.RankRules.GameOwnerIsOwner then
			ctx.Reply("You cannot kick the place owner.", "error")
			return false
		end
		local reason = table.concat(ctx.Args, " ", 2)
		if reason == "" then
			reason = "Removed by staff"
		end
		Broadcaster.Broadcast({
			Kind = "Banner",
			Message = target.Name .. " has been removed from the server. Reason: " .. reason,
			Title = "PLAYER REMOVED",
			Style = "Fire",
			Duration = 10,
			Rank = ctx.Rank,
			SenderName = ctx.Player.Name,
			Effects = { Flash = true },
		}, { Origin = ctx.Player, Source = ctx.Source })
		State.Bump("Kicks")
		task.wait(1.6)
		local ok, err = pcall(function()
			target:Kick(reason)
		end)
		if not ok then
			ctx.Reply("Kick failed: " .. tostring(err), "error")
			return false
		end
		ctx.Reply("Kicked " .. target.Name .. ".", "success")
		return true
	end,
})

--// ---------- information ---------------------------------------------------

registerCommand({
	Name = "help",
	Aliases = { "cmds", "commands", "?" },
	Category = "Information",
	Order = 40,
	Permission = "help",
	Usage = ":help [command] [page]",
	Description = "Lists the commands your rank may use.",
	Examples = { ":help", ":help announce", ":help 2" },
	Run = function(ctx)
		local available = Commands.ForPlayer(ctx.Player)
		local query = ctx.Args[1]

		-- Detailed help for one command.
		if query and Commands.Get(query) then
			local definition = Commands.Get(query)
			ctx.Reply("\u{2022} " .. definition.Name .. "  [" .. definition.Category .. "]", "info")
			ctx.Reply("   " .. definition.Description, "info")
			ctx.Reply("   Usage: " .. definition.Usage, "info")
			if #definition.Aliases > 0 then
				ctx.Reply("   Aliases: " .. table.concat(definition.Aliases, ", "), "info")
			end
			if #definition.Examples > 0 then
				for _, example in ipairs(definition.Examples) do
					ctx.Reply("   e.g. " .. example, "info")
				end
			end
			if definition.ServerOnly then
				ctx.Reply("   Requires the server install.", "warn")
			end
			return true
		end

		local page = tonumber(query) or tonumber(ctx.Args[2]) or 1
		local perPage = 9
		local pages = math.max(1, math.ceil(#available / perPage))
		page = Util.Clamp(page, 1, pages)
		local start = ((page - 1) * perPage) + 1
		local finish = math.min(#available, start + perPage - 1)

		ctx.Reply(string.format("%s commands (%s) - page %d/%d",
			CONFIG.SystemName, ctx.Rank, page, pages), "info")

		for index = start, finish do
			local definition = available[index]
			if definition then
				local aliasText = (#definition.Aliases > 0) and (" (" .. table.concat(definition.Aliases, ", ") .. ")") or ""
				ctx.Reply(string.format("%d. :%s%s - %s",
					index, definition.Name, aliasText, definition.Description), "info")
			end
		end

		if pages > 1 then
			ctx.Reply("Use :help " .. (page + 1) .. " for the next page.", "info")
		end
		ctx.Reply("Use :help <command> for details and examples.", "info")
		return true
	end,
})

registerCommand({
	Name = "stats",
	Aliases = { "info", "status", "uptime" },
	Category = "Information",
	Order = 41,
	Usage = ":stats",
	Description = "Server statistics and announcement counters.",
	Run = function(ctx)
		local stats = State.Stats
		local playerCount = #Players:GetPlayers()
		local staffCount = #RankSystem.GetStaffPlayers()
		ctx.Reply("\u{1F4CA} " .. CONFIG.SystemName .. " v" .. CONFIG.Version, "info")
		ctx.Reply(string.format("Mode: %s | Uptime: %s | JobId: %s",
			tostring(State.Mode), State.UptimeText(), Util.ShortId(6)), "info")
		ctx.Reply(string.format("Players: %d (staff: %d) | Active banners: %d",
			playerCount, staffCount, State.ActiveCount()), "info")
		ctx.Reply(string.format("Sent -> banners:%d alerts:%d toasts:%d tickers:%d countdowns:%d",
			stats.Announcements or 0, stats.Alerts or 0, stats.Toasts or 0,
			stats.Tickers or 0, stats.Countdowns or 0), "info")
		ctx.Reply(string.format("Commands -> run:%d denied:%d unknown:%d | effects:%d | errors:%d",
			stats.CommandsRun or 0, stats.CommandsDenied or 0, stats.CommandsUnknown or 0,
			stats.Effects or 0, stats.Errors or 0), "info")
		ctx.Reply(string.format("Chaos -> %s | Muted: %d | MOTD: %s | Scheduled: %d",
			State.Chaos.Active and ("ON (" .. State.Chaos.Count .. " fired)") or "off",
			Util.CountKeys(State.Muted),
			State.MOTD.Enabled and "on" or "off",
			Util.CountKeys(State.Scheduled)), "info")
		if ctx.Flags.ranks then
			local counts = RankSystem.CountByRank()
			for _, rankName in ipairs(Theme.RankNames()) do
				ctx.Reply("   " .. rankName .. ": " .. tostring(counts[rankName] or 0), "info")
			end
		end
		return true
	end,
})

registerCommand({
	Name = "whoami",
	Aliases = { "myrank", "me" },
	Category = "Information",
	Order = 42,
	Usage = ":whoami",
	Description = "Shows which rank the panel gave you and why.",
	Run = function(ctx)
		local rankName = RankSystem.GetRank(ctx.Player, true)
		local meta = Theme.GetRank(rankName)
		local cached = RankSystem.Cache[ctx.Player.UserId]
		ctx.Reply(string.format("You are %s%s (%s, order %d).",
			tostring(meta.Badge or ""), tostring(meta.DisplayName or rankName), rankName, meta.Order or 0), "info")
		ctx.Reply("Resolved from: " .. tostring(cached and cached.Source or "?"), "info")
		ctx.Reply("Commands available: " .. tostring(#Commands.ForPlayer(ctx.Player)), "info")
		ctx.Reply("Max announcement duration: " .. tostring(meta.MaxDuration or 0) .. "s", "info")
		return true
	end,
})

registerCommand({
	Name = "styles",
	Aliases = { "themes" },
	Category = "Information",
	Order = 43,
	Usage = ":styles",
	Description = "Lists the visual styles you can pass to -s.",
	Run = function(ctx)
		ctx.Reply("Available styles: " .. table.concat(Theme.StyleNames(), ", "), "info")
		ctx.Reply("Usage: :announce <message> -s Gold", "info")
		return true
	end,
})

registerCommand({
	Name = "presets",
	Aliases = { "quicklist" },
	Category = "Information",
	Order = 44,
	Usage = ":presets",
	Run = function(ctx)
		local names = Broadcaster.PresetNames()
		ctx.Reply("Presets (" .. #names .. "): " .. table.concat(names, ", "), "info")
		ctx.Reply("Usage: :preset restart", "info")
		return true
	end,
})

registerCommand({
	Name = "ranks",
	Aliases = { "ranklist", "online", "players" },
	Category = "Information",
	Order = 45,
	Usage = ":ranks",
	Description = "Lists everyone in the server with their resolved rank.",
	Run = function(ctx)
		local players = Players:GetPlayers()
		if #players == 0 then
			ctx.Reply("Nobody is here. Strange.", "info")
			return true
		end
		table.sort(players, function(a, b)
			return RankSystem.GetOrder(RankSystem.GetRank(a)) > RankSystem.GetOrder(RankSystem.GetRank(b))
		end)
		ctx.Reply("Players (" .. #players .. "):", "info")
		for _, player in ipairs(players) do
			local meta = Theme.GetRank(RankSystem.GetRank(player))
			ctx.Reply(string.format("%s %s - %s%s",
				tostring(meta.Badge or ""), player.Name, tostring(meta.DisplayName or "?"),
				State.IsMuted(player) and " [MUTED]" or ""), "info")
		end
		return true
	end,
})

registerCommand({
	Name = "ping",
	Aliases = { "alive", "pong" },
	Category = "Information",
	Order = 46,
	Usage = ":ping",
	Run = function(ctx)
		ctx.Reply("pong - " .. CONFIG.SystemName .. " is alive (" .. State.Mode .. ").", "success")
		return true
	end,
})

registerCommand({
	Name = "version",
	Aliases = { "ver", "about" },
	Category = "Information",
	Order = 47,
	Usage = ":version",
	Run = function(ctx)
		ctx.Reply(string.format("%s v%s (%s) running as %s",
			CONFIG.SystemName, CONFIG.Version, CONFIG.BuildStamp or "all-in-one", State.Mode), "info")
		return true
	end,
})

--// ---------- system --------------------------------------------------------

registerCommand({
	Name = "schedule",
	Aliases = { "sched", "every" },
	Category = "System",
	Order = 50,
	Usage = ":schedule <everySeconds> <message> [-s style] [-t duration]",
	Description = "Repeats an announcement on a timer.",
	Examples = { ":schedule 600 Follow the group for updates!", ":sched 300 Event ends soon -s Fire" },
	Run = function(ctx)
		local every = tonumber(ctx.Args[1])
		if every == nil then
			ctx.Reply("Usage: :schedule <everySeconds> <message>", "error")
			return false
		end
		local message = table.concat(ctx.Args, " ", 2)
		if message == "" then
			message = ctx.Message
		end
		if message == "" then
			ctx.Reply("You need a message to schedule.", "error")
			return false
		end
		local id, err = Scheduler.Add({
			Kind = ctx.Flags.kind or "Banner",
			Message = message,
			Title = ctx.Flags.title,
			Style = ctx.Flags.style or ctx.Flags.s or CONFIG.DefaultStyle,
			Duration = durationFromFlags(ctx.Flags, ctx, LIMITS.DefaultDuration),
			Rank = ctx.Rank,
			SenderName = ctx.Player and ctx.Player.Name or "Auto",
			Target = ctx.Flags.to or "all",
		}, every, tonumber(ctx.Flags.delay) or nil)
		if id == nil then
			ctx.Reply("Could not schedule: " .. tostring(err), "error")
			return false
		end
		ctx.Reply("Scheduled '" .. id .. "' every " .. Util.FormatDuration(every) .. ".", "success")
		return true
	end,
})

registerCommand({
	Name = "unschedule",
	Aliases = { "unsched", "removeschedule" },
	Category = "System",
	Order = 51,
	Usage = ":unschedule <id|index> | :unschedule all",
	Run = function(ctx)
		local target = ctx.Args[1]
		if target == nil then
			ctx.Reply("Usage: :unschedule <id|index|all>", "error")
			return false
		end
		if tostring(target):lower() == "all" then
			Scheduler.Clear()
			ctx.Reply("All scheduled announcements removed.", "success")
			return true
		end
		local removed = Scheduler.Remove(target)
		ctx.Reply(removed and ("Removed '" .. tostring(target) .. "'.") or ("Nothing found for '" .. tostring(target) .. "'."),
			removed and "success" or "error")
		return removed
	end,
})

registerCommand({
	Name = "schedules",
	Aliases = { "schedlist", "timers" },
	Category = "System",
	Order = 52,
	Usage = ":schedules",
	Run = function(ctx)
		local items = Scheduler.List()
		if #items == 0 then
			ctx.Reply("No scheduled announcements.", "info")
			return true
		end
		ctx.Reply("Scheduled (" .. #items .. "):", "info")
		for index, item in ipairs(items) do
			ctx.Reply(string.format("%d. %s every %s (next in %s) - %s",
				index, tostring(item.Id), Util.FormatDuration(item.Every),
				Util.FormatDuration(item.NextRunIn), Util.Truncate(item.Message, 60)), "info")
		end
		return true
	end,
})

registerCommand({
	Name = "panel",
	Aliases = { "console", "open", "ui" },
	Category = "System",
	Order = 53,
	Usage = ":panel",
	Description = "Opens the Owner Console (needs the client install).",
	Run = function(ctx)
		if IS_SERVER then
			local sent = Net.FireClient(ctx.Player, "OpenConsole", { RequestedBy = ctx.Player.Name })
			if sent then
				ctx.Reply("Asked your client panel to open. If nothing happens, install the LocalScript copy too.", "info")
			else
				ctx.Reply("No client half detected. Chat commands still work - see :help.", "info")
			end
			return true
		end
		local client = AnnouncementPanel.Client
		if client and client.ToggleConsole then
			client.ToggleConsole(true)
			ctx.Reply("Console opened.", "success")
		else
			ctx.Reply("Console is not available.", "error")
		end
		return true
	end,
})

registerCommand({
	Name = "refresh",
	Aliases = { "reload", "recache" },
	Category = "System",
	Order = 54,
	Usage = ":refresh",
	Description = "Clears the rank cache and re-resolves everyone.",
	Run = function(ctx)
		RankSystem.ClearCache()
		local count = 0
		for _, player in ipairs(Players:GetPlayers()) do
			RankSystem.GetRank(player, true)
			count += 1
		end
		ctx.Reply("Re-resolved ranks for " .. count .. " player(s).", "success")
		return true
	end,
})

registerCommand({
	Name = "colors",
	Aliases = { "colours" },
	Category = "Information",
	Order = 55,
	Usage = ":colors",
	Description = "Lists the colour names accepted by -c.",
	Run = function(ctx)
		ctx.Reply("Colours: " .. table.concat(Util.ColorNames(), ", "), "info")
		ctx.Reply("You can also use #RRGGBB or 255,120,60.", "info")
		return true
	end,
})

AnnouncementPanel.Commands = Commands

--// ==========================================================================
--// SECTION 20  ::  COMMAND PARSER
--// ":announce Double XP is live! -s Gold -t 15 --to all"
--//      ^name   ^----message----^  ^style ^time  ^target
--// ==========================================================================

local CommandParser = {}

CommandParser.Prefixes = nil -- built lazily so CONFIG edits are respected

function CommandParser.GetPrefixes()
	if CommandParser.Prefixes == nil then
		local prefixes = { CONFIG.CommandPrefix }
		for _, prefix in ipairs(CONFIG.AltPrefixes or {}) do
			table.insert(prefixes, prefix)
		end
		CommandParser.Prefixes = prefixes
	end
	return CommandParser.Prefixes
end

function CommandParser.Tokenize(text)
	local tokens = {}
	if type(text) ~= "string" then
		return tokens
	end
	local length = #text
	local index = 1
	while index <= length do
		local char = text:sub(index, index)
		if char == " " or char == "\t" or char == "\n" or char == "\r" then
			index += 1
			continue
		end
		if char == '"' or char == "'" then
			local quote = char
			index += 1
			local start = index
			while index <= length and text:sub(index, index) ~= quote do
				index += 1
			end
			table.insert(tokens, text:sub(start, index - 1))
			index += 1
			continue
		end
		local start = index
		while index <= length do
			local current = text:sub(index, index)
			if current == " " or current == "\t" or current == "\n" or current == "\r" then
				break
			end
			index += 1
		end
		table.insert(tokens, text:sub(start, index - 1))
	end
	return tokens
end

function CommandParser.DetectPrefix(text)
	for _, prefix in ipairs(CommandParser.GetPrefixes()) do
		if Util.StartsWith(text, prefix) then
			return prefix, text:sub(#prefix + 1)
		end
	end
	return nil, text
end

function CommandParser.Parse(text)
	local result = {
		IsCommand = false,
		Prefix = nil,
		Name = nil,
		Args = {},
		Flags = {},
		Message = "",
		Raw = tostring(text or ""),
		TokenCount = 0,
	}

	if type(text) ~= "string" then
		return result
	end

	local trimmed = Util.Trim(text)
	if trimmed == "" then
		return result
	end

	local prefix, remainder = CommandParser.DetectPrefix(trimmed)
	if prefix == nil then
		return result
	end

	local tokens = CommandParser.Tokenize(remainder)
	result.TokenCount = #tokens
	if #tokens == 0 then
		return result
	end

	result.Prefix = prefix
	result.IsCommand = true

	-- Command name: letters only, lowercased.
	local rawName = tostring(tokens[1]):lower()
	result.Name = rawName:gsub("[^a-z0-9%-]", "")
	if result.Name == "" then
		result.Name = rawName
	end

	local positional = {}
	local index = 2
	while index <= #tokens do
		local token = tokens[index]
		if token == "--" then
			-- Everything after "--" is message text.
			for rest = index + 1, #tokens do
				table.insert(positional, tokens[rest])
			end
			break
		elseif Util.StartsWith(token, "--") then
			local body = token:sub(3)
			local key, value = body:match("^([%w%-]+)=(.+)$")
			if key then
				result.Flags[key:lower()] = value
			else
				local flagName = body:lower()
				local nextToken = tokens[index + 1]
				if nextToken ~= nil and not Util.StartsWith(nextToken, "-") then
					result.Flags[flagName] = nextToken
					index += 1
				else
					result.Flags[flagName] = true
				end
			end
		elseif Util.StartsWith(token, "-") and #token > 1 then
			local body = token:sub(2)
			local key, value = body:match("^([%w%-]+)=(.+)$")
			if key then
				result.Flags[key:lower()] = value
			else
				local flagName = body:lower()
				local nextToken = tokens[index + 1]
				if nextToken ~= nil and not Util.StartsWith(nextToken, "-") then
					result.Flags[flagName] = nextToken
					index += 1
				else
					result.Flags[flagName] = true
				end
			end
		else
			table.insert(positional, token)
		end
		index += 1
	end

	result.Args = positional
	result.Message = Util.Trim(table.concat(positional, " "))
	return result
end

function CommandParser.Describe(parsed)
	if not parsed or not parsed.IsCommand then
		return "not a command"
	end
	local flagNames = {}
	for key in pairs(parsed.Flags or {}) do
		table.insert(flagNames, key)
	end
	table.sort(flagNames)
	return string.format("cmd=%s args=%d flags=[%s] message=%q",
		tostring(parsed.Name), #(parsed.Args or {}),
		table.concat(flagNames, ","), Util.Truncate(parsed.Message or "", 40))
end

AnnouncementPanel.CommandParser = CommandParser

--// ==========================================================================
--// SECTION 21  ::  COMMAND SERVICE
--// Permission gates, cooldowns, dedupe, logging, execution.
--// ==========================================================================

local CommandService = {}

CommandService.LastCommandAt = {} -- [userId] = clock (global cooldown)
CommandService.RecentSignatures = {} -- [signature] = clock (dedupe)
CommandService.ReplyColors = {
	info = Color3.fromRGB(170, 205, 255),
	success = Color3.fromRGB(150, 255, 180),
	warn = Color3.fromRGB(255, 215, 130),
	error = Color3.fromRGB(255, 140, 140),
}
CommandService.Log = {} -- last N executed commands
CommandService.OnExecuted = Util.CreateSignal()

local DEDUPE_WINDOW = 2.0

local function rememberSignature(signature)
	local now = os.clock()
	CommandService.RecentSignatures[signature] = now
	-- Prune occasionally so the table cannot grow forever.
	if Util.CountKeys(CommandService.RecentSignatures) > 200 then
		for key, stamp in pairs(CommandService.RecentSignatures) do
			if now - stamp > DEDUPE_WINDOW * 4 then
				CommandService.RecentSignatures[key] = nil
			end
		end
	end
end

local function isDuplicate(signature)
	local stamp = CommandService.RecentSignatures[signature]
	if stamp == nil then
		return false
	end
	return (os.clock() - stamp) < DEDUPE_WINDOW
end

function CommandService.MakeContext(player, parsed, source)
	local rankName = RankSystem.GetRank(player)
	local meta = Theme.GetRank(rankName)

	local context = {
		Player = player,
		Rank = rankName,
		Meta = meta,
		Parsed = parsed,
		Args = parsed.Args or {},
		Flags = parsed.Flags or {},
		Message = parsed.Message or "",
		Raw = parsed.Raw,
		Source = source or "chat",
		StartedAt = os.clock(),
		Replies = {},
	}

	function context.Reply(text, kind)
		kind = kind or "info"
		local color = CommandService.ReplyColors[kind] or CommandService.ReplyColors.info
		local line = tostring(text)
		table.insert(context.Replies, { Text = line, Kind = kind })
		ChatBridge.SystemMessageToPlayer(player, line, color)
		if AnnouncementPanel.Client and AnnouncementPanel.Client.LogLine then
			AnnouncementPanel.Client.LogLine(line, kind)
		end
	end

	function context.ReplyAll(text)
		ChatBridge.SystemMessageAll(tostring(text), "")
	end

	function context.RequireServer()
		if IS_SERVER then
			return true
		end
		context.Reply("That command needs the server install (a Script in ServerScriptService).", "warn")
		return false
	end

	function context.RequireClient()
		if IS_CLIENT then
			return true
		end
		context.Reply("That command needs the client install (a LocalScript in StarterPlayerScripts).", "warn")
		return false
	end

	return context
end

function CommandService.CanUse(player, definition)
	if player == nil or definition == nil then
		return false, "invalid"
	end
	if definition.Permission == "*" then
		return RankSystem.IsStaff(player)
	end
	if not RankSystem.Can(player, definition.Permission) then
		return false, "permission"
	end
	if definition.MinRank then
		if not RankSystem.IsAtLeast(player, definition.MinRank) then
			return false, "rank"
		end
	end
	return true
end

function CommandService.CooldownOk(player)
	if player == nil then
		return true, 0
	end
	local now = os.clock()
	local last = CommandService.LastCommandAt[player.UserId] or 0
	local remaining = (LIMITS.CommandCooldown or 1) - (now - last)
	if remaining > 0 then
		return false, Util.Round(remaining, 1)
	end
	CommandService.LastCommandAt[player.UserId] = now
	return true, 0
end

function CommandService.RecordExecution(player, definition, parsed, ok, duration)
	local entry = {
		Player = player and player.Name or "?",
		UserId = player and player.UserId or 0,
		Rank = player and RankSystem.GetRank(player) or "?",
		Command = definition and definition.Name or "?",
		Message = parsed and parsed.Message or "",
		Ok = ok,
		Duration = duration,
		At = os.time(),
		Source = parsed and parsed.Source or "chat",
	}
	table.insert(CommandService.Log, 1, entry)
	while #CommandService.Log > 60 do
		table.remove(CommandService.Log)
	end
	if CONFIG.Debug.PrintCommands then
		Util.Debug("command:", entry.Command, "by", entry.Player, ok and "(ok)" or "(failed)",
			string.format("%.3fs", duration or 0))
	end
	CommandService.OnExecuted:Fire(entry)
end

-- The single execution path. Returns true when the text was consumed.
function CommandService.Execute(player, text, source)
	if player == nil or type(text) ~= "string" then
		return false
	end

	local parsed = CommandParser.Parse(text)

	-- Muted players: swallow their chat entirely (that is the point of a mute).
	if IS_SERVER and State.IsMuted(player) then
		if parsed.IsCommand and RankSystem.IsStaff(player) then
			-- Staff may still use commands while muted (they muted themselves?).
		else
			return true
		end
	end

	if not parsed.IsCommand then
		return false
	end

	local signature = tostring(player.UserId) .. "|" .. tostring(parsed.Raw):lower()
	if isDuplicate(signature) then
		-- Same command twice in a heartbeat: almost always the two chat hooks
		-- (TextChannel + Player.Chatted) both firing. Suppress quietly.
		return true
	end
	rememberSignature(signature)

	local definition = Commands.Get(parsed.Name)
	if definition == nil then
		State.Bump("CommandsUnknown")
		if RankSystem.IsStaff(player) then
			local suggestion = CommandService.Suggest(parsed.Name)
			ChatBridge.SystemMessageToPlayer(player,
				"Unknown command '" .. tostring(parsed.Name) .. "'." .. (suggestion and (" Did you mean :" .. suggestion .. "?") or "")
				.. " Type :help for the list.",
				CommandService.ReplyColors.error)
		elseif CONFIG.Moderation.LogNonStaffAttempts then
			Util.Debug("non-staff tried command:", parsed.Raw, "by", player.Name)
		end
		return true
	end

	local allowed, reason = CommandService.CanUse(player, definition)
	if not allowed then
		State.Bump("CommandsDenied")
		local message = (reason == "rank")
			and ("'" .. definition.Name .. "' needs rank " .. tostring(definition.MinRank) .. " or higher.")
			or ("Your rank (" .. tostring(RankSystem.GetRank(player)) .. ") cannot use :" .. definition.Name .. ".")
		ChatBridge.SystemMessageToPlayer(player, message, CommandService.ReplyColors.error)
		Audio.Play("Deny", { Volume = CONFIG.Sounds.Volume * 0.6 })
		if CONFIG.Moderation.BlockedCommandsForNonStaff then
			Util.Debug("denied", definition.Name, "for", player.Name)
		end
		return true
	end

	local cooldownOk, remaining = CommandService.CooldownOk(player)
	if not cooldownOk then
		ChatBridge.SystemMessageToPlayer(player,
			"Slow down - commands are rate limited (" .. tostring(remaining) .. "s).",
			CommandService.ReplyColors.warn)
		return true
	end

	if definition.ServerOnly and not IS_SERVER then
		ChatBridge.SystemMessageToPlayer(player,
			":" .. definition.Name .. " requires the server install.",
			CommandService.ReplyColors.warn)
		return true
	end

	local context = CommandService.MakeContext(player, parsed, source)
	State.Bump("CommandsRun")

	local started = os.clock()
	local ok, err = pcall(function()
		return definition.Run(context)
	end)
	local duration = os.clock() - started

	if not ok then
		State.Bump("Errors")
		Util.Warn("command :" .. tostring(definition.Name) .. " crashed:", err)
		context.Reply("That command errored internally. Check the console output.", "error")
	end

	CommandService.RecordExecution(player, definition, parsed, ok, duration)
	return true
end

-- Levenshtein-ish suggestion so ":anounce" gets a helpful nudge.
function CommandService.Suggest(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local lowered = name:lower()
	local best = nil
	local bestScore = math.huge
	for _, definition in ipairs(Commands.List()) do
		local candidates = { definition.Name }
		for _, alias in ipairs(definition.Aliases or {}) do
			table.insert(candidates, alias)
		end
		for _, candidate in ipairs(candidates) do
			local score = CommandService.EditDistance(lowered, candidate:lower())
			if score < bestScore then
				bestScore = score
				best = definition.Name
			end
		end
	end
	if bestScore <= 3 then
		return best
	end
	return nil
end

function CommandService.EditDistance(a, b)
	a = tostring(a)
	b = tostring(b)
	local previous = {}
	local current = {}
	-- Rows are stored 1-based (index j+1 holds column j) so the linter and the
	-- algorithm agree about arrays starting at 1.
	for index = 1, #b + 1 do
		previous[index] = index - 1
	end
	for i = 1, #a do
		current[1] = i
		for j = 1, #b do
			local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
			current[j + 1] = math.min(
				current[j] + 1,
				previous[j + 1] + 1,
				previous[j] + cost
			)
		end
		for j = 1, #b + 1 do
			previous[j] = current[j]
		end
	end
	return previous[#b + 1] or 0
end

function CommandService.GetLog(limit)
	limit = limit or 20
	local result = {}
	for index = 1, math.min(limit, #CommandService.Log) do
		table.insert(result, CommandService.Log[index])
	end
	return result
end

AnnouncementPanel.CommandService = CommandService

--// ==========================================================================
--// SECTION 22  ::  CHAOS MODE
--// The "admin abuse" show. Fake owners and admins take turns firing dramatic
--// announcements while the screen flashes, shakes and rains confetti.
--// Auto-expires so nobody forgets it running.
--// ==========================================================================

local Chaos = {}

Chaos.Thread = nil
Chaos.StopRequested = false
Chaos.LinesUsed = {}

function Chaos.IsActive()
	return State.Chaos.Active == true
end

function Chaos.Remaining()
	if not Chaos.IsActive() then
		return 0
	end
	return math.max(0, State.Chaos.ExpiresAt - os.clock())
end

function Chaos.PickLine()
	local lines = CONFIG.Chaos.Lines or {}
	if #lines == 0 then
		return "The announcement system is working. Probably."
	end
	-- Avoid repeating the same line twice in a row where possible.
	local attempt = 0
	local choice = nil
	repeat
		choice = Util.RandomFromList(lines)
		attempt += 1
	until choice ~= Chaos.LastLine or attempt > 6
	Chaos.LastLine = choice
	return choice
end

function Chaos.PickFakeSender()
	local name = Util.RandomFromList(CONFIG.Chaos.FakeOwnerNames, "Owner")
	local rank = Util.RandomFromList(CONFIG.Chaos.FakeRanks, "Owner")
	return name, Theme.GetRankName(rank)
end

-- Fires exactly one chaotic announcement.
function Chaos.FireOne(kindOverride)
	local message = Chaos.PickLine()
	local senderName, rank = Chaos.PickFakeSender()

	local roll = math.random()
	local kind = kindOverride
	if kind == nil then
		if roll < (CONFIG.Chaos.AlertChance or 0.12) then
			kind = "Alert"
		elseif roll < (CONFIG.Chaos.AlertChance or 0.12) + (CONFIG.Chaos.TickerChance or 0.2) then
			kind = "Ticker"
		elseif roll < 0.85 then
			kind = "Banner"
		else
			kind = "Toast"
		end
	end

	local styleNames = Theme.StyleNames()
	local style = Util.RandomFromList(styleNames, "Gold")
	local duration = Util.RandomBetween(4, 11)

	local effects = {
		Flash = math.random() < (CONFIG.Chaos.FlashChance or 0.5),
		Shake = math.random() < (CONFIG.Chaos.ShakeChance or 0.5),
		Confetti = math.random() < (CONFIG.Chaos.ConfettiChance or 0.35),
	}

	local payload = {
		Kind = kind,
		Message = message,
		Title = kind == "Alert" and Util.RandomFromList({ "OWNER ALERT", "ATTENTION", "ADMIN NOTICE", "SERVER NOTICE" }) or nil,
		Style = style,
		Duration = duration,
		Rank = rank,
		SenderName = senderName,
		Effects = effects,
		Target = "all",
	}

	local ok, result = Broadcaster.Broadcast(payload, {
		Source = "chaos",
		SkipCooldown = true,
		SkipHistory = false,
	})

	State.Chaos.Count += 1
	if not ok then
		Util.Debug("chaos broadcast rejected:", result and result.Reason)
	end
	return ok
end

function Chaos.Loop(durationSeconds)
	local deadline = os.clock() + durationSeconds
	State.Chaos.ExpiresAt = deadline

	while not Chaos.StopRequested and os.clock() < deadline do
		if not State.Chaos.Active then
			break
		end
		local ok, err = pcall(function()
			Chaos.FireOne()
		end)
		if not ok then
			Util.Warn("chaos loop error:", err)
			State.Bump("Errors")
			break
		end
		local waitTime = Util.RandomBetween(CONFIG.Chaos.IntervalMin, CONFIG.Chaos.IntervalMax)
		local slice = 0
		while slice < waitTime and not Chaos.StopRequested and State.Chaos.Active do
			task.wait(math.min(0.25, waitTime - slice))
			slice += 0.25
		end
	end

	Chaos.StopInternal("expired")
end

function Chaos.StopInternal(reason)
	if not State.Chaos.Active then
		return false
	end
	State.Chaos.Active = false
	Chaos.StopRequested = true
	Chaos.Thread = nil

	local count = State.Chaos.Count
	State.Chaos.Count = 0
	State.Chaos.StartedBy = ""

	Broadcaster.Broadcast({
		Kind = "Banner",
		Message = "Chaos mode has ended after " .. tostring(count) .. " announcements. Order is restored.",
		Title = "CHAOS OVER",
		Style = "Ice",
		Duration = 8,
		Rank = "Owner",
		SenderName = "System",
		Effects = { Flash = false, Confetti = false },
	}, { Source = "chaos", SkipCooldown = true })

	Util.Info("chaos mode stopped (" .. tostring(reason) .. ") after", count, "messages")
	return true
end

function Chaos.Start(player, durationSeconds)
	if not CONFIG.Chaos.Enabled then
		return false, "chaos mode is disabled in CONFIG"
	end
	durationSeconds = Util.Clamp(
		tonumber(durationSeconds) or CONFIG.Chaos.DefaultDurationSeconds,
		5,
		CONFIG.Chaos.MaxDurationSeconds
	)

	if State.Chaos.Active then
		-- Extend instead of stacking two loops.
		State.Chaos.ExpiresAt = math.max(State.Chaos.ExpiresAt, os.clock() + durationSeconds)
		return true, "extended"
	end

	State.Chaos.Active = true
	State.Chaos.StartedAt = os.clock()
	State.Chaos.ExpiresAt = os.clock() + durationSeconds
	State.Chaos.StartedBy = player and player.Name or "System"
	State.Chaos.Count = 0
	Chaos.StopRequested = false
	State.Bump("ChaosActivations")

	Broadcaster.Broadcast({
		Kind = "Alert",
		Message = "Chaos mode has been enabled by " .. tostring(State.Chaos.StartedBy)
			.. ". Expect nonsense for the next " .. Util.FormatDuration(durationSeconds) .. ".",
		Title = "ADMIN ABUSE INITIATED",
		Style = "Emergency",
		Duration = 7,
		Rank = "Owner",
		SenderName = player and player.Name or "System",
		Effects = { Flash = true, Shake = true, Dim = true, Lighting = FX.EnableLighting },
	}, { Origin = player, Source = "chaos", SkipCooldown = true })

	Util.Spawn(function()
		task.wait(1.4)
		Chaos.Loop(durationSeconds)
	end, "Chaos.Loop")

	Util.Info("chaos mode started by", State.Chaos.StartedBy, "for", durationSeconds, "seconds")
	return true, "started"
end

function Chaos.Stop(player)
	if not State.Chaos.Active then
		return false, "not active"
	end
	Chaos.StopRequested = true
	Chaos.StopInternal("stopped by " .. (player and player.Name or "system"))
	return true
end

function Chaos.Status()
	return {
		Active = State.Chaos.Active,
		Remaining = Chaos.Remaining(),
		Count = State.Chaos.Count,
		StartedBy = State.Chaos.StartedBy,
	}
end

AnnouncementPanel.Chaos = Chaos

--// ==========================================================================
--// SECTION 23  ::  SERVER CORE
--// Runs when this file is a Script (ServerScriptService). Owns authority:
--// ranks, filtering, remotes, chat commands, per-player GUI installation,
--// MOTD, join messages, scheduling and persistence.
--// ==========================================================================

local ServerCore = {}

ServerCore.Started = false
ServerCore.RemoteRate = {} -- [userId] = { Count, WindowStart }

local REMOTE_RATE_LIMIT = 12 -- calls per window
local REMOTE_RATE_WINDOW = 2 -- seconds

function ServerCore.RemoteAllowed(player)
	if player == nil then
		return false
	end
	local now = os.clock()
	local entry = ServerCore.RemoteRate[player.UserId]
	if entry == nil or (now - entry.WindowStart) > REMOTE_RATE_WINDOW then
		ServerCore.RemoteRate[player.UserId] = { Count = 1, WindowStart = now }
		return true
	end
	entry.Count += 1
	if entry.Count > REMOTE_RATE_LIMIT then
		Util.Debug("remote rate limit hit by", player.Name)
		return false
	end
	return true
end

-- Validates anything a client sends. Never trust the payload shape.
function ServerCore.SanitizeClientRequest(payload)
	if type(payload) ~= "table" then
		return nil
	end
	local clean = {}
	clean.Action = type(payload.Action) == "string" and payload.Action:sub(1, 32) or ""
	clean.Text = type(payload.Text) == "string" and payload.Text:sub(1, 600) or ""
	if type(payload.Data) == "table" then
		clean.Data = {}
		clean.Data.Message = type(payload.Data.Message) == "string" and payload.Data.Message:sub(1, 600) or nil
		clean.Data.Title = type(payload.Data.Title) == "string" and payload.Data.Title:sub(1, 120) or nil
		clean.Data.Style = type(payload.Data.Style) == "string" and payload.Data.Style:sub(1, 32) or nil
		clean.Data.Target = type(payload.Data.Target) == "string" and payload.Data.Target:sub(1, 40) or nil
		clean.Data.Duration = tonumber(payload.Data.Duration)
		clean.Data.Kind = type(payload.Data.Kind) == "string" and payload.Data.Kind:sub(1, 16) or nil
	end
	return clean
end

function ServerCore.BuildStatePacket(player)
	local rankName = RankSystem.GetRank(player)
	local meta = Theme.GetRank(rankName)
	return {
		Action = "State",
		Version = CONFIG.Version,
		Rank = rankName,
		RankDisplay = meta.DisplayName,
		Badge = meta.Badge,
		Color = Util.ColorToHex(meta.Color),
		Permissions = RankSystem.AllowedCommands(player),
		CanChaos = RankSystem.CanUseChaos(player),
		MaxDuration = meta.MaxDuration or LIMITS.DefaultDuration,
		Uptime = State.Uptime(),
		PlayerCount = #Players:GetPlayers(),
		StaffCount = #RankSystem.GetStaffPlayers(),
		Stats = Util.DeepCopy(State.Stats),
		History = History.ToPayloadList(20),
		Presets = Broadcaster.PresetNames(),
		Styles = Theme.StyleNames(),
		Colors = Util.ColorNames(),
		Targets = { "all", "admins", "owners", "mods", "staff", "nonstaff", "random", "me" },
		MOTD = {
			Enabled = State.MOTD.Enabled,
			Title = State.MOTD.Title,
			Message = State.MOTD.Message,
			Style = State.MOTD.Style,
		},
		Chaos = Chaos.Status(),
		Scheduled = Scheduler.List(),
		Mode = "server",
		Limits = {
			MaxMessageLength = LIMITS.MaxMessageLength,
			MaxTitleLength = LIMITS.MaxTitleLength,
			DefaultDuration = LIMITS.DefaultDuration,
		},
	}
end

function ServerCore.HandleConsole(player, payload)
	if not ServerCore.RemoteAllowed(player) then
		return
	end
	local request = ServerCore.SanitizeClientRequest(payload)
	if request == nil then
		Util.Warn("malformed console payload from", player and player.Name)
		return
	end

	if CONFIG.Debug.PrintNetwork then
		Util.Debug("console request:", request.Action, "from", player.Name)
	end

	if request.Action == "RequestState" or request.Action == "Sync" then
		Net.AckClient(player, ServerCore.BuildStatePacket(player))
		return
	end

	if request.Action == "Execute" then
		-- The console sends raw command text; it goes through the exact same
		-- parser, permission gates and cooldowns as chat. No shortcuts.
		local text = request.Text
		if text == "" and request.Data and request.Data.Message then
			text = CommandParser.BuildText(request.Data)
		end
		if text ~= "" then
			CommandService.Execute(player, text, "console")
		end
		Net.AckClient(player, ServerCore.BuildStatePacket(player))
		return
	end

	if request.Action == "Ping" then
		Net.AckClient(player, { Action = "Pong", Time = os.clock() })
		return
	end

	Util.Debug("unknown console action:", request.Action)
end

-- Builds ":announce <message> -s <style> -t <n> --to <target>" from console
-- fields, so the GUI and the chat share one execution path.
function CommandParser.BuildText(data)
	if type(data) ~= "table" then
		return ""
	end
	local kind = tostring(data.Kind or "Banner"):lower()
	local commandName = "announce"
	if kind == "alert" then
		commandName = "alert"
	elseif kind == "toast" then
		commandName = "toast"
	elseif kind == "ticker" then
		commandName = "ticker"
	elseif kind == "countdown" then
		commandName = "countdown"
	end

	local parts = { CONFIG.CommandPrefix .. commandName }
	local message = tostring(data.Message or "")
	if message:find(" ") then
		table.insert(parts, '"' .. message .. '"')
	else
		table.insert(parts, message)
	end
	if data.Title and tostring(data.Title) ~= "" then
		table.insert(parts, '--title "' .. tostring(data.Title) .. '"')
	end
	if data.Style and tostring(data.Style) ~= "" then
		table.insert(parts, "-s " .. tostring(data.Style))
	end
	if data.Duration then
		table.insert(parts, "-t " .. tostring(math.floor(tonumber(data.Duration) or LIMITS.DefaultDuration)))
	end
	if data.Target and tostring(data.Target) ~= "" and tostring(data.Target) ~= "all" then
		table.insert(parts, "--to " .. tostring(data.Target))
	end
	return table.concat(parts, " ")
end

function ServerCore.HandleHandshake(player, payload)
	if not ServerCore.RemoteAllowed(player) then
		return
	end
	local rankName = RankSystem.GetRank(player, true)
	Util.Debug("handshake from", player.Name, "rank", rankName, "payload:", payload)
	Net.AckClient(player, ServerCore.BuildStatePacket(player))
	Net.AckClient(player, {
		Action = "Welcome",
		Text = "Announcement Panel client connected. Rank: " .. rankName,
		Rank = rankName,
	})
end

function ServerCore.InstallForPlayer(player)
	if player == nil then
		return
	end

	-- 1. Rank first, so the GUI knows what to show.
	RankSystem.OnPlayerAdded(player)

	-- 2. GUI.
	Renderer.InstallForPlayer(player)

	-- 3. Join announcement.
	if CONFIG.JoinMessages.Enabled then
		local rankName = RankSystem.GetRank(player)
		local isStaff = RankSystem.IsStaff(player)
		if (not CONFIG.JoinMessages.AnnounceStaffOnly) or isStaff then
			local meta = Theme.GetRank(rankName)
			local template = isStaff and CONFIG.JoinMessages.StaffTemplate or CONFIG.JoinMessages.Template
			local text = Util.Template(template, {
				player = player.Name,
				display = player.DisplayName,
				rank = meta.DisplayName,
				badge = meta.Badge,
			})
			Broadcaster.Broadcast({
				Kind = CONFIG.JoinMessages.Style == "Banner" and "Banner"
					or (CONFIG.JoinMessages.Style == "Ticker" and "Ticker" or "Toast"),
				Message = text,
				Duration = CONFIG.JoinMessages.Duration,
				Rank = isStaff and rankName or "Player",
				SenderName = "System",
				Style = "Ice",
			}, { Source = "join", SkipCooldown = true, SkipHistory = false })
		end
	end

	-- 4. MOTD a few seconds after they arrive.
	if CONFIG.MOTD.Enabled and State.MOTD.Enabled and State.MOTD.Message ~= "" then
		Util.Delay(CONFIG.MOTD.DelayAfterJoin, function()
			if player.Parent == nil then
				return
			end
			if State.MOTD.Seen[player.UserId] and not CONFIG.MOTD.ShowOnEverySpawn then
				return
			end
			State.MOTD.Seen[player.UserId] = true
			Renderer.ShowMOTD(player, State.MOTD)
		end, "ServerCore.MOTD")
	end

	-- 5. Welcome toast for staff, so they know the panel saw them.
	if RankSystem.IsStaff(player) then
		Util.Delay(1.2, function()
			if player.Parent == nil then
				return
			end
			local meta = Theme.GetRank(RankSystem.GetRank(player))
			ChatBridge.SystemMessageToPlayer(player,
				string.format("%s Welcome, %s. Type %shelp for your %d commands.",
					tostring(meta.Badge or ""), tostring(meta.DisplayName or ""), CONFIG.CommandPrefix,
					#Commands.ForPlayer(player)),
				Color3.fromRGB(150, 255, 180))
		end, "ServerCore.StaffWelcome")
	end
end

function ServerCore.OnPlayerRemoving(player)
	if player == nil then
		return
	end

	if CONFIG.LeaveMessages.Enabled then
		local rankName = RankSystem.Cache[player.UserId] and RankSystem.Cache[player.UserId].Rank or RankSystem.GetRank(player)
		local isStaff = RankSystem.GetOrder(rankName) >= RankSystem.GetOrder("Helper")
		if (not CONFIG.LeaveMessages.AnnounceStaffOnly) or isStaff then
			local meta = Theme.GetRank(rankName)
			local template = isStaff and CONFIG.LeaveMessages.StaffTemplate or CONFIG.LeaveMessages.Template
			local text = Util.Template(template, {
				player = player.Name,
				rank = meta.DisplayName,
				badge = meta.Badge,
			})
			Broadcaster.Broadcast({
				Kind = CONFIG.LeaveMessages.Style == "Banner" and "Banner"
					or (CONFIG.LeaveMessages.Style == "Ticker" and "Ticker" or "Toast"),
				Message = text,
				Duration = CONFIG.LeaveMessages.Duration,
				Rank = isStaff and rankName or "Player",
				SenderName = "System",
				Style = "Shadow",
			}, { Source = "leave", SkipCooldown = true })
		end
	end

	Renderer.UninstallForPlayer(player)
	RankSystem.OnPlayerRemoving(player)
	ServerCore.RemoteRate[player.UserId] = nil
	CommandService.LastCommandAt[player.UserId] = nil
	State.Muted[player.UserId] = nil
	State.MOTD.Seen[player.UserId] = nil
end

function ServerCore.HookChat()
	local handler = function(player, text, source)
		if player == nil or type(text) ~= "string" then
			return false
		end
		-- Muted players get their chat swallowed before any command parsing.
		if State.IsMuted(player) then
			local parsed = CommandParser.Parse(text)
			if parsed.IsCommand and RankSystem.IsStaff(player) then
				-- staff commands still work while muted
			else
				return true
			end
		end
		local handled = CommandService.Execute(player, text, source or "chat")
		return handled
	end

	local channelHookInstalled = ChatBridge.InstallServerCommandHook(handler)
	Util.Info("chat hooks installed" .. (channelHookInstalled and " (channel + Chatted)" or " (Chatted only)"))
	return channelHookInstalled
end

function ServerCore.HookRemotes()
	if Net.Console then
		Util.Track(Net.Console.OnServerEvent:Connect(function(player, action, payload)
			-- Clients fire (action, payload). Also accept a single table so an
			-- older or hand-rolled client still works, and never trust the
			-- argument shape to carry the action on its own.
			local request = payload
			if type(request) ~= "table" then
				request = action
			end
			if type(request) ~= "table" then
				request = { Action = tostring(action or "") }
			end
			if (request.Action == nil or request.Action == "") and type(action) == "string" then
				request.Action = action
			end
			ServerCore.HandleConsole(player, request)
		end), "Net.Console")
	end
	if Net.Handshake then
		Util.Track(Net.Handshake.OnServerEvent:Connect(function(player, payload)
			ServerCore.HandleHandshake(player, payload)
		end), "Net.Handshake")
	end
	if Net.Announcement then
		-- Clients should never fire the announcement remote. If one does, it is
		-- either a bug or an exploiter; log it and drop it.
		Util.Track(Net.Announcement.OnServerEvent:Connect(function(player, ...)
			State.Bump("CommandsDenied")
			Util.Warn("rejected client -> server Announcement fire from", player and player.Name)
		end), "Net.Announcement.Guard")
	end
end

function ServerCore.AnnounceServerStart()
	if not CONFIG.ServerInfo.AnnounceServerStart then
		return
	end
	Util.Delay(2, function()
		Broadcaster.Broadcast({
			Kind = "Banner",
			Message = CONFIG.ServerInfo.ServerStartMessage,
			Title = "SERVER ONLINE",
			Style = "Ice",
			Duration = 8,
			Rank = "Owner",
			SenderName = "System",
		}, { Source = "boot", SkipCooldown = true })
	end, "ServerCore.StartMessage")
end

function ServerCore.Start()
	if ServerCore.Started then
		return false
	end
	ServerCore.Started = true
	State.Mode = "server"

	Util.Info("starting server core for", #Players:GetPlayers(), "player(s)")

	Net.SetupServer()
	ServerCore.HookRemotes()
	ServerCore.HookChat()

	Audio.Preload()
	Persistence.Load()
	Scheduler.LoadFromConfig()
	Scheduler.Start()
	Persistence.StartAutoSave()

	Util.Track(Players.PlayerAdded:Connect(function(player)
		Util.Spawn(function()
			ServerCore.InstallForPlayer(player)
		end, "ServerCore.PlayerAdded")
	end), "Players.PlayerAdded")

	Util.Track(Players.PlayerRemoving:Connect(function(player)
		local ok, err = pcall(function()
			ServerCore.OnPlayerRemoving(player)
		end)
		if not ok then
			Util.Warn("player removing cleanup failed:", err)
		end
	end), "Players.PlayerRemoving")

	-- Players already in the server (Studio start, or a script reload).
	for _, player in ipairs(Players:GetPlayers()) do
		Util.Spawn(function()
			ServerCore.InstallForPlayer(player)
		end, "ServerCore.ExistingPlayer")
	end

	ServerCore.AnnounceServerStart()

	-- Graceful shutdown: say goodbye, then persist.
	pcall(function()
		game:BindToClose(function()
			if CONFIG.Persistence.SaveOnShutdown then
				Persistence.Save()
			end
			if #Players:GetPlayers() > 0 then
				Broadcaster.Broadcast({
					Kind = "Banner",
					Message = "This server is shutting down. Thanks for playing!",
					Title = "SERVER CLOSING",
					Style = "Shadow",
					Duration = 5,
					Rank = "Owner",
					SenderName = "System",
				}, { Source = "shutdown", SkipCooldown = true })
			end
			task.wait(1.5)
		end)
	end)

	Util.Info("server core ready")
	return true
end

AnnouncementPanel.ServerCore = ServerCore

--// ==========================================================================
--// SECTION 24  ::  OWNER CONSOLE  (client install)
--// A draggable control panel: compose announcements with buttons instead of
--// typing commands, fire presets, read history, tweak the MOTD, run tools and
--// start the chaos simulator. All of it sends real commands through the same
--// gated path as chat, so nothing bypasses permissions.
--// ==========================================================================

local ClientConsole = {}

ClientConsole.Built = false
ClientConsole.Open_ = false
ClientConsole.Minimized = false
ClientConsole.Tab = "Compose"
ClientConsole.Pages = {}
ClientConsole.Buttons = {}
ClientConsole.LogLines = {}
ClientConsole.Settings = {
	Kind = "Banner",
	Style = CONFIG.Console.DefaultStyle,
	Duration = CONFIG.Console.DefaultDuration,
	Target = "all",
	Color = nil,
	Effects = { Flash = true, Shake = false, Confetti = false },
	Sound = true,
}
ClientConsole.OnLog = Util.CreateSignal()
ClientConsole.OnOpenChanged = Util.CreateSignal()
ClientConsole.StatePacket = nil

local CONSOLE_COLORS = {
	Chrome = Color3.fromRGB(24, 24, 32),
	ChromeLight = Color3.fromRGB(38, 38, 50),
	Panel = Color3.fromRGB(18, 18, 25),
	Field = Color3.fromRGB(14, 14, 20),
	Text = Color3.fromRGB(236, 236, 244),
	TextDim = Color3.fromRGB(150, 152, 168),
	Accent = Color3.fromRGB(255, 196, 61),
	Accent2 = Color3.fromRGB(88, 176, 255),
	Success = Color3.fromRGB(140, 255, 170),
	Danger = Color3.fromRGB(255, 110, 110),
	Border = Color3.fromRGB(58, 58, 74),
}

--// ---------- small local helpers -------------------------------------------

local function consoleLabel(props)
	local label = UIBuilder.Label(props)
	label.ZIndex = (props and props.ZIndex or 0) + 60
	return label
end

local function consoleButton(props)
	local button = UIBuilder.Button(props)
	button.ZIndex = (props and props.ZIndex or 0) + 60
	return button
end

local function consoleBox(props)
	local box = UIBuilder.Box(props)
	box.ZIndex = (props and props.ZIndex or 0) + 60
	return box
end

local function consoleFrame(props)
	local frame = UIBuilder.Frame(props)
	frame.ZIndex = (props and props.ZIndex or 0) + 60
	return frame
end

local function chip(text, parent, options)
	options = options or {}
	local button = consoleButton({
		Name = "Chip_" .. tostring(text):gsub("%s", ""),
		Size = options.Size or UDim2.fromOffset(options.Width or 74, options.Height or 26),
		Position = options.Position,
		BackgroundColor3 = options.Color or CONSOLE_COLORS.ChromeLight,
		Text = tostring(text),
		TextSize = options.TextSize or 12,
		TextColor3 = options.TextColor or CONSOLE_COLORS.Text,
		CornerRadius = options.CornerRadius or 8,
		FontWeight = "bold",
		Parent = parent,
	})
	if options.StrokeColor then
		UIBuilder.Stroke(options.StrokeColor, 1, 0.35, button)
	end
	return button
end

local function fieldLabel(text, parent, position, size)
	return consoleLabel({
		Name = "FieldLabel",
		Position = position or UDim2.fromOffset(0, 0),
		Size = size or UDim2.new(1, 0, 0, 14),
		Text = tostring(text):upper(),
		TextSize = 10,
		TextColor3 = CONSOLE_COLORS.TextDim,
		FontWeight = "black",
		Parent = parent,
	})
end

--// ---------- build ---------------------------------------------------------

function ClientConsole.Build()
	if ClientConsole.Built then
		return ClientConsole.Gui
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end
	local playerGui = localPlayer:WaitForChild("PlayerGui", 20)
	if playerGui == nil then
		return nil
	end

	local gui = Util.New("ScreenGui", {
		Name = "AP_Console",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 400,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = playerGui,
	})

	local blur = nil
	if CONFIG.Console.BlurBehind and IS_CLIENT then
		blur = Util.New("BlurEffect", {
			Name = "AP_ConsoleBlur",
			Size = 0,
			Enabled = false,
			Parent = Lighting,
		})
		ClientConsole.Blur = blur
	end

	local window = consoleFrame({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = CONFIG.Console.Size,
		BackgroundColor3 = CONSOLE_COLORS.Chrome,
		CornerRadius = 16,
		StrokeColor = CONSOLE_COLORS.Border,
		StrokeThickness = 1,
		Active = true,
		Parent = gui,
	})
	window.BackgroundTransparency = 0.02

	Util.New("UISizeConstraint", {
		MinSize = Vector2.new(420, 320),
		MaxSize = Vector2.new(900, 700),
		Parent = window,
	})

	local chrome = Theme.ChromeGradient()
	chrome.Parent = window

	-- Title bar ------------------------------------------------------------
	local titleBar = consoleFrame({
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 0,
		Parent = window,
	})
	UIBuilder.Corner(16, titleBar)

	local titleAccent = consoleFrame({
		Name = "Accent",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = CONSOLE_COLORS.Accent,
		Parent = titleBar,
	})
	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 61)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 92, 92)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(88, 176, 255)),
		}),
		Rotation = 0,
		Parent = titleAccent,
	})

	local titleLabel = consoleLabel({
		Name = "Title",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -140, 1, 0),
		Text = "\u{1F451}  " .. string.upper(CONFIG.SystemName) .. "  \u{2022}  OWNER CONSOLE",
		TextSize = 13,
		TextColor3 = CONSOLE_COLORS.Text,
		FontWeight = "black",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = titleBar,
	})

	local rankBadge = consoleLabel({
		Name = "RankBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0.5, 0),
		Size = UDim2.fromOffset(64, 20),
		Text = "OWNER",
		TextSize = 10,
		TextColor3 = CONSOLE_COLORS.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		FontWeight = "black",
		Parent = titleBar,
	})

	local minimizeButton = consoleButton({
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		Text = "\u{2013}",
		TextSize = 14,
		BackgroundColor3 = CONSOLE_COLORS.Panel,
		TextColor3 = CONSOLE_COLORS.TextDim,
		CornerRadius = 6,
		Parent = titleBar,
	})

	local closeButton = consoleButton({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		Text = "\u{2715}",
		TextSize = 12,
		BackgroundColor3 = Color3.fromRGB(90, 30, 34),
		TextColor3 = Color3.fromRGB(255, 200, 200),
		CornerRadius = 6,
		Parent = titleBar,
	})

	-- Tab bar --------------------------------------------------------------
	local tabBar = consoleFrame({
		Name = "TabBar",
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = window,
	})

	local tabLayout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = tabBar,
	})
	UIBuilder.Padding(0, 0, 12, 12, tabBar)

	local tabDefinitions = {
		{ Key = "Compose", Text = "COMPOSE", Order = 1 },
		{ Key = "Presets", Text = "PRESETS", Order = 2 },
		{ Key = "History", Text = "HISTORY", Order = 3 },
		{ Key = "Tools", Text = "TOOLS", Order = 4 },
		{ Key = "Simulator", Text = "CHAOS", Order = 5 },
	}

	ClientConsole.TabButtons = {}
	for _, tab in ipairs(tabDefinitions) do
		local button = chip(tab.Text, tabBar, {
			Width = 86,
			Height = 26,
			Color = CONSOLE_COLORS.Panel,
			TextSize = 11,
		})
		button.LayoutOrder = tab.Order
		ClientConsole.TabButtons[tab.Key] = button
	end

	-- Body -----------------------------------------------------------------
	local body = consoleFrame({
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 78),
		Size = UDim2.new(1, 0, 1, -110),
		BackgroundColor3 = CONSOLE_COLORS.Panel,
		CornerRadius = 12,
		ClipsDescendants = true,
		Parent = window,
	})
	UIBuilder.Padding(0, 0, 10, 10, body)

	-- Status / log bar -----------------------------------------------------
	local statusBar = consoleFrame({
		Name = "StatusBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 0,
		Parent = window,
	})
	UIBuilder.Corner(16, statusBar)

	local statusText = consoleLabel({
		Name = "StatusText",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -160, 1, 0),
		Text = "Ready.",
		TextSize = 11,
		TextColor3 = CONSOLE_COLORS.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = statusBar,
	})

	local modeText = consoleLabel({
		Name = "ModeText",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 14),
		Text = "v" .. CONFIG.Version .. "  \u{2022}  solo",
		TextSize = 10,
		TextColor3 = CONSOLE_COLORS.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = statusBar,
	})

	-- Resize grip ----------------------------------------------------------
	local grip = consoleFrame({
		Name = "Grip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -6),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = CONSOLE_COLORS.Border,
		CornerRadius = 3,
		Parent = window,
	})

	ClientConsole.Gui = gui
	ClientConsole.Window = window
	ClientConsole.TitleBar = titleBar
	ClientConsole.TitleLabel = titleLabel
	ClientConsole.RankBadge = rankBadge
	ClientConsole.TabBar = tabBar
	ClientConsole.Body = body
	ClientConsole.StatusText = statusText
	ClientConsole.ModeText = modeText
	ClientConsole.MinimizeButton = minimizeButton
	ClientConsole.CloseButton = closeButton
	ClientConsole.Grip = grip
	ClientConsole.TabLayout = tabLayout

	ClientConsole.BuildPages()
	ClientConsole.WireWindow()
	ClientConsole.SetTab("Compose")
	ClientConsole.Built = true

	return gui
end

--// ---------- pages ---------------------------------------------------------

function ClientConsole.MakePage(name)
	local page = consoleFrame({
		Name = "Page_" .. name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = ClientConsole.Body,
	})
	ClientConsole.Pages[name] = page
	return page
end

function ClientConsole.BuildPages()
	ClientConsole.BuildComposePage()
	ClientConsole.BuildPresetsPage()
	ClientConsole.BuildHistoryPage()
	ClientConsole.BuildToolsPage()
	ClientConsole.BuildSimulatorPage()
end

function ClientConsole.BuildComposePage()
	local page = ClientConsole.MakePage("Compose")

	local scroll = Util.New("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = CONSOLE_COLORS.Border,
		CanvasSize = UDim2.fromOffset(0, 620),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	})
	UIBuilder.Padding(10, 10, 10, 10, scroll)

	local layout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = scroll,
	})
	ClientConsole.ComposeLayout = layout

	local cursor = 0
	local function nextRow(height)
		local row = consoleFrame({
			Name = "Row_" .. cursor,
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			LayoutOrder = cursor,
			Parent = scroll,
		})
		cursor += 1
		return row
	end

	-- Type of announcement --------------------------------------------------
	local kindRow = nextRow(40)
	fieldLabel("Announcement type", kindRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	local kinds = { "Banner", "Alert", "Toast", "Ticker", "Countdown" }
	ClientConsole.KindButtons = {}
	for index, kind in ipairs(kinds) do
		local button = chip(kind, kindRow, {
			Width = 82,
			Height = 24,
			Position = UDim2.fromOffset((index - 1) * 86, 16),
			Color = CONSOLE_COLORS.ChromeLight,
			TextSize = 11,
		})
		ClientConsole.KindButtons[kind] = button
	end

	-- Title -----------------------------------------------------------------
	local titleRow = nextRow(46)
	fieldLabel("Title (optional)", titleRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	local titleBox = consoleBox({
		Name = "TitleBox",
		Position = UDim2.new(0, 0, 0, 16),
		Size = UDim2.new(1, 0, 0, 28),
		PlaceholderText = "e.g. SERVER RESTART",
		TextSize = 13,
		Parent = titleRow,
	})

	-- Message ---------------------------------------------------------------
	local messageRow = nextRow(88)
	fieldLabel("Message", messageRow, UDim2.fromOffset(0, 0), UDim2.new(1, -60, 0, 14))
	local counter = consoleLabel({
		Name = "Counter",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, 14),
		Text = "0 / " .. LIMITS.MaxMessageLength,
		TextSize = 10,
		TextColor3 = CONSOLE_COLORS.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = messageRow,
	})
	local messageBox = consoleBox({
		Name = "MessageBox",
		Position = UDim2.new(0, 0, 0, 16),
		Size = UDim2.new(1, 0, 0, 68),
		PlaceholderText = "Type the announcement, then press Enter or SEND...",
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = messageRow,
	})
	UIBuilder.Padding(8, 8, 10, 10, messageBox)
	ClientConsole.MessageBox = messageBox
	ClientConsole.TitleBox = titleBox
	ClientConsole.Counter = counter

	-- Style -----------------------------------------------------------------
	local styleRow = nextRow(66)
	fieldLabel("Style", styleRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	ClientConsole.StyleButtons = {}
	local styleNames = Theme.StyleNames()
	for index, styleName in ipairs(styleNames) do
		local column = (index - 1) % 5
		local row = math.floor((index - 1) / 5)
		local style = Theme.GetStyle(styleName)
		local button = chip(styleName, styleRow, {
			Width = 82,
			Height = 22,
			Position = UDim2.fromOffset(column * 86, 16 + (row * 26)),
			Color = Util.ColorLerp(style.GradientBottom or CONSOLE_COLORS.ChromeLight, Color3.fromRGB(0, 0, 0), 0.45),
			StrokeColor = style.GradientTop,
			TextSize = 10,
		})
		ClientConsole.StyleButtons[styleName] = button
	end
	styleRow.Size = UDim2.new(1, 0, 0, 16 + (math.ceil(#styleNames / 5) * 26) + 6)

	-- Colour ----------------------------------------------------------------
	local colorRow = nextRow(44)
	fieldLabel("Accent colour (optional)", colorRow, UDim2.fromOffset(0, 0), UDim2.new(1, -60, 0, 14))
	local colorNames = { "gold", "red", "orange", "cyan", "green", "purple", "pink", "white", "silver" }
	ClientConsole.ColorButtons = {}
	for index, colorName in ipairs(colorNames) do
		local swatch = consoleButton({
			Name = "Swatch_" .. colorName,
			Position = UDim2.fromOffset((index - 1) * 28, 16),
			Size = UDim2.fromOffset(22, 22),
			Text = "",
			BackgroundColor3 = Util.ColorFromName(colorName),
			CornerRadius = 11,
			Parent = colorRow,
		})
		UIBuilder.Stroke(Color3.fromRGB(0, 0, 0), 1, 0.6, swatch)
		ClientConsole.ColorButtons[colorName] = swatch
	end
	local clearSwatch = consoleButton({
		Name = "Swatch_clear",
		Position = UDim2.fromOffset(#colorNames * 28, 16),
		Size = UDim2.fromOffset(22, 22),
		Text = "\u{2715}",
		TextSize = 10,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		TextColor3 = CONSOLE_COLORS.TextDim,
		CornerRadius = 11,
		Parent = colorRow,
	})
	ClientConsole.ColorButtons["none"] = clearSwatch

	-- Target ----------------------------------------------------------------
	local targetRow = nextRow(44)
	fieldLabel("Audience", targetRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	local targets = { "all", "staff", "admins", "nonstaff", "me" }
	ClientConsole.TargetButtons = {}
	for index, target in ipairs(targets) do
		local button = chip(target, targetRow, {
			Width = 78,
			Height = 24,
			Position = UDim2.fromOffset((index - 1) * 82, 16),
			Color = CONSOLE_COLORS.ChromeLight,
			TextSize = 11,
		})
		ClientConsole.TargetButtons[target] = button
	end

	-- Duration --------------------------------------------------------------
	local durationRow = nextRow(44)
	fieldLabel("Duration (seconds)", durationRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	local minus = consoleButton({
		Name = "DurationMinus",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.fromOffset(28, 24),
		Text = "-",
		TextSize = 16,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 6,
		Parent = durationRow,
	})
	local durationLabel = consoleLabel({
		Name = "DurationLabel",
		Position = UDim2.fromOffset(32, 16),
		Size = UDim2.fromOffset(52, 24),
		Text = tostring(ClientConsole.Settings.Duration),
		TextSize = 14,
		TextColor3 = CONSOLE_COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontWeight = "bold",
		Parent = durationRow,
	})
	local plus = consoleButton({
		Name = "DurationPlus",
		Position = UDim2.fromOffset(88, 16),
		Size = UDim2.fromOffset(28, 24),
		Text = "+",
		TextSize = 14,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 6,
		Parent = durationRow,
	})
	ClientConsole.DurationLabel = durationLabel
	ClientConsole.DurationMinus = minus
	ClientConsole.DurationPlus = plus

	-- Effects ---------------------------------------------------------------
	local effectRow = nextRow(44)
	fieldLabel("Effects", effectRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	local effectNames = { "Flash", "Shake", "Confetti", "Sound" }
	ClientConsole.EffectButtons = {}
	for index, effectName in ipairs(effectNames) do
		local button = chip(effectName, effectRow, {
			Width = 78,
			Height = 24,
			Position = UDim2.fromOffset((index - 1) * 82, 16),
			Color = CONSOLE_COLORS.ChromeLight,
			TextSize = 11,
		})
		ClientConsole.EffectButtons[effectName] = button
	end

	-- Quick messages --------------------------------------------------------
	local quickRow = nextRow(20 + (math.ceil(#CONFIG.Console.QuickMessages / 2) * 26))
	fieldLabel("Quick messages", quickRow, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	ClientConsole.QuickButtons = {}
	for index, quick in ipairs(CONFIG.Console.QuickMessages) do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local button = consoleButton({
			Name = "Quick_" .. index,
			Position = UDim2.fromOffset(column * 218, 16 + (row * 26)),
			Size = UDim2.fromOffset(212, 22),
			Text = Util.Truncate(quick, 34),
			TextSize = 11,
			BackgroundColor3 = CONSOLE_COLORS.Field,
			TextColor3 = CONSOLE_COLORS.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			CornerRadius = 6,
			Parent = quickRow,
		})
		UIBuilder.Padding(0, 0, 8, 8, button)
		ClientConsole.QuickButtons[index] = { Button = button, Text = quick }
	end

	-- Action buttons --------------------------------------------------------
	local actionRow = nextRow(40)
	local sendButton = consoleButton({
		Name = "Send",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(150, 30),
		Text = "\u{1F4E2}  SEND ANNOUNCEMENT",
		TextSize = 12,
		BackgroundColor3 = Color3.fromRGB(255, 176, 32),
		TextColor3 = Color3.fromRGB(30, 20, 0),
		FontWeight = "black",
		CornerRadius = 8,
		Parent = actionRow,
	})
	local previewButton = consoleButton({
		Name = "Preview",
		Position = UDim2.fromOffset(156, 8),
		Size = UDim2.fromOffset(104, 30),
		Text = "PREVIEW",
		TextSize = 11,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		TextColor3 = CONSOLE_COLORS.Text,
		CornerRadius = 8,
		Parent = actionRow,
	})
	local clearFields = consoleButton({
		Name = "ClearFields",
		Position = UDim2.fromOffset(266, 8),
		Size = UDim2.fromOffset(88, 30),
		Text = "CLEAR",
		TextSize = 11,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		TextColor3 = CONSOLE_COLORS.TextDim,
		CornerRadius = 8,
		Parent = actionRow,
	})
	ClientConsole.SendButton = sendButton
	ClientConsole.PreviewButton = previewButton
	ClientConsole.ClearFieldsButton = clearFields
	ClientConsole.ComposeScroll = scroll

	ClientConsole.WireComposePage()
end

function ClientConsole.BuildPresetsPage()
	local page = ClientConsole.MakePage("Presets")
	local names = Broadcaster.PresetNames()

	local scroll = Util.New("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = CONSOLE_COLORS.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Parent = page,
	})
	UIBuilder.Padding(10, 10, 10, 10, scroll)

	local grid = Util.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(212, 74),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})

	ClientConsole.PresetButtons = {}
	for index, name in ipairs(names) do
		local preset = CONFIG.Presets[name]
		local style = Theme.GetStyle(preset.Style)
		local card = consoleButton({
			Name = "Preset_" .. name,
			BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
			Text = "",
			CornerRadius = 10,
			LayoutOrder = index,
			Parent = scroll,
		})
		UIBuilder.Stroke(style.GradientTop or CONSOLE_COLORS.Accent, 1, 0.5, card)

		local label = consoleLabel({
			Name = "Label",
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 0, 16),
			Text = string.upper(name),
			TextSize = 12,
			TextColor3 = style.GradientTop or CONSOLE_COLORS.Accent,
			FontWeight = "black",
			Parent = card,
		})

		local detail = consoleLabel({
			Name = "Detail",
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -20, 0, 40),
			Text = Util.Truncate(preset.Message or "", 78),
			TextSize = 10,
			TextColor3 = CONSOLE_COLORS.TextDim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})

		ClientConsole.PresetButtons[name] = { Button = card, Label = label, Detail = detail, Preset = preset }
	end

	ClientConsole.PresetScroll = scroll
	ClientConsole.PresetGrid = grid
	ClientConsole.WirePresetsPage()
end

function ClientConsole.BuildHistoryPage()
	local page = ClientConsole.MakePage("History")

	local header = consoleFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = page,
	})

	local refresh = consoleButton({
		Name = "Refresh",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(78, 24),
		Text = "REFRESH",
		TextSize = 11,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 6,
		Parent = header,
	})

	local searchBox = consoleBox({
		Name = "Search",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -100, 0, 24),
		PlaceholderText = "search history...",
		TextSize = 12,
		Parent = header,
	})

	local scroll = Util.New("ScrollingFrame", {
		Name = "Scroll",
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = CONSOLE_COLORS.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Parent = page,
	})

	local layout = Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = scroll,
	})

	ClientConsole.HistoryScroll = scroll
	ClientConsole.HistoryLayout = layout
	ClientConsole.HistoryRefresh = refresh
	ClientConsole.HistorySearch = searchBox
	ClientConsole.HistoryEntries = {}
	ClientConsole.WireHistoryPage()
end

function ClientConsole.BuildToolsPage()
	local page = ClientConsole.MakePage("Tools")

	local scroll = Util.New("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = CONSOLE_COLORS.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Parent = page,
	})
	UIBuilder.Padding(10, 10, 10, 10, scroll)

	Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = scroll,
	})

	ClientConsole.ToolButtons = {}
	local tools = {
		{ Key = "Clear", Text = "CLEAR ALL SCREENS", Command = ":clear", Color = CONSOLE_COLORS.Danger },
		{ Key = "Flash", Text = "SCREEN FLASH", Command = ":flash", Color = CONSOLE_COLORS.Accent },
		{ Key = "Shake", Text = "SHAKE CAMERAS", Command = ":shake", Color = CONSOLE_COLORS.Accent },
		{ Key = "Confetti", Text = "CONFETTI RAIN", Command = ":confetti", Color = CONSOLE_COLORS.Success },
		{ Key = "Vignette", Text = "VIGNETTE ON", Command = ":vignette on", Color = CONSOLE_COLORS.Accent2 },
		{ Key = "VignetteOff", Text = "VIGNETTE OFF", Command = ":vignette off", Color = CONSOLE_COLORS.TextDim },
		{ Key = "Stats", Text = "SERVER STATS", Command = ":stats", Color = CONSOLE_COLORS.Accent2 },
		{ Key = "Ranks", Text = "PLAYER RANKS", Command = ":ranks", Color = CONSOLE_COLORS.Accent2 },
		{ Key = "Refresh", Text = "RE-RESOLVE RANKS", Command = ":refresh", Color = CONSOLE_COLORS.TextDim },
		{ Key = "Mutes", Text = "MUTE LIST", Command = ":mutes", Color = CONSOLE_COLORS.TextDim },
	}

	for index, tool in ipairs(tools) do
		local button = consoleButton({
			Name = "Tool_" .. tool.Key,
			Size = UDim2.new(1, 0, 0, 28),
			Text = tool.Text,
			TextSize = 12,
			BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
			TextColor3 = tool.Color or CONSOLE_COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontWeight = "bold",
			CornerRadius = 8,
			LayoutOrder = index,
			Parent = scroll,
		})
		UIBuilder.Padding(0, 0, 12, 12, button)
		ClientConsole.ToolButtons[tool.Key] = { Button = button, Command = tool.Command }
	end

	-- MOTD editor -----------------------------------------------------------
	local motdFrame = consoleFrame({
		Name = "MOTDFrame",
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = CONSOLE_COLORS.Field,
		CornerRadius = 10,
		LayoutOrder = 90,
		Parent = scroll,
	})
	UIBuilder.Padding(10, 10, 10, 10, motdFrame)

	fieldLabel("Message of the day", motdFrame, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 14))
	local motdBox = consoleBox({
		Name = "MOTDBox",
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, -96, 0, 46),
		PlaceholderText = "Shown to everyone who joins...",
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = motdFrame,
	})
	UIBuilder.Padding(6, 6, 8, 8, motdBox)

	local motdSend = consoleButton({
		Name = "MOTDSend",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 18),
		Size = UDim2.fromOffset(88, 22),
		Text = "SET MOTD",
		TextSize = 11,
		BackgroundColor3 = CONSOLE_COLORS.Accent2,
		TextColor3 = Color3.fromRGB(6, 18, 30),
		FontWeight = "bold",
		CornerRadius = 6,
		Parent = motdFrame,
	})
	local motdClear = consoleButton({
		Name = "MOTDClear",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 42),
		Size = UDim2.fromOffset(88, 22),
		Text = "CLEAR MOTD",
		TextSize = 11,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		TextColor3 = CONSOLE_COLORS.Danger,
		CornerRadius = 6,
		Parent = motdFrame,
	})

	ClientConsole.MOTDBox = motdBox
	ClientConsole.MOTDSend = motdSend
	ClientConsole.MOTDClear = motdClear
	ClientConsole.ToolsScroll = scroll
	ClientConsole.WireToolsPage()
end

function ClientConsole.BuildSimulatorPage()
	local page = ClientConsole.MakePage("Simulator")

	consoleLabel({
		Name = "Intro",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 40),
		Text = "The admin-abuse simulator. Fake owners take over the screen with dramatic messages, flashes and confetti. Great for videos and stress tests.",
		TextSize = 11,
		TextColor3 = CONSOLE_COLORS.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = page,
	})

	local chaosButton = consoleButton({
		Name = "ChaosToggle",
		Position = UDim2.fromOffset(10, 54),
		Size = UDim2.fromOffset(190, 34),
		Text = "\u{1F525}  START CHAOS MODE",
		TextSize = 12,
		BackgroundColor3 = Color3.fromRGB(200, 40, 40),
		TextColor3 = Color3.fromRGB(255, 230, 230),
		FontWeight = "black",
		CornerRadius = 8,
		Parent = page,
	})

	local durationLabel = consoleLabel({
		Name = "DurationLabel",
		Position = UDim2.fromOffset(210, 62),
		Size = UDim2.fromOffset(150, 18),
		Text = "duration: 45s",
		TextSize = 11,
		TextColor3 = CONSOLE_COLORS.TextDim,
		Parent = page,
	})

	local minus = consoleButton({
		Name = "ChaosMinus",
		Position = UDim2.fromOffset(300, 56),
		Size = UDim2.fromOffset(26, 24),
		Text = "-",
		TextSize = 14,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 6,
		Parent = page,
	})
	local plus = consoleButton({
		Name = "ChaosPlus",
		Position = UDim2.fromOffset(330, 56),
		Size = UDim2.fromOffset(26, 24),
		Text = "+",
		TextSize = 12,
		BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
		CornerRadius = 6,
		Parent = page,
	})

	fieldLabel("One-shot fakes", page, UDim2.fromOffset(10, 98), UDim2.new(1, -20, 0, 14))
	ClientConsole.SimButtons = {}
	local sims = {
		{ Key = "OwnerBanner", Text = "FAKE OWNER BANNER", Kind = "Banner", Rank = "Owner" },
		{ Key = "AdminAlert", Text = "FAKE ADMIN ALERT", Kind = "Alert", Rank = "Admin" },
		{ Key = "ModToast", Text = "FAKE MOD TOAST", Kind = "Toast", Rank = "Mod" },
		{ Key = "OwnerTicker", Text = "FAKE OWNER TICKER", Kind = "Ticker", Rank = "Owner" },
		{ Key = "Countdown", Text = "COUNTDOWN 10", Kind = "Countdown", Rank = "Owner" },
		{ Key = "Burst", Text = "BURST OF 5", Kind = "Burst", Rank = "Owner" },
	}
	for index, sim in ipairs(sims) do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local button = consoleButton({
			Name = "Sim_" .. sim.Key,
			Position = UDim2.fromOffset(10 + (column * 196), 116 + (row * 32)),
			Size = UDim2.fromOffset(190, 28),
			Text = sim.Text,
			TextSize = 11,
			BackgroundColor3 = CONSOLE_COLORS.ChromeLight,
			TextColor3 = CONSOLE_COLORS.Text,
			FontWeight = "bold",
			CornerRadius = 8,
			Parent = page,
		})
		ClientConsole.SimButtons[sim.Key] = { Button = button, Definition = sim }
	end

	local statusLabel = consoleLabel({
		Name = "ChaosStatus",
		Position = UDim2.fromOffset(10, 220),
		Size = UDim2.new(1, -20, 0, 34),
		Text = "Chaos is off.",
		TextSize = 11,
		TextColor3 = CONSOLE_COLORS.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = page,
	})

	ClientConsole.ChaosButton = chaosButton
	ClientConsole.ChaosDurationLabel = durationLabel
	ClientConsole.ChaosMinus = minus
	ClientConsole.ChaosPlus = plus
	ClientConsole.ChaosStatusLabel = statusLabel
	ClientConsole.ChaosDuration = CONFIG.Chaos.DefaultDurationSeconds
	ClientConsole.WireSimulatorPage()
end

AnnouncementPanel.ClientConsole = ClientConsole

--// ==========================================================================
--// SECTION 25  ::  CONSOLE WIRING
--// ==========================================================================

function ClientConsole.SetStatus(text, color)
	if ClientConsole.StatusText == nil then
		return
	end
	ClientConsole.StatusText.Text = tostring(text)
	ClientConsole.StatusText.TextColor3 = color or CONSOLE_COLORS.TextDim
end

-- Falls back to the shared log palette so every kind has a colour.
function ClientConsole.LogColor(kind)
	local replyColor = CommandService.ReplyColors[kind or "info"]
	if replyColor then
		return replyColor
	end
	return LOG_COLORS[kind or "info"] or LOG_COLORS.info
end

function ClientConsole.LogLine(text, kind)
	local color = ClientConsole.LogColor(kind)
	table.insert(ClientConsole.LogLines, { Text = tostring(text), Kind = kind or "info", At = os.clock() })
	while #ClientConsole.LogLines > 40 do
		table.remove(ClientConsole.LogLines, 1)
	end
	ClientConsole.SetStatus(text, color)
	ClientConsole.OnLog:Fire(text, kind)
end

-- The one place the console turns UI state into a command string.
function ClientConsole.RunCommandText(text, quiet)
	if type(text) ~= "string" or text == "" then
		return false
	end
	if not quiet then
		ClientConsole.LogLine("> " .. text, "info")
	end

	if AnnouncementPanel.Client and AnnouncementPanel.Client.Mode == "companion" and Net.IsServerActive() then
		local sent = Net.FireServer("Execute", { Action = "Execute", Text = text })
		if not sent then
			ClientConsole.LogLine("could not reach the server", "error")
		end
		-- Ask for a fresh state packet so history/stats stay in sync.
		Net.FireServer("Sync", { Action = "RequestState" })
		return sent
	end

	-- Solo mode: run it locally with the same parser and gates.
	local player = Players.LocalPlayer
	local ok = CommandService.Execute(player, text, "console")
	ClientConsole.RefreshState()
	return ok
end

function ClientConsole.BuildComposeCommand()
	local settings = ClientConsole.Settings
	local message = Util.Trim(ClientConsole.MessageBox and ClientConsole.MessageBox.Text or "")
	local title = Util.Trim(ClientConsole.TitleBox and ClientConsole.TitleBox.Text or "")

	if message == "" then
		return nil, "type a message first"
	end
	if #message > LIMITS.MaxMessageLength then
		message = Util.Truncate(message, LIMITS.MaxMessageLength)
	end

	local commandName = ({
		Banner = "announce",
		Alert = "alert",
		Toast = "toast",
		Ticker = "ticker",
		Countdown = "countdown",
	})[settings.Kind] or "announce"

	local parts = { CONFIG.CommandPrefix .. commandName }

	if settings.Kind == "Countdown" then
		local seconds = tonumber(message:match("^(%d+)"))
		if seconds then
			table.insert(parts, tostring(seconds))
			local rest = message:match("^%d+%s*(.*)$")
			if rest and rest ~= "" then
				table.insert(parts, '"' .. rest .. '"')
			end
		else
			table.insert(parts, tostring(math.floor(settings.Duration)))
			table.insert(parts, '"' .. message .. '"')
		end
	else
		if message:find('"') then
			message = message:gsub('"', "'")
		end
		table.insert(parts, '"' .. message .. '"')
		if title ~= "" then
			table.insert(parts, '--title "' .. title:gsub('"', "'") .. '"')
		end
		table.insert(parts, "-s " .. tostring(settings.Style))
		table.insert(parts, "-t " .. tostring(math.floor(settings.Duration)))
		if settings.Target ~= "all" then
			table.insert(parts, "--to " .. tostring(settings.Target))
		end
		if settings.Color then
			table.insert(parts, "-c " .. tostring(settings.Color))
		end
		local effectFlags = {}
		if settings.Effects.Flash then
			table.insert(effectFlags, "--flash")
		end
		if settings.Effects.Shake then
			table.insert(effectFlags, "--shake")
		end
		if settings.Effects.Confetti then
			table.insert(effectFlags, "--confetti")
		end
		if settings.Sound == false then
			table.insert(effectFlags, "--no-effects")
		end
		for _, flag in ipairs(effectFlags) do
			table.insert(parts, flag)
		end
	end

	return table.concat(parts, " ")
end

function ClientConsole.Send()
	local command, problem = ClientConsole.BuildComposeCommand()
	if command == nil then
		ClientConsole.SetStatus(problem or "cannot send", CONSOLE_COLORS.Danger)
		Audio.Play("Deny", { Volume = CONFIG.Sounds.Volume * 0.6 })
		if ClientConsole.Window then
			Effects.ShakeGUI({ Layers = ClientConsole.Window, Flash = nil, Backdrop = nil }, 0.5, 0.25)
		end
		return false
	end
	Audio.Play("ConsoleClick")
	ClientConsole.RunCommandText(command)
	if ClientConsole.MessageBox then
		ClientConsole.MessageBox.Text = ""
		ClientConsole.UpdateCounter()
	end
	return true
end

function ClientConsole.Preview()
	local command, problem = ClientConsole.BuildComposeCommand()
	if command == nil then
		ClientConsole.SetStatus(problem or "nothing to preview", CONSOLE_COLORS.Danger)
		return false
	end
	-- Preview always targets the local player only.
	local previewCommand = command:gsub("%-%-to%s+%S+", "") .. " --to me"
	ClientConsole.RunCommandText(previewCommand)
	return true
end

function ClientConsole.UpdateCounter()
	if ClientConsole.Counter == nil or ClientConsole.MessageBox == nil then
		return
	end
	local length = #ClientConsole.MessageBox.Text
	local color = CONSOLE_COLORS.TextDim
	if length > LIMITS.MaxMessageLength then
		color = CONSOLE_COLORS.Danger
	elseif length > LIMITS.MaxMessageLength * 0.8 then
		color = CONSOLE_COLORS.Accent
	end
	ClientConsole.Counter.Text = length .. " / " .. LIMITS.MaxMessageLength
	ClientConsole.Counter.TextColor3 = color
end

-- Highlights the chips that match the current settings.
function ClientConsole.RefreshChoices()
	local settings = ClientConsole.Settings

	for kind, button in pairs(ClientConsole.KindButtons or {}) do
		local selected = (kind == settings.Kind)
		button.BackgroundColor3 = selected and CONSOLE_COLORS.Accent or CONSOLE_COLORS.ChromeLight
		button.TextColor3 = selected and Color3.fromRGB(28, 20, 0) or CONSOLE_COLORS.Text
	end

	for styleName, button in pairs(ClientConsole.StyleButtons or {}) do
		local selected = (styleName == settings.Style)
		local style = Theme.GetStyle(styleName)
		button.BackgroundColor3 = selected
			and (style.GradientBottom or CONSOLE_COLORS.Accent)
			or Util.ColorLerp(style.GradientBottom or CONSOLE_COLORS.ChromeLight, Color3.fromRGB(0, 0, 0), 0.45)
		button.TextColor3 = selected and Theme.ReadableTextOn(style.GradientBottom or CONSOLE_COLORS.Accent) or CONSOLE_COLORS.Text
	end

	for colorName, button in pairs(ClientConsole.ColorButtons or {}) do
		local selected = (colorName == settings.Color) or (colorName == "none" and settings.Color == nil)
		for _, stroke in ipairs(button:GetChildren()) do
			if stroke:IsA("UIStroke") then
				stroke.Transparency = selected and 0 or 0.65
				stroke.Thickness = selected and 2 or 1
				stroke.Color = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
			end
		end
	end

	for target, button in pairs(ClientConsole.TargetButtons or {}) do
		local selected = (target == settings.Target)
		button.BackgroundColor3 = selected and CONSOLE_COLORS.Accent2 or CONSOLE_COLORS.ChromeLight
		button.TextColor3 = selected and Color3.fromRGB(4, 16, 28) or CONSOLE_COLORS.Text
	end

	local effectMap = { Flash = "Flash", Shake = "Shake", Confetti = "Confetti", Sound = "Sound" }
	for effectName, button in pairs(ClientConsole.EffectButtons or {}) do
		local enabled
		if effectName == "Sound" then
			enabled = settings.Sound ~= false
		else
			enabled = settings.Effects[effectMap[effectName]] == true
		end
		button.BackgroundColor3 = enabled and CONSOLE_COLORS.Success or CONSOLE_COLORS.ChromeLight
		button.TextColor3 = enabled and Color3.fromRGB(8, 30, 16) or CONSOLE_COLORS.TextDim
	end

	if ClientConsole.DurationLabel then
		ClientConsole.DurationLabel.Text = tostring(math.floor(settings.Duration))
	end
end

function ClientConsole.SetTab(name)
	if ClientConsole.Pages == nil then
		return
	end
	for key, page in pairs(ClientConsole.Pages) do
		page.Visible = (key == name)
	end
	for key, button in pairs(ClientConsole.TabButtons or {}) do
		local selected = (key == name)
		button.BackgroundColor3 = selected and CONSOLE_COLORS.Accent or CONSOLE_COLORS.Panel
		button.TextColor3 = selected and Color3.fromRGB(28, 20, 0) or CONSOLE_COLORS.TextDim
	end
	ClientConsole.Tab = name
	if name == "History" then
		ClientConsole.RefreshHistory()
	end
	if name == "Simulator" then
		ClientConsole.RefreshChaosStatus()
	end
end

function ClientConsole.RefreshHistory(query)
	if ClientConsole.HistoryScroll == nil then
		return
	end
	Util.ClearChildren(ClientConsole.HistoryScroll)
	ClientConsole.HistoryEntries = {}

	local entries
	if ClientConsole.StatePacket and ClientConsole.StatePacket.History and #ClientConsole.StatePacket.History > 0 then
		entries = ClientConsole.StatePacket.History
	else
		entries = State.GetHistory(20)
	end

	if query and query ~= "" then
		local filtered = {}
		local lowered = query:lower()
		for _, entry in ipairs(entries) do
			local haystack = tostring(entry.Message or ""):lower() .. " " .. tostring(entry.Title or ""):lower()
			if haystack:find(lowered, 1, true) then
				table.insert(filtered, entry)
			end
		end
		entries = filtered
	end

	if #entries == 0 then
		consoleLabel({
			Name = "Empty",
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Nothing here yet.",
			TextSize = 12,
			TextColor3 = CONSOLE_COLORS.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = ClientConsole.HistoryScroll,
		})
		return
	end

	for index, entry in ipairs(entries) do
		local meta = Theme.GetRank(entry.Rank or "Player")
		local row = consoleFrame({
			Name = "Entry_" .. index,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = CONSOLE_COLORS.Field,
			CornerRadius = 8,
			LayoutOrder = index,
			Parent = ClientConsole.HistoryScroll,
		})
		UIBuilder.Stroke(meta.Color or CONSOLE_COLORS.Border, 1, 0.6, row)

		consoleLabel({
			Name = "Head",
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 14),
			Text = string.format("%s %s  \u{2022}  %s  \u{2022}  %s",
				tostring(meta.Badge or ""),
				tostring(entry.SenderName or "?"),
				tostring(entry.Kind or "Banner"),
				os.date("%H:%M:%S", entry.Timestamp or os.time())),
			TextSize = 10,
			TextColor3 = meta.Color or CONSOLE_COLORS.TextDim,
			FontWeight = "bold",
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})

		consoleLabel({
			Name = "Body",
			Position = UDim2.fromOffset(10, 19),
			Size = UDim2.new(1, -20, 0, 18),
			Text = Util.Truncate(tostring(entry.Message or ""), 96),
			TextSize = 11,
			TextColor3 = CONSOLE_COLORS.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})

		table.insert(ClientConsole.HistoryEntries, row)
	end
end

function ClientConsole.RefreshChaosStatus()
	if ClientConsole.ChaosStatusLabel == nil then
		return
	end
	local status = Chaos.Status()
	if status.Active then
		ClientConsole.ChaosStatusLabel.Text = string.format(
			"CHAOS IS LIVE - %d messages fired, %s left (started by %s).",
			status.Count or 0, Util.FormatDuration(status.Remaining or 0), tostring(status.StartedBy or "?"))
		ClientConsole.ChaosStatusLabel.TextColor3 = CONSOLE_COLORS.Danger
		ClientConsole.ChaosButton.Text = "\u{23F9}  STOP CHAOS MODE"
		ClientConsole.ChaosButton.BackgroundColor3 = CONSOLE_COLORS.ChromeLight
		ClientConsole.ChaosButton.TextColor3 = CONSOLE_COLORS.Text
	else
		ClientConsole.ChaosStatusLabel.Text = "Chaos is off. Press the button to unleash the admin abuse."
		ClientConsole.ChaosStatusLabel.TextColor3 = CONSOLE_COLORS.TextDim
		ClientConsole.ChaosButton.Text = "\u{1F525}  START CHAOS MODE"
		ClientConsole.ChaosButton.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		ClientConsole.ChaosButton.TextColor3 = Color3.fromRGB(255, 230, 230)
	end
	if ClientConsole.ChaosDurationLabel then
		ClientConsole.ChaosDurationLabel.Text = "duration: " .. tostring(math.floor(ClientConsole.ChaosDuration or 45)) .. "s"
	end
end

function ClientConsole.RefreshState()
	if ClientConsole.RankBadge == nil then
		return
	end
	local player = Players.LocalPlayer
	local rankName = RankSystem.GetRank(player)
	local meta = Theme.GetRank(rankName)

	ClientConsole.RankBadge.Text = tostring(meta.DisplayName or rankName)
	ClientConsole.RankBadge.TextColor3 = meta.Color or CONSOLE_COLORS.Accent

	local mode = (AnnouncementPanel.Client and AnnouncementPanel.Client.Mode) or "solo"
	ClientConsole.ModeText.Text = "v" .. CONFIG.Version .. "  \u{2022}  " .. mode
	ClientConsole.ModeText.TextColor3 = (mode == "companion") and CONSOLE_COLORS.Success or CONSOLE_COLORS.Accent

	if ClientConsole.TitleAccent then
		ClientConsole.TitleAccent.BackgroundColor3 = meta.Color or CONSOLE_COLORS.Accent
	end

	local cap = meta.MaxDuration or LIMITS.DefaultDuration
	if cap > 0 and ClientConsole.Settings.Duration > cap then
		ClientConsole.Settings.Duration = cap
		ClientConsole.RefreshChoices()
	end

	ClientConsole.RefreshChoices()
	ClientConsole.RefreshChaosStatus()
end

function ClientConsole.ApplyStatePacket(packet)
	if type(packet) ~= "table" then
		return
	end
	ClientConsole.StatePacket = packet
	if packet.Rank then
		local meta = Theme.GetRank(packet.Rank)
		if ClientConsole.RankBadge then
			ClientConsole.RankBadge.Text = tostring(packet.RankDisplay or meta.DisplayName)
			ClientConsole.RankBadge.TextColor3 = Util.ColorFromName(packet.Color, meta.Color)
		end
	end
	if packet.Mode then
		ClientConsole.ModeText.Text = "v" .. tostring(packet.Version or CONFIG.Version) .. "  \u{2022}  " .. tostring(packet.Mode)
	end
	if packet.MOTD and ClientConsole.MOTDBox then
		ClientConsole.MOTDBox.Text = tostring(packet.MOTD.Message or "")
	end
	if packet.MaxDuration and ClientConsole.Settings.Duration > packet.MaxDuration then
		ClientConsole.Settings.Duration = packet.MaxDuration
	end
	ClientConsole.RefreshHistory()
	ClientConsole.RefreshState()
	ClientConsole.SetStatus("synced with server", CONSOLE_COLORS.Success)
end

--// ---------- window interactions -------------------------------------------

function ClientConsole.WireWindow()
	local window = ClientConsole.Window
	local titleBar = ClientConsole.TitleBar

	-- Drag -------------------------------------------------------------------
	if CONFIG.Console.Draggable and UserInputService then
		local dragging = false
		local dragStart = nil
		local startPos = nil

		Util.Track(titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = window.Position
			end
		end), "Console.DragBegin")

		Util.Track(titleBar.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end), "Console.DragEnd")

		Util.Track(UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if dragStart == nil or startPos == nil then
				return
			end
			local delta = input.Position - dragStart
			window.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end), "Console.DragMove")
	end

	-- Resize -----------------------------------------------------------------
	if CONFIG.Console.Resizable and UserInputService and ClientConsole.Grip then
		local resizing = false
		local resizeStart = nil
		local startSize = nil

		Util.Track(ClientConsole.Grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resizeStart = input.Position
				startSize = window.AbsoluteSize
			end
		end), "Console.ResizeBegin")

		Util.Track(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
			end
		end), "Console.ResizeEnd")

		Util.Track(UserInputService.InputChanged:Connect(function(input)
			if not resizing or resizeStart == nil or startSize == nil then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = input.Position - resizeStart
			local width = Util.Clamp(startSize.X + delta.X, 420, 900)
			local height = Util.Clamp(startSize.Y + delta.Y, 320, 700)
			window.Size = UDim2.fromOffset(width, height)
		end), "Console.ResizeMove")
	end

	-- Window buttons ---------------------------------------------------------
	Util.Track(ClientConsole.CloseButton.MouseButton1Click:Connect(function()
		Audio.Play("ConsoleClose")
		ClientConsole.Close()
	end), "Console.Close")

	Util.Track(ClientConsole.MinimizeButton.MouseButton1Click:Connect(function()
		ClientConsole.Minimized = not ClientConsole.Minimized
		ClientConsole.Body.Visible = not ClientConsole.Minimized
		ClientConsole.TabBar.Visible = not ClientConsole.Minimized
		ClientConsole.StatusBar = ClientConsole.Window:FindFirstChild("StatusBar")
		if ClientConsole.Minimized then
			window.Size = UDim2.new(window.Size.X.Scale, window.Size.X.Offset, 0, 44)
			ClientConsole.MinimizeButton.Text = "+"
		else
			window.Size = CONFIG.Console.Size
			ClientConsole.MinimizeButton.Text = "\u{2013}"
		end
	end), "Console.Minimize")

	-- Tab bar: the five page chips at the top of the console ------------------
	for key, button in pairs(ClientConsole.TabButtons or {}) do
		Util.Track(button.MouseButton1Click:Connect(function()
			Audio.Play("ConsoleClick")
			ClientConsole.SetTab(key)
		end), "Console.Tab." .. tostring(key))
	end

	-- Hover polish on every button in the window -----------------------------
	for _, descendant in ipairs(window:GetDescendants()) do
		if descendant:IsA("TextButton") then
			local original = descendant.BackgroundColor3
			Util.Track(descendant.MouseEnter:Connect(function()
				descendant.BackgroundColor3 = Util.ColorBrighten(descendant.BackgroundColor3, 0.08)
			end), "Console.Hover." .. descendant.Name)
			Util.Track(descendant.MouseLeave:Connect(function()
				if descendant.Name:find("Chip") or descendant.Name:find("Swatch") or descendant.Name:find("Tool")
					or descendant.Name:find("Sim") or descendant.Name:find("Preset") or descendant.Name:find("Quick")
					or descendant.Name:find("Send") or descendant.Name:find("Preview") or descendant.Name:find("Clear")
					or descendant.Name:find("MOTD") or descendant.Name:find("Refresh") or descendant.Name:find("Duration")
					or descendant.Name:find("Chaos") or descendant.Name:find("Close") or descendant.Name:find("Minimize") then
					-- RefreshChoices owns chip colours, so only nudge the rest.
					if not descendant.Name:find("Chip") and not descendant.Name:find("Swatch") then
						descendant.BackgroundColor3 = original
					end
				else
					descendant.BackgroundColor3 = original
				end
			end), "Console.Unhover." .. descendant.Name)
		end
	end
end

function ClientConsole.WireComposePage()
	for kind, button in pairs(ClientConsole.KindButtons) do
		Util.Track(button.MouseButton1Click:Connect(function()
			ClientConsole.Settings.Kind = kind
			Audio.Play("ConsoleClick")
			ClientConsole.RefreshChoices()
			ClientConsole.SetStatus("type: " .. kind, CONSOLE_COLORS.Accent2)
		end), "Console.Kind." .. kind)
	end

	for styleName, button in pairs(ClientConsole.StyleButtons) do
		Util.Track(button.MouseButton1Click:Connect(function()
			ClientConsole.Settings.Style = styleName
			Audio.Play("ConsoleClick")
			ClientConsole.RefreshChoices()
			ClientConsole.SetStatus("style: " .. styleName, CONSOLE_COLORS.Accent)
		end), "Console.Style." .. styleName)
	end

	for colorName, button in pairs(ClientConsole.ColorButtons) do
		Util.Track(button.MouseButton1Click:Connect(function()
			if colorName == "none" then
				ClientConsole.Settings.Color = nil
			else
				ClientConsole.Settings.Color = colorName
			end
			Audio.Play("ConsoleClick")
			ClientConsole.RefreshChoices()
		end), "Console.Color." .. colorName)
	end

	for target, button in pairs(ClientConsole.TargetButtons) do
		Util.Track(button.MouseButton1Click:Connect(function()
			ClientConsole.Settings.Target = target
			Audio.Play("ConsoleClick")
			ClientConsole.RefreshChoices()
			ClientConsole.SetStatus("audience: " .. target, CONSOLE_COLORS.Accent2)
		end), "Console.Target." .. target)
	end

	for effectName, button in pairs(ClientConsole.EffectButtons) do
		Util.Track(button.MouseButton1Click:Connect(function()
			if effectName == "Sound" then
				ClientConsole.Settings.Sound = not (ClientConsole.Settings.Sound ~= false)
			else
				ClientConsole.Settings.Effects[effectName] = not ClientConsole.Settings.Effects[effectName]
			end
			Audio.Play("ConsoleClick")
			ClientConsole.RefreshChoices()
		end), "Console.Effect." .. effectName)
	end

	Util.Track(ClientConsole.DurationMinus.MouseButton1Click:Connect(function()
		ClientConsole.Settings.Duration = Util.Clamp(ClientConsole.Settings.Duration - 1, LIMITS.MinDuration, LIMITS.MaxDuration)
		ClientConsole.RefreshChoices()
	end), "Console.DurationMinus")

	Util.Track(ClientConsole.DurationPlus.MouseButton1Click:Connect(function()
		local cap = RankSystem.MaxDuration(Players.LocalPlayer)
		local max = (cap and cap > 0) and math.min(cap, LIMITS.MaxDuration) or LIMITS.MaxDuration
		ClientConsole.Settings.Duration = Util.Clamp(ClientConsole.Settings.Duration + 1, LIMITS.MinDuration, max)
		ClientConsole.RefreshChoices()
	end), "Console.DurationPlus")

	for _, quick in pairs(ClientConsole.QuickButtons) do
		Util.Track(quick.Button.MouseButton1Click:Connect(function()
			if ClientConsole.MessageBox then
				ClientConsole.MessageBox.Text = quick.Text
				ClientConsole.UpdateCounter()
				ClientConsole.MessageBox:CaptureFocus()
			end
		end), "Console.Quick")
	end

	Util.Track(ClientConsole.SendButton.MouseButton1Click:Connect(function()
		ClientConsole.Send()
	end), "Console.Send")

	Util.Track(ClientConsole.PreviewButton.MouseButton1Click:Connect(function()
		ClientConsole.Preview()
	end), "Console.Preview")

	Util.Track(ClientConsole.ClearFieldsButton.MouseButton1Click:Connect(function()
		if ClientConsole.MessageBox then
			ClientConsole.MessageBox.Text = ""
		end
		if ClientConsole.TitleBox then
			ClientConsole.TitleBox.Text = ""
		end
		ClientConsole.UpdateCounter()
		ClientConsole.SetStatus("fields cleared", CONSOLE_COLORS.TextDim)
	end), "Console.ClearFields")

	if ClientConsole.MessageBox then
		Util.Track(ClientConsole.MessageBox:GetPropertyChangedSignal("Text"):Connect(function()
			ClientConsole.UpdateCounter()
		end), "Console.Counter")

		Util.Track(ClientConsole.MessageBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				ClientConsole.Send()
			end
		end), "Console.MessageEnter")
	end
end

function ClientConsole.WirePresetsPage()
	for name, entry in pairs(ClientConsole.PresetButtons or {}) do
		Util.Track(entry.Button.MouseButton1Click:Connect(function()
			Audio.Play("ConsoleClick")
			ClientConsole.RunCommandText(CONFIG.CommandPrefix .. "preset " .. name)
		end), "Console.Preset." .. name)
	end
end

function ClientConsole.WireHistoryPage()
	if ClientConsole.HistoryRefresh then
		Util.Track(ClientConsole.HistoryRefresh.MouseButton1Click:Connect(function()
			if AnnouncementPanel.Client and AnnouncementPanel.Client.Mode == "companion" then
				Net.FireServer("Sync", { Action = "RequestState" })
			end
			ClientConsole.RefreshHistory(ClientConsole.HistorySearch and ClientConsole.HistorySearch.Text)
		end), "Console.HistoryRefresh")
	end
	if ClientConsole.HistorySearch then
		Util.Track(ClientConsole.HistorySearch:GetPropertyChangedSignal("Text"):Connect(function()
			ClientConsole.RefreshHistory(ClientConsole.HistorySearch.Text)
		end), "Console.HistorySearch")
	end
end

function ClientConsole.WireToolsPage()
	for key, entry in pairs(ClientConsole.ToolButtons or {}) do
		Util.Track(entry.Button.MouseButton1Click:Connect(function()
			Audio.Play("ConsoleClick")
			ClientConsole.RunCommandText(entry.Command)
		end), "Console.Tool." .. key)
	end
	if ClientConsole.MOTDSend then
		Util.Track(ClientConsole.MOTDSend.MouseButton1Click:Connect(function()
			local text = Util.Trim(ClientConsole.MOTDBox.Text)
			if text == "" then
				ClientConsole.SetStatus("MOTD is empty", CONSOLE_COLORS.Danger)
				return
			end
			ClientConsole.RunCommandText(CONFIG.CommandPrefix .. 'motd "' .. text .. '" --now')
		end), "Console.MOTDSend")
	end
	if ClientConsole.MOTDClear then
		Util.Track(ClientConsole.MOTDClear.MouseButton1Click:Connect(function()
			ClientConsole.RunCommandText(CONFIG.CommandPrefix .. "motd --clear")
			ClientConsole.MOTDBox.Text = ""
		end), "Console.MOTDClear")
	end
end

function ClientConsole.WireSimulatorPage()
	if ClientConsole.ChaosButton then
		Util.Track(ClientConsole.ChaosButton.MouseButton1Click:Connect(function()
			local active = Chaos.IsActive()
			Audio.Play("ConsoleClick")
			if active then
				ClientConsole.RunCommandText(CONFIG.CommandPrefix .. "chaos off")
			else
				ClientConsole.RunCommandText(CONFIG.CommandPrefix .. "chaos on " .. tostring(math.floor(ClientConsole.ChaosDuration or 45)))
			end
			task.wait(0.2)
			ClientConsole.RefreshChaosStatus()
		end), "Console.ChaosToggle")
	end

	if ClientConsole.ChaosMinus then
		Util.Track(ClientConsole.ChaosMinus.MouseButton1Click:Connect(function()
			ClientConsole.ChaosDuration = Util.Clamp((ClientConsole.ChaosDuration or 45) - 10, 10, CONFIG.Chaos.MaxDurationSeconds)
			ClientConsole.RefreshChaosStatus()
		end), "Console.ChaosMinus")
	end

	if ClientConsole.ChaosPlus then
		Util.Track(ClientConsole.ChaosPlus.MouseButton1Click:Connect(function()
			ClientConsole.ChaosDuration = Util.Clamp((ClientConsole.ChaosDuration or 45) + 10, 10, CONFIG.Chaos.MaxDurationSeconds)
			ClientConsole.RefreshChaosStatus()
		end), "Console.ChaosPlus")
	end

	for key, entry in pairs(ClientConsole.SimButtons or {}) do
		Util.Track(entry.Button.MouseButton1Click:Connect(function()
			Audio.Play("ConsoleClick")
			ClientConsole.FireSimulation(entry.Definition)
		end), "Console.Sim." .. key)
	end
end

-- One-shot fake announcements. In companion mode these still go through the
-- server (so everyone sees them); in solo mode they render locally.
function ClientConsole.FireSimulation(definition)
	if type(definition) ~= "table" then
		return false
	end

	if definition.Kind == "Burst" then
		Util.Spawn(function()
			for _ = 1, 5 do
				ClientConsole.FireSimulation({
					Kind = Util.RandomFromList({ "Banner", "Toast", "Ticker" }),
					Rank = Util.RandomFromList(CONFIG.Chaos.FakeRanks, "Owner"),
				})
				task.wait(0.45)
			end
		end, "Console.SimBurst")
		return true
	end

	if definition.Kind == "Countdown" then
		ClientConsole.RunCommandText(CONFIG.CommandPrefix .. "countdown 10 \"Simulated countdown\"")
		return true
	end

	local line = Chaos.PickLine()
	local senderName = Util.RandomFromList(CONFIG.Chaos.FakeOwnerNames, "Owner")
	local style = Util.RandomFromList(Theme.StyleNames(), "Gold")

	local payload = {
		Kind = definition.Kind or "Banner",
		Message = line,
		Title = definition.Kind == "Alert" and "SIMULATED ALERT" or nil,
		Style = style,
		Duration = Util.RandomBetween(4, 8),
		Rank = definition.Rank or "Owner",
		SenderName = senderName,
		Target = "all",
		Effects = { Flash = true, Shake = false, Confetti = math.random() < 0.4 },
	}

	if AnnouncementPanel.Client and AnnouncementPanel.Client.Mode == "companion" and Net.IsServerActive() then
		-- Send it as a real command so permissions still apply.
		local text = CommandParser.BuildText({
			Kind = payload.Kind,
			Message = payload.Message,
			Title = payload.Title,
			Style = payload.Style,
			Duration = math.floor(tonumber(payload.Duration) or 6),
		})
		return ClientConsole.RunCommandText(text)
	end

	Broadcaster.Broadcast(payload, { Source = "simulator", SkipCooldown = true })
	return true
end

--// ---------- open / close ---------------------------------------------------

function ClientConsole.Open()
	if ClientConsole.Gui == nil then
		ClientConsole.Build()
	end
	if ClientConsole.Gui == nil then
		return false
	end
	if ClientConsole.Open_ then
		return true
	end
	ClientConsole.Open_ = true
	ClientConsole.Minimized = false
	ClientConsole.Gui.Enabled = true
	ClientConsole.Body.Visible = true
	ClientConsole.TabBar.Visible = true

	ClientConsole.Window.Size = UDim2.new(0, 0, 0, 0)
	ClientConsole.Window.Position = UDim2.fromScale(0.5, 0.56)
	Util.Tween(ClientConsole.Window, 0.26, {
		Size = CONFIG.Console.Size,
		Position = UDim2.fromScale(0.5, 0.5),
	}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if ClientConsole.Blur then
		ClientConsole.Blur.Enabled = true
		Util.Tween(ClientConsole.Blur, 0.3, { Size = 14 })
	end

	Audio.Play("ConsoleOpen")
	ClientConsole.RefreshState()
	ClientConsole.RefreshHistory()
	ClientConsole.OnOpenChanged:Fire(true)
	return true
end

function ClientConsole.Close()
	if ClientConsole.Gui == nil or not ClientConsole.Open_ then
		return false
	end
	ClientConsole.Open_ = false
	Util.Tween(ClientConsole.Window, 0.2, {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromScale(0.5, 0.46),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if ClientConsole.Blur then
		Util.Tween(ClientConsole.Blur, 0.25, { Size = 0 })
		Util.Delay(0.3, function()
			if ClientConsole.Blur then
				ClientConsole.Blur.Enabled = false
			end
		end)
	end
	Util.Delay(0.24, function()
		if not ClientConsole.Open_ and ClientConsole.Gui then
			ClientConsole.Gui.Enabled = false
		end
	end)
	Audio.Play("ConsoleClose")
	ClientConsole.OnOpenChanged:Fire(false)
	return true
end

function ClientConsole.Toggle(force)
	local shouldOpen = force
	if shouldOpen == nil then
		shouldOpen = not ClientConsole.Open_
	end
	if shouldOpen then
		return ClientConsole.Open()
	end
	return ClientConsole.Close()
end

function ClientConsole.IsOpen()
	return ClientConsole.Open_ == true
end

AnnouncementPanel.ClientConsole = ClientConsole

--// ==========================================================================
--// SECTION 26  ::  CLIENT CORE
--// Runs when this file is a LocalScript (StarterPlayerScripts).
--//   * COMPANION mode: the server half exists. The client owns the console,
--//     the keybinds, camera shake and local sounds; the server owns the GUI.
--//   * SOLO mode: no server half. The client builds the whole display itself
--//     and everything renders locally (perfect for testing and for videos).
--// ==========================================================================

local Client = {}

Client.Started = false
Client.Mode = "unknown" -- "companion" | "solo"
Client.LocalPlayer = nil
Client.ServerRoot = nil
Client.KeybindBound = false
Client.DemoRunning = false
Client.LastSyncAt = 0
Client.FloatingButton = nil

function Client.LogLine(text, kind)
	ClientConsole.LogLine(text, kind)
end

function Client.ToggleConsole(force)
	if not CONFIG.Console.Enabled then
		return false
	end
	return ClientConsole.Toggle(force)
end

-- Uses the real topbar inset so banners never hide behind Roblox's own UI.
function Client.ApplyTopbarInset(root)
	if root == nil or root.TopStack == nil or GuiService == nil then
		return false
	end
	local ok, inset = pcall(function()
		local _insetX, insetY = GuiService:GetGuiInset()
		return insetY or 0
	end)
	if not ok or type(inset) ~= "number" then
		return false
	end
	local offset = math.max(0, inset)
	root.TopStack.Position = UDim2.new(0.5, 0, 0, offset + 4)
	if root.Ticker and root.Ticker.Bar then
		root.Ticker.Bar.Size = UDim2.new(1, 0, 0, 30)
	end
	return true
end

-- In companion mode we polish the server-built GUI: responsive scaling and
-- correct topbar spacing, which the server cannot know about.
function Client.EnhanceServerRoot()
	local root = Renderer.FindServerRoot()
	if root == nil then
		return nil
	end
	Client.ServerRoot = root
	Renderer.HookResponsive(root)
	Client.ApplyTopbarInset(root)

	-- Keep re-applying if the server rebuilds the GUI (respawn, reload).
	if Players.LocalPlayer then
		Util.Spawn(function()
			local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 20)
			if playerGui == nil then
				return
			end
			Util.Track(playerGui.ChildAdded:Connect(function(child)
				if child.Name == UIBuilder.ROOT_NAME and child:IsA("ScreenGui") then
					task.wait(0.4)
					local fresh = Renderer.FindServerRoot()
					if fresh then
						Client.ServerRoot = fresh
						Renderer.HookResponsive(fresh)
						Client.ApplyTopbarInset(fresh)
						Util.Debug("re-enhanced a freshly built server panel")
					end
				end
			end), "Client.ServerRootWatch")
		end, "Client.EnhanceWatch")
	end

	return root
end

function Client.ActiveRoot()
	if Client.Mode == "companion" then
		return Client.ServerRoot or Renderer.GetRoot()
	end
	return Renderer.GetRoot()
end

--// ---------- networking ----------------------------------------------------

function Client.HandleAnnouncement(action, payload)
	if CONFIG.Debug.PrintNetwork then
		Util.Debug("announcement event:", action)
	end

	if action == "Polish" then
		-- The server already rendered the banner; we only add what a server
		-- cannot do: real camera shake and a local sound.
		if type(payload) == "table" and payload.Effects and payload.Effects.Shake then
			Effects.ShakeCamera(FX.CameraShakeIntensity)
		end
		if type(payload) == "table" and payload.SoundName then
			Audio.PlayLocal(payload.SoundName, { Volume = CONFIG.Sounds.Volume })
		end
		return
	end

	if action == "Effect" then
		local root = Client.ActiveRoot()
		Effects.Apply(root, payload or {}, "client")
		if type(payload) == "table" and payload.Effects and payload.Effects.Shake then
			Effects.ShakeCamera((payload.Intensity or FX.CameraShakeIntensity))
		end
		return
	end

	if action == "Clear" then
		if Client.Mode == "solo" then
			Renderer.KillAllFor(nil)
		end
		ClientConsole.SetStatus("screens cleared by server", CONSOLE_COLORS.TextDim)
		return
	end

	if action == "OpenConsole" then
		Client.ToggleConsole(true)
		return
	end

	if action == "Render" and Client.Mode == "solo" then
		-- Only used in solo mode / by other client scripts.
		Renderer.Render(nil, payload)
		return
	end
end

function Client.HandleAck(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Action == "State" then
		ClientConsole.ApplyStatePacket(payload)
		Client.LastSyncAt = os.clock()
		return
	end
	if payload.Action == "Pong" then
		local latency = payload.Time and Util.Round((os.clock() - payload.Time) * 1000, 1) or nil
		ClientConsole.SetStatus("server pong" .. (latency and (" (" .. latency .. "ms script time)") or ""), CONSOLE_COLORS.Success)
		return
	end
	if payload.Action == "Welcome" then
		ClientConsole.SetStatus(tostring(payload.Text or "connected"), CONSOLE_COLORS.Success)
		ClientConsole.LogLine(tostring(payload.Text or "connected"), "success")
		return
	end
	if payload.Action == "SystemChat" then
		ChatBridge.SystemMessageToPlayer(Players.LocalPlayer, tostring(payload.Text or ""),
			Util.ColorFromName(payload.Color, Color3.fromRGB(255, 220, 120)))
		return
	end
end

function Client.HookRemotes()
	if Net.Announcement then
		Util.Track(Net.Announcement.OnClientEvent:Connect(function(action, payload)
			local ok, err = pcall(function()
				Client.HandleAnnouncement(action, payload)
			end)
			if not ok then
				Util.Warn("announcement handler failed:", err)
			end
		end), "Client.Announcement")
	end
	if Net.Ack then
		Util.Track(Net.Ack.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(function()
				Client.HandleAck(payload)
			end)
			if not ok then
				Util.Warn("ack handler failed:", err)
			end
		end), "Client.Ack")
	end
end

function Client.Sync()
	if Net.IsServerActive() and Net.Handshake then
		Net.SendHandshake({ Action = "RequestState", Version = CONFIG.Version })
		Client.LastSyncAt = os.clock()
		return true
	end
	return false
end

--// ---------- floating button -----------------------------------------------

function Client.BuildFloatingButton()
	if not CONFIG.Console.ShowFloatingButton then
		return nil
	end
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end

	local gui = Util.New("ScreenGui", {
		Name = "AP_FloatingButton",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 380,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local button = Util.New("TextButton", {
		Name = "Button",
		AnchorPoint = Vector2.new(1, 1),
		Position = CONFIG.Console.FloatingButtonPosition,
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.fromRGB(28, 28, 38),
		Text = "\u{1F4E3}",
		TextSize = 22,
		AutoButtonColor = true,
		ZIndex = 40,
		Parent = gui,
	})
	UIBuilder.Corner(26, button)
	local stroke = UIBuilder.Stroke(Color3.fromRGB(255, 196, 61), 2, 0.1, button)

	local label = UIBuilder.Label({
		Name = "Label",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, 4),
		Size = UDim2.fromOffset(90, 14),
		Text = CONFIG.ShortName .. " console",
		TextSize = 10,
		TextColor3 = Color3.fromRGB(210, 210, 225),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.25,
		ZIndex = 40,
		Parent = button,
	})

	Util.Track(button.MouseButton1Click:Connect(function()
		Audio.Play("ConsoleClick")
		Client.ToggleConsole()
	end), "Client.FloatingButton")

	Util.Track(button.MouseEnter:Connect(function()
		Util.Tween(button, 0.15, { Size = UDim2.fromOffset(56, 56) })
		Util.Tween(stroke, 0.15, { Transparency = 0 })
	end), "Client.FloatingButtonEnter")

	Util.Track(button.MouseLeave:Connect(function()
		Util.Tween(button, 0.15, { Size = UDim2.fromOffset(52, 52) })
		Util.Tween(stroke, 0.15, { Transparency = 0.1 })
	end), "Client.FloatingButtonLeave")

	Client.FloatingButton = { Gui = gui, Button = button, Stroke = stroke, Label = label }
	return Client.FloatingButton
end

function Client.UpdateFloatingButton()
	local floating = Client.FloatingButton
	if floating == nil then
		return
	end
	local isStaff = RankSystem.IsStaff(Players.LocalPlayer)
	local shouldShow = isStaff or Client.Mode == "solo"
	floating.Gui.Enabled = shouldShow
	if shouldShow then
		local meta = Theme.GetRank(RankSystem.GetRank(Players.LocalPlayer))
		floating.Stroke.Color = meta.Color or Color3.fromRGB(255, 196, 61)
		floating.Button.Text = meta.Badge ~= "" and meta.Badge or "\u{1F4E3}"
	end
end

--// ---------- input ---------------------------------------------------------

function Client.BindKeybinds()
	if Client.KeybindBound then
		return false
	end
	if ContextActionService == nil and UserInputService == nil then
		return false
	end

	local function toggleAction()
		Client.ToggleConsole()
	end

	if ContextActionService then
		local ok = pcall(function()
			ContextActionService:BindActionAtPriority(
				"AP_ToggleConsole",
				function(_, state, input)
					if state == Enum.UserInputState.Begin then
						toggleAction()
						return Enum.ContextActionResult.Sink
					end
					return Enum.ContextActionResult.Pass
				end,
				false,
				Enum.ContextActionPriority.High.Value,
				CONFIG.Console.ToggleKeyCode
			)
		end)
		if ok then
			Client.KeybindBound = true
			Util.Debug("bound console key via ContextActionService")
		end
	end

	-- Fallback / secondary key + Escape handling through UserInputService.
	if UserInputService then
		Util.Track(UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			if input.KeyCode == CONFIG.Console.SecondaryToggleKey then
				toggleAction()
			elseif input.KeyCode == Enum.KeyCode.Escape and ClientConsole.IsOpen() and CONFIG.Console.CloseOnEscape then
				ClientConsole.Close()
			elseif not Client.KeybindBound and input.KeyCode == CONFIG.Console.ToggleKeyCode then
				toggleAction()
			end
		end), "Client.InputBegan")

		-- Mobile: also allow a two-finger tap anywhere to open the console.
		Util.Track(UserInputService.TouchTapInWorld:Connect(function(position, processed)
			if processed or not CONFIG.Console.ShowFloatingButton then
				return
			end
			if UserInputService.TouchEnabled and ClientConsole.IsOpen() == false and Client.FloatingButton == nil then
				Client.ToggleConsole(true)
			end
		end), "Client.TouchTap")
	end

	Client.KeybindBound = true
	return true
end

--// ---------- solo mode -----------------------------------------------------

function Client.StartSoloDemo()
	if Client.DemoRunning or not CONFIG.Solo.Enabled then
		return false
	end
	Client.DemoRunning = true
	Util.Spawn(function()
		task.wait(CONFIG.Solo.DemoDelay or 5)
		local interval = CONFIG.Solo.DemoInterval or 6
		while Client.DemoRunning do
			local kind = Util.RandomFromList({ "Banner", "Banner", "Toast", "Alert", "Ticker" })
			local line = Chaos.PickLine()
			local sender = Util.RandomFromList(CONFIG.Chaos.FakeOwnerNames, "You")
			Broadcaster.Broadcast({
				Kind = kind,
				Message = line,
				Title = kind == "Alert" and "OWNER ALERT" or nil,
				Style = Util.RandomFromList(Theme.StyleNames(), "Gold"),
				Duration = Util.RandomBetween(4, 8),
				Rank = Util.RandomFromList(CONFIG.Chaos.FakeRanks, "Owner"),
				SenderName = sender,
				Effects = { Flash = math.random() < 0.4, Confetti = math.random() < 0.3 },
			}, { Source = "demo", SkipCooldown = true })
			task.wait(interval)
		end
	end, "Client.SoloDemo")
	return true
end

function Client.StopSoloDemo()
	Client.DemoRunning = false
	return true
end

--// ---------- start ---------------------------------------------------------

function Client.Start()
	if Client.Started then
		return false
	end
	Client.Started = true

	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	end
	Client.LocalPlayer = localPlayer

	local playerGui = localPlayer:WaitForChild("PlayerGui", 30)
	if playerGui == nil then
		Util.Warn("PlayerGui never arrived; client core cannot start")
		return false
	end

	-- 1. Is the server half installed?
	local serverActive = Net.SetupClient(CONFIG.Solo.WaitForServerSeconds)
	Client.Mode = serverActive and "companion" or "solo"
	State.Mode = Client.Mode
	Util.Info("client core starting in", Client.Mode, "mode")

	-- 2. Build the right roots.
	if Client.Mode == "companion" then
		Client.EnhanceServerRoot()
		Client.HookRemotes()
		Client.Sync()
	else
		Renderer.InstallLocal({ Role = "client" })
		Client.ApplyTopbarInset(Renderer.GetRoot())
		if CONFIG.Solo.AutoDemo then
			Client.StartSoloDemo()
		end
		ClientConsole.LogLine("No server half found - running in SOLO mode (local only).", "warn")
	end

	-- 3. Console + input.
	RankSystem.GetRank(localPlayer, true)
	ClientConsole.Build()
	ClientConsole.RefreshState()
	Client.BindKeybinds()
	Client.BuildFloatingButton()
	Client.UpdateFloatingButton()

	if CONFIG.Console.OpenOnStart then
		ClientConsole.Open()
	end

	-- 4. Keep the rank badge honest: the server writes AP_Rank onto the player.
	Util.Track(localPlayer:GetAttributeChangedSignal(CONFIG.Net.RankAttribute):Connect(function()
		local value = localPlayer:GetAttribute(CONFIG.Net.RankAttribute)
		if type(value) == "string" and value ~= "" then
			RankSystem.Cache[localPlayer.UserId] = {
				Rank = Theme.GetRankName(value),
				At = os.clock(),
				Source = "server-attribute",
			}
			ClientConsole.RefreshState()
			Client.UpdateFloatingButton()
			Util.Debug("rank updated by server:", value)
		end
	end), "Client.RankAttribute")

	-- 5. Periodic re-sync so the console never drifts from the server.
	Util.Spawn(function()
		while true do
			task.wait(30)
			if Client.Mode == "companion" then
				Client.Sync()
			end
			Client.UpdateFloatingButton()
		end
	end, "Client.SyncLoop")

	-- 6. Character respawn: make sure the local root survives (ResetOnSpawn is
	--    false, but Studio "Stop/Play" cycles can leave orphans behind).
	Util.Track(localPlayer.CharacterAdded:Connect(function()
		task.wait(1)
		if Client.Mode == "solo" and (Renderer.LocalRoot == nil or Renderer.LocalRoot.Gui.Parent == nil) then
			Renderer.InstallLocal({ Role = "client" })
			Client.ApplyTopbarInset(Renderer.GetRoot())
		end
		if Client.Mode == "companion" then
			Client.EnhanceServerRoot()
		end
		Client.UpdateFloatingButton()
	end), "Client.CharacterAdded")

	Util.Info("client core ready -", Client.Mode, "mode, rank", RankSystem.GetRank(localPlayer))
	return true
end

AnnouncementPanel.Client = Client

--// ==========================================================================
--// SECTION 27  ::  BOOTSTRAP
--// ==========================================================================

local Bootstrap = {}

Bootstrap.BANNER = {
	"================================================================",
	"   _    _   _  _  ___  ___  ___  _  _ _____ ___ ___  _   _    ",
	"  /\\  | | | || \\| |/ _ \\|   \\| __|| \\| |_   _| __/ _ \\| \\ | |   ",
	" /  \\ | |_| || .` | (_) | |) | _| | .` | | | | _| (_) |  \\| |   ",
	"/_/\\_\\ \\___/ |_|\\_|\\___/|___/|___||_|\\_| |_| |___\\___/|_|\\_|   ",
	"                                                                ",
	"   ANNOUNCEMENT PANEL  ::  v" .. CONFIG.Version .. "  ::  all-in-one",
	"================================================================",
}

function Bootstrap.PrintBanner()
	if not CONFIG.Debug.BannerOnBoot then
		return
	end
	for _, line in ipairs(Bootstrap.BANNER) do
		print(line)
	end
	local side = IS_SERVER and "SERVER" or "CLIENT"
	print(string.format(">> %s side starting | Studio=%s | PlaceId=%s | JobId=%s",
		side, tostring(IS_STUDIO), tostring(game.PlaceId), tostring(Util.ShortId(6))))
end

function Bootstrap.ValidateConfig()
	local problems = {}

	if type(CONFIG.CommandPrefix) ~= "string" or CONFIG.CommandPrefix == "" then
		table.insert(problems, "CONFIG.CommandPrefix must be a non-empty string")
	end
	if type(CONFIG.Ranks) ~= "table" or CONFIG.Ranks.Owner == nil then
		table.insert(problems, "CONFIG.Ranks.Owner is missing")
	end
	if type(CONFIG.StYLES) ~= "nil" then
		-- CONFIG.Styles is the real name; catch a common typo.
		table.insert(problems, "CONFIG.STYLES is not a real field (did you mean CONFIG.Styles?)")
	end
	if LIMITS.DefaultDuration > LIMITS.MaxDuration then
		table.insert(problems, "CONFIG.Limits.DefaultDuration is larger than MaxDuration")
	end
	if LIMITS.MinDuration > LIMITS.DefaultDuration then
		table.insert(problems, "CONFIG.Limits.MinDuration is larger than DefaultDuration")
	end
	if APPEAR.BannerWidth < 200 then
		table.insert(problems, "CONFIG.Appearance.BannerWidth looks too small")
	end
	if CONFIG.Chaos.IntervalMin > CONFIG.Chaos.IntervalMax then
		table.insert(problems, "CONFIG.Chaos.IntervalMin is larger than IntervalMax")
	end

	-- Every permission referenced by a rank should exist as a command or "*".
	local knownCommands = {}
	for _, name in ipairs(Commands.Names()) do
		knownCommands[name] = true
	end
	for rankName, meta in pairs(RANKS) do
		for _, permission in ipairs(meta.Permissions or {}) do
			if permission ~= "*" and not knownCommands[permission] then
				table.insert(problems, string.format("rank %s lists unknown permission '%s'", rankName, permission))
			end
		end
		if meta.Order == nil then
			table.insert(problems, "rank " .. rankName .. " has no Order")
		end
	end

	-- Presets must reference styles that exist.
	for presetName, preset in pairs(CONFIG.Presets) do
		if preset.Style and CONFIG.Styles[preset.Style] == nil then
			table.insert(problems, "preset '" .. presetName .. "' uses unknown style '" .. tostring(preset.Style) .. "'")
		end
	end

	if #problems > 0 then
		Util.Warn("config validation found " .. #problems .. " problem(s):")
		for _, problem in ipairs(problems) do
			Util.Warn("  - " .. problem)
		end
	else
		Util.Debug("config validation passed")
	end

	return problems
end

function Bootstrap.SeedRandom()
	local seed = 0
	pcall(function()
		seed += game.JobId and #game.JobId or 0
		seed += game.PlaceId or 0
		seed += os.time()
	end)
	seed += math.floor(os.clock() * 1000)
	local ok = pcall(function()
		math.randomseed(seed)
	end)
	if not ok then
		math.randomseed(os.time())
	end
end

function Bootstrap.ReportStaffConfig()
	local configured = 0
	for _, listName in ipairs({ "Owners", "Admins", "Mods", "Helpers", "VIPs" }) do
		local list = CONFIG[listName]
		if type(list) == "table" then
			configured += #(list.UserIds or {}) + #(list.Usernames or {}) + #(list.GroupRanks or {})
		end
	end
	if configured == 0 and not CONFIG.RankRules.GameOwnerIsOwner and not CONFIG.RankRules.StudioEveryoneIsOwner then
		Util.Warn("no staff configured! Add UserIds to CONFIG.Owners so commands are not locked out.")
	elseif configured == 0 then
		Util.Info("staff list is empty - relying on game owner / Studio rules for rank resolution")
	else
		Util.Info("staff entries configured:", configured)
	end
	return configured
end

function Bootstrap.Start()
	Bootstrap.SeedRandom()
	Bootstrap.PrintBanner()
	Bootstrap.ValidateConfig()
	Bootstrap.ReportStaffConfig()

	if IS_EDIT then
		Util.Info("running in edit mode (not playing) - the panel will start when you press Play")
	end

	if IS_SERVER then
		local ok, err = pcall(function()
			ServerCore.Start()
		end)
		if not ok then
			Util.Error("server core failed to start:", err)
			State.Bump("Errors")
			return false
		end
		-- Expose the API so other server scripts can use it:
		--   shared.AnnouncementPanel.Broadcaster.Announce("Hello")
		pcall(function()
			shared.AnnouncementPanel = AnnouncementPanel
		end)
		Util.Info("server core started")
		return true
	end

	if IS_CLIENT then
		-- Wait for the LocalPlayer before doing anything.
		local localPlayer = Players.LocalPlayer
		if localPlayer == nil then
			Util.Debug("waiting for LocalPlayer")
			local connection
			connection = Players:GetPropertyChangedSignal("LocalPlayer"):Connect(function()
				if Players.LocalPlayer and connection then
					connection:Disconnect()
				end
			end)
			while Players.LocalPlayer == nil do
				task.wait(0.1)
			end
			if connection then
				connection:Disconnect()
			end
		end

		local ok, err = pcall(function()
			Client.Start()
		end)
		if not ok then
			Util.Error("client core failed to start:", err)
			State.Bump("Errors")
			return false
		end
		Util.Info("client core started")
		return true
	end

	Util.Warn("neither server nor client context detected - nothing to do")
	return false
end

-- Expose a tiny public API surface for other scripts that require/call this.
AnnouncementPanel.CONFIG = CONFIG
AnnouncementPanel.IS_SERVER = IS_SERVER
AnnouncementPanel.IS_CLIENT = IS_CLIENT
AnnouncementPanel.IS_STUDIO = IS_STUDIO

function AnnouncementPanel.Announce(message, options)
	return Broadcaster.Announce(message, options)
end

function AnnouncementPanel.Alert(message, options)
	return Broadcaster.Alert(message, options)
end

function AnnouncementPanel.Toast(message, options)
	return Broadcaster.Toast(message, options)
end

function AnnouncementPanel.Ticker(message, options)
	return Broadcaster.Ticker(message, options)
end

function AnnouncementPanel.Countdown(seconds, label, options)
	return Broadcaster.Countdown(seconds, label, options)
end

function AnnouncementPanel.GetRank(player)
	return RankSystem.GetRank(player)
end

function AnnouncementPanel.SetRank(player, rankName)
	return RankSystem.SetSessionRank(player, rankName)
end

function AnnouncementPanel.Clear()
	return Renderer.KillAll()
end

function AnnouncementPanel.StartChaos(player, seconds)
	return Chaos.Start(player, seconds)
end

function AnnouncementPanel.StopChaos(player)
	return Chaos.Stop(player)
end

function AnnouncementPanel.GetState()
	return {
		Mode = State.Mode,
		Uptime = State.Uptime(),
		Stats = Util.DeepCopy(State.Stats),
		Active = State.ActiveCount(),
		Chaos = Chaos.Status(),
		History = History.ToPayloadList(10),
	}
end

function AnnouncementPanel.Shutdown()
	Util.Info("shutting down")
	if State.Chaos.Active then
		Chaos.Stop(nil)
	end
	Scheduler.Stop()
	Renderer.KillAll()
	if IS_SERVER then
		for _, player in ipairs(Players:GetPlayers()) do
			Renderer.UninstallForPlayer(player)
		end
		Effects.CleanupLighting()
		Persistence.Save()
	else
		Client.StopSoloDemo()
		if ClientConsole.Gui then
			Util.Destroy(ClientConsole.Gui)
		end
		if ClientConsole.Blur then
			Util.Destroy(ClientConsole.Blur)
		end
		if Client.FloatingButton then
			Util.Destroy(Client.FloatingButton.Gui)
		end
		if ContextActionService then
			pcall(function()
				ContextActionService:UnbindAction("AP_ToggleConsole")
			end)
		end
	end
	Audio.UnloadPreloaded()
	Util.Cleanup()
	return true
end

AnnouncementPanel.Bootstrap = Bootstrap

--// ==========================================================================
--// GO
--// ==========================================================================

local bootOk, bootErr = pcall(function()
	return Bootstrap.Start()
end)

if not bootOk then
	warn("[" .. SYSTEM_TAG .. "] fatal boot error:", bootErr)
end

-- Returning the namespace means this file also works as a ModuleScript:
--   local AP = require(script.AnnouncementPanel)
--   AP.Announce("Hello from another script!")
return AnnouncementPanel
