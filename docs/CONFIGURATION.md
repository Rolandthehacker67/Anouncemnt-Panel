# Configuration reference

Everything you can change lives in **one `CONFIG` table at the top of `AnnouncementPanel.luau`**
(roughly lines 150-860). You never need to read the other 11,500 lines to configure the panel.

```lua
local AnnouncementPanel = {}
AnnouncementPanel.Version = "2.1.0"

local CONFIG = {}

CONFIG.SystemName = "Announcement Panel"
CONFIG.ShortName = "AP"
CONFIG.CommandPrefix = ":"            -- staff commands start with this
CONFIG.WhisperPrefix = "."            -- ".announce" = staff only
CONFIG.DefaultStyle = "Default"
```

> Both halves read the same table. If you install the file as a `Script` **and** a `LocalScript`,
> edit the config in **both** copies (or keep one copy and `require` it — see the README).

## Contents

- [`CONFIG.ServerInfo`](#configserverinfo)
- [`CONFIG.Ranks`](#configranks)
- [`CONFIG.Owners`](#configowners)
- [`CONFIG.Admins`](#configadmins)
- [`CONFIG.Mods`](#configmods)
- [`CONFIG.Helpers`](#confighelpers)
- [`CONFIG.VIPs`](#configvips)
- [`CONFIG.RankRules`](#configrankrules)
- [`CONFIG.Limits`](#configlimits)
- [`CONFIG.Appearance`](#configappearance)
- [`CONFIG.Animation`](#configanimation)
- [`CONFIG.Effects`](#configeffects)
- [`CONFIG.Sounds`](#configsounds)
- [`CONFIG.Styles`](#configstyles)
- [`CONFIG.Presets`](#configpresets)
- [`CONFIG.MOTD`](#configmotd)
- [`CONFIG.JoinMessages`](#configjoinmessages)
- [`CONFIG.LeaveMessages`](#configleavemessages)
- [`CONFIG.Schedule`](#configschedule)
- [`CONFIG.Chaos`](#configchaos)
- [`CONFIG.Console`](#configconsole)
- [`CONFIG.Solo`](#configsolo)
- [`CONFIG.Moderation`](#configmoderation)
- [`CONFIG.Persistence`](#configpersistence)
- [`CONFIG.Net`](#confignet)
- [`CONFIG.Debug`](#configdebug)
- [Recipes](#recipes)
- [Validating your changes](#validating-your-changes)

## `CONFIG.ServerInfo`

Identity and first-impression settings: what the watermark says, whether the server announces itself on boot, and whether join messages fire.

| Key | Default | What it does |
|---|---|---|
| `GameName` | `""` | leave blank to auto-detect from MarketplaceService |
| `FooterText` | `"Announcement Panel v" .. AnnouncementPanel.Version` | watermark text |
| `ShowFooterWatermark` | `true` | small credit line in the corner of the screen |
| `ShowJoinMessages` | `true` | legacy alias for `CONFIG.JoinMessages.Enabled` |
| `AnnounceServerStart` | `true` | broadcast once when the server boots |
| `ServerStartMessage` | `"This server is now live. Type :help if you are staff."` | text of that first announcement |

## `CONFIG.Ranks`

The six ranks, their order, colours, badges, permissions, maximum announcement duration and chaos rights. Ranks are resolved top-down by `Order`; a player keeps the highest they match.

| Key | Notes |
|---|---|
| `Owner` | `{` |
| `Admin` | `{` |
| `Mod` | `{` |
| `Helper` | `{` |
| `VIP` | `{` |
| `Player` | `{` |

## `CONFIG.Owners`

Who counts as an **Owner**. Every list is OR'd together, so a UserId in one list and a group rank in another both work.

| Key | Notes |
|---|---|
| `UserIds` | most reliable — survives name changes |
| `Usernames` | convenient, breaks when they rename |
| `GroupRanks` | `{ GroupId = 0, MinRank = 250, MaxRank = 255 }` |
| `Teams` | Roblox `Teams` names |
| `Gamepasses` | `{ [assetId] = true }` (VIPs) or `{ [assetId] = "Rank" }` |

## `CONFIG.Admins`

Who counts as an **Admin**. Same shape as `CONFIG.Owners`.

| Key | Notes |
|---|---|
| `UserIds` | most reliable — survives name changes |
| `Usernames` | convenient, breaks when they rename |
| `GroupRanks` | `{ GroupId = 0, MinRank = 250, MaxRank = 255 }` |
| `Teams` | Roblox `Teams` names |
| `Gamepasses` | `{ [assetId] = true }` (VIPs) or `{ [assetId] = "Rank" }` |

## `CONFIG.Mods`

Who counts as a **Mod**. Same shape as `CONFIG.Owners`.

| Key | Notes |
|---|---|
| `UserIds` | most reliable — survives name changes |
| `Usernames` | convenient, breaks when they rename |
| `GroupRanks` | `{ GroupId = 0, MinRank = 250, MaxRank = 255 }` |
| `Teams` | Roblox `Teams` names |
| `Gamepasses` | `{ [assetId] = true }` (VIPs) or `{ [assetId] = "Rank" }` |

## `CONFIG.Helpers`

Who counts as a **Helper**. Same shape as `CONFIG.Owners`.

| Key | Notes |
|---|---|
| `UserIds` | most reliable — survives name changes |
| `Usernames` | convenient, breaks when they rename |
| `GroupRanks` | `{ GroupId = 0, MinRank = 250, MaxRank = 255 }` |
| `Teams` | Roblox `Teams` names |
| `Gamepasses` | `{ [assetId] = true }` (VIPs) or `{ [assetId] = "Rank" }` |

## `CONFIG.VIPs`

Cosmetic-only rank: a chat tag and a coloured name, no commands. Wire it to a game pass to sell it.

| Key | Notes |
|---|---|
| `UserIds` | most reliable — survives name changes |
| `Usernames` | convenient, breaks when they rename |
| `GroupRanks` | `{ GroupId = 0, MinRank = 250, MaxRank = 255 }` |
| `Teams` | Roblox `Teams` names |
| `Gamepasses` | `{ [assetId] = true }` (VIPs) or `{ [assetId] = "Rank" }` |

## `CONFIG.RankRules`

How ranks are resolved, cached and overridden. **`StudioEveryoneIsOwner` is the one to turn off before shipping.**

| Key | Default | What it does |
|---|---|---|
| `GameOwnerIsOwner` | `true` | place owner always becomes Owner |
| `StudioEveryoneIsOwner` | `true` | in Studio every player is Owner (fast testing) |
| `AllowAttributeOverride` | `true` | player attribute "AP_Rank" wins over lists |
| `AttributeName` | `"AP_Rank"` | attribute used for the override and for server→client rank sync |
| `CacheForSeconds` | `20` | rank lookups (group/gamepass) are cached |
| `DenyListUserIds` | `{}` | these users are forced to Player rank |
| `DenyListUsernames` | `{}` | same, by username |

## `CONFIG.Limits`

Length caps, on-screen caps and cooldowns. These are the reason a command sometimes replies "Slow down" — they protect your game from spam and exploiters.

| Key | Default | What it does |
|---|---|---|
| `MaxMessageLength` | `280` | maximum characters in a message; longer text is truncated |
| `MaxTitleLength` | `48` | maximum characters in a `--title` |
| `MinDuration` | `2` | shortest allowed on-screen time (seconds) |
| `MaxDuration` | `600` | longest allowed on-screen time (seconds) |
| `DefaultDuration` | `9` | used when a command omits `-t` |
| `MaxVisibleBanners` | `3` | older banners collapse when exceeded |
| `MaxToastsOnScreen` | `4` | oldest toast is retired past this |
| `MaxHistoryEntries` | `40` | `:history` and the console keep this many entries |
| `CommandCooldown` | `1.2` | seconds between any two commands (per player) |
| `AnnounceCooldown` | `2.5` | seconds between announcements (per player) |
| `AlertCooldown` | `20` | full-screen alerts are rare on purpose |
| `ChaosCooldown` | `30` | seconds between `:chaos` uses |
| `MaxScheduledEvents` | `12` | cap on active `:schedule` timers |
| `MaxConcurrentEffects` | `8` | cap on simultaneous flashes / shakes / confetti |

## `CONFIG.Appearance`

Sizes, colours, fonts and scaling of the banners, toasts, alerts, ticker, countdown and MOTD.

| Key | Default | What it does |
|---|---|---|
| `TopbarOffset` | `58` | pixels reserved for the Roblox topbar |
| `BannerWidth` | `560` | pixels at scale 1 |
| `BannerMinWidth` | `300` | never shrink below this |
| `BannerHeight` | `76` | banner height at scale 1 |
| `BannerGap` | `8` | vertical gap between stacked banners |
| `BannerCornerRadius` | `14` | corner radius of every card |
| `BackgroundTransparency` | `0.08` | card backdrop transparency |
| `BorderThickness` | `2` | stroke thickness around cards |
| `GlowTransparency` | `0.55` | outer glow strength |
| `TextSize` | `17` | message text size |
| `TitleTextSize` | `15` | title text size |
| `RankTagTextSize` | `12` | rank tag text size |
| `FontFamily` | `"rbxasset://fonts/families/GothamSSm.json"` | Roblox font family asset |
| `FallbackFont` | `Enum.Font.GothamMedium` | used when the font family cannot load |
| `BoldFont` | `Enum.Font.GothamBold` | used for titles |
| `HeavyFont` | `Enum.Font.GothamBlack` | used for alerts and countdown digits |
| `BaseColor` | `Color3.fromRGB(18, 18, 24)` | banner backdrop |
| `BaseColor2` | `Color3.fromRGB(30, 30, 40)` | gradient partner |
| `BackdropDim` | `0.45` | alert overlay darkness |
| `ShadowOpacity` | `0.45` | drop shadow strength |
| `UseRichText` | `true` | allows `<b>` / `<i>` / `<font>` in your own text (player text is stripped) |
| `ScaleWithScreen` | `true` | scales the whole panel with the viewport |
| `MinUIScale` | `0.72` | smallest allowed scale |
| `MaxUIScale` | `1.25` | largest allowed scale |
| `ScaleReferenceWidth` | `1440` | viewport width that equals scale 1 |
| `RespectSafeArea` | `true` | keeps the UI inside the device safe area |

## `CONFIG.Animation`

Tween times, easing styles, ticker speed and whether the server-side install animates (it does, via replicated tweens).

| Key | Default | What it does |
|---|---|---|
| `BannerInTime` | `0.42` | slide-in duration |
| `BannerOutTime` | `0.32` | slide-out duration |
| `BannerInStyle` | `Enum.EasingStyle.Back` | easing style for the entrance |
| `BannerInDirection` | `Enum.EasingDirection.Out` | easing direction for the entrance |
| `BannerOutStyle` | `Enum.EasingStyle.Quad` | easing style for the exit |
| `BannerOutDirection` | `Enum.EasingDirection.In` | easing direction for the exit |
| `AlertInTime` | `0.3` | alert pop-in duration |
| `AlertOutTime` | `0.45` | alert fade-out duration |
| `ToastInTime` | `0.28` | toast slide-in duration |
| `PulseTime` | `1.1` | glow pulse period |
| `ProgressUpdateRate` | `0.05` | progress bar update interval (client side) |
| `TickerSpeed` | `190` | pixels per second |
| `TickerMinTime` | `9` | minimum time a ticker stays up |
| `ServerSideAnimations` | `true` | server install still animates (replicated) |
| `JitterFrames` | `14` | used by the server-side shake |

## `CONFIG.Effects`

Master switches and strengths for flash, shake, confetti, vignette and Lighting pulses.

| Key | Default | What it does |
|---|---|---|
| `EnableSound` | `true` | master switch for panel sounds |
| `EnableFlash` | `true` | allow screen flashes |
| `EnableShake` | `true` | allow camera and panel shake |
| `EnableConfetti` | `true` | allow confetti |
| `EnableVignette` | `true` | allow the vignette |
| `EnableLighting` | `true` | ColorCorrection / Blur pulses in Lighting |
| `FlashTime` | `0.32` | flash duration |
| `FlashColor` | `Color3.fromRGB(255, 255, 255)` | flash colour |
| `FlashMaxTransparency` | `0.62` | how opaque the flash gets |
| `ShakeIntensity` | `1.4` | panel shake strength |
| `ShakeTime` | `0.55` | shake duration |
| `CameraShakeIntensity` | `0.9` | client install only |
| `ConfettiPieces` | `46` | pieces per burst |
| `ConfettiLifetime` | `2.6` | how long a piece falls |
| `ConfettiColors` | *(table)* | nested values — see the file |
| `BlurAmount` | `10` | blur strength for `:blur` |
| `LightingPulseTime` | `0.9` | Lighting pulse duration |

## `CONFIG.Sounds`

Sound ids for each event. Empty by default — Roblox removed the free catalogue, so drop in your own `rbxassetid://` ids.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `true` | master switch |
| `Volume` | `0.6` | master volume for panel sounds |
| `Banner` | `""` | e.g. "rbxassetid://0000000000" |
| `Alert` | `""` | sound id for an alert |
| `Toast` | `""` | sound id for a toast |
| `Ticker` | `""` | sound id for a ticker |
| `Countdown` | `""` | tick sound id |
| `CountdownEnd` | `""` | sound id when a countdown finishes |
| `ConsoleOpen` | `""` | sound id when the console opens |
| `ConsoleClose` | `""` | sound id when the console closes |
| `ConsoleClick` | `""` | sound id for console clicks |
| `Chaos` | `""` | sound id while chaos runs |
| `Deny` | `""` | sound id when a command is rejected |
| `Join` | `""` | sound id for join messages |
| `Library` | `{}` | extra named sounds, usable with `--sound` |

## `CONFIG.Styles`

The 8 visual styles you can pass with `-s`. Each defines colours, gradient, stroke, glow, pulse and sound.

| Key | Notes |
|---|---|
| `Default` | `{` |
| `Gold` | `{` |
| `Fire` | `{` |
| `Ice` | `{` |
| `Neon` | `{` |
| `Shadow` | `{` |
| `Rainbow` | `{` |
| `Emergency` | `{` |

## `CONFIG.Presets`

One-shot bundles for `:preset <name>`, the console Presets tab, or `Broadcaster.Preset(name)`.

| Key | Notes |
|---|---|
| `restart` | `{` |
| `update` | `{` |
| `event` | `{` |
| `rules` | `{` |
| `welcome` | `{` |
| `doublexp` | `{` |
| `maintenance` | `{` |
| `giveaway` | `{` |
| `lag` | `{` |
| `shutdown` | `{` |

## `CONFIG.MOTD`

Message of the day: shown to each player a few seconds after they join, and editable at runtime with `:motd`.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `true` | master switch |
| `DelayAfterJoin` | `3` | seconds after joining before the MOTD appears |
| `Duration` | `16` | how long it stays on screen |
| `Title` | `"MESSAGE OF THE DAY"` | title line |
| `Message` | `"Welcome! Read the rules in the description. Staff can be reached with the report command."` | the text itself |
| `Style` | `"Ice"` | visual style name |
| `ShowOnEverySpawn` | `false` | re-show the MOTD on every respawn, not just on join |

## `CONFIG.JoinMessages`

Optional "X joined the server" broadcast. Off by default; can be limited to staff only.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `false` | master switch |
| `Style` | `"Toast"` | Banner | Toast | Ticker |
| `Duration` | `5` | how long it stays on screen |
| `Template` | `"{player} joined the server."` | text template — `{player}`, `{rank}`, `{badge}`, `{display}` |
| `StaffTemplate` | `"{badge} {rank} {player} joined the server."` | template used for staff members |
| `AnnounceStaffOnly` | `true` | only announce when a staff member joins |
| `AnnounceFirstPlayer` | `true` | also announce the very first player in an empty server |

## `CONFIG.LeaveMessages`

Optional "X left the server" broadcast. Off by default.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `false` | master switch |
| `Style` | `"Toast"` | visual style name |
| `Duration` | `4` | how long it stays on screen |
| `Template` | `"{player} left the server."` | text template — `{player}`, `{rank}`, `{badge}`, `{display}` |
| `StaffTemplate` | `"{badge} {rank} {player} left the server."` | template used for staff members |
| `AnnounceStaffOnly` | `true` | only announce when a staff member joins or leaves |

## `CONFIG.Schedule`

Declarative repeating announcements (interval or uptime milestones) that start automatically on boot, alongside the runtime `:schedule` command.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `true` | master switch |
| `TickRate` | `1` | how often the scheduler checks its timers, in seconds |
| `Items` | *(table)* | nested values — see the file |
| `FirstTickDelay` | `60` | don't greet people 1 second after they join |
| `UptimeAnnouncements` | *(table)* | nested values — see the file |

## `CONFIG.Chaos`

The admin-abuse show: fake owner names, dramatic lines, probabilities for each effect, and the auto-stop ceiling.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `true` | master switch |
| `MaxDurationSeconds` | `180` | auto-stops, nobody leaves it on forever |
| `DefaultDurationSeconds` | `45` | used by `:chaos on` with no number |
| `IntervalMin` | `2.2` | shortest gap between chaos messages |
| `IntervalMax` | `5.5` | longest gap between chaos messages |
| `FlashChance` | `0.5` | chance each chaos message also flashes |
| `ShakeChance` | `0.5` | chance each chaos message also shakes |
| `ConfettiChance` | `0.35` | chance each chaos message also confettis |
| `AlertChance` | `0.12` | chance a chaos message is a full-screen alert |
| `TickerChance` | `0.2` | chance a chaos message is a ticker |
| `FakeOwnerNames` | *(table)* | nested values — see the file |
| `FakeRanks` | `{ "Owner", "Admin", "Mod" }` | ranks chaos pretends those senders have |
| `Lines` | *(table)* | nested values — see the file |

## `CONFIG.Console`

The Owner Console GUI: keybinds, size, floating button, drag/resize, blur, quick messages and compose defaults.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `true` | master switch |
| `ToggleKeyCode` | `Enum.KeyCode.RightControl` | primary keybind for the console |
| `SecondaryToggleKey` | `Enum.KeyCode.F1` | second keybind |
| `ShowFloatingButton` | `true` | on-screen button for mobile / console players |
| `FloatingButtonPosition` | `UDim2.new(1, -78, 1, -78)` | where that button sits |
| `Size` | `UDim2.fromOffset(560, 420)` | console window size |
| `MinSize` | `UDim2.fromOffset(420, 320)` | smallest allowed resize |
| `OpenOnStart` | `false` | open the console automatically on join |
| `RememberPosition` | `true` | keep the dragged position between opens |
| `Draggable` | `true` | allow dragging by the title bar |
| `Resizable` | `true` | allow resizing by the corner grip |
| `BlurBehind` | `true` | blur the game behind the console |
| `CloseOnEscape` | `true` | Escape closes the console |
| `QuickMessages` | *(table)* | nested values — see the file |
| `DefaultStyle` | `"Gold"` | style preselected in the console |
| `DefaultDuration` | `9` | used when a command omits `-t` |

## `CONFIG.Solo`

What the client half does when no server half exists: how long to look, and whether to run the demo show automatically.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `true` | master switch |
| `WaitForServerSeconds` | `6` | how long to look for the server half |
| `AutoDemo` | `false` | fire the demo show automatically on join |
| `DemoDelay` | `5` | seconds before the demo starts |
| `DemoInterval` | `6` | seconds between demo messages |
| `SimulatedPlayers` | *(table)* | nested values — see the file |

## `CONFIG.Moderation`

Filtering, rich-text stripping, blocked words, logging of non-staff attempts and length rejection.

| Key | Default | What it does |
|---|---|---|
| `FilterBroadcastMessages` | `true` | TextService, never disable this |
| `FallbackCensor` | `true` | word list below, used if TextService fails |
| `StripRichText` | `true` | stop people injecting <font> tags |
| `MaxLengthBeforeReject` | `400` | reject the message outright past this length |
| `BlockedCommandsForNonStaff` | `true` | log attempts, don't run them |
| `LogNonStaffAttempts` | `true` | print those attempts to the server log |
| `LogAllCommands` | `true` | print every command to the server log |
| `WarnInChat` | `true` | reply in chat as well as in the console |
| `CensoredReplacement` | `"####"` | replaces blocked words |
| `BlockedWords` | *(table)* | nested values — see the file |

## `CONFIG.Persistence`

Optional DataStore saving of MOTD, schedules and stats. **Off by default** so nothing breaks before you enable API access.

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `false` | set true once your game has API access enabled |
| `DataStoreName` | `"AnnouncementPanel_v2"` | DataStore used for MOTD, schedules and stats |
| `KeyPrefix` | `"Global"` | key namespace inside that store |
| `AllowInStudio` | `false` | also save while testing in Studio |
| `SaveInterval` | `120` | seconds between auto-saves (minimum 30) |
| `SaveOnShutdown` | `true` | save again when the server closes |
| `SaveMOTD` | `true` | persist the MOTD |
| `SaveSchedule` | `true` | persist scheduled announcements |
| `SaveStats` | `true` | persist the counters |

## `CONFIG.Net`

Names of the RemoteEvent folder/events and the attributes the two halves use to find each other. Only change these if they clash with something.

| Key | Default | What it does |
|---|---|---|
| `FolderName` | `"AnnouncementPanelRemotes"` | ReplicatedStorage folder holding the RemoteEvents |
| `AnnouncementEvent` | `"Announcement"` | server → clients: render, effect, clear, open console |
| `ConsoleEvent` | `"ConsoleCommand"` | client → server: run this command |
| `HandshakeEvent` | `"Handshake"` | client → server: who am I, what is the state |
| `AckEvent` | `"Ack"` | server → client: state packet, pong, system chat |
| `RankAttribute` | `"AP_Rank"` | player attribute carrying the resolved rank |
| `RankNameAttribute` | `"AP_RankName"` | player attribute carrying the display name |
| `ServerActiveAttribute` | `"AP_ServerActive"` | folder attribute telling clients the server half is live |
| `RetryWait` | `0.5` | seconds between attempts to find the server half |
| `MaxRetries` | `12` | attempts before giving up |

## `CONFIG.Debug`

Console output verbosity, the ASCII boot banner, and `StrictMode` (turn internal warnings into errors while developing).

| Key | Default | What it does |
|---|---|---|
| `Enabled` | `false` | master switch |
| `PrintRankResolution` | `false` | log why each player got their rank |
| `PrintCommands` | `true` | log every command, who ran it and how long it took |
| `PrintNetwork` | `false` | log remote traffic |
| `PrintRender` | `false` | log every render call |
| `WarnOnMissingSound` | `true` | warn when a sound id is missing |
| `BannerOnBoot` | `true` | the ASCII banner in the output window |
| `StrictMode` | `false` | error() instead of warn() on internal failures |

## Recipes

**Change the command prefix** (if `:` clashes with your game):

```lua
CONFIG.CommandPrefix = ">"   -- now ">announce hello"
```

**Stop everyone being an Owner in Studio** (do this before shipping):

```lua
CONFIG.RankRules.StudioEveryoneIsOwner = false
CONFIG.Owners.UserIds = { 15645312 }   -- you
```

**Give a whole group staff ranks:**

```lua
CONFIG.Admins.GroupRanks = { { GroupId = 12345678, MinRank = 250, MaxRank = 255 } }
CONFIG.Mods.GroupRanks   = { { GroupId = 12345678, MinRank = 100, MaxRank = 249 } }
CONFIG.Helpers.GroupRanks= { { GroupId = 12345678, MinRank = 10,  MaxRank = 99  } }
```

**Sell a VIP tag with a game pass:**

```lua
CONFIG.VIPs.Gamepasses = { [123456789] = true }
```

**Add your own sounds:**

```lua
CONFIG.Sounds.Enabled = true
CONFIG.Sounds.Volume = 0.6
CONFIG.Sounds.Banner = "rbxassetid://0000000000"
CONFIG.Sounds.Alert  = "rbxassetid://0000000000"
```

**Recolour every banner** (edit a style instead of each command):

```lua
CONFIG.Styles.Gold.Primary = Color3.fromRGB(255, 200, 80)
CONFIG.Styles.Gold.Secondary = Color3.fromRGB(120, 70, 10)
```

**Mobile / small screens:**

```lua
CONFIG.Appearance.MinUIScale = 0.6
CONFIG.Appearance.BannerMinWidth = 240
CONFIG.Console.Size = UDim2.fromOffset(420, 340)
CONFIG.Console.ShowFloatingButton = true   -- tap target for touch/console players
```

**Turn chaos mode off completely** (the command disappears from `:help`):

```lua
CONFIG.Chaos.Enabled = false
```

**Announce joins and leaves:**

```lua
CONFIG.JoinMessages.Enabled = true
CONFIG.JoinMessages.Style = "Toast"          -- Banner | Toast | Ticker
CONFIG.JoinMessages.AnnounceStaffOnly = true -- only when staff join
CONFIG.LeaveMessages.Enabled = true
```

**Repeat an announcement every 5 minutes automatically:**

```lua
CONFIG.Schedule.Items = {
    { Every = 300, Message = "Double XP is live!", Style = "Gold", Kind = "Ticker" },
}
CONFIG.Schedule.UptimeAnnouncements = {
    { At = 3600, Message = "This server has been up for an hour!", Style = "Ice" },
}
```

**Enable DataStore persistence** (after turning on *Enable Studio Access to API Services*):

```lua
CONFIG.Persistence.Enabled = true
CONFIG.Persistence.AllowInStudio = true   -- optional, for testing
CONFIG.Persistence.SaveInterval = 120
```

**Quiet the output window:**

```lua
CONFIG.Debug.BannerOnBoot = false
CONFIG.Debug.PrintCommands = false
CONFIG.Debug.Enabled = false
```

## Validating your changes

The panel validates `CONFIG` on boot and warns about anything it cannot use:

- unknown style names fall back to `CONFIG.DefaultStyle`
- unknown colour names fall back to the rank colour
- unknown rank names fall back to `Player`
- missing or malformed `GroupRanks` entries are skipped with a warning
- `Bootstrap.ValidateConfig()` clamps durations, lengths and cooldowns into sane ranges

So a typo degrades gracefully instead of breaking the panel — but check the Output window after
editing, because that is where the warnings go.

