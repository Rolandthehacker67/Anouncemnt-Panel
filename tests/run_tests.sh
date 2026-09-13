#!/usr/bin/env bash
#
# Headless smoke tests for AnnouncementPanel.luau.
#
#   ./run_tests.sh                 # run every scenario
#   ./run_tests.sh server client   # run only the named scenarios
#   LUAU=/path/to/luau ./run_tests.sh
#
# Each scenario concatenates three things into one runnable chunk:
#
#   1. roblox_mock.luau      a mock Roblox API (instances, signals, services,
#                            datatypes, virtual clock, coroutine scheduler)
#   2. setup_<mode>.luau     world setup that runs BEFORE the panel boots
#   3. AnnouncementPanel.luau  the real panel source, wrapped in a function so
#                            its trailing `return` hands us the namespace
#   4. driver_<mode>.luau    the assertions
#
# The Luau CLI keeps _G read-only, so the mock cannot install globals. Instead
# the wrapper re-declares locals with exactly the Roblox global names (game,
# Instance, Enum, task, os, ...) which shadows them for the panel source.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PANEL="$ROOT/AnnouncementPanel.luau"
OUT="$HERE/.out"
LUAU="${LUAU:-luau}"

if [ ! -f "$PANEL" ]; then
	echo "error: cannot find $PANEL" >&2
	exit 1
fi

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "error: the Luau CLI ('$LUAU') is not on PATH." >&2
	echo "       grab it from https://github.com/luau-lang/luau/releases" >&2
	echo "       or point at your binary:  LUAU=/path/to/luau ./run_tests.sh" >&2
	exit 1
fi

mkdir -p "$OUT"

build() {
	local mode="$1"
	local out="$OUT/combined_${mode}.luau"

	cat "$HERE/roblox_mock.luau" > "$out"

	cat >> "$out" << 'SHADOWS'

local function __driver__()
-- Shadow the Roblox globals for the panel source (the CLI's _G is read-only).
local game = MockGame
local workspace = MockWorkspace
local shared = MockShared
local Instance = MockInstance
local Enum = MockEnum
local Color3 = MockColor3
local UDim = MockUDim
local UDim2 = MockUDim2
local Vector2 = MockVector2
local Vector3 = MockVector3
local CFrame = MockCFrame
local TweenInfo = MockTweenInfo
local NumberSequence = MockNumberSequence
local ColorSequence = MockColorSequence
local NumberSequenceKeypoint = MockNumberSequenceKeypoint
local ColorSequenceKeypoint = MockColorSequenceKeypoint
local Rect = MockRect
local Font = MockFont
local Random = MockRandom
local typeof = MockTypeof
local task = MockTask
local os = MockOs
local warn = MockWarn
local tick = MockTick
local wait = MockTask.wait
local spawn = MockTask.spawn
local delay = MockTask.delay
local Players = MockPlayersService
local ReplicatedStorage = MockReplicatedStorage
local StarterGui = MockStarterGuiService
local Lighting = MockLighting
local SoundService = MockSoundService
local TextChatService = MockTextChatService
local RunService = MockRunService
local generalChannel = MockGeneralChannel
local MockPlayers = MockPlayerList
local makePlayer = MockMakePlayer
local RuntimeErrors = MockRuntimeErrors
local TraceLog = MockTraceLog

SHADOWS

	if [ -f "$HERE/setup_${mode}.luau" ]; then
		cat "$HERE/setup_${mode}.luau" >> "$out"
	fi

	if [ "$mode" = "dual" ]; then
		# Load the panel twice into the same mock DataModel: once as the server
		# half, once as the client half.
		printf '\nlocal PANEL = (function()\n' >> "$out"
		cat "$PANEL" >> "$out"
		printf '\nend)()\n\nlocal PANEL_SERVER = PANEL\n\nMock.setMode(false, true, false) -- second boot: CLIENT\nprint("[setup] booting the client half")\n\nlocal PANEL = (function()\n' >> "$out"
		cat "$PANEL" >> "$out"
		printf '\nend)()\n\nlocal PANEL_CLIENT = PANEL\nPANEL = PANEL_CLIENT\n\n' >> "$out"
	else
		printf '\nlocal PANEL = (function()\n' >> "$out"
		cat "$PANEL" >> "$out"
		printf '\nend)()\n\n' >> "$out"
	fi

	cat "$HERE/driver_${mode}.luau" >> "$out"

	cat >> "$out" << 'RUNCOR'

end

-- Run the driver (and therefore the panel boot) inside a scheduled coroutine so
-- that task.wait()/WaitForChild() yields are handled by the mock scheduler.
do
	local driverCo = MockTask.spawn(__driver__)
	local guard = 0
	while coroutine.status(driverCo) ~= "dead" and guard < 600 do
		guard += 1
		Mock.pump(1)
	end
	if coroutine.status(driverCo) ~= "dead" then
		print("[DRIVER] still blocked after " .. guard .. " pump cycles (status=" .. coroutine.status(driverCo) .. ")")
	end
end
RUNCOR

	echo "$out"
}

MODES="${*:-server client dual legacy}"
overall=0
declare -a SUMMARY=()

for mode in $MODES; do
	if [ ! -f "$HERE/driver_${mode}.luau" ]; then
		echo "!! no driver for scenario '$mode' (expected $HERE/driver_${mode}.luau)" >&2
		overall=1
		continue
	fi

	combined="$(build "$mode")"
	echo
	echo "################ scenario: $mode ################"

	if ! "$LUAU" "$combined" > "$OUT/${mode}.log" 2>&1; then
		echo "!! $mode: the Luau VM exited with an error" >&2
		tail -20 "$OUT/${mode}.log" >&2
		overall=1
		SUMMARY+=("$mode: VM ERROR")
		continue
	fi

	grep -E "^  \[(PASS|FAIL)\]|RESULT:|RUNTIME ERROR|MOCK ERROR|^   - " "$OUT/${mode}.log" | tail -30

	result="$(grep -E 'RESULT:' "$OUT/${mode}.log" | tail -1)"
	errors="$(grep -cE 'RUNTIME ERRORS CAPTURED|MOCK ERROR' "$OUT/${mode}.log" || true)"

	if echo "$result" | grep -q " 0 failed" && [ "$errors" = "0" ]; then
		SUMMARY+=("$mode: ${result##*: }")
	else
		overall=1
		SUMMARY+=("$mode: ${result##*: } (see $OUT/${mode}.log)")
	fi
done

echo
echo "================== SUMMARY =================="
for line in "${SUMMARY[@]}"; do
	echo "  $line"
done
echo "============================================="
echo "logs: $OUT/*.log"

exit $overall
