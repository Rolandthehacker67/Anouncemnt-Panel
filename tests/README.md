# Headless test harness

`AnnouncementPanel.luau` is a single 12,000-line file that normally only runs inside Roblox.
This harness makes it testable outside Studio: a **mock Roblox API** plus four **drivers** that
boot the real panel source and exercise it like a player would.

```bash
./run_tests.sh                  # all four scenarios
./run_tests.sh server dual      # only some scenarios
LUAU=/path/to/luau ./run_tests.sh
```

Requires the [Luau CLI](https://github.com/luau-lang/luau/releases) (`luau`) on your `PATH`.
The script exits non-zero if any check fails, so it is CI-friendly.

**Current status: 280 checks passing, zero runtime errors.**

| Scenario | Checks | What it proves |
|---|---|---|
| `server` | 84 | The `Script` half: boot, remote creation, GUI injection into every `PlayerGui`, rank resolution, every command family, permission denials, mutes, session ranks, chaos mode, scheduling, effects, clearing, the `TextChannel` chat hook, the public API, custom-command registration, DataStore round-trip, player join/leave, kick and shutdown. |
| `client` | 121 | The `LocalScript` half in **solo** mode: console construction, every tab, button, chip, swatch and toggle, the send/preview paths, truncation of over-length text, history search, the console log, drag input, open/close/minimise, the floating button, state packets, the demo loop, respawn resilience and clearing. |
| `dual` | 65 | **Both halves in one DataModel**: they handshake, the client adopts the server-built GUI instead of rendering a second one, state syncs back to the console, server→client actions (`OpenConsole`, `Effect`, `Clear`, `Pong`, `Welcome`, `SystemChat`) are handled, console→server commands execute under the server's own gates, non-staff and malformed payloads are rejected, and a client firing the announcement remote is dropped. |
| `legacy` | 10 | Chat still works when `TextChatService` does not exist at all — `Player.Chatted` and `Players.PlayerChatted` carry every command, and permissions still apply. |

## How it works

```
roblox_mock.luau        ← the fake Roblox
setup_<mode>.luau       ← world setup, runs BEFORE the panel boots
AnnouncementPanel.luau  ← the real file, wrapped in `local PANEL = (function() ... end)()`
driver_<mode>.luau      ← the assertions
```

`run_tests.sh` concatenates those into `tests/.out/combined_<mode>.luau` and runs it.

**Mock** (`roblox_mock.luau`, ~1,100 lines) provides:

- a **virtual clock** and **coroutine scheduler** — `task.spawn/wait/delay/defer`, `Mock.pump(seconds)`
  advances time and runs everything scheduled inside that window, so a 20-second alert cooldown
  costs nothing to test;
- an **Instance tree** — parenting, `FindFirstChild(recursive)`, `FindFirstChildOfClass`,
  `GetChildren`, `GetDescendants`, `WaitForChild`, `Destroy`, attributes, properties with change
  signals, and Roblox's child-by-name lookup fallback;
- **signals** — `Connect` / `Once` / `Wait` / `Fire` / `Disconnect`;
- **services** — Players, ReplicatedStorage, RunService, TweenService (real tween bookkeeping),
  TextService, TextChatService, SoundService, Lighting, StarterGui, GuiService, UserInputService,
  ContextActionService, DataStoreService (with a real in-memory store), MarketplaceService,
  HttpService, Debris, CollectionService and friends;
- **datatypes** — `Color3`, `UDim`, `UDim2`, `Vector2`, `Vector3`, `CFrame`, `TweenInfo`, `Font`,
  `Rect`, number/colour sequences and a dynamic `Enum` that fabricates any `Enum.X.Y` with a
  `Name`/`Value`;
- **error capture** — anything thrown inside a scheduled coroutine lands in `RuntimeErrors`, so a
  silent failure can never pass as success.

**Shadowing.** The Luau CLI marks `_G` read-only, so the mock cannot install globals. Instead the
generated wrapper re-declares locals with exactly the Roblox names:

```lua
local function __driver__()
local game = MockGame
local Instance = MockInstance
local Enum = MockEnum
local task = MockTask
local os = MockOs        -- virtual clock instead of the real one
-- ...
local PANEL = (function()
    -- AnnouncementPanel.luau, verbatim
end)()
-- driver assertions follow
end
```

Local shadowing means the panel source is used **completely unmodified** — no test hooks, no
`if TEST then` branches, no injected globals.

**Drivers** drive the panel through its real entry points: firing `player.Chatted`, calling
`TextChannel.OnIncomingMessage`, clicking `MouseButton1Click` on console buttons, firing
`RemoteEvent.OnClientEvent` / `FireServer`, and waiting on the virtual clock. Each `check(label,
condition)` prints `[PASS]`/`[FAIL]`, and the run ends with a tally plus any captured runtime
errors, instance count and tween count.

Because the panel's own rate limits are part of its behaviour, the drivers pace themselves against
them (`CommandCooldown` 1.2s, `AnnounceCooldown` 2.5s, `AlertCooldown` 20s, `ChaosCooldown` 30s)
instead of disabling them — so the tests assert the real cooldown behaviour too.

## What it has caught

Four bugs that static analysis could not see, all fixed in 2.1.0:

1. **Console tab buttons were never wired.** They were built, styled on selection, and completely
   inert — the five tabs could not be switched with a mouse.
2. **`Net.Handshake` name collision.** The field held the RemoteEvent *and* was defined as a
   function; `SetupClient` overwrote the function with the instance, so `Client.Sync()` threw
   "attempt to call a Instance value" and companion mode never synced. Renamed to
   `Net.SendHandshake`.
3. **Implicit child-name indexing in `Renderer.FindServerRoot`** (`tickerBar.Tag` right after
   `tickerBar:FindFirstChild("Tag")`) crashed the client half when it adopted the server-built GUI.
4. **Console remote argument mismatch.** The client fired `(action, payload)`; the server handler
   read `(player, payload)`, so it sanitised the string `"Execute"`, decided the payload was
   malformed, and dropped *every* companion-mode console command. The server now accepts both
   shapes.

Plus several harness-side lessons that are worth knowing if you extend it: mock services must be
registered in `game._services` (an unregistered `TweenService` silently degrades every animation to
a property jump), and `Mock.pump` must advance the clock even when nothing is scheduled, otherwise
cooldowns never expire.

## Adding a scenario

1. `cp setup_server.luau setup_mymode.luau` and build the world you want (players, mode flags,
   services present or absent).
2. `cp driver_server.luau driver_mymode.luau` and write assertions. `PANEL` is the namespace the
   file returned; `Mock`, `MockPlayers`, `makePlayer`, `RuntimeErrors` and `TraceLog` come from the
   mock.
3. `./run_tests.sh mymode`.

Useful mock helpers: `Mock.pump(seconds)`, `Mock.setMode(server, client, studio)`,
`Mock.instanceCount()`, `Mock.tweenCount()`, `Mock.findInstances(className)`, `Mock.WarnMessages`.
