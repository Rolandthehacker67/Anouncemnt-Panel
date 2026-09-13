# Command reference

Every command in **Announcement Panel v2.1.0** — 39 commands in 5 categories.

- **Prefix:** `:` (change `CONFIG.CommandPrefix`)
- **Whisper prefix:** `.` — `.announce hi` reaches staff only (change `CONFIG.WhisperPrefix`)
- Commands marked **Requires the server install** need the `Script` half. In a client-only (solo)
  install they reply with a warning instead of silently doing nothing.
- Every command is rank-gated, rate-limited (`CONFIG.Limits`), text-filtered and history-logged.
- `:help` in game prints the same information, filtered to what *you* may use.

## Contents

- [Announcements](#announcements) (11)
- [Effects](#effects) (6)
- [Information](#information) (10)
- [Moderation](#moderation) (6)
- [System](#system) (6)
- [Permission matrix](#permission-matrix)
- [Flags](#flags)
- [Targets](#targets)
- [Styles](#styles)
- [Colours](#colours)
- [Presets](#presets)
- [Rate limits](#rate-limits)
- [Adding your own commands](#adding-your-own-commands)
- [Typing conventions](#typing-conventions)

## Announcements

### `:announce`

**Aliases:** `:a` `:say` `:msg` `:message`

**Usage:** `:announce <message> [-t seconds] [-s style] [-c color] [--to target] [--title text] [--sound name]`

Pins a glowing banner to the top of everyone's screen.

**Available to:** **Owner**, **Admin**, **Mod**, **Helper**

```
:announce Server restart in 5 minutes
:announce Double XP is live! -s Gold -t 15
:a Hello admins --to admins -c cyan
```

### `:alert`

**Aliases:** `:alarm` `:emergency` `:urgent`

**Usage:** `:alert <message> [-t seconds] [--title text]`

Full-screen takeover with a dimmed backdrop. Use sparingly.

**Available to:** **Owner**, **Admin**

```
:alert The server is restarting NOW
:alarm Intruder in the base --title SECURITY
```

### `:ticker`

**Aliases:** `:news` `:marquee` `:scroll`

**Usage:** `:ticker <message> [-t seconds] [-c color] [--tag LIVE]`

Scrolling news bar across the very top of the screen.

**Available to:** **Owner**, **Admin**, **Mod**

```
:ticker Weekend event is live all weekend long
:news Update 2.1 released -c neon
```

### `:toast`

**Aliases:** `:notify` `:n` `:note`

**Usage:** `:toast <message> [-t seconds] [--to target] [--title text]`

Small notification in the bottom-right corner.

**Available to:** **Owner**, **Admin**, **Mod**, **Helper**

```
:toast Report commands are open
:n Welcome back! --to @Steve
```

### `:countdown`

**Aliases:** `:timer` `:cd` `:count`

**Usage:** `:countdown <seconds> [label] [--finish GO!]`

Big centred countdown that pops on every tick.

**Available to:** **Owner**, **Admin**

```
:countdown 10
:cd 30 Restarting server
:timer 5 Race starts --finish RACE!
```

### `:broadcast`

**Aliases:** `:bc`

**Usage:** `:broadcast <message>`

Golden banner forced to every player, ignoring --to.

**Available to:** **Owner**, **Admin**

### `:preset`

**Aliases:** `:quick` `:p`

**Usage:** `:preset <name>`

Fires a pre-configured bundle from CONFIG.Presets.

**Available to:** **Owner**, **Admin**

```
:preset restart
:quick doublexp
```

### `:whisper`

**Aliases:** `:w` `:staff` `:sc`

**Usage:** `:whisper <message>`

Banner visible to staff only. Players never see it.

**Available to:** **Owner**

### `:test`

**Aliases:** `:preview` `:demo`

**Usage:** `:test [message]`

Sends an announcement to you only. Nobody else sees it.

**Available to:** **Owner**, **Admin**, **Mod**, **Helper**

### `:motd`

**Aliases:** `:messageoftheday` `:welcome`

**Usage:** `:motd <message> | :motd --clear | :motd --show`

Sets the message shown to everyone who joins from now on.

**Available to:** **Owner**, **Admin**

```
:motd Weekend event is live!
:motd --clear
:motd --show
```

### `:clear`

**Aliases:** `:clean` `:stop` `:reset` `:hide`

**Usage:** `:clear [--to target]`

Removes every banner, toast, ticker, alert and countdown.

**Available to:** **Owner**, **Admin**, **Mod**

## Effects

### `:flash`

**Aliases:** `:strobe` `:blink`

**Usage:** `:flash [-c color] [--times 3]`

Flashes the screen for everyone.

**Available to:** **Owner**, **Admin**

### `:shake`

**Aliases:** `:quake` `:earthquake` `:rumble`

**Usage:** `:shake [-i intensity]`

Shakes every camera and the whole panel.

**Available to:** **Owner**, **Admin**

### `:confetti`

**Aliases:** `:party` `:celebrate` `:rain`

**Usage:** `:confetti [-n count]`

Rains confetti down everyone's screen.

**Available to:** **Owner**, **Admin**

### `:vignette`

**Aliases:** `:dark` `:focus`

**Usage:** `:vignette on|off`

Darkens the screen edges for a dramatic look.

**Available to:** **Owner**, **Admin**

### `:blur`

**Aliases:** `:focusblur`

**Usage:** `:blur [-a amount]`

Brief blur pulse on the whole server (needs the server install).

**Available to:** **Owner**

> ⚠️ **Requires the server install.**

### `:chaos`

**Aliases:** `:abuse` `:adminabuse` `:show` `:party-mode`

**Usage:** `:chaos on|off [seconds]`

The admin-abuse show: fake owners spam dramatic messages.

**Available to:** **Owner**, **Admin**

```
:chaos on
:chaos on 60
:abuse off
```

## Information

### `:history`

**Aliases:** `:h` `:log` `:recent`

**Usage:** `:history [count] [search]`

Shows the most recent announcements.

**Available to:** **Owner**, **Admin**, **Mod**, **Helper**

```
:history
:history 15
:history 5 restart
```

### `:help`

**Aliases:** `:cmds` `:commands` `:?`

**Usage:** `:help [command] [page]`

Lists the commands your rank may use.

**Available to:** **Owner**, **Admin**, **Mod**, **Helper**

```
:help
:help announce
:help 2
```

### `:stats`

**Aliases:** `:info` `:status` `:uptime`

**Usage:** `:stats`

Server statistics and announcement counters.

**Available to:** **Owner**, **Admin**, **Mod**

### `:whoami`

**Aliases:** `:myrank` `:me`

**Usage:** `:whoami`

Shows which rank the panel gave you and why.

**Available to:** **Owner**

### `:styles`

**Aliases:** `:themes`

**Usage:** `:styles`

Lists the visual styles you can pass to -s.

**Available to:** **Owner**

### `:presets`

**Aliases:** `:quicklist`

**Usage:** `:presets`

**Available to:** **Owner**

### `:ranks`

**Aliases:** `:ranklist` `:online` `:players`

**Usage:** `:ranks`

Lists everyone in the server with their resolved rank.

**Available to:** **Owner**

### `:ping`

**Aliases:** `:alive` `:pong`

**Usage:** `:ping`

**Available to:** **Owner**, **Admin**, **Mod**, **Helper**

### `:version`

**Aliases:** `:ver` `:about`

**Usage:** `:version`

**Available to:** **Owner**

### `:colors`

**Aliases:** `:colours`

**Usage:** `:colors`

Lists the colour names accepted by -c.

**Available to:** **Owner**

## Moderation

### `:mute`

**Aliases:** `:silence` `:shush`

**Usage:** `:mute <player> [seconds] [reason]`

Stops a player's chat messages from being delivered.

**Available to:** **Owner**, **Admin**, **Mod**

> ⚠️ **Requires the server install.**

```
:mute Steve
:mute Steve 300 spamming
:mute @Steve 60
```

### `:unmute`

**Aliases:** `:unsilence`

**Usage:** `:unmute <player>`

**Available to:** **Owner**, **Admin**, **Mod**

> ⚠️ **Requires the server install.**

### `:mutes`

**Aliases:** `:mutelist` `:silenced`

**Usage:** `:mutes`

**Available to:** **Owner**

### `:rank`

**Aliases:** `:promote` `:setrank`

**Usage:** `:rank <player> <rank>`

Gives a player a session rank (lasts until they leave).

**Available to:** **Owner**, **Admin**

> ⚠️ **Requires the server install.**

```
:rank Steve Mod
:promote @Alex Admin
```

### `:unrank`

**Aliases:** `:demote` `:striprank`

**Usage:** `:unrank <player>`

**Available to:** **Owner**, **Admin**

> ⚠️ **Requires the server install.**

### `:kick`

**Aliases:** `:remove` `:boot`

**Usage:** `:kick <player> [reason]`

Announces the kick, then kicks. Owner only.

**Available to:** **Owner**

> ⚠️ **Requires the server install.**

## System

### `:clearhistory`

**Aliases:** `:ch`

**Usage:** `:clearhistory`

Empties the announcement history log.

**Available to:** **Owner**

### `:schedule`

**Aliases:** `:sched` `:every`

**Usage:** `:schedule <everySeconds> <message> [-s style] [-t duration]`

Repeats an announcement on a timer.

**Available to:** **Owner**, **Admin**

```
:schedule 600 Follow the group for updates!
:sched 300 Event ends soon -s Fire
```

### `:unschedule`

**Aliases:** `:unsched` `:removeschedule`

**Usage:** `:unschedule <id|index> | :unschedule all`

**Available to:** **Owner**, **Admin**

### `:schedules`

**Aliases:** `:schedlist` `:timers`

**Usage:** `:schedules`

**Available to:** **Owner**

### `:panel`

**Aliases:** `:console` `:open` `:ui`

**Usage:** `:panel`

Opens the Owner Console (needs the client install).

**Available to:** **Owner**, **Admin**, **Mod**

### `:refresh`

**Aliases:** `:reload` `:recache`

**Usage:** `:refresh`

Clears the rank cache and re-resolves everyone.

**Available to:** **Owner**

## Permission matrix

Sourced from `CONFIG.Ranks[rank].Permissions`. `"*"` means every command — including commands you
register yourself later with `Commands.Register`.

| Command | 👑 OWNER | 🛡 ADMIN | 🔨 MODERATOR | ✨ HELPER | 💎 VIP | PLAYER |
|---|---|---|---|---|---|---|
| `:announce` | ✅ | ✅ | ✅ | ✅ | · | · |
| `:alert` | ✅ | ✅ | · | · | · | · |
| `:ticker` | ✅ | ✅ | ✅ | · | · | · |
| `:toast` | ✅ | ✅ | ✅ | ✅ | · | · |
| `:countdown` | ✅ | ✅ | · | · | · | · |
| `:broadcast` | ✅ | ✅ | · | · | · | · |
| `:preset` | ✅ | ✅ | · | · | · | · |
| `:whisper` | ✅ | · | · | · | · | · |
| `:test` | ✅ | ✅ | ✅ | ✅ | · | · |
| `:motd` | ✅ | ✅ | · | · | · | · |
| `:clear` | ✅ | ✅ | ✅ | · | · | · |
| `:flash` | ✅ | ✅ | · | · | · | · |
| `:shake` | ✅ | ✅ | · | · | · | · |
| `:confetti` | ✅ | ✅ | · | · | · | · |
| `:vignette` | ✅ | ✅ | · | · | · | · |
| `:blur` | ✅ | · | · | · | · | · |
| `:chaos` | ✅ | ✅ | · | · | · | · |
| `:history` | ✅ | ✅ | ✅ | ✅ | · | · |
| `:help` | ✅ | ✅ | ✅ | ✅ | · | · |
| `:stats` | ✅ | ✅ | ✅ | · | · | · |
| `:whoami` | ✅ | · | · | · | · | · |
| `:styles` | ✅ | · | · | · | · | · |
| `:presets` | ✅ | · | · | · | · | · |
| `:ranks` | ✅ | · | · | · | · | · |
| `:ping` | ✅ | ✅ | ✅ | ✅ | · | · |
| `:version` | ✅ | · | · | · | · | · |
| `:colors` | ✅ | · | · | · | · | · |
| `:mute` | ✅ | ✅ | ✅ | · | · | · |
| `:unmute` | ✅ | ✅ | ✅ | · | · | · |
| `:mutes` | ✅ | · | · | · | · | · |
| `:rank` | ✅ | ✅ | · | · | · | · |
| `:unrank` | ✅ | ✅ | · | · | · | · |
| `:kick` | ✅ | · | · | · | · | · |
| `:clearhistory` | ✅ | · | · | · | · | · |
| `:schedule` | ✅ | ✅ | · | · | · | · |
| `:unschedule` | ✅ | ✅ | · | · | · | · |
| `:schedules` | ✅ | · | · | · | · | · |
| `:panel` | ✅ | ✅ | ✅ | · | · | · |
| `:refresh` | ✅ | · | · | · | · | · |

| | **OWNER** | **ADMIN** | **MODERATOR** | **HELPER** | **VIP** | **PLAYER** |
|---|---|---|---|---|---|---|
| Order | 100 | 75 | 50 | 30 | 15 | 0 |
| Max duration | 600s | 300s | 120s | 60s | 0s | 0s |
| Chaos mode | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Command count | 39 | 26 | 12 | 6 | 0 | 0 |

## Flags

Flags can appear anywhere after the command name, in any order, and are case-insensitive.

| Long | Short | Value | Typical use |
|---|---|---|---|
| `--time <seconds>` | `-t` | number | how long it stays on screen |
| `--style <name>` | `-s` | style name | `:announce` `:alert` `:toast` `:preset` `:schedule` |
| `--color <name>` | `-c` | colour / `#RRGGBB` / `r,g,b` | `:announce` `:ticker` `:toast` `:flash` |
| `--to <target>` |  | target name | `:announce` `:alert` `:toast` `:clear` `:schedule` |
| `--title <text>` |  | string | title line above the message |
| `--tag <text>` |  | string | `:ticker` tag chip, e.g. `LIVE` |
| `--finish <text>` |  | string | word shown when `:countdown` hits zero |
| `--kind <name>` |  | `Banner` `Toast` `Alert` `Ticker` | `:test` `:schedule` |
| `--times <n>` |  | number | `:flash` repetition count |
| `--intensity <n>` | `-i` | number | `:shake` strength |
| `--amount <n>` | `-a` | number | `:blur` strength |
| `--count <n>` | `-n` | number | `:confetti` pieces, `:history` rows |
| `--clear` |  | boolean | `:motd --clear` |
| `--show` |  | boolean | `:motd --show` (re-show it to yourself) |
| `--all` |  | boolean | `:unschedule all`, `:clear --to all` |

**Quoting** — wrap values that contain spaces:

```
:announce Server restart at 8pm --title "SERVER RESTART" -s Emergency --to everyone
```

**Bare flags** evaluate to `true` (`:motd --clear`). **`--flag=value`** works too (`-t=15`).

**A bare `--` ends flag parsing**, so everything after it is message text:

```
:announce -- -t is not a flag here, it is the message
```

## Targets

`--to` understands these names (aliases in brackets):

| Target | Receives |
|---|---|
| `all` (`everyone`, `server`, `global`) | every player in the server |
| `admins` (`admin`) | Admin rank and above |
| `owners` (`owner`) | Owner rank only |
| `mods` (`mod`, `moderators`) | Mod rank and above |
| `staff` | Helper rank and above |
| `nonstaff` (`players`) | everyone who is not staff |
| `random` | one random player |
| `me` (`self`) | only you — ideal for previewing |
| `<name>` | one player: name, display name, partial name, `@name` or `#userId` |

## Styles

8 visual styles, defined in `CONFIG.Styles`. Pass one with `-s`:

- **`Default`** — see `CONFIG.Styles.Default`
- **`Gold`** — see `CONFIG.Styles.Gold`
- **`Fire`** — see `CONFIG.Styles.Fire`
- **`Ice`** — see `CONFIG.Styles.Ice`
- **`Neon`** — see `CONFIG.Styles.Neon`
- **`Shadow`** — see `CONFIG.Styles.Shadow`
- **`Rainbow`** — see `CONFIG.Styles.Rainbow`
- **`Emergency`** — see `CONFIG.Styles.Emergency`

## Colours

23 named colours for `-c`, plus two literal forms:

```
`red`, `crimson`, `orange`, `gold`, `yellow`, `lime`, `green`, `emerald`, `teal`, `cyan`, `sky`, `blue`, `navy`, `purple`, `violet`, `pink`, `magenta`, `white`, `silver`, `grey`, `gray`, `black`, `brown`
```

- `#RRGGBB` — e.g. `-c #FF7A3D`
- `r,g,b` — e.g. `-c 255,120,60`

## Presets

Bundles from `CONFIG.Presets`, fired with `:preset <name>`, one click in the console, or from your
own code with `AnnouncementPanel.Broadcaster.Preset("restart")`:

| Preset | Title | Style | Message |
|---|---|---|---|
| `restart` | SERVER RESTART | Emergency | This server is restarting shortly. Please save your progress! |
| `update` | UPDATE LIVE | Neon | A new update has just been released. Rejoin to get it! |
| `event` | EVENT STARTING | Gold | A limited time event is starting right now. Don't miss it! |
| `rules` | SERVER RULES | Ice | No exploiting, no harassment, no spam. Be excellent to each other. |
| `welcome` | WELCOME | Default | Welcome to the server! Have fun and play fair. |
| `doublexp` | DOUBLE XP | Gold | Double XP is active for the whole server right now! |
| `maintenance` | MAINTENANCE | Shadow | The game is going down for maintenance. Thank you for your patience. |
| `giveaway` | GIVEAWAY | Rainbow | A giveaway is running in the community server. Check the group! |
| `lag` | PERFORMANCE | Fire | We are aware of the lag and are looking into it. Thanks for waiting. |
| `shutdown` | SHUTTING DOWN | Emergency | This server is closing in a few moments. Thanks for playing! |

## Rate limits

From `CONFIG.Limits`. These are why a command sometimes replies *"Slow down"* or *"cooldown"* —
they are per player, and they protect your game from spam and from exploiters.

| Limit | Default | Applies to |
|---|---|---|
| `CommandCooldown` | 1.2s | any two commands from the same player |
| `AnnounceCooldown` | 2.5s | any two broadcasts from the same player |
| `AlertCooldown` | 20s | `:alert` — full-screen takeovers are rare on purpose |
| `ChaosCooldown` | 30s | `:chaos` |
| `MaxMessageLength` | 280 | message text is truncated past this |
| `MaxLengthBeforeReject` | 400 | `CONFIG.Moderation` — rejected outright past this |
| `MaxVisibleBanners` | 3 | older banners collapse out of the way |
| `MaxToastsOnScreen` | 4 | oldest toast is retired |
| `MaxScheduledEvents` | 12 | `:schedule` |
| `MaxConcurrentEffects` | 8 | flashes / shakes / confetti at once |

## Adding your own commands

`Commands.Register` is exported, so another script (or code at the bottom of this one) can add
commands that go through the exact same parser, permission gates, cooldowns, filter, history log
and Owner Console as the built-ins:

```lua
local AP = require(game.ServerScriptService.AnnouncementPanel)

AP.Commands.Register({
    Name = "boss",
    Aliases = { "spawnboss" },
    Category = "Announcements",
    Usage = ":boss <name>",
    Description = "Announce a boss spawn.",
    Examples = { ":boss Voragos" },
    Order = 120,
    Permission = "boss",   -- key checked against rank Permissions; "*" ranks always pass
    ServerOnly = false,
    NeedsMessage = true,
    Run = function(ctx)
        AP.Announce(ctx.Message .. " has spawned!", { Style = "Fire", Rank = ctx.Rank })
        ctx.Reply("Boss announced.", "success")
        return true
    end,
})
```

`ctx` gives you: `Player`, `Rank`, `Meta`, `Parsed`, `Args`, `Flags`, `Message`, `Raw`, `Source`,
`StartedAt`, `Replies`, `Reply(text, kind)`, `ReplyAll(text)`, `RequireServer()`, `RequireClient()`.
Reply kinds are `info`, `success`, `warn` and `error`.

Grant it to ranks by adding `"boss"` to `CONFIG.Ranks.Admin.Permissions` (Owner has `"*"`, so it
works for Owners immediately). `Commands.Unregister("boss")` removes it and its aliases again.

## Typing conventions

- `<angle brackets>` — required.
- `[square brackets]` — optional.
- `a|b` — choose one.
- Player arguments accept a full name, display name, partial name, `@name` or `#userId`.
- Durations are seconds, clamped to `CONFIG.Limits.MinDuration`/`MaxDuration` **and** to your
  rank's `MaxDuration`.
- Message text passes through `TextService:FilterStringAsync` before anyone sees it.

