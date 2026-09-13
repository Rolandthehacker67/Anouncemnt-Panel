<div align="center">

# 📢 Announcement Panel

### One file. Two contexts. Every announcement trick in the book.

**A complete Roblox announcement / "admin abuse" broadcast system in a single Luau script.**
Owners and admins type `:announce Server restart in 5 minutes` in chat and a glowing banner
slams onto the top of every player's screen — with sounds, camera shake, confetti, countdowns,
tickers, alerts, a full Owner Console GUI, and a chaos mode that pretends the server is losing
its mind.

`12,300+ lines` · `39 commands` · `6 ranks` · `8 visual styles` · `0 dependencies` · `MIT licensed`

</div>

---

## Table of contents

1. [What you get](#what-you-get)
2. [Two minute install](#two-minute-install)
3. [Your first announcement](#your-first-announcement)
4. [Commands](#commands)
5. [Who is allowed to do what](#who-is-allowed-to-do-what)
6. [The Owner Console](#the-owner-console)
7. [Chaos mode (the "admin abuse" bit)](#chaos-mode-the-admin-abuse-bit)
8. [Configuration](#configuration)
9. [Using it from your own scripts](#using-it-from-your-own-scripts)
10. [How one file works as both a Script and a LocalScript](#how-one-file-works-as-both-a-script-and-a-localscript)
11. [Troubleshooting](#troubleshooting)
12. [Project layout](#project-layout)
13. [Testing](#testing)
14. [License](#license)

---

## What you get

**Seven announcement surfaces**, all rendered at the top of the screen or wherever they read best:

| Surface | What it looks like | Command |
|---|---|---|
| **Banner** | Glowing card pinned under the topbar with a rank badge, sender, progress bar | `:announce` |
| **Alert** | Full-screen takeover: dimmed backdrop, pulsing glow, big title | `:alert` |
| **Toast** | Small stacked notifications in the bottom-right corner | `:toast` |
| **Ticker** | Scrolling news bar across the very top of the screen | `:ticker` |
| **Countdown** | Huge centred numbers that pop on every tick, with a finish word | `:countdown` |
| **MOTD** | Message of the day card shown to everyone a few seconds after they join | `:motd` |
| **Effects** | Screen flash, camera shake, confetti rain, vignette, blur pulse | `:flash` `:shake` `:confetti` `:vignette` `:blur` |

**Plus the plumbing that makes it usable in a real game:**

- 🎚️ **Rank system** — Owner / Admin / Mod / Helper / VIP / Player, resolved from the place owner,
  UserIds, usernames, group ranks, Roblox Teams, game passes, or a runtime `AP_Rank` attribute.
- 🖥️ **Owner Console** — a draggable, resizable GUI with tabs for composing, presets, history,
  tools and the chaos simulator. Works on PC, mobile and console (floating button + keybinds).
- 🛡️ **Safe by default** — every broadcast goes through `TextService:FilterStringAsync`, rich-text
  injection is stripped, messages are length-capped, and every command is rank-gated, rate-limited
  and logged.
- 🔁 **Repeating announcements** — `:schedule 300 Save your progress!` or declarative timers in
  `CONFIG.Schedule`, including uptime milestones.
- 💾 **Optional persistence** — MOTD, schedules and stats can survive a server restart through a
  DataStore (off by default so nothing breaks before you enable API access).
- 🧩 **Solo mode** — install *only* the client half and everything still works locally, console and
  all, so you can demo it in an empty baseplate.
- 🎛️ **Scriptable** — the file returns a namespace, so other scripts can call
  `AnnouncementPanel.Announce("Boss fight started!")` directly.

---

## Two minute install

### Option A — Roblox Studio by hand

1. Open your place in Studio.
2. **Server half** (required for real announcements):
   - In the Explorer, right-click **ServerScriptService** → *Insert Object* → **Script**.
   - Rename it to `AnnouncementPanel`.
   - Paste the entire contents of [`AnnouncementPanel.luau`](AnnouncementPanel.luau) into it.
3. **Client half** (optional, adds the Owner Console, keybinds, camera shake and local sounds):
   - Right-click **StarterPlayer → StarterPlayerScripts** → *Insert Object* → **LocalScript**.
   - Rename it to `AnnouncementPanel`.
   - Paste the **same** file contents into it.
4. Press **Play**. You should see the ASCII banner in the Output window and, if you are the place
   owner (or you are testing in Studio), a welcome announcement at the top of the screen.

> The same file goes in both places. It detects whether it is running as a `Script` or a
> `LocalScript` and boots the correct half. See
> [How one file works as both](#how-one-file-works-as-both-a-script-and-a-localscript).

### Option B — Rojo

[`default.project.json`](default.project.json) maps the one source file into both
`ServerScriptService` (as a `Script`) and `StarterPlayerScripts` (as a `LocalScript`):

```bash
rojo serve
# then connect with the Rojo plugin in Studio
```

### Option C — ModuleScript

Put the file in a `ModuleScript` (for example `ReplicatedStorage.AnnouncementPanel`) and `require`
it from your own code. It boots the half that matches the requiring context and hands you the
namespace back.

> ⚠️ Use this **instead of** the Script/LocalScript install, not as well as it. The panel boots
> when the file runs, so two copies in the same context means two servers fighting over the same
> ScreenGuis and chat hooks.

---

## Your first announcement

In Studio, press Play and type into the chat:

```
:announce Hello world
```

A banner slides in under the topbar. Now try:

```
:alert The server is restarting NOW --title EMERGENCY -t 12
:toast Double XP is live -c gold
:ticker Weekend event all weekend long --tag LIVE
:countdown 10 Boss fight --finish GO!
:confetti
:chaos on 30
:help
```

`:help` lists only the commands **your** rank is allowed to use, with usage and examples.
`:whoami` tells you which rank you were given and exactly why.

---

## Commands

39 commands, all prefixed with `:` (change `CONFIG.CommandPrefix`). Full reference with every
alias, flag and example: **[docs/COMMANDS.md](docs/COMMANDS.md)**.

<details>
<summary><b>Announcements</b> — 11 commands</summary>

| Command | Aliases | What it does |
|---|---|---|
| `:announce <msg>` | `:a` `:say` `:msg` | Glowing banner at the top of everyone's screen |
| `:alert <msg>` | `:alarm` `:emergency` `:urgent` | Full-screen takeover with a dimmed backdrop |
| `:toast <msg>` | `:notify` `:n` `:note` | Small notification, bottom-right |
| `:ticker <msg>` | `:news` `:marquee` `:scroll` | Scrolling news bar at the very top |
| `:countdown <s> [label]` | `:timer` `:cd` `:count` | Big centred countdown |
| `:motd <msg>` | `:welcome` | Message of the day shown on join |
| `:broadcast <msg>` | `:bc` | Golden banner forced to every player |
| `:whisper <msg>` | `:w` `:staff` `:sc` | Banner only staff can see |
| `:test [msg]` | `:preview` `:demo` | Sends an announcement to you only |
| `:preset <name>` | `:quick` `:p` | Fires a pre-configured bundle |
| `:clear` | `:clean` `:stop` `:hide` | Removes everything from the screen |

</details>

<details>
<summary><b>Effects</b> — 6 commands</summary>

| Command | Aliases | What it does |
|---|---|---|
| `:flash` | `:strobe` `:blink` | Flashes the screen |
| `:shake` | `:quake` `:earthquake` | Shakes every camera and the panel |
| `:confetti` | `:party` `:celebrate` | Rains confetti |
| `:vignette on\|off` | `:dark` `:focus` | Darkens the screen edges |
| `:blur` | `:focusblur` | Blur pulse (server install) |
| `:chaos on\|off [s]` | `:abuse` `:adminabuse` `:party-mode` | The admin-abuse show |

</details>

<details>
<summary><b>Moderation</b> — 6 commands</summary>

| Command | Aliases | What it does |
|---|---|---|
| `:mute <player> [s] [reason]` | `:silence` `:shush` | Stops a player's chat being delivered |
| `:unmute <player>` | `:unsilence` | Lifts a mute |
| `:mutes` | `:mutelist` | Lists active mutes |
| `:rank <player> <rank>` | `:promote` `:setrank` | Session rank, lasts until they leave |
| `:unrank <player>` | `:demote` | Removes a session rank |
| `:kick <player> [reason]` | `:remove` `:boot` | Announces the kick, then kicks (Owner only) |

</details>

<details>
<summary><b>System</b> — 6 commands</summary>

| Command | Aliases | What it does |
|---|---|---|
| `:schedule <every> <msg>` | `:sched` `:every` | Repeats an announcement on a timer |
| `:schedules` | `:timers` | Lists active timers |
| `:unschedule <id\|all>` | `:unsched` | Removes a timer |
| `:panel` | `:console` `:ui` | Opens the Owner Console |
| `:refresh` | `:reload` | Clears the rank cache and re-resolves everyone |
| `:clearhistory` | `:ch` | Empties the history log |

</details>

<details>
<summary><b>Information</b> — 10 commands</summary>

`:help` `:stats` `:history` `:ranks` `:whoami` `:styles` `:colors` `:presets` `:version` `:ping`

</details>

### Flags

Flags work anywhere after the command name, in any order:

```
:announce Save your progress -t 15 -s Gold -c crimson --to admins --title "SERVER RESTART"
```

| Flag | Short | Meaning |
|---|---|---|
| `--time <seconds>` | `-t` | How long it stays on screen |
| `--style <name>` | `-s` | One of the 8 visual styles |
| `--color <name>` | `-c` | One of 23 colour names, `#RRGGBB`, or `255,120,60` |
| `--to <target>` | | `all` `admins` `owners` `mods` `staff` `nonstaff` `random` `me` |
| `--title <text>` | | Title line above the message |
| `--tag <text>` | | Ticker tag chip (e.g. `LIVE`) |
| `--finish <text>` | | Word shown when a countdown hits zero |
| `--kind <name>` | | Force `Banner` / `Toast` / `Alert` / `Ticker` |

Quoting: `"wrap multi word values in quotes"`. Everything after a bare `--` is treated as message
text, so `:announce -- -t is not a flag here` works.

- **Styles (8):** `Default` `Gold` `Fire` `Ice` `Neon` `Shadow` `Rainbow` `Emergency`
- **Colours (23):** `red` `crimson` `orange` `gold` `yellow` `lime` `green` `emerald` `teal` `cyan`
  `sky` `blue` `navy` `purple` `violet` `pink` `magenta` `white` `silver` `grey` `gray` `black` `brown`
- **Presets (10):** `restart` `update` `event` `rules` `welcome` `doublexp` `maintenance`
  `giveaway` `lag` `shutdown`

### Whisper prefix

`CONFIG.WhisperPrefix` (`.` by default) turns any announcement into a staff-only one:
`.announce meeting in VC` reaches staff, never players.

---

## Who is allowed to do what

Ranks are resolved **top-down by `Order`** — a player keeps the highest rank they match:

| Rank | Order | Badge | Can use | Max duration | Chaos |
|---|---|---|---|---|---|
| **Owner** | 100 | 👑 | everything (`*`) | 600s | ✅ |
| **Admin** | 75 | 🛡 | 27 commands incl. moderation | 300s | ✅ |
| **Mod** | 50 | 🔨 | announce, toast, ticker, clear, history, stats, mute, ping, panel | 120s | ❌ |
| **Helper** | 30 | ✨ | announce, toast, history, help, ping, test | 60s | ❌ |
| **VIP** | 15 | 💎 | cosmetic tag only | — | ❌ |
| **Player** | 0 | — | nothing | — | ❌ |

Tell the panel who your staff are in `CONFIG.Owners` / `CONFIG.Admins` / `CONFIG.Mods` /
`CONFIG.Helpers` / `CONFIG.VIPs`. Every list is OR'd together and each accepts:

```lua
CONFIG.Owners = {
    UserIds    = { 15645312 },                              -- most reliable
    Usernames  = { "Builderman" },                          -- convenient, can break
    GroupRanks = { { GroupId = 12345678, MinRank = 250, MaxRank = 255 } },
    Teams      = { "Administrators" },                      -- Roblox Teams
    Gamepasses = { [123456789] = true },
}
```

Out of the box these defaults already apply:

- `GameOwnerIsOwner = true` — the place owner is always an **Owner**.
- `StudioEveryoneIsOwner = true` — in Studio everyone is an Owner, so you can test instantly.
  **Turn this off before shipping** if you don't want every player to have the crown.
- `AllowAttributeOverride = true` — `player:SetAttribute("AP_Rank", "Admin")` at runtime wins,
  which is how your own admin systems can hand out ranks.
- `DenyListUserIds` — force specific users down to `Player` no matter what.

Ranks are cached for `RankRules.CacheForSeconds` (20s) so group/game pass lookups never spam.
`:whoami` shows the resolution source, and `CONFIG.Debug.PrintRankResolution = true` logs it.

---

## The Owner Console

Install the client half and press **Right Control** (or **F1**, or tap the floating button in the
bottom-right) to open a full GUI panel:

```
┌──────────────────────────────────────────────────────────┐
│ 👑 OWNER   Announcement Panel                      –   ✕ │
│ COMPOSE · PRESETS · HISTORY · TOOLS · CHAOS               │
│                                                           │
│  message ┌──────────────────────────────────────────────┐ │
│          │ Weekend event starts in 10 minutes!          │ │
│          └──────────────────────────────────────────────┘ │
│  title   ┌───────────────────────┐        128 / 280       │
│  type    [Banner][Alert][Toast][Ticker][Countdown]        │
│  style   [Gold][Fire][Ice][Neon][Rainbow][Emergency]      │
│  colour  ● ● ● ● ● ● ● ● ● ●                              │
│  target  [everyone][admins][mods][staff][me][random]      │
│  effects [flash][shake][confetti][sound]                  │
│  time    [−] 9s [+]        [ PREVIEW ]  [ 📢 SEND ]       │
│                                                           │
│  v2.1.0 • companion                          ready        │
└──────────────────────────────────────────────────────────┘
```

- **Compose** — message + title, kind, style, colour swatches, target, effect toggles, duration
  stepper, character counter, preview (sends to you only) and send.
- **Presets** — one-click bundles from `CONFIG.Presets`, plus `CONFIG.Console.QuickMessages`.
- **History** — searchable log of everything sent, with kind, sender, style and timestamp.
- **Tools** — MOTD editor, `:clear`, `:refresh`, `:ping`, rank list, stats.
- **Chaos** — the abuse simulator: duration stepper, on/off toggle, live status, and buttons that
  fire individual fake announcements.

The window is draggable (title bar), resizable (bottom-right grip), minimisable, closes on
**Escape**, remembers where you put it, and blurs the game behind it. It recolours itself to your
rank — Helpers get green, Admins red, Owners gold.

**Companion mode** (both halves installed): the console sends your command to the server over a
RemoteEvent, the server validates rank/cooldowns/filters exactly like chat, and pushes a state
packet back so the console history and stats stay live.
**Solo mode** (client half only): the console runs everything locally so you can still show off.

---

## Chaos mode (the "admin abuse" bit)

```
:chaos on 60
```

For the next 60 seconds the panel pretends the server has been taken over: fake owners with names
from `CONFIG.Chaos.FakeOwnerNames` spam dramatic lines from `CONFIG.Chaos.Lines`, in random styles
and colours, with random flashes, camera shakes, confetti bursts and the occasional full-screen
alert. It auto-stops after `CONFIG.Chaos.MaxDurationSeconds` (180s) so nobody leaves it running
forever, it is rank-gated (`CanUseChaos`), and it has its own 30s cooldown.

Everything chaos produces goes through the same broadcaster as real commands — so it is filtered,
history-logged and clearly marked as `chaos` in `:history`. `:chaos off` stops it immediately.

Set `CONFIG.Chaos.Enabled = false` to remove it entirely (the command disappears from `:help`).

---

## Configuration

Everything lives in one `CONFIG` table near the top of the file — no hunting through 12,000 lines.
Full reference: **[docs/CONFIGURATION.md](docs/CONFIGURATION.md)**.

The five things people change first:

```lua
CONFIG.CommandPrefix = ":"            -- or ">" or "!" if ":" clashes with your game
CONFIG.RankRules.StudioEveryoneIsOwner = false   -- ⚠️ before shipping!
CONFIG.Owners.UserIds = { 15645312 }             -- you
CONFIG.MOTD.Message = "Read the rules. Be excellent to each other."
CONFIG.Sounds.Banner = "rbxassetid://0000000000" -- your own sound ids
```

Other sections: `ServerInfo`, `Ranks`, `Limits`, `Appearance`, `Animation`, `Effects`, `Sounds`,
`Styles`, `Presets`, `MOTD`, `JoinMessages`, `LeaveMessages`, `Schedule`, `Chaos`, `Console`,
`Solo`, `Moderation`, `Persistence`, `Net`, `Debug`.

**Rate limits are on by default** and are the usual reason a command "did nothing":

| Limit | Default |
|---|---|
| `CommandCooldown` | 1.2s between any two commands, per player |
| `AnnounceCooldown` | 2.5s between announcements, per player |
| `AlertCooldown` | 20s — full-screen alerts are rare on purpose |
| `ChaosCooldown` | 30s |
| `MaxMessageLength` | 280 characters (longer text is truncated) |
| `MaxVisibleBanners` | 3 — older ones collapse out of the way |

---

## Using it from your own scripts

The file **returns** its namespace, so it doubles as a `ModuleScript`:

```lua
-- ServerScriptService/MyGameLogic.server.lua
local AP = require(game.ServerScriptService.AnnouncementPanel)

AP.Announce("Boss fight started!", { Style = "Fire", Duration = 12, Sound = "Alert" })
AP.Alert("Server restart in 60 seconds", { Title = "MAINTENANCE" })
AP.Toast("Double XP is live", { Color = "gold" })
AP.Ticker("Weekend event all weekend long", { Tag = "LIVE" })
AP.Countdown(10, "Boss spawn", { Finish = "GO!" })

AP.StartChaos(nil, 30)             -- nil = fired by the system
print(AP.GetRank(player))          -- "Owner"
AP.SetRank(player, "Mod")          -- session rank
AP.Clear()                         -- wipe every screen
local state = AP.GetState()        -- stats, history, MOTD, chaos, mode
```

Sub-namespaces are exported too, if you want the internals:
`AP.Util`, `AP.Theme`, `AP.Audio`, `AP.RankSystem`, `AP.MessageFilter`, `AP.ChatBridge`, `AP.Net`,
`AP.State`, `AP.History`, `AP.Persistence`, `AP.Scheduler`, `AP.UIBuilder`, `AP.Effects`,
`AP.Renderer`, `AP.Broadcaster`, `AP.Commands`, `AP.CommandParser`, `AP.CommandService`,
`AP.Chaos`, `AP.ServerCore`, `AP.ClientConsole`, `AP.Client`, `AP.Bootstrap`, `AP.CONFIG`.

Custom commands register through the same registry the built-ins use:

```lua
AP.Commands.Register({
    Name = "boss",
    Aliases = { "spawnboss" },
    Category = "Announcements",
    Usage = ":boss <name>",
    Description = "Announce a boss spawn.",
    Run = function(ctx)
        AP.Announce(ctx.Message .. " has spawned!", { Style = "Fire", Rank = ctx.Rank })
        ctx.Reply("Boss announced.", "success")
        return true
    end,
})
```

---

## How one file works as both a Script and a LocalScript

```lua
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()
```

Those two lines decide everything. The file is written so that each half only touches APIs that
exist in its own context:

- **Server half** (`Script` in `ServerScriptService`) creates the RemoteEvents, hooks chat
  (`TextChannel.OnIncomingMessage` *and* `Player.Chatted`, deduplicated so nothing runs twice),
  filters text, resolves ranks, injects a ScreenGui into every `PlayerGui`, drives the scheduler,
  chaos mode, persistence and moderation.
- **Client half** (`LocalScript` in `StarterPlayerScripts`) builds the Owner Console, binds
  keybinds, does camera shake and local sounds, and either **enhances** the server-built GUI
  (companion) or builds its own display (solo).
- When both are present they handshake over
  `ReplicatedStorage.AnnouncementPanelRemotes` and a `AP_ServerActive` attribute, so nothing is
  ever rendered twice and the client never guesses its own rank.

Nothing is `require`d, nothing is downloaded, nothing is parented into `ReplicatedStorage` except
the four RemoteEvents the two halves talk through.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| **Nothing happens when I type `:announce`** | You are not ranked. Type `:whoami` — it tells you your rank and why. In Studio, `RankRules.StudioEveryoneIsOwner` should make you Owner; add your UserId to `CONFIG.Owners.UserIds` in a live game. |
| **"Slow down - commands are rate limited"** | Working as intended. Raise `CONFIG.Limits.CommandCooldown` / `AnnounceCooldown` if you want faster spam. |
| **"Alert failed: cooldown"** | `AlertCooldown` is 20s by design. |
| **The banner appears twice** | You installed the file twice *in the same context* (two Scripts, or two LocalScripts). One of each, maximum. |
| **No console GUI** | The client half is a **LocalScript** in `StarterPlayerScripts`. Check `CONFIG.Console.Enabled`. Press Right Control / F1, or tap the floating button. |
| **Console says SOLO** | The server half is missing or booted later. That is fine — solo mode is fully functional, but only you see the announcements. |
| **Chat shows my command text** | The `TextChannel` hook suppresses commands on the new chat system. On legacy chat the text can still show; `CONFIG.Moderation.WarnInChat` controls the replies. |
| **No sounds** | `CONFIG.Sounds.*` are empty strings by default (Roblox removed free asset ids). Put your own `rbxassetid://` ids in. |
| **Output is too noisy / too quiet** | `CONFIG.Debug.Enabled`, `PrintCommands`, `PrintRender`, `PrintNetwork`, `PrintRankResolution`. |
| **DataStore warnings** | `CONFIG.Persistence.Enabled` is `false` by default. Enable it only after turning on *Enable Studio Access to API Services*. |

---

## Project layout

```
.
├── AnnouncementPanel.luau     ← the whole system (12,300+ lines, no dependencies)
├── README.md                  ← you are here
├── CHANGELOG.md
├── LICENSE                    ← MIT
├── default.project.json       ← Rojo: one file → Script + LocalScript
├── docs/
│   ├── COMMANDS.md            ← every command, alias, flag and example
│   └── CONFIGURATION.md       ← every CONFIG key explained
└── tests/
    ├── README.md              ← how the headless harness works
    ├── roblox_mock.luau       ← a mock Roblox API (instances, signals, services, tweens)
    ├── run_tests.sh           ← builds and runs all four scenarios
    ├── driver_server.luau     ← 84 checks: server half
    ├── driver_client.luau     ← 121 checks: client half in solo mode
    ├── driver_dual.luau       ← 65 checks: both halves together
    ├── driver_legacy.luau     ← 10 checks: legacy chat, no TextChatService
    └── setup_*.luau           ← per-scenario world setup
```

---

## Testing

This is a single 12,000-line file with no way to unit test it inside Studio, so it ships with a
headless harness: a mock Roblox API (`tests/roblox_mock.luau`) that implements the Instance tree,
signals, services, datatypes, a virtual clock and a coroutine scheduler. The panel source is loaded
into that world — twice in the "dual" scenario, once as a server and once as a client sharing the
same DataModel — and driven by real chat lines, button clicks and remote fires.

```bash
cd tests && ./run_tests.sh        # needs the Luau CLI (luau) on your PATH
```

Current status: **280 checks passing across 4 scenarios, zero runtime errors.**

| Scenario | Checks | Covers |
|---|---|---|
| `server` | 84 | boot, GUI injection, every command family, ranks, permissions, mutes, chaos, scheduling, persistence round-trip, player lifecycle, kick, shutdown |
| `client` (solo) | 121 | console build, every button/tab/selector, send & preview paths, history search, log, drag input, demo loop, respawn resilience |
| `dual` (companion) | 65 | handshake, state sync, one display root (no double render), server→client actions, console→server execution, exploit rejection, malformed payloads |
| `legacy` | 10 | chat still works with no `TextChatService` at all |

The harness has already earned its keep: it caught four real bugs that static analysis could not —
unwired console tab buttons, a `Net.Handshake` name collision between a RemoteEvent and a function,
implicit child-name indexing in `Renderer.FindServerRoot`, and a client/server remote argument
mismatch that silently dropped every console command in companion mode. All four are fixed; see
[CHANGELOG.md](CHANGELOG.md) and [tests/README.md](tests/README.md).

Static checks also run clean: the file parses with `luau-compile` and produces **zero warnings**
from `luau-analyze`, and every `Enum.*`, `Instance.new`, service method and property table in the
file has been cross-checked against Roblox's published API definitions.

---

## License

MIT — see [LICENSE](LICENSE). Use it, fork it, ship it, put your name on it.
Attribution is appreciated but not required.
