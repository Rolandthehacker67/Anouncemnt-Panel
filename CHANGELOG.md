# Changelog

All notable changes to **Announcement Panel** are documented here.
The project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-09-13

First public release: the whole system in one dual-context Luau file
(12,300+ lines, no dependencies, no external models).

### Added

**Announcement surfaces**
- Banner — glowing card pinned under the topbar with rank badge, title, sender, timestamp and a
  live progress bar; up to 3 on screen at once, older ones collapse out of the way.
- Alert — full-screen takeover with a dimmed backdrop, pulsing glow and a big title.
- Toast — stacked corner notifications with a per-toast lifetime.
- Ticker — scrolling news bar across the very top of the screen, with a tag chip (e.g. `LIVE`).
- Countdown — huge centred digits that pop on every tick, with a configurable finish word.
- MOTD — message of the day shown to each player a few seconds after they join.
- Effects — screen flash, camera shake, confetti rain, vignette and Lighting blur/colour pulses.

**Commands (39)**
- Announcements: `:announce` `:alert` `:toast` `:ticker` `:countdown` `:motd` `:broadcast`
  `:whisper` `:test` `:preset` `:clear`
- Effects: `:flash` `:shake` `:confetti` `:vignette` `:blur` `:chaos`
- Moderation: `:mute` `:unmute` `:mutes` `:rank` `:unrank` `:kick`
- System: `:schedule` `:schedules` `:unschedule` `:panel` `:refresh` `:clearhistory`
- Information: `:help` `:stats` `:history` `:ranks` `:whoami` `:styles` `:colors` `:presets`
  `:version` `:ping`
- Flag parser supporting `-t`, `-s`, `-c`, `--to`, `--title`, `--tag`, `--finish`, `--kind`,
  `--flag=value`, bare boolean flags, quoted values and a `--` end-of-flags separator.
- Command suggestions on typos (`:anounce` → "Did you mean :announce?") using edit distance.
- Whisper prefix (`.announce`) for staff-only broadcasts.

**Ranks and permissions**
- Six ranks — Owner, Admin, Mod, Helper, VIP, Player — resolved top-down by `Order`.
- Resolution sources: place owner, UserIds, usernames, group ranks, Roblox Teams, game passes,
  runtime `AP_Rank` attribute, and a deny list.
- Per-rank permissions, maximum announcement duration and chaos rights.
- 20-second rank cache so group/game pass lookups never spam the API.
- `:whoami` and `CONFIG.Debug.PrintRankResolution` expose exactly why a rank was chosen.

**Owner Console (client half)**
- Five tabs: Compose, Presets, History, Tools, Chaos.
- Message and title boxes with a live character counter, kind selector, style chips, colour
  swatches, target selector, effect toggles, duration stepper, preview and send.
- Searchable history, MOTD editor, rank list, stats, ping, clear and refresh tools.
- Chaos simulator with a duration stepper, live status and per-effect fire buttons.
- Draggable title bar, resizable corner grip, minimise, close, blur behind, Escape to close,
  position memory, keybinds (Right Control / F1) and a floating button for touch and console.
- recolours itself to the local player's rank.

**Chaos mode**
- Fake owners spam dramatic lines in random styles and colours with random flashes, shakes,
  confetti and occasional full-screen alerts.
- Rank-gated, cooldown-limited and capped by `CONFIG.Chaos.MaxDurationSeconds` so it can never be
  left running forever.

**Networking and installation**
- One file works as a `Script` (server) and as a `LocalScript` (client); it detects its context
  with `RunService` and boots only the relevant half.
- Companion mode: the two halves handshake over
  `ReplicatedStorage.AnnouncementPanelRemotes` (`Announcement`, `ConsoleCommand`, `Handshake`,
  `Ack`) plus an `AP_ServerActive` attribute, so nothing is ever rendered twice.
- Solo mode: with only the client half installed, the panel builds its own display and runs every
  command locally, plus an optional demo show.
- Chat hooks on both systems: `TextChannel.OnIncomingMessage` (suppresses the command text so it
  never appears in chat) with `Player.Chatted` / `Players.PlayerChatted` as a fallback, deduplicated
  so a message can never be handled twice.
- Server→client polish: camera shake and local sounds the server cannot produce.
- Client resilience: 30-second re-sync, `CharacterAdded` re-hook, rank attribute listener, and a
  server-root watcher that re-enhances the GUI if the server rebuilds it.

**Safety**
- `TextService:FilterStringAsync` on every broadcast, with a local word-list fallback when the
  service is unavailable.
- Rich-text stripping so players cannot inject `<font>` tags.
- Length caps, per-player command and announcement cooldowns, alert and chaos cooldowns, a remote
  rate limit (12 calls / 2s), and rejection of any client that fires the announcement remote.
- Malformed console payloads are sanitised or dropped, never trusted.
- Every internal call is `pcall`-guarded: a missing service degrades to a warning, not a crash.

**Other**
- Optional DataStore persistence for MOTD, schedules and stats, with auto-save and `BindToClose`.
- Declarative scheduled announcements plus uptime milestones, alongside the runtime `:schedule`.
- Join and leave messages (off by default), templates with `{player}` `{rank}` `{badge}`.
- History log with sender, rank, style, kind, target and timestamp; searchable in game.
- 8 visual styles, 23 colour names plus `#RRGGBB` and `r,g,b`, 10 presets.
- Scriptable API: the file returns a namespace (`Announce`, `Alert`, `Toast`, `Ticker`,
  `Countdown`, `GetRank`, `SetRank`, `Clear`, `StartChaos`, `StopChaos`, `GetState`, `Shutdown`)
  plus every internal sub-namespace, and `Commands.Register` / `Commands.Unregister` for adding
  your own commands.
- Responsive scaling with the real topbar inset and device safe area.
- ASCII boot banner and structured, prefixed console logging.

### Verified

- Parses with `luau-compile`; **zero warnings** from `luau-analyze`.
- Every `Enum.*` item, `Instance.new` class, service method and 103 property tables cross-checked
  against Roblox's published API definitions.
- **280 runtime checks across 4 headless scenarios** (server, client solo, both halves together,
  legacy chat) with zero runtime errors — see [`tests/README.md`](tests/README.md).

### Fixed during pre-release testing

The headless harness caught four bugs that static analysis could not:

- Console tab buttons were created and styled but never wired to a click handler, so the five tabs
  could not be switched with the mouse.
- `Net.Handshake` was used both as the RemoteEvent instance and as a function name; the instance
  assignment overwrote the function and `Client.Sync()` crashed in companion mode. Renamed to
  `Net.SendHandshake`.
- `Renderer.FindServerRoot` relied on implicit child-name indexing (`tickerBar.Tag`), which broke
  the client half's adoption of the server-built GUI. Now uses explicit locals.
- The client fired the console remote as `(action, payload)` while the server handler read
  `(player, payload)`, so every companion-mode console command was silently dropped as malformed.
  The server now accepts both shapes and back-fills the action.

[2.1.0]: https://github.com/Rolandthehacker67/Anouncemnt-Panel/releases/tag/v2.1.0
